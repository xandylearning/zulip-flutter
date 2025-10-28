import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/model/model.dart';
import '../generated/l10n/zulip_localizations.dart';
import '../model/narrow.dart';
import '../model/recent_dm_conversations.dart';
import '../model/store.dart';
import '../model/unreads.dart';
import 'icons.dart';
import 'message_list.dart';
import 'new_dm_sheet.dart';
import 'page.dart';
import 'store.dart';
import 'theme.dart';
import 'unread_count_badge.dart';
import 'user.dart';

enum ConversationFilter {
  all,
  unread,
  groups;

  String label(ZulipLocalizations zulipLocalizations) {
    switch (this) {
      case ConversationFilter.all:
        return 'All';
      case ConversationFilter.unread:
        return 'Unread';
      case ConversationFilter.groups:
        return 'Groups';
    }
  }
}

/// Helper function to format time display for chat items
String _formatChatTime(int? messageId, PerAccountStore store) {
  if (messageId == null || messageId == 0) return 'Now';

  final message = store.messages[messageId];
  if (message == null) {
    // If message not found in store, show a generic time
    return 'Now';
  }

  final messageTime = DateTime.fromMillisecondsSinceEpoch(message.timestamp * 1000);
  final now = DateTime.now();
  final difference = now.difference(messageTime);

  // If message is from today, show time
  if (messageTime.day == now.day &&
      messageTime.month == now.month &&
      messageTime.year == now.year) {
    if (difference.inMinutes < 1) {
      return 'Now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    }
  }

  // If message is from yesterday
  final yesterday = now.subtract(const Duration(days: 1));
  if (messageTime.day == yesterday.day &&
      messageTime.month == yesterday.month &&
      messageTime.year == yesterday.year) {
    return 'Yesterday';
  }

  // For older messages, show date
  if (messageTime.year == now.year) {
    return '${messageTime.month}/${messageTime.day}';
  } else {
    return '${messageTime.month}/${messageTime.day}/${messageTime.year}';
  }
}

class ChatsPageBody extends StatefulWidget {
  const ChatsPageBody({super.key});

  @override
  State<ChatsPageBody> createState() => _ChatsPageBodyState();
}

class _ChatsPageBodyState extends State<ChatsPageBody>
    with PerAccountStoreAwareStateMixin<ChatsPageBody> {
  RecentDmConversationsView? recentDmConversationsModel;
  Unreads? unreadsModel;

  ConversationFilter _selectedFilter = ConversationFilter.all;

  @override
  void onNewStore() {
    final newStore = PerAccountStoreWidget.of(context);

    recentDmConversationsModel?.removeListener(_modelChanged);
    recentDmConversationsModel = newStore.recentDmConversationsView
      ..addListener(_modelChanged);

    unreadsModel?.removeListener(_modelChanged);
    unreadsModel = newStore.unreads..addListener(_modelChanged);
  }

  @override
  void dispose() {
    recentDmConversationsModel?.removeListener(_modelChanged);
    unreadsModel?.removeListener(_modelChanged);
    super.dispose();
  }

  void _modelChanged() {
    setState(() {
      // State lives in the models
    });
  }

  void _onFilterChanged(ConversationFilter filter) {
    setState(() {
      _selectedFilter = filter;
    });
    HapticFeedback.selectionClick();
  }

  void _handleDmSelect(DmNarrow narrow) {
    // Add haptic feedback for better user experience
    HapticFeedback.lightImpact();
    Navigator.push(context,
      MessageListPage.buildRoute(context: context, narrow: narrow));
  }

  void _handleChannelSelect(ChannelNarrow narrow) {
    // Add haptic feedback for better user experience
    HapticFeedback.lightImpact();
    Navigator.push(context,
      MessageListPage.buildRoute(context: context, narrow: narrow));
  }

  void _handleNewDmSelect(DmNarrow narrow) {
    // Add haptic feedback for better user experience
    HapticFeedback.mediumImpact();
    Navigator.pushReplacement(context,
      MessageListPage.buildRoute(context: context, narrow: narrow));
  }

  List<_ChatItem> _applyFilter(List<_ChatItem> items) {
    switch (_selectedFilter) {
      case ConversationFilter.all:
        return items;
      case ConversationFilter.unread:
        return items.where((item) => item.unreadCount > 0).toList();
      case ConversationFilter.groups:
        return items.where((item) {
          if (item.type == _ChatItemType.dm) {
            // Group DMs have 2 or more other recipients (3+ total including self)
            return item.dmNarrow!.otherRecipientIds.length >= 2;
          }
          return false; // Exclude channels from groups filter
        }).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = PerAccountStoreWidget.of(context);
    final zulipLocalizations = ZulipLocalizations.of(context);

    // Combine DM conversations and channels with recent activity
    final List<_ChatItem> chatItems = [];

    // Add recent DM conversations
    final dmConversations = recentDmConversationsModel!.sorted;
    for (final dmNarrow in dmConversations) {
      if (store.shouldMuteDmConversation(dmNarrow)) continue;

      final unreadCount = unreadsModel!.countInDmNarrow(dmNarrow);
      int lastMessageId = recentDmConversationsModel!.map[dmNarrow]!;

      // If the message is not in the store, try to find any recent message in this conversation
      if (lastMessageId == 0 || !store.messages.containsKey(lastMessageId)) {
        final dmMessages = store.messages.values
            .where((message) {
              if (message is! DmMessage) return false;
              // Create DmNarrow from the message's conversation
              final messageNarrow = DmNarrow.ofConversation(message.conversation, selfUserId: store.selfUserId);
              return messageNarrow == dmNarrow;
            })
            .toList();
        if (dmMessages.isNotEmpty) {
          dmMessages.sort((a, b) => b.id.compareTo(a.id));
          lastMessageId = dmMessages.first.id;
        }
      }

      chatItems.add(_ChatItem.dm(
        narrow: dmNarrow,
        unreadCount: unreadCount,
        lastMessageId: lastMessageId,
      ));
    }

    // Add channels with recent activity (unread messages)
    final channelsWithUnreads = unreadsModel!.streams.entries
        .where((entry) => store.subscriptions.containsKey(entry.key))
        .map((entry) {
      final streamId = entry.key;
      final subscription = store.subscriptions[streamId]!;
      final totalUnreadCount = entry.value.values
          .expand((messageIds) => messageIds)
          .length;

      // Find the latest message ID across all topics in this stream
      int latestMessageId = 0;
      for (final messageIds in entry.value.values) {
        if (messageIds.isNotEmpty && messageIds.last > latestMessageId) {
          latestMessageId = messageIds.last;
        }
      }

      return _ChatItem.channel(
        subscription: subscription,
        unreadCount: totalUnreadCount,
        lastMessageId: latestMessageId,
      );
    }).toList();

    chatItems.addAll(channelsWithUnreads);

    // Sort by last message ID (most recent first)
    chatItems.sort((a, b) => b.lastMessageId.compareTo(a.lastMessageId));

    // Apply filter
    final filteredChatItems = _applyFilter(chatItems);

    if (chatItems.isEmpty) {
      return Stack(
        children: [
          Center(
            child: PageBodyEmptyContentPlaceholder(
              message: 'No conversations yet. Start a new chat!',
            ),
          ),
          Positioned(
            bottom: 21,
            right: 16,
            child: _NewChatButton(onDmSelect: _handleNewDmSelect),
          ),
        ],
      );
    }

    return Column(
      children: [
        _FilterBubbleBar(
          selectedFilter: _selectedFilter,
          onFilterChanged: _onFilterChanged,
          chatItems: chatItems,
          unreadsModel: unreadsModel!,
        ),
        Expanded(
          child: filteredChatItems.isEmpty
              ? Center(
                  child: PageBodyEmptyContentPlaceholder(
                    message: 'No ${_selectedFilter.label(zulipLocalizations).toLowerCase()} conversations',
                  ),
                )
              : Stack(
                  children: [
                    ListView.builder(
                      padding: const EdgeInsets.only(bottom: 90),
                      itemCount: filteredChatItems.length,
                      itemBuilder: (context, index) {
                        final chatItem = filteredChatItems[index];
                        return _buildChatItem(chatItem);
                      },
                    ),
                    Positioned(
                      bottom: 21,
                      right: 16,
                      child: Hero(
                        tag: 'new_chat_fab',
                        child: _NewChatButton(onDmSelect: _handleNewDmSelect),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildChatItem(_ChatItem chatItem) {
    switch (chatItem.type) {
      case _ChatItemType.dm:
        return _DmChatItem(
          narrow: chatItem.dmNarrow!,
          unreadCount: chatItem.unreadCount,
          lastMessageId: chatItem.lastMessageId,
          onDmSelect: _handleDmSelect,
        );
      case _ChatItemType.channel:
        return _ChannelChatItem(
          subscription: chatItem.subscription!,
          unreadCount: chatItem.unreadCount,
          lastMessageId: chatItem.lastMessageId,
          onChannelSelect: _handleChannelSelect,
        );
    }
  }
}

enum _ChatItemType { dm, channel }

class _ChatItem {
  const _ChatItem._({
    required this.type,
    this.dmNarrow,
    this.subscription,
    required this.unreadCount,
    required this.lastMessageId,
  });

  factory _ChatItem.dm({
    required DmNarrow narrow,
    required int unreadCount,
    required int lastMessageId,
  }) {
    return _ChatItem._(
      type: _ChatItemType.dm,
      dmNarrow: narrow,
      unreadCount: unreadCount,
      lastMessageId: lastMessageId,
    );
  }

  factory _ChatItem.channel({
    required Subscription subscription,
    required int unreadCount,
    required int lastMessageId,
  }) {
    return _ChatItem._(
      type: _ChatItemType.channel,
      subscription: subscription,
      unreadCount: unreadCount,
      lastMessageId: lastMessageId,
    );
  }

  final _ChatItemType type;
  final DmNarrow? dmNarrow;
  final Subscription? subscription;
  final int unreadCount;
  final int lastMessageId;
}

class _DmChatItem extends StatelessWidget {
  const _DmChatItem({
    required this.narrow,
    required this.unreadCount,
    required this.lastMessageId,
    required this.onDmSelect,
  });

  final DmNarrow narrow;
  final int unreadCount;
  final int lastMessageId;
  final void Function(DmNarrow) onDmSelect;

  static const double _avatarSize = 56;

  @override
  Widget build(BuildContext context) {
    final store = PerAccountStoreWidget.of(context);
    final designVariables = DesignVariables.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    final InlineSpan title;
    final Widget avatar;
    int? userIdForPresence;
    String lastMessage = 'Tap to start conversation';
    String timeString = _formatChatTime(lastMessageId, store);

    switch (narrow.otherRecipientIds) {
      case []:
        title = TextSpan(text: store.selfUser.fullName, children: [
          UserStatusEmoji.asWidgetSpan(userId: store.selfUserId,
            fontSize: 17, textScaler: MediaQuery.textScalerOf(context)),
        ]);
        avatar = Hero(
          tag: 'avatar_${store.selfUserId}',
          child: Avatar(userId: store.selfUserId, size: _avatarSize, borderRadius: 28),
        );
      case [var otherUserId]:
        title = TextSpan(text: store.userDisplayName(otherUserId), children: [
          UserStatusEmoji.asWidgetSpan(userId: otherUserId,
            fontSize: 17, textScaler: MediaQuery.textScalerOf(context)),
        ]);
        avatar = Hero(
          tag: 'avatar_$otherUserId',
          child: Avatar(userId: otherUserId, size: _avatarSize, borderRadius: 28),
        );
        userIdForPresence = otherUserId;
      default:
        title = TextSpan(
          text: narrow.otherRecipientIds.map(store.userDisplayName).join(', '));
        avatar = Hero(
          tag: 'avatar_group_${narrow.otherRecipientIds.join('_')}',
          child: Container(
            width: _avatarSize,
            height: _avatarSize,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colorScheme.primary, colorScheme.primary.withValues(alpha: 0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                ZulipIcons.group,
                size: 28,
                color: Colors.white,
              ),
            ),
          ),
        );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: designVariables.bgMessageRegular,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onDmSelect(narrow),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Stack(
                  children: [
                    avatar,
                    if (userIdForPresence != null)
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: PresenceIndicator(userId: userIdForPresence),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  color: designVariables.labelMenuButton,
                                  fontSize: 16,
                                  fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.w500,
                                ),
                                children: [title],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            timeString,
                            style: TextStyle(
                              color: unreadCount > 0
                                  ? colorScheme.primary
                                  : designVariables.labelTime,
                              fontSize: 12,
                              fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              lastMessage,
                              style: TextStyle(
                                color: unreadCount > 0
                                    ? designVariables.labelMenuButton.withValues(alpha: 0.8)
                                    : designVariables.labelMenuButton.withValues(alpha: 0.6),
                                fontSize: 14,
                                fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (unreadCount > 0) ...[
                            const SizedBox(width: 8),
                            UnreadCountBadge(
                              count: unreadCount,
                              backgroundColor: colorScheme.primary,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChannelChatItem extends StatelessWidget {
  const _ChannelChatItem({
    required this.subscription,
    required this.unreadCount,
    required this.lastMessageId,
    required this.onChannelSelect,
  });

  final Subscription subscription;
  final int unreadCount;
  final int lastMessageId;
  final void Function(ChannelNarrow) onChannelSelect;

  static const double _avatarSize = 56;

  @override
  Widget build(BuildContext context) {
    final store = PerAccountStoreWidget.of(context);
    final designVariables = DesignVariables.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final narrow = ChannelNarrow(subscription.streamId);

    String lastMessage = subscription.description.isNotEmpty
        ? subscription.description
        : 'Channel conversation';
    String timeString = _formatChatTime(lastMessageId, store);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: designVariables.bgMessageRegular,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onChannelSelect(narrow),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Hero(
                  tag: 'channel_avatar_${subscription.streamId}',
                  child: Container(
                    width: _avatarSize,
                    height: _avatarSize,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(subscription.color),
                          Color(subscription.color).withValues(alpha: 0.8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Color(subscription.color).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        ZulipIcons.hash_italic,
                        size: 28,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              subscription.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.w500,
                                color: designVariables.labelMenuButton,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            timeString,
                            style: TextStyle(
                              color: unreadCount > 0
                                  ? colorScheme.primary
                                  : designVariables.labelTime,
                              fontSize: 12,
                              fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              lastMessage,
                              style: TextStyle(
                                color: unreadCount > 0
                                    ? designVariables.labelMenuButton.withValues(alpha: 0.8)
                                    : designVariables.labelMenuButton.withValues(alpha: 0.6),
                                fontSize: 14,
                                fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (unreadCount > 0) ...[
                            const SizedBox(width: 8),
                            UnreadCountBadge(
                              count: unreadCount,
                              backgroundColor: colorScheme.primary,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NewChatButton extends StatefulWidget {
  const _NewChatButton({required this.onDmSelect});

  final void Function(DmNarrow) onDmSelect;

  @override
  State<_NewChatButton> createState() => _NewChatButtonState();
}

class _NewChatButtonState extends State<_NewChatButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTapDown: (_) {
        _controller.forward();
        HapticFeedback.mediumImpact();
      },
      onTapUp: (_) {
        _controller.reverse();
      },
      onTapCancel: () {
        _controller.reverse();
      },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colorScheme.primary, colorScheme.primary.withValues(alpha: 0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(32),
                child: InkWell(
                  borderRadius: BorderRadius.circular(32),
                  onTap: () {
                    showNewDmSheet(context, widget.onDmSelect);
                  },
                  child: const Center(
                    child: Icon(
                      ZulipIcons.pencil,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FilterBubbleBar extends StatelessWidget {
  const _FilterBubbleBar({
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.chatItems,
    required this.unreadsModel,
  });

  final ConversationFilter selectedFilter;
  final ValueChanged<ConversationFilter> onFilterChanged;
  final List<_ChatItem> chatItems;
  final Unreads unreadsModel;

  int _getFilterCount(ConversationFilter filter) {
    switch (filter) {
      case ConversationFilter.all:
        return chatItems.length;
      case ConversationFilter.unread:
        return chatItems.where((item) => item.unreadCount > 0).length;
      case ConversationFilter.groups:
        return chatItems.where((item) {
          if (item.type == _ChatItemType.dm) {
            return item.dmNarrow!.otherRecipientIds.length >= 2;
          }
          return false;
        }).length;
    }
  }

  @override
  Widget build(BuildContext context) {
    final zulipLocalizations = ZulipLocalizations.of(context);
    final designVariables = DesignVariables.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(


      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: ConversationFilter.values.map((filter) {
            final isSelected = filter == selectedFilter;
            final filterCount = _getFilterCount(filter);

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _FilterChip(
                label: filter.label(zulipLocalizations),
                count: filterCount,
                isSelected: isSelected,
                onTap: () => onFilterChanged(filter),
                colorScheme: colorScheme,
                designVariables: designVariables,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _FilterChip extends StatefulWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
    required this.colorScheme,
    required this.designVariables,
  });

  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;
  final ColorScheme colorScheme;
  final DesignVariables designVariables;

  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: widget.isSelected
                    ? widget.colorScheme.primary
                    : widget.designVariables.background,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: widget.isSelected
                      ? widget.colorScheme.primary
                      : widget.designVariables.borderBar,
                  width: 1,
                ),
                boxShadow: widget.isSelected
                    ? [
                        BoxShadow(
                          color: widget.colorScheme.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: widget.isSelected
                          ? Colors.white
                          : widget.designVariables.labelMenuButton,
                    ),
                  ),
                  if (widget.count > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: widget.isSelected
                            ? Colors.white.withValues(alpha: 0.25)
                            : widget.colorScheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        widget.count.toString(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: widget.isSelected
                              ? Colors.white
                              : widget.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// Enhanced presence indicator with smooth animations
class PresenceIndicator extends StatefulWidget {
  const PresenceIndicator({super.key, required this.userId});

  final int userId;

  @override
  State<PresenceIndicator> createState() => _PresenceIndicatorState();
}

class _PresenceIndicatorState extends State<PresenceIndicator>
    with SingleTickerProviderStateMixin, PerAccountStoreAwareStateMixin<PresenceIndicator> {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    _controller.repeat(reverse: true);
  }

  @override
  void onNewStore() {
    final newStore = PerAccountStoreWidget.of(context);
    newStore.presence.removeListener(_presenceChanged);
    newStore.presence.addListener(_presenceChanged);
  }

  @override
  void dispose() {
    final store = PerAccountStoreWidget.of(context);
    store.presence.removeListener(_presenceChanged);
    _controller.dispose();
    super.dispose();
  }

  void _presenceChanged() {
    setState(() {
      // Presence state lives in store.presence
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = PerAccountStoreWidget.of(context);
    final user = store.getUser(widget.userId);
    final designVariables = DesignVariables.of(context);

    if (user == null || !user.isActive) {
      return const SizedBox.shrink();
    }

    // Get actual presence status from store
    final presenceStatus = store.presence.presenceStatusForUser(
      widget.userId,
      utcNow: DateTime.now().toUtc(),
    );

    // If user is offline (null), don't show indicator
    if (presenceStatus == null) {
      return const SizedBox.shrink();
    }

    // Determine color based on presence status
    final Color indicatorColor;
    switch (presenceStatus) {
      case PresenceStatus.active:
        indicatorColor = Colors.green;
      case PresenceStatus.idle:
        indicatorColor = Colors.orange;
    }

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: indicatorColor,
            shape: BoxShape.circle,
            border: Border.all(color: designVariables.bgTopBar, width: 3),
            boxShadow: [
              BoxShadow(
                color: indicatorColor.withValues(alpha: 0.4),
                blurRadius: 4 * _pulseAnimation.value,
                spreadRadius: 1 * _pulseAnimation.value,
              ),
            ],
          ),
        );
      },
    );
  }
}
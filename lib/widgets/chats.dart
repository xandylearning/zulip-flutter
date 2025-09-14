import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/model/model.dart';
import '../generated/l10n/zulip_localizations.dart';
import '../model/narrow.dart';
import '../model/recent_dm_conversations.dart';
import '../model/unreads.dart';
import 'color.dart';
import 'icons.dart';
import 'message_list.dart';
import 'new_dm_sheet.dart';
import 'page.dart';
import 'store.dart';
import 'text.dart';
import 'theme.dart';
import 'unread_count_badge.dart';
import 'user.dart';

class ChatsPageBody extends StatefulWidget {
  const ChatsPageBody({super.key});

  @override
  State<ChatsPageBody> createState() => _ChatsPageBodyState();
}

class _ChatsPageBodyState extends State<ChatsPageBody>
    with PerAccountStoreAwareStateMixin<ChatsPageBody> {
  RecentDmConversationsView? recentDmConversationsModel;
  Unreads? unreadsModel;

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

  @override
  Widget build(BuildContext context) {
    final store = PerAccountStoreWidget.of(context);
    final zulipLocalizations = ZulipLocalizations.of(context);
    final designVariables = DesignVariables.of(context);

    // Combine DM conversations and channels with recent activity
    final List<_ChatItem> chatItems = [];

    // Add recent DM conversations
    final dmConversations = recentDmConversationsModel!.sorted;
    for (final dmNarrow in dmConversations) {
      if (store.shouldMuteDmConversation(dmNarrow)) continue;

      final unreadCount = unreadsModel!.countInDmNarrow(dmNarrow);
      chatItems.add(_ChatItem.dm(
        narrow: dmNarrow,
        unreadCount: unreadCount,
        lastMessageId: recentDmConversationsModel!.map[dmNarrow]!,
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

    return Stack(
      children: [
        AnimatedList(
          padding: const EdgeInsets.only(bottom: 90),
          initialItemCount: chatItems.length,
          itemBuilder: (context, index, animation) {
            if (index >= chatItems.length) return const SizedBox.shrink();

            final chatItem = chatItems[index];

            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: FadeTransition(
                opacity: animation,
                child: _buildChatItem(chatItem),
              ),
            );
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
    );
  }

  Widget _buildChatItem(_ChatItem chatItem) {
    switch (chatItem.type) {
      case _ChatItemType.dm:
        return _DmChatItem(
          narrow: chatItem.dmNarrow!,
          unreadCount: chatItem.unreadCount,
          onDmSelect: _handleDmSelect,
        );
      case _ChatItemType.channel:
        return _ChannelChatItem(
          subscription: chatItem.subscription!,
          unreadCount: chatItem.unreadCount,
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
    required this.onDmSelect,
  });

  final DmNarrow narrow;
  final int unreadCount;
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
    String timeString = 'Now';

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
                        child: PresenceIndicator(userId: userIdForPresence!),
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
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                unreadCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
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
    required this.onChannelSelect,
  });

  final Subscription subscription;
  final int unreadCount;
  final void Function(ChannelNarrow) onChannelSelect;

  static const double _avatarSize = 56;

  @override
  Widget build(BuildContext context) {
    final designVariables = DesignVariables.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final narrow = ChannelNarrow(subscription.streamId);

    String lastMessage = subscription.description?.isNotEmpty == true
        ? subscription.description!
        : 'Channel conversation';
    String timeString = 'Now';

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
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: colorScheme.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                unreadCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
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

// Enhanced presence indicator with smooth animations
class PresenceIndicator extends StatefulWidget {
  const PresenceIndicator({super.key, required this.userId});

  final int userId;

  @override
  State<PresenceIndicator> createState() => _PresenceIndicatorState();
}

class _PresenceIndicatorState extends State<PresenceIndicator>
    with SingleTickerProviderStateMixin {
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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = PerAccountStoreWidget.of(context);
    final user = store.getUser(widget.userId);
    final designVariables = DesignVariables.of(context);

    if (user == null || !user.isActive) {
      return const SizedBox.shrink();
    }

    // TODO: Implement actual presence status from store
    final isOnline = true; // Placeholder

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: isOnline ? Colors.green : Colors.grey,
            shape: BoxShape.circle,
            border: Border.all(color: designVariables.bgTopBar, width: 3),
            boxShadow: isOnline
                ? [
                    BoxShadow(
                      color: Colors.green.withValues(alpha: 0.4),
                      blurRadius: 4 * _pulseAnimation.value,
                      spreadRadius: 1 * _pulseAnimation.value,
                    ),
                  ]
                : null,
          ),
        );
      },
    );
  }
}
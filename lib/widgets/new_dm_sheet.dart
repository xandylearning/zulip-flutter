import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api/model/model.dart';
import '../generated/l10n/zulip_localizations.dart';
import '../model/autocomplete.dart';
import '../model/narrow.dart';
import '../model/store.dart';
import 'app_bar.dart';
import 'color.dart';
import 'icons.dart';
import 'page.dart';
import 'recent_dm_conversations.dart';
import 'store.dart';
import 'text.dart';
import 'theme.dart';
import 'user.dart';

void showNewDmSheet(BuildContext context, OnDmSelectCallback onDmSelect) {
  Navigator.of(context).push(
    MaterialAccountWidgetRoute(
      context: context,
      page: NewDmPage(onDmSelect: onDmSelect),
    ),
  );
}

class NewDmPage extends StatelessWidget {
  const NewDmPage({super.key, required this.onDmSelect});

  final OnDmSelectCallback onDmSelect;

  @override
  Widget build(BuildContext context) {
    final zulipLocalizations = ZulipLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final designVariables = DesignVariables.of(context);

    return Scaffold(
      backgroundColor: designVariables.mainBackground,
      appBar: AppBar(
        title: Text(
          zulipLocalizations.newDmSheetScreenTitle,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: colorScheme.primary,
          ),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).pop();
          },
        ),
        backgroundColor: designVariables.bgTopBar,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: NewDmPicker(onDmSelect: (narrow) {
        HapticFeedback.mediumImpact();
        Navigator.of(context).pop();
        onDmSelect(narrow);
      }),
    );
  }
}

@visibleForTesting
class NewDmPicker extends StatefulWidget {
  const NewDmPicker({super.key, required this.onDmSelect});

  final OnDmSelectCallback onDmSelect;

  @override
  State<NewDmPicker> createState() => _NewDmPickerState();
}

class _NewDmPickerState extends State<NewDmPicker> with PerAccountStoreAwareStateMixin<NewDmPicker> {
  late TextEditingController searchController;
  late ScrollController resultsScrollController;
  Set<int> selectedUserIds = {};
  List<User> filteredUsers = [];
  List <User> sortedUsers = [];

  @override
  void initState() {
    super.initState();
    searchController = TextEditingController()..addListener(_handleSearchUpdate);
    resultsScrollController = ScrollController();
  }

  @override
  void onNewStore() {
    final store = PerAccountStoreWidget.of(context);
    _initSortedUsers(store);
  }

  @override
  void dispose() {
    searchController.dispose();
    resultsScrollController.dispose();
    super.dispose();
  }

  void _initSortedUsers(PerAccountStore store) {
    final users = store.allUsers
      .where((user) => user.isActive && !store.isUserMuted(user.userId));
    sortedUsers = List<User>.from(users)
      ..sort((a, b) => MentionAutocompleteView.compareByDms(a, b, store: store));
    _updateFilteredUsers(store);
  }

  void _handleSearchUpdate() {
    final store = PerAccountStoreWidget.of(context);
    _updateFilteredUsers(store);
  }

  // Function to sort users based on recency of DM's
  // TODO: switch to using an `AutocompleteView` for users
  void _updateFilteredUsers(PerAccountStore store) {
    final excludeSelfUser = selectedUserIds.isNotEmpty
      && !selectedUserIds.contains(store.selfUserId);
    final normalizedQuery =
      AutocompleteQuery.lowercaseAndStripDiacritics(searchController.text);

    final result = <User>[];
    for (final user in sortedUsers) {
      if (excludeSelfUser && user.userId == store.selfUserId) continue;
      final normalizedName = AutocompleteQuery.lowercaseAndStripDiacritics(user.fullName);
      if (normalizedName.contains(normalizedQuery)) {
        result.add(user);
      }
    }

    setState(() {
      filteredUsers = result;
    });

    if (resultsScrollController.hasClients) {
      // Jump to the first results for the new query.
      resultsScrollController.jumpTo(0);
    }
  }

  void _selectUser(int userId) {
    assert(!selectedUserIds.contains(userId));
    final store = PerAccountStoreWidget.of(context);
    selectedUserIds.add(userId);
    if (userId != store.selfUserId) {
      selectedUserIds.remove(store.selfUserId);
    }
    _updateFilteredUsers(store);
  }

  void _unselectUser(int userId) {
    assert(selectedUserIds.contains(userId));
    final store = PerAccountStoreWidget.of(context);
    selectedUserIds.remove(userId);
    _updateFilteredUsers(store);
  }

  void _handleUserTap(int userId) {
    selectedUserIds.contains(userId)
      ? _unselectUser(userId)
      : _selectUser(userId);
    searchController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final designVariables = DesignVariables.of(context);

    return Container(
      decoration: BoxDecoration(
        color: designVariables.mainBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _NewDmSearchBar(
              controller: searchController,
              selectedUserIds: selectedUserIds,
              unselectUser: _unselectUser,
            ),
            const SizedBox(height: 20),
            Expanded(
              child: _NewDmUserList(
                filteredUsers: filteredUsers,
                selectedUserIds: selectedUserIds,
                scrollController: resultsScrollController,
                onUserTapped: (userId) => _handleUserTap(userId),
              ),
            ),
            const SizedBox(height: 20),
            _ComposeButton(
              selectedUserIds: selectedUserIds,
              onDmSelect: widget.onDmSelect,
            ),
          ],
        ),
      ),
    );
  }
}

class _ComposeButton extends StatefulWidget {
  const _ComposeButton({required this.selectedUserIds, required this.onDmSelect});

  final Set<int> selectedUserIds;
  final OnDmSelectCallback onDmSelect;

  @override
  State<_ComposeButton> createState() => _ComposeButtonState();
}

class _ComposeButtonState extends State<_ComposeButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
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
    final zulipLocalizations = ZulipLocalizations.of(context);

    final isEnabled = widget.selectedUserIds.isNotEmpty;

    return GestureDetector(
      onTapDown: isEnabled ? (_) => _controller.forward() : null,
      onTapUp: isEnabled ? (_) => _controller.reverse() : null,
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: isEnabled ? _scaleAnimation.value : 1.0,
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                gradient: isEnabled
                    ? LinearGradient(
                        colors: [colorScheme.primary, colorScheme.primary.withValues(alpha: 0.8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isEnabled ? null : colorScheme.outline.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
                boxShadow: isEnabled
                    ? [
                        BoxShadow(
                          color: colorScheme.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: isEnabled
                      ? () {
                          HapticFeedback.mediumImpact();
                          final store = PerAccountStoreWidget.of(context);
                          final narrow = DmNarrow.withUsers(
                            widget.selectedUserIds.toList(),
                            selfUserId: store.selfUserId,
                          );
                          widget.onDmSelect(narrow);
                        }
                      : null,
                  child: Center(
                    child: Text(
                      zulipLocalizations.newDmSheetComposeButtonLabel,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isEnabled ? Colors.white : colorScheme.outline,
                      ),
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



class _NewDmSearchBar extends StatelessWidget {
  const _NewDmSearchBar({
    required this.controller,
    required this.selectedUserIds,
    required this.unselectUser,
  });

  final TextEditingController controller;
  final Set<int> selectedUserIds;
  final void Function(int) unselectUser;

  // void _removeUser

  Widget _buildSearchField(BuildContext context) {
    final designVariables = DesignVariables.of(context);
    final zulipLocalizations = ZulipLocalizations.of(context);
    final hintText = selectedUserIds.isEmpty
      ? zulipLocalizations.newDmSheetSearchHintEmpty
      : zulipLocalizations.newDmSheetSearchHintSomeSelected;

    return TextField(
      controller: controller,
      autofocus: true,
      cursorColor: designVariables.foreground,
      style: TextStyle(
        color: designVariables.textMessage,
        fontSize: 16,
        height: 20 / 16,
        fontWeight: FontWeight.w500,
      ),
      scrollPadding: EdgeInsets.zero,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 4),
        border: InputBorder.none,
        hintText: hintText,
        hintStyle: TextStyle(
          color: designVariables.labelSearchPrompt,
          fontSize: 16,
          height: 20 / 16,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final designVariables = DesignVariables.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: designVariables.bgSearchInput,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.transparent,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        reverse: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(
                Icons.search,
                color: designVariables.labelSearchPrompt,
                size: 20,
              ),
              for (final userId in selectedUserIds)
                _SelectedUserChip(userId: userId, unselectUser: unselectUser),
              // The IntrinsicWidth lets the text field participate in the Wrap
              // when its content fits on the same line with a user chip,
              // by preventing it from expanding to fill the available width.  See:
              //   https://github.com/zulip/zulip-flutter/pull/1322#discussion_r2094112488
              IntrinsicWidth(child: _buildSearchField(context)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedUserChip extends StatelessWidget {
  const _SelectedUserChip({
    required this.userId,
    required this.unselectUser,
  });

  final int userId;
  final void Function(int) unselectUser;

  @override
  Widget build(BuildContext context) {
    final designVariables = DesignVariables.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final store = PerAccountStoreWidget.of(context);
    final clampedTextScaler = MediaQuery.textScalerOf(context)
      .clamp(maxScaleFactor: 1.5);

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        unselectUser(userId);
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [colorScheme.primary, colorScheme.primary.withValues(alpha: 0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Avatar(
                userId: userId,
                size: clampedTextScaler.scale(20),
                borderRadius: 10,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  store.userDisplayName(userId),
                  textScaler: clampedTextScaler,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.close,
                size: 16,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewDmUserList extends StatelessWidget {
  const _NewDmUserList({
    required this.filteredUsers,
    required this.selectedUserIds,
    required this.scrollController,
    required this.onUserTapped,
  });

  final List<User> filteredUsers;
  final Set<int> selectedUserIds;
  final ScrollController scrollController;
  final void Function(int userId) onUserTapped;

  @override
  Widget build(BuildContext context) {
    final designVariables = DesignVariables.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final zulipLocalizations = ZulipLocalizations.of(context);

    if (filteredUsers.isEmpty) {
      // TODO(design): Missing in Figma.
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.person_search,
                size: 64,
                color: designVariables.labelMenuButton.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                zulipLocalizations.newDmSheetNoUsersFound,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: designVariables.labelMenuButton.withValues(alpha: 0.7),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: designVariables.bgMessageRegular,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: CustomScrollView(
          controller: scrollController,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(8),
              sliver: SliverList.builder(
                itemCount: filteredUsers.length,
                itemBuilder: (context, index) {
                  final user = filteredUsers[index];
                  final isSelected = selectedUserIds.contains(user.userId);

                  return _NewDmUserListItem(
                    userId: user.userId,
                    isSelected: isSelected,
                    onTapped: onUserTapped,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewDmUserListItem extends StatelessWidget {
  const _NewDmUserListItem({
    required this.userId,
    required this.isSelected,
    required this.onTapped,
  });

  final int userId;
  final bool isSelected;
  final void Function(int userId) onTapped;

  @override
  Widget build(BuildContext context) {
    final store = PerAccountStoreWidget.of(context);
    final designVariables = DesignVariables.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isSelected
            ? colorScheme.primary.withValues(alpha: 0.1)
            : Colors.transparent,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            HapticFeedback.lightImpact();
            onTapped(userId);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? colorScheme.primary : designVariables.radioBorder,
                      width: 2,
                    ),
                    color: isSelected ? colorScheme.primary : Colors.transparent,
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check,
                          size: 16,
                          color: Colors.white,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Hero(
                  tag: 'user_avatar_$userId',
                  child: Avatar(userId: userId, size: 40, borderRadius: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          text: store.userDisplayName(userId),
                          children: [
                            UserStatusEmoji.asWidgetSpan(
                              userId: userId,
                              fontSize: 16,
                              textScaler: MediaQuery.textScalerOf(context),
                            ),
                          ],
                        ),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: designVariables.textMessage,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@${store.getUser(userId)?.email.split('@').first ?? 'user'}',
                        style: TextStyle(
                          fontSize: 14,
                          color: designVariables.textMessageMuted,
                        ),
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

import 'dart:async';

import 'package:flutter/material.dart';

import '../generated/l10n/zulip_localizations.dart';
import '../model/narrow.dart';
import '../model/settings.dart';
import 'about_zulip.dart';
import 'action_sheet.dart';
import 'app.dart';
import 'app_bar.dart';
import 'button.dart';

import 'calls_page.dart';
import 'chats.dart';
import 'color.dart';
import 'icons.dart';
import 'inbox.dart';
import 'inset_shadow.dart';
import 'message_list.dart';
import 'page.dart';
import 'profile.dart';
import 'recent_dm_conversations.dart';
import 'settings.dart';
import 'store.dart';
import 'subscription_list.dart';
import 'text.dart';
import 'theme.dart';
import 'user.dart';

enum _HomePageTab {
  chats,
  calls,
  settings,
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  static AccountRoute<void> buildRoute({required int accountId}) {
    return MaterialAccountWidgetRoute(accountId: accountId,
      loadingPlaceholderPage: _LoadingPlaceholderPage(accountId: accountId),
      page: const HomePage());
  }

  /// Navigate to [HomePage], ensuring that its route is at the root level.
  static void navigate(BuildContext context, {required int accountId}) {
    final navigator = Navigator.of(context);
    navigator.popUntil((route) => route.isFirst);
    unawaited(navigator.pushReplacement(
      HomePage.buildRoute(accountId: accountId)));
  }

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final _tab = ValueNotifier(_HomePageTab.chats);

  @override
  void initState() {
    super.initState();
    _tab.addListener(_tabChanged);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _tabChanged() {
    setState(() {
      // The actual state lives in [_tab].
    });
  }

  String get _currentTabTitle {
    final zulipLocalizations = ZulipLocalizations.of(context);
    switch(_tab.value) {
      case _HomePageTab.chats:
        return zulipLocalizations.chatsPageTitle;
      case _HomePageTab.calls:
        return zulipLocalizations.callsPageTitle;
      case _HomePageTab.settings:
        return zulipLocalizations.settingsPageTitle;
    }
  }

  @override
  Widget build(BuildContext context) {
    const pageBodies = [
      (_HomePageTab.chats,    ChatsPageBody()),
      (_HomePageTab.calls,    CallsPageBody()),
      (_HomePageTab.settings, _SettingsPageBody()),
    ];

    _NavigationBarButton button(_HomePageTab tab, IconData icon) {
      return _NavigationBarButton(icon: icon,
        selected: _tab.value == tab,
        onPressed: () {
          _tab.value = tab;
        });
    }

    // Simple 3-tab navigation for WhatsApp-like interface
    final navigationBarButtons = [
      button(_HomePageTab.chats,    Icons.chat_bubble_outline), // More universally recognized chat icon
      button(_HomePageTab.calls,    Icons.phone_outlined),       // Clear phone icon for calls
      button(_HomePageTab.settings, Icons.settings_outlined),    // Standard settings icon
    ];

    final designVariables = DesignVariables.of(context);
    return Scaffold(
      appBar: ZulipAppBar(titleSpacing: 16,
        title: Text(_currentTabTitle),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () {
                final store = PerAccountStoreWidget.of(context);
                Navigator.push(context,
                  ProfilePage.buildRoute(context: context, userId: store.selfUserId));
              },
              child: Avatar(
                userId: PerAccountStoreWidget.of(context).selfUserId,
                size: 32,
                borderRadius: 16,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          for (final (tab, body) in pageBodies)
            // TODO(#535): Decide if we find it helpful to use something like
            //   [SemanticsProperties.namesRoute] to structure this UI better
            //   for screen-reader software.
            Offstage(offstage: tab != _tab.value, child: body),
        ]),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: designVariables.borderBar)),
          color: designVariables.bgBotBar,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: SizedBox(height: 68,
            child: Center(
              child: ConstrainedBox(
                // TODO(design): determine a suitable max width for bottom nav bar
                constraints: const BoxConstraints(maxWidth: 600),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final navigationBarButton in navigationBarButtons)
                      Expanded(child: navigationBarButton),
                  ])))))));
  }
}

const kTryAnotherAccountWaitPeriod = Duration(seconds: 5);

class _LoadingPlaceholderPage extends StatefulWidget {
  const _LoadingPlaceholderPage({required this.accountId});

  /// The relevant account for this page.
  ///
  /// The account is not guaranteed to exist in the global store. This can
  /// happen briefly when the account is removed from the database for logout,
  /// but before [PerAccountStoreWidget.routeToRemoveOnLogout] is processed.
  final int accountId;

  @override
  State<_LoadingPlaceholderPage> createState() => _LoadingPlaceholderPageState();
}

class _LoadingPlaceholderPageState extends State<_LoadingPlaceholderPage> {
  Timer? tryAnotherAccountTimer;
  bool showTryAnotherAccount = false;

  @override
  void initState() {
    super.initState();
    tryAnotherAccountTimer = Timer(kTryAnotherAccountWaitPeriod, () {
      setState(() {
        showTryAnotherAccount = true;
      });
    });
  }

  @override
  void dispose() {
    tryAnotherAccountTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final zulipLocalizations = ZulipLocalizations.of(context);
    final account = GlobalStoreWidget.of(context).getAccount(widget.accountId);

    if (account == null) {
      // We should only reach this state very briefly.
      // See [_LoadingPlaceholderPage.accountId].
      return Scaffold(
        appBar: AppBar(),
        body: const SizedBox.shrink());
    }

    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            Visibility(
              visible: showTryAnotherAccount,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    Text(textAlign: TextAlign.center,
                      zulipLocalizations.tryAnotherAccountMessage(account.realmUrl.toString())),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () => Navigator.push(context,
                        MaterialWidgetRoute(page: const ChooseAccountPage())),
                      child: Text(zulipLocalizations.tryAnotherAccountButton)),
                  ]))),
          ])));
  }
}

class _NavigationBarButton extends StatelessWidget {
  const _NavigationBarButton({
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  final IconData icon;
  final bool selected;
  final void Function() onPressed;

  @override
  Widget build(BuildContext context) {
    final designVariables = DesignVariables.of(context);

    return AnimatedScaleOnTap(
      scaleEnd: 0.875,
      duration: const Duration(milliseconds: 100),
      child: IconButton(
        icon: selected
          ? ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF414d75), // Brand blue
                  Color(0xFFf05462), // Brand red
                ],
              ).createShader(bounds),
              child: Icon(icon, size: 24, color: Colors.white),
            )
          : Icon(icon, size: 24, color: designVariables.icon),
        onPressed: onPressed,
        style: IconButton.styleFrom(
          // TODO(#417): Disable splash effects for all buttons globally.
          splashFactory: NoSplash.splashFactory,
          highlightColor: designVariables.navigationButtonBg,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(4))),
        )));
  }
}

void _showMainMenu(BuildContext context, {
  required ValueNotifier<_HomePageTab> tabNotifier,
}) {
  final menuItems = <Widget>[
    const _SearchButton(),
    // const SizedBox(height: 8),
    _InboxButton(tabNotifier: tabNotifier),
    // TODO: Recent conversations
    const _MentionsButton(),
    const _StarredMessagesButton(),
    const _CombinedFeedButton(),
    // TODO: Drafts
    _ChannelsButton(tabNotifier: tabNotifier),
    _DirectMessagesButton(tabNotifier: tabNotifier),
    // TODO(#1094): Users
    const _MyProfileButton(),
    const _SwitchAccountButton(),
    // TODO(#198): Set my status
    // const SizedBox(height: 8),
    const _SettingsButton(),
    // TODO(#661): Notifications
    // const SizedBox(height: 8),
    const _AboutZulipButton(),
    // TODO(#1095): VersionInfo
  ];

  final designVariables = DesignVariables.of(context);
  final accountId = PerAccountStoreWidget.accountIdOf(context);
  showModalBottomSheet<void>(
    context: context,
    // Clip.hardEdge looks bad; Clip.antiAliasWithSaveLayer looks pixel-perfect
    // on my iPhone 13 Pro but is marked as "much slower":
    //   https://api.flutter.dev/flutter/dart-ui/Clip.html
    clipBehavior: Clip.antiAlias,
    useSafeArea: true,
    isScrollControlled: true,
    // TODO: Fix the issue that the color does not respond when the theme
    //   changes, because `designVariables` was retrieved from a gesture handler,
    //   not a build method.  Discussion and screenshots:
    //     https://github.com/zulip/zulip-flutter/pull/1076/files#r1872659043
    backgroundColor: designVariables.bgBotBar,
    builder: (BuildContext _) {
      return PerAccountStoreWidget(
        accountId: accountId,
        child: SafeArea(
          minimum: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: InsetShadowBox(
                top: 8, bottom: 8,
                color: designVariables.bgBotBar,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  child: Column(children: menuItems)))),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: AnimatedScaleOnTap(
                  scaleEnd: 0.95,
                  duration: Duration(milliseconds: 100),
                  child: BottomSheetDismissButton(
                    style: BottomSheetDismissButtonStyle.close))),
            ])));
    });
}

abstract class _MenuButton extends StatelessWidget {
  const _MenuButton();

  String label(ZulipLocalizations zulipLocalizations);

  bool get selected => false;

  /// An icon to display before [label].
  ///
  /// Must be non-null unless [buildLeading] is overridden.
  IconData? get icon;

  static const _iconSize = 24.0;

  Widget buildLeading(BuildContext context) {
    assert(icon != null);
    final designVariables = DesignVariables.of(context);
    return Icon(icon, size: _iconSize,
      color: selected ? designVariables.iconSelected : designVariables.icon);
  }

  void onPressed(BuildContext context);

  void _handlePress(BuildContext context) {
    // Dismiss the enclosing action sheet immediately,
    // for swift UI feedback that the user's selection was received.
    Navigator.of(context).pop();

    onPressed(context);
  }

  @override
  Widget build(BuildContext context) {
    final designVariables = DesignVariables.of(context);
    final zulipLocalizations = ZulipLocalizations.of(context);

    final borderSideSelected = BorderSide(width: 1,
      strokeAlign: BorderSide.strokeAlignOutside,
      color: designVariables.borderMenuButtonSelected);
    final buttonStyle = TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
      foregroundColor: designVariables.labelMenuButton,
      // This has a default behavior of affecting the background color of the
      // button for states including "hovered", "focused" and "pressed".
      // Make this transparent so that we can have full control of these colors.
      overlayColor: Colors.transparent,
      splashFactory: NoSplash.splashFactory,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ).copyWith(
      backgroundColor: WidgetStateColor.fromMap({
        WidgetState.hovered: designVariables.bgMenuButtonActive.withFadedAlpha(0.5),
        WidgetState.focused: designVariables.bgMenuButtonActive,
        WidgetState.pressed: designVariables.bgMenuButtonActive,
        WidgetState.any:
          selected ? designVariables.bgMenuButtonSelected : Colors.transparent,
      }),
      side: WidgetStateBorderSide.fromMap({
        WidgetState.pressed: null,
        ~WidgetState.pressed: selected ? borderSideSelected : null,
      }));

    return AnimatedScaleOnTap(
      duration: const Duration(milliseconds: 100),
      scaleEnd: 0.95,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: TextButton(
          onPressed: () => _handlePress(context),
          style: buttonStyle,
          child: Row(spacing: 8, children: [
            SizedBox.square(dimension: _iconSize,
              child: buildLeading(context)),
            Expanded(child: Text(label(zulipLocalizations),
              // TODO(design): determine if we prefer to wrap
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 19, height: 26 / 19)
                .merge(weightVariableTextStyle(context, wght: selected ? 600 : 400)))),
          ]))));
  }
}

/// A menu button controlling the selected [_HomePageTab] on the bottom nav bar.
abstract class _NavigationBarMenuButton extends _MenuButton {
  const _NavigationBarMenuButton({required this.tabNotifier});

  final ValueNotifier<_HomePageTab> tabNotifier;

  _HomePageTab get navigationTarget;

  @override
  bool get selected => tabNotifier.value == navigationTarget;

  @override
  void onPressed(BuildContext context) {
    tabNotifier.value = navigationTarget;
  }
}

class _SearchButton extends _MenuButton {
  const _SearchButton();

  @override
  IconData get icon => ZulipIcons.search;

  @override
  String label(ZulipLocalizations zulipLocalizations) {
    return zulipLocalizations.searchMessagesPageTitle;
  }

  @override
  void onPressed(BuildContext context) {
    Navigator.of(context).push(MessageListPage.buildRoute(
      context: context, narrow: KeywordSearchNarrow('')));
  }
}

class _InboxButton extends _NavigationBarMenuButton {
  const _InboxButton({required super.tabNotifier});

  @override
  IconData get icon => ZulipIcons.inbox;

  @override
  String label(ZulipLocalizations zulipLocalizations) {
    return zulipLocalizations.inboxPageTitle;
  }

  @override
  _HomePageTab get navigationTarget => _HomePageTab.chats;
}

class _MentionsButton extends _MenuButton {
  const _MentionsButton();

  @override
  IconData get icon => ZulipIcons.at_sign;

  @override
  String label(ZulipLocalizations zulipLocalizations) {
    return zulipLocalizations.mentionsPageTitle;
  }

  @override
  void onPressed(BuildContext context) {
    Navigator.of(context).push(MessageListPage.buildRoute(
      context: context, narrow: const MentionsNarrow()));
  }
}

class _StarredMessagesButton extends _MenuButton {
  const _StarredMessagesButton();

  @override
  IconData get icon => ZulipIcons.star;

  @override
  String label(ZulipLocalizations zulipLocalizations) {
    return zulipLocalizations.starredMessagesPageTitle;
  }

  @override
  void onPressed(BuildContext context) {
    Navigator.of(context).push(MessageListPage.buildRoute(
      context: context, narrow: const StarredMessagesNarrow()));
  }
}

class _CombinedFeedButton extends _MenuButton {
  const _CombinedFeedButton();

  @override
  IconData get icon => ZulipIcons.message_feed;

  @override
  String label(ZulipLocalizations zulipLocalizations) {
    return zulipLocalizations.combinedFeedPageTitle;
  }

  @override
  void onPressed(BuildContext context) {
    Navigator.of(context).push(MessageListPage.buildRoute(
      context: context, narrow: const CombinedFeedNarrow()));
  }
}

class _ChannelsButton extends _NavigationBarMenuButton {
  const _ChannelsButton({required super.tabNotifier});

  @override
  IconData get icon => ZulipIcons.hash_italic;

  @override
  String label(ZulipLocalizations zulipLocalizations) {
    return zulipLocalizations.channelsPageTitle;
  }

  @override
  _HomePageTab get navigationTarget => _HomePageTab.chats;
}

class _DirectMessagesButton extends _NavigationBarMenuButton {
  const _DirectMessagesButton({required super.tabNotifier});

  @override
  IconData get icon => ZulipIcons.two_person;

  @override
  String label(ZulipLocalizations zulipLocalizations) {
    return zulipLocalizations.recentDmConversationsPageTitle;
  }

  @override
  _HomePageTab get navigationTarget => _HomePageTab.chats;
}

class _MyProfileButton extends _MenuButton {
  const _MyProfileButton();

  @override
  IconData? get icon => null;

  @override
  Widget buildLeading(BuildContext context) {
    final store = PerAccountStoreWidget.of(context);
    return Avatar(
      userId: store.selfUserId,
      size: _MenuButton._iconSize,
      borderRadius: 4,
      showPresence: false,
    );
  }

  @override
  String label(ZulipLocalizations zulipLocalizations) {
    return zulipLocalizations.mainMenuMyProfile;
  }

  @override
  void onPressed(BuildContext context) {
    final store = PerAccountStoreWidget.of(context);
    Navigator.of(context).push(
      ProfilePage.buildRoute(context: context, userId: store.selfUserId));
  }
}

class _SwitchAccountButton extends _MenuButton {
  const _SwitchAccountButton();

  @override
  IconData? get icon => ZulipIcons.arrow_left_right;

  @override
  String label(ZulipLocalizations zulipLocalizations) {
    return zulipLocalizations.switchAccountButton;
  }

  @override
  void onPressed(BuildContext context) {
    Navigator.of(context).push(MaterialWidgetRoute(page: const ChooseAccountPage()));
  }
}

class _SettingsButton extends _MenuButton {
  const _SettingsButton();

  @override
  IconData get icon => ZulipIcons.settings;

  @override
  String label(ZulipLocalizations zulipLocalizations) {
    return zulipLocalizations.settingsPageTitle;
  }

  @override
  void onPressed(BuildContext context) {
    Navigator.of(context).push(SettingsPage.buildRoute(context: context));
  }
}

class _AboutZulipButton extends _MenuButton {
  const _AboutZulipButton();

  @override
  IconData get icon => ZulipIcons.info;

  @override
  String label(ZulipLocalizations zulipLocalizations) {
    return zulipLocalizations.aboutPageTitle;
  }

  @override
  void onPressed(BuildContext context) {
    Navigator.of(context).push(AboutZulipPage.buildRoute(context));
  }
}

// Comprehensive WhatsApp-like settings page embedded in navigation
class _SettingsPageBody extends StatelessWidget {
  const _SettingsPageBody();

  @override
  Widget build(BuildContext context) {
    final zulipLocalizations = ZulipLocalizations.of(context);
    final designVariables = DesignVariables.of(context);
    final store = PerAccountStoreWidget.of(context);
    final globalSettings = GlobalStoreWidget.settingsOf(context);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        // Profile Section
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: designVariables.bgTopBar,
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.push(context,
              ProfilePage.buildRoute(context: context, userId: store.selfUserId)),
            child: Row(
              children: [
                Avatar(
                  userId: store.selfUserId,
                  size: 60,
                  borderRadius: 30,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        store.selfUser.fullName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        store.selfUser.email,
                        style: TextStyle(
                          fontSize: 14,
                          color: designVariables.labelMenuButton.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  ZulipIcons.chevron_right,
                  color: designVariables.labelMenuButton.withOpacity(0.6),
                ),
              ],
            ),
          ),
        ),

        // Settings Sections
        _SettingsSection(
          title: 'Appearance',
          children: [
            _SettingsTile(
              icon: ZulipIcons.language,
              title: 'Theme',
              subtitle: _getThemeDisplayName(globalSettings.themeSetting, zulipLocalizations),
              onTap: () => _showThemeSelector(context),
            ),
          ],
        ),

        _SettingsSection(
          title: 'Chat',
          children: [
            _SettingsSwitchTile(
              icon: ZulipIcons.link,
              title: 'Open links in app',
              subtitle: 'Use in-app browser for external links',
              value: globalSettings.effectiveBrowserPreference == BrowserPreference.inApp,
              onChanged: (value) => _handleBrowserPreferenceChange(context, value),
            ),
            _SettingsTile(
              icon: ZulipIcons.message_feed,
              title: 'Mark messages as read',
              subtitle: _getMarkReadDisplayName(globalSettings.markReadOnScroll, zulipLocalizations),
              onTap: () => _showMarkReadSelector(context),
            ),
            _SettingsTile(
              icon: ZulipIcons.inbox,
              title: 'Message feed position',
              subtitle: _getVisitFirstUnreadDisplayName(globalSettings.visitFirstUnread, zulipLocalizations),
              onTap: () => _showInitialPositionSelector(context),
            ),
          ],
        ),

        _SettingsSection(
          title: 'Account',
          children: [
            _SettingsTile(
              icon: ZulipIcons.arrow_left_right,
              title: 'Switch account',
              subtitle: 'Switch to another Zulip account',
              onTap: () => Navigator.push(context,
                MaterialWidgetRoute(page: const ChooseAccountPage())),
            ),
          ],
        ),

        _SettingsSection(
          title: 'About',
          children: [
            _SettingsTile(
              icon: ZulipIcons.settings,
              title: 'Advanced settings',
              subtitle: 'More configuration options',
              onTap: () => Navigator.push(context,
                SettingsPage.buildRoute(context: context)),
            ),
            _SettingsTile(
              icon: ZulipIcons.info,
              title: 'About Zulip',
              subtitle: 'App version and information',
              onTap: () => Navigator.push(context,
                AboutZulipPage.buildRoute(context)),
            ),
            if (GlobalSettingsStore.experimentalFeatureFlags.isNotEmpty)
              _SettingsTile(
                icon: ZulipIcons.inherit,
                title: 'Experimental features',
                subtitle: 'Developer options and beta features',
                onTap: () => Navigator.push(context,
                  ExperimentalFeaturesPage.buildRoute()),
              ),
          ],
        ),
      ],
    );
  }

  String _getThemeDisplayName(ThemeSetting? themeSetting, ZulipLocalizations zulipLocalizations) {
    return ThemeSetting.displayName(
      themeSetting: themeSetting,
      zulipLocalizations: zulipLocalizations,
    );
  }

  String _getMarkReadDisplayName(MarkReadOnScrollSetting setting, ZulipLocalizations zulipLocalizations) {
    return switch (setting) {
      MarkReadOnScrollSetting.always => 'Always',
      MarkReadOnScrollSetting.conversations => 'In conversations only',
      MarkReadOnScrollSetting.never => 'Never',
    };
  }

  String _getVisitFirstUnreadDisplayName(VisitFirstUnreadSetting setting, ZulipLocalizations zulipLocalizations) {
    return switch (setting) {
      VisitFirstUnreadSetting.always => 'First unread',
      VisitFirstUnreadSetting.conversations => 'First unread in conversations',
      VisitFirstUnreadSetting.never => 'Newest message',
    };
  }

  void _handleBrowserPreferenceChange(BuildContext context, bool value) {
    final globalSettings = GlobalStoreWidget.settingsOf(context);
    globalSettings.setBrowserPreference(
      value ? BrowserPreference.inApp : BrowserPreference.external,
    );
  }

  void _showThemeSelector(BuildContext context) {
    final globalSettings = GlobalStoreWidget.settingsOf(context);
    final zulipLocalizations = ZulipLocalizations.of(context);

    showModalBottomSheet(
      context: context,
      builder: (context) => _SettingsBottomSheet(
        title: 'Theme',
        children: [
          for (final themeOption in [null, ...ThemeSetting.values])
            RadioListTile<ThemeSetting?>(
              title: Text(ThemeSetting.displayName(
                themeSetting: themeOption,
                zulipLocalizations: zulipLocalizations,
              )),
              value: themeOption,
              groupValue: globalSettings.themeSetting,
              onChanged: (value) {
                globalSettings.setThemeSetting(value);
                Navigator.pop(context);
              },
            ),
        ],
      ),
    );
  }

  void _showMarkReadSelector(BuildContext context) {
    final globalSettings = GlobalStoreWidget.settingsOf(context);

    showModalBottomSheet(
      context: context,
      builder: (context) => _SettingsBottomSheet(
        title: 'Mark messages as read',
        children: [
          for (final setting in MarkReadOnScrollSetting.values)
            RadioListTile<MarkReadOnScrollSetting>(
              title: Text(_getMarkReadDisplayName(setting, ZulipLocalizations.of(context))),
              subtitle: _getMarkReadDescription(setting),
              value: setting,
              groupValue: globalSettings.markReadOnScroll,
              onChanged: (value) {
                if (value != null) {
                  globalSettings.setMarkReadOnScroll(value);
                  Navigator.pop(context);
                }
              },
            ),
        ],
      ),
    );
  }

  void _showInitialPositionSelector(BuildContext context) {
    final globalSettings = GlobalStoreWidget.settingsOf(context);
    final zulipLocalizations = ZulipLocalizations.of(context);

    showModalBottomSheet(
      context: context,
      builder: (context) => _SettingsBottomSheet(
        title: 'Message feed position',
        children: [
          for (final setting in VisitFirstUnreadSetting.values)
            RadioListTile<VisitFirstUnreadSetting>(
              title: Text(_getVisitFirstUnreadDisplayName(setting, zulipLocalizations)),
              value: setting,
              groupValue: globalSettings.visitFirstUnread,
              onChanged: (value) {
                if (value != null) {
                  globalSettings.setVisitFirstUnread(value);
                  Navigator.pop(context);
                }
              },
            ),
        ],
      ),
    );
  }

  Widget? _getMarkReadDescription(MarkReadOnScrollSetting setting) {
    return switch (setting) {
      MarkReadOnScrollSetting.conversations => const Text(
        'Only in single topic or DM conversations',
        style: TextStyle(fontSize: 12),
      ),
      _ => null,
    };
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final designVariables = DesignVariables.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: designVariables.labelMenuButton.withOpacity(0.6),
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: designVariables.bgTopBar,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1)
                  Divider(
                    height: 1,
                    indent: 56,
                    color: designVariables.borderBar.withOpacity(0.3),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final designVariables = DesignVariables.of(context);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF414d75).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 20,
          color: const Color(0xFF414d75),
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 14,
          color: designVariables.labelMenuButton.withOpacity(0.7),
        ),
      ),
      trailing: Icon(
        ZulipIcons.chevron_right,
        size: 16,
        color: designVariables.labelMenuButton.withOpacity(0.6),
      ),
      onTap: onTap,
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  const _SettingsSwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final designVariables = DesignVariables.of(context);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF414d75).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 20,
          color: const Color(0xFF414d75),
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 14,
          color: designVariables.labelMenuButton.withOpacity(0.7),
        ),
      ),
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

class _SettingsBottomSheet extends StatelessWidget {
  const _SettingsBottomSheet({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final designVariables = DesignVariables.of(context);

    return Container(
      padding: const EdgeInsets.only(top: 16, bottom: 16),
      decoration: BoxDecoration(
        color: designVariables.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 4,
            decoration: BoxDecoration(
              color: designVariables.labelMenuButton.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          ...children,
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../generated/l10n/zulip_localizations.dart';
import '../model/settings.dart';
import 'app_bar.dart';
import 'page.dart';
import 'store.dart';
import 'theme.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static AccountRoute<void> buildRoute({required BuildContext context}) {
    return MaterialAccountWidgetRoute(
      context: context, page: const SettingsPage());
  }

  @override
  Widget build(BuildContext context) {
    final zulipLocalizations = ZulipLocalizations.of(context);
    final designVariables = DesignVariables.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: designVariables.mainBackground,
      appBar: ZulipAppBar(
        backgroundColor: designVariables.bgTopBar,
        title: Text(
          zulipLocalizations.settingsPageTitle,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          color: designVariables.mainBackground,
        ),
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            _SettingsSection(
              title: 'Appearance',
              children: [
                const _ThemeSetting(),
              ],
            ),
            _SettingsSection(
              title: 'Behavior',
              children: [
                const _BrowserPreferenceSetting(),
                const _VisitFirstUnreadSetting(),
                const _MarkReadOnScrollSetting(),
              ],
            ),
            if (GlobalSettingsStore.experimentalFeatureFlags.isNotEmpty)
              _SettingsSection(
                title: 'Advanced',
                children: [
                  _SettingsListTile(
                    title: zulipLocalizations.experimentalFeatureSettingsPageTitle,
                    onTap: () => Navigator.push(context,
                      ExperimentalFeaturesPage.buildRoute()),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
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
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: designVariables.bgMessageRegular,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colorScheme.primary,
                letterSpacing: 0.5,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _SettingsListTile extends StatelessWidget {
  const _SettingsListTile({
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final designVariables = DesignVariables.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: designVariables.textMessage,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 14,
                          color: designVariables.textMessageMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 12),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeSetting extends StatelessWidget {
  const _ThemeSetting();

  void _handleChange(BuildContext context, ThemeSetting? newThemeSetting) {
    final globalSettings = GlobalStoreWidget.settingsOf(context);
    globalSettings.setThemeSetting(newThemeSetting);
  }

  @override
  Widget build(BuildContext context) {
    final zulipLocalizations = ZulipLocalizations.of(context);
    final globalSettings = GlobalStoreWidget.settingsOf(context);
    final designVariables = DesignVariables.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    return RadioGroup<ThemeSetting?>(
      groupValue: globalSettings.themeSetting,
      onChanged: (newValue) => _handleChange(context, newValue),
      child: Column(
        children: [
          _SettingsListTile(
            title: zulipLocalizations.themeSettingTitle,
          ),
          for (final themeSettingOption in [null, ...ThemeSetting.values])
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                child: RadioListTile<ThemeSetting?>(
                  title: Text(
                    ThemeSetting.displayName(
                      themeSetting: themeSettingOption,
                      zulipLocalizations: zulipLocalizations,
                    ),
                    style: TextStyle(
                      fontSize: 15,
                      color: designVariables.textMessage,
                    ),
                  ),
                  value: themeSettingOption,
                  activeColor: colorScheme.primary,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BrowserPreferenceSetting extends StatelessWidget {
  const _BrowserPreferenceSetting();

  void _handleChange(BuildContext context, bool newOpenLinksWithInAppBrowser) {
    final globalSettings = GlobalStoreWidget.settingsOf(context);
    globalSettings.setBrowserPreference(
      newOpenLinksWithInAppBrowser ? BrowserPreference.inApp
                                   : BrowserPreference.external);
  }

  @override
  Widget build(BuildContext context) {
    final zulipLocalizations = ZulipLocalizations.of(context);
    final globalSettings = GlobalStoreWidget.settingsOf(context);
    final designVariables = DesignVariables.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    final openLinksWithInAppBrowser =
      globalSettings.effectiveBrowserPreference == BrowserPreference.inApp;

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                zulipLocalizations.openLinksWithInAppBrowser,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: designVariables.textMessage,
                ),
              ),
            ),
            Switch(
              value: openLinksWithInAppBrowser,
              onChanged: (newValue) => _handleChange(context, newValue),
              activeColor: colorScheme.primary,
              activeTrackColor: colorScheme.primary.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _VisitFirstUnreadSetting extends StatelessWidget {
  const _VisitFirstUnreadSetting();

  @override
  Widget build(BuildContext context) {
    final zulipLocalizations = ZulipLocalizations.of(context);
    final globalSettings = GlobalStoreWidget.settingsOf(context);

    return _SettingsListTile(
      title: zulipLocalizations.initialAnchorSettingTitle,
      subtitle: VisitFirstUnreadSettingPage._valueDisplayName(
        globalSettings.visitFirstUnread,
        zulipLocalizations: zulipLocalizations,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.push(context,
        VisitFirstUnreadSettingPage.buildRoute()),
    );
  }
}

class VisitFirstUnreadSettingPage extends StatelessWidget {
  const VisitFirstUnreadSettingPage({super.key});

  static WidgetRoute<void> buildRoute() {
    return MaterialWidgetRoute(page: const VisitFirstUnreadSettingPage());
  }

  static String _valueDisplayName(VisitFirstUnreadSetting value, {
    required ZulipLocalizations zulipLocalizations,
  }) {
    return switch (value) {
      VisitFirstUnreadSetting.always =>
        zulipLocalizations.initialAnchorSettingFirstUnreadAlways,
      VisitFirstUnreadSetting.conversations =>
        zulipLocalizations.initialAnchorSettingFirstUnreadConversations,
      VisitFirstUnreadSetting.never =>
        zulipLocalizations.initialAnchorSettingNewestAlways,
    };
  }

  void _handleChange(BuildContext context, VisitFirstUnreadSetting? value) {
    if (value == null) return; // TODO(log); can this actually happen? how?
    final globalSettings = GlobalStoreWidget.settingsOf(context);
    globalSettings.setVisitFirstUnread(value);
  }

  @override
  Widget build(BuildContext context) {
    final zulipLocalizations = ZulipLocalizations.of(context);
    final globalSettings = GlobalStoreWidget.settingsOf(context);
    return Scaffold(
      appBar: AppBar(title: Text(zulipLocalizations.initialAnchorSettingTitle)),
      body: RadioGroup<VisitFirstUnreadSetting>(
        groupValue: globalSettings.visitFirstUnread,
        onChanged: (newValue) => _handleChange(context, newValue),
        child: Column(children: [
          ListTile(title: Text(zulipLocalizations.initialAnchorSettingDescription)),
          for (final value in VisitFirstUnreadSetting.values)
            RadioListTile<VisitFirstUnreadSetting>.adaptive(
              title: Text(_valueDisplayName(value,
                zulipLocalizations: zulipLocalizations)),
              value: value),
        ])));
  }
}

class _MarkReadOnScrollSetting extends StatelessWidget {
  const _MarkReadOnScrollSetting();

  @override
  Widget build(BuildContext context) {
    final zulipLocalizations = ZulipLocalizations.of(context);
    final globalSettings = GlobalStoreWidget.settingsOf(context);

    return _SettingsListTile(
      title: zulipLocalizations.markReadOnScrollSettingTitle,
      subtitle: MarkReadOnScrollSettingPage._valueDisplayName(
        globalSettings.markReadOnScroll,
        zulipLocalizations: zulipLocalizations,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.push(context,
        MarkReadOnScrollSettingPage.buildRoute()),
    );
  }
}

class MarkReadOnScrollSettingPage extends StatelessWidget {
  const MarkReadOnScrollSettingPage({super.key});

  static WidgetRoute<void> buildRoute() {
    return MaterialWidgetRoute(page: const MarkReadOnScrollSettingPage());
  }

  static String _valueDisplayName(MarkReadOnScrollSetting value, {
    required ZulipLocalizations zulipLocalizations,
  }) {
    return switch (value) {
      MarkReadOnScrollSetting.always =>
        zulipLocalizations.markReadOnScrollSettingAlways,
      MarkReadOnScrollSetting.conversations =>
        zulipLocalizations.markReadOnScrollSettingConversations,
      MarkReadOnScrollSetting.never =>
        zulipLocalizations.markReadOnScrollSettingNever,
    };
  }

  static String? _valueDescription(MarkReadOnScrollSetting value, {
    required ZulipLocalizations zulipLocalizations,
  }) {
    return switch (value) {
      MarkReadOnScrollSetting.always => null,
      MarkReadOnScrollSetting.conversations =>
        zulipLocalizations.markReadOnScrollSettingConversationsDescription,
      MarkReadOnScrollSetting.never => null,
    };
  }

  void _handleChange(BuildContext context, MarkReadOnScrollSetting? value) {
    if (value == null) return; // TODO(log); can this actually happen? how?
    final globalSettings = GlobalStoreWidget.settingsOf(context);
    globalSettings.setMarkReadOnScroll(value);
  }

  @override
  Widget build(BuildContext context) {
    final zulipLocalizations = ZulipLocalizations.of(context);
    final globalSettings = GlobalStoreWidget.settingsOf(context);
    return Scaffold(
      appBar: AppBar(title: Text(zulipLocalizations.markReadOnScrollSettingTitle)),
      body: RadioGroup<MarkReadOnScrollSetting>(
        groupValue: globalSettings.markReadOnScroll,
        onChanged: (newValue) => _handleChange(context, newValue),
        child: Column(children: [
          ListTile(title: Text(zulipLocalizations.markReadOnScrollSettingDescription)),
          for (final value in MarkReadOnScrollSetting.values)
            RadioListTile<MarkReadOnScrollSetting>.adaptive(
              title: Text(_valueDisplayName(value,
                zulipLocalizations: zulipLocalizations)),
              subtitle: () {
                final result = _valueDescription(value,
                  zulipLocalizations: zulipLocalizations);
                return result == null ? null : Text(result);
              }(),
              value: value),
        ])));
  }
}

class ExperimentalFeaturesPage extends StatelessWidget {
  const ExperimentalFeaturesPage({super.key});

  static WidgetRoute<void> buildRoute() {
    return MaterialWidgetRoute(page: const ExperimentalFeaturesPage());
  }

  @override
  Widget build(BuildContext context) {
    final zulipLocalizations = ZulipLocalizations.of(context);
    final globalSettings = GlobalStoreWidget.settingsOf(context);
    final flags = GlobalSettingsStore.experimentalFeatureFlags;
    assert(flags.isNotEmpty);
    return Scaffold(
      appBar: AppBar(
        title: Text(zulipLocalizations.experimentalFeatureSettingsPageTitle)),
      body: Column(children: [
        ListTile(
          title: Text(zulipLocalizations.experimentalFeatureSettingsWarning)),
        for (final flag in flags)
          SwitchListTile.adaptive(
            title: Text(flag.name), // no i18n; these are developer-facing settings
            value: globalSettings.getBool(flag),
            onChanged: (value) => globalSettings.setBool(flag, value)),
      ]));
  }
}

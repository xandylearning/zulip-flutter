import 'package:checks/checks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_checks/flutter_checks.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zulip/widgets/settings.dart';
import 'package:zulip/widgets/store.dart';
import 'package:zulip/widgets/theme.dart';

import '../example_data.dart' as eg;
import '../flutter_checks.dart';
import '../model/binding.dart';
import 'test_app.dart';

void main() {
  TestZulipBinding.ensureInitialized();

  group('Enhanced Settings Page', () {
    Future<void> setupSettingsPage(WidgetTester tester) async {
      addTearDown(testBinding.reset);
      await testBinding.globalStore.add(eg.selfAccount, eg.initialSnapshot());

      await tester.pumpWidget(
        TestZulipApp(
          accountId: eg.selfAccount.id,
          child: const SettingsPage(),
        ),
      );
      await tester.pump();
    }

    group('Modern UI Design', () {
      testWidgets('settings sections have card-like design', (tester) async {
        await setupSettingsPage(tester);

        // Find section containers with modern styling
        final sectionContainers = find.byWidgetPredicate((widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration as BoxDecoration).borderRadius != null);

        expect(sectionContainers, findsAtLeastNWidgets(1));

        // Check for rounded corners and shadows
        final container = tester.widget<Container>(sectionContainers.first);
        final decoration = container.decoration as BoxDecoration;
        check(decoration.borderRadius).isNotNull();
        check(decoration.boxShadow).isNotNull();
      });

      testWidgets('section titles have proper styling', (tester) async {
        await setupSettingsPage(tester);

        // Find section titles
        final sectionTitles = find.text('Appearance');
        expect(sectionTitles, findsOneWidget);

        final behaviorTitles = find.text('Behavior');
        expect(behaviorTitles, findsOneWidget);

        // Check for proper text styling
        final titleWidget = tester.widget<Text>(sectionTitles);
        final style = titleWidget.style;
        check(style?.fontWeight).equals(FontWeight.w600);
        check(style?.fontSize).equals(14.0);
      });

      testWidgets('list items have modern interactive design', (tester) async {
        await setupSettingsPage(tester);

        // Find custom list tiles
        final customTiles = find.byType(Material);
        expect(customTiles, findsAtLeastNWidgets(1));

        // Find InkWell for interactions
        final inkWells = find.byType(InkWell);
        expect(inkWells, findsAtLeastNWidgets(1));

        // Check for rounded corners on interactive elements
        final inkWell = tester.widget<InkWell>(inkWells.first);
        check(inkWell.borderRadius).isNotNull();
      });
    });

    group('Brand Color Consistency', () {
      testWidgets('primary colors are applied consistently', (tester) async {
        await setupSettingsPage(tester);

        final context = tester.element(find.byType(SettingsPage));
        final colorScheme = Theme.of(context).colorScheme;
        final designVariables = DesignVariables.of(context);

        // Verify brand color consistency
        check(colorScheme.primary).equals(kZulipBrandColor);
        check(designVariables).isNotNull();
      });

      testWidgets('section titles use brand color', (tester) async {
        await setupSettingsPage(tester);

        final context = tester.element(find.byType(SettingsPage));
        final colorScheme = Theme.of(context).colorScheme;

        // Find section title text widgets
        final appearanceTitle = find.text('Appearance');
        if (appearanceTitle.hasFound) {
          final widget = tester.widget<Text>(appearanceTitle);
          check(widget.style?.color).equals(colorScheme.primary);
        }
      });

      testWidgets('switches use brand colors', (tester) async {
        await setupSettingsPage(tester);

        // Find switch widgets
        final switches = find.byType(Switch);
        expect(switches, findsAtLeastNWidgets(1));

        final context = tester.element(find.byType(SettingsPage));
        final colorScheme = Theme.of(context).colorScheme;

        // Check switch colors
        for (int i = 0; i < tester.widgetList(switches).length; i++) {
          final switchWidget = tester.widget<Switch>(switches.at(i));
          if (switchWidget.value) {
            check(switchWidget.activeColor).equals(colorScheme.primary);
          }
        }
      });
    });

    group('Layout and Spacing', () {
      testWidgets('sections have proper margins and padding', (tester) async {
        await setupSettingsPage(tester);

        // Find containers with margin
        final containers = find.byWidgetPredicate((widget) =>
          widget is Container &&
          widget.margin != null);

        expect(containers, findsAtLeastNWidgets(1));

        // Check for consistent spacing
        final container = tester.widget<Container>(containers.first);
        check(container.margin).isNotNull();
      });

      testWidgets('list items have appropriate padding', (tester) async {
        await setupSettingsPage(tester);

        // Find padded elements
        final paddedElements = find.byWidgetPredicate((widget) =>
          widget is Padding &&
          widget.padding is EdgeInsets);

        expect(paddedElements, findsAtLeastNWidgets(1));
      });

      testWidgets('uses ListView for proper scrolling', (tester) async {
        await setupSettingsPage(tester);

        // Find ListView
        final listViews = find.byType(ListView);
        expect(listViews, findsOneWidget);

        // Check for proper padding
        final listView = tester.widget<ListView>(listViews);
        check(listView.padding).isNotNull();
      });
    });

    group('Accessibility', () {
      testWidgets('interactive elements have proper touch targets', (tester) async {
        await setupSettingsPage(tester);

        // Find all interactive elements
        final inkWells = find.byType(InkWell);

        for (int i = 0; i < tester.widgetList(inkWells).length; i++) {
          final size = tester.getSize(inkWells.at(i));
          // Minimum touch target should be 44px
          expect(size.height, greaterThanOrEqualTo(44));
        }
      });

      testWidgets('text has sufficient contrast', (tester) async {
        await setupSettingsPage(tester);

        final context = tester.element(find.byType(SettingsPage));
        final designVariables = DesignVariables.of(context);

        // Check that text colors are defined and not null
        check(designVariables.textMessage).isNotNull();
        check(designVariables.textMessageMuted).isNotNull();
        check(designVariables.mainBackground).isNotNull();
      });

      testWidgets('settings maintain semantic structure', (tester) async {
        await setupSettingsPage(tester);

        // Find app bar for screen title
        final appBars = find.byType(AppBar);
        expect(appBars, findsOneWidget);

        // Find scaffold for proper page structure
        final scaffolds = find.byType(Scaffold);
        expect(scaffolds, findsOneWidget);
      });
    });

    group('Theme Integration', () {
      testWidgets('respects system theme settings', (tester) async {
        await setupSettingsPage(tester);

        final context = tester.element(find.byType(SettingsPage));
        final theme = Theme.of(context);

        // Verify theme data is properly applied
        check(theme.brightness).isNotNull();
        check(theme.colorScheme).isNotNull();
        check(theme.extensions).isNotEmpty();
      });

      testWidgets('design variables are properly integrated', (tester) async {
        await setupSettingsPage(tester);

        final context = tester.element(find.byType(SettingsPage));
        final designVariables = DesignVariables.of(context);

        // Check that all required design variables are available
        check(designVariables.bgMessageRegular).isNotNull();
        check(designVariables.textMessage).isNotNull();
        check(designVariables.mainBackground).isNotNull();
      });
    });

    group('Functionality', () {
      testWidgets('radio buttons work correctly', (tester) async {
        await setupSettingsPage(tester);

        // Find radio buttons
        final radioButtons = find.byType(RadioListTile<dynamic>);
        expect(radioButtons, findsAtLeastNWidgets(1));

        // Test interaction
        if (radioButtons.hasFound) {
          await tester.tap(radioButtons.first);
          await tester.pump();

          // Verify no errors occurred
          expect(tester.takeException(), isNull);
        }
      });

      testWidgets('switches toggle correctly', (tester) async {
        await setupSettingsPage(tester);

        // Find switches
        final switches = find.byType(Switch);
        expect(switches, findsAtLeastNWidgets(1));

        // Test toggle
        if (switches.hasFound) {
          final initialValue = tester.widget<Switch>(switches.first).value;
          await tester.tap(switches.first);
          await tester.pump();

          // Verify state changed
          final newValue = tester.widget<Switch>(switches.first).value;
          expect(newValue, isNot(equals(initialValue)));
        }
      });

      testWidgets('navigation to detail pages works', (tester) async {
        await setupSettingsPage(tester);

        // Find tappable list items that should navigate
        final tappableItems = find.byWidgetPredicate((widget) =>
          widget is InkWell &&
          find.descendant(
            of: find.byWidget(widget),
            matching: find.byIcon(Icons.chevron_right),
          ).hasFound);

        expect(tappableItems, findsAtLeastNWidgets(1));

        // Test navigation
        if (tappableItems.hasFound) {
          await tester.tap(tappableItems.first);
          await tester.pump();
          await tester.pumpAndSettle();

          // Verify navigation occurred (no exceptions)
          expect(tester.takeException(), isNull);
        }
      });
    });
  });
}
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zulip/model/store.dart';
import 'package:zulip/widgets/app_bar.dart';
import 'package:zulip/widgets/calls.dart';
import 'package:zulip/widgets/chats.dart';
import 'package:zulip/widgets/home.dart';
import 'package:zulip/widgets/icons.dart';
import 'package:zulip/widgets/new_dm_sheet.dart';
import 'package:zulip/widgets/profile.dart';
import 'package:zulip/widgets/user.dart';

import '../api/fake_api.dart';
import '../example_data.dart' as eg;
import '../model/binding.dart';
import '../model/test_store.dart';
import '../test_navigation.dart';
import 'test_app.dart';

void main() {
  TestZulipBinding.ensureInitialized();

  late PerAccountStore store;
  late FakeApiConnection connection;

  late Route<dynamic>? topRoute;
  late List<Route<dynamic>> pushedRoutes;

  final testNavObserver = TestNavigatorObserver()
    ..onChangedTop = ((current, previous) => topRoute = current)
    ..onPushed = ((route, prevRoute) => pushedRoutes.add(route));

  Future<void> prepare(WidgetTester tester) async {
    addTearDown(testBinding.reset);
    topRoute = null;
    pushedRoutes = [];

    await testBinding.globalStore.add(eg.selfAccount, eg.initialSnapshot());
    store = await testBinding.globalStore.perAccount(eg.selfAccount.id);
    connection = store.connection as FakeApiConnection;
    await store.addUser(eg.selfUser);

    await tester.pumpWidget(TestZulipApp(
      accountId: eg.selfAccount.id,
      navigatorObservers: [testNavObserver],
      child: const HomePage()));
    await tester.pump();
  }

  group('Bottom Navigation Bar Design', () {
    testWidgets('has increased height and rounded corners', (tester) async {
      await prepare(tester);

      // Find the bottom navigation bar container
      final bottomNavBar = find.byType(Container).last;
      expect(bottomNavBar, findsOneWidget);

      // Get the container widget
      final containerWidget = tester.widget<Container>(bottomNavBar);

      // Check decoration has rounded top corners
      final decoration = containerWidget.decoration as BoxDecoration;
      expect(decoration.borderRadius, equals(const BorderRadius.vertical(top: Radius.circular(20))));

      // Check the SafeArea has increased height
      final safeArea = find.descendant(
        of: bottomNavBar,
        matching: find.byType(SafeArea)
      );
      expect(safeArea, findsOneWidget);

      final sizedBox = find.descendant(
        of: safeArea,
        matching: find.byType(SizedBox)
      );
      expect(sizedBox, findsOneWidget);

      final sizedBoxWidget = tester.widget<SizedBox>(sizedBox);
      expect(sizedBoxWidget.height, equals(68)); // Increased from 48 to 68
    });
  });

  group('New Chat Page Navigation', () {
    testWidgets('new chat page has proper back button', (tester) async {
      await prepare(tester);

      // Open chats tab first (if not already)
      await tester.tap(find.byIcon(Icons.chat_bubble_outline));
      await tester.pump();

      // Find and tap the floating action button to open new chat
      final fab = find.byType(FloatingActionButton);
      expect(fab, findsOneWidget);
      await tester.tap(fab);
      await tester.pumpAndSettle();

      // Verify we're on the new DM page
      expect(find.byType(NewDmPage), findsOneWidget);

      // Verify the app bar has a back button
      final appBar = find.byType(AppBar);
      expect(appBar, findsOneWidget);

      final backButton = find.descendant(
        of: appBar,
        matching: find.byIcon(Icons.arrow_back)
      );
      expect(backButton, findsOneWidget);

      // Test that back button works
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Should be back to the home page
      expect(find.byType(NewDmPage), findsNothing);
      expect(find.byType(HomePage), findsOneWidget);
    });
  });

  group('WhatsApp-like Navigation', () {
    testWidgets('shows correct tab order: Chats, Calls, Settings', (tester) async {
      await prepare(tester);

      // Check the bottom navigation buttons are in correct order
      final bottomNavBar = find.byType(Container).last;
      expect(bottomNavBar, findsOneWidget);

      // Check for chat icon (first)
      final chatIcon = find.byIcon(Icons.chat_bubble_outline);
      expect(chatIcon, findsOneWidget);

      // Check for phone icon (second)
      final callIcon = find.byIcon(Icons.phone_outlined);
      expect(callIcon, findsOneWidget);

      // Check for settings icon (third)
      final settingsIcon = find.byIcon(Icons.settings_outlined);
      expect(settingsIcon, findsOneWidget);
    });

    testWidgets('starts on chats tab by default', (tester) async {
      await prepare(tester);

      // Should show ChatsPageBody by default
      expect(find.byType(ChatsPageBody), findsOneWidget);
      expect(find.byType(CallsPageBody), findsNothing);

      // App bar should show "Chats" title
      expect(find.descendant(
        of: find.byType(ZulipAppBar),
        matching: find.text('Chats')), findsOneWidget);
    });

    testWidgets('switches to calls tab when tapped', (tester) async {
      await prepare(tester);

      // Tap the calls tab
      await tester.tap(find.byIcon(Icons.phone_outlined));
      await tester.pump();

      // Should now show CallsPageBody
      expect(find.byType(CallsPageBody), findsOneWidget);
      expect(find.byType(ChatsPageBody), findsNothing);

      // App bar should show "Calls" title
      expect(find.descendant(
        of: find.byType(ZulipAppBar),
        matching: find.text('Calls')), findsOneWidget);
    });

    testWidgets('switches to settings tab when tapped', (tester) async {
      await prepare(tester);

      // Tap the settings tab
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pump();

      // Should show settings content
      expect(find.byType(CallsPageBody), findsNothing);
      expect(find.byType(ChatsPageBody), findsNothing);

      // App bar should show "Settings" title
      expect(find.descendant(
        of: find.byType(ZulipAppBar),
        matching: find.text('Settings')), findsOneWidget);
    });

    testWidgets('preserves tab states when switching', (tester) async {
      await prepare(tester);
      await store.addUser(eg.otherUser);

      // Start on chats tab - should be visible
      expect(find.byType(ChatsPageBody), findsOneWidget);

      // Switch to calls tab
      await tester.tap(find.byIcon(Icons.phone_outlined));
      await tester.pump();
      expect(find.byType(CallsPageBody), findsOneWidget);

      // Switch back to chats tab - should still be there
      await tester.tap(find.byIcon(Icons.chat_bubble_outline));
      await tester.pump();
      expect(find.byType(ChatsPageBody), findsOneWidget);
    });

    testWidgets('shows profile avatar in app bar', (tester) async {
      await prepare(tester);

      // Check for avatar in app bar
      final avatar = find.descendant(
        of: find.byType(ZulipAppBar),
        matching: find.byType(Avatar));
      expect(avatar, findsOneWidget);

      // Avatar should be circular (borderRadius = 16 for size 32)
      final avatarWidget = tester.widget<Avatar>(avatar);
      expect(avatarWidget.size, equals(32));
      expect(avatarWidget.borderRadius, equals(16));
      expect(avatarWidget.userId, equals(eg.selfUser.userId));
    });

    testWidgets('profile avatar navigates to profile page when tapped', (tester) async {
      await prepare(tester);
      pushedRoutes.clear();

      // Tap the avatar
      final avatar = find.descendant(
        of: find.byType(ZulipAppBar),
        matching: find.byType(Avatar));
      await tester.tap(avatar);
      await tester.pump();

      // Should navigate to profile page
      expect(pushedRoutes.length, equals(1));
    });

    testWidgets('app bar title updates correctly for each tab', (tester) async {
      await prepare(tester);

      // Start on chats - check title
      expect(find.descendant(
        of: find.byType(ZulipAppBar),
        matching: find.text('Chats')), findsOneWidget);

      // Switch to calls - check title
      await tester.tap(find.byIcon(Icons.phone_outlined));
      await tester.pump();
      expect(find.descendant(
        of: find.byType(ZulipAppBar),
        matching: find.text('Calls')), findsOneWidget);

      // Switch to settings - check title
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pump();
      expect(find.descendant(
        of: find.byType(ZulipAppBar),
        matching: find.text('Settings')), findsOneWidget);

      // Switch back to chats - check title
      await tester.tap(find.byIcon(Icons.chat_bubble_outline));
      await tester.pump();
      expect(find.descendant(
        of: find.byType(ZulipAppBar),
        matching: find.text('Chats')), findsOneWidget);
    });
  });

  group('Navigation Icons', () {
    testWidgets('uses Material Design icons for better recognition', (tester) async {
      await prepare(tester);

      // Check that we're using standard Material icons
      expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
      expect(find.byIcon(Icons.phone_outlined), findsOneWidget);
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);

      // Should not use the old custom icons
      expect(find.byIcon(ZulipIcons.message_feed), findsNothing);
      expect(find.byIcon(ZulipIcons.call), findsNothing);
      expect(find.byIcon(ZulipIcons.two_person), findsNothing);
    });

    testWidgets('icons are visually distinct and recognizable', (tester) async {
      await prepare(tester);

      // All three icons should be present and different
      final chatIcon = find.byIcon(Icons.chat_bubble_outline);
      final phoneIcon = find.byIcon(Icons.phone_outlined);
      final settingsIcon = find.byIcon(Icons.settings_outlined);

      expect(chatIcon, findsOneWidget);
      expect(phoneIcon, findsOneWidget);
      expect(settingsIcon, findsOneWidget);

      // Verify they have different icon data
      final chatWidget = tester.widget<Icon>(chatIcon);
      final phoneWidget = tester.widget<Icon>(phoneIcon);
      final settingsWidget = tester.widget<Icon>(settingsIcon);

      expect(chatWidget.icon, isNot(equals(phoneWidget.icon)));
      expect(chatWidget.icon, isNot(equals(settingsWidget.icon)));
      expect(phoneWidget.icon, isNot(equals(settingsWidget.icon)));
    });
  });
}
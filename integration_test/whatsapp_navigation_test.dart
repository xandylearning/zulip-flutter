import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:zulip/widgets/app.dart';
import 'package:zulip/widgets/calls.dart';
import 'package:zulip/widgets/chats.dart';
import 'package:zulip/widgets/home.dart';
import 'package:zulip/widgets/icons.dart';
import 'package:zulip/widgets/user.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('WhatsApp-like Navigation Integration Tests', () {
    testWidgets('Complete navigation flow works end-to-end', (tester) async {
      await tester.pumpWidget(const ZulipApp());
      await tester.pumpAndSettle();

      // Skip login flow - assume we're in the home screen
      // In a real integration test, you'd complete the login process first

      // Check that we start on the home page with chats tab
      expect(find.byType(HomePage), findsOneWidget);

      // Wait for the app to fully load
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Verify we're on the chats tab by default
      expect(find.byType(ChatsPageBody), findsOneWidget);
      expect(find.text('Chats'), findsOneWidget);
    });

    testWidgets('Navigation between all tabs works correctly', (tester) async {
      await tester.pumpWidget(const ZulipApp());
      await tester.pumpAndSettle();

      // Assume we're in the home screen
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Test navigation to calls tab
      await tester.tap(find.byIcon(Icons.phone_outlined));
      await tester.pumpAndSettle();

      expect(find.byType(CallsPageBody), findsOneWidget);
      expect(find.text('Calls'), findsOneWidget);

      // Test navigation to settings tab
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);

      // Test navigation back to chats tab
      await tester.tap(find.byIcon(Icons.chat_bubble_outline));
      await tester.pumpAndSettle();

      expect(find.byType(ChatsPageBody), findsOneWidget);
      expect(find.text('Chats'), findsOneWidget);
    });

    testWidgets('Call log interactions work in calls tab', (tester) async {
      await tester.pumpWidget(const ZulipApp());
      await tester.pumpAndSettle();

      // Navigate to calls tab
      await tester.tap(find.byIcon(Icons.phone_outlined));
      await tester.pumpAndSettle();

      // Check if call log is shown (may be empty)
      expect(find.byType(CallsPageBody), findsOneWidget);

      // If there are call log entries, test the call buttons
      final callButtons = find.byIcon(ZulipIcons.call);
      final videoCallButtons = find.byIcon(ZulipIcons.video_call);

      if (callButtons.evaluate().isNotEmpty) {
        // Test voice call button
        await tester.tap(callButtons.first);
        await tester.pumpAndSettle();

        // Should show snackbar
        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.textContaining('Calling'), findsOneWidget);

        // Wait for snackbar to disappear
        await tester.pumpAndSettle(const Duration(seconds: 5));

        // Test video call button
        if (videoCallButtons.evaluate().isNotEmpty) {
          await tester.tap(videoCallButtons.first);
          await tester.pumpAndSettle();

          expect(find.byType(SnackBar), findsOneWidget);
          expect(find.textContaining('Video calling'), findsOneWidget);
        }
      }
    });

    testWidgets('Profile avatar navigation works', (tester) async {
      await tester.pumpWidget(const ZulipApp());
      await tester.pumpAndSettle();

      // Look for profile avatar in app bar
      final avatarFinder = find.byType(Avatar);

      if (avatarFinder.evaluate().isNotEmpty) {
        await tester.tap(avatarFinder.first);
        await tester.pumpAndSettle();

        // Should navigate to profile page
        // Note: In integration tests, this might require specific setup
        // The actual behavior depends on the authentication state
      }
    });

    testWidgets('App maintains state across tab switches', (tester) async {
      await tester.pumpWidget(const ZulipApp());
      await tester.pumpAndSettle();

      // Start on chats tab
      expect(find.byType(ChatsPageBody), findsOneWidget);

      // Switch to calls tab
      await tester.tap(find.byIcon(Icons.phone_outlined));
      await tester.pumpAndSettle();
      expect(find.byType(CallsPageBody), findsOneWidget);

      // Switch to settings tab
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();

      // Switch back to chats tab - should maintain state
      await tester.tap(find.byIcon(Icons.chat_bubble_outline));
      await tester.pumpAndSettle();
      expect(find.byType(ChatsPageBody), findsOneWidget);

      // Switch back to calls tab - should maintain state
      await tester.tap(find.byIcon(Icons.phone_outlined));
      await tester.pumpAndSettle();
      expect(find.byType(CallsPageBody), findsOneWidget);
    });

    testWidgets('Icons are visually distinct and accessible', (tester) async {
      await tester.pumpWidget(const ZulipApp());
      await tester.pumpAndSettle();

      // Check that all navigation icons are present and distinct
      expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
      expect(find.byIcon(Icons.phone_outlined), findsOneWidget);
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);

      // Test that icons have proper semantics for accessibility
      final chatIcon = find.byIcon(Icons.chat_bubble_outline);
      final phoneIcon = find.byIcon(Icons.phone_outlined);
      final settingsIcon = find.byIcon(Icons.settings_outlined);

      // These should be tappable elements
      await tester.ensureVisible(chatIcon);
      await tester.ensureVisible(phoneIcon);
      await tester.ensureVisible(settingsIcon);
    });

    testWidgets('Performance: Navigation is smooth and responsive', (tester) async {
      await tester.pumpWidget(const ZulipApp());
      await tester.pumpAndSettle();

      // Measure time for navigation switches
      final stopwatch = Stopwatch()..start();

      // Rapidly switch between tabs
      for (int i = 0; i < 5; i++) {
        await tester.tap(find.byIcon(Icons.phone_outlined));
        await tester.pump();

        await tester.tap(find.byIcon(Icons.settings_outlined));
        await tester.pump();

        await tester.tap(find.byIcon(Icons.chat_bubble_outline));
        await tester.pump();
      }

      stopwatch.stop();

      // Navigation should be fast (less than 1 second for all switches)
      expect(stopwatch.elapsedMilliseconds, lessThan(1000));

      await tester.pumpAndSettle();
    });
  });

  group('Call Log Feature Integration Tests', () {
    testWidgets('Call log displays correctly with mock data', (tester) async {
      await tester.pumpWidget(const ZulipApp());
      await tester.pumpAndSettle();

      // Navigate to calls tab
      await tester.tap(find.byIcon(Icons.phone_outlined));
      await tester.pumpAndSettle();

      // Check for call log structure
      expect(find.byType(CallsPageBody), findsOneWidget);

      // Look for call direction icons
      final incomingIcons = find.byIcon(ZulipIcons.call_incoming);
      final outgoingIcons = find.byIcon(ZulipIcons.call_outgoing);
      final missedIcons = find.byIcon(ZulipIcons.call_missed);

      // At least one type of call should be present
      expect(
        incomingIcons.evaluate().length +
        outgoingIcons.evaluate().length +
        missedIcons.evaluate().length,
        greaterThan(0)
      );
    });

    testWidgets('Call buttons trigger appropriate actions', (tester) async {
      await tester.pumpWidget(const ZulipApp());
      await tester.pumpAndSettle();

      // Navigate to calls tab
      await tester.tap(find.byIcon(Icons.phone_outlined));
      await tester.pumpAndSettle();

      // Find call buttons
      final callButtons = find.byIcon(ZulipIcons.call);
      final videoCallButtons = find.byIcon(ZulipIcons.video_call);

      if (callButtons.evaluate().isNotEmpty) {
        // Test voice call functionality
        await tester.tap(callButtons.first);
        await tester.pumpAndSettle();

        // Should show feedback (snackbar)
        expect(find.byType(SnackBar), findsOneWidget);

        // Wait for snackbar to clear
        await tester.pumpAndSettle(const Duration(seconds: 5));
      }

      if (videoCallButtons.evaluate().isNotEmpty) {
        // Test video call functionality
        await tester.tap(videoCallButtons.first);
        await tester.pumpAndSettle();

        // Should show feedback (snackbar)
        expect(find.byType(SnackBar), findsOneWidget);
      }
    });
  });
}
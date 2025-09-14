import 'package:checks/checks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_checks/flutter_checks.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zulip/api/model/model.dart';
import 'package:zulip/model/store.dart';
import 'package:zulip/widgets/calls.dart';
import 'package:zulip/widgets/store.dart';

import '../example_data.dart' as eg;
import '../flutter_checks.dart';
import '../model/binding.dart';
import '../test_navigation.dart';
import 'test_app.dart';

void main() {
  TestZulipBinding.ensureInitialized();
  group('CallsPageBody', () {
    late PerAccountStore store;

    Future<void> setupPage(WidgetTester tester) async {
      addTearDown(testBinding.reset);
      await testBinding.globalStore.add(eg.selfAccount, eg.initialSnapshot());
      store = await testBinding.globalStore.perAccount(eg.selfAccount.id);

      // Add route observer to track navigation
      final testNavObserver = TestNavigatorObserver();
      await tester.pumpWidget(
        TestZulipApp(
          accountId: eg.selfAccount.id,
          navigatorObservers: [testNavObserver],
          child: const CallsPageBody(),
        ),
      );
      await tester.pump();
    }

    testWidgets('displays call log with proper icons', (tester) async {
      await setupPage(tester);

      // Check that call log items are displayed
      check(find.byType(ListTile)).findsAtLeast(1);

      // Check for better Material Design icons in call buttons
      check(find.byIcon(Icons.phone)).findsAtLeast(1);
      check(find.byIcon(Icons.videocam)).findsAtLeast(1);

      // Check that call direction icons use proper Material icons
      check(find.byIcon(Icons.call_received)).findsAtLeast(1);
    });

    testWidgets('call and video call buttons work correctly', (tester) async {
      await setupPage(tester);

      // Tap the first call button
      await tester.tap(find.byIcon(Icons.phone).first);
      await tester.pump();

      // Check that snackbar is shown
      check(find.byType(SnackBar)).findsOne();
      check(find.textContaining('Calling')).findsOne();

      // Wait for snackbar to disappear
      await tester.pump(const Duration(seconds: 5));

      // Tap the first video call button
      await tester.tap(find.byIcon(Icons.videocam).first);
      await tester.pump();

      // Check that video call snackbar is shown
      check(find.byType(SnackBar)).findsOne();
      check(find.textContaining('Video calling')).findsOne();
    });

    testWidgets('call direction colors are correct', (tester) async {
      await setupPage(tester);

      // Find call direction icons and verify they have appropriate colors
      final incomingCallIcon = find.byIcon(Icons.call_received).first;
      check(incomingCallIcon).findsOne();

      // The actual color verification would need to inspect the Icon widget's color property
      final iconWidget = tester.widget<Icon>(incomingCallIcon);
      // Green for incoming calls (WhatsApp style)
      check(iconWidget.color).equals(const Color(0xFF25D366));
    });

    testWidgets('shows empty state when no users', (tester) async {
      await setupPage(tester);

      check(find.text('No call history yet')).findsOne();
    });
  });

  group('CallLogEntry', () {
    testWidgets('displays correct call type icons', (tester) async {
      addTearDown(testBinding.reset);
      await testBinding.globalStore.add(eg.selfAccount, eg.initialSnapshot());

      await tester.pumpWidget(
        TestZulipApp(
          accountId: eg.selfAccount.id,
          child: const CallsPageBody(),
        ),
      );
      await tester.pump();

      // Verify that different call types have different icons
      // The mock data creates various call types, so we should see different icons
      check(find.byIcon(Icons.call_received)).findsAtLeast(1); // incoming/missed
      check(find.byIcon(Icons.call_made)).findsAtLeast(1);     // outgoing
    });
  });
}
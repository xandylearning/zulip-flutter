import 'package:checks/checks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zulip/api/model/model.dart';
import 'package:zulip/model/store.dart';
import 'package:zulip/widgets/chats.dart';
import 'package:zulip/widgets/new_dm_sheet.dart';
import 'package:zulip/widgets/store.dart';

import '../example_data.dart' as eg;
import '../flutter_checks.dart';
import '../model/binding.dart';
import '../test_navigation.dart';
import 'test_app.dart';

void main() {
  TestZulipBinding.ensureInitialized();
  group('ChatsPageBody', () {
    late PerAccountStore store;

    Future<void> setupPage(WidgetTester tester, {
      List<Message>? dmMessages,
    }) async {
      addTearDown(testBinding.reset);
      await testBinding.globalStore.add(eg.selfAccount, eg.initialSnapshot());
      store = await testBinding.globalStore.perAccount(eg.selfAccount.id);

      if (dmMessages != null) {
        for (final message in dmMessages) {
          store.addMessage(message);
        }
      }

      // Add route observer to track navigation
      final testNavObserver = TestNavigatorObserver();
      await tester.pumpWidget(
        TestZulipApp(
          accountId: eg.selfAccount.id,
          navigatorObservers: [testNavObserver],
          child: const ChatsPageBody(),
        ),
      );
      await tester.pump();
    }

    testWidgets('displays empty state when no conversations', (tester) async {
      await setupPage(tester);

      check(find.text('No conversations yet. Start a new chat!')).findsOne();
      check(find.byType(FloatingActionButton)).findsOne();
    });

    testWidgets('new chat button opens DM page navigation', (tester) async {
      await setupPage(tester);

      // Tap the new chat button
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();

      // Wait for navigation to complete
      await tester.pumpAndSettle();

      // Verify that NewDmPage is displayed
      check(find.byType(NewDmPage)).findsOne();

      // Verify page has proper app bar with title
      check(find.text('New DM')).findsOne();
      check(find.byType(AppBar)).findsOne();
    });

    testWidgets('page navigation works correctly', (tester) async {
      await setupPage(tester);

      // Tap the new chat button
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();
      await tester.pumpAndSettle();

      // Verify NewDmPage is present
      check(find.byType(NewDmPage)).findsOne();
      check(find.byType(NewDmPicker)).findsOne();

      // Try to go back using app bar back button
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pump();
      await tester.pumpAndSettle();

      // Verify we're back to chats page
      check(find.byType(NewDmPage)).findsNothing();
      check(find.byType(ChatsPageBody)).findsOne();
    });

    testWidgets('displays DM conversations when present', (tester) async {
      final dmMessage = eg.dmMessage(from: eg.otherUser, to: [eg.selfUser]);

      await setupPage(tester, dmMessages: [dmMessage]);

      // Should show the conversation instead of empty state
      check(find.text('No conversations yet. Start a new chat!')).findsNothing();

      // Should show the DM conversation
      check(find.text(eg.otherUser.fullName)).findsOne();
    });

    testWidgets('floating action button styling is correct', (tester) async {
      await setupPage(tester);

      final fab = tester.widget<FloatingActionButton>(find.byType(FloatingActionButton));

      // Check WhatsApp green color
      check(fab.backgroundColor).equals(const Color(0xFF25D366));
      check(fab.foregroundColor).equals(Colors.white);
    });
  });

  group('PerAccountStoreWidget access in pages', () {
    testWidgets('PerAccountStoreWidget is properly provided to page content', (tester) async {
      addTearDown(testBinding.reset);
      await testBinding.globalStore.add(eg.selfAccount, eg.initialSnapshot());

      await tester.pumpWidget(
        TestZulipApp(
          accountId: eg.selfAccount.id,
          child: const ChatsPageBody(),
        ),
      );
      await tester.pump();

      // Open the page
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pump();
      await tester.pumpAndSettle();

      // Verify the store is accessible within the page
      final context = tester.element(find.byType(NewDmPicker));

      // This should not throw an error
      expect(() => PerAccountStoreWidget.of(context), returnsNormally);

      final store = PerAccountStoreWidget.of(context);
      check(store.selfUserId).equals(eg.selfUser.userId);
    });
  });
}
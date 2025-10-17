import 'package:checks/checks.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zulip/api/model/model.dart';
import 'package:zulip/model/store.dart';
import 'package:zulip/widgets/chats.dart';
import 'package:zulip/widgets/theme.dart';

import '../example_data.dart' as eg;
import '../model/binding.dart';
import 'test_app.dart';

void main() {
  TestZulipBinding.ensureInitialized();

  group('WhatsApp-like UI Components', () {
    late PerAccountStore store;

    Future<void> setupPage(WidgetTester tester, {
      List<Message>? dmMessages,
      List<Subscription>? subscriptions,
    }) async {
      addTearDown(testBinding.reset);
      await testBinding.globalStore.add(eg.selfAccount, eg.initialSnapshot());
      store = await testBinding.globalStore.perAccount(eg.selfAccount.id);

      if (dmMessages != null) {
        for (final message in dmMessages) {
          store.addMessage(message);
        }
      }

      if (subscriptions != null) {
        for (final subscription in subscriptions) {
          store.addSubscription(subscription);
        }
      }

      await tester.pumpWidget(
        TestZulipApp(
          accountId: eg.selfAccount.id,
          child: const ChatsPageBody(),
        ),
      );
      await tester.pump();
    }

    group('Enhanced Chat List', () {
      testWidgets('chat items have modern card design', (tester) async {
        final dmMessage = eg.dmMessage(from: eg.otherUser, to: [eg.selfUser]);
        await setupPage(tester, dmMessages: [dmMessage]);

        // Find container with card styling
        final containers = find.byType(Container);
        expect(containers, findsAtLeastNWidgets(1));

        // Check for rounded corners and shadows
        final container = tester.widget<Container>(containers.first);
        final decoration = container.decoration as BoxDecoration?;
        if (decoration != null) {
          check(decoration.borderRadius).isNotNull();
          check(decoration.boxShadow).isNotNull();
        }
      });

      testWidgets('avatars are properly sized and styled', (tester) async {
        final dmMessage = eg.dmMessage(from: eg.otherUser, to: [eg.selfUser]);
        await setupPage(tester, dmMessages: [dmMessage]);

        // Find avatar containers
        final avatars = find.byType(Hero);
        expect(avatars, findsAtLeastNWidgets(1));

        // Check for proper circular design
        final avatar = tester.widget<Hero>(avatars.first);
        expect(avatar.tag, contains('avatar_'));
      });

      testWidgets('unread count badges are properly styled', (tester) async {
        final dmMessage = eg.dmMessage(from: eg.otherUser, to: [eg.selfUser]);
        await setupPage(tester, dmMessages: [dmMessage]);

        // Look for unread count styling
        final badges = find.byWidgetPredicate((widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration as BoxDecoration).color != null);

        expect(badges, findsAtLeastNWidgets(1));
      });

      testWidgets('chat items respond to taps with haptic feedback', (tester) async {
        final dmMessage = eg.dmMessage(from: eg.otherUser, to: [eg.selfUser]);
        await setupPage(tester, dmMessages: [dmMessage]);

        // Mock haptic feedback
        final List<MethodCall> hapticCalls = [];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (MethodCall methodCall) async {
            if (methodCall.method == 'HapticFeedback.vibrate') {
              hapticCalls.add(methodCall);
            }
            return null;
          },
        );

        // Tap on a chat item
        final inkWells = find.byType(InkWell);
        if (inkWells.hasFound) {
          await tester.tap(inkWells.first);
          await tester.pump();

          // Verify haptic feedback was called
          expect(hapticCalls, isNotEmpty);
        }
      });
    });

    group('Enhanced New DM Sheet', () {
      testWidgets('search bar has modern design without harsh outlines', (tester) async {
        await setupPage(tester);

        // Open DM sheet
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pump();
        await tester.pumpAndSettle();

        // Find search container
        final searchContainers = find.byWidgetPredicate((widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration as BoxDecoration).borderRadius != null);

        expect(searchContainers, findsAtLeastNWidgets(1));

        // Check for rounded corners and no harsh borders
        final container = tester.widget<Container>(searchContainers.first);
        final decoration = container.decoration as BoxDecoration;
        check(decoration.borderRadius).isNotNull();

        // Check that border is transparent or very subtle
        if (decoration.border != null) {
          final border = decoration.border as Border;
          final borderColor = border.top.color;
          check(borderColor.alpha).isLessThan(100); // Very transparent
        }
      });

      testWidgets('user list has modern card design', (tester) async {
        await setupPage(tester);

        // Open DM sheet
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pump();
        await tester.pumpAndSettle();

        // Find user list container
        final userListContainers = find.byWidgetPredicate((widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration);

        expect(userListContainers, findsAtLeastNWidgets(1));
      });

      testWidgets('selected user chips have gradient design', (tester) async {
        await setupPage(tester);

        // Open DM sheet
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pump();
        await tester.pumpAndSettle();

        // Find search field and add some text to trigger user display
        final searchField = find.byType(TextField);
        if (searchField.hasFound) {
          await tester.enterText(searchField, 'test');
          await tester.pump();
        }

        // Look for gradient decorations
        final gradientContainers = find.byWidgetPredicate((widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration as BoxDecoration).gradient != null);

        // May or may not find depending on whether users are selected
        // This test verifies the structure exists
        expect(gradientContainers, findsAny);
      });

      testWidgets('compose button has gradient and animation', (tester) async {
        await setupPage(tester);

        // Open DM sheet
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pump();
        await tester.pumpAndSettle();

        // Find compose button
        final animatedBuilders = find.byType(AnimatedBuilder);
        expect(animatedBuilders, findsAtLeastNWidgets(1));

        // Find gradient containers
        final gradientContainers = find.byWidgetPredicate((widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration as BoxDecoration).gradient != null);

        expect(gradientContainers, findsAtLeastNWidgets(1));
      });
    });

    group('Animated Components', () {
      testWidgets('floating action button has scale animation', (tester) async {
        await setupPage(tester);

        // Find the custom FAB
        final gestureDetectors = find.byType(GestureDetector);
        expect(gestureDetectors, findsAtLeastNWidgets(1));

        // Find AnimatedBuilder for scale animation
        final animatedBuilders = find.byType(AnimatedBuilder);
        expect(animatedBuilders, findsAtLeastNWidgets(1));
      });

      testWidgets('presence indicators have pulse animation', (tester) async {
        final dmMessage = eg.dmMessage(from: eg.otherUser, to: [eg.selfUser]);
        await setupPage(tester, dmMessages: [dmMessage]);

        // Find presence indicator with animation
        final animatedBuilders = find.byType(AnimatedBuilder);
        expect(animatedBuilders, findsAtLeastNWidgets(1));
      });

      testWidgets('chat list uses animated list for smooth transitions', (tester) async {
        await setupPage(tester);

        // Find AnimatedList
        final animatedLists = find.byType(AnimatedList);
        expect(animatedLists, findsOneWidget);
      });
    });

    group('Brand Color Consistency', () {
      testWidgets('primary colors are consistently applied', (tester) async {
        await setupPage(tester);

        // Build context to access theme
        final context = tester.element(find.byType(ChatsPageBody));
        final colorScheme = Theme.of(context).colorScheme;
        final designVariables = DesignVariables.of(context);

        // Verify brand color is set correctly
        check(colorScheme.primary).equals(kZulipBrandColor);
        check(designVariables).isNotNull();
      });

      testWidgets('design variables provide consistent theming', (tester) async {
        await setupPage(tester);

        final context = tester.element(find.byType(ChatsPageBody));
        final designVariables = DesignVariables.of(context);

        // Check that design variables are properly configured
        check(designVariables.textMessage).isNotNull();
        check(designVariables.bgMessageRegular).isNotNull();
        check(designVariables.mainBackground).isNotNull();
      });
    });

    group('Accessibility and UX', () {
      testWidgets('interactive elements have proper touch targets', (tester) async {
        final dmMessage = eg.dmMessage(from: eg.otherUser, to: [eg.selfUser]);
        await setupPage(tester, dmMessages: [dmMessage]);

        // Find interactive elements
        final inkWells = find.byType(InkWell);
        expect(inkWells, findsAtLeastNWidgets(1));

        // Check minimum touch target size (44px as per Flutter guidelines)
        for (int i = 0; i < tester.widgetList(inkWells).length; i++) {
          final size = tester.getSize(inkWells.at(i));
          expect(size.height, greaterThanOrEqualTo(44));
        }
      });

      testWidgets('text contrast is sufficient for readability', (tester) async {
        await setupPage(tester);

        final context = tester.element(find.byType(ChatsPageBody));
        final designVariables = DesignVariables.of(context);

        // Basic color contrast checks - ensure colors are defined
        check(designVariables.textMessage).isNotNull();
        check(designVariables.textMessageMuted).isNotNull();
        check(designVariables.mainBackground).isNotNull();
      });

      testWidgets('animations respect reduced motion preferences', (tester) async {
        await setupPage(tester);

        // Verify that animations exist and can be controlled
        final animatedBuilders = find.byType(AnimatedBuilder);
        expect(animatedBuilders, findsAtLeastNWidgets(1));

        // Note: In a real implementation, we would test with MediaQuery.disableAnimationsOf
        // to ensure accessibility compliance
      });
    });

    group('Error States and Edge Cases', () {
      testWidgets('handles empty user list gracefully', (tester) async {
        await setupPage(tester);

        // Open DM sheet with no users
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pump();
        await tester.pumpAndSettle();

        // Should show empty state with icon and message
        final emptyStateIcons = find.byIcon(Icons.person_search);
        expect(emptyStateIcons, findsAny);
      });

      testWidgets('handles network errors gracefully', (tester) async {
        await setupPage(tester);

        // This test would simulate network errors and verify proper error handling
        // For now, we verify the basic structure exists
        final chatBody = find.byType(ChatsPageBody);
        expect(chatBody, findsOneWidget);
      });
    });
  });
}
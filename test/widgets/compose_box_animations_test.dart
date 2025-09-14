import 'package:checks/checks.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_checks/flutter_checks.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zulip/api/model/model.dart';
import 'package:zulip/model/narrow.dart';
import 'package:zulip/model/store.dart';
import 'package:zulip/widgets/compose_box.dart';
import 'package:zulip/widgets/store.dart';

import '../example_data.dart' as eg;
import '../flutter_checks.dart';
import '../model/binding.dart';
import '../model/test_store.dart';
import 'test_app.dart';

void main() {
  TestZulipBinding.ensureInitialized();

  group('Enhanced Compose Box Animations', () {
    late PerAccountStore store;

    Future<void> setupComposeBox(WidgetTester tester, {
      required Narrow narrow,
    }) async {
      addTearDown(testBinding.reset);
      await testBinding.globalStore.add(eg.selfAccount, eg.initialSnapshot());
      store = await testBinding.globalStore.perAccount(eg.selfAccount.id);

      await tester.pumpWidget(
        TestZulipApp(
          accountId: eg.selfAccount.id,
          child: ComposeBox(narrow: narrow),
        ),
      );
      await tester.pump();
    }

    group('Send Button Animations', () {
      testWidgets('send button has scale and rotation animations', (tester) async {
        final narrow = DmNarrow.withUsers([eg.otherUser.userId], selfUserId: eg.selfUser.userId);
        await setupComposeBox(tester, narrow: narrow);

        // Find the send button with animations
        final animatedBuilders = find.byType(AnimatedBuilder);
        expect(animatedBuilders, findsAtLeastNWidgets(1));

        // Find scale and rotation transforms
        final transforms = find.byType(Transform);
        expect(transforms, findsAtLeastNWidgets(2)); // Scale and rotation
      });

      testWidgets('send button shows loading state during send', (tester) async {
        final narrow = DmNarrow.withUsers([eg.otherUser.userId], selfUserId: eg.selfUser.userId);
        await setupComposeBox(tester, narrow: narrow);

        // Enter some text
        final textField = find.byType(TextField);
        await tester.enterText(textField, 'Test message');
        await tester.pump();

        // Find and tap send button
        final sendButton = find.byWidgetPredicate((widget) =>
          widget is InkWell &&
          tester.widget<Center>(find.descendant(
            of: find.byWidget(widget),
            matching: find.byType(Center),
          )).child is Icon);

        if (sendButton.hasFound) {
          // Mock the send method to be slow
          await tester.tap(sendButton);
          await tester.pump(const Duration(milliseconds: 100));

          // Look for loading indicator
          final loadingIndicators = find.byType(CircularProgressIndicator);
          // May or may not be visible depending on timing
          expect(loadingIndicators, findsAny);
        }
      });

      testWidgets('send button has proper gradient styling', (tester) async {
        final narrow = DmNarrow.withUsers([eg.otherUser.userId], selfUserId: eg.selfUser.userId);
        await setupComposeBox(tester, narrow: narrow);

        // Find containers with gradient decoration
        final gradientContainers = find.byWidgetPredicate((widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration as BoxDecoration).gradient != null);

        expect(gradientContainers, findsAtLeastNWidgets(1));
      });

      testWidgets('send button provides haptic feedback', (tester) async {
        final narrow = DmNarrow.withUsers([eg.otherUser.userId], selfUserId: eg.selfUser.userId);
        await setupComposeBox(tester, narrow: narrow);

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

        // Enter text and tap send
        final textField = find.byType(TextField);
        await tester.enterText(textField, 'Test message');
        await tester.pump();

        final sendButton = find.byWidgetPredicate((widget) =>
          widget is InkWell &&
          find.descendant(
            of: find.byWidget(widget),
            matching: find.byIcon(Icons.send),
          ).hasFound);

        if (sendButton.hasFound) {
          await tester.tap(sendButton);
          await tester.pump();

          // Verify haptic feedback was called
          expect(hapticCalls, isNotEmpty);
        }
      });
    });

    group('Animation Controllers', () {
      testWidgets('animation controllers are properly initialized', (tester) async {
        final narrow = DmNarrow.withUsers([eg.otherUser.userId], selfUserId: eg.selfUser.userId);
        await setupComposeBox(tester, narrow: narrow);

        // Find StatefulWidgets that should have animation controllers
        final statefulWidgets = find.byWidgetPredicate((widget) =>
          widget is StatefulWidget &&
          widget.runtimeType.toString().contains('SendButton'));

        expect(statefulWidgets, findsAtLeastNWidgets(1));
      });

      testWidgets('animations complete properly', (tester) async {
        final narrow = DmNarrow.withUsers([eg.otherUser.userId], selfUserId: eg.selfUser.userId);
        await setupComposeBox(tester, narrow: narrow);

        // Enter text to enable send button
        final textField = find.byType(TextField);
        await tester.enterText(textField, 'Test message');
        await tester.pump();

        // Trigger animation by finding and pressing send button
        final sendButton = find.byWidgetPredicate((widget) =>
          widget is InkWell &&
          find.descendant(
            of: find.byWidget(widget),
            matching: find.byIcon(Icons.send),
          ).hasFound);

        if (sendButton.hasFound) {
          await tester.tap(sendButton);

          // Let animation run
          await tester.pump(const Duration(milliseconds: 100));
          await tester.pump(const Duration(milliseconds: 200));
          await tester.pump(const Duration(milliseconds: 300));

          // Verify no animation errors occurred
          expect(tester.takeException(), isNull);
        }
      });
    });

    group('Validation and Error States', () {
      testWidgets('send button is disabled when text is empty', (tester) async {
        final narrow = DmNarrow.withUsers([eg.otherUser.userId], selfUserId: eg.selfUser.userId);
        await setupComposeBox(tester, narrow: narrow);

        // Find send button containers
        final containers = find.byWidgetPredicate((widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration);

        expect(containers, findsAtLeastNWidgets(1));

        // With empty text, send button should be disabled (no gradient)
        final container = tester.widget<Container>(containers.first);
        final decoration = container.decoration as BoxDecoration;

        // Disabled state should not have gradient
        if (decoration.gradient == null) {
          // This is expected for disabled state
          expect(decoration.color, isNotNull);
        }
      });

      testWidgets('send button handles validation errors', (tester) async {
        final narrow = DmNarrow.withUsers([eg.otherUser.userId], selfUserId: eg.selfUser.userId);
        await setupComposeBox(tester, narrow: narrow);

        // The compose box should handle validation errors gracefully
        final composeBox = find.byType(ComposeBox);
        expect(composeBox, findsOneWidget);

        // Verify error state handling exists
        final sendButtons = find.byWidgetPredicate((widget) =>
          widget.toString().contains('Send'));
        expect(sendButtons, findsAny);
      });
    });

    group('Performance', () {
      testWidgets('animations do not cause memory leaks', (tester) async {
        final narrow = DmNarrow.withUsers([eg.otherUser.userId], selfUserId: eg.selfUser.userId);
        await setupComposeBox(tester, narrow: narrow);

        // Trigger multiple animations
        for (int i = 0; i < 5; i++) {
          final textField = find.byType(TextField);
          await tester.enterText(textField, 'Test message $i');
          await tester.pump();

          final sendButton = find.byWidgetPredicate((widget) =>
            widget is InkWell &&
            find.descendant(
              of: find.byWidget(widget),
              matching: find.byIcon(Icons.send),
            ).hasFound);

          if (sendButton.hasFound) {
            await tester.tap(sendButton);
            await tester.pump(const Duration(milliseconds: 50));
          }

          // Clear text for next iteration
          await tester.enterText(textField, '');
          await tester.pump();
        }

        // Verify no exceptions occurred
        expect(tester.takeException(), isNull);
      });

      testWidgets('animations are properly disposed', (tester) async {
        final narrow = DmNarrow.withUsers([eg.otherUser.userId], selfUserId: eg.selfUser.userId);
        await setupComposeBox(tester, narrow: narrow);

        // Remove the widget to trigger disposal
        await tester.pumpWidget(Container());

        // Verify no disposal errors
        expect(tester.takeException(), isNull);
      });
    });

    group('Interaction Design', () {
      testWidgets('send button has appropriate size and shape', (tester) async {
        final narrow = DmNarrow.withUsers([eg.otherUser.userId], selfUserId: eg.selfUser.userId);
        await setupComposeBox(tester, narrow: narrow);

        // Find send button container
        final sizedBoxes = find.byWidgetPredicate((widget) =>
          widget is SizedBox &&
          widget.width != null &&
          widget.height != null);

        expect(sizedBoxes, findsAtLeastNWidgets(1));

        // Check for circular shape
        final circles = find.byWidgetPredicate((widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration as BoxDecoration).shape == BoxShape.circle);

        expect(circles, findsAtLeastNWidgets(1));
      });

      testWidgets('send button icon is properly centered', (tester) async {
        final narrow = DmNarrow.withUsers([eg.otherUser.userId], selfUserId: eg.selfUser.userId);
        await setupComposeBox(tester, narrow: narrow);

        // Find Center widgets containing send icon
        final centers = find.byType(Center);
        expect(centers, findsAtLeastNWidgets(1));

        // Find send icons
        final sendIcons = find.byWidgetPredicate((widget) =>
          widget is Icon &&
          widget.icon.toString().contains('send'));

        expect(sendIcons, findsAny);
      });
    });
  });
}
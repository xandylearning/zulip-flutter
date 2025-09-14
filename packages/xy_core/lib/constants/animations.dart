import 'package:flutter/material.dart';

/// X&Y Learning Platform animation constants for consistent motion design.
///
/// This class provides standardized animation durations, curves, and
/// configurations to ensure consistent motion throughout the app.
class XYAnimations {
  XYAnimations._(); // Private constructor to prevent instantiation

  // Duration Constants
  static const Duration instant = Duration.zero;
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
  static const Duration slower = Duration(milliseconds: 600);
  static const Duration slowest = Duration(milliseconds: 800);

  // Standard Durations
  static const Duration defaultDuration = normal;
  static const Duration microInteraction = fast;
  static const Duration modalTransition = normal;
  static const Duration pageTransition = slow;
  static const Duration heroAnimation = slower;

  // Curve Constants
  static const Curve defaultCurve = Curves.easeOutCubic;
  static const Curve entranceCurve = Curves.easeOutBack;
  static const Curve exitCurve = Curves.easeInCubic;
  static const Curve bounceCurve = Curves.elasticOut;
  static const Curve sharpCurve = Curves.easeOutQuart;

  // Animation Specific Curves
  static const Curve buttonPressCurve = Curves.easeInOut;
  static const Curve slideInCurve = Curves.easeOutCubic;
  static const Curve slideOutCurve = Curves.easeInCubic;
  static const Curve fadeInCurve = Curves.easeIn;
  static const Curve fadeOutCurve = Curves.easeOut;

  // Scale Values
  static const double scalePressed = 0.95;
  static const double scaleHover = 1.02;
  static const double scalePopIn = 0.8;
  static const double scaleNormal = 1.0;
  static const double scalePopOut = 1.1;

  // Slide Distances (in logical pixels)
  static const double slideDistanceSmall = 24.0;
  static const double slideDistanceMedium = 48.0;
  static const double slideDistanceLarge = 80.0;

  // Send Message Animation (WhatsApp-style)
  static const Duration sendMessageDuration = Duration(milliseconds: 400);
  static const Curve sendMessageSlideCurve = Curves.easeOutCubic;
  static const Curve sendMessageScaleCurve = Curves.easeOut;
  static const Curve sendMessageFadeCurve = Curves.easeIn;
  static const double sendMessageSlideDistance = -50.0; // Negative for upward movement

  // Chat Bubble Animations
  static const Duration bubbleEntranceDuration = Duration(milliseconds: 300);
  static const Curve bubbleEntranceCurve = Curves.easeOutBack;
  static const double bubbleEntranceScale = 0.85;

  // Loading Animations
  static const Duration loadingDuration = Duration(milliseconds: 1200);
  static const Curve loadingCurve = Curves.easeInOut;

  // Page Transition Animations
  static const Duration pageTransitionDuration = Duration(milliseconds: 350);
  static const Curve pageTransitionCurve = Curves.easeOutCubic;

  // Modal Animations
  static const Duration modalEntranceDuration = Duration(milliseconds: 300);
  static const Duration modalExitDuration = Duration(milliseconds: 250);
  static const Curve modalEntranceCurve = Curves.easeOutCubic;
  static const Curve modalExitCurve = Curves.easeInCubic;

  // Stagger Animation Delays
  static const Duration staggerDelayShort = Duration(milliseconds: 50);
  static const Duration staggerDelayMedium = Duration(milliseconds: 100);
  static const Duration staggerDelayLong = Duration(milliseconds: 150);

  // Custom Animation Intervals
  static const Interval fadeInInterval = Interval(0.0, 0.6, curve: fadeInCurve);
  static const Interval slideInInterval = Interval(0.2, 1.0, curve: slideInCurve);
  static const Interval scaleInInterval = Interval(0.0, 0.8, curve: entranceCurve);

  // Hero Animation Tags
  static String messageAvatarHeroTag(String userId, String messageId) =>
      'message_avatar_${userId}_$messageId';
  static String sendButtonHeroTag() => 'send_button';
  static String voiceNoteHeroTag(String noteId) => 'voice_note_$noteId';

  // Predefined Tween Objects
  static final Tween<double> scaleTween = Tween<double>(
    begin: scalePopIn,
    end: scaleNormal,
  );

  static final Tween<double> fadeTween = Tween<double>(
    begin: 0.0,
    end: 1.0,
  );

  static final Tween<Offset> slideUpTween = Tween<Offset>(
    begin: const Offset(0.0, 1.0),
    end: Offset.zero,
  );

  static final Tween<Offset> slideDownTween = Tween<Offset>(
    begin: const Offset(0.0, -1.0),
    end: Offset.zero,
  );

  static final Tween<Offset> slideLeftTween = Tween<Offset>(
    begin: const Offset(1.0, 0.0),
    end: Offset.zero,
  );

  static final Tween<Offset> slideRightTween = Tween<Offset>(
    begin: const Offset(-1.0, 0.0),
    end: Offset.zero,
  );

  // Animation Configuration Helpers
  static CurvedAnimation createCurvedAnimation({
    required AnimationController parent,
    Curve curve = defaultCurve,
    Curve? reverseCurve,
  }) {
    return CurvedAnimation(
      parent: parent,
      curve: curve,
      reverseCurve: reverseCurve ?? curve,
    );
  }

  static AnimationController createController({
    required TickerProvider vsync,
    Duration duration = defaultDuration,
  }) {
    return AnimationController(
      duration: duration,
      vsync: vsync,
    );
  }

  // Stagger Animation Helper
  static List<Animation<double>> createStaggeredAnimations({
    required AnimationController controller,
    required int itemCount,
    Duration staggerDelay = staggerDelayMedium,
    Curve curve = defaultCurve,
  }) {
    final animations = <Animation<double>>[];
    final totalStaggerDuration = staggerDelay.inMilliseconds * (itemCount - 1);
    final animationDuration = controller.duration!.inMilliseconds - totalStaggerDuration;

    for (int i = 0; i < itemCount; i++) {
      final startTime = (staggerDelay.inMilliseconds * i) / controller.duration!.inMilliseconds;
      final endTime = (staggerDelay.inMilliseconds * i + animationDuration) / controller.duration!.inMilliseconds;

      animations.add(
        Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: controller,
            curve: Interval(startTime, endTime.clamp(0.0, 1.0), curve: curve),
          ),
        ),
      );
    }

    return animations;
  }
}
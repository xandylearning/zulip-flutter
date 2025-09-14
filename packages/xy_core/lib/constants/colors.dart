import 'package:flutter/material.dart';

/// X&Y Learning Platform brand colors and color system.
///
/// This class contains all the colors used throughout the app to ensure
/// consistent branding and easy maintenance.
class XYColors {
  XYColors._(); // Private constructor to prevent instantiation

  // Primary Brand Colors
  static const Color primaryBlue = Color(0xFF414d75);
  static const Color primaryRed = Color(0xFFf05462);
  static const Color lightBackground = Color(0xFFF8F9FB);
  static const Color darkBackground = Color(0xFF1E1E1E);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryBlue, primaryRed],
  );

  static const LinearGradient backgroundGradientLight = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      lightBackground,
      Color(0xFF414d75), // primaryBlue with alpha applied in usage
    ],
  );

  static const LinearGradient backgroundGradientDark = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      darkBackground,
      Color(0xFF414d75), // primaryBlue with alpha applied in usage
    ],
  );

  // Message Bubble Colors - Simple Design
  static const Color sentMessageBlue = Color(0xFF007AFF); // iOS blue for all modes
  static const Color receivedMessageLight = Colors.white;
  static const Color receivedMessageDark = Color(0xFF2A2A2A);

  // Text Colors
  static const Color textPrimary = Color(0xFF1A1F36);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textOnBrand = Colors.white;

  // State Colors
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Semantic Colors
  static const Color borderColor = Color(0xFFE5E7EB);
  static const Color dividerColor = Color(0xFFF3F4F6);
  static const Color shadowColor = Color(0x1A000000);

  // Helper methods for dynamic colors based on brightness
  static Color backgroundFor(Brightness brightness) {
    return brightness == Brightness.dark ? darkBackground : lightBackground;
  }

  static LinearGradient backgroundGradientFor(Brightness brightness) {
    return brightness == Brightness.dark
        ? backgroundGradientDark
        : backgroundGradientLight;
  }

  static Color sentMessageColorFor(Brightness brightness) {
    return sentMessageBlue; // Same blue for both light and dark modes
  }

  static Color receivedMessageFor(Brightness brightness) {
    return brightness == Brightness.dark
        ? receivedMessageDark
        : receivedMessageLight;
  }

  static Color shadowFor(Brightness brightness, {double opacity = 0.1}) {
    return brightness == Brightness.dark
        ? Colors.black.withOpacity(opacity * 3)
        : Colors.black.withOpacity(opacity);
  }

  static Color sentMessageShadowFor(Brightness brightness, {double opacity = 0.1}) {
    return sentMessageBlue.withOpacity(brightness == Brightness.dark ? opacity * 2 : opacity);
  }
}
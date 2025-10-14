import 'package:flutter/material.dart';

/// X&Y Learning Platform dimension constants for consistent spacing and sizing.
///
/// This class provides standardized dimensions to ensure consistent
/// layout and spacing throughout the app.
class XYDimensions {
  XYDimensions._(); // Private constructor to prevent instantiation

  // Spacing Scale (8pt grid system)
  static const double spaceXs = 4.0;
  static const double spaceSm = 8.0;
  static const double spaceMd = 16.0;
  static const double spaceLg = 24.0;
  static const double spaceXl = 32.0;
  static const double space2xl = 48.0;
  static const double space3xl = 64.0;

  // Padding (using spacing scale)
  static const EdgeInsets paddingXs = EdgeInsets.all(spaceXs);
  static const EdgeInsets paddingSm = EdgeInsets.all(spaceSm);
  static const EdgeInsets paddingMd = EdgeInsets.all(spaceMd);
  static const EdgeInsets paddingLg = EdgeInsets.all(spaceLg);
  static const EdgeInsets paddingXl = EdgeInsets.all(spaceXl);

  // Horizontal padding
  static const EdgeInsets paddingHorizontalXs = EdgeInsets.symmetric(horizontal: spaceXs);
  static const EdgeInsets paddingHorizontalSm = EdgeInsets.symmetric(horizontal: spaceSm);
  static const EdgeInsets paddingHorizontalMd = EdgeInsets.symmetric(horizontal: spaceMd);
  static const EdgeInsets paddingHorizontalLg = EdgeInsets.symmetric(horizontal: spaceLg);
  static const EdgeInsets paddingHorizontalXl = EdgeInsets.symmetric(horizontal: spaceXl);

  // Vertical padding
  static const EdgeInsets paddingVerticalXs = EdgeInsets.symmetric(vertical: spaceXs);
  static const EdgeInsets paddingVerticalSm = EdgeInsets.symmetric(vertical: spaceSm);
  static const EdgeInsets paddingVerticalMd = EdgeInsets.symmetric(vertical: spaceMd);
  static const EdgeInsets paddingVerticalLg = EdgeInsets.symmetric(vertical: spaceLg);
  static const EdgeInsets paddingVerticalXl = EdgeInsets.symmetric(vertical: spaceXl);

  // Border Radius
  static const double borderRadiusSm = 8.0;
  static const double borderRadiusMd = 12.0;
  static const double borderRadiusLg = 16.0;
  static const double borderRadiusXl = 20.0;
  static const double borderRadiusRound = 999.0; // For circular elements

  static const BorderRadius borderRadiusSmAll = BorderRadius.all(Radius.circular(borderRadiusSm));
  static const BorderRadius borderRadiusMdAll = BorderRadius.all(Radius.circular(borderRadiusMd));
  static const BorderRadius borderRadiusLgAll = BorderRadius.all(Radius.circular(borderRadiusLg));
  static const BorderRadius borderRadiusXlAll = BorderRadius.all(Radius.circular(borderRadiusXl));

  // Message Bubble Specific
  static const BorderRadius messageBubbleRadius = BorderRadius.only(
    topLeft: Radius.circular(borderRadiusLg),
    topRight: Radius.circular(borderRadiusLg),
    bottomLeft: Radius.circular(borderRadiusLg),
    bottomRight: Radius.circular(4.0),
  );

  static const BorderRadius messageBubbleRadiusReversed = BorderRadius.only(
    topLeft: Radius.circular(borderRadiusLg),
    topRight: Radius.circular(borderRadiusLg),
    bottomLeft: Radius.circular(4.0),
    bottomRight: Radius.circular(borderRadiusLg),
  );

  // Icon Sizes
  static const double iconXs = 16.0;
  static const double iconSm = 20.0;
  static const double iconMd = 24.0;
  static const double iconLg = 32.0;
  static const double iconXl = 48.0;

  // Avatar Sizes
  static const double avatarSm = 24.0;
  static const double avatarMd = 32.0;
  static const double avatarLg = 48.0;
  static const double avatarXl = 64.0;

  // Button Dimensions
  static const double buttonHeightSm = 36.0;
  static const double buttonHeightMd = 44.0;
  static const double buttonHeightLg = 52.0;
  static const double buttonHeightXl = 60.0;

  static const double buttonMinWidth = 88.0;

  // Input Field Dimensions
  static const double inputHeight = 48.0;
  static const double inputBorderWidth = 1.0;
  static const double inputFocusBorderWidth = 2.0;

  // Layout Constraints
  static const double maxContentWidth = 760.0; // From original Zulip design
  static const double minTouchTarget = 44.0; // Accessibility guideline

  // Chat Bubble Constraints
  static const double messageBubbleMaxWidthRatio = 0.75;
  static const double messageBubbleMinWidth = 60.0;
  static const double messageBubbleMaxWidthConstant = 280.0;

  // Shadow/Elevation
  static const double elevationSm = 2.0;
  static const double elevationMd = 4.0;
  static const double elevationLg = 8.0;
  static const double elevationXl = 16.0;

  // Screen Breakpoints
  static const double screenSmall = 320.0;
  static const double screenMedium = 768.0;
  static const double screenLarge = 1024.0;
  static const double screenExtraLarge = 1440.0;

  // Animation Values
  static const double scalePressed = 0.95;
  static const double scaleHover = 1.05;

  // Helper methods
  static bool isSmallScreen(double width) => width < screenMedium;
  static bool isMediumScreen(double width) => width >= screenMedium && width < screenLarge;
  static bool isLargeScreen(double width) => width >= screenLarge;

  static EdgeInsets responsivePadding(double screenWidth) {
    if (isSmallScreen(screenWidth)) return paddingMd;
    if (isMediumScreen(screenWidth)) return paddingLg;
    return paddingXl;
  }

  static double messageBubbleMaxWidth(double screenWidth) {
    return screenWidth * messageBubbleMaxWidthRatio;
  }
}
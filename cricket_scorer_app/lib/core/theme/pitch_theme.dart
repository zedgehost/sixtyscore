import 'package:flutter/material.dart';

/// Pitch Dynamic Design System tokens.
/// Extracted from the Stitch cricket theme design specifications.
class PitchTheme {
  PitchTheme._();

  // Primary Cricket Greens
  static const Color primary = Color(0xFF00261B); // Deep Forest Cricket Green
  static const Color primaryContainer = Color(0xFF0B3D2E); // Dark Pine Container
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFF79A894);

  // Secondary Emerald Greens
  static const Color secondary = Color(0xFF006D36); // Vibrant Pitch Green
  static const Color secondaryContainer = Color(0xFF7CF8A1); // Mint Badge Container
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color onSecondaryContainer = Color(0xFF007239);
  static const Color secondaryFixed = Color(0xFF7EFBA4);
  static const Color secondaryFixedDim = Color(0xFF61DE8A);

  // Tertiary Electric Lime
  static const Color tertiary = Color(0xFF172400);
  static const Color tertiaryContainer = Color(0xFF293B00);
  static const Color tertiaryFixed = Color(0xFFBBF540); // Electric Neon Lime Accent
  static const Color tertiaryFixedDim = Color(0xFFA0D820);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color onTertiaryContainer = Color(0xFF7DAD00);

  // Surfaces & Backgrounds (Clean, neutral sports telemetry - zero blue cast)
  static const Color surface = Color(0xFFF8F9FA); // Crisp clean sports background
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF); // Pure White Cards
  static const Color surfaceContainerLow = Color(0xFFF2F4F3); // Soft neutral off-white container
  static const Color surfaceContainer = Color(0xFFE6EAE7); // Soft neutral chip/track fill
  static const Color surfaceContainerHigh = Color(0xFFDCE1DE); // Neutral unselected chip fill
  static const Color surfaceVariant = Color(0xFFD3D9D5); // Neutral subtle surface

  // Typography & Text Slate
  static const Color onSurface = Color(0xFF141B2B); // Deep Navy/Charcoal for primary text
  static const Color onSurfaceVariant = Color(0xFF414944); // Subdued secondary text
  static const Color outline = Color(0xFF717974); // Muted gray outline
  static const Color outlineVariant = Color(0xFFC0C8C3); // Light border outline

  // Indicator
  static const Color error = Color(0xFFBA1A1A); // Cricket Red Live Indicator
  static const Color errorContainer = Color(0xFFFFDAD6);

  // Modern Clean Sports Palette (Cricbuzz / CREX / International standard)
  static const Color sportsEmerald = Color(0xFF047857); // Deep athletic turf green
  static const Color sportsEmeraldDark = Color(0xFF064E3B);
  static const Color sportsEmeraldLight = Color(0xFFECFDF5);
  static const Color liveRed = Color(0xFFDC2626); // Crisp international LIVE red
  static const Color liveRedBg = Color(0xFFFEE2E2); // Soft red badge background
  static const Color hairlineBorder = Color(0xFFE2E8F0); // 0.8px subtle card border
  static const Color slateHeading = Color(0xFF0F172A); // Sharp dark athletic text
  static const Color slateSubdued = Color(0xFF64748B); // Muted secondary text
  static const Color cardBg = Color(0xFFFFFFFF); // Pure white card surface

  // Card Box Shadow
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: const Color(0xFF000000).withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get cardShadowHover => [
        BoxShadow(
          color: const Color(0xFF000000).withValues(alpha: 0.08),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
      ];

  // ── Global Style Control System (Matches HomePage Pitch Dynamic) ──
  static const double cardRadius = 16.0;
  static const double inputRadius = 12.0;
  static const double chipRadius = 20.0;

  static BoxDecoration cardDecoration({
    bool isLive = false,
    double radius = cardRadius,
    Color? color,
  }) =>
      BoxDecoration(
        color: color ?? cardBg,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: isLive
              ? sportsEmerald.withValues(alpha: 0.45)
              : hairlineBorder,
          width: isLive ? 1.2 : 0.9,
        ),
        boxShadow: cardShadow,
      );

  static BoxDecoration subtleSurfaceDecoration({
    double radius = inputRadius,
    Color? color,
  }) =>
      BoxDecoration(
        color: color ?? surfaceContainerLow,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: hairlineBorder, width: 0.9),
      );

  static const TextStyle sectionHeaderStyle = TextStyle(
    color: slateHeading,
    fontSize: 13.5,
    fontWeight: FontWeight.w900,
    letterSpacing: 0.5,
  );

  static const TextStyle cardTitleStyle = TextStyle(
    color: slateHeading,
    fontSize: 15,
    fontWeight: FontWeight.w800,
  );

  static const TextStyle cardSubtitleStyle = TextStyle(
    color: slateSubdued,
    fontSize: 12,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle scoreNumeralStyle = TextStyle(
    color: slateHeading,
    fontSize: 17,
    fontWeight: FontWeight.w900,
  );

  static const TextStyle badgeTextStyle = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w900,
    letterSpacing: 0.4,
  );
}

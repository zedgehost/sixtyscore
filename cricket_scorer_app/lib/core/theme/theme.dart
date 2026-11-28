// 60Score design system.
// Approved branding: deep navy / near-black backgrounds, teal-cyan primary
// accents, amber-gold secondary accents, silver + white text, restrained
// cricket-red indicators. Metallic silver "60", red ball, golden stumps.
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:cricket_scorer_app/services/io/player_io.dart';
import 'package:cricket_scorer_app/core/theme/pitch_theme.dart';

// ---------- Color tokens (Pitch Dynamic Modernization) ----------
const kNavyDeep = PitchTheme.surface; // #F8F9FA
const kNavy = PitchTheme.cardBg; // #FFFFFF
const kPanel = PitchTheme.cardBg; // #FFFFFF
const kPanel2 = PitchTheme.surfaceContainerLow; // #F2F4F3
const kCyan = PitchTheme.sportsEmerald; // Athletic Emerald Green
const kTeal = PitchTheme.sportsEmerald;
const kTealDark = PitchTheme.primaryContainer;
const kGold = PitchTheme.primary;
const kAmber = Color(0xFFB58500);
const kSilver = PitchTheme.slateSubdued; // Muted athletic slate
const kWhite = Colors.white;
const kRed = PitchTheme.liveRed;
const kGreen = PitchTheme.sportsEmerald;

// Dual-palette professional system mapped to Pitch Dynamic
const kSunsetOrange = PitchTheme.sportsEmerald;
const kSunsetOrangeDeep = PitchTheme.primary;
const kSunsetOrangeSoft = PitchTheme.sportsEmeraldLight;
const kSunsetNavy = PitchTheme.surfaceContainerLow;
const kSunsetNavyDeep = PitchTheme.surface;
const kOceanBlack = PitchTheme.surface;
const kOceanDeep = PitchTheme.cardBg;
const kOceanSteel = PitchTheme.hairlineBorder;
const kOceanMist = PitchTheme.slateHeading;
const kOceanFaint = PitchTheme.slateSubdued;

const kSunsetGradient = LinearGradient(
  colors: [PitchTheme.surfaceContainerLowest, PitchTheme.surfaceContainerLow],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);
const kOceanCardGradient = LinearGradient(
  colors: [PitchTheme.surfaceContainerLowest, PitchTheme.surfaceContainerLow],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);
const kHeroGlowGradient = RadialGradient(
  center: Alignment.topCenter,
  radius: 1.2,
  colors: [Color(0x1A006D36), Color(0x00000000)],
);

// Legacy aliases
const kBg = kNavyDeep;
const kCopper = Color(0xFFF8AE6D);
const kOrangeRed = Color(0xFFE4572E);

// Professional shade scales mapped to PitchTheme surfaces
const kNavy950 = PitchTheme.surfaceContainerLowest;
const kNavy900 = PitchTheme.surface;
const kNavy800 = PitchTheme.surfaceContainerLow;
const kNavy700 = PitchTheme.surfaceContainer;
const kNavy600 = PitchTheme.surfaceContainerLowest;
const kNavy500 = PitchTheme.surfaceContainerLow;
const kNavy400 = PitchTheme.surfaceContainerHigh;
const kNavy300 = PitchTheme.surfaceVariant;

const kCyan700 = PitchTheme.primary;
const kCyan500 = PitchTheme.secondary;
const kCyan300 = PitchTheme.secondaryContainer;
const kCyan100 = PitchTheme.surfaceContainerLow;

const kGold700 = PitchTheme.primary;
const kGold500 = PitchTheme.primaryContainer;
const kGold300 = PitchTheme.tertiaryFixed;
const kGold100 = PitchTheme.surfaceContainer;

const kTextPrimary = PitchTheme.onSurface;
const kTextSecondary = PitchTheme.onSurfaceVariant;
const kTextMuted = PitchTheme.outline;
const kTextFaint = PitchTheme.outline;

const kCyanGradient = LinearGradient(
  colors: [PitchTheme.primary, PitchTheme.primaryContainer],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);
const kCardSheen = LinearGradient(
  colors: [Color(0x08000000), Color(0x00000000)],
  begin: Alignment.topCenter,
  end: Alignment.center,
);

ThemeData buildScore60Theme() {
  // Pitch Dynamic professional theme (approved Nov 2026):
  // Clean crisp sports off-white background (#F9F9FF), forest & emerald greens,
  // electric lime accents, dark charcoal typography.
  const scheme = ColorScheme.light(
    primary: PitchTheme.primary,
    onPrimary: PitchTheme.onPrimary,
    primaryContainer: PitchTheme.primaryContainer,
    onPrimaryContainer: PitchTheme.onPrimaryContainer,
    secondary: PitchTheme.secondary,
    onSecondary: PitchTheme.onSecondary,
    secondaryContainer: PitchTheme.secondaryContainer,
    onSecondaryContainer: PitchTheme.onSecondaryContainer,
    tertiary: PitchTheme.tertiary,
    tertiaryContainer: PitchTheme.tertiaryContainer,
    surface: PitchTheme.surface,
    onSurface: PitchTheme.onSurface,
    surfaceContainerLowest: PitchTheme.surfaceContainerLowest,
    surfaceContainerLow: PitchTheme.surfaceContainerLow,
    surfaceContainer: PitchTheme.surfaceContainer,
    surfaceContainerHigh: PitchTheme.surfaceContainerHigh,
    surfaceContainerHighest: PitchTheme.surfaceVariant,
    error: PitchTheme.error,
    onError: PitchTheme.onPrimary,
    outline: PitchTheme.outline,
    outlineVariant: PitchTheme.outlineVariant,
  );
  final textTheme = Typography.blackMountainView.apply(
    bodyColor: PitchTheme.onSurface,
    displayColor: PitchTheme.onSurface,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    textTheme: textTheme,
    scaffoldBackgroundColor: PitchTheme.surface,
    appBarTheme: const AppBarTheme(
      backgroundColor: PitchTheme.cardBg,
      foregroundColor: PitchTheme.slateHeading,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
      iconTheme: IconThemeData(color: PitchTheme.slateHeading),
      titleTextStyle: TextStyle(
        color: PitchTheme.slateHeading,
        fontSize: 18,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.2,
      ),
    ),
    cardTheme: CardThemeData(
      color: PitchTheme.cardBg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PitchTheme.cardRadius),
        side: const BorderSide(color: PitchTheme.hairlineBorder, width: 0.9),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: PitchTheme.cardBg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PitchTheme.cardRadius),
      ),
      titleTextStyle: const TextStyle(
        color: PitchTheme.slateHeading,
        fontSize: 18,
        fontWeight: FontWeight.w900,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: PitchTheme.cardBg,
      selectedItemColor: PitchTheme.sportsEmerald,
      unselectedItemColor: PitchTheme.slateSubdued,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: PitchTheme.cardBg,
      indicatorColor: PitchTheme.sportsEmeraldLight,
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: PitchTheme.cardBg,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: PitchTheme.surfaceContainerLow,
      hintStyle: const TextStyle(color: PitchTheme.slateSubdued, fontSize: 13.5),
      labelStyle: const TextStyle(color: PitchTheme.slateSubdued, fontWeight: FontWeight.w600),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PitchTheme.inputRadius),
        borderSide: const BorderSide(color: PitchTheme.hairlineBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PitchTheme.inputRadius),
        borderSide: const BorderSide(color: PitchTheme.hairlineBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(PitchTheme.inputRadius),
        borderSide: const BorderSide(color: PitchTheme.sportsEmerald, width: 1.5),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: PitchTheme.surfaceContainerLow,
      selectedColor: PitchTheme.sportsEmeraldLight,
      side: const BorderSide(color: PitchTheme.hairlineBorder),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(PitchTheme.chipRadius),
      ),
      labelStyle: const TextStyle(
        color: PitchTheme.slateHeading,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
    dividerColor: PitchTheme.hairlineBorder,
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: PitchTheme.primaryContainer,
      contentTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: PitchTheme.sportsEmerald,
      foregroundColor: Colors.white,
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: PitchTheme.sportsEmerald,
      unselectedLabelColor: PitchTheme.slateSubdued,
      indicatorColor: PitchTheme.sportsEmerald,
      labelStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
      unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: PitchTheme.cardBg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      textColor: PitchTheme.slateHeading,
      iconColor: PitchTheme.slateSubdued,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: PitchTheme.sportsEmerald,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PitchTheme.inputRadius),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: PitchTheme.sportsEmerald,
        side: const BorderSide(color: PitchTheme.hairlineBorder),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(PitchTheme.inputRadius),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: PitchTheme.sportsEmerald,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
  );
}

// ---------- Reusable components ----------

/// Standard branded card used across every screen.
class ScoreCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool highlight;
  const ScoreCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: PitchTheme.cardDecoration(isLive: highlight),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: PitchTheme.slateHeading),
        child: child,
      ),
    );
    if (onTap == null) return card;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: card,
    );
  }
}

/// Premium screen background: deep navy with a soft cyan radial glow at the
/// top — gives every screen a professional, lit-from-above feel.
class PremiumBackground extends StatelessWidget {
  final Widget child;
  const PremiumBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: PitchTheme.surface,
      child: child,
    );
  }
}

/// Big dramatic score display — for hero cards and live matches.
/// Huge heavy numerals with a soft cyan glow.
class HeroScore extends StatelessWidget {
  final String score;
  final String? label;
  const HeroScore({super.key, required this.score, this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          score,
          style: const TextStyle(
            color: PitchTheme.primary,
            fontSize: 44,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
        if (label != null)
          Text(
            label!,
            style: const TextStyle(
              color: PitchTheme.outline,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
      ],
    );
  }
}

/// Section heading with an optional trailing action.
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? action;
  const SectionHeader(this.title, {super.key, this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: PitchTheme.secondary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: PitchTheme.onSurface,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

/// Gold "Q" qualification badge for the points table.
class QBadge extends StatelessWidget {
  final bool provisional;
  const QBadge({super.key, this.provisional = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: provisional
            ? kGold.withValues(alpha: 0.18)
            : kGold.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: kGold),
      ),
      child: Text(
        provisional ? 'Q*' : 'Q',
        style: TextStyle(
          color: provisional ? kGold : const Color(0xFF2B1C05),
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

/// Small status pill (LIVE / UPCOMING / COMPLETED / CANCELLED).
class StatusPill extends StatelessWidget {
  final String status;
  const StatusPill(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    late Color fg;
    late Color bg;
    late String label;
    switch (status) {
      case 'live':
        fg = kRed;
        bg = kRed.withValues(alpha: 0.14);
        label = 'LIVE';
        break;
      case 'upcoming':
      case 'scheduled':
        fg = kCyan;
        bg = kCyan.withValues(alpha: 0.14);
        label = 'UPCOMING';
        break;
      case 'completed':
        fg = kGreen;
        bg = kGreen.withValues(alpha: 0.14);
        label = 'COMPLETED';
        break;
      case 'cancelled':
        fg = PitchTheme.outline;
        bg = PitchTheme.surfaceContainerLow;
        label = 'CANCELLED';
        break;
      default:
        fg = kGold;
        bg = kGold.withValues(alpha: 0.14);
        label = status.toUpperCase();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

enum ScoreButtonKind { primary, gold, ghost, danger }

/// Standard branded button.
class ScoreButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final ScoreButtonKind kind;
  final IconData? icon;
  const ScoreButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = ScoreButtonKind.primary,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    late Color bg;
    late Color fg;
    switch (kind) {
      case ScoreButtonKind.primary:
        bg = kCyan;
        fg = Colors.white;
        break;
      case ScoreButtonKind.gold:
        bg = kGold;
        fg = Colors.white;
        break;
      case ScoreButtonKind.ghost:
        bg = Colors.transparent;
        fg = kCyan;
        break;
      case ScoreButtonKind.danger:
        bg = kRed;
        fg = kWhite;
        break;
    }
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 8),
        ],
        // Flexible (v1.4.5): a long label must ellipsize instead of
        // overflowing the button at narrow widths (360dp screens).
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
    if (kind == ScoreButtonKind.ghost) {
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: fg,
          side: const BorderSide(color: kCyan),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: child,
      );
    }
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
      child: child,
    );
  }
}

/// Circular team avatar with initials.
class TeamAvatar extends StatelessWidget {
  final String name;
  final double radius;
  const TeamAvatar(this.name, {super.key, this.radius = 20});

  @override
  Widget build(BuildContext context) {
    final initials = name
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    return CircleAvatar(
      radius: radius,
      backgroundColor: PitchTheme.surfaceContainerLow,
      child: Center(
        child: Text(
          initials.isEmpty ? '?' : initials,
          style: TextStyle(
            color: PitchTheme.primary,
            fontWeight: FontWeight.w900,
            fontSize: radius * 0.75,
          ),
        ),
      ),
    );
  }
}

/// Friendly empty-state placeholder.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(icon, size: 48, color: PitchTheme.outline),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: PitchTheme.onSurface,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: PitchTheme.outline, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// Small labeled statistic chip.
class StatChip extends StatelessWidget {
  final String label;
  final String value;
  const StatChip(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: PitchTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: PitchTheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: PitchTheme.onSurface,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: PitchTheme.outline, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

// ---------- v1.1.2 redesign: shared components ----------

/// Gold gradient used for primary action buttons and highlights.
const kGoldGradient = LinearGradient(
  colors: [PitchTheme.primary, PitchTheme.primaryContainer],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

/// Branded screen header: hamburger (left), centered 60Score logo +
/// tagline, settings (right). Used on Home / Matches / Statistics.
class BrandedHeader extends StatelessWidget {
  final VoidCallback onMenu;
  final VoidCallback? onSettings;
  const BrandedHeader({
    super.key,
    required this.onMenu,
    this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Menu',
            icon: const Icon(Icons.menu, color: PitchTheme.onSurface, size: 28),
            onPressed: onMenu,
          ),
          const Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '60Score',
                  style: TextStyle(
                    color: PitchTheme.primary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'Cricket Scoring, Simplified.',
                  style: TextStyle(color: PitchTheme.outline, fontSize: 11),
                ),
              ],
            ),
          ),
          if (onSettings != null)
            IconButton(
              tooltip: 'Settings',
              icon: const Icon(Icons.settings_outlined, color: PitchTheme.onSurfaceVariant),
              onPressed: onSettings,
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }
}

/// Gradient action card (Home 5-card row, Quick Actions).
class ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final VoidCallback onTap;
  final double iconSize;
  const ActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
    this.iconSize = 30,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            boxShadow: [
              BoxShadow(
                color: gradient.last.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: kWhite, size: iconSize),
              const SizedBox(height: 6),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: kWhite,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: kWhite.withValues(alpha: 0.85),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Gold gradient primary button (Create Match, Save Settings, ...).
class GoldButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  const GoldButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onPressed,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: kGoldGradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: kGold.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: Colors.white, size: 22),
                const SizedBox(width: 10),
              ],
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Section title row: icon + UPPERCASE title + optional trailing action.
class SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  const SectionTitle({
    super.key,
    required this.icon,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
      child: Row(
        children: [
          Icon(icon, color: PitchTheme.secondary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(
                color: PitchTheme.onSurface,
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
          if (trailing != null) ...[trailing!],
        ],
      ),
    );
  }
}

/// Cyan "View All >" trailing link.
class ViewAllLink extends StatelessWidget {
  final VoidCallback onTap;
  const ViewAllLink({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'View All',
            style: TextStyle(
              color: kCyan,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          Icon(Icons.chevron_right, color: kCyan, size: 18),
        ],
      ),
    );
  }
}

/// Numbered settings section card (New Match screen sections).
class NumberedSection extends StatelessWidget {
  final int number;
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? headerAction;
  const NumberedSection({
    super.key,
    required this.number,
    required this.title,
    this.subtitle,
    required this.child,
    this.headerAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PitchTheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PitchTheme.outlineVariant.withValues(alpha: 0.3)),
        boxShadow: PitchTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: PitchTheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '$number',
                    style: const TextStyle(
                      color: PitchTheme.tertiaryFixed,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: PitchTheme.onSurface,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: PitchTheme.outline,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              if (headerAction != null) ...[headerAction!],
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// Selectable option chip card (format cards, toss options, tabs).
class OptionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  const OptionCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: selected
                ? PitchTheme.primaryContainer
                : PitchTheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? PitchTheme.secondary
                  : PitchTheme.outlineVariant.withValues(alpha: 0.4),
              width: selected ? 1.5 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: PitchTheme.primary.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  color: selected
                      ? PitchTheme.tertiaryFixed
                      : PitchTheme.onSurfaceVariant,
                  size: 20,
                ),
                const SizedBox(height: 4),
              ],
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected
                      ? PitchTheme.tertiaryFixed
                      : PitchTheme.onSurface,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected
                        ? Colors.white70
                        : PitchTheme.outline,
                    fontSize: 10,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- File helpers (kept from previous version) ----------

/// Write [bytes] to a temp file and open the system share sheet.
Future<void> shareBytes(
  String filename,
  List<int> bytes, {
  String? text,
}) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(bytes, flush: true);
  await SharePlus.instance.share(
    ShareParams(files: [XFile(file.path)], text: text),
  );
}

Future<void> shareCsvFile(String filename, String csv) =>
    shareBytes(filename, utf8.encode(csv), text: '60Score player list');

Future<void> shareXlsxFile(String filename, List<PlayerRow> rows) =>
    shareBytes(filename, rowsToXlsxBytes(rows), text: '60Score player list');

Future<void> copyToClipboard(String text) =>
    Clipboard.setData(ClipboardData(text: text));

class PickedPlayers {
  final List<PlayerRow> rows;
  final List<String> errors;
  final String sourceName;
  PickedPlayers(this.rows, this.errors, this.sourceName);
}

/// Let the user pick a .csv or .xlsx player list and parse it.
Future<PickedPlayers?> pickPlayerListFile() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['csv', 'xlsx'],
    withData: true,
  );
  if (result == null || result.files.isEmpty) return null;
  final f = result.files.first;
  final bytes = f.bytes;
  if (bytes == null) {
    return PickedPlayers([], ['Could not read the selected file'], f.name);
  }
  final isXlsx =
      (f.extension ?? '').toLowerCase() == 'xlsx' ||
      f.name.toLowerCase().endsWith('.xlsx');
  final parsed = isXlsx
      ? parsePlayersXlsx(bytes)
      : parsePlayersCsv(String.fromCharCodes(bytes));
  return PickedPlayers(parsed.rows, parsed.errors, f.name);
}

/// Import / Export popup used on every player-list screen.
class PlayerListIoButtons extends StatelessWidget {
  final List<PlayerRow> Function() exportRows;
  final Future<void> Function(List<PlayerRow> rows) onImport;
  final String exportName;
  const PlayerListIoButtons({
    super.key,
    required this.exportRows,
    required this.onImport,
    required this.exportName,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.import_export),
      tooltip: 'Import / Export',
      onSelected: (v) async {
        if (v == 'import') {
          final picked = await pickPlayerListFile();
          if (picked == null) return;
          if (!context.mounted) return;
          if (picked.rows.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  picked.errors.isEmpty
                      ? 'No players found in that file'
                      : picked.errors.join('; '),
                ),
              ),
            );
            return;
          }
          await onImport(picked.rows);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Imported ${picked.rows.length} players from ${picked.sourceName}',
                ),
              ),
            );
          }
        } else if (v == 'export_csv') {
          await shareCsvFile('$exportName.csv', rowsToCsv(exportRows()));
        } else if (v == 'export_xlsx') {
          await shareXlsxFile('$exportName.xlsx', exportRows());
        } else if (v == 'copy_csv') {
          await copyToClipboard(rowsToCsv(exportRows()));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('CSV copied to clipboard')),
            );
          }
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'import', child: Text('Import from Excel / CSV')),
        PopupMenuItem(
          value: 'export_xlsx',
          child: Text('Export to Excel (.xlsx)'),
        ),
        PopupMenuItem(value: 'export_csv', child: Text('Export to CSV')),
        PopupMenuItem(value: 'copy_csv', child: Text('Copy CSV to clipboard')),
      ],
    );
  }
}

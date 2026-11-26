import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:cricket_scorer_app/core/theme/pitch_theme.dart';

/// Pre-made sports franchise team logo definition
class PresetTeamLogo {
  final String id;
  final String name;
  final String defaultCode;
  final IconData icon;
  final Color primaryColor;
  final Color secondaryColor;
  final Color iconColor;

  const PresetTeamLogo({
    required this.id,
    required this.name,
    required this.defaultCode,
    required this.icon,
    required this.primaryColor,
    required this.secondaryColor,
    this.iconColor = Colors.white,
  });
}

/// 12 High-Energy Built-In Sports Team Franchise Logos
class TeamPresetCatalog {
  static const List<PresetTeamLogo> presets = [
    PresetTeamLogo(
      id: 'preset:tigers',
      name: 'Bengal Tigers',
      defaultCode: 'BT',
      icon: Icons.pets,
      primaryColor: Color(0xFFEA580C), // Orange
      secondaryColor: Color(0xFF7C2D12), // Deep burnt orange
      iconColor: Colors.white,
    ),
    PresetTeamLogo(
      id: 'preset:lions',
      name: 'Royal Lions',
      defaultCode: 'RL',
      icon: Icons.workspace_premium,
      primaryColor: Color(0xFFD97706), // Gold / Amber
      secondaryColor: Color(0xFF78350F), // Dark gold
      iconColor: Colors.white,
    ),
    PresetTeamLogo(
      id: 'preset:falcons',
      name: 'Desert Falcons',
      defaultCode: 'DF',
      icon: Icons.flight,
      primaryColor: Color(0xFF0284C7), // Sky blue
      secondaryColor: Color(0xFF0C4A6E), // Deep navy
      iconColor: Colors.white,
    ),
    PresetTeamLogo(
      id: 'preset:strikers',
      name: 'Thunder Strikers',
      defaultCode: 'TS',
      icon: Icons.flash_on,
      primaryColor: Color(0xFFEAB308), // Electric Yellow
      secondaryColor: Color(0xFFCA8A04), // Dark Gold
      iconColor: Color(0xFF0F172A), // Dark slate icon for contrast
    ),
    PresetTeamLogo(
      id: 'preset:kings',
      name: 'Golden Kings',
      defaultCode: 'GK',
      icon: Icons.military_tech,
      primaryColor: Color(0xFF9333EA), // Royal Purple
      secondaryColor: Color(0xFF581C87), // Dark Purple
      iconColor: Color(0xFFFDE047), // Gold icon
    ),
    PresetTeamLogo(
      id: 'preset:warriors',
      name: 'Emerald Warriors',
      defaultCode: 'EW',
      icon: Icons.shield,
      primaryColor: Color(0xFF059669), // Sports Emerald
      secondaryColor: Color(0xFF064E3B), // Deep Pine
      iconColor: Colors.white,
    ),
    PresetTeamLogo(
      id: 'preset:titans',
      name: 'Iron Titans',
      defaultCode: 'IT',
      icon: Icons.fitness_center,
      primaryColor: Color(0xFF475569), // Slate
      secondaryColor: Color(0xFF0F172A), // Obsidian
      iconColor: Colors.white,
    ),
    PresetTeamLogo(
      id: 'preset:knights',
      name: 'Storm Knights',
      defaultCode: 'SK',
      icon: Icons.security,
      primaryColor: Color(0xFF2563EB), // Royal Blue
      secondaryColor: Color(0xFF1E3A8A), // Midnight Blue
      iconColor: Colors.white,
    ),
    PresetTeamLogo(
      id: 'preset:panthers',
      name: 'Shadow Panthers',
      defaultCode: 'SP',
      icon: Icons.visibility,
      primaryColor: Color(0xFF1E293B), // Deep Charcoal
      secondaryColor: Color(0xFF020617), // Deep Black
      iconColor: Color(0xFF38BDF8), // Neon Cyan accent
    ),
    PresetTeamLogo(
      id: 'preset:sharks',
      name: 'Ocean Sharks',
      defaultCode: 'OS',
      icon: Icons.water,
      primaryColor: Color(0xFF0D9488), // Teal
      secondaryColor: Color(0xFF115E59), // Deep Teal
      iconColor: Colors.white,
    ),
    PresetTeamLogo(
      id: 'preset:dragons',
      name: 'Fire Dragons',
      defaultCode: 'FD',
      icon: Icons.local_fire_department,
      primaryColor: Color(0xFFDC2626), // Cricket Red
      secondaryColor: Color(0xFF7F1D1D), // Deep Maroon
      iconColor: Color(0xFFFEF08A), // Light Amber accent
    ),
    PresetTeamLogo(
      id: 'preset:eagles',
      name: 'Sky Eagles',
      defaultCode: 'SE',
      icon: Icons.air,
      primaryColor: Color(0xFF4F46E5), // Indigo
      secondaryColor: Color(0xFF312E81), // Dark Indigo
      iconColor: Colors.white,
    ),
  ];

  static PresetTeamLogo? findById(String id) {
    final clean = id.trim().toLowerCase();
    for (final p in presets) {
      if (p.id.toLowerCase() == clean) return p;
    }
    return null;
  }
}

/// Renders team logo badge: preset vector badge, decoded base64, or initial crest
class PresetTeamLogoBadge extends StatelessWidget {
  final String logoKey;
  final String teamName;
  final double size;
  final BorderRadius? borderRadius;

  const PresetTeamLogoBadge({
    super.key,
    required this.logoKey,
    required this.teamName,
    this.size = 36,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(size * 0.28);

    // 1. Check if it's a pre-made vector logo
    if (logoKey.startsWith('preset:')) {
      final preset = TeamPresetCatalog.findById(logoKey);
      if (preset != null) {
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [preset.primaryColor, preset.secondaryColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: radius,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.25),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: preset.secondaryColor.withValues(alpha: 0.25),
                blurRadius: 4,
                offset: const Offset(0, 1.5),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              preset.icon,
              size: size * 0.54,
              color: preset.iconColor,
            ),
          ),
        );
      }
    }

    // 2. Check if base64 encoded photo
    if (logoKey.isNotEmpty && !logoKey.startsWith('http')) {
      try {
        final Uint8List bytes = base64Decode(logoKey);
        return ClipRRect(
          borderRadius: radius,
          child: Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _buildFallback(radius),
          ),
        );
      } catch (_) {}
    }

    // 3. Fallback initials badge
    return _buildFallback(radius);
  }

  Widget _buildFallback(BorderRadius radius) {
    final trimmed = teamName.trim();
    String initials = 'TM';
    if (trimmed.isNotEmpty) {
      final parts = trimmed.split(RegExp(r'\s+'));
      if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
        initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else {
        initials = trimmed.length <= 2
            ? trimmed.toUpperCase()
            : trimmed.substring(0, min(2, trimmed.length)).toUpperCase();
      }
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: PitchTheme.surfaceContainerLow,
        borderRadius: radius,
        border: Border.all(
          color: PitchTheme.hairlineBorder,
          width: 0.9,
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: PitchTheme.slateHeading,
            fontSize: size * 0.38,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

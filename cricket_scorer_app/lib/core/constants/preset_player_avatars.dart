import 'package:flutter/material.dart';

/// Pre-made cricket player identity avatar
class PresetPlayerAvatar {
  final String id;
  final String title;
  final String roleDescription;
  final IconData icon;
  final Color primaryColor;
  final Color secondaryColor;
  final Color iconColor;

  const PresetPlayerAvatar({
    required this.id,
    required this.title,
    required this.roleDescription,
    required this.icon,
    required this.primaryColor,
    required this.secondaryColor,
    this.iconColor = Colors.white,
  });
}

/// 10 Built-In Cricket Player Avatars
class PlayerPresetCatalog {
  static const List<PresetPlayerAvatar> presets = [
    PresetPlayerAvatar(
      id: 'preset:batter',
      title: 'Power Batter',
      roleDescription: 'Heavy-striking batsman',
      icon: Icons.sports_cricket,
      primaryColor: Color(0xFF047857), // Emerald
      secondaryColor: Color(0xFF064E3B),
      iconColor: Colors.white,
    ),
    PresetPlayerAvatar(
      id: 'preset:bowler',
      title: 'Speed Pacer',
      roleDescription: '150kph Express fast bowler',
      icon: Icons.sports_baseball,
      primaryColor: Color(0xFFDC2626), // Cricket Red
      secondaryColor: Color(0xFF7F1D1D),
      iconColor: Colors.white,
    ),
    PresetPlayerAvatar(
      id: 'preset:spinner',
      title: 'Mystery Spinner',
      roleDescription: 'Carrom ball & Doosra specialist',
      icon: Icons.rotate_right,
      primaryColor: Color(0xFF7C3AED), // Violet
      secondaryColor: Color(0xFF4C1D95),
      iconColor: Colors.white,
    ),
    PresetPlayerAvatar(
      id: 'preset:keeper',
      title: 'Golden Keeper',
      roleDescription: 'Lightning gloves behind stumps',
      icon: Icons.front_hand,
      primaryColor: Color(0xFFD97706), // Amber
      secondaryColor: Color(0xFF78350F),
      iconColor: Colors.white,
    ),
    PresetPlayerAvatar(
      id: 'preset:captain',
      title: 'The Skipper',
      roleDescription: 'Master tactician & leader',
      icon: Icons.workspace_premium,
      primaryColor: Color(0xFF0F172A), // Dark Slate
      secondaryColor: Color(0xFF1E293B),
      iconColor: Color(0xFFFDE047), // Gold
    ),
    PresetPlayerAvatar(
      id: 'preset:allrounder',
      title: 'All-Rounder Ace',
      roleDescription: 'Dominates with bat & ball',
      icon: Icons.stars,
      primaryColor: Color(0xFF0284C7), // Sky Blue
      secondaryColor: Color(0xFF0369A1),
      iconColor: Colors.white,
    ),
    PresetPlayerAvatar(
      id: 'preset:opener',
      title: 'Solid Opener',
      roleDescription: 'Technique against the new ball',
      icon: Icons.verified,
      primaryColor: Color(0xFF4F46E5), // Indigo
      secondaryColor: Color(0xFF3730A3),
      iconColor: Colors.white,
    ),
    PresetPlayerAvatar(
      id: 'preset:finisher',
      title: 'Clutch Finisher',
      roleDescription: 'Death overs pressure master',
      icon: Icons.flash_on,
      primaryColor: Color(0xFFEA580C), // Orange
      secondaryColor: Color(0xFF9A3412),
      iconColor: Colors.white,
    ),
    PresetPlayerAvatar(
      id: 'preset:anchor',
      title: 'The Iron Wall',
      roleDescription: 'Impenetrable middle order anchor',
      icon: Icons.shield,
      primaryColor: Color(0xFF334155), // Steel
      secondaryColor: Color(0xFF1E293B),
      iconColor: Colors.white,
    ),
    PresetPlayerAvatar(
      id: 'preset:rookie',
      title: 'Rising Star',
      roleDescription: 'Young prodigy with raw talent',
      icon: Icons.rocket_launch,
      primaryColor: Color(0xFF0D9488), // Teal
      secondaryColor: Color(0xFF115E59),
      iconColor: Colors.white,
    ),
  ];

  static PresetPlayerAvatar? findById(String id) {
    final clean = id.trim().toLowerCase();
    for (final p in presets) {
      if (p.id.toLowerCase() == clean) return p;
    }
    return null;
  }
}

// Player avatar widget: shows player photo if available, otherwise player
// initials or role-specific icon (Batter / Bowler / All-Rounder / Wicket-Keeper).
// Used everywhere a player appears: lists, teams, posters, player-of-match.
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:cricket_scorer_app/services/storage/store.dart';
import 'package:cricket_scorer_app/core/theme/pitch_theme.dart';
import 'package:cricket_scorer_app/core/constants/preset_player_avatars.dart';

/// Returns the Material icon best representing a player role.
IconData roleIcon(String role) {
  final r = role.toLowerCase();
  if (r.contains('bowl') && r.contains('bat') ||
      r.contains('all-rounder') ||
      r.contains('allrounder')) {
    return Icons.sports_cricket;
  }
  if (r.contains('bowl')) {
    return Icons.sports_baseball;
  }
  if (r.contains('keeper') || r.contains('wicket')) {
    return Icons.front_hand;
  }
  return Icons.sports_cricket;
}

/// Cricket theme colors per role.
Color roleColor(String role) {
  final r = role.toLowerCase();
  if (r.contains('bowl') && !r.contains('bat') && !r.contains('all')) {
    return PitchTheme.secondary;
  }
  if (r.contains('all-rounder') || r.contains('allrounder')) {
    return PitchTheme.primaryContainer;
  }
  if (r.contains('keeper') || r.contains('wicket')) {
    return PitchTheme.onSurfaceVariant;
  }
  return PitchTheme.primary;
}

String _getInitials(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '';
  final parts = trimmed.split(RegExp(r'\s+'));
  if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
  return trimmed.substring(0, math.min(2, trimmed.length)).toUpperCase();
}

/// Circular player avatar: photo (base64) when available, otherwise player
/// initials or a fallback icon.
class PlayerAvatar extends StatelessWidget {
  final String? photoBase64;
  final String role;
  final String name;
  final double radius;
  final IconData? fallbackIcon;

  const PlayerAvatar({
    super.key,
    this.photoBase64,
    this.role = 'Batter',
    this.name = '',
    this.radius = 20,
    this.fallbackIcon,
  });

  @override
  Widget build(BuildContext context) {
    if (photoBase64 != null && photoBase64!.startsWith('preset:')) {
      final preset = PlayerPresetCatalog.findById(photoBase64!);
      if (preset != null) {
        return Container(
          width: radius * 2,
          height: radius * 2,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [preset.primaryColor, preset.secondaryColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.35),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: preset.secondaryColor.withValues(alpha: 0.3),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              preset.icon,
              size: radius * 1.05,
              color: preset.iconColor,
            ),
          ),
        );
      }
    }

    if (photoBase64 != null && photoBase64!.isNotEmpty) {
      try {
        final Uint8List bytes = base64Decode(photoBase64!);
        return CircleAvatar(
          radius: radius,
          backgroundColor: PitchTheme.surfaceContainerLow,
          backgroundImage: MemoryImage(bytes),
          onBackgroundImageError: (_, _) {},
        );
      } catch (_) {
        // Fall through to initials/icon on bad data.
      }
    }

    final initials = _getInitials(name);
    if (initials.isNotEmpty && fallbackIcon == null) {
      return Container(
        width: radius * 2,
        height: radius * 2,
        decoration: const BoxDecoration(
          color: PitchTheme.surfaceContainerLow,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            initials,
            style: TextStyle(
              color: PitchTheme.primary,
              fontWeight: FontWeight.w900,
              fontSize: radius * 0.8,
            ),
          ),
        ),
      );
    }

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: const BoxDecoration(
        color: PitchTheme.surfaceContainerLow,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          fallbackIcon ?? roleIcon(role),
          color: roleColor(role),
          size: radius * 1.1,
        ),
      ),
    );
  }
}

/// v1.1.7: Team avatar replaced by the assigned captain's actual photo.
class CaptainAvatar extends StatelessWidget {
  final Store store;
  final String teamId;
  final double radius;

  const CaptainAvatar({
    super.key,
    required this.store,
    required this.teamId,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    String? photo;
    String captainName = '';
    final t = store.teamById(teamId);
    if (t != null) {
      for (final p in t.players) {
        if (p.isCaptain) {
          captainName = p.name;
          final ph = store.photoForPlayer(p.id);
          if (ph.isNotEmpty) photo = ph;
          break;
        }
      }
      if (captainName.isEmpty && t.players.isNotEmpty) {
        captainName = t.players.first.name;
      }
    }
    return PlayerAvatar(
      photoBase64: photo,
      name: captainName.isNotEmpty ? captainName : (t?.name ?? ''),
      radius: radius,
      fallbackIcon: photo == null && captainName.isEmpty ? Icons.shield_outlined : null,
    );
  }
}

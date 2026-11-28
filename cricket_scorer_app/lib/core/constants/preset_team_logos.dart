import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:cricket_scorer_app/core/theme/pitch_theme.dart';

/// Vector emblem style drawn inside the team shield crest
enum CrestEmblem {
  tigerClaw,
  royalLion,
  falconWings,
  thunderBall,
  royalCrown,
  crossedBlades,
  titanHelmet,
  knightVisor,
  pantherEyes,
  sharkFin,
  dragonFlame,
  eagleSpread,
  crossedBats,
  cricketStumps,
  blazingBall,
  wolfFangs,
  bullHorns,
  viperFangs,
  phoenixRise,
  trophyStar,
}

/// Pre-made sports franchise team logo definition
class PresetTeamLogo {
  final String id;
  final String name;
  final String defaultCode;
  final CrestEmblem emblem;
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;

  const PresetTeamLogo({
    required this.id,
    required this.name,
    required this.defaultCode,
    required this.emblem,
    required this.primaryColor,
    required this.secondaryColor,
    this.accentColor = Colors.white,
  });
}

/// 20 Proper Cricket & Sports Franchise Vector Crest Logos
class TeamPresetCatalog {
  static const List<PresetTeamLogo> presets = [
    PresetTeamLogo(
      id: 'preset:batsmen',
      name: 'Power Hitters',
      defaultCode: 'PH',
      emblem: CrestEmblem.crossedBats,
      primaryColor: Color(0xFF006D36),
      secondaryColor: Color(0xFF00261B),
      accentColor: Color(0xFFBBF540),
    ),
    PresetTeamLogo(
      id: 'preset:stumps',
      name: 'Stumps XI',
      defaultCode: 'SXI',
      emblem: CrestEmblem.cricketStumps,
      primaryColor: Color(0xFF0B3D2E),
      secondaryColor: Color(0xFF001A12),
      accentColor: Color(0xFFFACC15),
    ),
    PresetTeamLogo(
      id: 'preset:fireballs',
      name: 'Fireballs',
      defaultCode: 'FB',
      emblem: CrestEmblem.blazingBall,
      primaryColor: Color(0xFFDC2626),
      secondaryColor: Color(0xFF7F1D1D),
      accentColor: Color(0xFFFDE047),
    ),
    PresetTeamLogo(
      id: 'preset:tigers',
      name: 'Bengal Tigers',
      defaultCode: 'BT',
      emblem: CrestEmblem.tigerClaw,
      primaryColor: Color(0xFFEA580C),
      secondaryColor: Color(0xFF7C2D12),
      accentColor: Color(0xFFFEF08A),
    ),
    PresetTeamLogo(
      id: 'preset:lions',
      name: 'Royal Lions',
      defaultCode: 'RL',
      emblem: CrestEmblem.royalLion,
      primaryColor: Color(0xFFD97706),
      secondaryColor: Color(0xFF78350F),
      accentColor: Color(0xFFFFFBEB),
    ),
    PresetTeamLogo(
      id: 'preset:kings',
      name: 'Golden Kings',
      defaultCode: 'GK',
      emblem: CrestEmblem.royalCrown,
      primaryColor: Color(0xFF9333EA),
      secondaryColor: Color(0xFF4C1D95),
      accentColor: Color(0xFFFDE047),
    ),
    PresetTeamLogo(
      id: 'preset:strikers',
      name: 'Thunder Strikers',
      defaultCode: 'TS',
      emblem: CrestEmblem.thunderBall,
      primaryColor: Color(0xFF2563EB),
      secondaryColor: Color(0xFF1E3A8A),
      accentColor: Color(0xFFFACC15),
    ),
    PresetTeamLogo(
      id: 'preset:falcons',
      name: 'Desert Falcons',
      defaultCode: 'DF',
      emblem: CrestEmblem.falconWings,
      primaryColor: Color(0xFF0284C7),
      secondaryColor: Color(0xFF0C4A6E),
      accentColor: Color(0xFFE0F2FE),
    ),
    PresetTeamLogo(
      id: 'preset:warriors',
      name: 'Emerald Warriors',
      defaultCode: 'EW',
      emblem: CrestEmblem.crossedBlades,
      primaryColor: Color(0xFF059669),
      secondaryColor: Color(0xFF064E3B),
      accentColor: Color(0xFFA7F3D0),
    ),
    PresetTeamLogo(
      id: 'preset:titans',
      name: 'Iron Titans',
      defaultCode: 'IT',
      emblem: CrestEmblem.titanHelmet,
      primaryColor: Color(0xFF475569),
      secondaryColor: Color(0xFF0F172A),
      accentColor: Color(0xFF38BDF8),
    ),
    PresetTeamLogo(
      id: 'preset:knights',
      name: 'Storm Knights',
      defaultCode: 'SK',
      emblem: CrestEmblem.knightVisor,
      primaryColor: Color(0xFF1D4ED8),
      secondaryColor: Color(0xFF172554),
      accentColor: Color(0xFFBAE6FD),
    ),
    PresetTeamLogo(
      id: 'preset:panthers',
      name: 'Shadow Panthers',
      defaultCode: 'SP',
      emblem: CrestEmblem.pantherEyes,
      primaryColor: Color(0xFF1E293B),
      secondaryColor: Color(0xFF020617),
      accentColor: Color(0xFF38BDF8),
    ),
    PresetTeamLogo(
      id: 'preset:sharks',
      name: 'Ocean Sharks',
      defaultCode: 'OS',
      emblem: CrestEmblem.sharkFin,
      primaryColor: Color(0xFF0D9488),
      secondaryColor: Color(0xFF134E4A),
      accentColor: Color(0xFF99F6E4),
    ),
    PresetTeamLogo(
      id: 'preset:dragons',
      name: 'Fire Dragons',
      defaultCode: 'FD',
      emblem: CrestEmblem.dragonFlame,
      primaryColor: Color(0xFFB91C1C),
      secondaryColor: Color(0xFF450A0A),
      accentColor: Color(0xFFFDBA74),
    ),
    PresetTeamLogo(
      id: 'preset:eagles',
      name: 'Sky Eagles',
      defaultCode: 'SE',
      emblem: CrestEmblem.eagleSpread,
      primaryColor: Color(0xFF4F46E5),
      secondaryColor: Color(0xFF312E81),
      accentColor: Color(0xFFE0E7FF),
    ),
    PresetTeamLogo(
      id: 'preset:wolves',
      name: 'Arctic Wolves',
      defaultCode: 'AW',
      emblem: CrestEmblem.wolfFangs,
      primaryColor: Color(0xFF334155),
      secondaryColor: Color(0xFF0F172A),
      accentColor: Color(0xFF7DD3FC),
    ),
    PresetTeamLogo(
      id: 'preset:bulls',
      name: 'Raging Bulls',
      defaultCode: 'RB',
      emblem: CrestEmblem.bullHorns,
      primaryColor: Color(0xFF991B1B),
      secondaryColor: Color(0xFF450A0A),
      accentColor: Color(0xFFFDE047),
    ),
    PresetTeamLogo(
      id: 'preset:vipers',
      name: 'Venom Vipers',
      defaultCode: 'VV',
      emblem: CrestEmblem.viperFangs,
      primaryColor: Color(0xFF15803D),
      secondaryColor: Color(0xFF052E16),
      accentColor: Color(0xFFBBF540),
    ),
    PresetTeamLogo(
      id: 'preset:phoenix',
      name: 'Rising Phoenix',
      defaultCode: 'RP',
      emblem: CrestEmblem.phoenixRise,
      primaryColor: Color(0xFFDB2777),
      secondaryColor: Color(0xFF831843),
      accentColor: Color(0xFFFDE047),
    ),
    PresetTeamLogo(
      id: 'preset:stars',
      name: 'Super Stars',
      defaultCode: 'SS',
      emblem: CrestEmblem.trophyStar,
      primaryColor: Color(0xFF0369A1),
      secondaryColor: Color(0xFF082F49),
      accentColor: Color(0xFFFACC15),
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

/// Renders team logo badge: preset vector crest, asset image, decoded base64, or initial crest
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

    // 1. Check if it's a pre-made vector crest logo
    if (logoKey.startsWith('preset:')) {
      final preset = TeamPresetCatalog.findById(logoKey);
      if (preset != null) {
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _SportsCrestPainter(preset: preset),
          ),
        );
      }
    }

    // 2. Check if it's an asset image path
    if (logoKey.startsWith('assets/')) {
      return ClipRRect(
        borderRadius: radius,
        child: Image.asset(
          logoKey,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _buildFallback(radius),
        ),
      );
    }

    // 3. Check if it's a base64 image string
    if (logoKey.isNotEmpty && !logoKey.startsWith('preset:')) {
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

    // 4. Fallback initials badge
    return _buildFallback(radius);
  }

  Widget _buildFallback(BorderRadius radius) {
    final trimmed = teamName.trim();
    final initials = trimmed.isEmpty
        ? 'TM'
        : (trimmed.length >= 2
            ? trimmed.substring(0, 2).toUpperCase()
            : trimmed[0].toUpperCase());

    final palette = [
      const [Color(0xFF0B3D2E), Color(0xFF00261B)],
      const [Color(0xFF1E3A8A), Color(0xFF172554)],
      const [Color(0xFF7C2D12), Color(0xFF431407)],
      const [Color(0xFF581C87), Color(0xFF3B0764)],
      const [Color(0xFF0F766E), Color(0xFF134E4A)],
    ];
    final hash = teamName.codeUnits.fold(0, (a, b) => a + b);
    final colors = palette[hash % palette.length];

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: radius,
        border: Border.all(
          color: PitchTheme.outlineVariant.withValues(alpha: 0.4),
          width: 1.0,
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: max(10, size * 0.35),
            fontWeight: FontWeight.w900,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

/// Draws a crisp heraldic sports shield with custom cricket/mascot vector art
class _SportsCrestPainter extends CustomPainter {
  final PresetTeamLogo preset;

  const _SportsCrestPainter({required this.preset});

  Path _buildShieldPath(double w, double h) {
    return Path()
      ..moveTo(w * 0.5, h * 0.04)
      ..lineTo(w * 0.90, h * 0.16)
      ..quadraticBezierTo(w * 0.92, h * 0.58, w * 0.5, h * 0.96)
      ..quadraticBezierTo(w * 0.08, h * 0.58, w * 0.10, h * 0.16)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final shield = _buildShieldPath(w, h);

    // Subtle drop shadow
    canvas.drawShadow(shield, Colors.black.withValues(alpha: 0.35), w * 0.08, true);

    // Shield gradient fill
    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [preset.primaryColor, preset.secondaryColor],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(shield, fillPaint);

    // Diagonal gloss highlight (clipped to shield)
    canvas.save();
    canvas.clipPath(shield);
    final sheenPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    final sheen = Path()
      ..moveTo(0, 0)
      ..lineTo(w * 0.65, 0)
      ..lineTo(w * 0.25, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(sheen, sheenPaint);
    canvas.restore();

    // Metallic / accent outer border
    final borderPaint = Paint()
      ..color = preset.accentColor.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.2, w * 0.055)
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(shield, borderPaint);

    // Draw center vector emblem
    _drawEmblem(canvas, w, h);
  }

  void _drawEmblem(Canvas canvas, double w, double h) {
    final fill = Paint()
      ..color = preset.accentColor
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = preset.accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.4, w * 0.06)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final darkCut = Paint()
      ..color = preset.secondaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.0, w * 0.04)
      ..strokeCap = StrokeCap.round;

    switch (preset.emblem) {
      case CrestEmblem.crossedBats:
        // Two crossed cricket bats + cricket ball at top
        for (final sign in [-1.0, 1.0]) {
          canvas.save();
          canvas.translate(w * 0.5, h * 0.52);
          canvas.rotate(sign * 0.62);
          // Bat blade
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset(0, h * 0.04), width: w * 0.12, height: h * 0.34),
              Radius.circular(w * 0.03),
            ),
            fill,
          );
          // Bat handle
          canvas.drawLine(Offset(0, -h * 0.13), Offset(0, -h * 0.27), stroke);
          canvas.restore();
        }
        canvas.drawCircle(Offset(w * 0.5, h * 0.28), w * 0.075, fill);
        break;

      case CrestEmblem.cricketStumps:
        // Three vertical stumps + two bails on top
        for (final dx in [-0.14, 0.0, 0.14]) {
          canvas.drawLine(
            Offset(w * (0.5 + dx), h * 0.28),
            Offset(w * (0.5 + dx), h * 0.74),
            stroke..strokeWidth = max(1.4, w * 0.065),
          );
        }
        // Bails
        canvas.drawLine(Offset(w * 0.33, h * 0.27), Offset(w * 0.49, h * 0.25), stroke..strokeWidth = max(1.2, w * 0.05));
        canvas.drawLine(Offset(w * 0.51, h * 0.25), Offset(w * 0.67, h * 0.27), stroke);
        break;

      case CrestEmblem.blazingBall:
        // Cricket ball + 3 flame trails
        canvas.drawCircle(Offset(w * 0.54, h * 0.55), w * 0.16, fill);
        canvas.drawArc(
          Rect.fromCircle(center: Offset(w * 0.54, h * 0.55), radius: w * 0.11),
          -0.8,
          2.2,
          false,
          darkCut,
        );
        final flame = Path()
          ..moveTo(w * 0.42, h * 0.40)
          ..lineTo(w * 0.24, h * 0.26)
          ..lineTo(w * 0.34, h * 0.46)
          ..lineTo(w * 0.20, h * 0.50)
          ..lineTo(w * 0.36, h * 0.62);
        canvas.drawPath(flame, stroke);
        break;

      case CrestEmblem.tigerClaw:
        // Three fierce diagonal claw slashes
        for (var i = -1; i <= 1; i++) {
          final offset = i * w * 0.12;
          final claw = Path()
            ..moveTo(w * 0.30 + offset, h * 0.28)
            ..quadraticBezierTo(w * 0.50 + offset, h * 0.48, w * 0.64 + offset * 0.6, h * 0.72);
          canvas.drawPath(claw, stroke..strokeWidth = max(1.5, w * 0.075));
        }
        break;

      case CrestEmblem.royalLion:
        // Crowned lion mane hexagon + inner roar core
        final mane = Path();
        for (var i = 0; i < 8; i++) {
          final angle = (i * pi / 4) - pi / 2;
          final r = i.isEven ? w * 0.24 : w * 0.17;
          final pt = Offset(w * 0.5 + cos(angle) * r, h * 0.52 + sin(angle) * r);
          if (i == 0) {
            mane.moveTo(pt.dx, pt.dy);
          } else {
            mane.lineTo(pt.dx, pt.dy);
          }
        }
        mane.close();
        canvas.drawPath(mane, fill);
        canvas.drawCircle(Offset(w * 0.5, h * 0.52), w * 0.09, Paint()..color = preset.secondaryColor);
        break;

      case CrestEmblem.royalCrown:
        final crown = Path()
          ..moveTo(w * 0.24, h * 0.65)
          ..lineTo(w * 0.22, h * 0.36)
          ..lineTo(w * 0.38, h * 0.50)
          ..lineTo(w * 0.50, h * 0.28)
          ..lineTo(w * 0.62, h * 0.50)
          ..lineTo(w * 0.78, h * 0.36)
          ..lineTo(w * 0.76, h * 0.65)
          ..close();
        canvas.drawPath(crown, fill);
        canvas.drawRect(Rect.fromLTWH(w * 0.24, h * 0.68, w * 0.52, h * 0.07), fill);
        break;

      case CrestEmblem.thunderBall:
        final bolt = Path()
          ..moveTo(w * 0.56, h * 0.22)
          ..lineTo(w * 0.34, h * 0.52)
          ..lineTo(w * 0.49, h * 0.52)
          ..lineTo(w * 0.42, h * 0.78)
          ..lineTo(w * 0.68, h * 0.45)
          ..lineTo(w * 0.52, h * 0.45)
          ..close();
        canvas.drawPath(bolt, fill);
        break;

      case CrestEmblem.falconWings:
        final wings = Path()
          ..moveTo(w * 0.50, h * 0.34)
          ..lineTo(w * 0.80, h * 0.28)
          ..lineTo(w * 0.66, h * 0.48)
          ..lineTo(w * 0.74, h * 0.56)
          ..lineTo(w * 0.50, h * 0.72)
          ..lineTo(w * 0.26, h * 0.56)
          ..lineTo(w * 0.34, h * 0.48)
          ..lineTo(w * 0.20, h * 0.28)
          ..close();
        canvas.drawPath(wings, fill);
        break;

      case CrestEmblem.crossedBlades:
        for (final sign in [-1.0, 1.0]) {
          canvas.save();
          canvas.translate(w * 0.5, h * 0.5);
          canvas.rotate(sign * 0.72);
          final blade = Path()
            ..moveTo(0, -h * 0.28)
            ..lineTo(w * 0.055, h * 0.14)
            ..lineTo(-w * 0.055, h * 0.14)
            ..close();
          canvas.drawPath(blade, fill);
          canvas.drawLine(Offset(-w * 0.10, h * 0.15), Offset(w * 0.10, h * 0.15), stroke);
          canvas.drawLine(Offset(0, h * 0.15), Offset(0, h * 0.26), stroke);
          canvas.restore();
        }
        break;

      case CrestEmblem.titanHelmet:
        final helmet = Path()
          ..moveTo(w * 0.50, h * 0.22)
          ..quadraticBezierTo(w * 0.75, h * 0.26, w * 0.72, h * 0.58)
          ..lineTo(w * 0.62, h * 0.74)
          ..lineTo(w * 0.55, h * 0.74)
          ..lineTo(w * 0.55, h * 0.52)
          ..lineTo(w * 0.45, h * 0.52)
          ..lineTo(w * 0.45, h * 0.74)
          ..lineTo(w * 0.38, h * 0.74)
          ..lineTo(w * 0.28, h * 0.58)
          ..quadraticBezierTo(w * 0.25, h * 0.26, w * 0.50, h * 0.22)
          ..close();
        canvas.drawPath(helmet, fill);
        break;

      case CrestEmblem.knightVisor:
        final visor = Path()
          ..moveTo(w * 0.30, h * 0.32)
          ..lineTo(w * 0.50, h * 0.24)
          ..lineTo(w * 0.70, h * 0.32)
          ..lineTo(w * 0.66, h * 0.66)
          ..lineTo(w * 0.50, h * 0.76)
          ..lineTo(w * 0.34, h * 0.66)
          ..close();
        canvas.drawPath(visor, fill);
        canvas.drawLine(Offset(w * 0.35, h * 0.46), Offset(w * 0.65, h * 0.46), darkCut);
        canvas.drawLine(Offset(w * 0.50, h * 0.34), Offset(w * 0.50, h * 0.68), darkCut);
        break;

      case CrestEmblem.pantherEyes:
        // Fierce slanted eyes + central nose chevron
        final leftEye = Path()
          ..moveTo(w * 0.24, h * 0.40)
          ..lineTo(w * 0.44, h * 0.48)
          ..lineTo(w * 0.30, h * 0.52)
          ..close();
        final rightEye = Path()
          ..moveTo(w * 0.76, h * 0.40)
          ..lineTo(w * 0.56, h * 0.48)
          ..lineTo(w * 0.70, h * 0.52)
          ..close();
        canvas.drawPath(leftEye, fill);
        canvas.drawPath(rightEye, fill);
        final snout = Path()
          ..moveTo(w * 0.42, h * 0.62)
          ..lineTo(w * 0.50, h * 0.72)
          ..lineTo(w * 0.58, h * 0.62);
        canvas.drawPath(snout, stroke);
        break;

      case CrestEmblem.sharkFin:
        final fin = Path()
          ..moveTo(w * 0.28, h * 0.62)
          ..quadraticBezierTo(w * 0.38, h * 0.26, w * 0.64, h * 0.24)
          ..quadraticBezierTo(w * 0.56, h * 0.46, w * 0.72, h * 0.62)
          ..close();
        canvas.drawPath(fin, fill);
        final wave = Path()
          ..moveTo(w * 0.22, h * 0.70)
          ..quadraticBezierTo(w * 0.36, h * 0.63, w * 0.50, h * 0.70)
          ..quadraticBezierTo(w * 0.64, h * 0.77, w * 0.78, h * 0.70);
        canvas.drawPath(wave, stroke);
        break;

      case CrestEmblem.dragonFlame:
        final dragon = Path()
          ..moveTo(w * 0.50, h * 0.22)
          ..quadraticBezierTo(w * 0.76, h * 0.42, w * 0.64, h * 0.72)
          ..lineTo(w * 0.50, h * 0.58)
          ..lineTo(w * 0.36, h * 0.72)
          ..quadraticBezierTo(w * 0.24, h * 0.42, w * 0.50, h * 0.22)
          ..close();
        canvas.drawPath(dragon, fill);
        break;

      case CrestEmblem.eagleSpread:
        final eagle = Path()
          ..moveTo(w * 0.20, h * 0.34)
          ..lineTo(w * 0.44, h * 0.40)
          ..lineTo(w * 0.50, h * 0.26)
          ..lineTo(w * 0.56, h * 0.40)
          ..lineTo(w * 0.80, h * 0.34)
          ..lineTo(w * 0.64, h * 0.58)
          ..lineTo(w * 0.50, h * 0.74)
          ..lineTo(w * 0.36, h * 0.58)
          ..close();
        canvas.drawPath(eagle, fill);
        break;

      case CrestEmblem.wolfFangs:
        final wolf = Path()
          ..moveTo(w * 0.28, h * 0.28)
          ..lineTo(w * 0.42, h * 0.42)
          ..lineTo(w * 0.58, h * 0.42)
          ..lineTo(w * 0.72, h * 0.28)
          ..lineTo(w * 0.68, h * 0.60)
          ..lineTo(w * 0.50, h * 0.76)
          ..lineTo(w * 0.32, h * 0.60)
          ..close();
        canvas.drawPath(wolf, fill);
        break;

      case CrestEmblem.bullHorns:
        final horns = Path()
          ..moveTo(w * 0.22, h * 0.28)
          ..quadraticBezierTo(w * 0.24, h * 0.54, w * 0.50, h * 0.54)
          ..quadraticBezierTo(w * 0.76, h * 0.54, w * 0.78, h * 0.28)
          ..quadraticBezierTo(w * 0.68, h * 0.44, w * 0.50, h * 0.44)
          ..quadraticBezierTo(w * 0.32, h * 0.44, w * 0.22, h * 0.28)
          ..close();
        canvas.drawPath(horns, fill);
        canvas.drawCircle(Offset(w * 0.50, h * 0.66), w * 0.08, stroke);
        break;

      case CrestEmblem.viperFangs:
        final hood = Path()
          ..moveTo(w * 0.50, h * 0.24)
          ..quadraticBezierTo(w * 0.76, h * 0.34, w * 0.68, h * 0.58)
          ..lineTo(w * 0.56, h * 0.58)
          ..lineTo(w * 0.56, h * 0.74)
          ..lineTo(w * 0.44, h * 0.74)
          ..lineTo(w * 0.44, h * 0.58)
          ..lineTo(w * 0.32, h * 0.58)
          ..quadraticBezierTo(w * 0.24, h * 0.34, w * 0.50, h * 0.24)
          ..close();
        canvas.drawPath(hood, fill);
        break;

      case CrestEmblem.phoenixRise:
        final phoenix = Path()
          ..moveTo(w * 0.50, h * 0.22)
          ..lineTo(w * 0.62, h * 0.42)
          ..lineTo(w * 0.80, h * 0.32)
          ..lineTo(w * 0.68, h * 0.60)
          ..lineTo(w * 0.50, h * 0.76)
          ..lineTo(w * 0.32, h * 0.60)
          ..lineTo(w * 0.20, h * 0.32)
          ..lineTo(w * 0.38, h * 0.42)
          ..close();
        canvas.drawPath(phoenix, fill);
        break;

      case CrestEmblem.trophyStar:
        final star = Path();
        for (var i = 0; i < 10; i++) {
          final angle = (i * pi / 5) - pi / 2;
          final r = i.isEven ? w * 0.25 : w * 0.11;
          final pt = Offset(w * 0.5 + cos(angle) * r, h * 0.50 + sin(angle) * r);
          if (i == 0) {
            star.moveTo(pt.dx, pt.dy);
          } else {
            star.lineTo(pt.dx, pt.dy);
          }
        }
        star.close();
        canvas.drawPath(star, fill);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _SportsCrestPainter oldDelegate) {
    return oldDelegate.preset.id != preset.id;
  }
}

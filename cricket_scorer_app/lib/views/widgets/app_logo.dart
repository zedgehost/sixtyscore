// 60Score official vector brand logo and emblem.
// Designed according to the Pitch Dynamic design system.
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cricket_scorer_app/core/theme/pitch_theme.dart';

/// Premier 60Score brand logo and emblem.
/// Rendered with vector precision using modern cricket telemetry design.
class AppLogo extends StatelessWidget {
  final double height;
  final bool showText;
  final bool isDark;

  const AppLogo({
    super.key,
    required this.height,
    this.showText = false,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final badge = Score60LogoBadge(size: height);
    if (!showText) return badge;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        badge,
        SizedBox(width: height * 0.22),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '60',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontWeight: FontWeight.w900,
                    fontSize: height * 0.52,
                    letterSpacing: -1.0,
                    color: isDark ? Colors.white : PitchTheme.primary,
                  ),
                ),
                Text(
                  'Score',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontWeight: FontWeight.w900,
                    fontSize: height * 0.52,
                    letterSpacing: 0.5,
                    color: isDark ? PitchTheme.tertiaryFixed : PitchTheme.secondary,
                  ),
                ),
              ],
            ),
            Text(
              'CRICKET SCORER',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: (height * 0.18).clamp(8.0, 14.0),
                letterSpacing: 1.4,
                color: isDark ? Colors.white70 : PitchTheme.outline,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The official 60Score emblem:
/// Deep forest cricket green squircle badge with metallic border,
/// athletic italic '60', vibrant cricket seam ball, and electric neon lime telemetry arc.
class Score60LogoBadge extends StatelessWidget {
  final double size;
  const Score60LogoBadge({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            PitchTheme.primaryContainer,
            PitchTheme.primary,
            Color(0xFF00150F),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: PitchTheme.primary.withValues(alpha: 0.35),
            blurRadius: size * 0.25,
            offset: Offset(0, size * 0.08),
          ),
        ],
        border: Border.all(
          color: PitchTheme.tertiaryFixed.withValues(alpha: 0.4),
          width: (size * 0.04).clamp(1.0, 2.5),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.24),
        child: CustomPaint(
          size: Size(size, size),
          painter: _Score60EmblemPainter(),
        ),
      ),
    );
  }
}

class _Score60EmblemPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Subtle cricket pitch telemetry lines in background
    final pitchPaint = Paint()
      ..color = PitchTheme.tertiaryFixed.withValues(alpha: 0.10)
      ..strokeWidth = (w * 0.02).clamp(0.8, 1.5)
      ..style = PaintingStyle.stroke;

    final pitchPath = Path();
    pitchPath.moveTo(w * 0.15, h * 0.82);
    pitchPath.lineTo(w * 0.85, h * 0.18);
    canvas.drawPath(pitchPath, pitchPaint);

    // Dynamic curved seam arc behind the numbers
    final arcPaint = Paint()
      ..color = PitchTheme.tertiaryFixed.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (w * 0.03).clamp(1.0, 2.0);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(w * 0.5, h * 0.5), radius: w * 0.38),
      -math.pi / 4,
      math.pi / 1.8,
      false,
      arcPaint,
    );

    // 2. Bold athletic '60'
    final textPainter = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: '6',
            style: TextStyle(
              fontSize: w * 0.52,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
              color: Colors.white,
              letterSpacing: -1.0,
            ),
          ),
          TextSpan(
            text: '0',
            style: TextStyle(
              fontSize: w * 0.52,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
              color: PitchTheme.tertiaryFixed,
              letterSpacing: -1.0,
            ),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final textX = (w - textPainter.width) / 2;
    final textY = (h - textPainter.height) / 2 - (h * 0.02);
    textPainter.paint(canvas, Offset(textX, textY));

    // 3. Mini red cricket ball with white seam integrated in lower right
    final ballRadius = (w * 0.11).clamp(2.5, 9.0);
    final ballCenter = Offset(w * 0.78, h * 0.76);

    // Ball glow
    final glowPaint = Paint()
      ..color = PitchTheme.error.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(ballCenter, ballRadius + 1.5, glowPaint);

    // Ball body
    final ballPaint = Paint()
      ..shader = const RadialGradient(
        colors: [
          Color(0xFFEF5350),
          PitchTheme.error,
          Color(0xFF7F0000),
        ],
        center: Alignment(-0.3, -0.3),
      ).createShader(Rect.fromCircle(center: ballCenter, radius: ballRadius));
    canvas.drawCircle(ballCenter, ballRadius, ballPaint);

    // Cricket ball seam
    final seamPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (ballRadius * 0.22).clamp(0.6, 1.2);
    final seamPath = Path();
    seamPath.moveTo(ballCenter.dx - ballRadius * 0.7, ballCenter.dy + ballRadius * 0.5);
    seamPath.quadraticBezierTo(
      ballCenter.dx,
      ballCenter.dy,
      ballCenter.dx + ballRadius * 0.7,
      ballCenter.dy - ballRadius * 0.5,
    );
    canvas.drawPath(seamPath, seamPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

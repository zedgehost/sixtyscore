// Simple charts drawn with CustomPainter — no chart package needed.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:cricket_scorer_app/domain/scoring/scoring.dart';
import 'package:cricket_scorer_app/core/theme/pitch_theme.dart';

/// Runs comparison (worm): cumulative runs per over for two innings.
class WormChart extends StatelessWidget {
  final List<int> innings1;
  final List<int> innings2;
  final String label1;
  final String label2;
  const WormChart({
    super.key,
    required this.innings1,
    required this.innings2,
    required this.label1,
    required this.label2,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.show_chart, size: 16, color: PitchTheme.primary),
            const SizedBox(width: 4),
            Text(
              label1,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: PitchTheme.onSurface,
              ),
            ),
            if (label2.isNotEmpty) ...[
              const SizedBox(width: 14),
              const Icon(Icons.show_chart, size: 16, color: PitchTheme.secondary),
              const SizedBox(width: 4),
              Text(
                label2,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: PitchTheme.onSurface,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 160,
          width: double.infinity,
          child: CustomPaint(painter: _WormPainter(innings1, innings2)),
        ),
      ],
    );
  }
}

class _WormPainter extends CustomPainter {
  final List<int> a;
  final List<int> b;
  _WormPainter(this.a, this.b);

  void _drawLine(
    Canvas canvas,
    List<int> data,
    Color color,
    double maxX,
    double maxY,
    Size size,
  ) {
    if (data.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final path = Path();
    for (var i = 0; i < data.length; i++) {
      final x = (i + 1) / maxX * size.width;
      final y = size.height - (data[i] / maxY * size.height);
      if (i == 0) {
        path.moveTo(0, size.height);
        path.lineTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
    final dot = Paint()..color = color;
    for (var i = 0; i < data.length; i++) {
      final x = (i + 1) / maxX * size.width;
      final y = size.height - (data[i] / maxY * size.height);
      canvas.drawCircle(Offset(x, y), 3, dot);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = PitchTheme.outlineVariant.withValues(alpha: 0.5)
      ..strokeWidth = 0.8;
    for (var i = 0; i <= 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final maxLen = math.max(a.length, b.length);
    if (maxLen == 0) return;
    final maxY = math.max(
      a.isEmpty ? 0 : a.reduce(math.max),
      b.isEmpty ? 0 : b.reduce(math.max),
    );
    _drawLine(
      canvas,
      a,
      PitchTheme.primary,
      maxLen.toDouble(),
      (maxY == 0 ? 1 : maxY).toDouble(),
      size,
    );
    _drawLine(
      canvas,
      b,
      PitchTheme.secondary,
      maxLen.toDouble(),
      (maxY == 0 ? 1 : maxY).toDouble(),
      size,
    );
  }

  @override
  bool shouldRepaint(covariant _WormPainter old) => old.a != a || old.b != b;
}

/// Over comparison (Manhattan): bars of runs per over.
class ManhattanChart extends StatelessWidget {
  final List<int> innings1;
  final List<int> innings2;
  const ManhattanChart({
    super.key,
    required this.innings1,
    required this.innings2,
  });

  @override
  Widget build(BuildContext context) {
    final maxLen = math.max(innings1.length, innings2.length);
    final maxVal = [...innings1, ...innings2, 1].reduce(math.max);
    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < maxLen; i++)
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (i < innings1.length)
                    Container(
                      width: 9,
                      height: 130 * innings1[i] / maxVal + 2,
                      decoration: const BoxDecoration(
                        color: PitchTheme.primary,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(2)),
                      ),
                    ),
                  if (i < innings2.length) ...[
                    const SizedBox(width: 2),
                    Container(
                      width: 9,
                      height: 130 * innings2[i] / maxVal + 2,
                      decoration: const BoxDecoration(
                        color: PitchTheme.secondary,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(2)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Wagon wheel: free-touch shot plot drawn as trajectory lines.
class WagonWheel extends StatelessWidget {
  final List<ShotPlot> shots;
  final double diameter;
  const WagonWheel({super.key, required this.shots, this.diameter = 240});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: diameter,
      width: diameter,
      child: CustomPaint(painter: _WagonPainter(shots)),
    );
  }
}

/// Color for a wagon-wheel shot: six = green, wicket = red, others split.
Color wagonShotColor(int runs, bool isWicket) {
  if (isWicket) return const Color(0xFFEF5350);
  switch (runs) {
    case 6:
      return const Color(0xFF66BB6A);
    case 4:
      return const Color(0xFF42A5F5);
    case 3:
      return const Color(0xFFAB47BC);
    case 2:
      return const Color(0xFFFFA726);
    case 1:
      return const Color(0xFFFFD54F);
    default:
      return const Color(0xFF9E9E9E);
  }
}

/// Compact color legend for the wagon wheel.
class WagonLegend extends StatelessWidget {
  final Color? textColor;
  const WagonLegend({super.key, this.textColor});

  @override
  Widget build(BuildContext context) {
    final effectiveColor = textColor ?? Colors.white70;
    Widget item(int runs, String label, {bool wicket = false}) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: 4,
              decoration: BoxDecoration(
                color: wagonShotColor(runs, wicket),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: effectiveColor,
              ),
            ),
          ],
        );
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: [
        item(1, '1'),
        item(2, '2'),
        item(3, '3'),
        item(4, '4'),
        item(6, '6'),
        item(0, 'W', wicket: true),
      ],
    );
  }
}

class _WagonPainter extends CustomPainter {
  final List<ShotPlot> shots;
  _WagonPainter(this.shots);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    final linePaint = Paint()
      ..color = Colors.white60
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    // boundary + inner circle
    canvas.drawCircle(center, radius, linePaint);
    canvas.drawCircle(center, radius * 0.45, linePaint);
    // crosshair guides
    canvas.drawLine(
      Offset(center.dx - radius, center.dy),
      Offset(center.dx + radius, center.dy),
      linePaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - radius),
      Offset(center.dx, center.dy + radius),
      linePaint,
    );
    // pitch
    final pitch = Paint()..color = const Color(0xFFC4A482);
    canvas.drawRect(
      Rect.fromCenter(center: center, width: 14, height: 60),
      pitch,
    );
    // shots as trajectory lines
    for (final s in shots) {
      final dist = math.sqrt(s.x * s.x + s.y * s.y);
      final ux = dist < 0.01 ? 1.0 : s.x / dist;
      final uy = dist < 0.01 ? 0.0 : s.y / dist;
      final color = wagonShotColor(s.runs, s.isWicket);
      final paint = Paint()
        ..color = color
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      if (!s.isWicket && s.runs == 6) {
        final endDist = radius * 1.28;
        final end = Offset(center.dx + ux * endDist, center.dy + uy * endDist);
        final mid = Offset(
          center.dx + ux * endDist * 0.5,
          center.dy + uy * endDist * 0.5,
        );
        final ctrl = Offset(
          mid.dx - uy * radius * 0.4,
          mid.dy + ux * radius * 0.4,
        );
        final path = Path()
          ..moveTo(center.dx, center.dy)
          ..quadraticBezierTo(ctrl.dx, ctrl.dy, end.dx, end.dy);
        canvas.drawPath(path, paint);
        canvas.drawCircle(end, 3.5, Paint()..color = color);
      } else if (!s.isWicket && s.runs == 0) {
        final p = Offset(
          center.dx + s.x.clamp(-1.0, 1.0) * radius,
          center.dy + s.y.clamp(-1.0, 1.0) * radius,
        );
        canvas.drawCircle(p, 4, Paint()..color = color);
      } else {
        var len = dist * radius;
        if (s.runs == 4) len = radius;
        if (dist < 0.05) len = radius * 0.8;
        len = len.clamp(0.0, radius * 1.02);
        canvas.drawLine(
          center,
          Offset(center.dx + ux * len, center.dy + uy * len),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WagonPainter old) => old.shots != shots;
}

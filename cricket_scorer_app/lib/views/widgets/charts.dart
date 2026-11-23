// Simple charts drawn with CustomPainter — no chart package needed.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:cricket_scorer_app/domain/scoring/scoring.dart';
import 'package:cricket_scorer_app/core/theme/pitch_theme.dart';

/// Runs comparison (worm): cumulative runs per over for two innings with clear X and Y axes.
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
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: PitchTheme.primary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label1.isNotEmpty ? label1 : 'Innings 1',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: PitchTheme.onSurface,
              ),
            ),
            if (label2.isNotEmpty || innings2.isNotEmpty) ...[
              const SizedBox(width: 16),
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: PitchTheme.secondary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label2.isNotEmpty ? label2 : 'Innings 2',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: PitchTheme.onSurface,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 195,
          width: double.infinity,
          child: CustomPaint(
            painter: _WormPainter(innings1, innings2),
          ),
        ),
      ],
    );
  }
}

class _WormPainter extends CustomPainter {
  final List<int> a;
  final List<int> b;
  _WormPainter(this.a, this.b);

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 40.0;
    const rightPad = 24.0;
    const topPad = 18.0;
    const bottomPad = 28.0;

    final plotWidth = size.width - leftPad - rightPad;
    final plotHeight = size.height - topPad - bottomPad;
    if (plotWidth <= 0 || plotHeight <= 0) return;

    // 1. Determine Y scale (Runs)
    final rawMaxY = math.max(
      a.isEmpty ? 0 : a.reduce(math.max),
      b.isEmpty ? 0 : b.reduce(math.max),
    );
    int maxY = 10;
    if (rawMaxY > 0) {
      if (rawMaxY <= 15) {
        maxY = 15;
      } else if (rawMaxY <= 30) {
        maxY = ((rawMaxY + 4) ~/ 5) * 5;
      } else if (rawMaxY <= 80) {
        maxY = ((rawMaxY + 9) ~/ 10) * 10;
      } else if (rawMaxY <= 160) {
        maxY = ((rawMaxY + 19) ~/ 20) * 20;
      } else {
        maxY = ((rawMaxY + 49) ~/ 50) * 50;
      }
    }

    // 2. Determine X scale (Overs)
    final maxLen = math.max(a.length, b.length);
    final maxOvers = maxLen > 0 ? maxLen : 1;

    final gridPaint = Paint()
      ..color = PitchTheme.outlineVariant.withValues(alpha: 0.35)
      ..strokeWidth = 0.8;

    final axisLinePaint = Paint()
      ..color = PitchTheme.outlineVariant
      ..strokeWidth = 1.2;

    const labelStyle = TextStyle(
      fontSize: 9.5,
      fontWeight: FontWeight.w600,
      color: PitchTheme.outline,
    );
    const titleStyle = TextStyle(
      fontSize: 9.5,
      fontWeight: FontWeight.w800,
      color: PitchTheme.onSurfaceVariant,
      letterSpacing: 0.3,
    );

    // Draw Y-axis title ("Runs")
    final yTitlePainter = TextPainter(
      text: const TextSpan(text: 'Runs', style: titleStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    yTitlePainter.paint(canvas, const Offset(leftPad - 38, topPad - 16));

    // Draw 4 horizontal grid lines & Y labels (0 to maxY)
    for (var i = 0; i <= 4; i++) {
      final yVal = (maxY * (4 - i) / 4).round();
      final y = topPad + (plotHeight * i / 4);

      // Grid line
      canvas.drawLine(
        Offset(leftPad, y),
        Offset(leftPad + plotWidth, y),
        gridPaint,
      );

      // Y-axis label text
      final tp = TextPainter(
        text: TextSpan(text: '$yVal', style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(leftPad - tp.width - 6, y - tp.height / 2));
    }

    // Draw X baseline
    final baselineY = topPad + plotHeight;
    canvas.drawLine(
      Offset(leftPad, baselineY),
      Offset(leftPad + plotWidth, baselineY),
      axisLinePaint,
    );

    // Determine X-axis tick step
    int overStep = 1;
    if (maxOvers > 20) {
      overStep = 5;
    } else if (maxOvers > 10) {
      overStep = 2;
    }

    // Draw X-axis ticks & Over numbers
    for (var over = 1; over <= maxOvers; over++) {
      final x = leftPad + (over / maxOvers) * plotWidth;
      // Tick mark
      canvas.drawLine(
        Offset(x, baselineY),
        Offset(x, baselineY + 3.5),
        axisLinePaint,
      );

      if (over % overStep == 0 || over == maxOvers) {
        final tp = TextPainter(
          text: TextSpan(text: '$over', style: labelStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, baselineY + 5));
      }
    }

    // Draw X-axis title ("Overs")
    final xTitlePainter = TextPainter(
      text: const TextSpan(text: 'Overs', style: titleStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    xTitlePainter.paint(
      canvas,
      Offset(leftPad + plotWidth - xTitlePainter.width, baselineY + 16),
    );

    // Draw Line Data
    void drawWorm(List<int> data, Color color) {
      if (data.isEmpty) return;
      final linePaint = Paint()
        ..color = color
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final path = Path();
      // Start from 0 overs, 0 runs
      path.moveTo(leftPad, baselineY);

      for (var i = 0; i < data.length; i++) {
        final x = leftPad + ((i + 1) / maxOvers) * plotWidth;
        final y = baselineY - (data[i] / maxY * plotHeight);
        path.lineTo(x, y);
      }
      canvas.drawPath(path, linePaint);

      // Draw point dots
      final dotPaint = Paint()..color = color;
      for (var i = 0; i < data.length; i++) {
        final x = leftPad + ((i + 1) / maxOvers) * plotWidth;
        final y = baselineY - (data[i] / maxY * plotHeight);
        final isLast = i == data.length - 1;
        canvas.drawCircle(Offset(x, y), isLast ? 4.0 : 2.5, dotPaint);

        // For the last point, draw the total runs score callout
        if (isLast) {
          final tp = TextPainter(
            text: TextSpan(
              text: '${data[i]}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          final textX = (x + 5 + tp.width > size.width)
              ? (x - tp.width - 5)
              : (x + 5);
          final textY = (y - 12 < topPad) ? (y + 4) : (y - 12);
          tp.paint(canvas, Offset(textX, textY));
        }
      }
    }

    drawWorm(a, PitchTheme.primary);
    drawWorm(b, PitchTheme.secondary);
  }

  @override
  bool shouldRepaint(covariant _WormPainter old) => old.a != a || old.b != b;
}

/// Over comparison (Manhattan): bars of runs per over with clear X & Y axes and run values.
class ManhattanChart extends StatelessWidget {
  final List<int> innings1;
  final List<int> innings2;
  final String label1;
  final String label2;
  const ManhattanChart({
    super.key,
    required this.innings1,
    required this.innings2,
    this.label1 = 'Innings 1',
    this.label2 = 'Innings 2',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: PitchTheme.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label1.isNotEmpty ? label1 : 'Innings 1',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: PitchTheme.onSurface,
              ),
            ),
            if (label2.isNotEmpty || innings2.isNotEmpty) ...[
              const SizedBox(width: 16),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: PitchTheme.secondary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label2.isNotEmpty ? label2 : 'Innings 2',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: PitchTheme.onSurface,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 195,
          width: double.infinity,
          child: CustomPaint(
            painter: _ManhattanPainter(innings1, innings2),
          ),
        ),
      ],
    );
  }
}

class _ManhattanPainter extends CustomPainter {
  final List<int> a;
  final List<int> b;
  _ManhattanPainter(this.a, this.b);

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 40.0;
    const rightPad = 24.0;
    const topPad = 22.0;
    const bottomPad = 28.0;

    final plotWidth = size.width - leftPad - rightPad;
    final plotHeight = size.height - topPad - bottomPad;
    if (plotWidth <= 0 || plotHeight <= 0) return;

    // 1. Determine Y scale (Runs per over)
    final rawMaxY = math.max(
      a.isEmpty ? 0 : a.reduce(math.max),
      b.isEmpty ? 0 : b.reduce(math.max),
    );
    int maxY = 10;
    if (rawMaxY > 0) {
      if (rawMaxY <= 6) {
        maxY = 6;
      } else if (rawMaxY <= 12) {
        maxY = 12;
      } else if (rawMaxY <= 20) {
        maxY = 20;
      } else if (rawMaxY <= 30) {
        maxY = 30;
      } else {
        maxY = ((rawMaxY + 9) ~/ 10) * 10;
      }
    }

    // 2. Determine X scale (Overs)
    final maxLen = math.max(a.length, b.length);
    final maxOvers = maxLen > 0 ? maxLen : 1;

    final gridPaint = Paint()
      ..color = PitchTheme.outlineVariant.withValues(alpha: 0.35)
      ..strokeWidth = 0.8;

    final axisLinePaint = Paint()
      ..color = PitchTheme.outlineVariant
      ..strokeWidth = 1.2;

    const labelStyle = TextStyle(
      fontSize: 9.5,
      fontWeight: FontWeight.w600,
      color: PitchTheme.outline,
    );
    const titleStyle = TextStyle(
      fontSize: 9.5,
      fontWeight: FontWeight.w800,
      color: PitchTheme.onSurfaceVariant,
      letterSpacing: 0.3,
    );

    // Draw Y-axis title ("Runs")
    final yTitlePainter = TextPainter(
      text: const TextSpan(text: 'Runs', style: titleStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    yTitlePainter.paint(canvas, const Offset(leftPad - 38, topPad - 18));

    // Draw 4 horizontal grid lines & Y labels (0 to maxY)
    for (var i = 0; i <= 4; i++) {
      final yVal = (maxY * (4 - i) / 4).round();
      final y = topPad + (plotHeight * i / 4);

      // Grid line
      canvas.drawLine(
        Offset(leftPad, y),
        Offset(leftPad + plotWidth, y),
        gridPaint,
      );

      // Y-axis label text
      final tp = TextPainter(
        text: TextSpan(text: '$yVal', style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(leftPad - tp.width - 6, y - tp.height / 2));
    }

    // Draw X baseline
    final baselineY = topPad + plotHeight;
    canvas.drawLine(
      Offset(leftPad, baselineY),
      Offset(leftPad + plotWidth, baselineY),
      axisLinePaint,
    );

    // Determine X-axis tick step
    int overStep = 1;
    if (maxOvers > 20) {
      overStep = 5;
    } else if (maxOvers > 10) {
      overStep = 2;
    }

    final slotWidth = plotWidth / maxOvers;

    // Draw Bars and X-axis labels
    for (var over = 1; over <= maxOvers; over++) {
      final slotCenter = leftPad + (over - 0.5) * slotWidth;

      // Tick mark
      canvas.drawLine(
        Offset(slotCenter, baselineY),
        Offset(slotCenter, baselineY + 3.5),
        axisLinePaint,
      );

      // Over label
      if (over % overStep == 0 || over == maxOvers) {
        final tp = TextPainter(
          text: TextSpan(text: '$over', style: labelStyle),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(slotCenter - tp.width / 2, baselineY + 5));
      }

      final idx = over - 1;
      final hasA = idx < a.length;
      final hasB = idx < b.length;

      if (hasA && hasB) {
        final barWidth = (slotWidth * 0.36).clamp(3.0, 14.0);
        const gap = 2.0;
        final x1 = slotCenter - barWidth - (gap / 2);
        final x2 = slotCenter + (gap / 2);

        // Bar 1 (Innings 1)
        final r1 = a[idx];
        final h1 = (r1 / maxY * plotHeight).clamp(0.0, plotHeight);
        final y1 = baselineY - h1;
        final paint1 = Paint()..color = PitchTheme.primary;
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(x1, y1, barWidth, h1),
            topLeft: const Radius.circular(2),
            topRight: const Radius.circular(2),
          ),
          paint1,
        );
        if (r1 > 0) {
          final tp1 = TextPainter(
            text: TextSpan(
              text: '$r1',
              style: const TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
                color: PitchTheme.primary,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          tp1.paint(canvas, Offset(x1 + (barWidth - tp1.width) / 2, y1 - tp1.height - 1));
        }

        // Bar 2 (Innings 2)
        final r2 = b[idx];
        final h2 = (r2 / maxY * plotHeight).clamp(0.0, plotHeight);
        final y2 = baselineY - h2;
        final paint2 = Paint()..color = PitchTheme.secondary;
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(x2, y2, barWidth, h2),
            topLeft: const Radius.circular(2),
            topRight: const Radius.circular(2),
          ),
          paint2,
        );
        if (r2 > 0) {
          final tp2 = TextPainter(
            text: TextSpan(
              text: '$r2',
              style: const TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
                color: PitchTheme.secondary,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          tp2.paint(canvas, Offset(x2 + (barWidth - tp2.width) / 2, y2 - tp2.height - 1));
        }
      } else if (hasA) {
        final barWidth = (slotWidth * 0.48).clamp(5.0, 22.0);
        final x = slotCenter - barWidth / 2;
        final r = a[idx];
        final h = (r / maxY * plotHeight).clamp(0.0, plotHeight);
        final y = baselineY - h;
        final paint = Paint()..color = PitchTheme.primary;
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(x, y, barWidth, h),
            topLeft: const Radius.circular(2),
            topRight: const Radius.circular(2),
          ),
          paint,
        );
        if (r > 0) {
          final tp = TextPainter(
            text: TextSpan(
              text: '$r',
              style: const TextStyle(
                fontSize: 9.0,
                fontWeight: FontWeight.w700,
                color: PitchTheme.primary,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas, Offset(slotCenter - tp.width / 2, y - tp.height - 1));
        }
      }
    }

    // Draw X-axis title ("Overs")
    final xTitlePainter = TextPainter(
      text: const TextSpan(text: 'Overs', style: titleStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    xTitlePainter.paint(
      canvas,
      Offset(leftPad + plotWidth - xTitlePainter.width, baselineY + 16),
    );
  }

  @override
  bool shouldRepaint(covariant _ManhattanPainter old) => old.a != a || old.b != b;
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
    // sector dividers
    final dividerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < 8; i++) {
      final angle = -math.pi / 2 + i * (math.pi / 4);
      final p1 = Offset(
        center.dx + (radius * 0.45) * math.cos(angle),
        center.dy + (radius * 0.45) * math.sin(angle),
      );
      final p2 = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      canvas.drawLine(p1, p2, dividerPaint);
    }
    // sector labels (standard cricket fielding regions)
    final textStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.70),
      fontSize: (size.width < 240) ? 7.5 : 9.0,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
    );
    final sectors = const [
      (angle: -math.pi * 5 / 8, label: 'Long Off'),
      (angle: -math.pi * 3 / 8, label: 'Long On'),
      (angle: -math.pi * 1 / 8, label: 'Mid-Wicket'),
      (angle: math.pi * 1 / 8, label: 'Square Leg'),
      (angle: math.pi * 3 / 8, label: 'Fine Leg'),
      (angle: math.pi * 5 / 8, label: 'Third Man'),
      (angle: math.pi * 7 / 8, label: 'Point'),
      (angle: -math.pi * 7 / 8, label: 'Cover'),
    ];
    for (final s in sectors) {
      final textSpan = TextSpan(text: s.label, style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();
      final labelR = radius * 0.75;
      final lx = center.dx + labelR * math.cos(s.angle) - (textPainter.width / 2);
      final ly = center.dy + labelR * math.sin(s.angle) - (textPainter.height / 2);
      textPainter.paint(canvas, Offset(lx, ly));
    }
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

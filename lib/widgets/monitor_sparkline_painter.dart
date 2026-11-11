import 'package:flutter/material.dart';

import '../models/device_metrics.dart';

class MonitorSparklinePainter extends CustomPainter {
  const MonitorSparklinePainter({
    required this.data,
    required this.lineColor,
    required this.fillGradient,
    this.maxValue = 100.0,
    this.minValue = 0.0,
    this.unit = '%',
  });

  final List<MetricDataPoint> data;
  final Color lineColor;
  final LinearGradient fillGradient;
  final double maxValue;
  final double minValue;
  final String unit;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final w = size.width;
    final h = size.height;

    // Draw grid lines
    final gridPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int i = 1; i <= 3; i++) {
      final y = h * (i / 4.0);
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }

    // Calculate actual bounds
    double effectiveMax = maxValue;
    for (final point in data) {
      if (point.value > effectiveMax) effectiveMax = point.value;
    }
    final range = (effectiveMax - minValue) > 0 ? (effectiveMax - minValue) : 1.0;

    final points = <Offset>[];
    final count = data.length;
    final dx = count > 1 ? w / (count - 1) : w;

    for (int i = 0; i < count; i++) {
      final val = data[i].value.clamp(minValue, effectiveMax);
      final normalizedY = (val - minValue) / range;
      final y = h - (normalizedY * (h - 10)) - 5;
      final x = i * dx;
      points.add(Offset(x, y));
    }

    if (points.isEmpty) return;

    // Path for line
    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlPoint1 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p0.dy);
      final controlPoint2 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p1.dy);
      path.cubicTo(
        controlPoint1.dx,
        controlPoint1.dy,
        controlPoint2.dx,
        controlPoint2.dy,
        p1.dx,
        p1.dy,
      );
    }

    // Fill area under line
    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, h)
      ..lineTo(points.first.dx, h)
      ..close();

    final fillPaint = Paint()
      ..shader = fillGradient.createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    // Stroke line
    final strokePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, strokePaint);

    // Draw glowing dot at the latest point
    final last = points.last;
    final glowPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(last, 6.0, glowPaint);

    final dotPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(last, 3.5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant MonitorSparklinePainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.lineColor != lineColor;
  }
}

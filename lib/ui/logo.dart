import 'dart:math';

import 'package:flutter/material.dart';

import '../theme_district.dart';

/// ============================================================
/// MYNDASH "Neural Infinity" mark — one continuous neural pathway
/// forming an infinity loop. Left lobe solid (logic), right lobe
/// pulse-dashed (creativity firing), synapse node at the
/// crossover with three dendrite sparks.
/// Master vector: branding/mynd_logo.svg
/// ============================================================
class MyndLogo extends StatelessWidget {
  final double size;
  const MyndLogo({super.key, this.size = 64});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size * 1.6, size),
      painter: _MyndPainter(),
    );
  }
}

class _MyndPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final cx = w / 2, cy = h / 2;
    final stroke = h * 0.11;

    final gradient = LinearGradient(colors: [
      DC.cyan,
      DC.violet,
      DC.magenta,
    ]).createShader(Rect.fromLTWH(0, 0, w, h));

    final solid = Paint()
      ..shader = gradient
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    final glow = Paint()
      ..shader = gradient
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke * 2.2
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    // left lobe (solid)
    final left = Path()
      ..moveTo(cx, cy)
      ..cubicTo(cx - w * 0.14, cy - h * 0.38, cx - w * 0.50, cy - h * 0.42,
          cx - w * 0.42, cy - h * 0.02)
      ..cubicTo(
          cx - w * 0.36, cy + h * 0.34, cx - w * 0.18, cy + h * 0.30, cx, cy);

    // right lobe (dashed pulses)
    final right = Path()
      ..moveTo(cx, cy)
      ..cubicTo(cx + w * 0.14, cy + h * 0.38, cx + w * 0.50, cy + h * 0.42,
          cx + w * 0.42, cy + h * 0.02)
      ..cubicTo(
          cx + w * 0.36, cy - h * 0.34, cx + w * 0.18, cy - h * 0.30, cx, cy);

    canvas.drawPath(left, glow);
    canvas.drawPath(left, solid);
    canvas.drawPath(right, glow);
    _drawDashed(canvas, right, solid, dash: h * 0.16, gap: h * 0.10);

    // synapse node
    canvas.drawCircle(
        Offset(cx, cy),
        h * 0.16,
        Paint()
          ..shader = RadialGradient(colors: [
            Colors.white,
            const Color(0xFFB9F4FF),
            DC.cyan.withOpacity(0)
          ]).createShader(
              Rect.fromCircle(center: Offset(cx, cy), radius: h * 0.16)));
    canvas.drawCircle(Offset(cx, cy), h * 0.065, Paint()..color = Colors.white);

    // dendrite sparks
    void spark(double angleDeg, Color c) {
      final a = angleDeg * pi / 180;
      final r1 = h * 0.20, r2 = h * 0.32;
      canvas.drawLine(
        Offset(cx + cos(a) * r1, cy - sin(a) * r1),
        Offset(cx + cos(a) * r2, cy - sin(a) * r2),
        Paint()
          ..color = c
          ..strokeWidth = stroke * 0.4
          ..strokeCap = StrokeCap.round,
      );
    }

    spark(90, const Color(0xFFB9F4FF));
    spark(135, DC.violet);
    spark(45, DC.magenta);
  }

  void _drawDashed(Canvas canvas, Path path, Paint paint,
      {required double dash, required double gap}) {
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        final end = min(d + dash, metric.length);
        canvas.drawPath(metric.extractPath(d, end), paint);
        d = end + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

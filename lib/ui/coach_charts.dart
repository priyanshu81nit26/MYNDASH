import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/local_coach_engine.dart';
import '../theme_district.dart';

class CoachSkillRadar extends StatelessWidget {
  const CoachSkillRadar({
    super.key,
    required this.scores,
    this.height = 270,
  });

  final Map<String, double> scores;
  final double height;

  @override
  Widget build(BuildContext context) {
    const labels = [
      'Calculation',
      'Logic',
      'Spatial',
      'Memory',
      'Language',
      'Competition',
    ];
    final values = [for (final label in labels) scores[label] ?? 0];
    final measured = values.where((value) => value > 0).length;
    final summary = measured == 0
        ? 'Skillprint chart. No measured skill groups yet.'
        : 'Skillprint chart. ${[
            for (var i = 0; i < labels.length; i++)
              '${labels[i]} ${(values[i] * 100).round()} percent'
          ].join(', ')}.';
    return Semantics(
      image: true,
      label: summary,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _RadarPainter(
              labels: labels,
              values: values,
              grid: DC.fg24,
              text: DC.dim,
              primary: DC.cyan,
              secondary: DC.magenta,
            ),
          ),
        ),
      ),
    );
  }
}

class CoachPulseChart extends StatelessWidget {
  const CoachPulseChart({
    super.key,
    required this.days,
    this.height = 210,
  });

  final List<CoachDayPoint> days;
  final double height;

  @override
  Widget build(BuildContext context) {
    final active = days.where((day) => day.sessions > 0).length;
    final total = days.fold<int>(0, (sum, day) => sum + day.sessions);
    final quality = days.where((day) => day.quality != null).toList();
    final averageQuality = quality.isEmpty
        ? null
        : quality.fold<double>(0, (sum, day) => sum + (day.quality ?? 0)) /
            quality.length;
    final label = 'Fourteen day training pulse. $active active days, '
        '$total tracked sessions${averageQuality == null ? '' : ', average quality ${(averageQuality * 100).round()} percent'}.';
    return Semantics(
      image: true,
      label: label,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _PulsePainter(
              days: days,
              grid: DC.fg12,
              text: DC.dim,
              volume: DC.violet,
              quality: DC.lime,
              glow: DC.cyan,
            ),
          ),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  const _RadarPainter({
    required this.labels,
    required this.values,
    required this.grid,
    required this.text,
    required this.primary,
    required this.secondary,
  });

  final List<String> labels;
  final List<double> values;
  final Color grid;
  final Color text;
  final Color primary;
  final Color secondary;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 4);
    final radius = math.min(size.width * 0.31, size.height * 0.34);
    final axisCount = labels.length;

    List<Offset> polygon(double factor) => List.generate(axisCount, (index) {
          final angle = -math.pi / 2 + index * math.pi * 2 / axisCount;
          return center +
              Offset(math.cos(angle), math.sin(angle)) * radius * factor;
        });

    final gridPaint = Paint()
      ..color = grid
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final factor in const [0.25, 0.5, 0.75, 1.0]) {
      canvas.drawPath(_closed(polygon(factor)), gridPaint);
    }
    for (final point in polygon(1)) {
      canvas.drawLine(center, point, gridPaint);
    }

    final points = List.generate(axisCount, (index) {
      final value = values[index].clamp(0.0, 1.0);
      final angle = -math.pi / 2 + index * math.pi * 2 / axisCount;
      return center + Offset(math.cos(angle), math.sin(angle)) * radius * value;
    });
    final dataPath = _closed(points);
    canvas.drawPath(
      dataPath,
      Paint()
        ..color = primary.withValues(alpha: 0.18)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      dataPath,
      Paint()
        ..color = primary.withValues(alpha: 0.38)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );
    canvas.drawPath(
      dataPath,
      Paint()
        ..shader = LinearGradient(colors: [primary, secondary])
            .createShader(Offset.zero & size)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4,
    );
    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(
        points[i],
        4.5,
        Paint()..color = i.isEven ? primary : secondary,
      );
      canvas.drawCircle(
        points[i],
        8,
        Paint()
          ..color = (i.isEven ? primary : secondary).withValues(alpha: 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }

    for (var i = 0; i < axisCount; i++) {
      final angle = -math.pi / 2 + i * math.pi * 2 / axisCount;
      final anchor =
          center + Offset(math.cos(angle), math.sin(angle)) * (radius + 25);
      final painter = TextPainter(
        text: TextSpan(
          text: '${labels[i]}\n${(values[i] * 100).round()}',
          style: TextStyle(
            color: text,
            fontSize: 9.5,
            height: 1.25,
            fontWeight: FontWeight.w700,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 78);
      painter.paint(
        canvas,
        Offset(anchor.dx - painter.width / 2, anchor.dy - painter.height / 2),
      );
    }
  }

  Path _closed(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(_RadarPainter oldDelegate) => true;
}

class _PulsePainter extends CustomPainter {
  const _PulsePainter({
    required this.days,
    required this.grid,
    required this.text,
    required this.volume,
    required this.quality,
    required this.glow,
  });

  final List<CoachDayPoint> days;
  final Color grid;
  final Color text;
  final Color volume;
  final Color quality;
  final Color glow;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 8.0;
    const top = 16.0;
    const bottom = 28.0;
    final chart =
        Rect.fromLTRB(left, top, size.width - 8, size.height - bottom);
    final maxSessions = math.max(
      1,
      days.fold<int>(0, (best, day) => math.max(best, day.sessions)),
    );
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = chart.bottom - chart.height * i / 4;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
    }

    final slot = chart.width / days.length;
    for (var i = 0; i < days.length; i++) {
      final day = days[i];
      final height = chart.height * day.sessions / maxSessions;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          chart.left + slot * i + slot * 0.18,
          chart.bottom - height,
          slot * 0.64,
          height,
        ),
        const Radius.circular(5),
      );
      canvas.drawRRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [volume.withValues(alpha: 0.22), volume],
          ).createShader(rect.outerRect),
      );
    }

    final qualityPoints = <Offset>[];
    for (var i = 0; i < days.length; i++) {
      final value = days[i].quality;
      if (value == null) continue;
      qualityPoints.add(Offset(
        chart.left + slot * (i + 0.5),
        chart.bottom - chart.height * value.clamp(0.0, 1.0),
      ));
    }
    if (qualityPoints.length > 1) {
      final path = _smoothPath(qualityPoints);
      canvas.drawPath(
        path,
        Paint()
          ..color = glow.withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = quality
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
      for (final point in qualityPoints) {
        canvas.drawCircle(point, 3.5, Paint()..color = quality);
      }
    }

    for (var i = 0; i < days.length; i += 2) {
      final painter = TextPainter(
        text: TextSpan(
          text: days[i].shortLabel,
          style: TextStyle(
            color: text,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        Offset(
          chart.left + slot * (i + 0.5) - painter.width / 2,
          chart.bottom + 8,
        ),
      );
    }
  }

  Path _smoothPath(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final current = points[i];
      final midX = (previous.dx + current.dx) / 2;
      path.cubicTo(
        midX,
        previous.dy,
        midX,
        current.dy,
        current.dx,
        current.dy,
      );
    }
    return path;
  }

  @override
  bool shouldRepaint(_PulsePainter oldDelegate) => true;
}

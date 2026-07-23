import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/state.dart';
import '../theme_district.dart';
import 'extras.dart';
import 'glass.dart';

/// ============================================================
/// MIND DNA — a living radar of 6 traits computed from real play.
/// Speed · Logic · Memory · Calculation · Nerve · Consistency
/// ============================================================

class MindDna {
  final double speed, logic, memory, calc, nerve, consistency;
  const MindDna(this.speed, this.logic, this.memory, this.calc, this.nerve,
      this.consistency);

  static double _n(num v, num lo, num hi) =>
      ((v - lo) / (hi - lo)).clamp(0.0, 1.0).toDouble();

  factory MindDna.of(AppData a) {
    // SPEED — recent win rate + streak pressure
    final wins = a.lastForm.where((r) => r == 'W').length;
    final speed = _n(wins * 18 + a.streak * 6, 0, 100);
    // LOGIC — solve progression across categories
    final logic = _n(a.overallRating, 800, 2500);
    // MEMORY — lifetime earned XP (never purchasable)
    final memory = _n(math.sqrt(a.xp.toDouble()), 0, 90);
    // CALCULATION — duel Elo
    final calc = _n(a.elo, 400, 2600);
    // NERVE — rated-contest performance
    final nerve = _n(a.contestRating, 1000, 2900);
    // CONSISTENCY — active days in the last 4 weeks
    var activeDays = 0;
    final now = DateTime.now();
    for (var d = 0; d < 28; d++) {
      final day = now.subtract(Duration(days: d));
      final k =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      if (a.activityOn(k) > 0) activeDays++;
    }
    final consistency = _n(activeDays, 0, 24);
    return MindDna(speed, logic, memory, calc, nerve, consistency);
  }

  List<double> get values => [speed, logic, memory, calc, nerve, consistency];
  static const labels = ['SPD', 'LOG', 'MEM', 'CALC', 'NRV', 'CON'];

  /// Archetype name — the shareable identity hook.
  String get archetype {
    final v = values;
    final top = v.indexOf(v.reduce(math.max));
    return switch (top) {
      0 => 'The Bolt ⚡',
      1 => 'The Architect 🧩',
      2 => 'The Vault 🧠',
      3 => 'The Calculator 🔢',
      4 => 'The Ice Vein 🧊',
      _ => 'The Machine 🔁',
    };
  }
}

class MindDnaCard extends StatelessWidget {
  const MindDnaCard({super.key});

  @override
  Widget build(BuildContext context) {
    final a = AppData.i;
    final dna = MindDna.of(a);
    return Glass(
      radius: 24,
      child: Column(children: [
        Row(children: [
          const Text('🧬', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          const Text('MIND DNA',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2)),
          const Spacer(),
          Text(dna.archetype,
              style: TextStyle(
                  fontSize: 12, color: DC.cyan, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          height: 190,
          child: CustomPaint(
            size: const Size(double.infinity, 190),
            painter: _RadarPainter(dna.values),
          ),
        ),
        const SizedBox(height: 6),
        TextButton.icon(
          onPressed: () => shareResult(
              context,
              'My MYNDASH Mind DNA 🧬 ${dna.archetype} — '
              '${[
                for (var i = 0; i < 6; i++)
                  '${MindDna.labels[i]} ${(dna.values[i] * 100).round()}'
              ].join(' · ')}'
              ' — evolve yours on MYNDASH.'),
          icon: Icon(Icons.ios_share, size: 15, color: DC.cyan),
          label: Text('Share my DNA',
              style: TextStyle(color: DC.cyan, fontSize: 12)),
        ),
      ]),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final List<double> values;
  _RadarPainter(this.values);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = math.min(size.width, size.height) / 2 - 22;
    const n = 6;
    Offset pt(int i, double f) {
      final ang = -math.pi / 2 + i * 2 * math.pi / n;
      return c + Offset(math.cos(ang), math.sin(ang)) * r * f;
    }

    // grid rings
    final grid = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = DC.fgo(0.10);
    for (final f in [0.33, 0.66, 1.0]) {
      final path = Path();
      for (var i = 0; i < n; i++) {
        final p = pt(i, f);
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      path.close();
      canvas.drawPath(path, grid);
    }
    // spokes
    for (var i = 0; i < n; i++) {
      canvas.drawLine(c, pt(i, 1), grid);
    }
    // value polygon
    final poly = Path();
    for (var i = 0; i < n; i++) {
      final p = pt(i, 0.08 + values[i] * 0.92);
      i == 0 ? poly.moveTo(p.dx, p.dy) : poly.lineTo(p.dx, p.dy);
    }
    poly.close();
    canvas.drawPath(
        poly,
        Paint()
          ..shader = LinearGradient(colors: [
            DC.cyan.withOpacity(0.45),
            DC.violet.withOpacity(0.45)
          ]).createShader(Rect.fromCircle(center: c, radius: r)));
    canvas.drawPath(
        poly,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = DC.cyan);
    // vertex dots + labels
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i < n; i++) {
      final p = pt(i, 0.08 + values[i] * 0.92);
      canvas.drawCircle(p, 3, Paint()..color = DC.cyan);
      final lp = pt(i, 1.22);
      tp.text = TextSpan(
          text: '${MindDna.labels[i]}\n${(values[i] * 100).round()}',
          style: TextStyle(
              fontSize: 9,
              height: 1.2,
              fontWeight: FontWeight.w800,
              color: Colors.white.withOpacity(0.75)));
      tp.layout();
      tp.paint(canvas, lp - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) => old.values != values;
}

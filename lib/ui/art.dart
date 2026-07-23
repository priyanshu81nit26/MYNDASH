import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme_district.dart';

/// ============================================================
/// MYNDASH ART 🎨 — procedural animated illustrations.
/// Replaces flat boxes & emojis with living, glowing vector art
/// drawn on canvas — zero image assets, crisp at any size, and
/// each theme gently animates forever (orbits, pulses, shimmer).
///
/// Themes: brain · duel · arena · squad · community · games ·
///         store · mania · reflex
/// ============================================================
class MyndArt extends StatefulWidget {
  final String theme;
  final double size;
  const MyndArt({super.key, required this.theme, this.size = 64});

  @override
  State<MyndArt> createState() => _MyndArtState();
}

class _MyndArtState extends State<MyndArt> with SingleTickerProviderStateMixin {
  // ponytail: slow 8s loop (not 60fps), RepaintBoundary-isolated to the
  // small art rect — gentle motion without keeping the whole tree awake.
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 8))
        ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(
            painter: _ArtPainter(widget.theme, _c.value),
          ),
        ),
      ),
    );
  }
}

class _ArtPainter extends CustomPainter {
  final String theme;
  final double t; // 0..1 looping
  _ArtPainter(this.theme, this.t);

  static Map<String, List<Color>> get _themeColors => {
        'brain': [DC.cyan, DC.violet],
        'duel': [DC.magenta, DC.violet],
        'arena': [DC.amber, DC.magenta],
        'squad': [DC.lime, DC.cyan],
        'community': [DC.cyan, DC.lime],
        'games': [DC.violet, DC.cyan],
        'store': [DC.amber, DC.lime],
        'mania': [DC.amber, DC.magenta],
        'reflex': [DC.cyan, DC.magenta],
      };

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide / 2;
    final colors = _themeColors[theme] ?? [DC.cyan, DC.violet];
    final phase = t * 2 * math.pi;

    // ---- glowing backdrop orb (all themes) ----
    final pulse = 0.92 + 0.08 * math.sin(phase);
    canvas.drawCircle(
        c,
        r * 0.92 * pulse,
        Paint()
          ..shader = RadialGradient(colors: [
            colors[0].withOpacity(0.34),
            colors[1].withOpacity(0.12),
            Colors.transparent,
          ]).createShader(Rect.fromCircle(center: c, radius: r)));

    switch (theme) {
      case 'duel':
        _duel(canvas, c, r, phase, colors);
      case 'arena':
        _arena(canvas, c, r, phase, colors);
      case 'squad':
        _squad(canvas, c, r, phase, colors);
      case 'community':
        _community(canvas, c, r, phase, colors);
      case 'games':
        _games(canvas, c, r, phase, colors);
      case 'store':
        _store(canvas, c, r, phase, colors);
      case 'mania':
        _mania(canvas, c, r, phase, colors);
      case 'reflex':
        _reflex(canvas, c, r, phase, colors);
      default:
        _brain(canvas, c, r, phase, colors);
    }

    // ---- orbiting sparkles (all themes) ----
    for (var i = 0; i < 3; i++) {
      final a = phase + i * 2.1;
      final sr = r * (0.78 + 0.1 * math.sin(phase * 2 + i));
      final p = c + Offset(math.cos(a) * sr, math.sin(a) * sr);
      _sparkle(canvas, p, r * 0.07 * (0.7 + 0.3 * math.sin(phase * 3 + i)),
          Colors.white.withOpacity(0.85));
    }
  }

  // ---------------- theme drawings ----------------

  void _brain(Canvas cv, Offset c, double r, double p, List<Color> col) {
    // concentric mind-arcs + pulsing synapse nodes
    for (var i = 0; i < 3; i++) {
      final rr = r * (0.30 + i * 0.18);
      cv.drawArc(
          Rect.fromCircle(center: c, radius: rr),
          p * (i.isEven ? 1 : -1) + i,
          math.pi * 1.4,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.055
            ..strokeCap = StrokeCap.round
            ..color = col[i % 2].withOpacity(0.85));
    }
    for (var i = 0; i < 5; i++) {
      final a = i * 1.256 + p * 0.5;
      final rr = r * (0.30 + (i % 3) * 0.18);
      final n = c + Offset(math.cos(a) * rr, math.sin(a) * rr);
      cv.drawCircle(n, r * 0.06 * (0.8 + 0.4 * math.sin(p * 2 + i)),
          Paint()..color = Colors.white.withOpacity(0.9));
    }
  }

  void _duel(Canvas cv, Offset c, double r, double p, List<Color> col) {
    // two crossed energy blades with a clash spark
    final sway = math.sin(p) * 0.12;
    for (final (dir, color) in [(1.0, col[0]), (-1.0, col[1])]) {
      cv.save();
      cv.translate(c.dx, c.dy);
      cv.rotate(dir * (math.pi / 4 + sway));
      final blade = Paint()
        ..strokeWidth = r * 0.13
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(colors: [color, Colors.white])
            .createShader(Rect.fromLTWH(-r, -r * 0.1, 2 * r, r * 0.2));
      cv.drawLine(Offset(-r * 0.62, 0), Offset(r * 0.62, 0), blade);
      // hilt
      cv.drawLine(
          Offset(-r * 0.30, -r * 0.14),
          Offset(-r * 0.30, r * 0.14),
          Paint()
            ..strokeWidth = r * 0.08
            ..strokeCap = StrokeCap.round
            ..color = color);
      cv.restore();
    }
    _sparkle(cv, c, r * 0.14 * (0.8 + 0.5 * math.sin(p * 4)),
        Colors.white.withOpacity(0.95));
  }

  void _arena(Canvas cv, Offset c, double r, double p, List<Color> col) {
    // stadium rings + a champion dot doing laps
    for (var i = 0; i < 2; i++) {
      cv.drawOval(
          Rect.fromCenter(
              center: c,
              width: r * (1.28 - i * 0.34),
              height: r * (0.78 - i * 0.2)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.05
            ..color = col[i].withOpacity(0.8));
    }
    final a = p * 2;
    final dot = c + Offset(math.cos(a) * r * 0.64, math.sin(a) * r * 0.39);
    cv.drawCircle(dot, r * 0.09, Paint()..color = Colors.white);
    cv.drawCircle(dot, r * 0.16, Paint()..color = col[0].withOpacity(0.35));
    // podium
    final base = c + Offset(0, r * 0.18);
    final pw = r * 0.20;
    for (final (dx, h, color) in [
      (-pw, r * 0.20, col[1]),
      (0.0, r * 0.32, col[0]),
      (pw, r * 0.14, col[1]),
    ]) {
      cv.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: base + Offset(dx, -h / 2 + r * 0.1),
                  width: pw * 0.82,
                  height: h),
              Radius.circular(r * 0.04)),
          Paint()..color = color.withOpacity(0.9));
    }
  }

  void _squad(Canvas cv, Offset c, double r, double p, List<Color> col) {
    // three teammates orbiting a shared core — tight, together
    cv.drawCircle(c, r * 0.16, Paint()..color = Colors.white.withOpacity(0.95));
    cv.drawCircle(
        c,
        r * 0.26,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.03
          ..color = col[0].withOpacity(0.6));
    for (var i = 0; i < 3; i++) {
      final a = p + i * 2 * math.pi / 3;
      final m = c + Offset(math.cos(a) * r * 0.55, math.sin(a) * r * 0.55);
      // head + shoulders silhouette
      cv.drawCircle(
          m + Offset(0, -r * 0.05), r * 0.09, Paint()..color = col[i % 2]);
      cv.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: m + Offset(0, r * 0.09),
                  width: r * 0.22,
                  height: r * 0.14),
              Radius.circular(r * 0.07)),
          Paint()..color = col[i % 2]);
      // bond line to the core
      cv.drawLine(
          c,
          m,
          Paint()
            ..strokeWidth = r * 0.02
            ..color = DC.fgo(0.25));
    }
  }

  void _community(Canvas cv, Offset c, double r, double p, List<Color> col) {
    // a living network graph
    final nodes = <Offset>[];
    for (var i = 0; i < 6; i++) {
      final a = i * math.pi / 3 + math.sin(p + i) * 0.15;
      final rr = r * (i.isEven ? 0.62 : 0.38);
      nodes.add(c + Offset(math.cos(a) * rr, math.sin(a) * rr));
    }
    final link = Paint()
      ..strokeWidth = r * 0.022
      ..color = DC.fgo(0.30);
    for (var i = 0; i < nodes.length; i++) {
      cv.drawLine(nodes[i], nodes[(i + 1) % nodes.length], link);
      cv.drawLine(nodes[i], c, link);
    }
    cv.drawCircle(c, r * 0.10, Paint()..color = Colors.white);
    for (var i = 0; i < nodes.length; i++) {
      cv.drawCircle(nodes[i], r * 0.075 * (0.85 + 0.3 * math.sin(p * 2 + i)),
          Paint()..color = col[i % 2]);
    }
  }

  void _games(Canvas cv, Offset c, double r, double p, List<Color> col) {
    // bobbing game shapes: pawn-circle, d-pad cross, dart triangle
    final bob = math.sin(p) * r * 0.06;
    // circle piece
    cv.drawCircle(c + Offset(-r * 0.42, -r * 0.1 + bob), r * 0.17,
        Paint()..color = col[0]);
    // cross / d-pad
    final cross = Paint()
      ..strokeWidth = r * 0.11
      ..strokeCap = StrokeCap.round
      ..color = col[1];
    final cc = c + Offset(r * 0.34, -r * 0.22 - bob);
    cv.drawLine(cc - Offset(r * 0.14, 0), cc + Offset(r * 0.14, 0), cross);
    cv.drawLine(cc - Offset(0, r * 0.14), cc + Offset(0, r * 0.14), cross);
    // triangle (dart)
    final path = Path();
    final tc = c + Offset(0, r * 0.36 - bob);
    path.moveTo(tc.dx, tc.dy - r * 0.18);
    path.lineTo(tc.dx - r * 0.16, tc.dy + r * 0.12);
    path.lineTo(tc.dx + r * 0.16, tc.dy + r * 0.12);
    path.close();
    cv.drawPath(path, Paint()..color = Colors.white.withOpacity(0.9));
  }

  void _store(Canvas cv, Offset c, double r, double p, List<Color> col) {
    // gift box with a breathing bow + rising star
    final box = Rect.fromCenter(
        center: c + Offset(0, r * 0.12), width: r * 0.8, height: r * 0.62);
    cv.drawRRect(RRect.fromRectAndRadius(box, Radius.circular(r * 0.08)),
        Paint()..color = col[0].withOpacity(0.9));
    cv.drawRect(
        Rect.fromCenter(
            center: box.center, width: r * 0.12, height: box.height),
        Paint()..color = Colors.white.withOpacity(0.85));
    cv.drawRect(
        Rect.fromCenter(
            center: box.topCenter, width: box.width, height: r * 0.10),
        Paint()..color = col[1].withOpacity(0.95));
    final sy = r * (0.42 + 0.08 * math.sin(p * 2));
    _sparkle(cv, c - Offset(0, sy), r * 0.12, Colors.white);
  }

  void _mania(Canvas cv, Offset c, double r, double p, List<Color> col) {
    // trophy cup with shimmering shine
    final cup = Path()
      ..moveTo(c.dx - r * 0.3, c.dy - r * 0.35)
      ..lineTo(c.dx + r * 0.3, c.dy - r * 0.35)
      ..quadraticBezierTo(c.dx + r * 0.3, c.dy + r * 0.1, c.dx, c.dy + r * 0.16)
      ..quadraticBezierTo(
          c.dx - r * 0.3, c.dy + r * 0.1, c.dx - r * 0.3, c.dy - r * 0.35)
      ..close();
    cv.drawPath(
        cup,
        Paint()
          ..shader = LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [col[0], col[1]])
              .createShader(Rect.fromCircle(center: c, radius: r)));
    // handles
    for (final s in [-1.0, 1.0]) {
      cv.drawArc(
          Rect.fromCircle(
              center: c + Offset(s * r * 0.38, c.dy * 0 - r * 0.18),
              radius: r * 0.14),
          s > 0 ? -math.pi / 2 : math.pi / 2,
          s > 0 ? math.pi : -math.pi,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = r * 0.06
            ..color = col[0]);
    }
    // stem + base
    cv.drawRect(
        Rect.fromCenter(
            center: c + Offset(0, r * 0.26), width: r * 0.10, height: r * 0.2),
        Paint()..color = col[1]);
    cv.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: c + Offset(0, r * 0.42),
                width: r * 0.44,
                height: r * 0.1),
            Radius.circular(r * 0.04)),
        Paint()..color = col[1]);
    // shine sweep
    final shineX = c.dx + math.sin(p) * r * 0.22;
    cv.drawLine(
        Offset(shineX, c.dy - r * 0.30),
        Offset(shineX - r * 0.08, c.dy + r * 0.05),
        Paint()
          ..strokeWidth = r * 0.05
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withOpacity(0.75));
  }

  void _reflex(Canvas cv, Offset c, double r, double p, List<Color> col) {
    // lightning bolt with radiating pulse rings
    final ring = (p % 1);
    cv.drawCircle(
        c,
        r * (0.3 + ring * 0.65),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.04 * (1 - ring)
          ..color = col[0].withOpacity((1 - ring) * 0.7));
    final bolt = Path()
      ..moveTo(c.dx + r * 0.10, c.dy - r * 0.45)
      ..lineTo(c.dx - r * 0.18, c.dy + r * 0.06)
      ..lineTo(c.dx - 0, c.dy + r * 0.06)
      ..lineTo(c.dx - r * 0.10, c.dy + r * 0.45)
      ..lineTo(c.dx + r * 0.20, c.dy - r * 0.08)
      ..lineTo(c.dx + r * 0.02, c.dy - r * 0.08)
      ..close();
    cv.drawPath(
        bolt,
        Paint()
          ..shader = LinearGradient(colors: [Colors.white, col[1]])
              .createShader(Rect.fromCircle(center: c, radius: r)));
  }

  void _sparkle(Canvas cv, Offset p, double s, Color color) {
    final paint = Paint()
      ..strokeWidth = s * 0.4
      ..strokeCap = StrokeCap.round
      ..color = color;
    cv.drawLine(p - Offset(s, 0), p + Offset(s, 0), paint);
    cv.drawLine(p - Offset(0, s), p + Offset(0, s), paint);
  }

  @override
  bool shouldRepaint(covariant _ArtPainter old) =>
      old.t != t || old.theme != theme;
}

/// A ready-made hero banner: art + title + subtitle on a themed
/// gradient — drop-in replacement for emoji header rows.
class ArtBanner extends StatelessWidget {
  final String theme;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  const ArtBanner(
      {super.key,
      required this.theme,
      required this.title,
      required this.subtitle,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = _ArtPainter._themeColors[theme] ?? [DC.cyan, DC.violet];
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors[0].withOpacity(0.22),
                colors[1].withOpacity(0.10),
                DC.fgo(0.03),
              ]),
          border: Border.all(color: colors[0].withOpacity(0.45)),
        ),
        child: Row(children: [
          MyndArt(theme: theme, size: 64),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 16)),
              const SizedBox(height: 3),
              Text(subtitle,
                  style: TextStyle(fontSize: 11, color: DC.dim, height: 1.4)),
            ]),
          ),
          if (onTap != null) Icon(Icons.chevron_right, color: DC.dim),
        ]),
      ),
    );
  }
}

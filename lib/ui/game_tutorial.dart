import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/state.dart';
import '../theme_district.dart';
import 'glass.dart';

/// The animated gesture drawn for a tutorial step.
enum TutorialGesture { tap, swipeUp, dragAcross, sequence, none }

class TutorialStep {
  final String text;
  final TutorialGesture gesture;
  const TutorialStep(this.text, {this.gesture = TutorialGesture.tap});
}

/// Reusable level-0 "how to play" coach overlay. Dims the screen, walks the
/// player through a few steps — each with a looping arrow/gesture demo,
/// caption, and progress dots — then a Skip / Back / Next / Got-it control.
/// Show it once per game (persisted) or replay from a "?" help button.
///
/// A game wires it in two lines:
///   initState → GameTutorial.showOnce(context, tutKey:'darts', title:.., steps:..)
///   a help button → GameTutorial.show(context, title:.., steps:..)
class GameTutorial extends StatefulWidget {
  final String title;
  final List<TutorialStep> steps;
  const GameTutorial({super.key, required this.title, required this.steps});

  static Future<void> show(BuildContext context,
      {required String title, required List<TutorialStep> steps}) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) => GameTutorial(title: title, steps: steps),
      transitionBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    );
  }

  /// Shows only the first time for [tutKey]; marks it seen immediately so a
  /// fast back-out still counts (no nagging on every entry).
  static Future<void> showOnce(BuildContext context,
      {required String tutKey,
      required String title,
      required List<TutorialStep> steps}) async {
    if (AppData.i.tutSeen(tutKey)) return;
    AppData.i.markTutSeen(tutKey);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!context.mounted) return;
    await show(context, title: title, steps: steps);
  }

  /// A small round "?" help button games can drop in their header to replay.
  static Widget helpButton(BuildContext context,
      {required String title, required List<TutorialStep> steps}) {
    return Glass(
      radius: 16,
      padding: const EdgeInsets.all(8),
      onTap: () => show(context, title: title, steps: steps),
      child: Icon(Icons.help_outline, size: 18, color: DC.cyan),
    );
  }

  @override
  State<GameTutorial> createState() => _GameTutorialState();
}

class _GameTutorialState extends State<GameTutorial>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600))
    ..repeat();
  int _i = 0;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _next() {
    if (_i >= widget.steps.length - 1) {
      Navigator.of(context).pop();
    } else {
      setState(() => _i++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_i];
    final last = _i == widget.steps.length - 1;
    return Material(
      color: DC.bg.withOpacity(0.92),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            Row(children: [
              Expanded(
                child: Text(widget.title,
                    style: TextStyle(
                        fontSize: 13,
                        letterSpacing: 3,
                        fontWeight: FontWeight.w900,
                        color: DC.cyan)),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Text('SKIP',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: DC.dim)),
              ),
            ]),
            const Spacer(),
            // looping gesture demo
            SizedBox(
              height: 190,
              width: double.infinity,
              child: AnimatedBuilder(
                animation: _c,
                builder: (_, __) => CustomPaint(
                  painter: _GesturePainter(step.gesture, _c.value),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(step.text,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 18,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                    color: DC.text)),
            const SizedBox(height: 20),
            // progress dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var d = 0; d < widget.steps.length; d++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: d == _i ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: d == _i ? DC.cyan : DC.fgo(0.18),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Row(children: [
              if (_i > 0) ...[
                Expanded(
                  child: GhostButton(
                      label: 'BACK',
                      height: 50,
                      onPressed: () => setState(() => _i--)),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                flex: 2,
                child: NeonButton(
                  label: last ? 'GOT IT!' : 'NEXT',
                  icon:
                      last ? Icons.check_rounded : Icons.arrow_forward_rounded,
                  height: 50,
                  colors: last ? [DC.lime, DC.cyan] : [DC.cyan, DC.violet],
                  onPressed: _next,
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// Draws a single looping gesture demo. [t] is 0..1 (repeating).
class _GesturePainter extends CustomPainter {
  final TutorialGesture gesture;
  final double t;
  _GesturePainter(this.gesture, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    switch (gesture) {
      case TutorialGesture.tap:
        _tap(canvas, size);
      case TutorialGesture.swipeUp:
        _swipeUp(canvas, size);
      case TutorialGesture.dragAcross:
        _dragAcross(canvas, size);
      case TutorialGesture.sequence:
        _sequence(canvas, size);
      case TutorialGesture.none:
        break;
    }
  }

  Paint get _tile => Paint()..color = DC.fgo(0.10);
  Paint _stroke(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round;

  void _finger(Canvas canvas, Offset p, {double press = 0}) {
    // ripple on press
    if (press > 0) {
      canvas.drawCircle(p, 14 + press * 26,
          Paint()..color = DC.cyan.withOpacity((1 - press) * 0.5));
    }
    canvas.drawCircle(p, 16, Paint()..color = DC.cyan);
    canvas.drawCircle(p, 16, _stroke(Colors.white.withOpacity(0.8), 2));
  }

  // TAP: a tile with a finger tapping it (press ripple loop).
  void _tap(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = RRect.fromRectAndRadius(
        Rect.fromCenter(center: c, width: 96, height: 96),
        const Radius.circular(18));
    canvas.drawRRect(r, _tile);
    canvas.drawRRect(r, _stroke(DC.cyan.withOpacity(0.5), 2));
    final press = (math.sin(t * math.pi * 2) * 0.5 + 0.5); // 0..1
    _finger(canvas, c + const Offset(6, 8), press: press);
  }

  // SWIPE UP: arrow + finger travelling from bottom to top.
  void _swipeUp(Canvas canvas, Size size) {
    final x = size.width / 2;
    final bottom = size.height * 0.85;
    final top = size.height * 0.18;
    // dashed track
    for (double y = bottom; y > top; y -= 16) {
      canvas.drawLine(Offset(x, y), Offset(x, y - 7), _stroke(DC.fgo(0.22), 3));
    }
    // arrow head at top
    final ah = Path()
      ..moveTo(x, top - 4)
      ..lineTo(x - 12, top + 14)
      ..moveTo(x, top - 4)
      ..lineTo(x + 12, top + 14);
    canvas.drawPath(ah, _stroke(DC.lime, 4));
    // finger travels up on a loop
    final y = bottom - (bottom - top) * Curves.easeInOut.transform(t);
    _finger(canvas, Offset(x, y));
    _labelPower(canvas, size);
  }

  void _labelPower(Canvas canvas, Size size) {
    final tp = TextPainter(
      text: TextSpan(
          text: 'power ↑',
          style: TextStyle(
              color: DC.lime, fontSize: 12, fontWeight: FontWeight.w800)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(size.width / 2 + 22, size.height * 0.14));
  }

  // DRAG ACROSS: 4 letter tiles, a finger sweeping across them.
  void _dragAcross(Canvas canvas, Size size) {
    const letters = ['M', 'Y', 'N', 'D'];
    final n = letters.length;
    const tile = 52.0;
    const gap = 12.0;
    final totalW = n * tile + (n - 1) * gap;
    final startX = (size.width - totalW) / 2 + tile / 2;
    final cy = size.height / 2;
    final centers = [
      for (var k = 0; k < n; k++) Offset(startX + k * (tile + gap), cy)
    ];
    // progress along the row
    final prog = t * (n - 1);
    for (var k = 0; k < n; k++) {
      final active = prog >= k - 0.35;
      final rect = RRect.fromRectAndRadius(
          Rect.fromCenter(center: centers[k], width: tile, height: tile),
          const Radius.circular(14));
      canvas.drawRRect(rect,
          Paint()..color = active ? DC.cyan.withOpacity(0.30) : DC.fgo(0.08));
      canvas.drawRRect(rect, _stroke(active ? DC.cyan : DC.fgo(0.18), 2));
      final tp = TextPainter(
        text: TextSpan(
            text: letters[k],
            style: TextStyle(
                color: active ? DC.text : DC.dim,
                fontSize: 24,
                fontWeight: FontWeight.w900)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, centers[k] - Offset(tp.width / 2, tp.height / 2));
    }
    // trail + finger
    final idx = prog.floor().clamp(0, n - 1);
    final frac = prog - idx;
    final pos = idx >= n - 1
        ? centers[n - 1]
        : Offset.lerp(centers[idx], centers[idx + 1], frac)!;
    final trail = Path()..moveTo(centers[0].dx, cy);
    for (var k = 1; k <= idx; k++) {
      trail.lineTo(centers[k].dx, cy);
    }
    trail.lineTo(pos.dx, cy);
    canvas.drawPath(trail, _stroke(DC.cyan.withOpacity(0.7), 5));
    _finger(canvas, pos);
  }

  // SEQUENCE: three tiles light up 1-2-3 in a loop (memory games).
  void _sequence(Canvas canvas, Size size) {
    const n = 3;
    const tile = 60.0;
    const gap = 16.0;
    final totalW = n * tile + (n - 1) * gap;
    final startX = (size.width - totalW) / 2 + tile / 2;
    final cy = size.height / 2;
    final lit = (t * n).floor().clamp(0, n - 1);
    for (var k = 0; k < n; k++) {
      final on = k == lit;
      final center = Offset(startX + k * (tile + gap), cy);
      final rect = RRect.fromRectAndRadius(
          Rect.fromCenter(center: center, width: tile, height: tile),
          const Radius.circular(16));
      canvas.drawRRect(
          rect, Paint()..color = on ? DC.amber.withOpacity(0.9) : DC.fgo(0.10));
      canvas.drawRRect(rect, _stroke(on ? DC.amber : DC.fgo(0.2), 2));
      final tp = TextPainter(
        text: TextSpan(
            text: '${k + 1}',
            style: TextStyle(
                color: on ? Colors.black : DC.dim,
                fontSize: 24,
                fontWeight: FontWeight.w900)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_GesturePainter old) =>
      old.t != t || old.gesture != gesture;
}

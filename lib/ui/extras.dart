import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../core/state.dart';
import '../theme_district.dart';
import 'glass.dart';
import 'share_card.dart' show myndashShare;

/// =====================================================================
/// MYNDASH polish widgets — activity heatmap, form strip, confetti,
/// first-time guides, emoji reactions, share snippets.
/// No packages beyond what the app already ships.
/// =====================================================================

/// ---------------- GitHub-style activity heatmap (last 12 weeks) ----------------
class ActivityHeatmap extends StatelessWidget {
  const ActivityHeatmap({super.key});

  static String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // Any activity that day (≥1 solve / game / daily / duel — anything) lights the
  // cell a clearly-visible light blue; higher volume deepens it. The first
  // level is deliberately bright, not a faint 30% tint, so a single play is
  // obviously "on".
  Color _cell(int n) {
    if (n <= 0) return DC.fgo(0.06);
    if (n <= 2) return const Color(0xFF7DD3FC); // light blue — any activity
    if (n <= 5) return const Color(0xFF38BDF8); // sky
    if (n <= 9) return const Color(0xFF0EA5E9); // brighter
    return const Color(0xFF0284C7); // deep blue — a heavy day
  }

  @override
  Widget build(BuildContext context) {
    final a = AppData.i;
    final today = DateTime.now();
    // align so each column is one week ending with today's week
    const weeks = 12;
    final startOffset = (weeks * 7 - 1) + (6 - (today.weekday % 7));
    final start = today.subtract(Duration(days: startOffset));
    var total = 0;
    final cols = <Widget>[];
    for (var w = 0; w < weeks; w++) {
      final cells = <Widget>[];
      for (var d = 0; d < 7; d++) {
        final day = start.add(Duration(days: w * 7 + d));
        final future = day.isAfter(today);
        final n = future ? 0 : a.activityOn(_key(day));
        total += n;
        cells.add(Container(
          width: 13,
          height: 13,
          margin: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: future ? Colors.transparent : _cell(n),
          ),
        ));
      }
      cols.add(Column(mainAxisSize: MainAxisSize.min, children: cells));
    }
    return Glass(
      radius: 20,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('ACTIVITY',
              style: TextStyle(fontSize: 10, letterSpacing: 2, color: DC.dim)),
          const Spacer(),
          Text('$total solves · 12 weeks',
              style: TextStyle(fontSize: 10, color: DC.dim)),
        ]),
        const SizedBox(height: 10),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(mainAxisSize: MainAxisSize.min, children: cols),
        ),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Text('less ', style: TextStyle(fontSize: 9, color: DC.dim)),
          for (final n in [0, 2, 5, 9, 12])
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2), color: _cell(n)),
            ),
          Text(' more', style: TextStyle(fontSize: 9, color: DC.dim)),
        ]),
      ]),
    );
  }
}

/// ---------------- last-5 form strip (W W L W D) ----------------
class FormStrip extends StatelessWidget {
  const FormStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final form = AppData.i.lastForm;
    if (form.isEmpty) {
      return Text('no games yet',
          style: TextStyle(fontSize: 11, color: DC.dim));
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (final r in form.reversed)
        Container(
          width: 26,
          height: 26,
          margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: switch (r) {
              'W' => DC.lime.withOpacity(0.9),
              'L' => DC.danger.withOpacity(0.9),
              _ => DC.amber.withOpacity(0.9),
            },
          ),
          child: Center(
            child: Text(r,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Colors.black)),
          ),
        ),
    ]);
  }
}

/// ---------------- confetti burst (pure widgets, no packages) ----------------
class ConfettiBurst extends StatefulWidget {
  final double height;
  const ConfettiBurst({super.key, this.height = 90});

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1800))
    ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) =>
            CustomPaint(painter: _ConfettiPainter(_c.value)),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double t;
  _ConfettiPainter(this.t);

  List<Color> get _colors =>
      [DC.cyan, DC.magenta, DC.violet, DC.lime, DC.amber];

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(7);
    final paint = Paint();
    for (var i = 0; i < 42; i++) {
      final x0 = rng.nextDouble() * size.width;
      final drift = (rng.nextDouble() - 0.5) * 60;
      final speed = 0.6 + rng.nextDouble() * 0.8;
      final y = (t * speed * (size.height + 40)) - 20 + rng.nextDouble() * 20;
      if (y > size.height) continue;
      final rot = t * (rng.nextDouble() * 8 - 4);
      paint.color = _colors[i % _colors.length]
          .withOpacity((1 - t).clamp(0.0, 1.0).toDouble());
      canvas.save();
      canvas.translate(x0 + drift * t, y);
      canvas.rotate(rot);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: Offset.zero,
                  width: 4 + rng.nextDouble() * 4,
                  height: 7 + rng.nextDouble() * 5),
              const Radius.circular(1.5)),
          paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

/// ---------------- first-time guide overlay (Q0) ----------------
/// Wrap any section: shows a dismissible 2–3 step intro the first time,
/// persists the seen-flag in AppData.
class FirstTimeGuide extends StatefulWidget {
  final String id;
  final String title;
  final String emoji;
  final List<String> steps;
  final Widget child;

  const FirstTimeGuide({
    super.key,
    required this.id,
    required this.title,
    required this.emoji,
    required this.steps,
    required this.child,
  });

  @override
  State<FirstTimeGuide> createState() => _FirstTimeGuideState();
}

class _FirstTimeGuideState extends State<FirstTimeGuide> {
  late bool show = !AppData.i.seenGuide(widget.id);

  void _dismiss() {
    AppData.i.markGuideSeen(widget.id);
    setState(() => show = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!show) return widget.child;
    return Stack(fit: StackFit.expand, children: [
      widget.child,
      Positioned.fill(
        child: GestureDetector(
          onTap: _dismiss,
          child: Container(
            color: Colors.black.withOpacity(0.72),
            padding: const EdgeInsets.all(28),
            child: Center(
              child: GestureDetector(
                onTap: () {}, // don't dismiss when tapping the card
                child: Glass(
                  radius: 26,
                  tint: DC.violet,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(widget.emoji, style: const TextStyle(fontSize: 44)),
                    const SizedBox(height: 8),
                    Text(widget.title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 14),
                    for (var i = 0; i < widget.steps.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                    colors: [DC.violet, DC.cyan]),
                              ),
                              child: Center(
                                child: Text('${i + 1}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900)),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(widget.steps[i],
                                  style: TextStyle(
                                      fontSize: 13,
                                      height: 1.4,
                                      color: DC.text)),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 6),
                    NeonButton(
                        label: 'GOT IT', height: 44, onPressed: _dismiss),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

/// ---------------- emoji reactions row (for result dialogs) ----------------
class ReactionBar extends StatefulWidget {
  const ReactionBar({super.key});

  @override
  State<ReactionBar> createState() => _ReactionBarState();
}

class _ReactionBarState extends State<ReactionBar> {
  String? picked;

  @override
  Widget build(BuildContext context) {
    const emojis = ['🔥', '😎', '🤯', '💀', '🎯'];
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      for (final e in emojis)
        GestureDetector(
          onTap: () => setState(() => picked = e),
          child: AnimatedScale(
            scale: picked == e ? 1.5 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(e, style: const TextStyle(fontSize: 24)),
            ),
          ),
        ),
    ]);
  }
}

/// ---------------- share-your-result snippet ----------------
/// Opens the system share sheet (WhatsApp / Instagram / anywhere) with a
/// consistently-branded MYNDASH message + link. Falls back to the clipboard
/// if the share sheet can't open.
Future<void> shareResult(BuildContext context, String text) async {
  final full = myndashShare(text);
  try {
    await Share.share(full);
  } catch (_) {
    await Clipboard.setData(ClipboardData(text: full));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Copied! Paste it anywhere to flex 😎')));
    }
  }
}

/// ---------------- letter avatar ----------------
/// A circular avatar showing the first letter of a name — used for
/// opponents (bots & humans) instead of a generic robot icon.
class LetterAvatar extends StatelessWidget {
  final String name;
  final Color? color;
  final double size;
  const LetterAvatar(
      {super.key, required this.name, this.color, this.size = 26});

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? DC.magenta;
    final ch = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
            colors: [color.withOpacity(0.85), color.withOpacity(0.45)]),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Text(ch,
          style: TextStyle(
              fontSize: size * 0.5,
              fontWeight: FontWeight.w900,
              color: Colors.white)),
    );
  }
}

/// ---------------- compact stat wallet ----------------
/// Streak (if > 0) · XP · coins on a single line. Replaces three separate
/// Pills in the header so the MYNDASH wordmark keeps its space.
class StatWallet extends StatelessWidget {
  final int streak, xp, coins;
  const StatWallet(
      {super.key, this.streak = 0, required this.xp, required this.coins});

  Widget _stat(IconData i, int v, Color c) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(i, size: 14, color: c),
        const SizedBox(width: 3),
        Text('$v',
            style:
                TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: c)),
      ]);

  @override
  Widget build(BuildContext context) {
    return Glass(
      radius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (streak > 0) ...[
          _stat(Icons.local_fire_department, streak, DC.magenta),
          const SizedBox(width: 9),
        ],
        _stat(Icons.bolt, xp, DC.cyan),
        const SizedBox(width: 9),
        _stat(Icons.monetization_on, coins, DC.amber),
      ]),
    );
  }
}

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme.dart';
import '../widgets/glass.dart';

/// Plays one [RoundSpec]. Both phones derive the identical challenge
/// from the spec's seed, and the challenge fires at the shared
/// server-clock timestamp [RoundSpec.goAtMs] — so it's lag-fair.
///
/// Calls [onFinish] exactly once with the reaction time in ms,
/// or -1 for a false start / wrong answer.
class RoundPlayer extends StatefulWidget {
  final RoundSpec spec;
  final int Function() nowMs; // server-synced clock
  final void Function(int timeMs) onFinish;

  const RoundPlayer({
    super.key,
    required this.spec,
    required this.nowMs,
    required this.onFinish,
  });

  @override
  State<RoundPlayer> createState() => _RoundPlayerState();
}

class _RoundPlayerState extends State<RoundPlayer> {
  Timer? _ticker;
  bool _finished = false;
  int _myTime = 0;

  // sequence round state
  int _seqProgress = 0;
  int? _seqInputStart;

  late final Random _rng = Random(widget.spec.seed);
  late final _TrapPlan? _trap;
  late final _TargetPlan? _targetPlan;
  late final List<int> _seqDirs;
  late final _MathPlan? _math;

  int get _goAt => widget.spec.goAtMs;

  @override
  void initState() {
    super.initState();
    _trap = widget.spec.type == RoundType.trap ? _TrapPlan(_rng) : null;
    _targetPlan =
        widget.spec.type == RoundType.target ? _TargetPlan(_rng) : null;
    _seqDirs = widget.spec.type == RoundType.sequence
        ? List.generate(4, (_) => _rng.nextInt(4))
        : const [];
    _math = widget.spec.type == RoundType.math ? _MathPlan(_rng) : null;
    _ticker = Timer.periodic(
        const Duration(milliseconds: 16), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _finish(int timeMs) {
    if (_finished) return;
    _finished = true;
    _myTime = timeMs;
    widget.onFinish(timeMs);
    setState(() {});
  }

  /// The moment the actionable stimulus appears (deterministic per seed).
  int get _stimulusAt => switch (widget.spec.type) {
        RoundType.trap => _trap!.stimulusAt(_goAt),
        RoundType.sequence => _goAt + 1400,
        RoundType.memflash => _goAt + 900,
        _ => _goAt,
      };

  @override
  Widget build(BuildContext context) {
    final now = widget.nowMs();

    if (_finished) return _waitingOverlay(context);

    if (now < _goAt) return _preCountdown(context, now);

    return switch (widget.spec.type) {
      RoundType.strike => _strike(context, now),
      RoundType.trap => _trapView(context, now),
      RoundType.target => _target(context, now),
      RoundType.sequence => _sequence(context, now),
      RoundType.math => _mathView(context, now),
      RoundType.stroop => _stroop(context, now),
      RoundType.oddemoji => _oddEmoji(context, now),
      RoundType.countdots => _countDots(context, now),
      RoundType.arrows => _arrowFlip(context, now),
      RoundType.bigger => _bigger(context, now),
      RoundType.memflash => _memFlash(context, now),
      RoundType.avoid => _avoid(context, now),
    };
  }

  // ---------------- shared views ----------------

  Widget _preCountdown(BuildContext context, int now) {
    final secs = ((_goAt - now) / 1000).ceil();
    return _fullTap(
      onTap: () => _finish(-1), // tapping early is a false start
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(widget.spec.type.title,
              style: Theme.of(context).textTheme.displayMedium),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              widget.spec.type.hint,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 15,
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
            ),
          ),
          const SizedBox(height: 40),
          _pulse(
            Text('$secs',
                style: Theme.of(context)
                    .textTheme
                    .displayLarge
                    ?.copyWith(fontSize: 72, color: RDColors.cyan)),
          ),
          const SizedBox(height: 16),
          Text('GET READY — no early taps!',
              style: TextStyle(
                  letterSpacing: 2,
                  fontSize: 12,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.5))),
        ],
      ),
    );
  }

  Widget _waitingOverlay(BuildContext context) {
    final good = _myTime >= 0;
    return Center(
      child: GlassCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(good ? Icons.bolt : Icons.close_rounded,
                size: 48, color: good ? RDColors.lime : RDColors.danger),
            const SizedBox(height: 10),
            Text(
              good ? '${_myTime} ms' : 'FAULT!',
              style: Theme.of(context)
                  .textTheme
                  .displayMedium
                  ?.copyWith(color: good ? RDColors.lime : RDColors.danger),
            ),
            const SizedBox(height: 8),
            const Text('Waiting for opponent…'),
          ],
        ),
      ),
    );
  }

  Widget _pulse(Widget child) => TweenAnimationBuilder<double>(
        key: ValueKey(widget.nowMs() ~/ 1000),
        tween: Tween(begin: 1.25, end: 1.0),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOutBack,
        builder: (_, v, c) => Transform.scale(scale: v, child: c),
        child: child,
      );

  Widget _fullTap({required VoidCallback onTap, required Widget child}) =>
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => onTap(),
        child: SizedBox.expand(child: child),
      );

  // ---------------- STRIKE ----------------
  Widget _strike(BuildContext context, int now) {
    return _fullTap(
      onTap: () => _finish(widget.nowMs() - _goAt),
      child: Container(
        margin: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient:
              const LinearGradient(colors: [RDColors.lime, Color(0xFF00C853)]),
          boxShadow: [
            BoxShadow(
                color: RDColors.lime.withOpacity(0.5),
                blurRadius: 40,
                spreadRadius: 4)
          ],
        ),
        child: Center(
          child: Text('STRIKE!',
              style: Theme.of(context)
                  .textTheme
                  .displayLarge
                  ?.copyWith(color: Colors.white, fontSize: 52)),
        ),
      ),
    );
  }

  // ---------------- TRAP ----------------
  Widget _trapView(BuildContext context, int now) {
    final seg = _trap!.segmentAt(_goAt, now);
    if (seg == _TrapSeg.go) {
      return _fullTap(
        onTap: () => _finish(widget.nowMs() - _stimulusAt),
        child: Container(
          margin: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
                colors: [RDColors.lime, Color(0xFF00C853)]),
          ),
          child: Center(
            child: Text('GO!',
                style: Theme.of(context)
                    .textTheme
                    .displayLarge
                    ?.copyWith(color: Colors.white, fontSize: 56)),
          ),
        ),
      );
    }
    final isDecoy = seg == _TrapSeg.decoy;
    return _fullTap(
      onTap: () => _finish(-1), // tapped a trap or the gap
      child: Container(
        margin: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          color: isDecoy ? RDColors.danger : Colors.transparent,
          border: isDecoy
              ? null
              : Border.all(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.2)),
        ),
        child: Center(
          child: Text(isDecoy ? 'TRAP!' : '…',
              style: Theme.of(context)
                  .textTheme
                  .displayLarge
                  ?.copyWith(color: Colors.white, fontSize: 52)),
        ),
      ),
    );
  }

  // ---------------- TARGET ----------------
  Widget _target(BuildContext context, int now) {
    final elapsed = now - _goAt;
    final shrink = (elapsed / 2500).clamp(0.0, 1.0);
    final radius = 56 - 40 * shrink;
    return LayoutBuilder(builder: (context, box) {
      final cx = _targetPlan!.x * box.maxWidth;
      final cy = _targetPlan!.y * box.maxHeight;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) {
          final p = d.localPosition;
          final hit =
              (p - Offset(cx, cy)).distance <= radius + 8; // small grace
          _finish(hit ? widget.nowMs() - _goAt : -1);
        },
        child: Stack(
          children: [
            Positioned(
              left: cx - radius,
              top: cy - radius,
              child: Container(
                width: radius * 2,
                height: radius * 2,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                      colors: [RDColors.magenta, RDColors.violet]),
                  boxShadow: [
                    BoxShadow(
                        color: RDColors.magenta.withOpacity(0.6),
                        blurRadius: 24)
                  ],
                ),
                child: const Center(
                    child:
                        Icon(Icons.gps_fixed, color: Colors.white, size: 26)),
              ),
            ),
          ],
        ),
      );
    });
  }

  // ---------------- SEQUENCE ----------------
  static const _dirIcons = [
    Icons.keyboard_arrow_up_rounded,
    Icons.keyboard_arrow_down_rounded,
    Icons.keyboard_arrow_left_rounded,
    Icons.keyboard_arrow_right_rounded,
  ];

  Widget _sequence(BuildContext context, int now) {
    final showing = now < _goAt + 1400;
    if (showing) {
      return Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final d in _seqDirs)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: GlassCard(
                  padding: const EdgeInsets.all(10),
                  radius: 18,
                  child: Icon(_dirIcons[d], size: 44, color: RDColors.cyan),
                ),
              ),
          ],
        ),
      );
    }
    _seqInputStart ??= _goAt + 1400;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('REPEAT!  ${_seqProgress}/4',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 24),
        Wrap(
          spacing: 14,
          runSpacing: 14,
          alignment: WrapAlignment.center,
          children: [
            for (int d = 0; d < 4; d++)
              GestureDetector(
                onTapDown: (_) {
                  if (_finished) return;
                  if (_seqDirs[_seqProgress] == d) {
                    _seqProgress++;
                    if (_seqProgress >= 4) {
                      _finish(widget.nowMs() - _seqInputStart!);
                    } else {
                      setState(() {});
                    }
                  } else {
                    _finish(-1);
                  }
                },
                child: GlassCard(
                  padding: const EdgeInsets.all(18),
                  radius: 22,
                  child: Icon(_dirIcons[d],
                      size: 48, color: Theme.of(context).colorScheme.onSurface),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // ---------------- MATH ----------------
  Widget _mathView(BuildContext context, int now) {
    final m = _math!;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(m.question,
            style: Theme.of(context)
                .textTheme
                .displayLarge
                ?.copyWith(fontSize: 56)),
        const SizedBox(height: 36),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final opt in m.options)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: GestureDetector(
                  onTapDown: (_) =>
                      _finish(opt == m.answer ? widget.nowMs() - _goAt : -1),
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 18),
                    radius: 20,
                    child: Text('$opt',
                        style: const TextStyle(
                            fontSize: 28, fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // ---------------- EXPANSION ROUNDS (seed-identical on both phones) ----

  Widget _pad2(Widget child) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24), child: child);

  /// COLOR TRAP — stroop: word says one color, painted another.
  Widget _stroop(BuildContext context, int now) {
    final rng = Random(widget.spec.seed);
    const names = ['RED', 'GREEN', 'BLUE', 'YELLOW'];
    const colors = [DC_red, DC_green, DC_blue, DC_yellow];
    final wordIdx = rng.nextInt(4);
    var inkIdx = rng.nextInt(4);
    if (inkIdx == wordIdx) inkIdx = (inkIdx + 1) % 4;
    final order = [0, 1, 2, 3]..shuffle(rng);
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(names[wordIdx],
          style: TextStyle(
              fontSize: 54,
              fontWeight: FontWeight.w900,
              color: colors[inkIdx])),
      const SizedBox(height: 28),
      _pad2(Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            for (final i in order)
              GestureDetector(
                onTapDown: (_) =>
                    _finish(i == inkIdx ? widget.nowMs() - _goAt : -1),
                child: Container(
                  width: 74,
                  height: 52,
                  decoration: BoxDecoration(
                    color: colors[i],
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                      child: Text(names[i],
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: Colors.black87))),
                ),
              ),
          ])),
    ]);
  }

  static const DC_red = Color(0xFFFF5252);
  static const DC_green = Color(0xFF69F0AE);
  static const DC_blue = Color(0xFF40C4FF);
  static const DC_yellow = Color(0xFFFFD740);

  /// ODD ONE — one emoji differs in an n×n grid (n grows with seed).
  Widget _oddEmoji(BuildContext context, int now) {
    final rng = Random(widget.spec.seed);
    const pairs = [
      ('😀', '😃'),
      ('🐶', '🐕'),
      ('⭐', '🌟'),
      ('🍎', '🍅'),
      ('🐱', '🦁'),
      ('🌚', '🌑'),
      ('🔵', '🟦'),
      ('❤️', '🧡'),
    ];
    final pair = pairs[rng.nextInt(pairs.length)];
    final n = 3 + rng.nextInt(3); // 3..5 → difficulty variation
    final odd = rng.nextInt(n * n);
    return Center(
      child: SizedBox(
        width: 300,
        child: Wrap(alignment: WrapAlignment.center, children: [
          for (var i = 0; i < n * n; i++)
            GestureDetector(
              onTapDown: (_) => _finish(i == odd ? widget.nowMs() - _goAt : -1),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Text(i == odd ? pair.$2 : pair.$1,
                    style:
                        TextStyle(fontSize: n == 3 ? 44 : (n == 4 ? 34 : 27))),
              ),
            ),
        ]),
      ),
    );
  }

  /// DOT COUNT — count scattered dots, pick the number.
  Widget _countDots(BuildContext context, int now) {
    final rng = Random(widget.spec.seed);
    final count = 5 + rng.nextInt(9); // 5..13
    final positions =
        List.generate(count, (_) => Offset(rng.nextDouble(), rng.nextDouble()));
    final opts = <int>{count};
    while (opts.length < 3) {
      final v = count + rng.nextInt(5) - 2;
      if (v > 0) opts.add(v);
    }
    final options = opts.toList()..shuffle(rng);
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      SizedBox(
        width: 260,
        height: 200,
        child: Stack(children: [
          for (final p in positions)
            Positioned(
              left: p.dx * 236,
              top: p.dy * 176,
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: DC_yellow),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 18),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (final o in options)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: GestureDetector(
              onTapDown: (_) =>
                  _finish(o == count ? widget.nowMs() - _goAt : -1),
              child: GlassCard(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                radius: 18,
                child: Text('$o',
                    style: const TextStyle(
                        fontSize: 26, fontWeight: FontWeight.w900)),
              ),
            ),
          ),
      ]),
    ]);
  }

  /// ARROW FLIP — tap the OPPOSITE direction of the shown arrow.
  Widget _arrowFlip(BuildContext context, int now) {
    final rng = Random(widget.spec.seed);
    final dir = rng.nextInt(4); // up down left right
    final opposite = switch (dir) { 0 => 1, 1 => 0, 2 => 3, _ => 2 };
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(_dirIcons[dir], size: 110, color: DC_yellow),
      const SizedBox(height: 6),
      const Text('tap the OPPOSITE',
          style: TextStyle(fontSize: 11, letterSpacing: 2)),
      const SizedBox(height: 18),
      Wrap(
          spacing: 14,
          runSpacing: 14,
          alignment: WrapAlignment.center,
          children: [
            for (var d = 0; d < 4; d++)
              GestureDetector(
                onTapDown: (_) =>
                    _finish(d == opposite ? widget.nowMs() - _goAt : -1),
                child: GlassCard(
                  padding: const EdgeInsets.all(16),
                  radius: 20,
                  child: Icon(_dirIcons[d], size: 42),
                ),
              ),
          ]),
    ]);
  }

  /// BIG NUMBER — visual size is a distraction; value decides.
  Widget _bigger(BuildContext context, int now) {
    final rng = Random(widget.spec.seed);
    final a = 10 + rng.nextInt(89);
    var b = 10 + rng.nextInt(89);
    if (b == a) b = (b % 89) + 11;
    final bigger = a > b ? a : b;
    // Which value renders LARGE is a seeded coin-flip — sometimes the bigger
    // value looks bigger, sometimes smaller. Kills the old "answer is always
    // the physically small one" tell that made this trivially learnable.
    final biggerRendersLarge = rng.nextBool();
    // Left/right order is randomized too, so position is never a tell.
    final leftIsA = rng.nextBool();
    Widget numBox(int v) {
      final renderLarge =
          v == bigger ? biggerRendersLarge : !biggerRendersLarge;
      return GestureDetector(
        onTapDown: (_) => _finish(v == bigger ? widget.nowMs() - _goAt : -1),
        child: GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 18),
          radius: 22,
          child: Text('$v',
              style: TextStyle(
                  fontSize: renderLarge ? 56 : 26,
                  fontWeight: FontWeight.w900)),
        ),
      );
    }

    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      numBox(leftIsA ? a : b),
      const SizedBox(width: 22),
      numBox(leftIsA ? b : a),
    ]);
  }

  /// MEM FLASH — a 4-digit number flashes 900ms, then pick it.
  Widget _memFlash(BuildContext context, int now) {
    final rng = Random(widget.spec.seed);
    final target = 1000 + rng.nextInt(9000);
    final showing = now < _goAt + 900;
    if (showing) {
      return Center(
          child: Text('$target',
              style: const TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 6)));
    }
    final opts = <int>{target};
    while (opts.length < 3) {
      // near-miss traps: swapped/shifted digits
      final trick = rng.nextBool()
          ? target + (rng.nextBool() ? 10 : -10)
          : target + (rng.nextBool() ? 100 : -100);
      if (trick > 999) opts.add(trick);
    }
    final options = opts.toList()..shuffle(rng);
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('WHICH WAS IT?',
          style: TextStyle(letterSpacing: 3, fontSize: 12)),
      const SizedBox(height: 18),
      for (final o in options)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTapDown: (_) =>
                _finish(o == target ? widget.nowMs() - _stimulusAt : -1),
            child: GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
              radius: 18,
              child: Text('$o',
                  style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 4)),
            ),
          ),
        ),
    ]);
  }

  /// BOMB DODGE — tap all stars, never a bomb. Time = last star.
  final Set<int> _avoidHits = {};

  Widget _avoid(BuildContext context, int now) {
    final rng = Random(widget.spec.seed);
    final cells = 3 + rng.nextInt(2); // 3..4 stars
    final total = 6;
    final starIdx = <int>{};
    while (starIdx.length < cells) {
      starIdx.add(rng.nextInt(total));
    }
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text('${_avoidHits.length}/$cells ⭐',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      const SizedBox(height: 14),
      Wrap(
          spacing: 14,
          runSpacing: 14,
          alignment: WrapAlignment.center,
          children: [
            for (var i = 0; i < total; i++)
              GestureDetector(
                onTapDown: (_) {
                  if (_finished) return;
                  if (!starIdx.contains(i)) {
                    _finish(-1); // bomb!
                    return;
                  }
                  if (_avoidHits.contains(i)) return;
                  setState(() => _avoidHits.add(i));
                  if (_avoidHits.length >= cells) {
                    _finish(widget.nowMs() - _goAt);
                  }
                },
                child: GlassCard(
                  padding: const EdgeInsets.all(14),
                  radius: 20,
                  child: Text(
                      _avoidHits.contains(i)
                          ? '✅'
                          : (starIdx.contains(i) ? '⭐' : '💣'),
                      style: const TextStyle(fontSize: 34)),
                ),
              ),
          ]),
    ]);
  }
}

// ---------------- seeded plans ----------------

enum _TrapSeg { decoy, gap, go }

class _TrapPlan {
  late final List<int> durations; // decoy durations
  static const gapMs = 260;

  _TrapPlan(Random rng) {
    final n = 1 + rng.nextInt(3);
    durations = List.generate(n, (_) => 550 + rng.nextInt(550));
  }

  int stimulusAt(int goAt) =>
      goAt + durations.fold<int>(0, (a, b) => a + b) + durations.length * gapMs;

  _TrapSeg segmentAt(int goAt, int now) {
    var t = goAt;
    for (final d in durations) {
      if (now < t + d) return _TrapSeg.decoy;
      t += d;
      if (now < t + gapMs) return _TrapSeg.gap;
      t += gapMs;
    }
    return _TrapSeg.go;
  }
}

class _TargetPlan {
  late final double x, y;
  _TargetPlan(Random rng) {
    x = 0.18 + rng.nextDouble() * 0.64;
    y = 0.18 + rng.nextDouble() * 0.64;
  }
}

class _MathPlan {
  late final String question;
  late final int answer;
  late final List<int> options;

  _MathPlan(Random rng) {
    final a = 3 + rng.nextInt(16);
    final b = 3 + rng.nextInt(16);
    final op = rng.nextInt(3);
    switch (op) {
      case 0:
        question = '$a + $b';
        answer = a + b;
      case 1:
        question = '${a + b} − $b';
        answer = a;
      default:
        final x = 2 + rng.nextInt(8);
        final y = 2 + rng.nextInt(8);
        question = '$x × $y';
        answer = x * y;
    }
    final opts = <int>{answer};
    while (opts.length < 3) {
      final delta = (1 + rng.nextInt(4)) * (rng.nextBool() ? 1 : -1);
      final v = answer + delta;
      if (v > 0) opts.add(v);
    }
    options = opts.toList()..shuffle(rng);
  }
}

/// Simple AI opponent for practice mode.
class DuelBot {
  final Random _r = Random();
  int wins = 0;

  /// Bot reaction for a round; difficulty scales with [roundIndex].
  int reactFor(RoundType type, int roundIndex) {
    // ~8% chance the bot faults
    if (_r.nextDouble() < 0.08) return -1;
    final base = switch (type) {
      RoundType.strike => 330,
      RoundType.trap => 380,
      RoundType.target => 520,
      RoundType.sequence => 1500,
      RoundType.math => 1400,
      RoundType.stroop => 900,
      RoundType.oddemoji => 1100,
      RoundType.countdots => 1600,
      RoundType.arrows => 700,
      RoundType.bigger => 650,
      RoundType.memflash => 1500,
      RoundType.avoid => 1800,
    };
    final skillBoost = min(roundIndex * 12, 90); // gets sharper each round
    return base - skillBoost + _r.nextInt(240);
  }
}

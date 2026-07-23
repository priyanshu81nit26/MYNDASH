import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/fx.dart';
import '../core/state.dart';
import '../engine/rating_catalog.dart';
import '../theme_district.dart';
import '../ui/extras.dart';
import '../ui/game_tutorial.dart';
import '../ui/glass.dart';

/// Level-0 "how to play" for Darts.
const dartsTutorial = [
  TutorialStep('Press and hold in the launch zone at the bottom.',
      gesture: TutorialGesture.tap),
  TutorialStep('Drag straight UP and release to throw the dart.',
      gesture: TutorialGesture.swipeUp),
  TutorialStep(
      'Longer drag = more power (match the ghost ring). Drift left/right to aim.',
      gesture: TutorialGesture.swipeUp),
];

/// ============================================================
/// DARTS ENGINE — swipe-to-throw physics on a real board.
///
/// Controls: press in the launch zone, drag UP and release —
///   · drag length/straightness = power (match the ghost ring)
///   · horizontal drift of the drag = aim left/right
/// Rating design (800–2500):
///   · 800–1100 static board, shrinking as rating rises
///   · 1200–1800 board slides side to side, faster at higher ratings
///   · 1900–2500 a moving blocker sweeps IN FRONT of the board
/// ============================================================

class DartConfig {
  final double boardScale; // 1.0 → smaller
  final double boardSpeed; // 0 = static, oscillations per second
  final bool obstacle; // blocker sweeping in front
  final double obstacleSpeed;

  const DartConfig({
    this.boardScale = 1.0,
    this.boardSpeed = 0,
    this.obstacle = false,
    this.obstacleSpeed = 0.5,
  });

  /// Config for a journey level 1..50.
  factory DartConfig.level(int level) {
    final scale = (1.0 - (level - 1) * 0.008).clamp(0.58, 1.0).toDouble();
    if (level <= 10) return DartConfig(boardScale: scale);
    if (level <= 30) {
      return DartConfig(
          boardScale: scale, boardSpeed: 0.22 + (level - 11) * 0.033);
    }
    return DartConfig(
      boardScale: scale,
      boardSpeed: 0.5 + (level - 31) * 0.02,
      obstacle: true,
      obstacleSpeed: 0.45 + (level - 31) * 0.028,
    );
  }
}

/// One throw's outcome.
class DartHit {
  final int score; // 0..100 (50+ ring, 100 bullseye zone)
  final bool blocked;
  const DartHit(this.score, {this.blocked = false});
}

class DartThrowBoard extends StatefulWidget {
  final DartConfig config;
  final bool enabled;
  final void Function(DartHit hit) onThrow;

  const DartThrowBoard({
    super.key,
    required this.config,
    required this.enabled,
    required this.onThrow,
  });

  @override
  State<DartThrowBoard> createState() => _DartThrowBoardState();
}

class _DartThrowBoardState extends State<DartThrowBoard>
    with TickerProviderStateMixin {
  late final AnimationController world =
      AnimationController(vsync: this, duration: const Duration(seconds: 4))
        ..repeat();
  AnimationController? flight;
  final rng = math.Random();

  // drag state
  Offset? dragStart;
  Offset? dragNow;

  // dart in flight / landed
  Offset? dartFrom;
  Offset? dartTo;
  bool inFlight = false;
  Offset? lastLanding; // board-relative marker
  String? feedback; // "BULLSEYE!", "BLOCKED", …

  static const idealDrag = 240.0; // px of upward drag = perfect power

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        GameTutorial.showOnce(context,
            tutKey: 'darts', title: 'DARTS', steps: dartsTutorial);
      }
    });
  }

  @override
  void dispose() {
    world.dispose();
    flight?.dispose();
    super.dispose();
  }

  // ---------------- geometry ----------------

  double boardR(Size s) =>
      math.min(s.width, s.height * 0.62) * 0.30 * widget.config.boardScale;

  Offset boardCenter(Size s, double t) {
    final amp =
        widget.config.boardSpeed == 0 ? 0.0 : s.width * 0.5 - boardR(s) - 8;
    final x = s.width / 2 +
        amp *
            math.sin(2 *
                math.pi *
                widget.config.boardSpeed *
                t *
                world.duration!.inSeconds);
    return Offset(x, s.height * 0.24);
  }

  /// Blocker: a vertical bar sweeping across the board's height band.
  double obstacleX(Size s, double t) {
    final span = s.width * 0.9;
    final ph =
        (t * widget.config.obstacleSpeed * world.duration!.inSeconds) % 1.0;
    // triangle wave for a smooth back & forth sweep
    final tri = ph < 0.5 ? ph * 2 : 2 - ph * 2;
    return s.width * 0.05 + span * tri;
  }

  Offset launchPoint(Size s) => Offset(s.width / 2, s.height - 46);

  // ---------------- throwing ----------------

  void _panStart(DragStartDetails d, Size s) {
    if (!widget.enabled || inFlight) return;
    if (d.localPosition.dy < s.height * 0.55) return; // launch zone only
    dragStart = d.localPosition;
    dragNow = d.localPosition;
    feedback = null;
    setState(() {});
  }

  void _panUpdate(DragUpdateDetails d) {
    if (dragStart == null) return;
    dragNow = d.localPosition;
    setState(() {});
  }

  void _panEnd(Size s) {
    final start = dragStart, end = dragNow;
    dragStart = null;
    dragNow = null;
    if (start == null || end == null) return;
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    if (dy > -40) {
      setState(() => feedback = 'Flick UP to throw 🎯');
      return;
    }
    // power 0..~1.6 (1.0 = perfect); aim from horizontal drift
    final power = (-dy / idealDrag).clamp(0.35, 1.7).toDouble();
    final launch = launchPoint(s);
    final tImpact = world.value; // board sampled when dart lands (~now)
    final center = boardCenter(s, tImpact);
    // intended x: launch + amplified drift; vertical error from power
    final aimX = launch.dx + dx * 2.6 + (rng.nextDouble() - 0.5) * 10;
    final missY = (1.0 - power) * 230; // weak = lands low, hot = high
    final aimY = center.dy + missY + (rng.nextDouble() - 0.5) * 12;
    final to = Offset(aimX.clamp(8.0, s.width - 8.0).toDouble(),
        aimY.clamp(20.0, s.height * 0.6).toDouble());

    Fx.impact(); // the dart leaves the hand
    dartFrom = launch;
    dartTo = to;
    inFlight = true;
    flight?.dispose();
    flight = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 340))
      ..addListener(() => setState(() {}))
      ..addStatusListener((st) {
        if (st == AnimationStatus.completed) _land(s, to);
      })
      ..forward();
    setState(() {});
  }

  void _land(Size s, Offset to) {
    inFlight = false;
    final t = world.value;
    final center = boardCenter(s, t);
    final r = boardR(s);
    // blocked by the sweeping bar?
    if (widget.config.obstacle) {
      final ox = obstacleX(s, t);
      final inBand = (to.dy - center.dy).abs() < r + 26;
      if (inBand && (to.dx - ox).abs() < 14) {
        lastLanding = null;
        feedback = '🚫 BLOCKED';
        Fx.fail();
        widget.onThrow(const DartHit(0, blocked: true));
        setState(() {});
        return;
      }
    }
    final dist = (to - center).distance;
    int score;
    if (dist > r) {
      score = 0;
      feedback = 'MISS';
      Fx.fail();
    } else {
      Fx.success();
      final f = dist / r;
      if (f < 0.08) {
        score = 100;
        feedback = '🎯 BULLSEYE!';
      } else if (f < 0.25) {
        score = 80;
        feedback = '🔥 INNER RING';
      } else {
        score = (70 * (1 - f)).round() + 5;
        feedback = '+$score';
      }
      lastLanding = to - center; // remember relative to board
    }
    widget.onThrow(DartHit(score));
    setState(() {});
  }

  // ---------------- painting ----------------

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final s = Size(box.maxWidth, box.maxHeight);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (d) => _panStart(d, s),
        onPanUpdate: _panUpdate,
        onPanEnd: (_) => _panEnd(s),
        child: AnimatedBuilder(
          animation: world,
          builder: (context, _) => CustomPaint(
            size: s,
            painter: _DartPainter(
              boardCenter: boardCenter(s, world.value),
              r: boardR(s),
              obstacleX:
                  widget.config.obstacle ? obstacleX(s, world.value) : null,
              launch: launchPoint(s),
              dragStart: dragStart,
              dragNow: dragNow,
              dartPos: _dartPos(),
              dartT: flight?.value ?? 0,
              lastLanding: lastLanding,
              feedback: feedback,
              enabled: widget.enabled && !inFlight,
            ),
          ),
        ),
      );
    });
  }

  Offset? _dartPos() {
    if (!inFlight || dartFrom == null || dartTo == null) return null;
    final t = Curves.easeOut.transform(flight!.value);
    final p = Offset.lerp(dartFrom, dartTo, t)!;
    // little arc for depth
    return p - Offset(0, math.sin(t * math.pi) * 36);
  }
}

class _DartPainter extends CustomPainter {
  final Offset boardCenter, launch;
  final double r;
  final double? obstacleX;
  final Offset? dragStart, dragNow, dartPos, lastLanding;
  final double dartT;
  final String? feedback;
  final bool enabled;

  _DartPainter({
    required this.boardCenter,
    required this.r,
    required this.obstacleX,
    required this.launch,
    required this.dragStart,
    required this.dragNow,
    required this.dartPos,
    required this.dartT,
    required this.lastLanding,
    required this.feedback,
    required this.enabled,
  });

  @override
  void paint(Canvas canvas, Size s) {
    // ---- board ----
    final rings = <(double, Color)>[
      (1.0, const Color(0xFF163425)),
      (0.82, const Color(0xFFE8E4D8)),
      (0.66, const Color(0xFF1B4D33)),
      (0.5, const Color(0xFFE8E4D8)),
      (0.34, const Color(0xFF1B4D33)),
      (0.25, DC.danger.withOpacity(0.85)),
      (0.08, DC.amber),
    ];
    for (final (f, c) in rings) {
      canvas.drawCircle(boardCenter, r * f, Paint()..color = c);
    }
    canvas.drawCircle(
        boardCenter,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Colors.black54);
    // wires
    final wire = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.black38;
    for (var i = 0; i < 10; i++) {
      final a = i * math.pi / 5;
      canvas.drawLine(boardCenter + Offset(math.cos(a), math.sin(a)) * r * 0.25,
          boardCenter + Offset(math.cos(a), math.sin(a)) * r, wire);
    }
    // previous landing marker
    if (lastLanding != null) {
      canvas.drawCircle(
          boardCenter + lastLanding!, 4, Paint()..color = DC.cyan);
      canvas.drawCircle(
          boardCenter + lastLanding!,
          7,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = DC.fg70);
    }
    // ---- obstacle ----
    if (obstacleX != null) {
      final p = Paint()
        ..shader = LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [DC.magenta.withOpacity(0.9), DC.violet])
            .createShader(Rect.fromLTWH(
                obstacleX! - 7, boardCenter.dy - r - 30, 14, 2 * r + 60));
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(
                  obstacleX! - 7, boardCenter.dy - r - 30, 14, 2 * r + 60),
              const Radius.circular(7)),
          p);
    }
    // ---- launch zone ----
    final zoneY = s.height * 0.55;
    canvas.drawLine(
        Offset(16, zoneY),
        Offset(s.width - 16, zoneY),
        Paint()
          ..strokeWidth = 1
          ..color = DC.fg12);
    // power guide ring at ideal drag distance
    if (dragStart != null) {
      canvas.drawCircle(
          dragStart!,
          _DartThrowBoardState.idealDrag,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = DC.cyan.withOpacity(0.25));
    }
    // drag aim line + power bar
    if (dragStart != null && dragNow != null) {
      canvas.drawLine(
          dragStart!,
          dragNow!,
          Paint()
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round
            ..color = DC.cyan.withOpacity(0.8));
      final pow =
          ((dragStart!.dy - dragNow!.dy) / _DartThrowBoardState.idealDrag)
              .clamp(0.0, 1.7);
      final barW = s.width * 0.5;
      final rect = Rect.fromLTWH((s.width - barW) / 2, s.height - 22, barW, 8);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)),
          Paint()..color = DC.fg12);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(
                  rect.left, rect.top, barW * (pow / 1.7).clamp(0.0, 1.0), 8),
              const Radius.circular(4)),
          Paint()..color = (pow > 0.85 && pow < 1.15) ? DC.lime : DC.amber);
    }
    // ---- dart ----
    final d = dartPos ?? (enabled ? launch : null);
    if (d != null) {
      final size = 1.0 - 0.45 * dartT; // shrinks as it flies away
      final body = Paint()..color = DC.amber;
      canvas.save();
      canvas.translate(d.dx, d.dy);
      canvas.scale(size);
      // tip
      canvas.drawPath(
          Path()
            ..moveTo(0, -16)
            ..lineTo(3.5, -4)
            ..lineTo(-3.5, -4)
            ..close(),
          Paint()..color = const Color(0xFFB0BEC5));
      // shaft
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              const Rect.fromLTWH(-2.5, -4, 5, 16), const Radius.circular(2)),
          body);
      // flights
      canvas.drawPath(
          Path()
            ..moveTo(0, 8)
            ..lineTo(7, 18)
            ..lineTo(0, 14)
            ..lineTo(-7, 18)
            ..close(),
          Paint()..color = DC.cyan);
      canvas.restore();
    }
    // ---- feedback text ----
    if (feedback != null) {
      final tp = TextPainter(
          textDirection: TextDirection.ltr,
          text: TextSpan(
              text: feedback,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: feedback!.contains('BULLS')
                      ? DC.amber
                      : feedback!.contains('BLOCK') || feedback == 'MISS'
                          ? DC.danger
                          : DC.lime,
                  shadows: const [Shadow(color: Colors.black, blurRadius: 6)])))
        ..layout();
      tp.paint(
          canvas, Offset((s.width - tp.width) / 2, boardCenter.dy + r + 18));
    }
    // hint
    if (enabled && dragStart == null && dartPos == null) {
      final tp = TextPainter(
          textDirection: TextDirection.ltr,
          text: TextSpan(
              text: 'press below the line · flick UP to throw',
              style: TextStyle(fontSize: 11, color: DC.fg38)))
        ..layout();
      tp.paint(canvas, Offset((s.width - tp.width) / 2, s.height * 0.55 + 8));
    }
  }

  @override
  bool shouldRepaint(_DartPainter old) => true;
}

/// ============================================================
/// DARTS JOURNEY — 50 levels, 5 throws per level.
/// ============================================================
class DartsJourneyScreen extends StatefulWidget {
  const DartsJourneyScreen({super.key});

  @override
  State<DartsJourneyScreen> createState() => _DartsJourneyScreenState();
}

class _DartsJourneyScreenState extends State<DartsJourneyScreen> {
  static int passScore(int level) => 220 + level * 3; // of max 500

  @override
  Widget build(BuildContext context) {
    final a = AppData.i;
    return Scaffold(
      body: ShaderBackground(
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(children: [
                Glass(
                    radius: 16,
                    padding: const EdgeInsets.all(8),
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back, size: 18)),
                const SizedBox(width: 12),
                Text('DARTS JOURNEY 🎯',
                    style: Theme.of(context).textTheme.titleLarge),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Glass(
                radius: 20,
                padding: const EdgeInsets.all(14),
                tint: DC.amber,
                child: Row(children: [
                  const Text('🎯', style: TextStyle(fontSize: 30)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              '${RatingCatalog.ratingForLegacyLevel(a.dartsLevel)} rating · variant ${a.dartsLevel}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900, fontSize: 15)),
                          Text(
                              '5 throws · score ${passScore(a.dartsLevel)}+ to pass · ${_levelTag(a.dartsLevel)}',
                              style: TextStyle(fontSize: 11, color: DC.dim)),
                        ]),
                  ),
                  NeonButton(
                      label: 'THROW',
                      height: 40,
                      colors: [DC.amber, DC.magenta],
                      onPressed: () => _play(a.dartsLevel)),
                ]),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: 50,
                itemBuilder: (context, i) {
                  final level = i + 1;
                  final unlocked = level <= AppData.i.dartsLevel;
                  final done = level < AppData.i.dartsLevel;
                  final current = level == AppData.i.dartsLevel;
                  return GestureDetector(
                    onTap: unlocked ? () => _play(level) : null,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: unlocked ? DC.fgo(0.06) : DC.fgo(0.02),
                        border: Border.all(
                            color: current ? DC.amber : DC.fgo(0.10),
                            width: current ? 1.6 : 1),
                      ),
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                                done
                                    ? '✅'
                                    : unlocked
                                        ? '🎯'
                                        : '🔒',
                                style: const TextStyle(fontSize: 15)),
                            Text(
                                '${RatingCatalog.ratingForLegacyLevel(level)} · V$level',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: unlocked ? DC.text : DC.fg38)),
                          ]),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text(
                  '800–1100 static · 1200–1800 sliding · 1900–2500 sweeping blocker',
                  style: TextStyle(fontSize: 10, color: DC.dim)),
            ),
          ]),
        ),
      ),
    );
  }

  static String _levelTag(int level) => level <= 10
      ? 'static board'
      : level <= 30
          ? 'moving board'
          : 'moving board + blocker';

  void _play(int level) {
    Navigator.push(context,
            MaterialPageRoute(builder: (_) => _DartsLevelScreen(level: level)))
        .then((_) => setState(() {}));
  }
}

class _DartsLevelScreen extends StatefulWidget {
  final int level;
  const _DartsLevelScreen({required this.level});

  @override
  State<_DartsLevelScreen> createState() => _DartsLevelScreenState();
}

class _DartsLevelScreenState extends State<_DartsLevelScreen> {
  static const throwsTotal = 5;
  int thrown = 0;
  int score = 0;
  bool between = false;
  bool finished = false;

  void _onThrow(DartHit hit) {
    if (finished || between) return;
    between = true;
    score += hit.score;
    thrown++;
    setState(() {});
    Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      between = false;
      if (thrown >= throwsTotal) {
        _finish();
      } else {
        setState(() {});
      }
    });
  }

  void _finish() {
    if (finished) return;
    finished = true;
    final a = AppData.i;
    final need = _DartsJourneyScreenState.passScore(widget.level);
    final passed = score >= need;
    if (passed) {
      Fx.win();
    } else {
      Fx.lose();
    }
    var coins = 0;
    if (passed) {
      coins = 15 + widget.level * 2;
      a.addCoins(coins);
      a.addXp(10 + widget.level * 2);
      if (widget.level == a.dartsLevel && a.dartsLevel < 50) {
        a.dartsLevel++;
      }
      a.recordTrainingSession('darts',
          value: score / need, type: 'level');
    } else {
      a.addXp(5);
      a.recordTrainingSession('darts',
          value: score / need, type: 'level');
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: DC.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (passed) const ConfettiBurst(height: 60),
            Text(passed ? '🏆' : '🎯', style: const TextStyle(fontSize: 44)),
            const SizedBox(height: 8),
            Text(passed ? 'RATING CLEARED!' : 'SO CLOSE',
                style: Theme.of(context).textTheme.displayMedium),
            Text('$score / $need needed', style: TextStyle(color: DC.dim)),
            const SizedBox(height: 8),
            if (passed)
              Text(
                  '+$coins 🪙 · ${RatingCatalog.ratingForLegacyLevel((widget.level + 1).clamp(1, 50))} unlocked',
                  style: TextStyle(color: DC.lime, fontWeight: FontWeight.w800))
            else
              Text('Match the ghost ring for perfect power.',
                  style: TextStyle(color: DC.dim, fontSize: 12)),
            const SizedBox(height: 14),
            NeonButton(
                label: 'DONE',
                height: 46,
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                }),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final need = _DartsJourneyScreenState.passScore(widget.level);
    return Scaffold(
      body: ShaderBackground(
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(children: [
                Glass(
                    radius: 16,
                    padding: const EdgeInsets.all(8),
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, size: 18)),
                const SizedBox(width: 8),
                GameTutorial.helpButton(context,
                    title: 'DARTS', steps: dartsTutorial),
                const SizedBox(width: 12),
                Text(
                    '${RatingCatalog.ratingForLegacyLevel(widget.level)} · V${widget.level}',
                    style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                Pill(
                    icon: Icons.gps_fixed,
                    label: '$score/$need',
                    color: score >= need ? DC.lime : DC.amber),
              ]),
            ),
            const SizedBox(height: 4),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 0; i < throwsTotal; i++)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < thrown ? DC.amber : DC.fg24,
                  ),
                ),
            ]),
            Expanded(
              child: DartThrowBoard(
                config: DartConfig.level(widget.level),
                enabled: !finished && !between && thrown < throwsTotal,
                onThrow: _onThrow,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;

import '../core/fx.dart';
import '../core/state.dart';
import '../theme_district.dart';
import '../ui/glass.dart';

/// ============================================================
/// KID ARCADE — endless, addictive, pseudo-3D fun games. No maths,
/// no levels: just a high score that keeps you coming back. Two games:
///   🏗️ Sky Stack — drop sliding blocks, trim the overhang, climb.
///   🚀 Cube Dash — dodge cubes down a perspective tunnel.
/// Both pay coins/XP per run via AppData.recordKidArcade.
/// ============================================================

Color _lighten(Color c, double a) => Color.lerp(c, Colors.white, a)!;
Color _darken(Color c, double a) => Color.lerp(c, Colors.black, a)!;

/// A stacked/receding 3D box: front face + top + right side.
void _cuboid(Canvas c, Rect r, Color col, double d) {
  final side = Paint()..color = _darken(col, 0.28);
  final top = Paint()..color = _lighten(col, 0.22);
  final front = Paint()..color = col;
  final sp = Path()
    ..moveTo(r.right, r.top)
    ..lineTo(r.right + d, r.top - d)
    ..lineTo(r.right + d, r.bottom - d)
    ..lineTo(r.right, r.bottom)
    ..close();
  final tp = Path()
    ..moveTo(r.left, r.top)
    ..lineTo(r.right, r.top)
    ..lineTo(r.right + d, r.top - d)
    ..lineTo(r.left + d, r.top - d)
    ..close();
  c.drawPath(sp, side);
  c.drawPath(tp, top);
  c.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(4)), front);
}

void _arcadeGameOver(
    BuildContext context, String id, int score, Widget Function() again) {
  AppData.i.recordKidArcade(id, score);
  Fx.lose();
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => Dialog(
      backgroundColor: DC.bg2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('💥', style: TextStyle(fontSize: 52)),
          const SizedBox(height: 6),
          Text('$score',
              style: TextStyle(
                  fontSize: 44, fontWeight: FontWeight.w900, color: DC.cyan)),
          Text('Best  ${AppData.i.kidBest(id)}',
              style: TextStyle(color: DC.dim)),
          const SizedBox(height: 16),
          NeonButton(
            label: 'PLAY AGAIN',
            icon: Icons.refresh,
            height: 46,
            colors: [DC.magenta, DC.violet],
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                  context, MaterialPageRoute(builder: (_) => again()));
            },
          ),
          const SizedBox(height: 8),
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

Widget _arcadeBar(BuildContext context, String title, int score, String id) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    child: Row(children: [
      Glass(
          radius: 16,
          padding: const EdgeInsets.all(8),
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back, size: 18)),
      const SizedBox(width: 12),
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      const Spacer(),
      Pill(
          icon: Icons.emoji_events,
          label: '${AppData.i.kidBest(id)}',
          color: DC.amber),
      const SizedBox(width: 8),
      Pill(icon: Icons.bolt, label: '$score', color: DC.cyan),
    ]),
  );
}

/// ---------------- 🏗️ SKY STACK ----------------
class _Block {
  double x, w; // pixels within the play area
  _Block(this.x, this.w);
}

class StackGameScreen extends StatefulWidget {
  const StackGameScreen({super.key});
  @override
  State<StackGameScreen> createState() => _StackGameScreenState();
}

class _StackGameScreenState extends State<StackGameScreen>
    with SingleTickerProviderStateMixin {
  static const id = 'stack';
  static const blockH = 30.0;
  static const depth = 9.0;

  late final Ticker _ticker;
  Duration _last = Duration.zero;

  double _playW = 300;
  final List<_Block> blocks = [];
  double _mx = 0; // moving block left
  double _mw = 160; // moving block width
  int _dir = 1;
  double _speed = 150;
  int score = 0;
  bool over = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  void _reset(double w) {
    _playW = w;
    _mw = w * 0.5;
    blocks
      ..clear()
      ..add(_Block(w * 0.25, w * 0.5));
    _mx = 0;
    _dir = 1;
    _speed = 150;
    score = 0;
    over = false;
    _started = true;
  }

  void _tick(Duration elapsed) {
    final dt =
        _last == Duration.zero ? 0.0 : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (over || !_started || dt == 0) return;
    _mx += _dir * _speed * dt;
    if (_mx <= 0) {
      _mx = 0;
      _dir = 1;
    } else if (_mx + _mw >= _playW) {
      _mx = _playW - _mw;
      _dir = -1;
    }
    setState(() {});
  }

  void _drop() {
    if (over || !_started) return;
    final below = blocks.last;
    final left = math.max(_mx, below.x);
    final right = math.min(_mx + _mw, below.x + below.w);
    final ov = right - left;
    if (ov <= 3) {
      setState(() => over = true);
      _arcadeGameOver(context, id, score, () => const StackGameScreen());
      return;
    }
    Fx.tap();
    setState(() {
      blocks.add(_Block(left, ov));
      _mw = ov;
      _mx = _dir > 0 ? 0 : _playW - _mw;
      _speed = math.min(_speed + 10, 460);
      score++;
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ShaderBackground(
        child: SafeArea(
          child: Column(children: [
            _arcadeBar(context, '🏗️ Sky Stack', score, id),
            const SizedBox(height: 4),
            Text('tap anywhere to drop — line them up!',
                style: TextStyle(fontSize: 11, color: DC.dim)),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (_) => _drop(),
                child: LayoutBuilder(builder: (context, box) {
                  final w = math.min(box.maxWidth - 40, 340).toDouble();
                  if (!_started) {
                    WidgetsBinding.instance
                        .addPostFrameCallback((_) => setState(() => _reset(w)));
                  }
                  return CustomPaint(
                    size: Size(box.maxWidth, box.maxHeight),
                    painter: _StackPainter(
                      blocks: blocks,
                      mx: _mx,
                      mw: _mw,
                      playW: _playW,
                      over: over,
                    ),
                  );
                }),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _StackPainter extends CustomPainter {
  final List<_Block> blocks;
  final double mx, mw, playW;
  final bool over;
  _StackPainter(
      {required this.blocks,
      required this.mx,
      required this.mw,
      required this.playW,
      required this.over});

  @override
  void paint(Canvas canvas, Size size) {
    final ox = (size.width - playW) / 2;
    final dropY = size.height * 0.42;
    // hue shifts as the tower climbs — arcade candy colours.
    Color colFor(int i) =>
        HSVColor.fromAHSV(1, (i * 26) % 360.0, 0.55, 0.95).toColor();

    // placed blocks: last just below the drop line, older ones lower.
    for (int k = 0; k < blocks.length; k++) {
      final b = blocks[blocks.length - 1 - k];
      final y = dropY + (k + 1) * _StackGameScreenState.blockH;
      if (y - _StackGameScreenState.depth > size.height) break;
      _cuboid(
          canvas,
          Rect.fromLTWH(ox + b.x, y, b.w, _StackGameScreenState.blockH),
          colFor(blocks.length - 1 - k),
          _StackGameScreenState.depth);
    }
    if (!over && blocks.isNotEmpty) {
      _cuboid(
          canvas,
          Rect.fromLTWH(ox + mx, dropY, mw, _StackGameScreenState.blockH),
          colFor(blocks.length),
          _StackGameScreenState.depth);
    }
  }

  @override
  bool shouldRepaint(_StackPainter old) => true;
}

/// ---------------- 🚀 CUBE DASH ----------------
class _Ob {
  int lane;
  double z; // 1 = far, 0 = at player
  bool scored;
  _Ob(this.lane, this.z) : scored = false;
}

class DashGameScreen extends StatefulWidget {
  const DashGameScreen({super.key});
  @override
  State<DashGameScreen> createState() => _DashGameScreenState();
}

class _DashGameScreenState extends State<DashGameScreen>
    with SingleTickerProviderStateMixin {
  static const id = 'dash';
  late final Ticker _ticker;
  Duration _last = Duration.zero;

  final List<_Ob> obs = [];
  int lane = 1; // 0,1,2
  double _laneShown = 1;
  double _spawn = 0;
  double _speed = 0.55; // depth units / sec
  int score = 0;
  bool over = false;
  final _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  void _tick(Duration elapsed) {
    final dt =
        _last == Duration.zero ? 0.0 : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (over || dt == 0) return;
    _laneShown += (lane - _laneShown) * math.min(1, dt * 12);
    for (final o in obs) {
      o.z -= _speed * dt;
    }
    // score a dodge as it passes the player plane
    for (final o in obs) {
      if (!o.scored && o.z < 0.04) {
        o.scored = true;
        if (o.lane == lane) {
          setState(() => over = true);
          _arcadeGameOver(context, id, score, () => const DashGameScreen());
          return;
        }
        score++;
        Fx.tap();
        _speed = math.min(_speed + 0.02, 1.6);
      }
    }
    obs.removeWhere((o) => o.z < -0.1);
    _spawn -= dt;
    if (_spawn <= 0) {
      _spawn = (0.85 - _speed * 0.25).clamp(0.35, 0.85);
      obs.add(_Ob(_rng.nextInt(3), 1.05));
    }
    setState(() {});
  }

  void _move(int dir) {
    if (over) return;
    setState(() => lane = (lane + dir).clamp(0, 2));
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ShaderBackground(
        child: SafeArea(
          child: Column(children: [
            _arcadeBar(context, '🚀 Cube Dash', score, id),
            const SizedBox(height: 4),
            Text('tap left / right to dodge the cubes',
                style: TextStyle(fontSize: 11, color: DC.dim)),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => _move(
                    d.localPosition.dx < MediaQuery.of(context).size.width / 2
                        ? -1
                        : 1),
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _DashPainter(obs: obs, lane: _laneShown),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  final List<_Ob> obs;
  final double lane;
  _DashPainter({required this.obs, required this.lane});

  // perspective helpers: z in [0(near)..1(far)]
  double _y(Size s, double z) => s.height * 0.22 + (s.height * 0.72) * (1 - z);
  double _scale(double z) => 0.14 + 0.86 * (1 - z);
  double _laneX(Size s, int l, double z) =>
      s.width / 2 + (l - 1) * s.width * 0.30 * _scale(z);

  @override
  void paint(Canvas canvas, Size s) {
    // floor + lane guides converging to the vanishing point
    final guide = Paint()
      ..color = DC.fgo(0.14)
      ..strokeWidth = 2;
    for (int l = 0; l <= 3; l++) {
      final xNear = s.width / 2 + (l - 1.5) * s.width * 0.30;
      final xFar = s.width / 2 + (l - 1.5) * s.width * 0.30 * _scale(1);
      canvas.drawLine(Offset(xNear, _y(s, 0)), Offset(xFar, _y(s, 1)), guide);
    }
    // obstacles, far first
    final sorted = [...obs]..sort((a, b) => b.z.compareTo(a.z));
    for (final o in sorted) {
      if (o.z > 1.05 || o.z < -0.1) continue;
      final sc = _scale(o.z);
      final size = 46.0 * sc;
      final cx = _laneX(s, o.lane, o.z);
      final cy = _y(s, o.z);
      final col = HSVColor.fromAHSV(1, (o.lane * 90 + 200) % 360.0, 0.6, 0.95)
          .toColor();
      _cuboid(
          canvas,
          Rect.fromCenter(center: Offset(cx, cy), width: size, height: size),
          col,
          8 * sc);
    }
    // player cube at the near plane
    final px =
        _laneX(s, lane.round(), 0) + (lane - lane.round()) * s.width * 0.30;
    _cuboid(
        canvas,
        Rect.fromCenter(
            center: Offset(px, _y(s, 0) - 20), width: 52, height: 52),
        DC.cyan,
        10);
  }

  @override
  bool shouldRepaint(_DashPainter old) => true;
}

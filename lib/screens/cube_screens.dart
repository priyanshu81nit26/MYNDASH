import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/fx.dart';
import '../core/state.dart';
import '../engine/cube_core.dart';
import '../services/account_service.dart';
import '../theme_district.dart';
import '../ui/extras.dart';
import '../ui/glass.dart';
import '../ui/rating_picker.dart';
import 'online_play.dart';

/// ============================================================
/// RUBIK'S CUBE — realistic 3D rendering (orbit with a finger),
/// animated face turns, authentic colors.
/// Practice: 2×2 & 4×4, shuffle, timer, move counter.
/// Compete: vs bot · online (closest rating) · a friend (code+link).
/// ============================================================

/// ---------------- 3D cube board with controls ----------------
class CubeBoard extends StatefulWidget {
  final CubeState cube;
  final bool enabled;
  final VoidCallback? onTurn; // after each applied turn
  final bool wideAvailable; // 4×4 gets a 2-layer (wide) toggle

  const CubeBoard({
    super.key,
    required this.cube,
    this.enabled = true,
    this.onTurn,
    this.wideAvailable = false,
  });

  @override
  State<CubeBoard> createState() => CubeBoardState();
}

class CubeBoardState extends State<CubeBoard>
    with SingleTickerProviderStateMixin {
  double yaw = -0.55, pitch = -0.42;
  bool wide = false;

  late final AnimationController anim = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 190))
    ..addListener(() => setState(() {}))
    ..addStatusListener((st) {
      if (st == AnimationStatus.completed) _commitTurn();
    });
  int? tAxis;
  List<int> tLayers = [];
  bool tPositive = true;

  // ---------------- first-time controls guide ----------------
  bool _showGuide = !AppData.i.seenGuide('cube_controls');
  int _guideStep = 0;

  // face -> (rotation axis, is-top-layer, ring color, screen slot).
  // Slot alignments frame the 3D cube with a button at each of the six
  // requested positions: mid-top-left/right, mid-left/right,
  // mid-bottom-left/right.
  static const _faceMeta =
      <String, (int axis, bool top, Color color, Alignment slot)>{
    'U': (1, true, Color(0xFFFFFFFF), Alignment(-0.8, -0.62)),
    'D': (1, false, Color(0xFFFFD500), Alignment(0.8, -0.62)),
    'F': (2, true, Color(0xFF009E60), Alignment(-0.94, 0.02)),
    'B': (2, false, Color(0xFF0051BA), Alignment(0.94, 0.02)),
    'R': (0, true, Color(0xFFC41E3A), Alignment(-0.8, 0.66)),
    'L': (0, false, Color(0xFFFF5800), Alignment(0.8, 0.66)),
  };

  static const _guideOrder = ['U', 'D', 'F', 'B', 'R', 'L'];
  static const _guideDesc = <String, String>{
    'U': 'Turns the UP layer — the top of the cube.',
    'D': 'Turns the DOWN layer — the bottom of the cube.',
    'F': 'Turns the FRONT layer — the face you\'re looking at.',
    'B': 'Turns the BACK layer — the far side.',
    'R': 'Turns the RIGHT layer.',
    'L': 'Turns the LEFT layer.',
  };
  static const _guideArrow = <String, String>{
    'U': '↖',
    'D': '↗',
    'F': '←',
    'B': '→',
    'R': '↙',
    'L': '↘',
  };

  void _guideNext() {
    if (!_showGuide) return;
    if (_guideStep >= _guideOrder.length - 1) {
      AppData.i.markGuideSeen('cube_controls');
      setState(() => _showGuide = false);
    } else {
      setState(() => _guideStep++);
    }
  }

  void _startTurn(String face, int axis, int layer, bool positive) {
    if (!widget.enabled || anim.isAnimating) return;
    Fx.light();
    tAxis = axis;
    tPositive = positive;
    tLayers = [layer];
    if (wide && widget.cube.n >= 4) {
      tLayers.add(layer == 0 ? 1 : layer - 1);
    }
    anim.forward(from: 0);
    if (_showGuide && _guideOrder[_guideStep] == face) _guideNext();
  }

  void _commitTurn() {
    for (final l in tLayers) {
      widget.cube.turn(CubeTurn(tAxis!, l, tPositive));
    }
    tAxis = null;
    tLayers = [];
    setState(() {});
    widget.onTurn?.call();
  }

  @override
  void dispose() {
    anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.cube.n;
    return Column(children: [
      Expanded(
        child: Stack(children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (d) => setState(() {
              yaw += d.delta.dx * 0.011;
              pitch =
                  (pitch - d.delta.dy * 0.011).clamp(-1.25, 1.25).toDouble();
            }),
            child: CustomPaint(
              size: Size.infinite,
              painter: _CubePainter(
                cube: widget.cube,
                yaw: yaw,
                pitch: pitch,
                tAxis: tAxis,
                tLayers: tLayers,
                angle: tAxis == null
                    ? 0
                    : (tPositive ? 1 : -1) * anim.value * math.pi / 2,
              ),
            ),
          ),
          // six face-turn buttons framing the cube: mid-top-left/right,
          // mid-left/right, mid-bottom-left/right.
          for (final face in _faceMeta.keys) _edgeTurnBtn(face, n),
          if (_showGuide) _guideOverlay(),
        ]),
      ),
      const SizedBox(height: 4),
      Text('drag anywhere to spin the cube · buttons turn faces',
          style: TextStyle(fontSize: 10, color: DC.dim)),
      const SizedBox(height: 6),
      if (widget.wideAvailable)
        GestureDetector(
          onTap: () => setState(() => wide = !wide),
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: wide ? DC.cyan.withOpacity(0.25) : DC.fgo(0.06),
              border: Border.all(color: wide ? DC.cyan : DC.fg24),
            ),
            child: Text(wide ? 'WIDE TURNS: ON (2 layers)' : 'WIDE TURNS: OFF',
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
          ),
        ),
    ]);
  }

  /// One face's turn button, placed at its fixed screen-edge slot.
  Widget _edgeTurnBtn(String face, int n) {
    final (axis, top, color, slot) = _faceMeta[face]!;
    final layer = top ? n - 1 : 0;
    Widget half(String glyph, bool positive) => GestureDetector(
          onTap: widget.enabled
              ? () => _startTurn(face, axis, layer, positive)
              : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
            child: Text(glyph,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
          ),
        );
    return Align(
      alignment: slot,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: DC.fgo(0.07),
          border: Border.all(color: color.withOpacity(0.65), width: 1.4),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          half('↺', false),
          Text(face,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w900, color: color)),
          half('↻', true),
        ]),
      ),
    );
  }

  /// First-time interactive guide: dims the board, rings the current
  /// step's button and shows a small arrow + description. Advances on
  /// "NEXT" or the moment the player actually performs that move.
  Widget _guideOverlay() {
    final face = _guideOrder[_guideStep];
    final (guideAxis, guideTop, color, slot) = _faceMeta[face]!;
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.62),
        child: Stack(children: [
          Align(
            alignment: slot,
            child: GestureDetector(
              onTap: () => _startTurn(
                  face, guideAxis, guideTop ? widget.cube.n - 1 : 0, true),
              child: Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: DC.cyan, width: 3),
                  boxShadow: [
                    BoxShadow(
                        color: DC.cyan.withOpacity(0.65),
                        blurRadius: 18,
                        spreadRadius: 2),
                  ],
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment(slot.x * 0.42, slot.y * 0.42),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 210),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: DC.bg2,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: DC.cyan.withOpacity(0.5)),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_guideArrow[face]!,
                    style: TextStyle(fontSize: 22, color: color)),
                const SizedBox(height: 4),
                Text('$face face',
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                        color: DC.text)),
                const SizedBox(height: 2),
                Text(_guideDesc[face]!,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: DC.dim)),
                const SizedBox(height: 10),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  TextButton(
                    onPressed: () {
                      AppData.i.markGuideSeen('cube_controls');
                      setState(() => _showGuide = false);
                    },
                    child: Text('SKIP',
                        style: TextStyle(color: DC.dim, fontSize: 11)),
                  ),
                  const SizedBox(width: 6),
                  FilledButton(
                    onPressed: _guideNext,
                    child: Text(_guideStep == _guideOrder.length - 1
                        ? 'GOT IT'
                        : 'NEXT · ${_guideStep + 1}/${_guideOrder.length}'),
                  ),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _CubePainter extends CustomPainter {
  final CubeState cube;
  final double yaw, pitch, angle;
  final int? tAxis;
  final List<int> tLayers;

  _CubePainter({
    required this.cube,
    required this.yaw,
    required this.pitch,
    required this.tAxis,
    required this.tLayers,
    required this.angle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final n = cube.n;
    final u = math.min(size.width, size.height) / (n * 2.35);
    final c0 = Offset(size.width / 2, size.height / 2);
    final cy = math.cos(yaw), sy = math.sin(yaw);
    final cp = math.cos(pitch), sp = math.sin(pitch);
    final half = (n - 1) / 2.0;

    List<double> view(List<double> v) {
      final x1 = v[0] * cy + v[2] * sy;
      final z1 = -v[0] * sy + v[2] * cy;
      final y2 = v[1] * cp - z1 * sp;
      final z2 = v[1] * sp + z1 * cp;
      return [x1, y2, z2];
    }

    List<double> spin(List<double> v) {
      // rotate around tAxis by angle in the tangent plane (b,c)
      if (tAxis == null) return v;
      final (b, c) = CubeState.tangents(tAxis!);
      final ca = math.cos(angle), sa = math.sin(angle);
      final out = [...v];
      out[b] = v[b] * ca - v[c] * sa;
      out[c] = v[b] * sa + v[c] * ca;
      return out;
    }

    final quads = <(double, Path, Color)>[];
    for (final s in cube.stickers) {
      final turning = tAxis != null &&
          tLayers.contains(tAxis == 0 ? s.x : (tAxis == 1 ? s.y : s.z));
      // sticker center pushed slightly off the face
      final centerV = [
        s.x - half + s.nx * 0.5,
        s.y - half + s.ny * 0.5,
        s.z - half + s.nz * 0.5,
      ];
      // tangent directions on the face
      final t1 = s.nx != 0 ? [0.0, 1.0, 0.0] : [1.0, 0.0, 0.0];
      final t2 = s.ny != 0
          ? [0.0, 0.0, 1.0]
          : (s.nz != 0 ? [0.0, 1.0, 0.0] : [0.0, 0.0, 1.0]);
      const h = 0.44;
      final corners = <Offset>[];
      var depth = 0.0;
      for (final (f1, f2) in [(h, h), (h, -h), (-h, -h), (-h, h)]) {
        var w = [
          centerV[0] + t1[0] * f1 + t2[0] * f2,
          centerV[1] + t1[1] * f1 + t2[1] * f2,
          centerV[2] + t1[2] * f1 + t2[2] * f2,
        ];
        if (turning) w = spin(w);
        final r = view(w);
        corners.add(c0 + Offset(r[0] * u, -r[1] * u));
        depth += r[2];
      }
      final path = Path()..addPolygon(corners, true);
      quads.add((depth / 4, path, Color(cubeColors[s.color])));
    }
    // painter's algorithm: farthest first
    quads.sort((a, b) => a.$1.compareTo(b.$1));
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFF0A0A0A);
    for (final (_, path, color) in quads) {
      canvas.drawPath(path, Paint()..color = color);
      canvas.drawPath(path, stroke);
    }
  }

  @override
  bool shouldRepaint(_CubePainter old) => true;
}

/// ============================================================
/// CUBE HOME — Practice / Compete
/// ============================================================
class CubeHomeScreen extends StatelessWidget {
  const CubeHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ShaderBackground(
        child: SafeArea(
          child: ListView(padding: const EdgeInsets.all(20), children: [
            Row(children: [
              Glass(
                  radius: 16,
                  padding: const EdgeInsets.all(8),
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back, size: 18)),
              const SizedBox(width: 12),
              Text('RUBIK\'S CUBE 🧊',
                  style: Theme.of(context).textTheme.titleLarge),
            ]),
            const SizedBox(height: 16),
            Glass(
              tint: DC.cyan,
              onTap: () => _pickSize(context, (nn) {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => CubePracticeScreen(n: nn)));
              }),
              child: Row(children: [
                const Text('🧊', style: TextStyle(fontSize: 34)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PRACTICE',
                            style: TextStyle(
                                fontWeight: FontWeight.w900, fontSize: 16)),
                        Text('2×2 & 4×4 · shuffle · timer · learn at your pace',
                            style: TextStyle(fontSize: 12, color: DC.dim)),
                      ]),
                ),
                Icon(Icons.chevron_right, color: DC.dim),
              ]),
            ),
            const SizedBox(height: 12),
            Glass(
              tint: DC.magenta,
              onTap: () => _competeSheet(context),
              child: Row(children: [
                const Text('⚔️', style: TextStyle(fontSize: 34)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('COMPETE',
                            style: TextStyle(
                                fontWeight: FontWeight.w900, fontSize: 16)),
                        Text('race a bot · online rival · or a friend',
                            style: TextStyle(fontSize: 12, color: DC.dim)),
                      ]),
                ),
                Icon(Icons.chevron_right, color: DC.dim),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  void _pickSize(BuildContext context, void Function(int) onPick) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: DC.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Cube size'),
        content: Row(children: [
          Expanded(
            child: NeonButton(
                label: '2 × 2',
                height: 48,
                onPressed: () {
                  Navigator.pop(c);
                  onPick(2);
                }),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: NeonButton(
                label: '4 × 4',
                height: 48,
                colors: [DC.amber, DC.magenta],
                onPressed: () {
                  Navigator.pop(c);
                  onPick(4);
                }),
          ),
        ]),
      ),
    );
  }

  void _competeSheet(BuildContext context) {
    _pickSize(context, (nn) {
      showModalBottomSheet(
        useSafeArea: true,
        context: context,
        backgroundColor: DC.bg2,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        builder: (c) => Padding(
          padding: const EdgeInsets.all(22),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('COMPETE · ${nn}×$nn',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            NeonButton(
              label: 'VS BOT',
              icon: Icons.smart_toy,
              onPressed: () async {
                Navigator.pop(c);
                final tMin = await pickTimeControl(context, 'Cube 🧊');
                if (tMin == null || !context.mounted) return;
                final rating = await pickBotRating(context, 'Cube 🧊');
                if (rating == null || !context.mounted) return;
                startBotMatch(context,
                    label: 'Cube ${nn}×$nn',
                    detail: '$rating · ${timeControlLabel(tMin)}',
                    game: () => CubeBotRaceScreen(
                        n: nn, timeMinutes: tMin, botRating: rating));
              },
            ),
            if (!AppData.i.kidMode) ...[
              const SizedBox(height: 10),
              NeonButton(
                label: 'SEARCH ONLINE',
                icon: Icons.public,
                colors: [DC.magenta, DC.violet],
                onPressed: () {
                  Navigator.pop(c);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => MatchmakingScreen(
                              game: 'cube',
                              sub: '$nn',
                              label: 'Cube ${nn}×$nn')));
                },
              ),
              const SizedBox(height: 10),
              GhostButton(
                label: 'PLAY A FRIEND',
                icon: Icons.group,
                onPressed: () {
                  Navigator.pop(c);
                  showFriendPlayDialog(
                      context, 'cube', '$nn', 'Cube ${nn}×$nn');
                },
              ),
            ] else
              Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text('Online cube races unlock at 12+ 🚀',
                    style: TextStyle(fontSize: 11, color: DC.dim)),
              ),
          ]),
        ),
      );
    });
  }
}

/// ============================================================
/// PRACTICE — shuffle, timer, move counter, solve celebration.
/// ============================================================
class CubePracticeScreen extends StatefulWidget {
  final int n;
  const CubePracticeScreen({super.key, required this.n});

  @override
  State<CubePracticeScreen> createState() => _CubePracticeScreenState();
}

class _CubePracticeScreenState extends State<CubePracticeScreen> {
  late CubeState cube = CubeState(widget.n);
  final rng = math.Random();
  bool scrambled = false;
  final watch = Stopwatch();
  Timer? tick;

  @override
  void initState() {
    super.initState();
    tick = Timer.periodic(
        const Duration(seconds: 1), (_) => mounted ? setState(() {}) : null);
  }

  @override
  void dispose() {
    tick?.cancel();
    super.dispose();
  }

  void _shuffle() {
    setState(() {
      cube = CubeState(widget.n)..scramble(rng);
      scrambled = true;
      watch
        ..reset()
        ..start();
    });
  }

  void _reset() {
    setState(() {
      cube = CubeState(widget.n);
      scrambled = false;
      watch
        ..stop()
        ..reset();
    });
  }

  void _onTurn() {
    if (scrambled && cube.solved) {
      watch.stop();
      scrambled = false;
      Fx.win();
      final secs = watch.elapsed.inSeconds;
      final coins = widget.n == 2 ? 25 : 60;
      AppData.i.addCoins(coins);
      AppData.i.addXp(coins);
      AppData.i.recordTrainingSession(
        'cube',
        value: 1,
        durationMs: watch.elapsedMilliseconds,
      );
      showDialog(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: DC.bg2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const ConfettiBurst(height: 60),
              const Text('🧊✨', style: TextStyle(fontSize: 40)),
              Text('SOLVED!', style: Theme.of(context).textTheme.displayMedium),
              Text(
                  '${widget.n}×${widget.n} in ${secs}s · ${cube.moveCount} moves',
                  style: TextStyle(color: DC.dim)),
              const SizedBox(height: 6),
              Text('+$coins 🪙 · +$coins XP',
                  style:
                      TextStyle(color: DC.lime, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              NeonButton(
                  label: 'NICE',
                  height: 44,
                  onPressed: () => Navigator.pop(context)),
            ]),
          ),
        ),
      );
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
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
                    child: const Icon(Icons.arrow_back, size: 18)),
                const SizedBox(width: 10),
                Text('${widget.n}×${widget.n} PRACTICE',
                    style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                Pill(
                    icon: Icons.timer,
                    label: scrambled ? '${watch.elapsed.inSeconds}s' : '—',
                    color: DC.cyan),
                const SizedBox(width: 6),
                Pill(
                    icon: Icons.sync,
                    label: '${cube.moveCount}',
                    color: DC.amber),
              ]),
            ),
            Expanded(
              child: CubeBoard(
                cube: cube,
                wideAvailable: widget.n >= 4,
                onTurn: _onTurn,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Row(children: [
                Expanded(
                  child: NeonButton(
                      label: 'SHUFFLE 🔀', height: 48, onPressed: _shuffle),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GhostButton(
                      label: 'RESET', height: 48, onPressed: _reset),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// ============================================================
/// VS BOT — race the clock persona.
/// ============================================================
class CubeBotRaceScreen extends StatefulWidget {
  final int n;
  final int timeMinutes; // 0 = untimed; else 5/10 min solve limit
  final int? botRating;
  const CubeBotRaceScreen(
      {super.key, required this.n, this.timeMinutes = 0, this.botRating});

  @override
  State<CubeBotRaceScreen> createState() => _CubeBotRaceScreenState();
}

class _CubeBotRaceScreenState extends State<CubeBotRaceScreen> {
  late CubeState cube;
  late int botMs;
  late String botName;
  final watch = Stopwatch()..start();
  Timer? tick;
  bool finished = false;

  static const _names = ['Nova', 'Zephyr', 'Kira', 'Axel', 'Omen', 'Pixel'];

  @override
  void initState() {
    super.initState();
    final rng = math.Random();
    cube = CubeState(widget.n)..scramble(rng);
    botName = _names[rng.nextInt(_names.length)];
    final skill = (((widget.botRating ?? AppData.i.elo) - 800) / 1700)
        .clamp(0.0, 1.0)
        .toDouble();
    final base = widget.n == 2 ? 150.0 : 420.0;
    botMs = (base * (1.35 - skill * 0.75) * (0.85 + rng.nextDouble() * 0.3))
            .round() *
        1000;
    tick = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted || finished) return;
      final limitMs = widget.timeMinutes * 60000;
      // Lose if the bot finishes first, or the time limit runs out.
      if (widget.timeMinutes > 0 && watch.elapsedMilliseconds >= limitMs) {
        _finish(false);
      } else if (watch.elapsedMilliseconds >= botMs) {
        _finish(false);
      } else {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    tick?.cancel();
    super.dispose();
  }

  static String _fmtRemain(int ms) {
    final s = (ms.clamp(0, 1 << 31) / 1000).ceil();
    final m = s ~/ 60;
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$m:$ss';
  }

  void _onTurn() {
    if (!finished && cube.solved) _finish(true);
    setState(() {});
  }

  void _finish(bool won) {
    if (finished) return;
    finished = true;
    watch.stop();
    if (won) {
      Fx.win();
    } else {
      Fx.lose();
    }
    final a = AppData.i;
    final delta = a.applyElo(a.elo, won ? 1 : 0); // even-odds race
    a.addXp(won ? 40 : 10);
    a.recordMatch(
        mode: 'Cube 🧊 ${widget.n}×${widget.n}',
        opponent: botName,
        result: won ? 'W' : 'L',
        delta: delta);
    AccountService.instance.updatePublicProfile();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: DC.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (won) const ConfettiBurst(height: 70),
            Icon(won ? Icons.emoji_events : Icons.hourglass_bottom,
                size: 60, color: won ? DC.amber : DC.violet),
            const SizedBox(height: 10),
            Text(won ? 'SOLVED FIRST!' : 'TOO SLOW',
                style: Theme.of(context).textTheme.displayMedium),
            Text(
                won
                    ? 'You beat $botName by ${((botMs - watch.elapsedMilliseconds) / 1000).toStringAsFixed(1)}s'
                    : '$botName solved it in ${(botMs / 1000).round()}s',
                style: TextStyle(color: DC.dim)),
            const SizedBox(height: 8),
            Text('${delta >= 0 ? '+' : ''}$delta rating',
                style: TextStyle(
                    color: delta >= 0 ? DC.lime : DC.danger,
                    fontWeight: FontWeight.w900,
                    fontSize: 18)),
            const SizedBox(height: 8),
            const ReactionBar(),
            TextButton.icon(
              onPressed: () => shareResult(
                  context,
                  won
                      ? 'Solved a ${widget.n}×${widget.n} cube in ${watch.elapsed.inSeconds}s and smoked $botName on MYNDASH 🧊🔥'
                      : 'Cube race lost to $botName on MYNDASH — revenge run loading 🧊😤'),
              icon: Icon(Icons.ios_share, size: 16, color: DC.cyan),
              label: Text('Share result',
                  style: TextStyle(color: DC.cyan, fontSize: 13)),
            ),
            const SizedBox(height: 6),
            NeonButton(
              label: 'PLAY AGAIN',
              icon: Icons.refresh,
              height: 46,
              colors: [DC.magenta, DC.violet],
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) => CubeBotRaceScreen(
                            n: widget.n, timeMinutes: widget.timeMinutes)));
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

  @override
  Widget build(BuildContext context) {
    final botFrac =
        (watch.elapsedMilliseconds / botMs).clamp(0.0, 1.0).toDouble();
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
                    child: Icon(Icons.flag, size: 18, color: DC.danger)),
                const SizedBox(width: 10),
                Text('CUBE RACE',
                    style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                Pill(
                    icon: Icons.timer,
                    // Timed mode counts DOWN the 5/10-min limit; otherwise
                    // counts elapsed solve time up.
                    label: widget.timeMinutes > 0
                        ? _fmtRemain(widget.timeMinutes * 60000 -
                            watch.elapsedMilliseconds)
                        : '${watch.elapsed.inSeconds}s',
                    color: DC.cyan),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(children: [
                LetterAvatar(name: botName, size: 20),
                const SizedBox(width: 6),
                Text(botName,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w800)),
                const SizedBox(width: 10),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: botFrac,
                      minHeight: 6,
                      backgroundColor: DC.fg10,
                      color: botFrac > 0.75 ? DC.danger : DC.magenta,
                    ),
                  ),
                ),
              ]),
            ),
            Expanded(
              child: CubeBoard(
                cube: cube,
                wideAvailable: widget.n >= 4,
                onTurn: _onTurn,
                enabled: !finished,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// ============================================================
/// ONLINE RACE — same seeded scramble, first solve wins.
/// ============================================================
class CubeRaceScreen extends StatefulWidget {
  final Map<String, dynamic> room;
  final bool amHost;
  const CubeRaceScreen({super.key, required this.room, required this.amHost});

  @override
  State<CubeRaceScreen> createState() => _CubeRaceScreenState();
}

class _CubeRaceScreenState extends State<CubeRaceScreen> {
  late final String roomId = widget.room['id'];
  late final String mySide = widget.amHost ? 'host' : 'guest';
  late final String oppSide = widget.amHost ? 'guest' : 'host';
  late final Map<String, dynamic> opp =
      Map<String, dynamic>.from(widget.room[oppSide] as Map);
  late final int n;
  late CubeState cube;
  final watch = Stopwatch()..start();
  StreamSubscription? sub;
  int oppMoves = 0;
  bool finished = false;

  @override
  void initState() {
    super.initState();
    n = int.tryParse('${widget.room['sub']}') ?? 2;
    final seed = (widget.room['seed'] as num?)?.toInt() ?? 1;
    cube = CubeState(n)..scramble(math.Random(seed));
    AccountService.instance.pinRoom(roomId, true);
    sub = AccountService.instance.roomStream(roomId).listen(_onRoom);
  }

  void _onRoom(Map<String, dynamic>? r) {
    if (r == null || finished || !mounted) return;
    final st = r['state'] as Map?;
    final o = st?[oppSide] as Map?;
    if (o != null) {
      final m = (o['moves'] as num?)?.toInt() ?? 0;
      if (m != oppMoves) setState(() => oppMoves = m);
    }
    // Atomic winner claim decides the race — first commit wins,
    // both phones converge on the same result instantly.
    final w = st?['winner'];
    if (w == oppSide) {
      _finish(false);
      return;
    }
    if (st?['left'] == oppSide) _finish(true, forfeit: true);
  }

  void _onTurn() {
    AccountService.instance
        .roomWrite(roomId, 'state/$mySide/moves', cube.moveCount);
    if (!finished && cube.solved) {
      AccountService.instance.roomWrite(
          roomId, 'state/$mySide/solvedMs', watch.elapsedMilliseconds);
      AccountService.instance.claimRoomWin(roomId, mySide).then((won) {
        if (mounted && !finished) _finish(won);
      });
    }
    setState(() {});
  }

  void _finish(bool won, {bool forfeit = false}) {
    if (finished) return;
    finished = true;
    watch.stop();
    if (won) {
      Fx.win();
    } else {
      Fx.lose();
    }
    final a = AppData.i;
    final oppElo = (opp['elo'] as num?)?.toInt() ?? 800;
    final delta = a.applyElo(oppElo, won ? 1 : 0);
    a.addXp(won ? 50 : 15);
    a.recordMatch(
        mode: 'Cube 🧊 online',
        opponent: '@${opp['u']}',
        result: won ? 'W' : 'L',
        delta: delta);
    AccountService.instance.updatePublicProfile();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: DC.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (won) const ConfettiBurst(height: 70),
            Icon(won ? Icons.emoji_events : Icons.bolt,
                size: 60, color: won ? DC.amber : DC.violet),
            const SizedBox(height: 10),
            Text(won ? 'SOLVED FIRST!' : 'OUT-CUBED',
                style: Theme.of(context).textTheme.displayMedium),
            Text(
                forfeit
                    ? '@${opp['u']} left the race'
                    : 'vs @${opp['u']} ($oppElo)',
                style: TextStyle(color: DC.dim)),
            const SizedBox(height: 8),
            Text('${delta >= 0 ? '+' : ''}$delta rating',
                style: TextStyle(
                    color: delta >= 0 ? DC.lime : DC.danger,
                    fontWeight: FontWeight.w900,
                    fontSize: 18)),
            const SizedBox(height: 8),
            const ReactionBar(),
            TextButton.icon(
              onPressed: () => shareResult(
                  context,
                  won
                      ? 'Won a live ${n}×$n cube race vs @${opp['u']} on MYNDASH 🧊⚡'
                      : 'Lost a cube race to @${opp['u']} on MYNDASH — rematch soon 🧊'),
              icon: Icon(Icons.ios_share, size: 16, color: DC.cyan),
              label: Text('Share result',
                  style: TextStyle(color: DC.cyan, fontSize: 13)),
            ),
            const SizedBox(height: 6),
            RematchButton(room: widget.room, amHost: widget.amHost),
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
  void dispose() {
    AccountService.instance.pinRoom(roomId, false);
    sub?.cancel();
    if (!finished) {
      AccountService.instance.roomWrite(roomId, 'state/left', mySide);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                    child: Icon(Icons.flag, size: 18, color: DC.danger)),
                const SizedBox(width: 10),
                Text('LIVE CUBE RACE',
                    style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                Pill(
                    icon: Icons.timer,
                    label: '${watch.elapsed.inSeconds}s',
                    color: DC.cyan),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Glass(
                radius: 16,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(children: [
                  Text('@${opp['u']}',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  Text('$oppMoves moves',
                      style: TextStyle(fontSize: 12, color: DC.magenta)),
                ]),
              ),
            ),
            Expanded(
              child: CubeBoard(
                cube: cube,
                wideAvailable: n >= 4,
                onTurn: _onTurn,
                enabled: !finished,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../core/fx.dart';
import '../engine/mind_engines.dart';
import '../theme_district.dart';
import '../ui/game_tutorial.dart';
import '../ui/glass.dart';
import 'mind_games.dart';

/// ============================================================
/// NUMBER PUZZLE 🔢 — the classic sliding 15-puzzle family.
/// Chunky 3D bevelled tiles glide into the gap; boards grow
/// 3×3 → 4×4 → 5×5 across 50 levels. Order every number to win.
/// ============================================================

const _numTutorial = [
  TutorialStep('Tap a tile next to the gap — it slides in.',
      gesture: TutorialGesture.tap),
  TutorialStep('You can also swipe anywhere on the board to slide.',
      gesture: TutorialGesture.dragAcross),
  TutorialStep('Arrange 1, 2, 3… in order, gap last, to win!',
      gesture: TutorialGesture.none),
];

Widget numpzBuilder(
        {int level = 1,
        int? botLevel,
        Map<String, dynamic>? room,
        bool amHost = true,
        int? progressionStep,
        int? puzzleSeed,
        int? displayRating,
        ValueChanged<int>? arenaScore}) =>
    NumPuzzleScreen(
      level: level,
      botLevel: botLevel,
      room: room,
      amHost: amHost,
      progressionStep: progressionStep,
      puzzleSeed: puzzleSeed,
      displayRating: displayRating,
      arenaScore: arenaScore,
    );

class NumPuzzleScreen extends StatefulWidget {
  final int level;
  final int? botLevel;
  final Map<String, dynamic>? room;
  final bool amHost;
  final int? progressionStep;
  final int? puzzleSeed;
  final int? displayRating;
  final ValueChanged<int>? arenaScore;
  const NumPuzzleScreen(
      {super.key,
      this.level = 1,
      this.botLevel,
      this.room,
      this.amHost = true,
      this.progressionStep,
      this.puzzleSeed,
      this.displayRating,
      this.arenaScore});

  @override
  State<NumPuzzleScreen> createState() => _NumPuzzleScreenState();
}

class _NumPuzzleScreenState extends State<NumPuzzleScreen>
    with TickerProviderStateMixin, MindRace {
  late SlidePuzzle pz;
  int pressedTile = -1;

  @override
  void initState() {
    super.initState();
    final lvl = widget.room != null
        ? mindOnlineLevel(widget.room!)
        : (widget.botLevel ?? widget.level);
    initRace(
        game: 'numpz',
        label: 'Number Puzzle 🔢',
        level: lvl,
        botLevel: widget.botLevel,
        room: widget.room,
        amHost: widget.amHost,
        progressionStep: widget.progressionStep,
        progressMaxLevel: widget.progressionStep == null ? null : 270,
        displayRating: widget.displayRating,
        localSeed: widget.puzzleSeed,
        arenaScore: widget.arenaScore);
    pz = SlidePuzzle(SlidePuzzle.sizeForLevel(lvl), raceSeed,
        SlidePuzzle.depthForLevel(lvl));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        GameTutorial.showOnce(context,
            tutKey: 'numpz', title: 'NUMBER PUZZLE', steps: _numTutorial);
      }
    });
  }

  @override
  void dispose() {
    disposeRace();
    super.dispose();
  }

  @override
  void onPlayAgain(int level) {
    Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => NumPuzzleScreen(
                level: isBot ? widget.level : level,
                botLevel: isBot ? level : null,
                progressionStep: widget.progressionStep,
                puzzleSeed: widget.puzzleSeed,
                displayRating: widget.displayRating,
                arenaScore: widget.arenaScore)));
  }

  void _tapTile(int cellIndex) {
    if (raceOver || paused) return;
    if (pz.tap(cellIndex)) {
      Fx.tap();
      setState(() {});
      reportProgress(pz.progress);
      if (pz.solved) solvedNow();
    } else {
      Fx.light();
    }
  }

  /// Swipe: move the tile on the OPPOSITE side of the blank into the gap
  /// (i.e. swipe right pushes the tile left of the blank rightwards).
  void _swipe(int dr, int dc) {
    if (raceOver || paused) return;
    final n = pz.n;
    final blank = pz.cells.indexOf(0);
    final r = blank ~/ n - dr, c = blank % n - dc;
    if (r < 0 || r >= n || c < 0 || c >= n) return;
    _tapTile(r * n + c);
  }

  @override
  Widget build(BuildContext context) {
    final n = pz.n;
    return Scaffold(
      body: ShaderBackground(
        child: SafeArea(
          child: Stack(children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                raceHud(context,
                    accent: DC.electric,
                    help: GameTutorial.helpButton(context,
                        title: 'NUMBER PUZZLE', steps: _numTutorial)),
                const SizedBox(height: 6),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Pill(
                      icon: Icons.swap_horiz,
                      label: '${pz.moves} moves',
                      color: DC.cyan),
                  const SizedBox(width: 8),
                  Pill(
                      icon: Icons.grid_view,
                      label: '$n×$n',
                      color: DC.electric),
                  const SizedBox(width: 8),
                  Pill(
                      icon: Icons.check_circle,
                      label: '${(pz.progress * 100).round()}%',
                      color: DC.lime),
                ]),
                const Spacer(),
                Tilt3D(tilt: 0.09, child: _board()),
                const Spacer(),
                Text('Tap a tile beside the gap — or swipe the board.',
                    style: TextStyle(fontSize: 11, color: DC.dim)),
                const SizedBox(height: 8),
              ]),
            ),
            pauseCurtain(),
          ]),
        ),
      ),
    );
  }

  Widget _board() {
    final n = pz.n;
    return AspectRatio(
      aspectRatio: 1,
      child: GestureDetector(
        onHorizontalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (v.abs() > 80) _swipe(0, v > 0 ? 1 : -1);
        },
        onVerticalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (v.abs() > 80) _swipe(v > 0 ? 1 : -1, 0);
        },
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: ThemeCtl.isDark
                    ? [const Color(0xFF14172B), const Color(0xFF0A0C18)]
                    : [const Color(0xFFDDE4F5), const Color(0xFFBCC8E8)]),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 12)),
            ],
            border: Border.all(color: DC.electric.withOpacity(0.35)),
          ),
          child: LayoutBuilder(builder: (context, box) {
            final side = box.maxWidth;
            final cell = side / n;
            return Stack(children: [
              // the empty socket (subtle inner hole)
              for (var i = 0; i < n * n; i++)
                if (pz.cells[i] == 0)
                  Positioned(
                    left: (i % n) * cell,
                    top: (i ~/ n) * cell,
                    width: cell,
                    height: cell,
                    child: Container(
                      margin: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.black.withOpacity(0.25),
                        border: Border.all(color: DC.fgo(0.06), width: 1),
                      ),
                    ),
                  ),
              // tiles
              for (var i = 0; i < n * n; i++)
                if (pz.cells[i] != 0) _tile(i, cell),
            ]);
          }),
        ),
      ),
    );
  }

  Widget _tile(int i, double cell) {
    final n = pz.n;
    final v = pz.cells[i];
    final correct = v == i + 1;
    final pressed = pressedTile == i;
    return AnimatedPositioned(
      key: ValueKey('tile$v'),
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      left: (i % n) * cell,
      top: (i ~/ n) * cell,
      width: cell,
      height: cell,
      child: GestureDetector(
        onTapDown: (_) => setState(() => pressedTile = i),
        onTapCancel: () => setState(() => pressedTile = -1),
        onTapUp: (_) {
          setState(() => pressedTile = -1);
          _tapTile(i);
        },
        child: AnimatedScale(
          scale: pressed ? 0.93 : 1,
          duration: const Duration(milliseconds: 80),
          child: Container(
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: correct
                    ? [const Color(0xFF35D07F), const Color(0xFF1B9A5A)]
                    : [
                        Color.lerp(DC.electric, Colors.white, 0.25)!,
                        DC.electric,
                        Color.lerp(DC.electric, Colors.black, 0.3)!,
                      ],
                stops: correct ? null : const [0, 0.5, 1],
              ),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 4)),
                // bevel: light inner top edge
                BoxShadow(
                    color: Colors.white.withOpacity(0.25),
                    blurRadius: 1,
                    spreadRadius: -1,
                    offset: const Offset(0, -1)),
              ],
              border: Border.all(color: Colors.black.withOpacity(0.2)),
            ),
            alignment: Alignment.center,
            child: Text('$v',
                style: TextStyle(
                    fontSize: cell * 0.38,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    shadows: const [
                      Shadow(
                          color: Colors.black38,
                          offset: Offset(0, 2),
                          blurRadius: 2),
                    ])),
          ),
        ),
      ),
    );
  }
}

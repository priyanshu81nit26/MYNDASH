import 'dart:async';

import 'package:flutter/material.dart';

import '../core/fx.dart';
import '../engine/mind_engines.dart';
import '../theme_district.dart';
import '../ui/game_tutorial.dart';
import '../ui/glass.dart';
import 'mind_games.dart';

/// ============================================================
/// ARROW PUZZLE 🧭 — tap a tile and it spins 90° clockwise…
/// along with its up/down/left/right neighbours (they follow a
/// beat later — watch the cascade!). Point EVERY arrow up to win.
/// ============================================================

const _arrowTutorial = [
  TutorialStep('Tap a tile — it rotates 90° clockwise.',
      gesture: TutorialGesture.tap),
  TutorialStep('Its 4 neighbours (up/down/left/right) spin too!',
      gesture: TutorialGesture.tap),
  TutorialStep('Make every arrow point UP. Fewer taps = smarter.',
      gesture: TutorialGesture.none),
];

Widget arrowBuilder(
        {int level = 1,
        int? botLevel,
        Map<String, dynamic>? room,
        bool amHost = true,
        int? progressionStep,
        int? puzzleSeed,
        int? displayRating}) =>
    ArrowPuzzleScreen(
      level: level,
      botLevel: botLevel,
      room: room,
      amHost: amHost,
      progressionStep: progressionStep,
      puzzleSeed: puzzleSeed,
      displayRating: displayRating,
    );

class ArrowPuzzleScreen extends StatefulWidget {
  final int level;
  final int? botLevel;
  final Map<String, dynamic>? room;
  final bool amHost;
  final int? progressionStep;
  final int? puzzleSeed;
  final int? displayRating;
  const ArrowPuzzleScreen(
      {super.key,
      this.level = 1,
      this.botLevel,
      this.room,
      this.amHost = true,
      this.progressionStep,
      this.puzzleSeed,
      this.displayRating});

  @override
  State<ArrowPuzzleScreen> createState() => _ArrowPuzzleScreenState();
}

class _ArrowPuzzleScreenState extends State<ArrowPuzzleScreen> with MindRace {
  late ArrowPuzzle pz;
  late List<double> visTurns; // cumulative visual quarter-turns
  bool busy = false;

  @override
  void initState() {
    super.initState();
    final lvl = widget.room != null
        ? mindOnlineLevel(widget.room!)
        : (widget.botLevel ?? widget.level);
    initRace(
        game: 'arrow',
        label: 'Arrow Puzzle 🧭',
        level: lvl,
        botLevel: widget.botLevel,
        room: widget.room,
        amHost: widget.amHost,
        progressionStep: widget.progressionStep,
        progressMaxLevel: widget.progressionStep == null ? null : 540,
        displayRating: widget.displayRating,
        localSeed: widget.puzzleSeed);
    pz = ArrowPuzzle(ArrowPuzzle.sizeForLevel(lvl), raceSeed,
        ArrowPuzzle.scrambleForLevel(lvl));
    visTurns = pz.dirs.map((d) => d * 0.25).toList();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        GameTutorial.showOnce(context,
            tutKey: 'arrowpz', title: 'ARROW PUZZLE', steps: _arrowTutorial);
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
            builder: (_) => ArrowPuzzleScreen(
                level: isBot ? widget.level : level,
                botLevel: isBot ? level : null,
                progressionStep: widget.progressionStep,
                puzzleSeed: widget.puzzleSeed,
                displayRating: widget.displayRating)));
  }

  void _tap(int i) {
    if (raceOver || paused || busy) return;
    busy = true;
    Fx.tap();
    pz.tap(i);
    // cascade: the tapped tile turns instantly, neighbours a beat later
    setState(() => visTurns[i] += 0.25);
    final others = pz.affected(i).where((j) => j != i).toList();
    Timer(const Duration(milliseconds: 90), () {
      if (!mounted) return;
      Fx.light();
      setState(() {
        for (final j in others) {
          visTurns[j] += 0.25;
        }
      });
      Timer(const Duration(milliseconds: 260), () {
        if (!mounted) return;
        busy = false;
        reportProgress(pz.progress);
        if (pz.solved) solvedNow();
      });
    });
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
                    accent: DC.violet,
                    help: GameTutorial.helpButton(context,
                        title: 'ARROW PUZZLE', steps: _arrowTutorial)),
                const SizedBox(height: 6),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Pill(
                      icon: Icons.touch_app,
                      label: '${pz.taps} taps',
                      color: DC.cyan),
                  const SizedBox(width: 8),
                  Pill(
                      icon: Icons.navigation,
                      label:
                          '${pz.dirs.where((d) => d == 0).length}/${n * n} up',
                      color: DC.lime),
                ]),
                const Spacer(),
                Tilt3D(tilt: 0.09, child: _board()),
                const Spacer(),
                Text('A tap also spins the 4 tiles around it.',
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
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: ThemeCtl.isDark
                  ? [const Color(0xFF1C1230), const Color(0xFF0D0918)]
                  : [const Color(0xFFEDE6FA), const Color(0xFFD8CBF2)]),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 12)),
          ],
          border: Border.all(color: DC.violet.withOpacity(0.35)),
        ),
        child: Column(children: [
          for (var r = 0; r < n; r++)
            Expanded(
              child: Row(children: [
                for (var c = 0; c < n; c++) Expanded(child: _tile(r * n + c)),
              ]),
            ),
        ]),
      ),
    );
  }

  Widget _tile(int i) {
    final up = pz.dirs[i] == 0;
    return GestureDetector(
      onTap: () => _tap(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: up
                ? [
                    DC.lime.withOpacity(0.55),
                    DC.lime.withOpacity(0.22),
                  ]
                : [DC.fgo(0.14), DC.fgo(0.05)],
          ),
          border: Border.all(
              color: up ? DC.lime.withOpacity(0.8) : DC.fgo(0.16),
              width: up ? 1.6 : 1),
          boxShadow: [
            BoxShadow(
                color: up
                    ? DC.lime.withOpacity(0.30)
                    : Colors.black.withOpacity(0.25),
                blurRadius: up ? 12 : 5,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Center(
          child: AnimatedRotation(
            turns: visTurns[i],
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutBack,
            child: Icon(Icons.navigation,
                size: 30, color: up ? DC.lime : DC.text.withOpacity(0.85)),
          ),
        ),
      ),
    );
  }
}

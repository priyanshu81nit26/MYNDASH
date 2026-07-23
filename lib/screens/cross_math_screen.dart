import 'package:flutter/material.dart';

import '../engine/rating_catalog.dart';
import '../puzzles/cross_math_board.dart';
import '../theme_district.dart';
import '../ui/game_tutorial.dart';
import '../ui/glass.dart';
import 'mind_games.dart';

const _crossMathTutorial = [
  TutorialStep(
    'This is one connected arithmetic crossword, not a list of questions.',
  ),
  TutorialStep(
    'Dark cells are given. Gold question cells are numbers you must find.',
  ),
  TutorialStep(
    'Tap a missing cell, then choose a number. Check every horizontal and vertical crossing.',
  ),
  TutorialStep(
    'Correct answers stay green. Complete all six linked equations to win.',
  ),
];

Widget crossMathBuilder({
  int level = 1,
  int? botLevel,
  Map<String, dynamic>? room,
  bool amHost = true,
  int? progressionStep,
  int? puzzleSeed,
  int? displayRating,
  ValueChanged<int>? arenaScore,
}) =>
    CrossMathGameScreen(
      level: level,
      botLevel: botLevel,
      room: room,
      amHost: amHost,
      progressionStep: progressionStep,
      puzzleSeed: puzzleSeed,
      displayRating: displayRating,
      arenaScore: arenaScore,
    );

class CrossMathGameScreen extends StatefulWidget {
  final int level;
  final int? botLevel;
  final Map<String, dynamic>? room;
  final bool amHost;
  final int? progressionStep;
  final int? puzzleSeed;
  final int? displayRating;
  final ValueChanged<int>? arenaScore;

  const CrossMathGameScreen({
    super.key,
    this.level = 1,
    this.botLevel,
    this.room,
    this.amHost = true,
    this.progressionStep,
    this.puzzleSeed,
    this.displayRating,
    this.arenaScore,
  });

  @override
  State<CrossMathGameScreen> createState() => _CrossMathGameScreenState();
}

class _CrossMathGameScreenState extends State<CrossMathGameScreen>
    with MindRace {
  late final int engineLevel;
  late final int rating;

  @override
  void initState() {
    super.initState();
    engineLevel = widget.room != null
        ? mindOnlineLevel(widget.room!)
        : (widget.botLevel ?? widget.level);
    rating = widget.displayRating ??
        RatingCatalog.ratingForLegacyLevel(engineLevel, maxLevel: 50);
    initRace(
      game: 'crossmath',
      label: 'Cross Math',
      level: engineLevel,
      botLevel: widget.botLevel,
      room: widget.room,
      amHost: widget.amHost,
      progressionStep: widget.progressionStep,
      progressMaxLevel: widget.progressionStep == null ? null : 540,
      displayRating: rating,
      localSeed: widget.puzzleSeed,
      arenaScore: widget.arenaScore,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      GameTutorial.showOnce(
        context,
        tutKey: 'cross_math_grid',
        title: 'CROSS MATH',
        steps: _crossMathTutorial,
      );
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
        builder: (_) => CrossMathGameScreen(
          level: isBot ? widget.level : level,
          botLevel: isBot ? level : null,
          progressionStep: widget.progressionStep,
          puzzleSeed: widget.puzzleSeed,
          displayRating: widget.displayRating,
          arenaScore: widget.arenaScore,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ShaderBackground(
        child: SafeArea(
          child: Stack(children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(children: [
                raceHud(
                  context,
                  accent: DC.amber,
                  help: GameTutorial.helpButton(
                    context,
                    title: 'CROSS MATH',
                    steps: _crossMathTutorial,
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: CrossMathBoard(
                    rating: rating,
                    seed: raceSeed,
                    onProgress: reportProgress,
                    onSolved: solvedNow,
                  ),
                ),
              ]),
            ),
            pauseCurtain(),
          ]),
        ),
      ),
    );
  }
}

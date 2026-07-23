import 'package:flutter/material.dart';

import '../engine/rating_catalog.dart';
import '../puzzles/word_hunt_board.dart';
import '../theme_district.dart';
import '../ui/game_tutorial.dart';
import '../ui/glass.dart';
import 'mind_games.dart';

const _wordHuntTutorial = [
  TutorialStep(
    'Drag through touching letters in any direction. You may also tap a path.',
    gesture: TutorialGesture.dragAcross,
  ),
  TutorialStep(
    'Make any real dictionary word with 3 or more letters. There is no fixed answer.',
  ),
  TutorialStep(
    'Several valid words are woven into every board, but every valid trail counts.',
  ),
  TutorialStep(
    'Find the target number of unique words before your rival.',
  ),
];

Widget crosswordBuilder({
  int level = 1,
  int? botLevel,
  Map<String, dynamic>? room,
  bool amHost = true,
  int? progressionStep,
  int? puzzleSeed,
  int? displayRating,
  ValueChanged<int>? arenaScore,
}) =>
    CrosswordScreen(
      level: level,
      botLevel: botLevel,
      room: room,
      amHost: amHost,
      progressionStep: progressionStep,
      puzzleSeed: puzzleSeed,
      displayRating: displayRating,
      arenaScore: arenaScore,
    );

/// Open-ended Crossword is now a seeded word hunt rather than a clue sheet.
///
/// Keeping the existing public class/builder contract means arenas, bots,
/// online rooms, and rated progression all use the same redesigned board.
class CrosswordScreen extends StatefulWidget {
  final int level;
  final int? botLevel;
  final Map<String, dynamic>? room;
  final bool amHost;
  final int? progressionStep;
  final int? puzzleSeed;
  final int? displayRating;
  final ValueChanged<int>? arenaScore;

  const CrosswordScreen({
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
  State<CrosswordScreen> createState() => _CrosswordScreenState();
}

class _CrosswordScreenState extends State<CrosswordScreen> with MindRace {
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
      game: 'crossword',
      label: 'Word Hunt',
      level: engineLevel,
      botLevel: widget.botLevel,
      room: widget.room,
      amHost: widget.amHost,
      progressionStep: widget.progressionStep,
      progressMaxLevel: widget.progressionStep == null ? null : 360,
      displayRating: rating,
      localSeed: widget.puzzleSeed,
      arenaScore: widget.arenaScore,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      GameTutorial.showOnce(
        context,
        tutKey: 'open_word_hunt',
        title: 'WORD HUNT',
        steps: _wordHuntTutorial,
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
        builder: (_) => CrosswordScreen(
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
                  accent: DC.violet,
                  help: GameTutorial.helpButton(
                    context,
                    title: 'WORD HUNT',
                    steps: _wordHuntTutorial,
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: WordHuntBoard(
                    rating: rating,
                    seed: raceSeed,
                    targetWords: rating < 1300
                        ? 4
                        : rating < 1900
                            ? 5
                            : 6,
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

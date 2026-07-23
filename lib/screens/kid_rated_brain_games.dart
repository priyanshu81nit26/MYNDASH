import 'dart:async';

import 'package:flutter/material.dart';

import '../core/fx.dart';
import '../core/state.dart';
import '../engine/rating_catalog.dart';
import '../puzzles/board_core.dart';
import '../puzzles/cross_math_board.dart';
import '../puzzles/grid_boards.dart';
import '../puzzles/word_hunt_board.dart';
import '../theme_district.dart';
import '../ui/game_tutorial.dart';
import '../ui/glass.dart';

const kidRatedVariants = 20;
const kidRatedSteps = 18 * kidRatedVariants;

int _stableKidSeed(String gameId, int rating, int variant) {
  var hash = 0x51A7E;
  for (final codeUnit in gameId.codeUnits) {
    hash = ((hash * 31) + codeUnit) & 0x7fffffff;
  }
  return (hash ^ (rating * 7919) ^ (variant * 104729)) & 0x7fffffff;
}

typedef KidRatedLevelBuilder = Widget Function(
  int step,
  int rating,
  int seed,
);

class KidRatedJourney extends StatefulWidget {
  final String gameId;
  final String title;
  final String subtitle;
  final Color accent;
  final IconData icon;
  final KidRatedLevelBuilder builder;

  const KidRatedJourney({
    super.key,
    required this.gameId,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.icon,
    required this.builder,
  });

  @override
  State<KidRatedJourney> createState() => _KidRatedJourneyState();
}

class _KidRatedJourneyState extends State<KidRatedJourney> {
  @override
  Widget build(BuildContext context) {
    final app = AppData.i;
    final unlocked = app.kidLevel(widget.gameId).clamp(1, kidRatedSteps);
    return Scaffold(
      body: ShaderBackground(
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Row(children: [
                Glass(
                  radius: 16,
                  padding: const EdgeInsets.all(8),
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back_rounded, size: 18),
                ),
                const SizedBox(width: 12),
                Icon(widget.icon, color: widget.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Pill(
                  icon: Icons.flag_rounded,
                  label: '${unlocked - 1}/$kidRatedSteps',
                  color: widget.accent,
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '${widget.subtitle}\n800-2500 difficulty · $kidRatedVariants fresh boards at every rating',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: DC.dim),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                itemCount: RatingCatalog.bands.length,
                itemBuilder: (_, band) =>
                    _band(app, unlocked, band, RatingCatalog.bands[band]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _band(AppData app, int unlocked, int band, int rating) {
    final first = band * kidRatedVariants + 1;
    final open = first <= unlocked;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: open ? widget.accent.withOpacity(0.09) : DC.fgo(0.025),
        border: Border.all(
          color: open ? widget.accent.withOpacity(0.42) : DC.fgo(0.08),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(
            '$rating',
            style: TextStyle(
              color: open ? widget.accent : DC.dim,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$kidRatedVariants seeded combinations',
              style: TextStyle(fontSize: 10, color: DC.dim),
            ),
          ),
          if (!open) Icon(Icons.lock_rounded, size: 16, color: DC.fg38),
        ]),
        const SizedBox(height: 10),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (var variant = 1; variant <= kidRatedVariants; variant++)
              _levelButton(app, unlocked, band, rating, variant),
          ],
        ),
      ]),
    );
  }

  Widget _levelButton(
    AppData app,
    int unlocked,
    int band,
    int rating,
    int variant,
  ) {
    final step = band * kidRatedVariants + variant;
    final open = step <= unlocked;
    final stars = (app.kidProgress['${widget.gameId}_s$step'] as int?) ?? 0;
    return Semantics(
      button: true,
      enabled: open,
      label: '$rating board $variant${open ? '' : ', locked'}',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: open
            ? () async {
                Fx.tap();
                final seed = _stableKidSeed(widget.gameId, rating, variant);
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => widget.builder(step, rating, seed),
                  ),
                );
                if (mounted) setState(() {});
              }
            : () => Fx.error(),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: open
                ? widget.accent.withOpacity(stars > 0 ? 0.25 : 0.10)
                : DC.fgo(0.025),
            border: Border.all(
              color: step == unlocked
                  ? Colors.white
                  : open
                      ? widget.accent.withOpacity(0.55)
                      : DC.fgo(0.07),
              width: step == unlocked ? 2 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: open
              ? Stack(alignment: Alignment.center, children: [
                  Text(
                    '$variant',
                    style: TextStyle(
                      color: stars > 0 ? DC.lime : DC.text,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (stars > 0)
                    Positioned(
                      top: 2,
                      right: 3,
                      child: Icon(Icons.star_rounded, size: 9, color: DC.amber),
                    ),
                ])
              : Icon(Icons.lock_rounded, size: 15, color: DC.fg38),
        ),
      ),
    );
  }
}

class _KidLevelClock {
  final int startedAt = DateTime.now().millisecondsSinceEpoch;

  int get seconds =>
      (DateTime.now().millisecondsSinceEpoch - startedAt) ~/ 1000;
}

Future<void> _showKidRatedResult(
  BuildContext context, {
  required String gameId,
  required int step,
  required int rating,
  required int stars,
  required String detail,
}) async {
  final app = AppData.i;
  app.recordKidLevel(gameId, step, stars, max: kidRatedSteps);
  final key = '${gameId}_s$step';
  final previous = (app.kidProgress[key] as int?) ?? 0;
  if (stars > previous) app.kidProgress[key] = stars;
  await app.save();
  if (!context.mounted) return;
  stars > 0 ? Fx.win() : Fx.lose();
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: DC.bg2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      icon: Icon(
        stars > 0 ? Icons.verified_rounded : Icons.replay_rounded,
        color: stars > 0 ? DC.lime : DC.amber,
        size: 48,
      ),
      title: Text(stars > 0 ? 'BOARD CLEARED' : 'TRY AGAIN'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('$rating · $detail', textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var index = 0; index < 3; index++)
              Icon(
                index < stars ? Icons.star_rounded : Icons.star_border_rounded,
                color: DC.amber,
              ),
          ],
        ),
      ]),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        FilledButton(
          onPressed: () {
            Navigator.pop(dialogContext);
            Navigator.pop(context);
          },
          child: const Text('BACK TO LEVELS'),
        ),
      ],
    ),
  );
}

class KidWordHuntLevel extends StatefulWidget {
  final int step;
  final int rating;
  final int seed;

  const KidWordHuntLevel({
    super.key,
    required this.step,
    required this.rating,
    required this.seed,
  });

  @override
  State<KidWordHuntLevel> createState() => _KidWordHuntLevelState();
}

class _KidWordHuntLevelState extends State<KidWordHuntLevel> {
  final clock = _KidLevelClock();
  bool done = false;

  void _finish() {
    if (done) return;
    done = true;
    final seconds = clock.seconds;
    final par = widget.rating < 1400
        ? 110
        : widget.rating < 2000
            ? 95
            : 80;
    final stars = seconds <= par
        ? 3
        : seconds <= (par * 1.5).round()
            ? 2
            : 1;
    _showKidRatedResult(
      context,
      gameId: 'kidword',
      step: widget.step,
      rating: widget.rating,
      stars: stars,
      detail: '$seconds seconds',
    );
  }

  @override
  Widget build(BuildContext context) => _KidRatedScaffold(
        title: 'WORD HUNT',
        rating: widget.rating,
        accent: DC.violet,
        child: WordHuntBoard(
          rating: widget.rating,
          seed: widget.seed,
          kids: true,
          onSolved: _finish,
        ),
      );
}

class KidCrossMathLevel extends StatefulWidget {
  final int step;
  final int rating;
  final int seed;

  const KidCrossMathLevel({
    super.key,
    required this.step,
    required this.rating,
    required this.seed,
  });

  @override
  State<KidCrossMathLevel> createState() => _KidCrossMathLevelState();
}

class _KidCrossMathLevelState extends State<KidCrossMathLevel> {
  final clock = _KidLevelClock();
  bool done = false;

  void _finish() {
    if (done) return;
    done = true;
    final seconds = clock.seconds;
    final stars = seconds <= 120
        ? 3
        : seconds <= 190
            ? 2
            : 1;
    _showKidRatedResult(
      context,
      gameId: 'kidcrossmath',
      step: widget.step,
      rating: widget.rating,
      stars: stars,
      detail: 'six equations · ${seconds}s',
    );
  }

  @override
  Widget build(BuildContext context) => _KidRatedScaffold(
        title: 'CROSS MATH',
        rating: widget.rating,
        accent: DC.lime,
        child: CrossMathBoard(
          rating: widget.rating,
          seed: widget.seed,
          kids: true,
          onSolved: _finish,
        ),
      );
}

const _kidKenKenTutorial = [
  TutorialStep('Use every number once in each row and column.'),
  TutorialStep(
    'Outlined cages have a target and operation. Their cells must combine to make that target.',
  ),
  TutorialStep('A 6× cage can hold 2 and 3. A 2÷ cage can hold 4 and 2.'),
  TutorialStep('Correct numbers turn green. Three mistakes reset the board.'),
];

class KidKenKenLevel extends StatefulWidget {
  final int step;
  final int rating;
  final int seed;

  const KidKenKenLevel({
    super.key,
    required this.step,
    required this.rating,
    required this.seed,
  });

  @override
  State<KidKenKenLevel> createState() => _KidKenKenLevelState();
}

class _KidKenKenLevelState extends State<KidKenKenLevel> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      GameTutorial.showOnce(
        context,
        tutKey: 'kid_kenken',
        title: 'KENKEN TRAINING',
        steps: _kidKenKenTutorial,
      );
    });
  }

  void _finish(BoardResult result) {
    final seconds = result.timeMs ~/ 1000;
    final stars = !result.won
        ? 0
        : seconds <= 140
            ? 3
            : seconds <= 220
                ? 2
                : 1;
    _showKidRatedResult(
      context,
      gameId: 'kidkenken',
      step: widget.step,
      rating: widget.rating,
      stars: stars,
      detail: result.won ? '${seconds}s · cage master' : 'three mistakes',
    );
  }

  @override
  Widget build(BuildContext context) => _KidRatedScaffold(
        title: 'KENKEN',
        rating: widget.rating,
        accent: DC.amber,
        help: GameTutorial.helpButton(
          context,
          title: 'KENKEN TRAINING',
          steps: _kidKenKenTutorial,
        ),
        scroll: true,
        child: KenKenBoard(
          rating: widget.rating,
          seed: widget.seed,
          onDone: _finish,
        ),
      );
}

class KidSudokuLightLevel extends StatefulWidget {
  final int step;
  final int rating;
  final int seed;

  const KidSudokuLightLevel({
    super.key,
    required this.step,
    required this.rating,
    required this.seed,
  });

  @override
  State<KidSudokuLightLevel> createState() => _KidSudokuLightLevelState();
}

class _KidSudokuLightLevelState extends State<KidSudokuLightLevel> {
  void _finish(BoardResult result) {
    final seconds = result.timeMs ~/ 1000;
    final stars = !result.won
        ? 0
        : seconds <= 180
            ? 3
            : seconds <= 280
                ? 2
                : 1;
    _showKidRatedResult(
      context,
      gameId: 'kidsudoku6',
      step: widget.step,
      rating: widget.rating,
      stars: stars,
      detail: result.won ? '6×6 solved · ${seconds}s' : 'three mistakes',
    );
  }

  @override
  Widget build(BuildContext context) => _KidRatedScaffold(
        title: 'SUDOKU LIGHT 6×6',
        rating: widget.rating,
        accent: DC.cyan,
        scroll: true,
        child: SudokuBoard(
          rating: widget.rating,
          seed: widget.seed,
          forceSize: 6,
          onDone: _finish,
        ),
      );
}

class _KidRatedScaffold extends StatelessWidget {
  final String title;
  final int rating;
  final Color accent;
  final Widget child;
  final Widget? help;
  final bool scroll;

  const _KidRatedScaffold({
    required this.title,
    required this.rating,
    required this.accent,
    required this.child,
    this.help,
    this.scroll = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = scroll
        ? SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 20),
            child: child,
          )
        : child;
    return Scaffold(
      body: ShaderBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(children: [
              Row(children: [
                Glass(
                  radius: 16,
                  padding: const EdgeInsets.all(8),
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close_rounded, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (help != null) ...[help!, const SizedBox(width: 8)],
                Pill(
                  icon: Icons.military_tech_rounded,
                  label: '$rating',
                  color: accent,
                ),
              ]),
              const SizedBox(height: 10),
              Expanded(child: content),
            ]),
          ),
        ),
      ),
    );
  }
}

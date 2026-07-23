import 'dart:math';

import 'package:flutter/material.dart';

import '../puzzles/cross_math_board.dart';
import '../puzzles/grid_boards.dart';
import '../puzzles/word_hunt_board.dart';
import '../screens/art_race.dart';
import '../theme_district.dart';
import '../ui/game_tutorial.dart';
import '../ui/glass.dart';
import 'daily_models.dart';

const _dailyKenKenTutorial = [
  TutorialStep(
    'Fill every row and column with each number exactly once.',
    gesture: TutorialGesture.tap,
  ),
  TutorialStep(
    'A small cage clue shows its target and operation. The numbers inside that outlined cage must make the target.',
  ),
  TutorialStep(
    'For example, 6× can be 2 and 3. A 2÷ cage can be 4 and 2 in either order.',
  ),
  TutorialStep(
    'Tap a cell, then a number. Correct placements turn green with a check.',
  ),
];

class DailyGameScreen extends StatefulWidget {
  final DailyChallengeItem item;
  final VoidCallback? onSolved;
  final bool replay;

  const DailyGameScreen({
    super.key,
    required this.item,
    this.onSolved,
    this.replay = false,
  });

  @override
  State<DailyGameScreen> createState() => _DailyGameScreenState();
}

class _DailyGameScreenState extends State<DailyGameScreen> {
  final answer = TextEditingController();
  int attempt = 0;
  bool finished = false;
  bool wrong = false;

  @override
  void initState() {
    super.initState();
    if (widget.item.type == DailyItemType.kenKen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        GameTutorial.showOnce(
          context,
          tutKey: 'daily_kenken',
          title: 'HOW TO PLAY KENKEN',
          steps: _dailyKenKenTutorial,
        );
      });
    }
  }

  @override
  void dispose() {
    answer.dispose();
    super.dispose();
  }

  void _submit() {
    if (finished || answer.text.trim().isEmpty) return;
    if (widget.item.check(answer.text)) {
      _complete();
    } else {
      setState(() => wrong = true);
    }
  }

  void _boardDone(bool won) {
    if (won) {
      _complete();
      return;
    }
    setState(() => attempt++);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Board reset. Try the fresh layout again.'),
    ));
  }

  void _complete() {
    if (finished) return;
    finished = true;
    widget.onSolved?.call();
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: DC.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: Icon(Icons.verified_rounded, color: DC.lime, size: 52),
        title: Text(widget.replay ? 'Solved again' : 'Challenge cleared'),
        content: Text(
          widget.replay
              ? '${widget.item.rating} practice replay complete.'
              : '+${widget.item.xp} XP · +${widget.item.coins} coins\n'
                  'Saved under ${widget.item.title} · ${widget.item.rating}.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.pop(context);
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Scaffold(
      body: ShaderBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Row(children: [
                Glass(
                  radius: 16,
                  padding: const EdgeInsets.all(8),
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close_rounded, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge),
                      Text(item.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: DC.dim)),
                    ],
                  ),
                ),
                if (item.type == DailyItemType.kenKen) ...[
                  GameTutorial.helpButton(
                    context,
                    title: 'HOW TO PLAY KENKEN',
                    steps: _dailyKenKenTutorial,
                  ),
                  const SizedBox(width: 8),
                ],
                Pill(
                  icon: Icons.monitor_heart_outlined,
                  label: '${item.rating}',
                  color: DC.cyan,
                ),
              ]),
              const SizedBox(height: 14),
              Expanded(child: _content()),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _content() => switch (widget.item.type) {
        DailyItemType.sudoku => SingleChildScrollView(
            key: ValueKey('sudoku-$attempt'),
            child: SudokuBoard(
              rating: widget.item.rating,
              seed: widget.item.seed + attempt,
              forceSize: 8,
              capMistakes: false,
              onDone: (result) => _boardDone(result.won),
            ),
          ),
        DailyItemType.kenKen => SingleChildScrollView(
            key: ValueKey('kenken-$attempt'),
            child: KenKenBoard(
              rating: widget.item.rating,
              seed: widget.item.seed + attempt,
              capMistakes: false,
              onDone: (result) => _boardDone(result.won),
            ),
          ),
        DailyItemType.crossword => WordHuntBoard(
            key: ValueKey('word-hunt-$attempt'),
            rating: widget.item.rating,
            seed: widget.item.seed + attempt,
            targetWords: widget.item.rating < 1500 ? 4 : 5,
            onSolved: _complete,
          ),
        DailyItemType.crossMath => CrossMathBoard(
            key: ValueKey('cross-math-$attempt'),
            rating: widget.item.rating,
            seed: widget.item.seed + attempt,
            onSolved: _complete,
          ),
        DailyItemType.artHeist => _DailyArtHeist(
            key: ValueKey('art-$attempt'),
            seed: widget.item.seed,
            onSolved: _complete,
          ),
        DailyItemType.numberPuzzle => _DailyNumberPuzzle(
            key: ValueKey('number-$attempt'),
            seed: widget.item.seed,
            onSolved: _complete,
          ),
        _ => _answerPuzzle(),
      };

  Widget _answerPuzzle() {
    final item = widget.item;
    return ListView(children: [
      Glass(
        radius: 24,
        padding: const EdgeInsets.all(22),
        border: wrong ? Border.all(color: DC.danger, width: 2) : null,
        child: Text(
          item.prompt ?? '',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: (item.prompt?.length ?? 0) > 90 ? 17 : 21,
            fontWeight: FontWeight.w700,
            height: 1.45,
          ),
        ),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: answer,
        autofocus: true,
        textAlign: TextAlign.center,
        textCapitalization: TextCapitalization.none,
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true, signed: true),
        onChanged: (_) {
          if (wrong) setState(() => wrong = false);
        },
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          labelText: 'Your answer',
          errorText: wrong ? 'That does not satisfy the puzzle yet.' : null,
          helperText: item.type == DailyItemType.math &&
                  item.answer?.contains('/') == true
              ? 'Use a reduced fraction, for example 3/5.'
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
      const SizedBox(height: 12),
      NeonButton(
        label: 'CHECK ANSWER',
        icon: Icons.check_rounded,
        height: 48,
        onPressed: _submit,
      ),
    ]);
  }
}

class _DailyArtHeist extends StatefulWidget {
  final int seed;
  final VoidCallback onSolved;

  const _DailyArtHeist({super.key, required this.seed, required this.onSolved});

  @override
  State<_DailyArtHeist> createState() => _DailyArtHeistState();
}

class _DailyArtHeistState extends State<_DailyArtHeist> {
  static const n = 4;
  late final List<int> tiles;
  int selected = -1;

  @override
  void initState() {
    super.initState();
    final rng = Random(widget.seed);
    tiles = List.generate(n * n, (i) => i);
    for (var i = 0; i < 18; i++) {
      final a = rng.nextInt(tiles.length);
      var b = rng.nextInt(tiles.length);
      if (b == a) b = (b + 1) % tiles.length;
      final t = tiles[a];
      tiles[a] = tiles[b];
      tiles[b] = t;
    }
  }

  void _tap(int index) {
    if (selected < 0) {
      setState(() => selected = index);
      return;
    }
    setState(() {
      final t = tiles[selected];
      tiles[selected] = tiles[index];
      tiles[index] = t;
      selected = -1;
    });
    if (_solved) widget.onSolved();
  }

  bool get _solved {
    for (var i = 0; i < tiles.length; i++) {
      if (tiles[i] != i) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      Glass(
        tint: DC.magenta,
        child: Row(children: [
          Icon(Icons.image_search_rounded, color: DC.magenta),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Restore the complete figure below. Every fragment is one exact slice of this artwork.',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      Text('COMPLETE TARGET',
          style: TextStyle(
              color: DC.dim,
              fontSize: 10,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox.square(
            dimension: 132,
            child: CustomPaint(
              painter: ArtPainter(widget.seed, const Size.square(132)),
            ),
          ),
        ),
      ),
      const SizedBox(height: 14),
      Text('Tap two stolen fragments to swap them.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: DC.dim)),
      const SizedBox(height: 10),
      AspectRatio(aspectRatio: 1, child: _artGrid()),
    ]);
  }

  Widget _artGrid() {
    return LayoutBuilder(builder: (context, box) {
      final side = min(box.maxWidth, box.maxHeight);
      final cell = side / n;
      return GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: n,
          mainAxisSpacing: 3,
          crossAxisSpacing: 3,
        ),
        itemCount: n * n,
        itemBuilder: (_, index) {
          final tile = tiles[index];
          final correct = tile == index;
          return GestureDetector(
            onTap: () => _tap(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected == index
                      ? DC.amber
                      : correct
                          ? DC.lime
                          : DC.fg12,
                  width: selected == index ? 3 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: CustomPaint(
                  painter: _DailyArtTilePainter(
                    seed: widget.seed,
                    piece: tile,
                    gridSize: n,
                    fullSize: Size.square(side),
                  ),
                  size: Size.square(cell),
                ),
              ),
            ),
          );
        },
      );
    });
  }
}

class _DailyArtTilePainter extends CustomPainter {
  final int seed;
  final int piece;
  final int gridSize;
  final Size fullSize;

  const _DailyArtTilePainter({
    required this.seed,
    required this.piece,
    required this.gridSize,
    required this.fullSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width * gridSize / fullSize.width;
    final offsetX = (piece % gridSize) * fullSize.width / gridSize;
    final offsetY = (piece ~/ gridSize) * fullSize.height / gridSize;
    canvas.scale(scale);
    canvas.translate(-offsetX, -offsetY);
    ArtPainter(seed, fullSize).paint(canvas, fullSize);
  }

  @override
  bool shouldRepaint(covariant _DailyArtTilePainter oldDelegate) =>
      oldDelegate.seed != seed ||
      oldDelegate.piece != piece ||
      oldDelegate.gridSize != gridSize ||
      oldDelegate.fullSize != fullSize;
}

class _DailyNumberPuzzle extends StatefulWidget {
  final int seed;
  final VoidCallback onSolved;

  const _DailyNumberPuzzle({
    super.key,
    required this.seed,
    required this.onSolved,
  });

  @override
  State<_DailyNumberPuzzle> createState() => _DailyNumberPuzzleState();
}

class _DailyNumberPuzzleState extends State<_DailyNumberPuzzle> {
  static const n = 5;
  late final List<int> tiles;
  int moves = 0;

  @override
  void initState() {
    super.initState();
    tiles = List.generate(n * n, (i) => (i + 1) % (n * n));
    final rng = Random(widget.seed);
    var blank = tiles.indexOf(0);
    var previous = -1;
    for (var i = 0; i < 150; i++) {
      final options = _neighbors(blank).where((e) => e != previous).toList();
      final next = options[rng.nextInt(options.length)];
      tiles[blank] = tiles[next];
      tiles[next] = 0;
      previous = blank;
      blank = next;
    }
  }

  Iterable<int> _neighbors(int index) sync* {
    final r = index ~/ n;
    final c = index % n;
    if (r > 0) yield index - n;
    if (r < n - 1) yield index + n;
    if (c > 0) yield index - 1;
    if (c < n - 1) yield index + 1;
  }

  void _tap(int index) {
    final blank = tiles.indexOf(0);
    if (!_neighbors(blank).contains(index)) return;
    setState(() {
      tiles[blank] = tiles[index];
      tiles[index] = 0;
      moves++;
    });
    if (_solved) widget.onSolved();
  }

  bool get _solved {
    for (var i = 0; i < tiles.length; i++) {
      if (tiles[i] != (i + 1) % tiles.length) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      Glass(
        child: Row(children: [
          Icon(Icons.swipe_rounded, color: DC.cyan),
          const SizedBox(width: 10),
          const Expanded(child: Text('Slide a tile into the empty space.')),
          Text('$moves moves',
              style: TextStyle(color: DC.dim, fontWeight: FontWeight.w700)),
        ]),
      ),
      const SizedBox(height: 14),
      AspectRatio(
        aspectRatio: 1,
        child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: n,
            mainAxisSpacing: 5,
            crossAxisSpacing: 5,
          ),
          itemCount: tiles.length,
          itemBuilder: (_, index) {
            final value = tiles[index];
            final correct = value != 0 && value == index + 1;
            return GestureDetector(
              onTap: value == 0 ? null : () => _tap(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: value == 0
                      ? DC.fgo(0.05)
                      : correct
                          ? DC.lime.withOpacity(0.22)
                          : DC.cyan.withOpacity(0.16),
                  border: Border.all(
                    color: value == 0
                        ? DC.fg10
                        : correct
                            ? DC.lime
                            : DC.cyan.withOpacity(0.5),
                  ),
                ),
                alignment: Alignment.center,
                child: value == 0
                    ? null
                    : Text(
                        '$value',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: correct ? DC.lime : DC.text,
                        ),
                      ),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

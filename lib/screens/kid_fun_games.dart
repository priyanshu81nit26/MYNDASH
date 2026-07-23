import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../core/fx.dart';
import '../core/state.dart';
import '../engine/kid_generators.dart';
import '../engine/question.dart';
import '../theme_district.dart';
import '../ui/extras.dart';
import '../ui/glass.dart';
import 'kid_arcade.dart';
import 'kid_rated_brain_games.dart';

/// ============================================================
/// MYNDASH KIDS — FUN GAMES 🎪
/// Non-arithmetic brain games: build, remember, know, connect.
///   🧱 Block Builder — copy (then memorise!) block patterns
///   🃏 Memory Match  — classic pairs, growing grids
///   📚 Almanac       — fun facts about the world
///   ➕ Cross Math    — crossword-style number crosses
/// 10 levels each · 2★ unlocks the next · rewards via kid economy.
/// ============================================================

class KidFunGame {
  final String id; // kidProgress topic id (or arcade high-score id)
  final String name;
  final String emoji;
  final Color color;
  final String tagline;
  final Widget Function(int level) builder;

  /// Arcade games are endless high-score runs — they skip the level
  /// picker and launch straight into the game.
  final bool arcade;

  /// Games with their own journey/map screen (e.g. Crossword Quest's
  /// 800→2500 rating bands) skip the generic level picker too.
  final Widget Function()? journey;

  /// Total playable levels shown on the hub card.
  final int maxLevel;
  const KidFunGame(
      this.id, this.name, this.emoji, this.color, this.tagline, this.builder,
      {this.arcade = false,
      this.journey,
      this.maxLevel = AppData.kidFunMaxLevel});
}

List<KidFunGame> get kidFunGames => [
      KidFunGame(
          'stack',
          'Sky Stack',
          '🏗️',
          DC.cyan,
          'drop the blocks · how high can you climb?',
          (l) => const StackGameScreen(),
          arcade: true),
      KidFunGame('dash', 'Cube Dash', '🚀', DC.magenta,
          'dodge the cubes · endless 3D run!', (l) => const DashGameScreen(),
          arcade: true),
      KidFunGame(
          'blocks',
          'Block Builder',
          '🧱',
          DC.amber,
          'copy the pattern · then from memory!',
          (l) => BlockBuilderScreen(level: l)),
      KidFunGame(
          'memory',
          'Memory Match',
          '🃏',
          DC.magenta,
          'find the pairs · fewest flips wins',
          (l) => MemoryMatchScreen(level: l)),
      KidFunGame(
          'almanac',
          'Almanac',
          '📚',
          DC.cyan,
          'amazing facts · animals, space & world',
          (l) => AlmanacScreen(level: l)),
      KidFunGame(
          'kidcrossmath',
          'Cross Math',
          '➕',
          DC.lime,
          'number crosswords · fill the crossing',
          (l) => const SizedBox.shrink(),
          journey: () => KidRatedJourney(
                gameId: 'kidcrossmath',
                title: 'CROSS MATH',
                subtitle: 'Complete a six-equation arithmetic crossword.',
                accent: DC.lime,
                icon: Icons.calculate_rounded,
                builder: (step, rating, seed) => KidCrossMathLevel(
                  step: step,
                  rating: rating,
                  seed: seed,
                ),
              ),
          maxLevel: kidRatedSteps),
      KidFunGame('kidword', 'Word Hunt', '🧩', DC.violet,
          '3D word puzzles · climb 800 → 2500!', (l) => const SizedBox.shrink(),
          journey: () => KidRatedJourney(
                gameId: 'kidword',
                title: 'WORD HUNT',
                subtitle: 'Make any real word from touching letters.',
                accent: DC.violet,
                icon: Icons.abc_rounded,
                builder: (step, rating, seed) => KidWordHuntLevel(
                  step: step,
                  rating: rating,
                  seed: seed,
                ),
              ),
          maxLevel: kidRatedSteps),
      KidFunGame(
          'kidsudoku6',
          'Sudoku Light',
          '6x6',
          DC.cyan,
          'kid-sized 6x6 logic · ratings 800-2500',
          (l) => const SizedBox.shrink(),
          journey: () => KidRatedJourney(
                gameId: 'kidsudoku6',
                title: 'SUDOKU LIGHT 6x6',
                subtitle: 'Use 1-6 once in every row, column, and 2x3 box.',
                accent: DC.cyan,
                icon: Icons.grid_4x4_rounded,
                builder: (step, rating, seed) => KidSudokuLightLevel(
                  step: step,
                  rating: rating,
                  seed: seed,
                ),
              ),
          maxLevel: kidRatedSteps),
      KidFunGame('kidkenken', 'KenKen', '123', DC.amber,
          'rows, columns and arithmetic cages', (l) => const SizedBox.shrink(),
          journey: () => KidRatedJourney(
                gameId: 'kidkenken',
                title: 'KENKEN',
                subtitle: 'Solve Latin-square rows and arithmetic cages.',
                accent: DC.amber,
                icon: Icons.functions_rounded,
                builder: (step, rating, seed) => KidKenKenLevel(
                  step: step,
                  rating: rating,
                  seed: seed,
                ),
              ),
          maxLevel: kidRatedSteps),
    ];

/// ---------------- shared level picker ----------------
class KidFunLevelScreen extends StatefulWidget {
  final KidFunGame game;
  const KidFunLevelScreen({super.key, required this.game});

  @override
  State<KidFunLevelScreen> createState() => _KidFunLevelScreenState();
}

class _KidFunLevelScreenState extends State<KidFunLevelScreen> {
  @override
  Widget build(BuildContext context) {
    final g = widget.game;
    final unlocked = AppData.i.kidLevel(g.id);
    return Scaffold(
      body: ShaderBackground(
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Glass(
                    radius: 16,
                    padding: const EdgeInsets.all(8),
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back, size: 18)),
                const SizedBox(width: 12),
                Text('${g.emoji}  ${g.name}',
                    style: Theme.of(context).textTheme.titleLarge),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Glass(
                padding: const EdgeInsets.all(12),
                child: Text(g.tagline,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: DC.dim)),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10),
                itemCount: AppData.kidFunMaxLevel,
                itemBuilder: (context, i) {
                  final level = i + 1;
                  final open = level <= unlocked;
                  return Press3D(
                    onTap: open
                        ? () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => g.builder(level)))
                            .then((_) => setState(() {}))
                        : null,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: open ? g.color.withOpacity(0.18) : DC.fgo(0.03),
                        border: Border.all(color: open ? g.color : DC.fg12),
                      ),
                      child: Center(
                        child: Text(open ? '$level' : '🔒',
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: open ? DC.text : DC.fg38)),
                      ),
                    ),
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// ---------------- shared result dialog ----------------
void showKidFunResult(
    BuildContext context, String topic, int level, int stars, String detail) {
  AppData.i.recordKidLevel(topic, level, stars, max: AppData.kidFunMaxLevel);
  if (stars >= 2) {
    Fx.win();
  } else {
    Fx.lose();
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
          if (stars >= 2) const ConfettiBurst(height: 60),
          Text(['💪', '🙂', '🌟', '🏆'][stars],
              style: const TextStyle(fontSize: 44)),
          const SizedBox(height: 8),
          Text(
              stars >= 2
                  ? 'AMAZING!'
                  : stars == 1
                      ? 'GOOD TRY!'
                      : 'KEEP GOING!',
              style: Theme.of(context).textTheme.displayMedium),
          Text(detail, style: TextStyle(color: DC.dim)),
          const SizedBox(height: 6),
          Row(mainAxisSize: MainAxisSize.min, children: [
            for (var i = 0; i < 3; i++)
              Icon(Icons.star_rounded,
                  size: 30, color: i < stars ? DC.amber : DC.fg24),
          ]),
          if (stars >= 2 && level < AppData.kidFunMaxLevel)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Level ${level + 1} unlocked! 🎉',
                  style:
                      TextStyle(color: DC.lime, fontWeight: FontWeight.w800)),
            ),
          const SizedBox(height: 14),
          NeonButton(
              label: 'DONE',
              height: 46,
              onPressed: () {
                Navigator.pop(context); // dialog
                Navigator.pop(context); // game
              }),
        ]),
      ),
    ),
  );
}

Widget kidGameHeader(BuildContext context, String title, {String? right}) {
  return Row(children: [
    Glass(
        radius: 16,
        padding: const EdgeInsets.all(8),
        onTap: () => Navigator.pop(context),
        child: const Icon(Icons.close, size: 18)),
    const SizedBox(width: 12),
    Expanded(
      child: Text(title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleLarge),
    ),
    if (right != null)
      Text(right, style: TextStyle(fontSize: 12, color: DC.dim)),
  ]);
}

/// ============================================================
/// 🧱 BLOCK BUILDER — rebuild the block pattern. From level 6 the
/// blueprint hides after a preview: build it from memory (peeks
/// allowed, but they cost stars).
/// ============================================================
class BlockBuilderScreen extends StatefulWidget {
  final int level;
  const BlockBuilderScreen({super.key, required this.level});

  @override
  State<BlockBuilderScreen> createState() => _BlockBuilderScreenState();
}

class _BlockBuilderScreenState extends State<BlockBuilderScreen> {
  // 100-level curve, tougher: bigger grids, more colours, memory sooner.
  late final int grid = (3 + ((widget.level - 1) ~/ 11)).clamp(3, 9);
  late final int nColors = (3 + ((widget.level - 1) ~/ 15)).clamp(3, 6);
  late final bool memoryMode = widget.level >= 3;
  late final Random rng = Random(widget.level * 7919 ^ 0xB10C);

  late final List<int> target; // -1 empty, else color index
  late List<int> board;
  int picked = 0; // selected palette color, nColors == eraser
  bool blueprintVisible = true;
  int peeks = 0;
  bool done = false;

  List<Color> get palette =>
      [DC.amber, DC.cyan, DC.magenta, DC.lime].take(nColors).toList();

  @override
  void initState() {
    super.initState();
    target = List.generate(grid * grid,
        (_) => rng.nextDouble() < 0.72 ? rng.nextInt(nColors) : -1);
    board = List.filled(grid * grid, -1);
    if (memoryMode) {
      // blueprint shows for a few seconds, then hides
      Timer(const Duration(seconds: 5), () {
        if (mounted) setState(() => blueprintVisible = false);
      });
    }
  }

  void _check() {
    if (done) return;
    var wrong = 0;
    for (var i = 0; i < target.length; i++) {
      if (board[i] != target[i]) wrong++;
    }
    if (wrong == 0 || !memoryMode) {
      done = true;
      var stars = wrong == 0 ? 3 : (wrong <= 2 ? 2 : (wrong <= grid ? 1 : 0));
      if (memoryMode && peeks > 2 && stars > 2) stars = 2;
      showKidFunResult(context, 'blocks', widget.level, stars,
          wrong == 0 ? 'Perfect build!' : '$wrong block(s) off');
    } else {
      // memory mode: tell how many are wrong, let them fix it
      Fx.fail();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          duration: const Duration(milliseconds: 900),
          content: Text('$wrong block(s) wrong — keep fixing! 🧱')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ShaderBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              kidGameHeader(context, '🧱 Block Builder · Lv ${widget.level}',
                  right: memoryMode ? 'MEMORY MODE 🧠' : 'COPY MODE'),
              const SizedBox(height: 12),
              // ---- blueprint ----
              Glass(
                padding: const EdgeInsets.all(10),
                child: Column(children: [
                  Text(
                      memoryMode
                          ? (blueprintVisible
                              ? 'MEMORISE THE BLUEPRINT…'
                              : 'BLUEPRINT HIDDEN — build from memory!')
                          : 'COPY THIS BLUEPRINT',
                      style: TextStyle(
                          fontSize: 10, letterSpacing: 1.5, color: DC.dim)),
                  const SizedBox(height: 8),
                  blueprintVisible
                      ? _grid(target, small: true)
                      : GhostButton(
                          label: 'PEEK 👀 ($peeks used)',
                          height: 40,
                          onPressed: () {
                            setState(() {
                              peeks++;
                              blueprintVisible = true;
                            });
                            Timer(const Duration(seconds: 2), () {
                              if (mounted) {
                                setState(() => blueprintVisible = false);
                              }
                            });
                          }),
                ]),
              ),
              const SizedBox(height: 12),
              // ---- your build ----
              Expanded(child: Center(child: _grid(board, small: false))),
              const SizedBox(height: 10),
              // ---- palette ----
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var c = 0; c < nColors; c++) _swatch(c, palette[c]),
                  _swatch(nColors, Colors.transparent, eraser: true),
                ],
              ),
              const SizedBox(height: 12),
              NeonButton(
                  label: 'CHECK MY BUILD',
                  icon: Icons.fact_check,
                  onPressed: _check),
              const SizedBox(height: 6),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _swatch(int idx, Color color, {bool eraser = false}) {
    final selected = picked == idx;
    return Press3D(
      onTap: () => setState(() => picked = idx),
      child: Container(
        width: 44,
        height: 44,
        margin: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: eraser ? DC.fgo(0.06) : color,
          border: Border.all(
              color: selected ? DC.text : DC.fg24, width: selected ? 3 : 1),
        ),
        child: eraser
            ? Icon(Icons.backspace_outlined, size: 18, color: DC.dim)
            : null,
      ),
    );
  }

  Widget _grid(List<int> cells, {required bool small}) {
    final side = small ? 26.0 : 52.0 - (grid - 3) * 6;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      for (var r = 0; r < grid; r++)
        Row(mainAxisSize: MainAxisSize.min, children: [
          for (var c = 0; c < grid; c++)
            GestureDetector(
              onTap: small
                  ? null
                  : () {
                      Fx.light();
                      setState(() => board[r * grid + c] =
                          picked >= nColors ? -1 : picked);
                    },
              child: Container(
                width: side,
                height: side,
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(small ? 5 : 10),
                  color: cells[r * grid + c] == -1
                      ? DC.fgo(0.05)
                      : palette[cells[r * grid + c]],
                  border: Border.all(color: DC.fg12),
                ),
              ),
            ),
        ]),
    ]);
  }
}

/// ============================================================
/// 🃏 MEMORY MATCH — flip two cards, find the pairs.
/// ============================================================
class MemoryMatchScreen extends StatefulWidget {
  final int level;
  const MemoryMatchScreen({super.key, required this.level});

  @override
  State<MemoryMatchScreen> createState() => _MemoryMatchScreenState();
}

class _MemoryMatchScreenState extends State<MemoryMatchScreen> {
  static const pool = [
    '🐶',
    '🐱',
    '🦊',
    '🐼',
    '🦁',
    '🐸',
    '🐙',
    '🦄',
    '🐢',
    '🍕',
    '🚀',
    '⚽',
    '🎈',
    '🌟',
    '🍩',
    '🦋',
  ];

  // 100-level curve: 4 pairs → 15 pairs (30 cards) for a real memory test.
  late final int pairs = (4 + ((widget.level - 1) ~/ 6)).clamp(4, 15);
  late final Random rng = Random(widget.level * 4409 ^ 0x3E3);
  late final List<String> cards;
  late List<bool> up; // face-up right now
  late List<bool> matched;
  int? firstPick;
  int moves = 0;
  bool busy = false;
  bool done = false;

  @override
  void initState() {
    super.initState();
    final chosen = List<String>.from(pool)..shuffle(rng);
    cards = [...chosen.take(pairs), ...chosen.take(pairs)]..shuffle(rng);
    up = List.filled(cards.length, false);
    matched = List.filled(cards.length, false);
  }

  void _flip(int i) {
    if (busy || done || up[i] || matched[i]) return;
    Fx.light();
    setState(() => up[i] = true);
    if (firstPick == null) {
      firstPick = i;
      return;
    }
    final a = firstPick!;
    firstPick = null;
    moves++;
    if (cards[a] == cards[i]) {
      Fx.success();
      matched[a] = true;
      matched[i] = true;
      if (matched.every((m) => m)) _finish();
      setState(() {});
    } else {
      busy = true;
      Timer(const Duration(milliseconds: 750), () {
        if (!mounted) return;
        setState(() {
          up[a] = false;
          up[i] = false;
          busy = false;
        });
      });
    }
  }

  void _finish() {
    done = true;
    final stars =
        moves <= pairs + 2 ? 3 : (moves <= (pairs * 2.2).round() ? 2 : 1);
    showKidFunResult(
        context, 'memory', widget.level, stars, 'All pairs in $moves moves');
  }

  @override
  Widget build(BuildContext context) {
    final cols = cards.length <= 12 ? 3 : 4;
    return Scaffold(
      body: ShaderBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              kidGameHeader(context, '🃏 Memory Match · Lv ${widget.level}',
                  right: 'moves $moves'),
              const SizedBox(height: 12),
              Expanded(
                child: Center(
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10),
                    itemCount: cards.length,
                    itemBuilder: (context, i) {
                      final show = up[i] || matched[i];
                      return Press3D(
                        onTap: show ? null : () => _flip(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            gradient: show
                                ? null
                                : LinearGradient(colors: [
                                    DC.violet.withOpacity(0.55),
                                    DC.magenta.withOpacity(0.4)
                                  ]),
                            color: show
                                ? (matched[i]
                                    ? DC.lime.withOpacity(0.18)
                                    : DC.fgo(0.08))
                                : null,
                            border: Border.all(
                                color: matched[i] ? DC.lime : DC.fg24),
                          ),
                          child: Center(
                            child: show
                                ? Text(cards[i],
                                    style: const TextStyle(fontSize: 30))
                                : const Text('❔',
                                    style: TextStyle(fontSize: 22)),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Text('fewest flips = more stars ⭐',
                  style: TextStyle(fontSize: 11, color: DC.dim)),
              const SizedBox(height: 8),
            ]),
          ),
        ),
      ),
    );
  }
}

/// ============================================================
/// 📚 ALMANAC — fun facts about animals, space, the body & world.
/// ============================================================
class _Fact {
  final int tier; // 1 easy → 3 tricky
  final String q;
  final List<String> options; // first is correct
  const _Fact(this.tier, this.q, this.options);
}

const List<_Fact> _facts = [
  // ---- tier 1 ----
  _Fact(1, 'Which animal is the tallest in the world?',
      ['Giraffe', 'Elephant', 'Horse', 'Camel']),
  _Fact(1, 'How many legs does a spider have?', ['8', '6', '10', '4']),
  _Fact(1, 'What do bees make?', ['Honey', 'Milk', 'Butter', 'Jam']),
  _Fact(
      1, 'Which planet do we live on?', ['Earth', 'Mars', 'Venus', 'Jupiter']),
  _Fact(1, 'What color do you get mixing blue and yellow?',
      ['Green', 'Purple', 'Orange', 'Pink']),
  _Fact(1, 'Which animal says "moo"?', ['Cow', 'Cat', 'Dog', 'Duck']),
  _Fact(1, 'How many days are in one week?', ['7', '5', '6', '10']),
  _Fact(1, 'What do caterpillars turn into?',
      ['Butterflies', 'Bees', 'Birds', 'Frogs']),
  _Fact(1, 'Which season is the coldest?',
      ['Winter', 'Summer', 'Spring', 'Autumn']),
  _Fact(1, 'What is the biggest animal in the ocean?',
      ['Blue whale', 'Shark', 'Dolphin', 'Octopus']),
  _Fact(1, 'Which fruit do monkeys love in cartoons?',
      ['Banana', 'Apple', 'Grape', 'Mango']),
  _Fact(1, 'What do you use to smell?', ['Nose', 'Ears', 'Eyes', 'Hands']),
  _Fact(1, 'Which bird cannot fly but runs super fast?',
      ['Ostrich', 'Eagle', 'Parrot', 'Owl']),
  _Fact(1, 'The Sun rises in the…', ['East', 'West', 'North', 'South']),
  _Fact(1, 'How many colors are in a rainbow?', ['7', '5', '6', '9']),
  // ---- tier 2 ----
  _Fact(2, 'Which planet is called the Red Planet?',
      ['Mars', 'Venus', 'Mercury', 'Saturn']),
  _Fact(2, 'What is the fastest land animal?',
      ['Cheetah', 'Lion', 'Horse', 'Kangaroo']),
  _Fact(2, 'How many bones does a shark have?',
      ['Zero — it\'s all cartilage!', '206', '50', '1000']),
  _Fact(2, 'Which is the largest country in the world?',
      ['Russia', 'China', 'USA', 'India']),
  _Fact(2, 'What gas do plants breathe in?',
      ['Carbon dioxide', 'Oxygen', 'Nitrogen', 'Helium']),
  _Fact(2, 'Which animal sleeps standing up?',
      ['Horse', 'Cat', 'Snake', 'Penguin']),
  _Fact(2, 'How many continents are there?', ['7', '5', '6', '8']),
  _Fact(2, 'The Great Wall is in which country?',
      ['China', 'Japan', 'India', 'Egypt']),
  _Fact(2, 'Which organ pumps blood around your body?',
      ['Heart', 'Brain', 'Lungs', 'Stomach']),
  _Fact(2, 'What is a baby kangaroo called?', ['Joey', 'Cub', 'Pup', 'Calf']),
  _Fact(2, 'Which is the longest river in the world?',
      ['Nile', 'Amazon', 'Ganga', 'Mississippi']),
  _Fact(2, 'Octopuses have how many hearts?', ['3', '1', '2', '5']),
  _Fact(2, 'Which planet has beautiful rings?',
      ['Saturn', 'Mars', 'Earth', 'Mercury']),
  _Fact(2, 'What is the hottest desert in the world?',
      ['Sahara', 'Gobi', 'Thar', 'Atacama']),
  _Fact(2, 'Penguins live mostly near which pole?',
      ['South Pole', 'North Pole', 'Equator', 'Everywhere']),
  // ---- tier 3 ----
  _Fact(3, 'What is the smallest planet in our solar system?',
      ['Mercury', 'Mars', 'Pluto', 'Venus']),
  _Fact(3, 'How long does light from the Sun take to reach Earth?',
      ['About 8 minutes', '8 seconds', '8 hours', '8 days']),
  _Fact(3, 'Which animal has the best memory in the animal kingdom?',
      ['Elephant', 'Goldfish', 'Rabbit', 'Pigeon']),
  _Fact(3, 'What is the largest organ of the human body?',
      ['Skin', 'Liver', 'Brain', 'Heart']),
  _Fact(3, 'Mount Everest sits between Nepal and…',
      ['China (Tibet)', 'India', 'Bhutan', 'Pakistan']),
  _Fact(3, 'Which sea creature can regrow lost arms?',
      ['Starfish', 'Crab', 'Seahorse', 'Jellyfish']),
  _Fact(3, 'What are baby frogs called?',
      ['Tadpoles', 'Froglings', 'Minnows', 'Larvae']),
  _Fact(3, 'Which metal is liquid at room temperature?',
      ['Mercury', 'Iron', 'Gold', 'Silver']),
  _Fact(3, 'The fastest bird in a dive is the…',
      ['Peregrine falcon', 'Eagle', 'Hawk', 'Swift']),
  _Fact(
      3, 'How many teeth does an adult human have?', ['32', '28', '36', '24']),
  _Fact(3, 'Which country invented paper?',
      ['China', 'Egypt', 'Greece', 'India']),
  _Fact(3, 'A group of lions is called a…', ['Pride', 'Pack', 'Herd', 'Flock']),
  _Fact(3, 'Which planet spins on its side?',
      ['Uranus', 'Neptune', 'Venus', 'Jupiter']),
  _Fact(3, 'What is the only mammal that can truly fly?',
      ['Bat', 'Flying squirrel', 'Sugar glider', 'Ostrich']),
  _Fact(
      3, 'Sound travels fastest through…', ['Solids', 'Air', 'Water', 'Space']),
];

class AlmanacScreen extends StatefulWidget {
  final int level;
  const AlmanacScreen({super.key, required this.level});

  @override
  State<AlmanacScreen> createState() => _AlmanacScreenState();
}

class _AlmanacScreenState extends State<AlmanacScreen> {
  // 100-level curve: longer sets (5→15 questions) and harder fact tiers.
  late final int total = (5 + ((widget.level - 1) ~/ 10)).clamp(5, 15);
  late final int tier = (1 + ((widget.level - 1) ~/ 33)).clamp(1, 3);
  late final Random rng = Random(widget.level * 2861 ^ 0xA1);
  late final List<_Fact> session;
  late List<List<String>> shuffled; // options per question, shuffled
  int index = 0;
  int correct = 0;
  bool answered = false;
  bool right = false;
  bool done = false;

  @override
  void initState() {
    super.initState();
    final bank = _facts.where((f) => f.tier == tier).toList()..shuffle(rng);
    session = bank.take(total).toList();
    shuffled = [
      for (final f in session) (List<String>.from(f.options)..shuffle(rng))
    ];
  }

  void _answer(String o) {
    if (answered || done) return;
    answered = true;
    right = o == session[index].options.first;
    if (right) {
      correct++;
      Fx.success();
    } else {
      Fx.fail();
    }
    setState(() {});
    Timer(Duration(milliseconds: right ? 700 : 1600), () {
      if (!mounted) return;
      if (index + 1 >= total) {
        done = true;
        final stars =
            correct >= 6 ? 3 : (correct >= 5 ? 2 : (correct >= 4 ? 1 : 0));
        showKidFunResult(context, 'almanac', widget.level, stars,
            '$correct / $total facts known');
      } else {
        setState(() {
          index++;
          answered = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final f = session[index];
    return Scaffold(
      body: ShaderBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              kidGameHeader(context, '📚 Almanac · Lv ${widget.level}',
                  right: '${index + 1}/$total · ✓$correct'),
              const Spacer(),
              Glass(
                radius: 24,
                padding: const EdgeInsets.all(22),
                border: answered
                    ? Border.all(color: right ? DC.lime : DC.danger, width: 2)
                    : null,
                child: Column(children: [
                  Text(f.q,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          height: 1.5)),
                  if (answered && !right)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text('Answer: ${f.options.first}',
                          style: TextStyle(
                              color: DC.lime, fontWeight: FontWeight.w800)),
                    ),
                ]),
              ),
              const SizedBox(height: 18),
              for (final o in shuffled[index])
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GhostButton(
                      label: o,
                      height: 48,
                      onPressed: answered ? null : () => _answer(o)),
                ),
              const Spacer(flex: 2),
            ]),
          ),
        ),
      ),
    );
  }
}

/// ============================================================
/// ➕ CROSS MATH — a number crossword: the row equation and the
/// column equation share the centre cell. Fill the blanks!
///
///          [A]
///           op2
///   [B] op1 [C] = [D]
///           =
///          [E]
/// Row:  B op1 C = D      Column: A op2 C = E
/// ============================================================
class CrossMathScreen extends StatefulWidget {
  final int level;
  const CrossMathScreen({super.key, required this.level});

  @override
  State<CrossMathScreen> createState() => _CrossMathScreenState();
}

class _CrossMathScreenState extends State<CrossMathScreen> {
  static const rounds = 5;
  late final Random rng = Random(widget.level * 6199 ^ 0xC805);
  int round = 0;
  int mistakes = 0;
  bool done = false;

  // puzzle cells: A,B,C,D,E — values + which are blanks
  late List<int> vals; // [A,B,C,D,E]
  late String op1, op2;
  late Set<int> blanks; // indices into vals
  late Map<int, int?> filled; // blank index -> player value
  int? activeBlank;
  late List<int> chips;

  @override
  void initState() {
    super.initState();
    _newPuzzle();
  }

  void _newPuzzle() {
    final lv = widget.level;
    // 100-level curve, tougher: operators arrive sooner, numbers grow.
    final ops = lv <= 2
        ? ['+']
        : lv <= 4
            ? ['+', '−']
            : ['+', '−', '×'];
    op1 = ops[rng.nextInt(ops.length)];
    op2 = ops[rng.nextInt(ops.length)];
    final hasMul = op1 == '×' || op2 == '×';
    final hi = hasMul
        ? (7 + (lv - 1) ~/ 12).clamp(7, 12)
        : (9 + (lv - 1) ~/ 8).clamp(9, 20);
    int apply(String op, int x, int y) =>
        op == '+' ? x + y : (op == '−' ? x - y : x * y);
    // pick operands so subtraction never goes negative
    int c = 1 + rng.nextInt(op1 == '×' || op2 == '×' ? 8 : hi - 1);
    int b = op1 == '−' ? c + rng.nextInt(hi - 1) + 0 : 1 + rng.nextInt(hi);
    int a = op2 == '−' ? c + rng.nextInt(hi - 1) + 0 : 1 + rng.nextInt(hi);
    if (op1 == '−' && b < c) b = c + rng.nextInt(5);
    if (op2 == '−' && a < c) a = c + rng.nextInt(5);
    final d = apply(op1, b, c);
    final e = apply(op2, a, c);
    vals = [a, b, c, d, e];
    final nBlanks = lv < 3 ? 1 : (lv < 6 ? 2 : (lv < 14 ? 3 : 4));
    final idxs = [0, 1, 2, 3, 4]..shuffle(rng);
    blanks = idxs.take(nBlanks).toSet();
    filled = {for (final i in blanks) i: null};
    activeBlank = blanks.first;
    // chips: correct answers + decoys
    final set = <int>{for (final i in blanks) vals[i]};
    while (set.length < 8) {
      set.add(max(0, vals[blanks.first] + rng.nextInt(9) - 4 + set.length));
    }
    chips = set.toList()..shuffle(rng);
    setState(() {});
  }

  void _place(int v) {
    if (activeBlank == null || done) return;
    Fx.light();
    setState(() {
      filled[activeBlank!] = v;
      // move focus to the next empty blank
      final empty = blanks.where((b) => filled[b] == null).toList();
      activeBlank = empty.isEmpty ? activeBlank : empty.first;
    });
    if (filled.values.every((v) => v != null)) _check();
  }

  void _check() {
    final ok = blanks.every((i) => filled[i] == vals[i]);
    if (ok) {
      Fx.success();
      round++;
      if (round >= rounds) {
        done = true;
        final stars =
            mistakes == 0 ? 3 : (mistakes <= 2 ? 2 : (mistakes <= 5 ? 1 : 0));
        showKidFunResult(context, 'crossmath', widget.level, stars,
            '$rounds crossings solved · $mistakes slip(s)');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            duration: Duration(milliseconds: 700),
            content: Text('Solved! Next crossing → 🎉')));
        _newPuzzle();
      }
    } else {
      mistakes++;
      Fx.fail();
      setState(() {
        for (final i in blanks) {
          if (filled[i] != vals[i]) filled[i] = null;
        }
        activeBlank = blanks.firstWhere((b) => filled[b] == null);
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          duration: Duration(milliseconds: 800),
          content: Text('Not quite — the wrong ones popped out! 🔍')));
    }
  }

  Widget _cell(int i, {bool label = false, String? text}) {
    if (label) {
      return SizedBox(
        width: 48,
        height: 48,
        child: Center(
            child: Text(text!,
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w900, color: DC.dim))),
      );
    }
    final isBlank = blanks.contains(i);
    final v = isBlank ? filled[i] : vals[i];
    final active = isBlank && activeBlank == i;
    return Press3D(
      onTap: isBlank ? () => setState(() => activeBlank = i) : null,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isBlank
              ? (active ? DC.lime.withOpacity(0.18) : DC.fgo(0.06))
              : DC.fgo(0.10),
          border: Border.all(
              color: active ? DC.lime : (isBlank ? DC.amber : DC.fg24),
              width: active ? 2.5 : 1.2),
        ),
        child: Center(
          child: Text(v == null ? '?' : '$v',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: v == null ? DC.amber : DC.text)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(width: 4);
    return Scaffold(
      body: ShaderBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              kidGameHeader(context, '➕ Cross Math · Lv ${widget.level}',
                  right: 'cross ${round + 1}/$rounds'),
              const Spacer(),
              Glass(
                padding: const EdgeInsets.all(18),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  // A
                  Row(mainAxisSize: MainAxisSize.min, children: [_cell(0)]),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    _cell(-1, label: true, text: op2),
                  ]),
                  // B op1 C = D
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    _cell(1),
                    gap,
                    _cell(-1, label: true, text: op1),
                    gap,
                    _cell(2),
                    gap,
                    _cell(-1, label: true, text: '='),
                    gap,
                    _cell(3),
                  ]),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    _cell(-1, label: true, text: '='),
                  ]),
                  // E
                  Row(mainAxisSize: MainAxisSize.min, children: [_cell(4)]),
                ]),
              ),
              const SizedBox(height: 8),
              Text('row and column cross at the middle number',
                  style: TextStyle(fontSize: 11, color: DC.dim)),
              const Spacer(),
              // number chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (final v in chips)
                    Press3D(
                      onTap: () => _place(v),
                      child: Container(
                        width: 52,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: LinearGradient(colors: [
                            DC.lime.withOpacity(0.30),
                            DC.cyan.withOpacity(0.22)
                          ]),
                          border: Border.all(color: DC.fg24),
                        ),
                        child: Center(
                            child: Text('$v',
                                style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900))),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
            ]),
          ),
        ),
      ),
    );
  }
}

/// ============================================================
/// 🔥 KIDS DAILY 5 — five questions from your topics, one a time,
/// rising difficulty. Finishing all 5 keeps the streak alive
/// (same streak & coin engine as the big app).
/// ============================================================
class KidDaily5Screen extends StatefulWidget {
  const KidDaily5Screen({super.key});

  @override
  State<KidDaily5Screen> createState() => _KidDaily5State();
}

class _KidDaily5State extends State<KidDaily5Screen> {
  Question? q;
  bool answered = false;
  bool right = false;

  int get progress => AppData.i.dailyMathProgress;

  void _load() {
    final a = AppData.i;
    if (progress >= 5) {
      q = null;
      return;
    }
    final topics = kidTopicsFor(a.age == 0 ? 10 : a.age);
    final dayHash = AppData.todayKey().hashCode;
    final t = topics[(dayHash + progress) % topics.length];
    final lv = (progress * 2 + 1).clamp(1, 10);
    q = generateKid(t.id, lv, Random(dayHash ^ (progress * 373)));
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _answer(String o) {
    if (answered || q == null) return;
    answered = true;
    right = q!.check(o);
    if (right) {
      Fx.success();
      AppData.i.recordDailySolve(progress);
    } else {
      Fx.fail();
    }
    setState(() {});
    Timer(Duration(milliseconds: right ? 900 : 1600), () {
      if (!mounted) return;
      setState(() {
        answered = false;
        _load();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final a = AppData.i;
    final doneAll = progress >= 5;
    return Scaffold(
      body: ShaderBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              kidGameHeader(context, '🔥 Daily 5',
                  right: 'streak ${a.streak} 🔥'),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 5; i++)
                    Container(
                      width: 40,
                      height: 40,
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < progress
                            ? DC.lime.withOpacity(0.25)
                            : DC.fgo(0.05),
                        border: Border.all(
                            color: i < progress
                                ? DC.lime
                                : (i == progress ? DC.amber : DC.fg24),
                            width: i == progress ? 2.5 : 1.2),
                      ),
                      child: Center(
                          child: Text(i < progress ? '✓' : '${i + 1}',
                              style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: i < progress ? DC.lime : DC.text))),
                    ),
                ],
              ),
              const Spacer(),
              if (doneAll) ...[
                const Text('🎉', style: TextStyle(fontSize: 60)),
                const SizedBox(height: 10),
                Text('All 5 done — streak safe!',
                    style: Theme.of(context).textTheme.titleLarge),
                Text('come back tomorrow for 5 new ones',
                    style: TextStyle(fontSize: 12, color: DC.dim)),
              ] else if (q != null) ...[
                Glass(
                  radius: 24,
                  padding: const EdgeInsets.all(22),
                  border: answered
                      ? Border.all(color: right ? DC.lime : DC.danger, width: 2)
                      : null,
                  child: Column(children: [
                    Text(q!.prompt,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            height: 1.5)),
                    if (answered && !right)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                            'Answer: ${q!.answer} — try this one again!',
                            style: TextStyle(
                                color: DC.lime, fontWeight: FontWeight.w800)),
                      ),
                  ]),
                ),
                const SizedBox(height: 18),
                for (final o in q!.options ?? const <String>[])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GhostButton(
                        label: o,
                        height: 48,
                        onPressed: answered ? null : () => _answer(o)),
                  ),
              ],
              const Spacer(flex: 2),
            ]),
          ),
        ),
      ),
    );
  }
}

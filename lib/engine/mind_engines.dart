import 'dart:math';

/// ============================================================
/// MIND ENGINES — pure logic for the 5 mind-fun games:
/// Sudoku · Tower of Hanoi · Number Puzzle · Arrow Puzzle ·
/// Crossword. No Flutter imports — fully testable, seeded and
/// deterministic so online races share identical puzzles.
/// ============================================================

// ---------------------------------------------------------------
// SUDOKU
// ---------------------------------------------------------------
class SudokuPuzzle {
  final List<int> solution; // 81 cells, 1..9
  final List<int> given; // 81 cells, 0 = blank
  SudokuPuzzle(this.solution, this.given);

  int get blanks => given.where((v) => v == 0).length;
}

class SudokuEngine {
  /// Clue count for a practice level 1..50 (45 easy → 24 expert).
  static int cluesForLevel(int level) =>
      (46 - (level * 22 / 50)).round().clamp(24, 46).toInt();

  /// Deterministic puzzle for a seed. [clues] = how many givens remain.
  static SudokuPuzzle generate(int seed, int clues) {
    final rng = Random(seed);
    final grid = List<int>.filled(81, 0);
    _fill(grid, 0, rng);
    final solution = List<int>.from(grid);
    // dig holes, keeping the solution unique
    final order = List<int>.generate(81, (i) => i)..shuffle(rng);
    var remaining = 81;
    for (final cell in order) {
      if (remaining <= clues) break;
      final backup = grid[cell];
      grid[cell] = 0;
      if (_countSolutions(List<int>.from(grid), 2) == 1) {
        remaining--;
      } else {
        grid[cell] = backup; // digging here breaks uniqueness
      }
    }
    return SudokuPuzzle(solution, grid);
  }

  static bool _fill(List<int> g, int idx, Random rng) {
    if (idx == 81) return true;
    if (g[idx] != 0) return _fill(g, idx + 1, rng);
    final nums = List<int>.generate(9, (i) => i + 1)..shuffle(rng);
    for (final n in nums) {
      if (_ok(g, idx, n)) {
        g[idx] = n;
        if (_fill(g, idx + 1, rng)) return true;
        g[idx] = 0;
      }
    }
    return false;
  }

  static bool _ok(List<int> g, int idx, int n) {
    final r = idx ~/ 9, c = idx % 9;
    for (var i = 0; i < 9; i++) {
      if (g[r * 9 + i] == n || g[i * 9 + c] == n) return false;
    }
    final br = (r ~/ 3) * 3, bc = (c ~/ 3) * 3;
    for (var i = 0; i < 3; i++) {
      for (var j = 0; j < 3; j++) {
        if (g[(br + i) * 9 + bc + j] == n) return false;
      }
    }
    return true;
  }

  static int _countSolutions(List<int> g, int cap) {
    var count = 0;
    bool solve(int idx) {
      while (idx < 81 && g[idx] != 0) {
        idx++;
      }
      if (idx == 81) {
        count++;
        return count >= cap;
      }
      for (var n = 1; n <= 9; n++) {
        if (_ok(g, idx, n)) {
          g[idx] = n;
          if (solve(idx + 1)) {
            g[idx] = 0;
            return true;
          }
          g[idx] = 0;
        }
      }
      return false;
    }

    solve(0);
    return count;
  }

  /// Cells that conflict with [idx] holding value [v] (row/col/box).
  static bool conflicts(List<int> g, int idx, int v) {
    if (v == 0) return false;
    final r = idx ~/ 9, c = idx % 9;
    for (var i = 0; i < 9; i++) {
      final ri = r * 9 + i, ci = i * 9 + c;
      if (ri != idx && g[ri] == v) return true;
      if (ci != idx && g[ci] == v) return true;
    }
    final br = (r ~/ 3) * 3, bc = (c ~/ 3) * 3;
    for (var i = 0; i < 3; i++) {
      for (var j = 0; j < 3; j++) {
        final bi = (br + i) * 9 + bc + j;
        if (bi != idx && g[bi] == v) return true;
      }
    }
    return false;
  }
}

// ---------------------------------------------------------------
// TOWER OF HANOI — multi-peg (3/4/5 pegs) with Frame-Stewart
// optimal move counts. Discs numbered 1(small)..n(large).
// ---------------------------------------------------------------
class HanoiGame {
  final int discs;
  final int pegCount;
  // pegs[p] is a stack, last = top.
  final List<List<int>> pegs;
  int moves = 0;

  HanoiGame(this.discs, {this.pegCount = 3})
      : pegs = [
          List<int>.generate(discs, (i) => discs - i),
          for (var p = 1; p < pegCount; p++) <int>[],
        ];

  /// The goal peg is always the right-most one.
  int get target => pegCount - 1;

  int get minMoves => frameStewart(discs, pegCount);
  bool get solved => pegs[target].length == discs;

  int? topOf(int peg) => pegs[peg].isEmpty ? null : pegs[peg].last;

  bool canMove(int from, int to) {
    final d = topOf(from);
    if (d == null) return false;
    final t = topOf(to);
    return t == null || t > d;
  }

  bool move(int from, int to) {
    if (from == to || !canMove(from, to)) return false;
    pegs[to].add(pegs[from].removeLast());
    moves++;
    return true;
  }

  /// Solve progress 0..1 — largest discs settled on the target peg.
  double get progress {
    var settled = 0;
    for (var i = 0; i < pegs[target].length; i++) {
      if (pegs[target][i] == discs - i) {
        settled++;
      } else {
        break;
      }
    }
    return settled / discs;
  }

  static final Map<int, int> _fsMemo = {};

  /// Frame-Stewart minimum move count for [n] discs on [k] pegs
  /// (exact for 3 pegs, optimal FS values for 4-5 pegs).
  static int frameStewart(int n, int k) {
    if (n <= 0) return 0;
    if (n == 1) return 1;
    if (k <= 3) return (1 << n) - 1;
    final key = n * 100 + k;
    final cached = _fsMemo[key];
    if (cached != null) return cached;
    var best = 1 << 30;
    for (var t = 1; t < n; t++) {
      final v = 2 * frameStewart(t, k) + frameStewart(n - t, k - 1);
      if (v < best) best = v;
    }
    _fsMemo[key] = best;
    return best;
  }
}

/// A rings×pegs combination. The rated journey uses every pairing from
/// 3-8 rings and 3-5 pegs with five distinct move-budget variants.
class HanoiCombo {
  final int rings, pegCount, minMoves;
  HanoiCombo(this.rings, this.pegCount)
      : minMoves = HanoiGame.frameStewart(rings, pegCount);

  int budgetFor(int tier) => switch (tier.clamp(0, 4).toInt()) {
        0 => (minMoves * 1.8).ceil() + 3,
        1 => (minMoves * 1.55).ceil() + 2,
        2 => (minMoves * 1.3).ceil() + 1,
        3 => (minMoves * 1.14).ceil(),
        _ => minMoves,
      };

  /// Room/queue code for online play ('c43' = 4 rings, 3 pegs).
  String get sub => 'c$rings$pegCount';

  String get title => '$rings RINGS × $pegCount PEGS';

  /// All meaningful board layouts, easiest first.
  static final List<HanoiCombo> all = () {
    final list = <HanoiCombo>[
      for (var p = 3; p <= 5; p++)
        for (var r = 3; r <= 8; r++) HanoiCombo(r, p),
    ];
    list.sort((a, b) => a.minMoves != b.minMoves
        ? a.minMoves.compareTo(b.minMoves)
        : a.rings.compareTo(b.rings));
    return list;
  }();

  static final List<(HanoiCombo, int)> _ratedVariants = () {
    final variants = <(HanoiCombo, int)>[
      for (final combo in all)
        for (var tier = 0; tier < 5; tier++) (combo, tier),
    ];
    double score((HanoiCombo, int) entry) =>
        log(entry.$1.minMoves + 1) * 100 + entry.$2 * 18;
    variants.sort((a, b) {
      final byScore = score(a).compareTo(score(b));
      if (byScore != 0) return byScore;
      final byRings = a.$1.rings.compareTo(b.$1.rings);
      if (byRings != 0) return byRings;
      final byPegs = a.$1.pegCount.compareTo(b.$1.pegCount);
      if (byPegs != 0) return byPegs;
      return a.$2.compareTo(b.$2);
    });
    return variants;
  }();

  static int get levelCount => _ratedVariants.length; // 18 × 5 = 90

  /// Journey step (1-based) → a unique layout and budget combination.
  static (HanoiCombo, int) forLevel(int level) {
    final i = (level - 1).clamp(0, levelCount - 1).toInt();
    return _ratedVariants[i];
  }

  /// Parse a room sub code; null for 'std'/'rnd' (random-by-seed).
  static HanoiCombo? fromSub(String? sub) {
    if (sub == null || sub.length != 3 || !sub.startsWith('c')) return null;
    final r = int.tryParse(sub[1]), p = int.tryParse(sub[2]);
    if (r == null || p == null || r < 3 || r > 8 || p < 3 || p > 5) {
      return null;
    }
    return HanoiCombo(r, p);
  }

  /// Deterministic combo for a shared room seed.
  static HanoiCombo bySeed(int seed) => all[seed % all.length];
}

// ---------------------------------------------------------------
// NUMBER PUZZLE (sliding 15-puzzle family)
// ---------------------------------------------------------------
class SlidePuzzle {
  final int n; // board is n×n
  late List<int> cells; // 0 = blank, else tile number
  int moves = 0;

  SlidePuzzle(this.n, int seed, int scrambleDepth) {
    cells = List<int>.generate(n * n, (i) => (i + 1) % (n * n));
    // scramble with a random walk from solved → always solvable
    final rng = Random(seed);
    var last = -1;
    for (var k = 0; k < scrambleDepth; k++) {
      final blank = cells.indexOf(0);
      final opts = _neighbours(blank).where((i) => i != last).toList();
      final pick = opts[rng.nextInt(opts.length)];
      cells[blank] = cells[pick];
      cells[pick] = 0;
      last = blank;
    }
    moves = 0;
  }

  List<int> _neighbours(int i) {
    final r = i ~/ n, c = i % n;
    return [
      if (r > 0) i - n,
      if (r < n - 1) i + n,
      if (c > 0) i - 1,
      if (c < n - 1) i + 1,
    ];
  }

  /// Slides tile at [i] into the blank if adjacent. Returns true on move.
  bool tap(int i) {
    final blank = cells.indexOf(0);
    if (!_neighbours(blank).contains(i)) return false;
    cells[blank] = cells[i];
    cells[i] = 0;
    moves++;
    return true;
  }

  bool get solved {
    for (var i = 0; i < n * n - 1; i++) {
      if (cells[i] != i + 1) return false;
    }
    return true;
  }

  double get progress {
    var right = 0;
    for (var i = 0; i < n * n - 1; i++) {
      if (cells[i] == i + 1) right++;
    }
    return right / (n * n - 1);
  }

  static int sizeForLevel(int level) => level <= 15 ? 3 : (level <= 35 ? 4 : 5);

  static int depthForLevel(int level) {
    final within =
        level <= 15 ? level : (level <= 35 ? level - 15 : level - 35);
    final size = sizeForLevel(level);
    return (size * size * 2) + within * (size + 1);
  }
}

// ---------------------------------------------------------------
// ARROW PUZZLE — tap a tile: it and its orthogonal neighbours
// rotate 90° clockwise. Goal: every arrow points up.
// ---------------------------------------------------------------
class ArrowPuzzle {
  final int n;
  late List<int> dirs; // 0=up 1=right 2=down 3=left
  int taps = 0;

  ArrowPuzzle(this.n, int seed, int scrambleTaps) {
    dirs = List<int>.filled(n * n, 0);
    final rng = Random(seed);
    for (var k = 0; k < scrambleTaps; k++) {
      // scramble by REVERSE taps (counter-clockwise) so each player tap
      // visibly undoes the mess
      _rotate(rng.nextInt(n * n), -1);
    }
    if (solved) _rotate(rng.nextInt(n * n), -1); // never start solved
    taps = 0;
  }

  List<int> affected(int i) {
    final r = i ~/ n, c = i % n;
    return [
      i,
      if (r > 0) i - n,
      if (r < n - 1) i + n,
      if (c > 0) i - 1,
      if (c < n - 1) i + 1,
    ];
  }

  void _rotate(int i, int dir) {
    for (final j in affected(i)) {
      dirs[j] = (dirs[j] + dir + 4) % 4;
    }
  }

  void tap(int i) {
    _rotate(i, 1);
    taps++;
  }

  bool get solved => dirs.every((d) => d == 0);

  double get progress => dirs.where((d) => d == 0).length / (n * n);

  static int sizeForLevel(int level) {
    if (level <= 10) return 3;
    if (level <= 22) return 4;
    if (level <= 34) return 5;
    if (level <= 44) return 6;
    return 7;
  }

  static int scrambleForLevel(int level) => 2 + (level * 0.55).round();
}

// ---------------------------------------------------------------
// CROSSWORD — seeded generator over a curated word+clue bank.
// ---------------------------------------------------------------
class CrosswordWord {
  final String word;
  final String clue;
  const CrosswordWord(this.word, this.clue);
}

class PlacedWord {
  final String word;
  final String clue;
  final int row, col;
  final bool across;
  int number = 0;
  PlacedWord(this.word, this.clue, this.row, this.col, this.across);

  List<int> cellsIn(int n) => List<int>.generate(
      word.length, (i) => across ? row * n + col + i : (row + i) * n + col);
}

class Crossword {
  final int n;
  final List<PlacedWord> words;
  final List<String> solution; // '' = block, else letter
  Crossword(this.n, this.words, this.solution);

  int get letterCells => solution.where((s) => s.isNotEmpty).length;
}

class CrosswordGen {
  static const bank = <CrosswordWord>[
    CrosswordWord('CAT', 'Whiskered house pet'),
    CrosswordWord('DOG', 'Man\'s best friend'),
    CrosswordWord('SUN', 'Star of our sky'),
    CrosswordWord('MOON', 'Night-sky lamp'),
    CrosswordWord('STAR', 'Twinkler above'),
    CrosswordWord('TREE', 'It grows rings'),
    CrosswordWord('FISH', 'Swimmer with gills'),
    CrosswordWord('BIRD', 'Feathered flyer'),
    CrosswordWord('RAIN', 'Cloud tears'),
    CrosswordWord('SNOW', 'Winter white flakes'),
    CrosswordWord('WIND', 'Invisible mover of leaves'),
    CrosswordWord('FIRE', 'It needs oxygen to dance'),
    CrosswordWord('LAKE', 'Still inland water'),
    CrosswordWord('RIVER', 'It always runs downhill'),
    CrosswordWord('OCEAN', 'Pacific, for one'),
    CrosswordWord('CLOUD', 'Sky cotton'),
    CrosswordWord('STONE', 'Rock, plainly'),
    CrosswordWord('PLANT', 'Green grower'),
    CrosswordWord('HORSE', 'Gallops and neighs'),
    CrosswordWord('TIGER', 'Striped big cat'),
    CrosswordWord('ZEBRA', 'Striped horse cousin'),
    CrosswordWord('EAGLE', 'Sharp-eyed raptor'),
    CrosswordWord('SNAKE', 'Legless slitherer'),
    CrosswordWord('MOUSE', 'Cheese fan / PC pointer'),
    CrosswordWord('CAMEL', 'Desert ship'),
    CrosswordWord('WHALE', 'Largest animal ever'),
    CrosswordWord('SHARK', 'Fin above the waves'),
    CrosswordWord('PIANO', '88-key instrument'),
    CrosswordWord('GUITAR', 'Six-string strummer'),
    CrosswordWord('DRUM', 'You beat it'),
    CrosswordWord('MUSIC', 'Organised sound'),
    CrosswordWord('DANCE', 'Move to a beat'),
    CrosswordWord('PAINT', 'Artist\'s liquid colour'),
    CrosswordWord('BRUSH', 'Painter\'s tool'),
    CrosswordWord('PAPER', 'Origami material'),
    CrosswordWord('PENCIL', 'Eraser-topped writer'),
    CrosswordWord('BOOK', 'Pages between covers'),
    CrosswordWord('STORY', 'Once upon a time…'),
    CrosswordWord('POEM', 'Verse with rhythm'),
    CrosswordWord('CHESS', 'Game of kings'),
    CrosswordWord('QUEEN', 'Most powerful chess piece'),
    CrosswordWord('KNIGHT', 'Chess piece that jumps'),
    CrosswordWord('CASTLE', 'Fortress with towers'),
    CrosswordWord('CROWN', 'Royal headwear'),
    CrosswordWord('SWORD', 'Knight\'s blade'),
    CrosswordWord('SHIELD', 'Battle protector'),
    CrosswordWord('DRAGON', 'Fire-breathing legend'),
    CrosswordWord('WIZARD', 'Spell caster'),
    CrosswordWord('MAGIC', 'Abracadabra art'),
    CrosswordWord('APPLE', 'Fruit that fell on Newton'),
    CrosswordWord('MANGO', 'King of fruits'),
    CrosswordWord('LEMON', 'Sour yellow fruit'),
    CrosswordWord('GRAPE', 'Wine\'s beginning'),
    CrosswordWord('BREAD', 'Baker\'s basic'),
    CrosswordWord('HONEY', 'Bees make it'),
    CrosswordWord('SUGAR', 'Sweet crystals'),
    CrosswordWord('SPICE', 'Pepper or clove'),
    CrosswordWord('PIZZA', 'Cheesy Italian disc'),
    CrosswordWord('PASTA', 'Penne or fusilli'),
    CrosswordWord('RICE', 'Staple grain of Asia'),
    CrosswordWord('CURRY', 'Spiced Indian dish'),
    CrosswordWord('SALT', 'Sea seasoning'),
    CrosswordWord('WATER', 'H2O'),
    CrosswordWord('JUICE', 'Squeezed fruit drink'),
    CrosswordWord('COFFEE', 'Morning brew'),
    CrosswordWord('EARTH', 'Third rock from the sun'),
    CrosswordWord('MARS', 'The red planet'),
    CrosswordWord('VENUS', 'Hottest planet'),
    CrosswordWord('COMET', 'Icy space traveller with a tail'),
    CrosswordWord('ORBIT', 'Path around a planet'),
    CrosswordWord('ROCKET', 'It launches to space'),
    CrosswordWord('ROBOT', 'Mechanical helper'),
    CrosswordWord('LASER', 'Focused light beam'),
    CrosswordWord('ATOM', 'Matter\'s tiny unit'),
    CrosswordWord('ENERGY', 'Joules measure it'),
    CrosswordWord('LIGHT', 'Fastest thing there is'),
    CrosswordWord('SOUND', 'It travels in waves'),
    CrosswordWord('BRAIN', 'Thinking organ'),
    CrosswordWord('HEART', 'It beats for you'),
    CrosswordWord('SMILE', 'Curve that sets things straight'),
    CrosswordWord('DREAM', 'Sleep cinema'),
    CrosswordWord('SLEEP', 'Nightly recharge'),
    CrosswordWord('LAUGH', 'Ha-ha response'),
    CrosswordWord('FRIEND', 'Buddy, pal'),
    CrosswordWord('FAMILY', 'Your nearest and dearest'),
    CrosswordWord('SCHOOL', 'Place of lessons'),
    CrosswordWord('TEACHER', 'Classroom guide'),
    CrosswordWord('DOCTOR', 'Stethoscope wearer'),
    CrosswordWord('PILOT', 'Cockpit commander'),
    CrosswordWord('FARMER', 'Crop grower'),
    CrosswordWord('CHEF', 'Kitchen boss'),
    CrosswordWord('TRAIN', 'It runs on rails'),
    CrosswordWord('PLANE', 'Winged transport'),
    CrosswordWord('SHIP', 'Ocean vessel'),
    CrosswordWord('BRIDGE', 'River crosser'),
    CrosswordWord('TOWER', 'Eiffel, for one'),
    CrosswordWord('CITY', 'Urban sprawl'),
    CrosswordWord('VILLAGE', 'Small rural settlement'),
    CrosswordWord('ISLAND', 'Land ringed by water'),
    CrosswordWord('DESERT', 'Sahara, e.g.'),
    CrosswordWord('JUNGLE', 'Dense tropical forest'),
    CrosswordWord('MOUNTAIN', 'Everest is one'),
    CrosswordWord('VALLEY', 'Low land between hills'),
    CrosswordWord('CAVE', 'Bat\'s home'),
    CrosswordWord('BEACH', 'Sandy shore'),
    CrosswordWord('SUMMER', 'Hottest season'),
    CrosswordWord('WINTER', 'Coldest season'),
    CrosswordWord('SPRING', 'Season of blossoms'),
    CrosswordWord('AUTUMN', 'Season of falling leaves'),
    CrosswordWord('MORNING', 'Day\'s beginning'),
    CrosswordWord('NIGHT', 'When owls wake'),
    CrosswordWord('CLOCK', 'Tick-tock teller'),
    CrosswordWord('HOUR', 'Sixty minutes'),
    CrosswordWord('MINUTE', 'Sixty seconds'),
    CrosswordWord('YEAR', '365 days'),
    CrosswordWord('GOLD', 'Au on the table'),
    CrosswordWord('SILVER', 'Ag, second-place metal'),
    CrosswordWord('IRON', 'Fe — and a pressing tool'),
    CrosswordWord('DIAMOND', 'Hardest natural gem'),
    CrosswordWord('PEARL', 'Oyster\'s treasure'),
    CrosswordWord('OCTOPUS', 'Eight-armed sea genius'),
    CrosswordWord('PENGUIN', 'Tuxedoed non-flyer'),
    CrosswordWord('DOLPHIN', 'Clicking sea acrobat'),
    CrosswordWord('ELEPHANT', 'Trunk carrier'),
    CrosswordWord('GIRAFFE', 'Tallest land animal'),
    CrosswordWord('MONKEY', 'Banana-loving climber'),
    CrosswordWord('RABBIT', 'Hopping carrot fan'),
    CrosswordWord('TURTLE', 'Shell-backed slowpoke'),
    CrosswordWord('SPIDER', 'Eight-legged web maker'),
    CrosswordWord('HONEST', 'Truthful'),
    CrosswordWord('BRAVE', 'Fearless'),
    CrosswordWord('CLEVER', 'Quick-witted'),
    CrosswordWord('SILENT', 'Making no sound'),
    CrosswordWord('SHADOW', 'It follows you in sunlight'),
    CrosswordWord('MIRROR', 'It shows you yourself'),
    CrosswordWord('WINDOW', 'Wall\'s glass eye'),
    CrosswordWord('GARDEN', 'Backyard of blooms'),
    CrosswordWord('FLOWER', 'Bloom on a stem'),
    CrosswordWord('FOREST', 'Sea of trees'),
    CrosswordWord('THUNDER', 'Lightning\'s roar'),
    CrosswordWord('VOLCANO', 'Mountain that erupts'),
    CrosswordWord('GALAXY', 'Milky Way, e.g.'),
    CrosswordWord('PLANET', 'Earth or Mars'),
    CrosswordWord('OXYGEN', 'Gas we breathe'),
    CrosswordWord('PUZZLE', 'What you\'re solving now'),
    CrosswordWord('RIDDLE', 'Brain-teasing question'),
    CrosswordWord('SECRET', 'It\'s kept, not told'),
    CrosswordWord('TREASURE', 'X marks its spot'),
    CrosswordWord('JOURNEY', 'A long trip'),
    CrosswordWord('VICTORY', 'The win'),
  ];

  static int gridForLevel(int level) =>
      level <= 12 ? 7 : (level <= 28 ? 9 : 11);

  static int wordsForLevel(int level) =>
      (4 + level * 0.16 * gridForLevel(level) / 7).round().clamp(4, 14).toInt();

  /// Seeded crossword: places up to [target] bank words on an n×n grid so
  /// that every word after the first crosses an existing one. Pass [wordPool]
  /// to build from a custom bank (e.g. the kids' emoji words).
  static Crossword generate(int seed, int n, int target,
      {List<CrosswordWord>? wordPool}) {
    final rng = Random(seed);
    final grid = List<String>.filled(n * n, '');
    final placed = <PlacedWord>[];
    final pool = List<CrosswordWord>.from(
        (wordPool ?? bank).where((w) => w.word.length <= n))
      ..shuffle(rng);

    bool fits(String w, int r, int c, bool across) {
      if (across) {
        if (c < 0 || c + w.length > n || r < 0 || r >= n) return false;
        if (c > 0 && grid[r * n + c - 1].isNotEmpty) return false;
        if (c + w.length < n && grid[r * n + c + w.length].isNotEmpty) {
          return false;
        }
      } else {
        if (r < 0 || r + w.length > n || c < 0 || c >= n) return false;
        if (r > 0 && grid[(r - 1) * n + c].isNotEmpty) return false;
        if (r + w.length < n && grid[(r + w.length) * n + c].isNotEmpty) {
          return false;
        }
      }
      var crossesExisting = false;
      for (var i = 0; i < w.length; i++) {
        final rr = across ? r : r + i, cc = across ? c + i : c;
        final cell = grid[rr * n + cc];
        if (cell.isNotEmpty) {
          if (cell != w[i]) return false;
          crossesExisting = true;
        } else {
          // no touching parallel words: cells beside a fresh letter must be
          // empty in the perpendicular direction
          if (across) {
            if (rr > 0 && grid[(rr - 1) * n + cc].isNotEmpty) return false;
            if (rr < n - 1 && grid[(rr + 1) * n + cc].isNotEmpty) return false;
          } else {
            if (cc > 0 && grid[rr * n + cc - 1].isNotEmpty) return false;
            if (cc < n - 1 && grid[rr * n + cc + 1].isNotEmpty) return false;
          }
        }
      }
      return placed.isEmpty || crossesExisting;
    }

    void put(CrosswordWord cw, int r, int c, bool across) {
      for (var i = 0; i < cw.word.length; i++) {
        final rr = across ? r : r + i, cc = across ? c + i : c;
        grid[rr * n + cc] = cw.word[i];
      }
      placed.add(PlacedWord(cw.word, cw.clue, r, c, across));
    }

    // first word: horizontal, centred
    for (final cw in pool) {
      if (cw.word.length >= min(5, n - 2)) {
        put(cw, n ~/ 2, (n - cw.word.length) ~/ 2, true);
        pool.remove(cw);
        break;
      }
    }

    // remaining: try to cross an existing letter
    var guard = 0;
    while (placed.length < target && guard < 400 && pool.isNotEmpty) {
      guard++;
      final cw = pool[guard % pool.length];
      var done = false;
      for (final p in List<PlacedWord>.from(placed)..shuffle(rng)) {
        for (var pi = 0; pi < p.word.length && !done; pi++) {
          final li = cw.word.indexOf(p.word[pi]);
          if (li < 0) continue;
          final cr = p.across ? p.row : p.row + pi;
          final cc = p.across ? p.col + pi : p.col;
          final across = !p.across;
          final r = across ? cr : cr - li;
          final c = across ? cc - li : cc;
          if (fits(cw.word, r, c, across)) {
            put(cw, r, c, across);
            done = true;
          }
        }
        if (done) break;
      }
      if (done) pool.remove(cw);
    }

    // number the entries like a printed crossword (top-left order)
    placed.sort((a, b) => (a.row * n + a.col).compareTo(b.row * n + b.col));
    var num = 0;
    final numAt = <int, int>{};
    for (final p in placed) {
      final key = p.row * n + p.col;
      if (numAt.containsKey(key)) {
        p.number = numAt[key]!;
      } else {
        num++;
        numAt[key] = num;
        p.number = num;
      }
    }
    return Crossword(n, placed, grid);
  }
}

// ---------------------------------------------------------------
// SHARED DIFFICULTY / PAR TIMES
// ---------------------------------------------------------------
class MindDifficulty {
  /// Par solve time (seconds) for a game at a level — used for star ratings
  /// AND for how fast a bot of that level solves.
  static int parSeconds(String game, int level) {
    switch (game) {
      case 'sudoku':
        return 120 + level * 9; // 2 min → ~9.5 min of puzzle
      case 'hanoi':
        final (combo, _) = HanoiCombo.forLevel(level);
        return (combo.minMoves * 2.4).round() + 12;
      case 'numpz':
        final s = SlidePuzzle.sizeForLevel(level);
        return 25 + SlidePuzzle.depthForLevel(level) * (s - 1);
      case 'arrow':
        return 20 + ArrowPuzzle.scrambleForLevel(level) * 7;
      case 'crossword':
        return 60 + CrosswordGen.wordsForLevel(level) * 26;
      default:
        return 120;
    }
  }

  /// How long a bot of [botLevel] takes to solve, in seconds. Bots get
  /// SERIOUS from level 7 up — the forgiveness multiplier collapses fast.
  /// [parOverride] pins the puzzle's par (e.g. a chosen Hanoi combo) so the
  /// bot's speed reflects the actual board, scaled by its skill level.
  static int botSolveSeconds(String game, int botLevel, Random rng,
      {int? parOverride}) {
    final par = parOverride ?? parSeconds(game, botLevel);
    double factor;
    if (botLevel <= 3) {
      factor = 2.4 - botLevel * 0.2; // very chill
    } else if (botLevel <= 6) {
      factor = 1.8 - (botLevel - 3) * 0.15; // warming up
    } else {
      // serious mode: 1.25 at lvl 7 → ~0.55 at lvl 50
      factor = 1.25 - (botLevel - 7) * 0.016;
    }
    factor = factor.clamp(0.55, 2.4).toDouble();
    final jitter = 0.9 + rng.nextDouble() * 0.2;
    return (par * factor * jitter).round().clamp(10, 3600).toInt();
  }

  /// Stars for a practice solve: 3 = under par, 2 = under 1.8×par, 1 = solved.
  static int stars(String game, int level, int seconds) {
    final par = parSeconds(game, level);
    if (seconds <= par) return 3;
    if (seconds <= par * 1.8) return 2;
    return 1;
  }
}

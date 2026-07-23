import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../theme_district.dart';
import '../ui/game_tutorial.dart';
import '../ui/glass.dart';
import 'board_core.dart';

/// Level-0 "how to play" for Tower of Hanoi.
const hanoiTutorial = [
  TutorialStep('Tap a tower to lift its top disk.',
      gesture: TutorialGesture.tap),
  TutorialStep('Tap another tower to drop the disk there.',
      gesture: TutorialGesture.tap),
  TutorialStep('A bigger disk can never sit on a smaller one.',
      gesture: TutorialGesture.none),
  TutorialStep('Move the whole stack to the last tower to win!',
      gesture: TutorialGesture.none),
];

/// Level-0 "how to play" for Minesweeper.
const minesTutorial = [
  TutorialStep(
      'Tap a square to reveal it — the number shows how many mines touch it.',
      gesture: TutorialGesture.tap),
  TutorialStep('Long-press a square you think hides a mine to flag it 🚩.',
      gesture: TutorialGesture.tap),
  TutorialStep('Reveal every safe square without tapping a mine to win!',
      gesture: TutorialGesture.none),
];

/// Level-0 "how to play" for the Sliding Puzzle.
const slidingTutorial = [
  TutorialStep('Tap a tile next to the empty gap to slide it in.',
      gesture: TutorialGesture.tap),
  TutorialStep('Keep sliding until the tiles are back in order (1, 2, 3 …).',
      gesture: TutorialGesture.sequence),
  TutorialStep('Solve it in as few moves as you can!',
      gesture: TutorialGesture.none),
];

// ============================================================ MINESWEEPER

class MinesweeperBoard extends StatefulWidget {
  final int rating;
  final int seed;
  final BoardDone onDone;
  const MinesweeperBoard(
      {super.key,
      required this.rating,
      required this.seed,
      required this.onDone});

  @override
  State<MinesweeperBoard> createState() => _MinesweeperBoardState();
}

class _MinesweeperBoardState extends State<MinesweeperBoard> {
  late int n, mines;
  late List<bool> mine;
  late List<bool> open;
  late List<bool> flag;
  final int start = DateTime.now().millisecondsSinceEpoch;
  bool placed = false;
  bool done = false;
  late Random rng;

  @override
  void initState() {
    super.initState();
    rng = Random(widget.seed);
    n = widget.rating < 1300 ? 6 : (widget.rating < 1800 ? 8 : 10);
    mines = widget.rating < 1300 ? 5 : (widget.rating < 1800 ? 10 : 17);
    mine = List<bool>.filled(n * n, false);
    open = List<bool>.filled(n * n, false);
    flag = List<bool>.filled(n * n, false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        GameTutorial.showOnce(context,
            tutKey: 'mines', title: 'MINESWEEPER', steps: minesTutorial);
      }
    });
  }

  List<int> _nbrs(int i) {
    final r = i ~/ n, c = i % n;
    final out = <int>[];
    for (var dr = -1; dr <= 1; dr++) {
      for (var dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) continue;
        final rr = r + dr, cc = c + dc;
        if (rr >= 0 && rr < n && cc >= 0 && cc < n) out.add(rr * n + cc);
      }
    }
    return out;
  }

  int _count(int i) => _nbrs(i).where((j) => mine[j]).length;

  void _placeMines(int safe) {
    final banned = {safe, ..._nbrs(safe)};
    var left = mines;
    while (left > 0) {
      final i = rng.nextInt(n * n);
      if (mine[i] || banned.contains(i)) continue;
      mine[i] = true;
      left--;
    }
    placed = true;
  }

  void _reveal(int i) {
    if (done || open[i] || flag[i]) return;
    if (!placed) _placeMines(i);
    if (mine[i]) {
      setState(() => open[i] = true);
      _finish(false);
      return;
    }
    final stack = [i];
    while (stack.isNotEmpty) {
      final j = stack.removeLast();
      if (open[j] || flag[j]) continue;
      open[j] = true;
      if (_count(j) == 0 && !mine[j]) {
        stack.addAll(_nbrs(j).where((k) => !open[k] && !mine[k]));
      }
    }
    setState(() {});
    if (open.where((o) => o).length == n * n - mines) _finish(true);
  }

  void _toggleFlag(int i) {
    if (done || open[i]) return;
    setState(() => flag[i] = !flag[i]);
  }

  void _hint() {
    if (done || !chargeHint(context)) return;
    if (!placed) {
      _reveal(rng.nextInt(n * n));
      return;
    }
    final safe = [
      for (var i = 0; i < n * n; i++)
        if (!mine[i] && !open[i]) i
    ];
    if (safe.isNotEmpty) _reveal(safe[rng.nextInt(safe.length)]);
  }

  void _finish(bool won) {
    if (done) return;
    done = true;
    widget.onDone(BoardResult(won: won, timeMs: elapsedSince(start)));
  }

  static List<Color> get _numColors => [
        DC.dim,
        DC.cyan,
        DC.lime,
        DC.amber,
        DC.magenta,
        DC.danger,
        DC.violet,
        DC.text,
        DC.text,
      ];

  @override
  Widget build(BuildContext context) {
    final flags = flag.where((f) => f).length;
    return Column(children: [
      BoardHud(
          title: 'MINESWEEPER ${n}×$n',
          maxMistakes: 0,
          extra: '💣 ${mines - flags}',
          onHint: _hint),
      const SizedBox(height: 6),
      Text('tap = reveal · long-press = flag',
          style: TextStyle(fontSize: 11, color: DC.dim)),
      const SizedBox(height: 8),
      AspectRatio(
        aspectRatio: 1,
        child: Glass(
          padding: const EdgeInsets.all(6),
          radius: 18,
          child: Column(children: [
            for (var r = 0; r < n; r++)
              Expanded(
                  child: Row(children: [
                for (var c = 0; c < n; c++) Expanded(child: _cell(r * n + c)),
              ])),
          ]),
        ),
      ),
    ]);
  }

  Widget _cell(int i) {
    final o = open[i];
    final cnt = o && !mine[i] ? _count(i) : 0;
    return GestureDetector(
      onTap: () => _reveal(i),
      onLongPress: () => _toggleFlag(i),
      child: Container(
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          color: o
              ? (mine[i] ? DC.danger.withOpacity(0.7) : DC.fgo(0.02))
              : DC.violet.withOpacity(0.22),
          border: Border.all(color: DC.fgo(0.08), width: 0.5),
        ),
        child: Center(
          child: o
              ? (mine[i]
                  ? const Text('💣', style: TextStyle(fontSize: 13))
                  : cnt > 0
                      ? Text('$cnt',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: _numColors[cnt]))
                      : null)
              : flag[i]
                  ? const Text('🚩', style: TextStyle(fontSize: 12))
                  : null,
        ),
      ),
    );
  }
}

// ============================================================ SLIDING TILE

class SlidingBoard extends StatefulWidget {
  final int rating;
  final int seed;
  final BoardDone onDone;
  const SlidingBoard(
      {super.key,
      required this.rating,
      required this.seed,
      required this.onDone});

  @override
  State<SlidingBoard> createState() => _SlidingBoardState();
}

class _SlidingBoardState extends State<SlidingBoard> {
  late int n;
  late List<int> tiles; // 0 = blank
  final int start = DateTime.now().millisecondsSinceEpoch;
  int moves = 0;
  bool done = false;

  @override
  void initState() {
    super.initState();
    final rng = Random(widget.seed);
    n = widget.rating < 1500 ? 3 : 4;
    tiles = List<int>.generate(n * n, (i) => (i + 1) % (n * n));
    // shuffle with random valid moves — always solvable
    final steps = 40 + ((widget.rating - 800) ~/ 12);
    var blank = tiles.indexOf(0);
    for (var s = 0; s < steps; s++) {
      final opts = _slidable(blank);
      final pick = opts[rng.nextInt(opts.length)];
      tiles[blank] = tiles[pick];
      tiles[pick] = 0;
      blank = pick;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        GameTutorial.showOnce(context,
            tutKey: 'sliding', title: 'SLIDING PUZZLE', steps: slidingTutorial);
      }
    });
  }

  List<int> _slidable(int blank) {
    final r = blank ~/ n, c = blank % n;
    return [
      if (r > 0) blank - n,
      if (r < n - 1) blank + n,
      if (c > 0) blank - 1,
      if (c < n - 1) blank + 1,
    ];
  }

  void _tap(int i) {
    if (done) return;
    final blank = tiles.indexOf(0);
    if (!_slidable(blank).contains(i)) return;
    setState(() {
      tiles[blank] = tiles[i];
      tiles[i] = 0;
      moves++;
    });
    if (_solved) _finish(true);
  }

  bool get _solved {
    for (var i = 0; i < n * n; i++) {
      if (tiles[i] != (i + 1) % (n * n)) return false;
    }
    return true;
  }

  void _finish(bool won) {
    if (done) return;
    done = true;
    widget.onDone(BoardResult(won: won, timeMs: elapsedSince(start)));
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      BoardHud(title: 'SLIDING ${n}×$n', maxMistakes: 0, extra: '$moves moves'),
      const SizedBox(height: 12),
      AspectRatio(
        aspectRatio: 1,
        child: Glass(
          padding: const EdgeInsets.all(8),
          radius: 18,
          child: Column(children: [
            for (var r = 0; r < n; r++)
              Expanded(
                  child: Row(children: [
                for (var c = 0; c < n; c++) Expanded(child: _tile(r * n + c)),
              ])),
          ]),
        ),
      ),
    ]);
  }

  Widget _tile(int i) {
    final v = tiles[i];
    if (v == 0) return const SizedBox();
    return GestureDetector(
      onTap: () => _tap(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
              colors: [DC.violet.withOpacity(0.55), DC.cyan.withOpacity(0.35)]),
          border: Border.all(color: DC.fgo(0.15)),
        ),
        child: Center(
            child: Text('$v',
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w900))),
      ),
    );
  }
}

// ============================================================ TOWER OF HANOI

class HanoiBoard extends StatefulWidget {
  final int rating;
  final int seed;
  final BoardDone onDone;
  const HanoiBoard(
      {super.key,
      required this.rating,
      required this.seed,
      required this.onDone});

  @override
  State<HanoiBoard> createState() => _HanoiBoardState();
}

class _HanoiBoardState extends State<HanoiBoard> {
  late int disks;
  late List<List<int>> pegs; // disk sizes, last = top
  final int start = DateTime.now().millisecondsSinceEpoch;
  int? from;
  int moves = 0;
  bool done = false;

  int get par => (1 << disks) - 1;

  @override
  void initState() {
    super.initState();
    disks = widget.rating < 1100
        ? 3
        : widget.rating < 1500
            ? 4
            : widget.rating < 1900
                ? 5
                : widget.rating < 2300
                    ? 6
                    : 7;
    pegs = [List<int>.generate(disks, (i) => disks - i), [], []];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        GameTutorial.showOnce(context,
            tutKey: 'hanoi', title: 'TOWER OF HANOI', steps: hanoiTutorial);
      }
    });
  }

  void _tapPeg(int p) {
    if (done) return;
    if (from == null) {
      if (pegs[p].isNotEmpty) setState(() => from = p);
      return;
    }
    if (from == p) {
      setState(() => from = null);
      return;
    }
    final disk = pegs[from!].last;
    if (pegs[p].isNotEmpty && pegs[p].last < disk) {
      // illegal
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('A bigger disk can\'t sit on a smaller one!'),
          duration: Duration(milliseconds: 800)));
      setState(() => from = null);
      return;
    }
    setState(() {
      pegs[from!].removeLast();
      pegs[p].add(disk);
      from = null;
      moves++;
    });
    if (pegs[2].length == disks) {
      done = true;
      // exceeded 3x par = still a win, stars handled by time at level layer
      widget.onDone(
          BoardResult(won: moves <= par * 3, timeMs: elapsedSince(start)));
    }
  }

  static List<Color> get _diskColors => [
        DC.cyan,
        DC.violet,
        DC.magenta,
        DC.amber,
        DC.lime,
        const Color(0xFFFF8A65),
        const Color(0xFF80D8FF),
      ];

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      BoardHud(
          title: 'HANOI · $disks disks',
          maxMistakes: 0,
          extra: '$moves / par $par'),
      const SizedBox(height: 12),
      Glass(
        padding: const EdgeInsets.all(10),
        radius: 18,
        child: SizedBox(
          height: 240,
          child: Row(children: [
            for (var p = 0; p < 3; p++)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _tapPeg(p),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Container(
                          width: 4,
                          decoration: BoxDecoration(
                            color: from == p ? DC.amber : DC.fgo(0.25),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      for (var d = pegs[p].length - 1; d >= 0; d--)
                        Container(
                          height: 20,
                          width: 28.0 + pegs[p][d] * 16,
                          margin: const EdgeInsets.only(top: 3),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: _diskColors[
                                    (pegs[p][d] - 1) % _diskColors.length]
                                .withOpacity(
                                    from == p && d == pegs[p].length - 1
                                        ? 1.0
                                        : 0.65),
                          ),
                        ),
                      Container(
                        height: 6,
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          color: DC.fgo(0.15),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ]),
        ),
      ),
      const SizedBox(height: 8),
      Text('Move the whole tower to the right peg',
          style: TextStyle(fontSize: 12, color: DC.dim)),
    ]);
  }
}

// ============================================================ MEMORY MATRIX

class MemoryBoard extends StatefulWidget {
  final int rating;
  final int seed;
  final BoardDone onDone;
  const MemoryBoard(
      {super.key,
      required this.rating,
      required this.seed,
      required this.onDone});

  @override
  State<MemoryBoard> createState() => _MemoryBoardState();
}

class _MemoryBoardState extends State<MemoryBoard> {
  late int n, targets;
  late Set<int> pattern;
  final Set<int> picked = {};
  final int start = DateTime.now().millisecondsSinceEpoch;
  bool showing = true;
  int lives = 2;
  bool done = false;
  int round = 0;
  static const roundsToWin = 3;

  @override
  void initState() {
    super.initState();
    _newRound();
  }

  void _newRound() {
    final rng = Random(widget.seed + round * 977);
    n = widget.rating < 1300 ? 4 : (widget.rating < 1900 ? 5 : 6);
    targets = (n * n * (0.22 + 0.10 * ((widget.rating - 800) / 1700)))
        .round()
        .clamp(3, 14)
        .toInt();
    pattern = {};
    while (pattern.length < targets) {
      pattern.add(rng.nextInt(n * n));
    }
    picked.clear();
    showing = true;
    setState(() {});
    Timer(Duration(milliseconds: 1400 + targets * 120), () {
      if (mounted) setState(() => showing = false);
    });
  }

  void _tap(int i) {
    if (showing || done || picked.contains(i)) return;
    if (pattern.contains(i)) {
      setState(() => picked.add(i));
      if (picked.length == targets) {
        round++;
        if (round >= roundsToWin) {
          done = true;
          widget.onDone(BoardResult(won: true, timeMs: elapsedSince(start)));
        } else {
          Timer(const Duration(milliseconds: 600), _newRound);
        }
      }
    } else {
      setState(() => lives--);
      if (lives < 0) {
        done = true;
        widget.onDone(BoardResult(won: false, timeMs: elapsedSince(start)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      BoardHud(
          title: 'MEMORY · round ${round + 1}/$roundsToWin',
          maxMistakes: 0,
          extra: '♥ ${lives + 1}'),
      const SizedBox(height: 6),
      Text(showing ? 'MEMORIZE…' : 'REPRODUCE THE PATTERN',
          style: TextStyle(
              fontSize: 12,
              letterSpacing: 2,
              color: showing ? DC.amber : DC.cyan)),
      const SizedBox(height: 8),
      AspectRatio(
        aspectRatio: 1,
        child: Glass(
          padding: const EdgeInsets.all(8),
          radius: 18,
          child: Column(children: [
            for (var r = 0; r < n; r++)
              Expanded(
                  child: Row(children: [
                for (var c = 0; c < n; c++) Expanded(child: _cell(r * n + c)),
              ])),
          ]),
        ),
      ),
    ]);
  }

  Widget _cell(int i) {
    final lit = showing && pattern.contains(i);
    final got = picked.contains(i);
    return GestureDetector(
      onTap: () => _tap(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: lit
              ? DC.amber.withOpacity(0.85)
              : got
                  ? DC.lime.withOpacity(0.7)
                  : DC.fgo(0.05),
          border: Border.all(color: DC.fgo(0.10)),
        ),
      ),
    );
  }
}

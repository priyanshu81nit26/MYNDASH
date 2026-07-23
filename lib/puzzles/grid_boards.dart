import 'dart:math';

import 'package:flutter/material.dart';

import '../theme_district.dart';
import '../ui/glass.dart';
import 'board_core.dart';

// ============================================================ SUDOKU

class SudokuSpec {
  final int n, boxW, boxH;
  final List<int> solution; // n*n values 1..n
  final List<int> given; // 0 = empty
  SudokuSpec(this.n, this.boxW, this.boxH, this.solution, this.given);
}

SudokuSpec generateSudoku(int rating, Random rng, {int? forceSize}) {
  late int n, bw, bh;
  if (forceSize == 8) {
    n = 8;
    bw = 4;
    bh = 2;
  } else if (forceSize == 6) {
    n = 6;
    bw = 3;
    bh = 2;
  } else if (rating < 1200) {
    n = 4;
    bw = 2;
    bh = 2;
  } else if (rating < 1600) {
    n = 6;
    bw = 3;
    bh = 2;
  } else {
    n = 9;
    bw = 3;
    bh = 3;
  }
  final grid = List<int>.filled(n * n, 0);
  _fillSudoku(grid, n, bw, bh, rng);
  final solution = List<int>.from(grid);

  // target givens fraction shrinks with rating
  final keepFrac = n == 4
      ? 0.55 - 0.1 * d01r(rating, 800, 1200)
      : n == 6
          ? 0.52 - 0.12 * d01r(rating, 1200, 1600)
          : 0.48 - 0.18 * d01r(rating, 1600, 2500);
  final target = (n * n * keepFrac).round();
  final order = List<int>.generate(n * n, (i) => i)..shuffle(rng);
  var filled = n * n;
  final puzzle = List<int>.from(solution);
  for (final idx in order) {
    if (filled <= target) break;
    final backup = puzzle[idx];
    puzzle[idx] = 0;
    if (_countSolutions(List<int>.from(puzzle), n, bw, bh, 2) == 1) {
      filled--;
    } else {
      puzzle[idx] = backup;
    }
  }
  return SudokuSpec(n, bw, bh, solution, puzzle);
}

double d01r(int rating, int lo, int hi) =>
    ((rating - lo) / (hi - lo)).clamp(0.0, 1.0).toDouble();

bool _fillSudoku(List<int> g, int n, int bw, int bh, Random rng) {
  final idx = g.indexOf(0);
  if (idx < 0) return true;
  final vals = List<int>.generate(n, (i) => i + 1)..shuffle(rng);
  for (final v in vals) {
    if (_okSudoku(g, n, bw, bh, idx, v)) {
      g[idx] = v;
      if (_fillSudoku(g, n, bw, bh, rng)) return true;
      g[idx] = 0;
    }
  }
  return false;
}

bool _okSudoku(List<int> g, int n, int bw, int bh, int idx, int v) {
  final r = idx ~/ n, c = idx % n;
  for (var i = 0; i < n; i++) {
    if (g[r * n + i] == v || g[i * n + c] == v) return false;
  }
  final br = (r ~/ bh) * bh, bc = (c ~/ bw) * bw;
  for (var i = 0; i < bh; i++) {
    for (var j = 0; j < bw; j++) {
      if (g[(br + i) * n + bc + j] == v) return false;
    }
  }
  return true;
}

int _countSolutions(List<int> g, int n, int bw, int bh, int cap) {
  final idx = g.indexOf(0);
  if (idx < 0) return 1;
  var count = 0;
  for (var v = 1; v <= n; v++) {
    if (_okSudoku(g, n, bw, bh, idx, v)) {
      g[idx] = v;
      count += _countSolutions(g, n, bw, bh, cap - count);
      g[idx] = 0;
      if (count >= cap) return count;
    }
  }
  return count;
}

class SudokuBoard extends StatefulWidget {
  final int rating;
  final int seed;
  final int? forceSize;
  final BoardDone onDone;

  /// When false, mistakes are tracked (and shown) but never auto-fail the
  /// board — used by the daily challenge, where every player must see the
  /// exact same board regardless of how many wrong guesses they make.
  final bool capMistakes;
  const SudokuBoard(
      {super.key,
      required this.rating,
      required this.seed,
      this.forceSize,
      this.capMistakes = true,
      required this.onDone});

  @override
  State<SudokuBoard> createState() => _SudokuBoardState();
}

class _SudokuBoardState extends State<SudokuBoard> {
  late final SudokuSpec spec = generateSudoku(
      widget.rating, Random(widget.seed),
      forceSize: widget.forceSize);
  late final List<int> cells = List<int>.from(spec.given);
  late final List<Set<int>> notes =
      List.generate(spec.n * spec.n, (_) => <int>{});
  final int start = DateTime.now().millisecondsSinceEpoch;
  int selected = -1;
  int mistakes = 0;
  bool noteMode = false;
  int? flashWrong;
  int? flashValue;
  bool done = false;

  void _place(int v) {
    if (selected < 0 || spec.given[selected] != 0 || done) return;
    if (noteMode) {
      setState(() {
        notes[selected].contains(v)
            ? notes[selected].remove(v)
            : notes[selected].add(v);
      });
      return;
    }
    if (v == 0) {
      setState(() => cells[selected] = 0);
      return;
    }
    if (spec.solution[selected] == v) {
      setState(() {
        cells[selected] = v;
        notes[selected].clear();
      });
      if (!cells.contains(0)) _finish(true);
    } else {
      setState(() {
        flashWrong = selected;
        flashValue = v;
        mistakes++;
      });
      Future.delayed(const Duration(milliseconds: 450), () {
        if (mounted) setState(() {
          flashWrong = null;
          flashValue = null;
        });
      });
      if (widget.capMistakes && mistakes >= 3) _finish(false);
    }
  }

  void _hint() {
    if (done || !chargeHint(context)) return;
    var target = selected;
    if (target < 0 || cells[target] != 0) {
      target = cells.indexOf(0);
    }
    if (target < 0) return;
    setState(() {
      cells[target] = spec.solution[target];
      notes[target].clear();
      selected = target;
    });
    if (!cells.contains(0)) _finish(true);
  }

  void _finish(bool won) {
    if (done) return;
    done = true;
    widget.onDone(BoardResult(won: won, timeMs: elapsedSince(start)));
  }

  @override
  Widget build(BuildContext context) {
    final n = spec.n;
    return Column(
      children: [
        BoardHud(title: 'SUDOKU ${n}×$n', mistakes: mistakes, onHint: _hint),
        const SizedBox(height: 12),
        AspectRatio(
          aspectRatio: 1,
          child: Glass(
            padding: const EdgeInsets.all(6),
            radius: 18,
            child: Column(
              children: [
                for (var r = 0; r < n; r++)
                  Expanded(
                    child: Row(children: [
                      for (var c = 0; c < n; c++)
                        Expanded(child: _cell(r * n + c)),
                    ]),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _keypad(n),
      ],
    );
  }

  Widget _cell(int i) {
    final n = spec.n;
    final r = i ~/ n, c = i % n;
    final isGiven = spec.given[i] != 0;
    final v = cells[i];
    final sel = selected == i;
    final sameVal = selected >= 0 &&
        cells[selected] != 0 &&
        v == cells[selected] &&
        i != selected;
    final thickR = (c + 1) % spec.boxW == 0 && c != n - 1;
    final thickB = (r + 1) % spec.boxH == 0 && r != n - 1;
    return GestureDetector(
      onTap: () => setState(() => selected = i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: flashWrong == i
              ? DC.danger.withOpacity(0.55)
              : sel
                  ? DC.cyan.withOpacity(0.22)
                  : sameVal
                      ? DC.violet.withOpacity(0.18)
                      : Colors.transparent,
          border: Border(
            // Theme-aware grid lines: dark ink on Arcade, white on Night.
            right: BorderSide(
                color: DC.fgo(thickR ? 0.32 : 0.12), width: thickR ? 1.6 : 0.6),
            bottom: BorderSide(
                color: DC.fgo(thickB ? 0.32 : 0.12), width: thickB ? 1.6 : 0.6),
          ),
        ),
        child: Center(
          child: flashWrong == i && flashValue != null
              ? Text('$flashValue',
                  style: TextStyle(
                      fontSize: n == 9 ? 16 : 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white))
              : v != 0
                  ? Text('$v',
                      style: TextStyle(
                          fontSize: n == 9 ? 16 : 22,
                          fontWeight: FontWeight.w800,
                          color: isGiven ? DC.text : DC.cyan))
                  : notes[i].isNotEmpty
                      ? Text(notes[i].toList().join(' '),
                          style: TextStyle(fontSize: 8, color: DC.dim))
                      : const SizedBox(),
        ),
      ),
    );
  }

  Widget _keypad(int n) {
    return Column(children: [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          for (var v = 1; v <= n; v++)
            _key('$v', () => _place(v), highlight: false),
          _key('⌫', () => _place(0)),
          _key('✎', () => setState(() => noteMode = !noteMode),
              highlight: noteMode),
        ],
      ),
    ]);
  }

  Widget _key(String label, VoidCallback onTap, {bool highlight = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient:
              highlight ? LinearGradient(colors: [DC.violet, DC.cyan]) : null,
          color: highlight ? null : DC.fgo(0.06),
          border: Border.all(color: DC.fgo(0.12)),
        ),
        child: Center(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800))),
      ),
    );
  }
}

// ============================================================ KENKEN

class _Cage {
  final List<int> cells;
  final String op;
  final int target;
  _Cage(this.cells, this.op, this.target);
}

class KenKenBoard extends StatefulWidget {
  final int rating;
  final int seed;
  final BoardDone onDone;

  /// When false, mistakes are tracked (and shown) but never auto-fail the
  /// board — used by the daily challenge, where every player must see the
  /// exact same board regardless of how many wrong guesses they make.
  final bool capMistakes;
  const KenKenBoard(
      {super.key,
      required this.rating,
      required this.seed,
      this.capMistakes = true,
      required this.onDone});

  @override
  State<KenKenBoard> createState() => _KenKenBoardState();
}

class _KenKenBoardState extends State<KenKenBoard> {
  late int n;
  late List<int> solution;
  late List<_Cage> cages;
  late List<int> cageOf;
  late List<int> cells;
  final int start = DateTime.now().millisecondsSinceEpoch;
  int selected = -1;
  int mistakes = 0;
  int? flashWrong;
  int? flashValue;
  bool done = false;

  @override
  void initState() {
    super.initState();
    final rng = Random(widget.seed);
    n = widget.rating < 1300 ? 3 : (widget.rating < 1800 ? 4 : 5);
    // latin square from shifted base, shuffled
    final rows = List<int>.generate(n, (i) => i)..shuffle(rng);
    final cols = List<int>.generate(n, (i) => i)..shuffle(rng);
    final syms = List<int>.generate(n, (i) => i + 1)..shuffle(rng);
    solution = List<int>.generate(
        n * n, (i) => syms[(rows[i ~/ n] + cols[i % n]) % n]);
    // cages
    cageOf = List<int>.filled(n * n, -1);
    cages = [];
    final order = List<int>.generate(n * n, (i) => i)..shuffle(rng);
    for (final c in order) {
      if (cageOf[c] != -1) continue;
      final cellsInCage = [c];
      cageOf[c] = cages.length;
      var cur = c;
      while (cellsInCage.length < 3 &&
          rng.nextDouble() < (cellsInCage.length == 1 ? 0.75 : 0.35)) {
        final nb = _neighbors(cur).where((x) => cageOf[x] == -1).toList();
        if (nb.isEmpty) break;
        cur = nb[rng.nextInt(nb.length)];
        cageOf[cur] = cages.length;
        cellsInCage.add(cur);
      }
      cages.add(_makeCage(cellsInCage, rng));
    }
    cells = List<int>.filled(n * n, 0);
  }

  List<int> _neighbors(int i) {
    final r = i ~/ n, c = i % n;
    return [
      if (r > 0) i - n,
      if (r < n - 1) i + n,
      if (c > 0) i - 1,
      if (c < n - 1) i + 1,
    ];
  }

  _Cage _makeCage(List<int> cs, Random rng) {
    final vals = cs.map((i) => solution[i]).toList();
    if (cs.length == 1) return _Cage(cs, '=', vals[0]);
    if (cs.length == 2) {
      final a = vals[0], b = vals[1];
      if (rng.nextBool() && (a % b == 0 || b % a == 0)) {
        return _Cage(cs, '÷', max(a, b) ~/ min(a, b));
      }
      if (rng.nextBool()) return _Cage(cs, '−', (a - b).abs());
      return rng.nextBool() ? _Cage(cs, '+', a + b) : _Cage(cs, '×', a * b);
    }
    return rng.nextBool()
        ? _Cage(cs, '+', vals.reduce((x, y) => x + y))
        : _Cage(cs, '×', vals.reduce((x, y) => x * y));
  }

  void _place(int v) {
    if (selected < 0 || done) return;
    if (v == 0) {
      setState(() => cells[selected] = 0);
      return;
    }
    // live latin validation
    final r = selected ~/ n, c = selected % n;
    var conflict = false;
    for (var i = 0; i < n; i++) {
      if (cells[r * n + i] == v && r * n + i != selected) conflict = true;
      if (cells[i * n + c] == v && i * n + c != selected) conflict = true;
    }
    if (conflict || solution[selected] != v) {
      setState(() {
        flashWrong = selected;
        flashValue = v;
        mistakes++;
      });
      Future.delayed(const Duration(milliseconds: 450), () {
        if (mounted) setState(() {
          flashWrong = null;
          flashValue = null;
        });
      });
      if (widget.capMistakes && mistakes >= 3) _finish(false);
      return;
    }
    setState(() => cells[selected] = v);
    if (!cells.contains(0)) _finish(true);
  }

  void _hint() {
    if (done || !chargeHint(context)) return;
    var t = selected;
    if (t < 0 || cells[t] != 0) t = cells.indexOf(0);
    if (t < 0) return;
    setState(() {
      cells[t] = solution[t];
      selected = t;
    });
    if (!cells.contains(0)) _finish(true);
  }

  void _finish(bool won) {
    if (done) return;
    done = true;
    widget.onDone(BoardResult(won: won, timeMs: elapsedSince(start)));
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      BoardHud(title: 'KENKEN ${n}×$n', mistakes: mistakes, onHint: _hint),
      const SizedBox(height: 12),
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
      const SizedBox(height: 12),
      Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (var v = 1; v <= n; v++) _key('$v', () => _place(v)),
            _key('⌫', () => _place(0)),
          ]),
    ]);
  }

  Widget _cell(int i) {
    final r = i ~/ n, c = i % n;
    final cage = cageOf[i];
    final isHead = cages[cage].cells.reduce(min) == i;
    bool diffCage(int j) => j < 0 || j >= n * n ? true : cageOf[j] != cage;
    final v = cells[i];
    final correct = v != 0;
    return Semantics(
        button: true,
        selected: selected == i,
        label: correct
            ? 'Cell ${i + 1}, correct number $v'
            : 'Cell ${i + 1}${selected == i ? ', selected' : ''}',
        child: GestureDetector(
          onTap: correct ? null : () => setState(() => selected = i),
          child: Container(
            decoration: BoxDecoration(
              color: flashWrong == i
                  ? DC.danger.withOpacity(0.55)
                  : correct
                      ? DC.lime.withOpacity(0.18)
                      : selected == i
                          ? DC.cyan.withOpacity(0.22)
                          : Colors.transparent,
              border: Border(
                // Theme-aware cage lines: dark ink on Arcade, white on Night.
                top: BorderSide(
                    color: DC.fgo(r == 0 || diffCage(i - n) ? 0.36 : 0.11),
                    width: r == 0 || diffCage(i - n) ? 1.4 : 0.6),
                left: BorderSide(
                    color: DC.fgo(
                        c == 0 || diffCage(c == 0 ? -1 : i - 1) ? 0.36 : 0.11),
                    width: c == 0 || diffCage(c == 0 ? -1 : i - 1) ? 1.4 : 0.6),
              ),
            ),
            child: Stack(children: [
              if (isHead)
                Positioned(
                  top: 2,
                  left: 3,
                  child: Text(
                      '${cages[cage].target}${cages[cage].op == '=' ? '' : cages[cage].op}',
                      style: TextStyle(fontSize: 9, color: DC.amber)),
                ),
              Center(
                child: flashWrong == i && flashValue != null
                    ? Text('$flashValue',
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white))
                    : v == 0
                        ? const SizedBox.shrink()
                        : Text('$v',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: DC.lime)),
              ),
            ]),
          ),
        ));
  }

  Widget _key(String label, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: DC.fgo(0.06),
            border: Border.all(color: DC.fgo(0.12)),
          ),
          child: Center(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800))),
        ),
      );
}

// ============================================================ KAKURO (lite)

class KakuroBoard extends StatefulWidget {
  final int rating;
  final int seed;
  final BoardDone onDone;
  const KakuroBoard(
      {super.key,
      required this.rating,
      required this.seed,
      required this.onDone});

  @override
  State<KakuroBoard> createState() => _KakuroBoardState();
}

class _KakuroBoardState extends State<KakuroBoard> {
  late List<String> mask;
  late int rows, cols;
  late List<int> solution; // 0 for blocks
  late List<int> cells;
  late Map<int, int> rowClue; // head block index -> sum (run to the right)
  late Map<int, int> colClue; // head block index -> sum (run below)
  final int start = DateTime.now().millisecondsSinceEpoch;
  int selected = -1;
  int mistakes = 0;
  int? flashWrong;
  bool done = false;

  @override
  void initState() {
    super.initState();
    final rng = Random(widget.seed);
    mask = widget.rating < 1300
        ? ['####', '#...', '#...', '#...']
        : widget.rating < 1800
            ? ['#####', '#....', '#....', '#..#.', '#....']
            : ['######', '#.....', '#....#', '#..#..', '#.....', '#.....'];
    rows = mask.length;
    cols = mask[0].length;
    solution = List<int>.filled(rows * cols, 0);
    // collect runs
    final runsH = <List<int>>[], runsV = <List<int>>[];
    for (var r = 0; r < rows; r++) {
      var run = <int>[];
      for (var c = 0; c < cols; c++) {
        if (mask[r][c] == '.') {
          run.add(r * cols + c);
        } else {
          if (run.length >= 2) runsH.add(run);
          run = [];
        }
      }
      if (run.length >= 2) runsH.add(run);
    }
    for (var c = 0; c < cols; c++) {
      var run = <int>[];
      for (var r = 0; r < rows; r++) {
        if (mask[r][c] == '.') {
          run.add(r * cols + c);
        } else {
          if (run.length >= 2) runsV.add(run);
          run = [];
        }
      }
      if (run.length >= 2) runsV.add(run);
    }
    // backtracking fill: unique digits within each run
    final whiteCells = <int>[
      for (var i = 0; i < rows * cols; i++)
        if (mask[i ~/ cols][i % cols] == '.') i
    ];
    final runOfH = <int, List<int>>{}, runOfV = <int, List<int>>{};
    for (final run in runsH) {
      for (final c in run) {
        runOfH[c] = run;
      }
    }
    for (final run in runsV) {
      for (final c in run) {
        runOfV[c] = run;
      }
    }
    bool fill(int k) {
      if (k == whiteCells.length) return true;
      final cell = whiteCells[k];
      final digits = List<int>.generate(9, (i) => i + 1)..shuffle(rng);
      for (final d in digits) {
        final okH = !(runOfH[cell]?.any((c) => solution[c] == d) ?? false);
        final okV = !(runOfV[cell]?.any((c) => solution[c] == d) ?? false);
        if (okH && okV) {
          solution[cell] = d;
          if (fill(k + 1)) return true;
          solution[cell] = 0;
        }
      }
      return false;
    }

    fill(0);
    // clues
    rowClue = {};
    colClue = {};
    for (final run in runsH) {
      rowClue[run.first - 1] = run.fold(0, (a, c) => a + solution[c]);
    }
    for (final run in runsV) {
      colClue[run.first - cols] = run.fold(0, (a, c) => a + solution[c]);
    }
    cells = List<int>.filled(rows * cols, 0);
  }

  bool _isWhite(int i) => mask[i ~/ cols][i % cols] == '.';

  void _place(int v) {
    if (selected < 0 || done || !_isWhite(selected)) return;
    if (v == 0) {
      setState(() => cells[selected] = 0);
      return;
    }
    if (solution[selected] == v) {
      setState(() => cells[selected] = v);
      final allDone = [
        for (var i = 0; i < rows * cols; i++)
          if (_isWhite(i)) cells[i] == solution[i]
      ].every((x) => x);
      if (allDone) _finish(true);
    } else {
      setState(() {
        flashWrong = selected;
        mistakes++;
      });
      Future.delayed(const Duration(milliseconds: 450), () {
        if (mounted) setState(() => flashWrong = null);
      });
      if (mistakes >= 3) _finish(false);
    }
  }

  void _hint() {
    if (done || !chargeHint(context)) return;
    for (var i = 0; i < rows * cols; i++) {
      if (_isWhite(i) && cells[i] == 0) {
        setState(() {
          cells[i] = solution[i];
          selected = i;
        });
        break;
      }
    }
  }

  void _finish(bool won) {
    if (done) return;
    done = true;
    widget.onDone(BoardResult(won: won, timeMs: elapsedSince(start)));
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      BoardHud(title: 'KAKURO', mistakes: mistakes, onHint: _hint),
      const SizedBox(height: 12),
      AspectRatio(
        aspectRatio: cols / rows,
        child: Glass(
          padding: const EdgeInsets.all(6),
          radius: 18,
          child: Column(children: [
            for (var r = 0; r < rows; r++)
              Expanded(
                  child: Row(children: [
                for (var c = 0; c < cols; c++)
                  Expanded(child: _cell(r * cols + c)),
              ])),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (var v = 1; v <= 9; v++) _key('$v', () => _place(v)),
            _key('⌫', () => _place(0)),
          ]),
    ]);
  }

  Widget _cell(int i) {
    if (!_isWhite(i)) {
      final right = rowClue[i];
      final below = colClue[i];
      return Container(
        margin: const EdgeInsets.all(0.5),
        color: DC.fgo(0.05),
        child: (right == null && below == null)
            ? null
            : Stack(children: [
                if (right != null)
                  Positioned(
                      top: 3,
                      right: 4,
                      child: Text('$right→',
                          style: TextStyle(fontSize: 10, color: DC.amber))),
                if (below != null)
                  Positioned(
                      bottom: 3,
                      left: 4,
                      child: Text('$below↓',
                          style: TextStyle(fontSize: 10, color: DC.cyan))),
              ]),
      );
    }
    final v = cells[i];
    return GestureDetector(
      onTap: () => setState(() => selected = i),
      child: Container(
        margin: const EdgeInsets.all(0.5),
        decoration: BoxDecoration(
          color: flashWrong == i
              ? DC.danger.withOpacity(0.55)
              : selected == i
                  ? DC.cyan.withOpacity(0.22)
                  : DC.fgo(0.01),
          border: Border.all(color: DC.fgo(0.15), width: 0.7),
        ),
        child: Center(
            child: Text(v == 0 ? '' : '$v',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: DC.cyan))),
      ),
    );
  }

  Widget _key(String label, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: DC.fgo(0.06),
            border: Border.all(color: DC.fgo(0.12)),
          ),
          child: Center(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w800))),
        ),
      );
}

// ============================================================ NONOGRAM

class NonogramBoard extends StatefulWidget {
  final int rating;
  final int seed;
  final BoardDone onDone;
  const NonogramBoard(
      {super.key,
      required this.rating,
      required this.seed,
      required this.onDone});

  @override
  State<NonogramBoard> createState() => _NonogramBoardState();
}

class _NonogramBoardState extends State<NonogramBoard> {
  late int n;
  late List<bool> target;
  late List<int> state; // 0 empty, 1 filled, 2 marked X
  late List<List<int>> rowClues, colClues;
  final int start = DateTime.now().millisecondsSinceEpoch;
  bool done = false;

  @override
  void initState() {
    super.initState();
    final rng = Random(widget.seed);
    n = widget.rating < 1300 ? 5 : (widget.rating < 1800 ? 8 : 10);
    target = List.generate(n * n, (_) => rng.nextDouble() < 0.55);
    rowClues = [
      for (var r = 0; r < n; r++)
        _clues([for (var c = 0; c < n; c++) target[r * n + c]])
    ];
    colClues = [
      for (var c = 0; c < n; c++)
        _clues([for (var r = 0; r < n; r++) target[r * n + c]])
    ];
    state = List<int>.filled(n * n, 0);
  }

  List<int> _clues(List<bool> line) {
    final out = <int>[];
    var run = 0;
    for (final b in line) {
      if (b) {
        run++;
      } else if (run > 0) {
        out.add(run);
        run = 0;
      }
    }
    if (run > 0) out.add(run);
    return out.isEmpty ? [0] : out;
  }

  void _tap(int i, {bool mark = false}) {
    if (done) return;
    setState(() {
      if (mark) {
        state[i] = state[i] == 2 ? 0 : 2;
      } else {
        state[i] = state[i] == 1 ? 0 : 1;
      }
    });
    _checkWin();
  }

  void _checkWin() {
    // win when the player's filled pattern produces the same clues
    for (var r = 0; r < n; r++) {
      final line = [for (var c = 0; c < n; c++) state[r * n + c] == 1];
      if (_clues(line).join(',') != rowClues[r].join(',')) return;
    }
    for (var c = 0; c < n; c++) {
      final line = [for (var r = 0; r < n; r++) state[r * n + c] == 1];
      if (_clues(line).join(',') != colClues[c].join(',')) return;
    }
    done = true;
    widget.onDone(BoardResult(won: true, timeMs: elapsedSince(start)));
  }

  void _hint() {
    if (done || !chargeHint(context)) return;
    for (var i = 0; i < n * n; i++) {
      final want = target[i] ? 1 : 2;
      if (state[i] != want) {
        setState(() => state[i] = want);
        break;
      }
    }
    _checkWin();
  }

  @override
  Widget build(BuildContext context) {
    final clueW = 34.0;
    return Column(children: [
      BoardHud(title: 'NONOGRAM ${n}×$n', maxMistakes: 0, onHint: _hint),
      const SizedBox(height: 6),
      Text('tap = fill · long-press = mark ✕',
          style: TextStyle(fontSize: 11, color: DC.dim)),
      const SizedBox(height: 8),
      Glass(
        padding: const EdgeInsets.all(8),
        radius: 18,
        child: Column(children: [
          Row(children: [
            SizedBox(width: clueW),
            for (var c = 0; c < n; c++)
              Expanded(
                child: Text(colClues[c].join('\n'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 9, color: DC.amber)),
              ),
          ]),
          AspectRatio(
            aspectRatio: (n + 1) / n,
            child: Row(children: [
              SizedBox(
                width: clueW,
                child: Column(children: [
                  for (var r = 0; r < n; r++)
                    Expanded(
                      child: Center(
                        child: Text(rowClues[r].join(' '),
                            style: TextStyle(fontSize: 9, color: DC.amber)),
                      ),
                    ),
                ]),
              ),
              Expanded(
                child: Column(children: [
                  for (var r = 0; r < n; r++)
                    Expanded(
                      child: Row(children: [
                        for (var c = 0; c < n; c++)
                          Expanded(child: _cell(r * n + c)),
                      ]),
                    ),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    ]);
  }

  Widget _cell(int i) {
    return GestureDetector(
      onTap: () => _tap(i),
      onLongPress: () => _tap(i, mark: true),
      child: Container(
        margin: const EdgeInsets.all(0.7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(3),
          color: state[i] == 1 ? DC.cyan.withOpacity(0.85) : DC.fgo(0.04),
          border: Border.all(color: DC.fgo(0.10), width: 0.5),
        ),
        child: state[i] == 2
            ? Center(
                child: Text('✕', style: TextStyle(fontSize: 10, color: DC.dim)))
            : null,
      ),
    );
  }
}

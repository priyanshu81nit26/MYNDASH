import 'dart:math';

import 'package:flutter/material.dart';

import '../core/fx.dart';
import '../engine/mind_engines.dart';
import '../theme_district.dart';
import '../ui/game_tutorial.dart';
import '../ui/glass.dart';
import 'mind_games.dart';

/// ============================================================
/// SUDOKU 🌿 — classic 9×9 on a green felt board (white theme:
/// club-green on ivory · dark theme: deep emerald on black).
/// Practice (50 levels), vs bot, online & friend races — first
/// to complete the grid wins.
/// ============================================================

const _sudokuTutorial = [
  TutorialStep('Tap a cell, then tap a number to fill it.',
      gesture: TutorialGesture.tap),
  TutorialStep('Every row, column and 3×3 box needs 1-9 exactly once.',
      gesture: TutorialGesture.tap),
  TutorialStep('Long-press a number (or use ✏️) for pencil notes.',
      gesture: TutorialGesture.tap),
  TutorialStep('Racing? The first player to finish the grid WINS!',
      gesture: TutorialGesture.none),
];

Widget sudokuBuilder(
        {int level = 1,
        int? botLevel,
        Map<String, dynamic>? room,
        bool amHost = true,
        int? progressionStep,
        int? puzzleSeed,
        int? displayRating,
        ValueChanged<int>? arenaScore}) =>
    SudokuScreen(
      level: level,
      botLevel: botLevel,
      room: room,
      amHost: amHost,
      progressionStep: progressionStep,
      puzzleSeed: puzzleSeed,
      displayRating: displayRating,
      arenaScore: arenaScore,
    );

class SudokuScreen extends StatefulWidget {
  final int level;
  final int? botLevel;
  final Map<String, dynamic>? room;
  final bool amHost;
  final int? progressionStep;
  final int? puzzleSeed;
  final int? displayRating;
  final ValueChanged<int>? arenaScore;
  const SudokuScreen(
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
  State<SudokuScreen> createState() => _SudokuScreenState();
}

class _SudokuScreenState extends State<SudokuScreen>
    with TickerProviderStateMixin, MindRace {
  SudokuPuzzle? puzzle;
  late List<int> board; // current values, 0 = empty
  late List<Set<int>> notes; // pencil marks
  int selected = -1;
  bool pencil = false;
  int mistakes = 0;
  int? shakeCell;
  late final AnimationController _shake = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 320));
  late final AnimationController _winWave = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400));

  // felt palette
  Color get _felt =>
      ThemeCtl.isDark ? const Color(0xFF0B3A28) : const Color(0xFF1B6B45);
  Color get _feltLight =>
      ThemeCtl.isDark ? const Color(0xFF104A34) : const Color(0xFF238755);

  @override
  void initState() {
    super.initState();
    final lvl = widget.room != null
        ? mindOnlineLevel(widget.room!)
        : (widget.botLevel ?? widget.level);
    initRace(
        game: 'sudoku',
        label: 'Sudoku 🌿',
        level: lvl,
        botLevel: widget.botLevel,
        room: widget.room,
        amHost: widget.amHost,
        progressionStep: widget.progressionStep,
        progressMaxLevel: widget.progressionStep == null ? null : 270,
        displayRating: widget.displayRating,
        localSeed: widget.puzzleSeed,
        arenaScore: widget.arenaScore);
    final seed = raceSeed;
    // generate after first frame so the screen appears instantly
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = SudokuEngine.generate(seed, SudokuEngine.cluesForLevel(lvl));
      if (!mounted) return;
      setState(() {
        puzzle = p;
        board = List<int>.from(p.given);
        notes = List.generate(81, (_) => <int>{});
      });
      GameTutorial.showOnce(context,
          tutKey: 'sudoku', title: 'SUDOKU', steps: _sudokuTutorial);
    });
  }

  @override
  void dispose() {
    disposeRace();
    _shake.dispose();
    _winWave.dispose();
    super.dispose();
  }

  @override
  void onRaceFinished(bool won) {
    if (won) _winWave.forward(from: 0);
  }

  @override
  void onPlayAgain(int level) {
    Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => SudokuScreen(
                level: isBot ? widget.level : level,
                botLevel: isBot ? level : null,
                progressionStep: widget.progressionStep,
                puzzleSeed: widget.puzzleSeed,
                displayRating: widget.displayRating,
                arenaScore: widget.arenaScore)));
  }

  bool _given(int i) => puzzle!.given[i] != 0;

  double get _progress {
    if (puzzle == null) return 0;
    var right = 0, total = 0;
    for (var i = 0; i < 81; i++) {
      if (!_given(i)) {
        total++;
        if (board[i] == puzzle!.solution[i]) right++;
      }
    }
    return total == 0 ? 0 : right / total;
  }

  int _countOf(int n) => board.where((v) => v == n).length;

  void _enter(int n) {
    if (raceOver || paused || selected < 0 || puzzle == null) return;
    final i = selected;
    if (_given(i)) return Fx.error();
    if (pencil) {
      Fx.tap();
      setState(
          () => notes[i].contains(n) ? notes[i].remove(n) : notes[i].add(n));
      return;
    }
    if (board[i] == n) {
      Fx.tap();
      setState(() => board[i] = 0);
      return;
    }
    setState(() {
      board[i] = n;
      notes[i].clear();
    });
    if (n != puzzle!.solution[i]) {
      mistakes++;
      shakeCell = i;
      Fx.fail();
      _shake.forward(from: 0);
      setState(() {});
      return;
    }
    Fx.tap();
    // auto-clean pencil notes in row/col/box
    for (var j = 0; j < 81; j++) {
      if (j ~/ 9 == i ~/ 9 ||
          j % 9 == i % 9 ||
          (j ~/ 27 == i ~/ 27 && (j % 9) ~/ 3 == (i % 9) ~/ 3)) {
        notes[j].remove(n);
      }
    }
    reportProgress(_progress);
    if (_progress >= 1) solvedNow();
  }

  void _erase() {
    if (selected < 0 || puzzle == null || _given(selected)) return;
    Fx.tap();
    setState(() {
      board[selected] = 0;
      notes[selected].clear();
    });
  }

  void _hint() {
    if (puzzle == null || raceOver || paused) return;
    // fill the selected cell (or first empty) — costs 25s on the clock
    var i = selected;
    if (i < 0 || _given(i) || board[i] == puzzle!.solution[i]) {
      i = List.generate(81, (k) => k).firstWhere(
          (k) => !_given(k) && board[k] != puzzle!.solution[k],
          orElse: () => -1);
    }
    if (i < 0) return;
    penalise(25);
    Fx.success();
    setState(() {
      selected = i;
      board[i] = puzzle!.solution[i];
      notes[i].clear();
    });
    reportProgress(_progress);
    if (_progress >= 1) solvedNow();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ShaderBackground(
        child: SafeArea(
          child: Stack(children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                raceHud(context,
                    accent: DC.lime,
                    help: GameTutorial.helpButton(context,
                        title: 'SUDOKU', steps: _sudokuTutorial)),
                const SizedBox(height: 6),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.close, size: 12, color: DC.danger),
                  Text(' $mistakes mistakes',
                      style: TextStyle(fontSize: 11, color: DC.dim)),
                  const SizedBox(width: 14),
                  Icon(Icons.grid_on, size: 12, color: DC.lime),
                  Text(' ${(_progress * 100).round()}% done',
                      style: TextStyle(fontSize: 11, color: DC.dim)),
                ]),
                const Spacer(),
                if (puzzle == null)
                  Column(children: [
                    CircularProgressIndicator(color: DC.lime),
                    const SizedBox(height: 12),
                    Text('Laying out the felt…',
                        style: TextStyle(color: DC.dim, fontSize: 12)),
                  ])
                else
                  Tilt3D(tilt: 0.08, child: _board()),
                const Spacer(),
                if (puzzle != null) _pad(),
                const SizedBox(height: 6),
              ]),
            ),
            pauseCurtain(),
          ]),
        ),
      ),
    );
  }

  Widget _board() {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_feltLight, _felt]),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.45),
                blurRadius: 22,
                offset: const Offset(0, 14)),
            BoxShadow(
                color: _feltLight.withOpacity(0.35),
                blurRadius: 3,
                spreadRadius: -1,
                offset: const Offset(0, -2)),
          ],
          border: Border.all(color: Colors.white.withOpacity(0.18), width: 1.2),
        ),
        child: AnimatedBuilder(
          animation: Listenable.merge([_shake, _winWave]),
          builder: (_, __) => Column(children: [
            for (var r = 0; r < 9; r++)
              Expanded(
                child: Row(children: [
                  for (var c = 0; c < 9; c++) Expanded(child: _cell(r * 9 + c)),
                ]),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _cell(int i) {
    final r = i ~/ 9, c = i % 9;
    final v = board[i];
    final given = _given(i);
    final sel = i == selected;
    final selV = selected >= 0 ? board[selected] : 0;
    final sameRegion = selected >= 0 &&
        (r == selected ~/ 9 ||
            c == selected % 9 ||
            (r ~/ 3 == (selected ~/ 9) ~/ 3 && c ~/ 3 == (selected % 9) ~/ 3));
    final sameNum = v != 0 && v == selV && !sel;
    final wrong = v != 0 && !given && v != puzzle!.solution[i];

    // 3×3 box walls
    final thickR = c % 3 == 2 && c != 8;
    final thickB = r % 3 == 2 && r != 8;

    double dx = 0;
    if (shakeCell == i && _shake.isAnimating) {
      dx = sin(_shake.value * pi * 5) * 4 * (1 - _shake.value);
    }
    double winPop = 0;
    if (_winWave.isAnimating || _winWave.isCompleted) {
      final wave = (_winWave.value * 12 - (r + c) / 16 * 12).clamp(0.0, 1.0);
      winPop = sin(wave * pi) * 0.12;
    }

    return GestureDetector(
      onTap: () {
        if (paused) return;
        Fx.light();
        setState(() => selected = i);
      },
      child: Transform.translate(
        offset: Offset(dx, 0),
        child: Transform.scale(
          scale: 1 + winPop,
          child: Container(
            margin: EdgeInsets.only(
                right: thickR ? 2.5 : 0.5, bottom: thickB ? 2.5 : 0.5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: sel
                  ? Colors.white.withOpacity(0.34)
                  : sameNum
                      ? DC.amber.withOpacity(0.38)
                      : sameRegion
                          ? Colors.white.withOpacity(0.13)
                          : Colors.white.withOpacity(0.055),
              boxShadow: sel
                  ? [
                      BoxShadow(
                          color: Colors.white.withOpacity(0.35), blurRadius: 8)
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: v != 0
                ? AnimatedScale(
                    duration: const Duration(milliseconds: 160),
                    scale: 1,
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey('$i-$v'),
                      tween: Tween(begin: 0.4, end: 1),
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutBack,
                      builder: (_, s, child) =>
                          Transform.scale(scale: s, child: child),
                      child: Text('$v',
                          style: TextStyle(
                              fontSize: 19,
                              fontWeight:
                                  given ? FontWeight.w900 : FontWeight.w700,
                              color: wrong
                                  ? const Color(0xFFFF6B6B)
                                  : given
                                      ? Colors.white
                                      : const Color(0xFFB6F3D2))),
                    ),
                  )
                : notes[i].isEmpty
                    ? null
                    : Wrap(
                        alignment: WrapAlignment.center,
                        children: [
                          for (final n in (notes[i].toList()..sort()))
                            Text('$n ',
                                style: TextStyle(
                                    fontSize: 7.5,
                                    color: Colors.white.withOpacity(0.65))),
                        ],
                      ),
          ),
        ),
      ),
    );
  }

  Widget _pad() {
    return Column(children: [
      Row(children: [
        for (var n = 1; n <= 9; n++)
          Expanded(
            child: GestureDetector(
              onTap: () => _enter(n),
              onLongPress: () {
                if (selected < 0 || _given(selected)) return;
                Fx.tap();
                setState(() => notes[selected].contains(n)
                    ? notes[selected].remove(n)
                    : notes[selected].add(n));
              },
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: _countOf(n) >= 9 ? 0.25 : 1,
                child: Container(
                  height: 52,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [DC.fgo(0.12), DC.fgo(0.05)]),
                    border: Border.all(color: DC.fgo(0.14)),
                  ),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('$n',
                            style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                                color: DC.text)),
                        Text('${9 - _countOf(n)}',
                            style: TextStyle(fontSize: 8, color: DC.dim)),
                      ]),
                ),
              ),
            ),
          ),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
          child: GhostButton(
            label: pencil ? '✏️ PENCIL ON' : '✏️ PENCIL',
            height: 42,
            onPressed: () {
              Fx.tap();
              setState(() => pencil = !pencil);
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
            child: GhostButton(label: 'ERASE', height: 42, onPressed: _erase)),
        const SizedBox(width: 8),
        Expanded(
          child: GhostButton(label: 'HINT +25s', height: 42, onPressed: _hint),
        ),
      ]),
    ]);
  }
}

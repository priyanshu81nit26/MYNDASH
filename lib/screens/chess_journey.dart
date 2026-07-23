import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../core/state.dart';
import '../engine/chess_puzzles.dart';
import '../engine/question.dart';
import '../theme_district.dart';
import '../ui/extras.dart';
import '../ui/glass.dart';
import '../ui/mini_chess_board.dart';
import 'chess_duel.dart';

/// ============================================================
/// CHESS HUB — two tracks, 30 levels each:
///  ♟ GAME — real chess vs the Guardian bots.
///    Thirty variants distributed across the shared 800–2500 rating bands.
///  🧠 IQ TESTING — 15-question tactic/vision sets per level,
///    progressive difficulty inside each set, level 30 = hardest.
///    Score 12/15+ to unlock the next set.
/// ============================================================
class ChessJourneyScreen extends StatefulWidget {
  const ChessJourneyScreen({super.key});

  @override
  State<ChessJourneyScreen> createState() => _ChessJourneyScreenState();
}

class _ChessJourneyScreenState extends State<ChessJourneyScreen> {
  bool iqMode = false;

  /// Rating that IQ level N (1..30) simulates for its questions.
  static int iqBaseRating(int level) {
    final raw = 800 + (level - 1) * 58;
    return ((raw / 100).round() * 100).clamp(800, 2500).toInt();
  }

  @override
  Widget build(BuildContext context) {
    final a = AppData.i;
    return Scaffold(
      body: ShaderBackground(
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(children: [
                Glass(
                    radius: 16,
                    padding: const EdgeInsets.all(8),
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back, size: 18)),
                const SizedBox(width: 12),
                Text('CHESS ♟', style: Theme.of(context).textTheme.titleLarge),
              ]),
            ),
            const SizedBox(height: 12),
            // ---------- mode toggle ----------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                _modeChip('♟ GAME', !iqMode, () {
                  setState(() => iqMode = false);
                }),
                const SizedBox(width: 10),
                _modeChip('🧠 IQ TESTING', iqMode, () {
                  setState(() => iqMode = true);
                }),
              ]),
            ),
            const SizedBox(height: 10),
            // ---------- header card ----------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: iqMode
                  ? Glass(
                      radius: 20,
                      padding: const EdgeInsets.all(14),
                      tint: DC.magenta,
                      child: Row(children: [
                        const Text('🧠', style: TextStyle(fontSize: 30)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('IQ Set ${a.chessIqLevel}/30',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 15)),
                                Text(
                                    '15 puzzles · ~${iqBaseRating(a.chessIqLevel)} rated · 12+ to pass',
                                    style:
                                        TextStyle(fontSize: 11, color: DC.dim)),
                              ]),
                        ),
                        NeonButton(
                            label: 'START',
                            height: 40,
                            colors: [DC.magenta, DC.violet],
                            onPressed: () => _playIq(a.chessIqLevel)),
                      ]),
                    )
                  : Glass(
                      radius: 20,
                      padding: const EdgeInsets.all(14),
                      tint: DC.cyan,
                      child: Row(children: [
                        const Text('⚔️', style: TextStyle(fontSize: 30)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    '${AppData.chessLevelElo(a.chessLevel)} rating · variant ${a.chessLevel}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 15)),
                                Text(
                                    'Game ${a.chessNextGame}/5 · next bot: ${AppData.chessGameElo(a.chessLevel, a.chessNextGame)} Elo',
                                    style:
                                        TextStyle(fontSize: 11, color: DC.dim)),
                              ]),
                        ),
                        NeonButton(
                            label: 'PLAY',
                            height: 40,
                            onPressed: () => _playGame(a.chessLevel)),
                      ]),
                    ),
            ),
            const SizedBox(height: 10),
            // ---------- level grid ----------
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.95,
                ),
                itemCount: 30,
                itemBuilder: (context, i) =>
                    iqMode ? _iqCell(i + 1) : _gameCell(i + 1),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _modeChip(String label, bool sel, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: sel ? LinearGradient(colors: [DC.violet, DC.cyan]) : null,
            color: sel ? null : DC.fgo(0.06),
            border: Border.all(color: DC.fgo(0.12)),
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: sel ? FontWeight.w900 : FontWeight.w600)),
          ),
        ),
      ),
    );
  }

  // ---------------- GAME cells ----------------

  Widget _gameCell(int level) {
    final unlocked = level <= AppData.i.chessLevel;
    final done = level < AppData.i.chessLevel;
    final current = level == AppData.i.chessLevel;
    return _cell(
      unlocked: unlocked,
      done: done,
      current: current,
      emoji: done ? '👑' : (unlocked ? '♟' : '🔒'),
      title: '${AppData.chessLevelElo(level)}',
      subtitle: 'variant $level',
      accent: DC.cyan,
      progress: current ? AppData.i.chessWins / 5 : null,
      progressDots: current ? (AppData.i.chessWins, 5) : null,
      onTap: unlocked ? () => _playGame(level) : null,
    );
  }

  void _playGame(int level) {
    final isCurrent = level == AppData.i.chessLevel;
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ChessDuelScreen(
                journeyLevel: isCurrent ? level : null,
                practiceRating: isCurrent ? null : AppData.chessLevelElo(level),
                wager: 0))).then((_) => setState(() {}));
  }

  // ---------------- IQ cells ----------------

  Widget _iqCell(int level) {
    final unlocked = level <= AppData.i.chessIqLevel;
    final done = level < AppData.i.chessIqLevel;
    final current = level == AppData.i.chessIqLevel;
    return _cell(
      unlocked: unlocked,
      done: done,
      current: current,
      emoji: done ? '🏅' : (unlocked ? '🧠' : '🔒'),
      title: '${iqBaseRating(level)}',
      subtitle: 'variant $level',
      accent: DC.magenta,
      onTap: unlocked ? () => _playIq(level) : null,
    );
  }

  void _playIq(int level) {
    Navigator.push(context,
            MaterialPageRoute(builder: (_) => ChessIqScreen(level: level)))
        .then((_) => setState(() {}));
  }

  // ---------------- shared cell ----------------

  Widget _cell({
    required bool unlocked,
    required bool done,
    required bool current,
    required String emoji,
    required String title,
    required String subtitle,
    required Color accent,
    (int, int)? progressDots,
    double? progress,
    VoidCallback? onTap,
  }) {
    final color = done ? DC.lime : (current ? accent : DC.fg24);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: unlocked ? DC.fgo(0.06) : DC.fgo(0.02),
          border: Border.all(
              color: current ? accent : DC.fgo(0.10), width: current ? 1.6 : 1),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(emoji,
              style:
                  TextStyle(fontSize: 24, color: unlocked ? DC.text : DC.fg38)),
          const SizedBox(height: 4),
          Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: unlocked ? DC.text : DC.fg38)),
          Text(subtitle, style: TextStyle(fontSize: 10, color: color)),
          if (progressDots != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (var g = 0; g < progressDots.$2; g++)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: g < progressDots.$1 ? DC.lime : DC.fg24,
                    ),
                  ),
              ]),
            ),
        ]),
      ),
    );
  }
}

/// ============================================================
/// CHESS IQ SET — 15 tactic/vision questions, difficulty rising
/// inside the set. 12+ correct passes the level.
/// ============================================================
class ChessIqScreen extends StatefulWidget {
  final int level;
  const ChessIqScreen({super.key, required this.level});

  @override
  State<ChessIqScreen> createState() => _ChessIqScreenState();
}

class _ChessIqScreenState extends State<ChessIqScreen> {
  static const total = 15;
  static const passMark = 12;
  late final Random rng = Random(0xC4E5 ^ widget.level * 6151);
  late Question q;
  int index = 0;
  int correct = 0;
  bool answered = false;
  bool wasRight = false;
  bool finished = false;

  int _ratingFor(int i) {
    // inside a set the questions ramp: +12 rating per question
    final base = _ChessJourneyScreenState.iqBaseRating(widget.level);
    return (base + i * 12).clamp(800, 2500).toInt();
  }

  @override
  void initState() {
    super.initState();
    _next();
  }

  void _next() {
    if (index >= total) {
      _finish();
      return;
    }
    q = chessQuestion(_ratingFor(index), rng);
    answered = false;
    setState(() {});
  }

  void _answer(String input) {
    if (answered || finished) return;
    answered = true;
    wasRight = q.check(input);
    if (wasRight) correct++;
    setState(() {});
    Timer(Duration(milliseconds: wasRight ? 600 : 1500), () {
      if (!mounted) return;
      index++;
      _next();
    });
  }

  void _finish() {
    if (finished) return;
    finished = true;
    final a = AppData.i;
    final passed = correct >= passMark;
    var coins = 0;
    if (passed) {
      coins = 20 + widget.level * 3;
      a.addCoins(coins);
      a.addXp(15 + widget.level * 3);
      if (widget.level == a.chessIqLevel && a.chessIqLevel < 30) {
        a.chessIqLevel++;
      }
      a.recordTrainingSession('chess_iq',
          value: correct / total, type: 'answer-set');
    } else {
      a.addXp(5);
      a.recordTrainingSession('chess_iq',
          value: correct / total, type: 'answer-set');
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
            if (passed) const ConfettiBurst(height: 60),
            Text(passed ? '🏅' : '🧠', style: const TextStyle(fontSize: 44)),
            const SizedBox(height: 8),
            Text(passed ? 'SET CLEARED!' : 'NOT YET',
                style: Theme.of(context).textTheme.displayMedium),
            Text('$correct / $total correct · need $passMark to pass',
                style: TextStyle(color: DC.dim)),
            const SizedBox(height: 8),
            if (passed)
              Text(
                  '+$coins 🪙 · ${_ChessJourneyScreenState.iqBaseRating(min(widget.level + 1, 30))} unlocked',
                  style: TextStyle(color: DC.lime, fontWeight: FontWeight.w800))
            else
              Text('Run it back — the set reshuffles every attempt.',
                  style: TextStyle(color: DC.dim, fontSize: 12)),
            const SizedBox(height: 14),
            NeonButton(
                label: 'DONE',
                height: 46,
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                }),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                    child: const Icon(Icons.close, size: 18)),
                const SizedBox(width: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: index / total,
                      minHeight: 8,
                      backgroundColor: DC.fg10,
                      valueColor: AlwaysStoppedAnimation(DC.magenta),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text('${min(index + 1, total)}/$total ✓$correct',
                    style: TextStyle(fontSize: 12, color: DC.dim)),
              ]),
              const SizedBox(height: 6),
              Text(
                  'CHESS IQ · ${_ratingFor(min(index, total - 1))} rating · V${widget.level}',
                  style: TextStyle(fontSize: 11, color: DC.dim)),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(children: [
                    const SizedBox(height: 16),
                    if (q.fen != null) ...[
                      Center(child: MiniChessBoard(fen: q.fen!, size: 260)),
                      const SizedBox(height: 14),
                    ],
                    Glass(
                      radius: 24,
                      padding: const EdgeInsets.all(20),
                      border: answered
                          ? Border.all(
                              color: wasRight ? DC.lime : DC.danger, width: 2)
                          : null,
                      child: Column(children: [
                        Text(q.prompt,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: q.prompt.contains('\n') ? 15 : 17,
                                height: 1.5,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w600)),
                        if (answered && !wasRight) ...[
                          const SizedBox(height: 8),
                          Text('Answer: ${q.answer}',
                              style: TextStyle(
                                  color: DC.lime, fontWeight: FontWeight.w800)),
                          if (q.note != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(q.note!,
                                  textAlign: TextAlign.center,
                                  style:
                                      TextStyle(fontSize: 12, color: DC.dim)),
                            ),
                        ],
                      ]),
                    ),
                    const SizedBox(height: 16),
                    if (q.options != null)
                      Column(children: [
                        for (final o in q.options!)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: GhostButton(
                              label: o,
                              onPressed: answered ? null : () => _answer(o),
                            ),
                          ),
                      ]),
                    const SizedBox(height: 16),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

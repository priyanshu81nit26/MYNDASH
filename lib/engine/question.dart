import 'package:flutter/material.dart';

import '../theme_district.dart';

/// One generated question. If [options] is null the player types the answer.
class Question {
  final String prompt;
  final List<String>? options;
  final String answer;
  final int parMs;
  final String? note; // shown after answering (mini-explanation)
  /// Piece-placement FEN (ranks 8→1, '/'-separated) for questions that
  /// show a visual board — currently chess tactics. Null = no board.
  final String? fen;

  const Question({
    required this.prompt,
    this.options,
    required this.answer,
    required this.parMs,
    this.note,
    this.fen,
  });

  bool get typed => options == null;
  bool check(String input) =>
      input.trim().toLowerCase() == answer.trim().toLowerCase();
}

/// Category registry.
class Cat {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final bool board; // interactive board vs question feed
  final bool ready; // implemented in this build

  const Cat(this.id, this.name, this.icon, this.color,
      {this.board = false, this.ready = true});
}

List<Cat> get cats => <Cat>[
      // Group A/B — question feeds
      Cat('mental', 'Mental Math', Icons.bolt, DC.cyan),
      Cat('quant', 'Quant Aptitude', Icons.trending_up, DC.violet),
      Cat('numtheory', 'Number Theory', Icons.tag, DC.magenta),
      Cat('patterns', 'IQ Patterns', Icons.auto_awesome, DC.amber),
      Cat('geometry', 'Geometry', Icons.change_history, DC.lime),
      Cat('probability', 'Probability', Icons.casino, DC.cyan),
      Cat('clock', 'Clock & Calendar', Icons.schedule, DC.violet),
      Cat('knights', 'Knights & Knaves', Icons.theater_comedy, DC.magenta),
      // Group C/D — boards
      Cat('sudoku', 'Sudoku', Icons.grid_4x4, DC.cyan, board: true),
      Cat('mines', 'Minesweeper', Icons.flag, DC.danger, board: true),
      Cat('sliding', 'Sliding Tile', Icons.swap_horiz, DC.amber, board: true),
      Cat('hanoi', 'Tower of Hanoi', Icons.layers, DC.violet, board: true),
      Cat('memory', 'Memory Matrix', Icons.psychology, DC.lime, board: true),
      Cat('kenken', 'KenKen', Icons.calculate, DC.magenta, board: true),
      Cat('nonogram', 'Nonograms', Icons.blur_on, DC.cyan, board: true),
      Cat('kakuro', 'Kakuro', Icons.grid_on, DC.amber, board: true),
      Cat('logicgrid', 'Logic Grid', Icons.rule, DC.violet, board: true),
      Cat('setgame', 'Set Cards', Icons.style, DC.lime, board: true),
      Cat('river', 'River Crossing', Icons.sailing, DC.cyan, board: true),
      // Group B — more feeds
      Cat('crypta', 'Cryptarithms', Icons.abc, DC.amber),
      Cat('words', 'Word Problems', Icons.menu_book, DC.lime),
      Cat('finance', 'Speed Finance', Icons.currency_rupee, DC.amber),
      // Coming soon
      Cat('syllogism', 'Syllogisms', Icons.account_tree, DC.dim, ready: false),
      Cat('data', 'Data Interpretation', Icons.bar_chart, DC.dim, ready: false),
    ];

Cat catById(String id) => cats.firstWhere((c) => c.id == id,
    orElse: () => Cat(
        id, id == 'speedmath' ? 'Speed Maths' : 'Mixed', Icons.bolt, DC.cyan));

/// All Solve levels: 800, 900 … 2500.
final levels = List<int>.generate(18, (i) => 800 + i * 100);

/// Difficulty scalar 0..1 for a rating.
double d01(int rating) => ((rating - 800) / 1700).clamp(0.0, 1.0).toDouble();

/// Par time shrinks as rating grows.
int parMsFor(int rating, int baseMs) =>
    (baseMs * (1.0 - 0.35 * d01(rating))).round();

/// Stars from accuracy + pace. [onPar] = fraction of answers inside par.
int starsFor(double accuracy, double onPar) {
  if (accuracy >= 0.95 && onPar >= 0.6) return 3;
  if (accuracy >= 0.80) return 2;
  if (accuracy >= 0.60) return 1;
  return 0;
}

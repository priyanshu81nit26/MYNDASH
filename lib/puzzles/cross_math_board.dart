import 'dart:math';

import 'package:flutter/material.dart';

import '../core/fx.dart';
import '../theme_district.dart';
import '../ui/glass.dart';

class CrossMathSpec {
  final int size;
  final Map<int, String> tokens;
  final Map<int, int> answers;
  final Set<int> editable;

  const CrossMathSpec({
    required this.size,
    required this.tokens,
    required this.answers,
    required this.editable,
  });
}

/// Builds a six-equation arithmetic crossword.
///
/// Equations turn corners through shared answers, so every missing number is
/// constrained by a real horizontal or vertical crossing.
CrossMathSpec generateCrossMath({
  required int rating,
  required int seed,
}) {
  const size = 9;
  final rng = Random(seed);
  final allowed = rating < 1100
      ? const ['+']
      : rating < 1500
          ? const ['+', '−']
          : rating < 1800
              ? const ['+', '−', '×']
              : const ['+', '−', '×', '÷'];
  final ops = List<String>.generate(
    6,
    (index) => allowed[(index + rng.nextInt(allowed.length)) % allowed.length],
  );
  if (allowed.contains('÷')) ops[seed.abs() % ops.length] = '÷';
  if (allowed.contains('−')) ops[(seed.abs() + 2) % ops.length] = '−';

  final maxBase = rating < 1300
      ? 9
      : rating < 1900
          ? 14
          : 20;
  final first = _initialEquation(ops[0], rng, maxBase);
  final second = _forwardEquation(first.$3, ops[1], rng, maxBase);
  final third = _targetEquation(second.$3, ops[2], rng, maxBase);
  final fourth = _forwardEquation(third.$1, ops[3], rng, maxBase);
  final fifth = _forwardEquation(fourth.$3, ops[4], rng, maxBase);
  final sixth = _forwardEquation(fifth.$3, ops[5], rng, maxBase);

  final tokens = <int, String>{};
  final answers = <int, int>{};

  void place(
    List<int> cells,
    (int, int, int) equation,
    String op,
  ) {
    answers[cells[0]] = equation.$1;
    tokens[cells[1]] = op;
    answers[cells[2]] = equation.$2;
    tokens[cells[3]] = '=';
    answers[cells[4]] = equation.$3;
  }

  place([0, 1, 2, 3, 4], first, ops[0]);
  place([4, 13, 22, 31, 40], second, ops[1]);
  place([36, 37, 38, 39, 40], third, ops[2]);
  place([36, 45, 54, 63, 72], fourth, ops[3]);
  place([72, 73, 74, 75, 76], fifth, ops[4]);
  place([76, 77, 78, 79, 80], sixth, ops[5]);

  for (final entry in answers.entries) {
    tokens[entry.key] = '${entry.value}';
  }

  final numberCells = answers.keys.toList()..shuffle(rng);
  final blankCount = (4 + ((rating - 800) / 300).floor())
      .clamp(4, max(4, numberCells.length - 4))
      .toInt();
  final editable = numberCells.take(blankCount).toSet();

  return CrossMathSpec(
    size: size,
    tokens: tokens,
    answers: answers,
    editable: editable,
  );
}

(int, int, int) _initialEquation(String op, Random rng, int high) {
  switch (op) {
    case '−':
      final right = 1 + rng.nextInt(max(2, high ~/ 2));
      final result = 1 + rng.nextInt(max(2, high));
      return (result + right, right, result);
    case '×':
      final left = 2 + rng.nextInt(max(2, min(9, high) - 1));
      final right = 2 + rng.nextInt(max(2, min(9, high) - 1));
      return (left, right, left * right);
    case '÷':
      final result = 2 + rng.nextInt(max(2, min(9, high) - 1));
      final right = 2 + rng.nextInt(max(2, min(9, high) - 1));
      return (result * right, right, result);
    default:
      final left = 1 + rng.nextInt(high);
      final right = 1 + rng.nextInt(high);
      return (left, right, left + right);
  }
}

(int, int, int) _forwardEquation(
  int left,
  String op,
  Random rng,
  int high,
) {
  switch (op) {
    case '−':
      if (left <= 1) {
        final right = 1 + rng.nextInt(high);
        return (left, right, left - right);
      }
      final right = 1 + rng.nextInt(max(1, min(high, left - 1)));
      return (left, right, left - right);
    case '×':
      final right = 2 + rng.nextInt(max(2, min(9, high) - 1));
      return (left, right, left * right);
    case '÷':
      final divisors = <int>[
        for (var value = 2; value <= min(9, left); value++)
          if (left % value == 0) value,
      ];
      final right =
          divisors.isEmpty ? 1 : divisors[rng.nextInt(divisors.length)];
      return (left, right, left ~/ right);
    default:
      final right = 1 + rng.nextInt(high);
      return (left, right, left + right);
  }
}

(int, int, int) _targetEquation(
  int target,
  String op,
  Random rng,
  int high,
) {
  switch (op) {
    case '−':
      final right = 1 + rng.nextInt(high);
      return (target + right, right, target);
    case '×':
      final factors = <int>[
        for (var value = 2; value <= min(9, target); value++)
          if (target % value == 0) value,
      ];
      if (factors.isEmpty) return (target, 1, target);
      final right = factors[rng.nextInt(factors.length)];
      return (target ~/ right, right, target);
    case '÷':
      final right = 2 + rng.nextInt(max(2, min(9, high) - 1));
      return (target * right, right, target);
    default:
      if (target <= 1) return (target, 0, target);
      final right = 1 + rng.nextInt(min(high, target - 1));
      return (target - right, right, target);
  }
}

class CrossMathBoard extends StatefulWidget {
  final int rating;
  final int seed;
  final bool kids;
  final VoidCallback onSolved;
  final ValueChanged<double>? onProgress;

  const CrossMathBoard({
    super.key,
    required this.rating,
    required this.seed,
    required this.onSolved,
    this.kids = false,
    this.onProgress,
  });

  @override
  State<CrossMathBoard> createState() => _CrossMathBoardState();
}

class _CrossMathBoardState extends State<CrossMathBoard> {
  late final CrossMathSpec spec =
      generateCrossMath(rating: widget.rating, seed: widget.seed);
  late final Map<int, int?> filled = {
    for (final index in spec.editable) index: null,
  };
  late final List<int> chips = _buildChips();
  int? selected;
  int? wrong;
  int mistakes = 0;
  bool finished = false;

  @override
  void initState() {
    super.initState();
    selected = spec.editable.first;
  }

  List<int> _buildChips() {
    final rng = Random(widget.seed ^ 0xC2055);
    final values = <int>{
      for (final index in spec.editable) spec.answers[index]!
    };
    final ceiling = values.isEmpty ? 20 : values.reduce(max) + 12;
    while (values.length < min(12, spec.editable.length + 5)) {
      values.add(1 + rng.nextInt(max(8, ceiling)));
    }
    return values.toList()..shuffle(rng);
  }

  void _place(int value) {
    final index = selected;
    if (index == null || finished) return;
    if (spec.answers[index] != value) {
      Fx.fail();
      setState(() {
        wrong = index;
        mistakes++;
      });
      Future<void>.delayed(const Duration(milliseconds: 450), () {
        if (mounted && wrong == index) setState(() => wrong = null);
      });
      return;
    }

    Fx.success();
    setState(() {
      filled[index] = value;
      wrong = null;
      selected = spec.editable.cast<int?>().firstWhere(
            (cell) => filled[cell] == null,
            orElse: () => null,
          );
    });
    final solved = filled.values.whereType<int>().length;
    widget.onProgress?.call(solved / spec.editable.length);
    if (solved == spec.editable.length) {
      finished = true;
      widget.onSolved();
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.kids ? DC.lime : DC.amber;
    final solved = filled.values.whereType<int>().length;
    return Column(children: [
      Glass(
        radius: 20,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        tint: accent,
        child: Row(children: [
          Icon(Icons.calculate_rounded, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ARITHMETIC CROSS',
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  'Six linked equations share their crossing numbers.',
                  style: TextStyle(fontSize: 10, color: DC.dim),
                ),
              ],
            ),
          ),
          Text(
            '$solved/${spec.editable.length}',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
        ]),
      ),
      const SizedBox(height: 10),
      Expanded(
        child: Center(
          child: AspectRatio(
            aspectRatio: 1,
            child: Glass(
              radius: 22,
              padding: const EdgeInsets.all(7),
              tint: accent,
              child: Column(children: [
                for (var row = 0; row < spec.size; row++)
                  Expanded(
                    child: Row(children: [
                      for (var col = 0; col < spec.size; col++)
                        Expanded(child: _cell(row * spec.size + col, accent)),
                    ]),
                  ),
              ]),
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Row(children: [
        Icon(Icons.info_outline_rounded, size: 16, color: DC.dim),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            mistakes == 0
                ? 'Gold cells are missing. Given numbers stay dark; correct answers turn green.'
                : '$mistakes attempt${mistakes == 1 ? '' : 's'} missed. Recheck both crossing equations.',
            style: TextStyle(fontSize: 10, color: DC.dim),
          ),
        ),
      ]),
      const SizedBox(height: 9),
      SizedBox(
        height: 104,
        child: SingleChildScrollView(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final value in chips)
                SizedBox(
                  width: 52,
                  height: 48,
                  child: FilledButton(
                    onPressed: selected == null ? null : () => _place(value),
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: accent.withOpacity(0.82),
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                      '$value',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ]);
  }

  Widget _cell(int index, Color accent) {
    final token = spec.tokens[index];
    if (token == null) return const SizedBox.expand();
    final editable = spec.editable.contains(index);
    final value = editable ? filled[index] : spec.answers[index];
    final operator = !spec.answers.containsKey(index);
    final active = selected == index;
    final correct = editable && value != null;
    final isWrong = wrong == index;

    if (operator) {
      return Center(
        child: Text(
          token,
          style: TextStyle(
            color: token == '=' ? DC.dim : accent,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
    }

    return Semantics(
      button: editable,
      selected: active,
      label: editable
          ? value == null
              ? 'Missing number${active ? ', selected' : ''}'
              : 'Correct number $value'
          : 'Given number $value',
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: editable && !correct
            ? () => setState(() {
                  selected = index;
                  wrong = null;
                })
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            color: isWrong
                ? DC.danger.withOpacity(0.25)
                : correct
                    ? DC.lime.withOpacity(0.22)
                    : editable
                        ? accent.withOpacity(active ? 0.22 : 0.10)
                        : DC.fgo(0.08),
            border: Border.all(
              color: isWrong
                  ? DC.danger
                  : correct
                      ? DC.lime
                      : active
                          ? accent
                          : editable
                              ? accent.withOpacity(0.55)
                              : DC.fgo(0.14),
              width: active || isWrong ? 2 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: value == null
              ? Icon(Icons.question_mark_rounded, size: 15, color: accent)
              : Text(
                  '$value',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: correct ? DC.lime : DC.text,
                  ),
                ),
        ),
      ),
    );
  }
}

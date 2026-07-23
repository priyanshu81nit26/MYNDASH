import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../engine/mind_engines.dart';
import '../theme_district.dart';
import '../ui/glass.dart';
import 'contest_bank.dart';

class ContestSudokuRound extends StatefulWidget {
  final SudokuPuzzle puzzle;
  final VoidCallback onSolved;

  const ContestSudokuRound({
    super.key,
    required this.puzzle,
    required this.onSolved,
  });

  @override
  State<ContestSudokuRound> createState() => _ContestSudokuRoundState();
}

class _ContestSudokuRoundState extends State<ContestSudokuRound> {
  late final List<int> _cells = List<int>.from(widget.puzzle.given);
  int _selected = -1;
  int _mistakes = 0;
  bool _complete = false;

  void _enter(int value) {
    if (_complete || _selected < 0 || widget.puzzle.given[_selected] != 0) {
      return;
    }
    setState(() {
      _cells[_selected] = value;
      if (value != widget.puzzle.solution[_selected]) _mistakes++;
    });
    if (_cells.asMap().entries.every(
          (entry) => entry.value == widget.puzzle.solution[entry.key],
        )) {
      _complete = true;
      widget.onSolved();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _GameDirection(
          icon: Icons.grid_4x4_rounded,
          title: 'Complete the 9×9 grid',
          message:
              'Every row, column and 3×3 box must contain 1–9 exactly once.',
          accent: DC.cyan,
          trailing: '$_mistakes checks',
        ),
        const SizedBox(height: 12),
        Flexible(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: AspectRatio(
                aspectRatio: 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: DC.bg2.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: DC.fg24),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final side = constraints.maxWidth / 9;
                      return Stack(
                        children: [
                          GridView.builder(
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 9,
                            ),
                            itemCount: 81,
                            itemBuilder: (context, index) {
                              final value = _cells[index];
                              final given = widget.puzzle.given[index] != 0;
                              final selected = index == _selected;
                              final wrong = value != 0 &&
                                  value != widget.puzzle.solution[index];
                              return InkWell(
                                onTap: given
                                    ? null
                                    : () => setState(() => _selected = index),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? DC.cyan.withValues(alpha: 0.16)
                                        : wrong
                                            ? DC.danger.withValues(alpha: 0.10)
                                            : Colors.transparent,
                                    border: Border(
                                      right: BorderSide(
                                        color:
                                            (index % 9 == 2 || index % 9 == 5)
                                                ? DC.fg54
                                                : DC.fg12,
                                        width:
                                            (index % 9 == 2 || index % 9 == 5)
                                                ? 1.5
                                                : 0.6,
                                      ),
                                      bottom: BorderSide(
                                        color:
                                            (index ~/ 9 == 2 || index ~/ 9 == 5)
                                                ? DC.fg54
                                                : DC.fg12,
                                        width:
                                            (index ~/ 9 == 2 || index ~/ 9 == 5)
                                                ? 1.5
                                                : 0.6,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    value == 0 ? '' : '$value',
                                    style: TextStyle(
                                      fontSize: side < 38 ? 14 : 18,
                                      fontWeight: given
                                          ? FontWeight.w900
                                          : FontWeight.w700,
                                      color: wrong
                                          ? DC.danger
                                          : given
                                              ? DC.text
                                              : DC.cyan,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          if (_complete)
                            ColoredBox(
                              color: DC.bg2.withValues(alpha: 0.86),
                              child: Center(
                                child: Icon(
                                  Icons.check_circle_rounded,
                                  size: 72,
                                  color: DC.lime,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: [
            for (var value = 1; value <= 9; value++)
              SizedBox(
                width: 42,
                height: 42,
                child: OutlinedButton(
                  onPressed: _complete ? null : () => _enter(value),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                  ),
                  child: Text(
                    '$value',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            SizedBox(
              width: 48,
              height: 42,
              child: IconButton.outlined(
                tooltip: 'Erase cell',
                onPressed: _selected < 0 ||
                        widget.puzzle.given[_selected] != 0 ||
                        _complete
                    ? null
                    : () => setState(() => _cells[_selected] = 0),
                icon: const Icon(Icons.backspace_outlined, size: 17),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class ContestHanoiRound extends StatefulWidget {
  final int discs;
  final VoidCallback onSolved;

  const ContestHanoiRound({
    super.key,
    required this.discs,
    required this.onSolved,
  });

  @override
  State<ContestHanoiRound> createState() => _ContestHanoiRoundState();
}

class _ContestHanoiRoundState extends State<ContestHanoiRound> {
  late final List<List<int>> _rods = [
    List<int>.generate(widget.discs, (index) => widget.discs - index),
    <int>[],
    <int>[],
  ];
  int? _selectedRod;
  int _moves = 0;
  bool _complete = false;

  int get _minimum => math.pow(2, widget.discs).toInt() - 1;

  void _tapRod(int rod) {
    if (_complete) return;
    if (_selectedRod == null) {
      if (_rods[rod].isNotEmpty) setState(() => _selectedRod = rod);
      return;
    }
    final from = _selectedRod!;
    if (from == rod) {
      setState(() => _selectedRod = null);
      return;
    }
    final disc = _rods[from].last;
    if (_rods[rod].isNotEmpty && _rods[rod].last < disc) {
      setState(() => _selectedRod = null);
      return;
    }
    setState(() {
      _rods[from].removeLast();
      _rods[rod].add(disc);
      _selectedRod = null;
      _moves++;
    });
    if (_rods[2].length == widget.discs) {
      _complete = true;
      widget.onSolved();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _GameDirection(
          icon: Icons.layers_rounded,
          title: 'Move the tower to rod C',
          message:
              'Tap a source rod → destination rod. Never place a larger disc on a smaller one.',
          accent: DC.violet,
          trailing: '$_moves / $_minimum min',
        ),
        const SizedBox(height: 20),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620, maxHeight: 390),
              child: Glass(
                radius: 28,
                padding: const EdgeInsets.fromLTRB(12, 22, 12, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var rod = 0; rod < 3; rod++)
                      Expanded(
                        child: _HanoiRod(
                          label: String.fromCharCode(65 + rod),
                          discs: _rods[rod],
                          totalDiscs: widget.discs,
                          selected: _selectedRod == rod,
                          complete: _complete && rod == 2,
                          onTap: () => _tapRod(rod),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _selectedRod == null
              ? 'SELECT A ROD WITH A TOP DISC'
              : 'NOW SELECT ITS DESTINATION  →',
          style: TextStyle(
            color: _selectedRod == null ? DC.dim : DC.violet,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

class _HanoiRod extends StatelessWidget {
  final String label;
  final List<int> discs;
  final int totalDiscs;
  final bool selected;
  final bool complete;
  final VoidCallback onTap;

  const _HanoiRod({
    required this.label,
    required this.discs,
    required this.totalDiscs,
    required this.selected,
    required this.complete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Rod $label, ${discs.length} discs',
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: selected
                ? DC.violet.withValues(alpha: 0.13)
                : complete
                    ? DC.lime.withValues(alpha: 0.12)
                    : DC.fg10,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? DC.violet
                  : complete
                      ? DC.lime
                      : DC.fg12,
              width: selected || complete ? 1.5 : 1,
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final usable = constraints.maxWidth - 12;
              final discHeight =
                  math.min(28.0, (constraints.maxHeight - 52) / totalDiscs);
              return Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  Positioned(
                    top: 34,
                    bottom: 20,
                    child: Container(
                      width: 5,
                      decoration: BoxDecoration(
                        color: DC.fg24,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 20,
                    child: Container(
                      height: 5,
                      decoration: BoxDecoration(
                        color: DC.fg38,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  for (var index = 0; index < discs.length; index++)
                    Positioned(
                      bottom: 24 + index * discHeight,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        width: usable *
                            (0.34 +
                                0.62 * discs[index] / math.max(1, totalDiscs)),
                        height: math.max(14, discHeight - 3),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              DC.violet,
                              Color.lerp(DC.violet, DC.cyan, 0.55)!,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: DC.violet.withValues(alpha: 0.22),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                  Positioned(
                    top: 4,
                    child: Text(
                      label,
                      style: TextStyle(
                        color: selected ? DC.violet : DC.dim,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class ContestNumWordsRound extends StatefulWidget {
  final NumWordsPuzzle puzzle;
  final VoidCallback onSolved;

  const ContestNumWordsRound({
    super.key,
    required this.puzzle,
    required this.onSolved,
  });

  @override
  State<ContestNumWordsRound> createState() => _ContestNumWordsRoundState();
}

class _ContestNumWordsRoundState extends State<ContestNumWordsRound> {
  final List<int> _chosen = [];
  int _attempts = 0;
  bool _complete = false;

  Future<void> _choose(int value) async {
    if (_complete || _chosen.contains(value)) return;
    setState(() => _chosen.add(value));
    if (_chosen.length != widget.puzzle.correctOrder.length) return;
    if (_same(_chosen, widget.puzzle.correctOrder)) {
      _complete = true;
      widget.onSolved();
      return;
    }
    setState(() => _attempts++);
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (mounted && !_complete) setState(_chosen.clear);
  }

  bool _same(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _GameDirection(
          icon: Icons.spellcheck_rounded,
          title: 'Sort by number word',
          message:
              'Tap the numbers in alphabetical order of their English names—not numerical order.',
          accent: DC.amber,
          trailing: '$_attempts resets',
        ),
        const SizedBox(height: 18),
        Glass(
          radius: 24,
          tint: DC.amber,
          child: Row(
            children: [
              _MiniToken(label: '8', color: DC.amber),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 9),
                child: Icon(Icons.arrow_forward_rounded, color: DC.dim),
              ),
              const Expanded(
                child: Text(
                  'EIGHT  →  compare “E”',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            for (final value in widget.puzzle.values)
              _NumberWordTile(
                value: value,
                position: _chosen.indexOf(value),
                complete: _complete,
                onTap: () => _choose(value),
              ),
          ],
        ),
        const SizedBox(height: 24),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 240),
          child: _chosen.isEmpty
              ? Text(
                  'FIRST LETTER WINS THE SORT',
                  key: const ValueKey('empty'),
                  style: TextStyle(
                    color: DC.dim,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                )
              : Wrap(
                  key: ValueKey(_chosen.join('-')),
                  spacing: 5,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (var i = 0; i < _chosen.length; i++) ...[
                      Chip(
                        label: Text(
                          '${_chosen[i]} · ${numberWord(_chosen[i]).toUpperCase()}',
                        ),
                      ),
                      if (i < _chosen.length - 1)
                        Icon(Icons.arrow_forward_rounded,
                            size: 16, color: DC.amber),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _NumberWordTile extends StatelessWidget {
  final int value;
  final int position;
  final bool complete;
  final VoidCallback onTap;

  const _NumberWordTile({
    required this.value,
    required this.position,
    required this.complete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final selected = position >= 0;
    return SizedBox(
      width: 92,
      height: 92,
      child: FilledButton(
        onPressed: selected || complete ? null : onTap,
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: selected
              ? DC.amber.withValues(alpha: 0.20)
              : DC.bg2.withValues(alpha: 0.84),
          foregroundColor: selected ? DC.amber : DC.text,
          disabledBackgroundColor: selected
              ? DC.amber.withValues(alpha: 0.18)
              : DC.lime.withValues(alpha: 0.15),
          disabledForegroundColor: selected ? DC.amber : DC.lime,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
            side: BorderSide(
              color: selected ? DC.amber : DC.fg24,
            ),
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Text(
                '$value',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (selected)
              Positioned(
                top: 8,
                right: 9,
                child: CircleAvatar(
                  radius: 10,
                  backgroundColor: DC.amber,
                  foregroundColor: DC.bg2,
                  child: Text(
                    '${position + 1}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ContestSignalPathRound extends StatefulWidget {
  final SignalPathPuzzle puzzle;
  final VoidCallback onSolved;

  const ContestSignalPathRound({
    super.key,
    required this.puzzle,
    required this.onSolved,
  });

  @override
  State<ContestSignalPathRound> createState() => _ContestSignalPathRoundState();
}

class _ContestSignalPathRoundState extends State<ContestSignalPathRound> {
  late final List<int> _selected = widget.puzzle.path.take(3).toList();
  int _misses = 0;
  bool _complete = false;

  void _tap(int cell) {
    if (_complete || _selected.contains(cell)) return;
    final expected = widget.puzzle.path[_selected.length];
    if (cell != expected) {
      setState(() => _misses++);
      return;
    }
    setState(() => _selected.add(cell));
    if (_selected.length == widget.puzzle.path.length) {
      _complete = true;
      widget.onSolved();
    }
  }

  @override
  Widget build(BuildContext context) {
    final stepText = widget.puzzle.steps.map((step) => '+$step').join(' → ');
    return Column(
      children: [
        _GameDirection(
          icon: Icons.route_rounded,
          title: 'Continue the signal path',
          message:
              'The first three nodes are connected. Infer the repeating step rule, then tap adjacent nodes to finish it.',
          accent: DC.magenta,
          trailing: '$_misses misses',
        ),
        const SizedBox(height: 14),
        Text(
          'HIDDEN CYCLE  ·  ${widget.puzzle.steps.length} REPEATING STEPS',
          style: TextStyle(
            color: DC.dim,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _complete ? stepText : 'Observe the connected values',
          style: TextStyle(
            color: _complete ? DC.lime : DC.magenta,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 18),
        Flexible(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 490),
              child: AspectRatio(
                aspectRatio: 1,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final side = constraints.maxWidth;
                    return Stack(
                      children: [
                        CustomPaint(
                          size: Size.square(side),
                          painter: _SignalArrowPainter(
                            path: _selected,
                            color: _complete ? DC.lime : DC.magenta,
                          ),
                        ),
                        GridView.builder(
                          padding: EdgeInsets.zero,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemCount: 16,
                          itemBuilder: (context, index) {
                            final order = _selected.indexOf(index);
                            final selected = order >= 0;
                            return Semantics(
                              button: true,
                              label:
                                  'Signal ${widget.puzzle.cells[index]}${selected ? ', path position ${order + 1}' : ''}',
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () => _tap(index),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 220),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? (_complete ? DC.lime : DC.magenta)
                                            .withValues(alpha: 0.18)
                                        : DC.bg2.withValues(alpha: 0.82),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: selected
                                          ? (_complete ? DC.lime : DC.magenta)
                                          : DC.fg24,
                                      width: selected ? 2 : 1,
                                    ),
                                    boxShadow: selected
                                        ? [
                                            BoxShadow(
                                              color: (_complete
                                                      ? DC.lime
                                                      : DC.magenta)
                                                  .withValues(alpha: 0.16),
                                              blurRadius: 12,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Stack(
                                    children: [
                                      Center(
                                        child: Text(
                                          '${widget.puzzle.cells[index]}',
                                          style: TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w900,
                                            color: selected
                                                ? (_complete
                                                    ? DC.lime
                                                    : DC.magenta)
                                                : DC.text,
                                          ),
                                        ),
                                      ),
                                      if (selected)
                                        Positioned(
                                          top: 6,
                                          left: 7,
                                          child: Text(
                                            '${order + 1}',
                                            style: TextStyle(
                                              color: _complete
                                                  ? DC.lime
                                                  : DC.magenta,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'GIVEN',
              style: TextStyle(
                color: DC.dim,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9),
              child: Icon(Icons.arrow_forward_rounded,
                  color: DC.magenta, size: 18),
            ),
            Text(
              'INFER RULE',
              style: TextStyle(
                color: DC.magenta,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 9),
              child: Icon(Icons.arrow_forward_rounded,
                  color: DC.magenta, size: 18),
            ),
            Text(
              'TAP PATH',
              style: TextStyle(
                color: DC.text,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SignalArrowPainter extends CustomPainter {
  final List<int> path;
  final Color color;

  const _SignalArrowPainter({required this.path, required this.color});

  Offset _center(int cell, Size size) {
    const gap = 10.0;
    final cellSide = (size.width - gap * 3) / 4;
    final row = cell ~/ 4;
    final col = cell % 4;
    return Offset(
      col * (cellSide + gap) + cellSide / 2,
      row * (cellSide + gap) + cellSide / 2,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (path.length < 2) return;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.72)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (var i = 1; i < path.length; i++) {
      final from = _center(path[i - 1], size);
      final to = _center(path[i], size);
      final vector = to - from;
      final length = vector.distance;
      if (length == 0) continue;
      final unit = vector / length;
      final start = from + unit * 30;
      final end = to - unit * 30;
      canvas.drawLine(start, end, paint);
      final angle = math.atan2(unit.dy, unit.dx);
      const arrow = 8.0;
      final p1 = end -
          Offset(
            math.cos(angle - math.pi / 6) * arrow,
            math.sin(angle - math.pi / 6) * arrow,
          );
      final p2 = end -
          Offset(
            math.cos(angle + math.pi / 6) * arrow,
            math.sin(angle + math.pi / 6) * arrow,
          );
      canvas.drawLine(end, p1, paint);
      canvas.drawLine(end, p2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignalArrowPainter oldDelegate) =>
      oldDelegate.path.length != path.length || oldDelegate.color != color;
}

class _GameDirection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color accent;
  final String trailing;

  const _GameDirection({
    required this.icon,
    required this.title,
    required this.message,
    required this.accent,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Glass(
      radius: 22,
      padding: const EdgeInsets.all(14),
      tint: accent,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: TextStyle(color: DC.dim, fontSize: 11, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            trailing,
            style: TextStyle(
              color: accent,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniToken extends StatelessWidget {
  final String label;
  final Color color;

  const _MiniToken({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w900),
      ),
    );
  }
}

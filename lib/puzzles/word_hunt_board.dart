import 'dart:math';

import 'package:flutter/material.dart';

import '../core/fx.dart';
import '../engine/word_grid.dart';
import '../engine/wordlist.dart';
import '../theme_district.dart';
import '../ui/glass.dart';

/// A seeded, open-ended word board.
///
/// Unlike a clue crossword, players are never asked for one predetermined
/// answer. The generator weaves several dictionary words through the grid,
/// but any valid 3-5 letter word made from adjacent cells is accepted.
class WordHuntBoard extends StatefulWidget {
  final int rating;
  final int seed;
  final int? targetWords;
  final bool kids;
  final VoidCallback onSolved;
  final ValueChanged<double>? onProgress;

  const WordHuntBoard({
    super.key,
    required this.rating,
    required this.seed,
    required this.onSolved,
    this.targetWords,
    this.kids = false,
    this.onProgress,
  });

  @override
  State<WordHuntBoard> createState() => _WordHuntBoardState();
}

class _WordHuntBoardState extends State<WordHuntBoard> {
  late final int target = widget.targetWords ??
      (widget.rating < 1300
          ? 4
          : widget.rating < 1900
              ? 5
              : 6);
  late final int size = widget.rating < 1300
      ? 4
      : widget.rating < 2000
          ? 5
          : 6;
  late final WordGridSpec spec = WordGridGenerator.generate(
    size: size,
    seed: widget.seed,
    minimumWords: target + 3,
  );

  final List<int> selected = [];
  final Set<String> found = {};
  String message = 'Drag across neighbouring letters, or tap a path.';
  bool invalid = false;
  bool finished = false;

  String get currentWord =>
      selected.map((index) => spec.letters[index]).join().toUpperCase();

  bool _adjacent(int a, int b) {
    final ar = a ~/ size;
    final ac = a % size;
    final br = b ~/ size;
    final bc = b % size;
    return (ar - br).abs() <= 1 &&
        (ac - bc).abs() <= 1 &&
        (ar != br || ac != bc);
  }

  int? _cellAt(Offset position, double side) {
    if (position.dx < 0 ||
        position.dy < 0 ||
        position.dx >= side ||
        position.dy >= side) {
      return null;
    }
    final cell = side / size;
    final col = (position.dx / cell).floor();
    final row = (position.dy / cell).floor();
    return row * size + col;
  }

  void _startPath(int? index) {
    if (index == null || finished) return;
    Fx.light();
    setState(() {
      selected
        ..clear()
        ..add(index);
      invalid = false;
      message = 'Keep moving through touching letters.';
    });
  }

  void _extendPath(int? index) {
    if (index == null || finished || selected.isEmpty) return;
    if (index == selected.last) return;
    if (selected.length > 1 && index == selected[selected.length - 2]) {
      setState(() => selected.removeLast());
      return;
    }
    if (selected.contains(index) || !_adjacent(selected.last, index)) return;
    Fx.light();
    setState(() => selected.add(index));
  }

  void _tapCell(int index) {
    if (finished) return;
    if (selected.isEmpty) {
      _startPath(index);
      return;
    }
    if (selected.last == index) {
      _submit();
      return;
    }
    _extendPath(index);
  }

  void _clear() {
    if (selected.isEmpty || finished) return;
    setState(() {
      selected.clear();
      invalid = false;
      message = 'Path cleared. Try another trail.';
    });
  }

  void _submit() {
    if (finished || selected.isEmpty) return;
    final word = currentWord.toLowerCase();
    if (word.length < 3) {
      Fx.fail();
      setState(() {
        invalid = true;
        message = 'Words need at least 3 letters.';
      });
      return;
    }
    if (!wordSet.contains(word)) {
      Fx.fail();
      setState(() {
        invalid = true;
        message = '${word.toUpperCase()} is not in the game dictionary.';
      });
      return;
    }
    if (found.contains(word)) {
      Fx.light();
      setState(() {
        invalid = true;
        message = '${word.toUpperCase()} was already found.';
      });
      return;
    }

    Fx.success();
    setState(() {
      found.add(word);
      selected.clear();
      invalid = false;
      message = found.length >= target
          ? 'Word target cleared.'
          : 'Valid word! Find ${target - found.length} more.';
    });
    widget.onProgress?.call((found.length / target).clamp(0, 1));
    if (found.length >= target) {
      finished = true;
      widget.onSolved();
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.kids ? DC.violet : DC.cyan;
    return Column(children: [
      Glass(
        radius: 20,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        tint: accent,
        child: Row(children: [
          Icon(Icons.auto_awesome_rounded, color: accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FIND ANY REAL WORD',
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  '${spec.guaranteedWords.length}+ valid trails are woven into this board.',
                  style: TextStyle(color: DC.dim, fontSize: 10),
                ),
              ],
            ),
          ),
          Text(
            '${found.length}/$target',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
        ]),
      ),
      const SizedBox(height: 10),
      Expanded(
        child: Center(
          child: AspectRatio(
            aspectRatio: 1,
            child: LayoutBuilder(builder: (context, box) {
              final side = min(box.maxWidth, box.maxHeight);
              return Semantics(
                label:
                    '$size by $size open word board. Make words from touching letters.',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (details) =>
                      _startPath(_cellAt(details.localPosition, side)),
                  onPanUpdate: (details) =>
                      _extendPath(_cellAt(details.localPosition, side)),
                  onPanEnd: (_) => _submit(),
                  child: Stack(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            accent.withOpacity(0.28),
                            DC.violet.withOpacity(0.12),
                            DC.fgo(0.04),
                          ],
                        ),
                        border: Border.all(color: accent.withOpacity(0.55)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.28),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(children: [
                        for (var row = 0; row < size; row++)
                          Expanded(
                            child: Row(children: [
                              for (var col = 0; col < size; col++)
                                Expanded(
                                    child: _cell(row * size + col, accent)),
                            ]),
                          ),
                      ]),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: CustomPaint(
                            painter: _WordTrailPainter(
                              selected: selected,
                              size: size,
                              color: accent,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ]),
                ),
              );
            }),
          ),
        ),
      ),
      const SizedBox(height: 8),
      AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: invalid ? DC.danger.withOpacity(0.12) : DC.fgo(0.05),
          border: Border.all(
            color: invalid ? DC.danger : accent.withOpacity(0.35),
          ),
        ),
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currentWord.isEmpty ? 'YOUR WORD' : currentWord,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w900,
                    color: invalid ? DC.danger : DC.text,
                  ),
                ),
                Text(message, style: TextStyle(fontSize: 10, color: DC.dim)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Clear selected letters',
            onPressed: selected.isEmpty ? null : _clear,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 4),
          SizedBox(
            height: 44,
            child: FilledButton.icon(
              onPressed: selected.isEmpty ? null : _submit,
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('WORD'),
            ),
          ),
        ]),
      ),
      if (found.isNotEmpty) ...[
        const SizedBox(height: 8),
        SizedBox(
          height: 32,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final word in found)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Chip(
                    visualDensity: VisualDensity.compact,
                    avatar: Icon(Icons.check_circle_rounded,
                        size: 15, color: DC.lime),
                    label: Text(word.toUpperCase()),
                  ),
                ),
            ],
          ),
        ),
      ],
    ]);
  }

  Widget _cell(int index, Color accent) {
    final order = selected.indexOf(index);
    final active = order >= 0;
    return Semantics(
      button: true,
      selected: active,
      label:
          'Letter ${spec.letters[index].toUpperCase()}${active ? ', selected ${order + 1}' : ''}',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _tapCell(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors:
                  active ? [accent, DC.violet] : [DC.fgo(0.13), DC.fgo(0.055)],
            ),
            border: Border.all(
              color: active ? Colors.white.withOpacity(0.75) : DC.fgo(0.13),
              width: active ? 2 : 1,
            ),
            boxShadow: active
                ? [BoxShadow(color: accent.withOpacity(0.4), blurRadius: 10)]
                : null,
          ),
          alignment: Alignment.center,
          child: Stack(children: [
            Center(
              child: Text(
                spec.letters[index].toUpperCase(),
                style: TextStyle(
                  fontSize: size >= 6 ? 19 : 24,
                  fontWeight: FontWeight.w900,
                  color: active ? Colors.white : DC.text,
                ),
              ),
            ),
            if (active)
              Positioned(
                top: 3,
                right: 5,
                child: Text(
                  '${order + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

class _WordTrailPainter extends CustomPainter {
  final List<int> selected;
  final int size;
  final Color color;

  const _WordTrailPainter({
    required this.selected,
    required this.size,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    if (selected.length < 2) return;
    final cell = canvasSize.width / size;
    final path = Path();
    for (var i = 0; i < selected.length; i++) {
      final index = selected[i];
      final point = Offset(
        (index % size + 0.5) * cell,
        (index ~/ size + 0.5) * cell,
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withOpacity(0.7)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = max(4, cell * 0.08),
    );
  }

  @override
  bool shouldRepaint(covariant _WordTrailPainter oldDelegate) =>
      oldDelegate.selected.join(',') != selected.join(',') ||
      oldDelegate.color != color ||
      oldDelegate.size != size;
}

import 'dart:async';

import 'package:flutter/material.dart';

import '../core/state.dart';
import '../theme_district.dart';
import '../ui/glass.dart';

/// Result of one interactive board.
class BoardResult {
  final bool won;
  final int timeMs;
  const BoardResult({required this.won, required this.timeMs});
}

typedef BoardDone = void Function(BoardResult result);

/// Charges one hint: free hints first, then 25 coins.
bool chargeHint(BuildContext context) {
  final a = AppData.i;
  if (a.freeHints > 0) {
    a.freeHints--;
    a.save();
    return true;
  }
  if (a.spendCoins(25)) return true;
  ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Not enough coins for a hint (25).')));
  return false;
}

/// Standard top bar for every board: live timer, mistakes, hint button.
class BoardHud extends StatefulWidget {
  final String title;
  final int mistakes;
  final int maxMistakes;
  final VoidCallback? onHint;
  final String? extra; // e.g. moves counter

  const BoardHud({
    super.key,
    required this.title,
    this.mistakes = 0,
    this.maxMistakes = 3,
    this.onHint,
    this.extra,
  });

  @override
  State<BoardHud> createState() => _BoardHudState();
}

class _BoardHudState extends State<BoardHud> {
  final int _start = DateTime.now().millisecondsSinceEpoch;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final secs = (DateTime.now().millisecondsSinceEpoch - _start) ~/ 1000;
    final mm = (secs ~/ 60).toString().padLeft(2, '0');
    final ss = (secs % 60).toString().padLeft(2, '0');
    final a = AppData.i;
    return Glass(
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(widget.title,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          ),
          if (widget.extra != null) ...[
            Text(widget.extra!, style: TextStyle(color: DC.dim, fontSize: 12)),
            const SizedBox(width: 10),
          ],
          Icon(Icons.timer_outlined, size: 15, color: DC.dim),
          const SizedBox(width: 3),
          Text('$mm:$ss', style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 10),
          if (widget.maxMistakes > 0) ...[
            Icon(Icons.close,
                size: 15, color: widget.mistakes > 0 ? DC.danger : DC.dim),
            Text(' ${widget.mistakes}/${widget.maxMistakes}',
                style: TextStyle(
                    fontSize: 13,
                    color: widget.mistakes > 0 ? DC.danger : DC.dim)),
            const SizedBox(width: 10),
          ],
          if (widget.onHint != null)
            GestureDetector(
              onTap: widget.onHint,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(colors: [DC.amber, DC.magenta]),
                ),
                child: Row(children: [
                  const Icon(Icons.lightbulb, size: 14, color: Colors.white),
                  Text(
                    a.freeHints > 0 ? ' ${a.freeHints}' : ' 25c',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800),
                  ),
                ]),
              ),
            ),
        ],
      ),
    );
  }
}

/// Small helper: milliseconds elapsed since [start].
int elapsedSince(int start) => DateTime.now().millisecondsSinceEpoch - start;

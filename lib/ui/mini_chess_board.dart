import 'package:flutter/material.dart';

import '../theme_district.dart';
import 'chess_pieces.dart';

/// Compact, non-interactive chessboard for showing a puzzle position —
/// pure white/pure black vector pieces, same visual language as the live
/// 1v1 chess board. Always shown from White's point of view (rank 8 at
/// the top), with file/rank coordinates on the edges so the answer
/// notation (e.g. "Qd5") is easy to follow on the board.
class MiniChessBoard extends StatelessWidget {
  /// Piece-placement FEN field only: ranks 8→1, '/'-separated,
  /// digits for consecutive empty squares (e.g. "6k1/5ppp/8/8/8/8/8/4R1K1").
  final String fen;
  final double size;
  const MiniChessBoard({super.key, required this.fen, this.size = 240});

  static const _typeOf = {'p': 1, 'n': 2, 'b': 3, 'r': 4, 'q': 5, 'k': 6};

  List<int> _parse() {
    final board = List<int>.filled(64, 0);
    final ranks = fen.split('/');
    for (var r = 0; r < 8 && r < ranks.length; r++) {
      var file = 0;
      for (final ch in ranks[r].split('')) {
        final digit = int.tryParse(ch);
        if (digit != null) {
          file += digit;
        } else {
          final type = _typeOf[ch.toLowerCase()];
          if (type != null && file < 8) {
            board[r * 8 + file] = ch == ch.toUpperCase() ? type : -type;
            file++;
          }
        }
      }
    }
    return board;
  }

  @override
  Widget build(BuildContext context) {
    final board = _parse();
    final cell = size / 8;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: DC.fg24),
      ),
      clipBehavior: Clip.antiAlias,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8),
        itemCount: 64,
        itemBuilder: (context, i) => _square(i, board[i], cell),
      ),
    );
  }

  Widget _square(int i, int p, double cell) {
    final row = i ~/ 8, col = i % 8;
    final light = (row + col) % 2 == 0;
    final bg = light ? const Color(0xFFD9B27E) : const Color(0xFF7B4F28);
    final labelColor =
        light ? const Color(0xAA5A3B18) : const Color(0xAAEBD9BC);
    return Container(
      width: cell,
      height: cell,
      color: bg,
      child: Stack(alignment: Alignment.center, children: [
        if (col == 0)
          Positioned(
            top: 1,
            left: 2,
            child: Text('${8 - row}',
                style: TextStyle(
                    fontSize: cell * 0.2,
                    color: labelColor,
                    fontWeight: FontWeight.w700)),
          ),
        if (row == 7)
          Positioned(
            bottom: 0,
            right: 2,
            child: Text(String.fromCharCode(97 + col),
                style: TextStyle(
                    fontSize: cell * 0.2,
                    color: labelColor,
                    fontWeight: FontWeight.w700)),
          ),
        if (p != 0)
          ChessPieceGlyph(type: p.abs(), white: p > 0, size: cell * 0.9),
      ]),
    );
  }
}

import 'dart:math';

import 'question.dart';

/// =====================================================================
/// CHESS TACTICS — curated mate-in-one / tactic MCQs for 1v1 duels.
/// Positions are tiny and hand-verified; boards are drawn with unicode
/// pieces on a text grid so no assets are needed.
/// =====================================================================

class _ChessPuzzle {
  final int tier; // minimum rating this puzzle suits
  final String board; // unicode diagram (fallback text)
  final String ask;
  final List<String> options;
  final String answer;
  final String note;

  /// Piece-placement FEN for the visual board. Null for the handful of
  /// conceptual (non-positional) questions.
  final String? fen;
  const _ChessPuzzle(
      this.tier, this.board, this.ask, this.options, this.answer, this.note,
      [this.fen]);
}

// Board strings: ranks 8→1, '·' = empty. White = ♔♕♖♗♘♙, Black = ♚♛♜♝♞♟.
const _puzzles = <_ChessPuzzle>[
  _ChessPuzzle(
    800,
    '8  · · · · · · ♚ ·\n7  · · · · · ♟ ♟ ♟\n1  · · · · ♖ · ♔ ·',
    'White to move. Mate in one!',
    ['Re8#', 'Re7', 'Kf2', 'Re5'],
    'Re8#',
    'Back-rank mate: the king is boxed in by its own pawns.',
    '6k1/5ppp/8/8/8/8/8/4R1K1',
  ),
  _ChessPuzzle(
    800,
    '8  · · · · · · ♚ ·\n7  · · · · · ♟ ♟ ♟\n1  · · · ♕ · · ♔ ·',
    'White to move. Mate in one!',
    ['Qd8#', 'Qd5', 'Qg4+', 'Qd7'],
    'Qd8#',
    'The queen slides to the back rank — no escape squares.',
    '6k1/5ppp/8/8/8/8/8/3Q2K1',
  ),
  _ChessPuzzle(
    1000,
    '8  · · · · · · ♚ ·\n7  · · · · · ♟ · ♟\n6  · · · · · · · ♕\n2  · ♗ · · · · · ·\n1  · · · · · · ♔ ·',
    'White to move. Mate in one!',
    ['Qg7#', 'Qxh7+', 'Qh8+', 'Bf6'],
    'Qg7#',
    'Qg7# — the b2-bishop guards g7 along the long diagonal.',
    '6k1/5p1p/7Q/8/8/8/1B6/6K1',
  ),
  _ChessPuzzle(
    1200,
    '8  · · · · · · ♜ ♚\n7  · · · · · · ♟ ♟\n5  · · · · · · ♘ ·\n1  · · · · · · ♔ ·',
    'White to move. Mate in one!',
    ['Nf7#', 'Nxh7', 'Ne6', 'Ne4'],
    'Nf7#',
    'Smothered mate — the king suffocates behind its own pieces.',
    '6rk/6pp/8/6N1/8/8/8/6K1',
  ),
  _ChessPuzzle(
    1000,
    '8  · · · · · · · ♚\n7  ♖ · · · · · · ·\n1  · ♖ · · · · ♔ ·',
    'White to move. Mate in one!',
    ['Rb8#', 'Ra8+', 'Rb7', 'Rh7+'],
    'Rb8#',
    'The ladder mate: one rook cuts the 7th, the other delivers on the 8th.',
    '7k/R7/8/8/8/8/8/1R4K1',
  ),
  _ChessPuzzle(
    900,
    '8  · · · · · · ♚ ·\n6  · · · · · · ♔ ·\n1  · · · ♕ · · · ·',
    'White to move. Mate in one!',
    ['Qd8#', 'Qd5+', 'Qg4+', 'Qd7'],
    'Qd8#',
    'Classic K+Q mate: your king covers every escape on the 7th rank.',
    '6k1/8/6K1/8/8/8/8/3Q4',
  ),
  _ChessPuzzle(
    1300,
    '8  · · · ♚ · · · ·\n5  ♛ · · · · · · ·\n4  · ♘ · · · · · ·\n1  · · · · · · ♔ ·',
    'White to move. Win the queen!',
    ['Nc6+', 'Nxa5', 'Nd5', 'Nd3'],
    'Nc6+',
    'Royal fork: Nc6+ hits the king on d8 AND the queen on a5.',
    '3k4/8/8/q7/1N6/8/8/6K1',
  ),
  _ChessPuzzle(
    1300,
    '8  · · ♛ · · · ♚ ·\n6  · · ♘ · · · · ·\n1  · · · · · · ♔ ·',
    'White to move. Win the queen!',
    ['Ne7+', 'Nd8', 'Na7', 'Nb8'],
    'Ne7+',
    'Ne7+ forks the king on g8 and the queen on c8.',
    '2q3k1/8/2N5/8/8/8/8/6K1',
  ),
  _ChessPuzzle(
    1400,
    '8  · · · · ♛ · · ·\n5  · · · · ♚ · · ·\n1  ♖ · · · · · ♔ ·',
    'White to move. Win the queen!',
    ['Re1+', 'Ra5+', 'Ra8', 'Rxa7'],
    'Re1+',
    'The skewer: after the king steps off the e-file, Rxe8 follows.',
    '4q3/8/8/4k3/8/8/8/R5K1',
  ),
  _ChessPuzzle(
    900,
    'White has: ♕ + ♖.\nBlack has: ♜ + ♝ + ♞.',
    'Count the points (Q=9, R=5, B/N=3). Who is up material?',
    ['White by 3', 'Black by 3', 'Equal', 'White by 1'],
    'White by 3',
    'White 9+5=14 vs Black 5+3+3=11 → White is +3.',
  ),
  _ChessPuzzle(
    1000,
    '8  · · · · · · ♚ ·\n6  · · · · · · ♔ ·\n1  ♖ · · · · · · ·',
    'White to move. Mate in one!',
    ['Ra8#', 'Ra7', 'Rg1+', 'Kf6'],
    'Ra8#',
    'The rook checks on the 8th while your king denies f7, g7 and h7.',
    '6k1/8/6K1/8/8/8/8/R7',
  ),
  _ChessPuzzle(
    1500,
    '8  · · · · · ♜ ♚ ·\n7  · · · · · ♟ ♟ ·\n3  · · · ♕ · · · ·\n2  · · ♗ · · · · ·\n1  · · · · · · ♔ ·',
    'White to move. Mate in one!',
    ['Qh7#', 'Qd8', 'Qg6', 'Bb3+'],
    'Qh7#',
    'Queen+bishop battery on b1–h7: f8 is blocked by Black\'s own rook.',
    '5rk1/5pp1/8/8/8/3Q4/2B5/6K1',
  ),
  _ChessPuzzle(
    800,
    '7  ♙ · · · · · · ·\n4  · · · ♔ · · · ·\n8  · · · · · · ♚(g7)',
    'White pawn on a7, Black king far away on g7. Best move?',
    ['a8=Q', 'Kc5', 'Kd5', 'a8=N'],
    'a8=Q',
    'Promote! The black king can never catch the a-pawn.',
    '8/P5k1/8/8/3K4/8/8/8',
  ),
  _ChessPuzzle(
    1600,
    '8  · · · · · · · ♚\n6  · · · · · ♔ ♕(g6)',
    'Black has only the king (h8). Which move mates — and which one stalemates?',
    ['Qg7# mates', 'Qh6+ mates', 'Kg5 mates', 'Qf7 mates'],
    'Qg7# mates',
    'Qg7# is mate (guarded by Kf6). Careless quiet moves risk stalemate!',
    '7k/8/5KQ1/8/8/8/8/8',
  ),
  _ChessPuzzle(
    1100,
    '8  · · · · ♜ · ♚ ·\n7  · · · · · ♟ ♟ ♟\n1  · · · · ♖ · ♔ ·',
    'White to move. Mate in one!',
    ['Rxe8#', 'Rd1', 'Re7', 'Kf1'],
    'Rxe8#',
    'Capture and mate — the defender of the back rank falls.',
    '4r1k1/5ppp/8/8/8/8/8/4R1K1',
  ),
  _ChessPuzzle(
    1200,
    '5  · · · · · · · ♕(h5)\n4  · · ♗ · · · · ·\n8  ♚(e8) ♛(d8) ♟(d7) ♟(f7)',
    'The classic attack: White Qh5 + Bc4 vs the f7 pawn. Mate in one!',
    ['Qxf7#', 'Qxh7', 'Bxf7+', 'Qe5+'],
    'Qxf7#',
    'Scholar\'s mate: Qxf7# is guarded by the c4-bishop.',
    '3qk3/3p1p2/8/7Q/2B5/8/8/8',
  ),
  _ChessPuzzle(
    900,
    'A knight stands in the corner on a1.',
    'How many squares can it jump to?',
    ['2', '3', '4', '8'],
    '2',
    'Corner knights are sad knights: only b3 and c2.',
  ),
  _ChessPuzzle(
    1700,
    '8  · · · · · · ♚ ·\n7  · · · · · ♟ ♟ ·\n6  · · · · · · · ♙\n3  · · ♕ · · · · ·\n1  · · · · · · ♔ ·',
    'White to move. Mate in one!',
    ['Qxg7#', 'h7+', 'Qc8+', 'Qh1'],
    'Qxg7#',
    'Qxg7# — the h6 pawn guards g7, so the king can\'t recapture.',
    '6k1/5pp1/7P/8/8/2Q5/8/6K1',
  ),
];

/// Picks a rating-appropriate chess puzzle and formats it as a [Question].
Question chessQuestion(int rating, Random rng) {
  final pool = _puzzles.where((p) => (rating - p.tier).abs() <= 400).toList();
  final list = pool.isEmpty ? _puzzles : pool;
  final p = list[rng.nextInt(list.length)];
  final opts = List<String>.from(p.options)..shuffle(rng);
  return Question(
    // Puzzles with a FEN render a real board instead, so drop the
    // ASCII diagram from the prompt text for those.
    prompt: p.fen != null
        ? '♟ CHESS TACTICS\n\n${p.ask}'
        : '♟ CHESS TACTICS\n\n${p.board}\n\n${p.ask}',
    options: opts,
    answer: p.answer,
    parMs: (14000 - (rating - 800) * 3).clamp(8000, 14000).toInt(),
    note: p.note,
    fen: p.fen,
  );
}

import 'dart:math';

/// ============================================================
/// MYNDASH real chess engine — legal move generation + rated AI.
/// Pure Dart, no packages. Board is a 64-int list, rank 8 first
/// (index 0 = a8 … 63 = h1). White pieces positive, black negative:
/// 1 P · 2 N · 3 B · 4 R · 5 Q · 6 K
/// ============================================================

const wP = 1, wN = 2, wB = 3, wR = 4, wQ = 5, wK = 6;
const bP = -1, bN = -2, bB = -3, bR = -4, bQ = -5, bK = -6;

class ChessMove {
  final int from, to;
  final int piece; // moving piece (signed)
  final int captured; // 0 if none (en passant stores the pawn)
  final int promotion; // 0 or ±N/B/R/Q
  final bool isEnPassant;
  final bool isCastle; // king moves two files

  const ChessMove(this.from, this.to, this.piece,
      {this.captured = 0,
      this.promotion = 0,
      this.isEnPassant = false,
      this.isCastle = false});

  /// Long algebraic, e.g. "e2e4", "e7e8q".
  String get uci =>
      _sq(from) + _sq(to) + (promotion != 0 ? 'nbrq'[promotion.abs() - 2] : '');

  static String _sq(int i) =>
      String.fromCharCode(97 + i % 8) + (8 - i ~/ 8).toString();
}

class ChessGame {
  /// index 0 = a8 (top-left from White's view), 63 = h1.
  final List<int> board = List.filled(64, 0);
  bool whiteToMove = true;

  // castling rights
  bool wCastleK = true, wCastleQ = true, bCastleK = true, bCastleQ = true;

  /// square a pawn can capture onto en passant, or -1.
  int epSquare = -1;

  int halfmoveClock = 0; // for the 50-move rule
  int fullmove = 1;

  final List<ChessMove> history = [];
  final List<List<int>> _undoState = []; // [castles×4, ep, halfmove]

  ChessGame() {
    const back = [bR, bN, bB, bQ, bK, bB, bN, bR];
    for (var f = 0; f < 8; f++) {
      board[f] = back[f];
      board[8 + f] = bP;
      board[48 + f] = wP;
      board[56 + f] = -back[f];
    }
  }

  // ---------------- attack detection ----------------

  static const _knightJumps = [
    [-2, -1],
    [-2, 1],
    [-1, -2],
    [-1, 2],
    [1, -2],
    [1, 2],
    [2, -1],
    [2, 1]
  ];
  static const _kingSteps = [
    [-1, -1],
    [-1, 0],
    [-1, 1],
    [0, -1],
    [0, 1],
    [1, -1],
    [1, 0],
    [1, 1]
  ];
  static const _rookDirs = [
    [-1, 0],
    [1, 0],
    [0, -1],
    [0, 1]
  ];
  static const _bishopDirs = [
    [-1, -1],
    [-1, 1],
    [1, -1],
    [1, 1]
  ];

  /// Is [sq] attacked by the side [byWhite]?
  bool isAttacked(int sq, bool byWhite) {
    final r = sq ~/ 8, f = sq % 8;
    final s = byWhite ? 1 : -1;
    // pawns (white pawns attack upward = decreasing rank index)
    final pr = byWhite ? r + 1 : r - 1;
    if (pr >= 0 && pr < 8) {
      if (f > 0 && board[pr * 8 + f - 1] == s * wP) return true;
      if (f < 7 && board[pr * 8 + f + 1] == s * wP) return true;
    }
    for (final j in _knightJumps) {
      final nr = r + j[0], nf = f + j[1];
      if (nr >= 0 &&
          nr < 8 &&
          nf >= 0 &&
          nf < 8 &&
          board[nr * 8 + nf] == s * wN) return true;
    }
    for (final j in _kingSteps) {
      final nr = r + j[0], nf = f + j[1];
      if (nr >= 0 &&
          nr < 8 &&
          nf >= 0 &&
          nf < 8 &&
          board[nr * 8 + nf] == s * wK) return true;
    }
    for (final d in _rookDirs) {
      var nr = r + d[0], nf = f + d[1];
      while (nr >= 0 && nr < 8 && nf >= 0 && nf < 8) {
        final p = board[nr * 8 + nf];
        if (p != 0) {
          if (p == s * wR || p == s * wQ) return true;
          break;
        }
        nr += d[0];
        nf += d[1];
      }
    }
    for (final d in _bishopDirs) {
      var nr = r + d[0], nf = f + d[1];
      while (nr >= 0 && nr < 8 && nf >= 0 && nf < 8) {
        final p = board[nr * 8 + nf];
        if (p != 0) {
          if (p == s * wB || p == s * wQ) return true;
          break;
        }
        nr += d[0];
        nf += d[1];
      }
    }
    return false;
  }

  int kingSquare(bool white) => board.indexOf(white ? wK : bK);

  bool get inCheck => isAttacked(kingSquare(whiteToMove), !whiteToMove);

  // ---------------- move generation ----------------

  /// All fully legal moves for the side to move.
  List<ChessMove> legalMoves() {
    final out = <ChessMove>[];
    for (final m in _pseudoMoves()) {
      makeMove(m);
      final ok = !isAttacked(kingSquare(!whiteToMove), whiteToMove);
      undoMove();
      if (ok) out.add(m);
    }
    return out;
  }

  List<ChessMove> legalMovesFrom(int from) =>
      legalMoves().where((m) => m.from == from).toList();

  List<ChessMove> _pseudoMoves() {
    final out = <ChessMove>[];
    final side = whiteToMove ? 1 : -1;
    for (var sq = 0; sq < 64; sq++) {
      final p = board[sq];
      if (p == 0 || p.sign != side) continue;
      final r = sq ~/ 8, f = sq % 8;
      switch (p.abs()) {
        case wP:
          final dir = whiteToMove ? -1 : 1;
          final startRank = whiteToMove ? 6 : 1;
          final promoRank = whiteToMove ? 0 : 7;
          final one = (r + dir) * 8 + f;
          if (one >= 0 && one < 64 && board[one] == 0) {
            if (one ~/ 8 == promoRank) {
              for (final promo in [wQ, wR, wB, wN]) {
                out.add(ChessMove(sq, one, p, promotion: side * promo));
              }
            } else {
              out.add(ChessMove(sq, one, p));
              if (r == startRank) {
                final two = (r + 2 * dir) * 8 + f;
                if (board[two] == 0) out.add(ChessMove(sq, two, p));
              }
            }
          }
          for (final df in [-1, 1]) {
            final nf = f + df;
            if (nf < 0 || nf > 7) continue;
            final t = (r + dir) * 8 + nf;
            if (t < 0 || t > 63) continue;
            final target = board[t];
            if (target != 0 && target.sign != side) {
              if (t ~/ 8 == promoRank) {
                for (final promo in [wQ, wR, wB, wN]) {
                  out.add(ChessMove(sq, t, p,
                      captured: target, promotion: side * promo));
                }
              } else {
                out.add(ChessMove(sq, t, p, captured: target));
              }
            } else if (t == epSquare && target == 0) {
              out.add(
                  ChessMove(sq, t, p, captured: -side * wP, isEnPassant: true));
            }
          }
          break;
        case wN:
          for (final j in _knightJumps) {
            _step(out, sq, r + j[0], f + j[1], p, side);
          }
          break;
        case wK:
          for (final j in _kingSteps) {
            _step(out, sq, r + j[0], f + j[1], p, side);
          }
          _castles(out, sq, p, side);
          break;
        case wB:
          _slide(out, sq, p, side, _bishopDirs);
          break;
        case wR:
          _slide(out, sq, p, side, _rookDirs);
          break;
        case wQ:
          _slide(out, sq, p, side, _rookDirs);
          _slide(out, sq, p, side, _bishopDirs);
          break;
      }
    }
    return out;
  }

  void _step(List<ChessMove> out, int from, int nr, int nf, int p, int side) {
    if (nr < 0 || nr > 7 || nf < 0 || nf > 7) return;
    final t = nr * 8 + nf;
    final target = board[t];
    if (target == 0) {
      out.add(ChessMove(from, t, p));
    } else if (target.sign != side) {
      out.add(ChessMove(from, t, p, captured: target));
    }
  }

  void _slide(
      List<ChessMove> out, int from, int p, int side, List<List<int>> dirs) {
    final r = from ~/ 8, f = from % 8;
    for (final d in dirs) {
      var nr = r + d[0], nf = f + d[1];
      while (nr >= 0 && nr < 8 && nf >= 0 && nf < 8) {
        final t = nr * 8 + nf;
        final target = board[t];
        if (target == 0) {
          out.add(ChessMove(from, t, p));
        } else {
          if (target.sign != side) {
            out.add(ChessMove(from, t, p, captured: target));
          }
          break;
        }
        nr += d[0];
        nf += d[1];
      }
    }
  }

  void _castles(List<ChessMove> out, int from, int p, int side) {
    final home = whiteToMove ? 60 : 4; // e1 / e8
    if (from != home) return;
    if (isAttacked(home, !whiteToMove)) return;
    final canK = whiteToMove ? wCastleK : bCastleK;
    final canQ = whiteToMove ? wCastleQ : bCastleQ;
    if (canK &&
        board[home + 1] == 0 &&
        board[home + 2] == 0 &&
        board[home + 3] == side * wR &&
        !isAttacked(home + 1, !whiteToMove) &&
        !isAttacked(home + 2, !whiteToMove)) {
      out.add(ChessMove(from, home + 2, p, isCastle: true));
    }
    if (canQ &&
        board[home - 1] == 0 &&
        board[home - 2] == 0 &&
        board[home - 3] == 0 &&
        board[home - 4] == side * wR &&
        !isAttacked(home - 1, !whiteToMove) &&
        !isAttacked(home - 2, !whiteToMove)) {
      out.add(ChessMove(from, home - 2, p, isCastle: true));
    }
  }

  // ---------------- make / undo ----------------

  void makeMove(ChessMove m) {
    _undoState.add([
      wCastleK ? 1 : 0,
      wCastleQ ? 1 : 0,
      bCastleK ? 1 : 0,
      bCastleQ ? 1 : 0,
      epSquare,
      halfmoveClock,
    ]);
    history.add(m);

    board[m.from] = 0;
    board[m.to] = m.promotion != 0 ? m.promotion : m.piece;
    if (m.isEnPassant) {
      // captured pawn sits behind the target square
      board[m.to + (m.piece > 0 ? 8 : -8)] = 0;
    }
    if (m.isCastle) {
      if (m.to == m.from + 2) {
        board[m.from + 1] = board[m.from + 3];
        board[m.from + 3] = 0;
      } else {
        board[m.from - 1] = board[m.from - 4];
        board[m.from - 4] = 0;
      }
    }
    // castling rights
    if (m.piece == wK) {
      wCastleK = false;
      wCastleQ = false;
    }
    if (m.piece == bK) {
      bCastleK = false;
      bCastleQ = false;
    }
    if (m.from == 63 || m.to == 63) wCastleK = false;
    if (m.from == 56 || m.to == 56) wCastleQ = false;
    if (m.from == 7 || m.to == 7) bCastleK = false;
    if (m.from == 0 || m.to == 0) bCastleQ = false;
    // en passant square
    epSquare = -1;
    if (m.piece.abs() == wP && (m.to - m.from).abs() == 16) {
      epSquare = (m.from + m.to) ~/ 2;
    }
    // clocks
    if (m.piece.abs() == wP || m.captured != 0) {
      halfmoveClock = 0;
    } else {
      halfmoveClock++;
    }
    if (!whiteToMove) fullmove++;
    whiteToMove = !whiteToMove;
  }

  void undoMove() {
    final m = history.removeLast();
    final s = _undoState.removeLast();
    wCastleK = s[0] == 1;
    wCastleQ = s[1] == 1;
    bCastleK = s[2] == 1;
    bCastleQ = s[3] == 1;
    epSquare = s[4];
    halfmoveClock = s[5];
    whiteToMove = !whiteToMove;
    if (whiteToMove == false) fullmove--; // undoing a white move
    board[m.from] = m.piece;
    board[m.to] = 0;
    if (m.isEnPassant) {
      board[m.to + (m.piece > 0 ? 8 : -8)] = m.captured;
    } else if (m.captured != 0) {
      board[m.to] = m.captured;
    }
    if (m.isCastle) {
      if (m.to == m.from + 2) {
        board[m.from + 3] = board[m.from + 1];
        board[m.from + 1] = 0;
      } else {
        board[m.from - 4] = board[m.from - 1];
        board[m.from - 1] = 0;
      }
    }
  }

  // ---------------- game state ----------------

  /// '' = ongoing · '1-0' · '0-1' · '½' (draw)
  String result() {
    if (legalMoves().isEmpty) {
      if (inCheck) return whiteToMove ? '0-1' : '1-0';
      return '½'; // stalemate
    }
    if (halfmoveClock >= 100) return '½';
    if (_insufficientMaterial()) return '½';
    return '';
  }

  bool _insufficientMaterial() {
    var minor = 0;
    for (final p in board) {
      switch (p.abs()) {
        case 0:
        case wK:
          break;
        case wB:
        case wN:
          minor++;
          break;
        default:
          return false; // pawn, rook or queen present
      }
    }
    return minor <= 1;
  }

  // ---------------- evaluation & AI ----------------

  static const _pieceVal = [0, 100, 320, 330, 500, 900, 20000];

  // piece-square tables (white perspective, index 0 = a8)
  static const _pawnPst = [
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    50,
    50,
    50,
    50,
    50,
    50,
    50,
    50,
    10,
    10,
    20,
    30,
    30,
    20,
    10,
    10,
    5,
    5,
    10,
    25,
    25,
    10,
    5,
    5,
    0,
    0,
    0,
    20,
    20,
    0,
    0,
    0,
    5,
    -5,
    -10,
    0,
    0,
    -10,
    -5,
    5,
    5,
    10,
    10,
    -20,
    -20,
    10,
    10,
    5,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
    0,
  ];
  static const _knightPst = [
    -50,
    -40,
    -30,
    -30,
    -30,
    -30,
    -40,
    -50,
    -40,
    -20,
    0,
    0,
    0,
    0,
    -20,
    -40,
    -30,
    0,
    10,
    15,
    15,
    10,
    0,
    -30,
    -30,
    5,
    15,
    20,
    20,
    15,
    5,
    -30,
    -30,
    0,
    15,
    20,
    20,
    15,
    0,
    -30,
    -30,
    5,
    10,
    15,
    15,
    10,
    5,
    -30,
    -40,
    -20,
    0,
    5,
    5,
    0,
    -20,
    -40,
    -50,
    -40,
    -30,
    -30,
    -30,
    -30,
    -40,
    -50,
  ];
  static const _bishopPst = [
    -20,
    -10,
    -10,
    -10,
    -10,
    -10,
    -10,
    -20,
    -10,
    0,
    0,
    0,
    0,
    0,
    0,
    -10,
    -10,
    0,
    5,
    10,
    10,
    5,
    0,
    -10,
    -10,
    5,
    5,
    10,
    10,
    5,
    5,
    -10,
    -10,
    0,
    10,
    10,
    10,
    10,
    0,
    -10,
    -10,
    10,
    10,
    10,
    10,
    10,
    10,
    -10,
    -10,
    5,
    0,
    0,
    0,
    0,
    5,
    -10,
    -20,
    -10,
    -10,
    -10,
    -10,
    -10,
    -10,
    -20,
  ];
  static const _kingPst = [
    -30,
    -40,
    -40,
    -50,
    -50,
    -40,
    -40,
    -30,
    -30,
    -40,
    -40,
    -50,
    -50,
    -40,
    -40,
    -30,
    -30,
    -40,
    -40,
    -50,
    -50,
    -40,
    -40,
    -30,
    -30,
    -40,
    -40,
    -50,
    -50,
    -40,
    -40,
    -30,
    -20,
    -30,
    -30,
    -40,
    -40,
    -30,
    -30,
    -20,
    -10,
    -20,
    -20,
    -20,
    -20,
    -20,
    -20,
    -10,
    20,
    20,
    0,
    0,
    0,
    0,
    20,
    20,
    20,
    30,
    10,
    0,
    0,
    10,
    30,
    20,
  ];

  /// Static eval from White's perspective, in centipawns.
  int evaluate() {
    var score = 0;
    for (var sq = 0; sq < 64; sq++) {
      final p = board[sq];
      if (p == 0) continue;
      final white = p > 0;
      final idx = white ? sq : 63 - sq;
      var v = _pieceVal[p.abs()];
      switch (p.abs()) {
        case wP:
          v += _pawnPst[idx];
          break;
        case wN:
          v += _knightPst[idx];
          break;
        case wB:
          v += _bishopPst[idx];
          break;
        case wK:
          v += _kingPst[idx];
          break;
        case wR:
          v += (idx ~/ 8 == 1) ? 10 : 0;
          break; // 7th rank
      }
      score += white ? v : -v;
    }
    return score;
  }

  int _nodes = 0;
  static const _nodeCap = 25000; // keeps a move well under a second on-device

  /// Best move for the side to move at the given [rating] (800–2600).
  /// Weaker ratings search shallower and blunder on purpose.
  ChessMove? bestMove(int rating, Random rng) {
    final moves = legalMoves();
    if (moves.isEmpty) return null;

    final depth = rating < 1000
        ? 1
        : rating < 1500
            ? 2
            : rating < 2100
                ? 3
                : 4;
    // chance of ignoring the engine choice and playing a random move
    final blunder = rating < 900
        ? 0.35
        : rating < 1200
            ? 0.2
            : rating < 1600
                ? 0.1
                : rating < 2000
                    ? 0.04
                    : 0.0;
    if (rng.nextDouble() < blunder) {
      return moves[rng.nextInt(moves.length)];
    }

    _nodes = 0;
    _orderMoves(moves);
    ChessMove best = moves.first;
    var bestScore = -1 << 30;
    var alpha = -1 << 30;
    const beta = 1 << 30;
    final me = whiteToMove;
    for (final m in moves) {
      makeMove(m);
      final score = -_negamax(depth - 1, -beta, -alpha, !me);
      undoMove();
      if (score > bestScore) {
        bestScore = score;
        best = m;
      }
      if (score > alpha) alpha = score;
    }
    return best;
  }

  int _negamax(int depth, int alpha, int beta, bool white) {
    _nodes++;
    final moves = legalMoves();
    if (moves.isEmpty) {
      if (inCheck) return -100000 - depth; // prefer faster mates
      return 0; // stalemate
    }
    if (depth <= 0 || _nodes > _nodeCap) {
      final e = evaluate();
      return white ? e : -e;
    }
    _orderMoves(moves);
    var best = -1 << 30;
    for (final m in moves) {
      makeMove(m);
      final score = -_negamax(depth - 1, -beta, -alpha, !white);
      undoMove();
      if (score > best) best = score;
      if (score > alpha) alpha = score;
      if (alpha >= beta) break;
    }
    return best;
  }

  void _orderMoves(List<ChessMove> moves) {
    moves.sort((a, b) {
      final av = a.captured.abs() * 10 - a.piece.abs() + a.promotion.abs() * 9;
      final bv = b.captured.abs() * 10 - b.piece.abs() + b.promotion.abs() * 9;
      return bv.compareTo(av);
    });
  }

  // ---------------- helpers for the UI ----------------

  static String pieceGlyph(int p) => switch (p) {
        wK => '♔',
        wQ => '♕',
        wR => '♖',
        wB => '♗',
        wN => '♘',
        wP => '♙',
        bK => '♚',
        bQ => '♛',
        bR => '♜',
        bB => '♝',
        bN => '♞',
        bP => '♟',
        _ => '',
      };

  /// Material captured *by* the given side, as glyphs (biggest first).
  String capturedBy(bool white) {
    final taken = <int>[];
    for (final m in history) {
      if (m.captured != 0 && (m.captured < 0) == white) taken.add(m.captured);
    }
    taken.sort((a, b) => b.abs().compareTo(a.abs()));
    return taken.map(pieceGlyph).join();
  }
}

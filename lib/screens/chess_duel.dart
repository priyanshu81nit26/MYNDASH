import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../core/fx.dart';
import '../core/state.dart';
import '../engine/chess_engine.dart';
import '../services/account_service.dart';
import '../theme_district.dart';
import '../ui/chess_pieces.dart';
import '../ui/extras.dart';
import '../ui/glass.dart';
import 'online_play.dart';

/// ============================================================
/// REAL CHESS 1v1 — full legal chess on a responsive 2D board
/// vs a rating-scaled engine. Castling, en passant, promotion,
/// checkmate, stalemate, 50-move & insufficient material.
/// ============================================================
class ChessDuelScreen extends StatefulWidget {
  final int wager;

  /// When non-null this is a Chess Journey game: level 1..30.
  /// The bot plays at 900 + level×100 + (game−1)×20 Elo,
  /// no wager and no Elo change — progress + rewards instead.
  final int? journeyLevel;

  /// Practice vs a fixed-strength bot (no wager pot changes to Elo apply
  /// as usual). Used when replaying completed journey levels.
  final int? practiceRating;

  /// Online match: a /rooms entry (from matchmaking or an invite).
  /// Host plays white. Moves sync live through the room.
  final Map<String, dynamic>? room;
  final bool amHost;

  /// Demo-bot fallback for online: a local engine game presented as an
  /// online match vs a real leaderboard bot. [botName] is the bot's
  /// @handle; [botMatch] labels the result as an online chess game.
  final String? botName;
  final bool botMatch;

  /// Time control in minutes per side (0 = untimed). When > 0 each side
  /// has a chess clock; running out of time loses on the spot.
  final int timeMinutes;
  final ValueChanged<int>? arenaScore;

  const ChessDuelScreen(
      {super.key,
      this.wager = 0,
      this.journeyLevel,
      this.practiceRating,
      this.room,
      this.amHost = true,
      this.botName,
      this.botMatch = false,
      this.timeMinutes = 0,
      this.arenaScore});

  @override
  State<ChessDuelScreen> createState() => _ChessDuelScreenState();
}

class _ChessDuelScreenState extends State<ChessDuelScreen> {
  final rng = Random();
  final game = ChessGame();

  late String botName;
  late int botRating;
  late bool iPlayWhite;
  bool searching = true;
  bool thinking = false;
  bool finished = false;

  // ---- chess clock (timeMinutes > 0) ----
  bool get timed => widget.timeMinutes > 0;
  late int myClockMs = widget.timeMinutes * 60000;
  late int botClockMs = widget.timeMinutes * 60000;
  Timer? _clock;
  static const _tickMs = 250;

  void _startClock() {
    if (!timed) return;
    _clock?.cancel();
    _clock = Timer.periodic(const Duration(milliseconds: _tickMs), (_) {
      if (finished || searching || !mounted) return;
      final myTurn = game.whiteToMove == iPlayWhite;
      setState(() {
        if (myTurn) {
          myClockMs -= _tickMs;
          if (myClockMs <= 0) {
            myClockMs = 0;
            _finish(false, false, 'Out of time — you flagged ⏱');
          }
        } else {
          botClockMs -= _tickMs;
          if (botClockMs <= 0) {
            botClockMs = 0;
            _finish(true, false, '$botName flagged ⏱');
          }
        }
      });
    });
  }

  static String _fmtClock(int ms) {
    final s = (ms / 1000).ceil();
    final m = s ~/ 60;
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$m:$ss';
  }

  int? selected; // selected square (board index)
  List<ChessMove> hints = []; // legal moves from the selected square
  ChessMove? lastMove;

  static const _names = [
    'Nova',
    'Zephyr',
    'Kira',
    'Axel',
    'Mira',
    'Dash',
    'Rehan',
    'Tara',
    'Vik',
    'Luna',
    'Omen',
    'Pixel',
    'Sage',
    'Rio',
    'Ivy',
    'Neo',
  ];

  bool get isJourney => widget.journeyLevel != null;
  bool get isOnline => widget.room != null;
  late int journeyGame; // 1..5, fixed at start
  StreamSubscription? roomSub;
  late final String mySide = widget.amHost ? 'host' : 'guest';
  late final String oppSide = widget.amHost ? 'guest' : 'host';

  @override
  void initState() {
    super.initState();
    final a = AppData.i;
    journeyGame = a.chessNextGame;
    if (isOnline) {
      final opp = Map<String, dynamic>.from(widget.room![oppSide] as Map);
      botName = '@${opp['u']}';
      botRating = (opp['elo'] as num?)?.toInt() ?? 800;
      iPlayWhite = widget.amHost; // host is white, both agree
      searching = false;
      _startClock();
      AccountService.instance.pinRoom(widget.room!['id'], true);
      roomSub = AccountService.instance
          .roomStream(widget.room!['id'])
          .listen(_onRoom);
      return;
    }
    if (isJourney) {
      final lvl = widget.journeyLevel!;
      botName = 'Guardian L$lvl·G$journeyGame';
      botRating = AppData.chessGameElo(lvl, journeyGame);
    } else {
      botName = widget.botName ?? _names[rng.nextInt(_names.length)];
      botRating = widget.practiceRating ??
          (a.elo + rng.nextInt(300) - 150).clamp(500, 2600).toInt();
      // Bot matches are friendly — no coin stake (kept XP + rating only).
    }
    iPlayWhite = rng.nextBool();
    // A caller that already supplied botName picked the opponent up front and
    // showed its own get-ready lobby (ShowdownScreen) — skip this screen's
    // redundant "searching" spinner so the player isn't shown two waits.
    final skipSearch = widget.botName != null;
    if (skipSearch) searching = false;
    Timer(Duration(milliseconds: skipSearch ? 0 : (isJourney ? 900 : 2000)),
        () {
      if (!mounted) return;
      setState(() => searching = false);
      _startClock();
      if (!iPlayWhite) _botTurn();
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    roomSub?.cancel();
    if (isOnline) {
      AccountService.instance.pinRoom(widget.room!['id'], false);
      if (!finished) {
        AccountService.instance
            .roomWrite(widget.room!['id'], 'state/left', mySide);
      }
    }
    super.dispose();
  }

  // ---------------- online sync ----------------

  void _onRoom(Map<String, dynamic>? r) {
    if (r == null || finished || !mounted) return;
    final st = r['state'] as Map?;
    if (st == null) return;
    // Apply any remote moves we haven't played yet.
    // NOTE: read through idxValue — RTDB turns numeric-keyed children
    // into a List, which used to kill sync after a few moves.
    final moves = st['moves'];
    var applied = false;
    while (true) {
      final uci = idxValue(moves, game.history.length) as String?;
      if (uci == null) break;
      final legal = game.legalMoves().where((m) => m.uci == uci).toList();
      if (legal.isEmpty) break; // desync guard
      game.makeMove(legal.first);
      lastMove = legal.first;
      applied = true;
    }
    if (applied) {
      Fx.impact();
      setState(() {});
      _checkEnd();
    }
    final resign = st['resign'];
    if (resign != null && resign != mySide && !finished) {
      _finish(true, false, '$botName resigned');
    }
    if (st['left'] == oppSide && !finished) {
      _finish(true, false, '$botName left the board');
    }
  }

  // ---------------- interaction ----------------

  bool get myTurn =>
      !searching && !finished && !thinking && game.whiteToMove == iPlayWhite;

  void _tapSquare(int sq) {
    if (!myTurn) return;
    final p = game.board[sq];
    final mine = p != 0 && (p > 0) == iPlayWhite;
    if (selected == null || mine) {
      setState(() {
        selected = mine ? sq : null;
        hints = mine ? game.legalMovesFrom(sq) : [];
      });
      return;
    }
    final options = hints.where((m) => m.to == sq).toList();
    if (options.isEmpty) {
      setState(() {
        selected = null;
        hints = [];
      });
      return;
    }
    if (options.length > 1) {
      _pickPromotion(options); // promotion — 4 move variants
    } else {
      _playMyMove(options.first);
    }
  }

  Future<void> _pickPromotion(List<ChessMove> options) async {
    final choice = await showDialog<ChessMove>(
      context: context,
      builder: (c) => Dialog(
        backgroundColor: DC.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Promote to',
                style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Row(mainAxisSize: MainAxisSize.min, children: [
              for (final m in options)
                GestureDetector(
                  onTap: () => Navigator.pop(c, m),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: DC.fgo(0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(ChessGame.pieceGlyph(m.promotion),
                        style: const TextStyle(fontSize: 34)),
                  ),
                ),
            ]),
          ]),
        ),
      ),
    );
    if (choice != null) _playMyMove(choice);
  }

  void _playMyMove(ChessMove m) {
    if (m.captured != 0) {
      Fx.success();
    } else {
      Fx.impact();
    }
    setState(() {
      game.makeMove(m);
      lastMove = m;
      selected = null;
      hints = [];
    });
    if (isOnline) {
      // 'm' prefix keeps keys non-numeric → no RTDB list coercion.
      AccountService.instance.roomWrite(
          widget.room!['id'], 'state/moves/m${game.history.length - 1}', m.uci);
      _checkEnd();
      return;
    }
    if (!_checkEnd()) _botTurn();
  }

  void _botTurn() {
    if (isOnline) return;
    setState(() => thinking = true);
    // small human-like pause, then search (post-frame so the UI paints first)
    Timer(Duration(milliseconds: 350 + rng.nextInt(650)), () async {
      if (!mounted || finished) return;
      await Future<void>.delayed(const Duration(milliseconds: 16));
      final m = game.bestMove(botRating, rng);
      if (!mounted || finished) return;
      setState(() {
        if (m != null) {
          game.makeMove(m);
          lastMove = m;
        }
        thinking = false;
      });
      _checkEnd();
    });
  }

  // ---------------- finishing ----------------

  bool _checkEnd() {
    final r = game.result();
    if (r.isEmpty) return false;
    final iWon = (r == '1-0') == iPlayWhite && r != '½';
    _finish(iWon, r == '½',
        r == '½' ? 'Draw' : (game.inCheck ? 'Checkmate' : 'Game over'));
    return true;
  }

  void _resign() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: DC.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Resign?'),
        content: const Text('This counts as a loss.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Keep playing')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Resign')),
        ],
      ),
    );
    if (sure == true && !finished) {
      if (isOnline) {
        AccountService.instance
            .roomWrite(widget.room!['id'], 'state/resign', mySide);
      }
      _finish(false, false, 'Resigned');
    }
  }

  void _finish(bool won, bool draw, String how) {
    if (finished) return;
    finished = true;
    _clock?.cancel();
    if (won) {
      Fx.win();
    } else if (!draw) {
      Fx.lose();
    }
    final a = AppData.i;
    var delta = 0;
    var leveledUp = false;
    int rewardCoins = 0, rewardXp = 0;
    if (isJourney) {
      final lvl = widget.journeyLevel!;
      leveledUp = a.recordChessJourney(won);
      if (won) {
        rewardCoins = 40 + lvl * 10 + (leveledUp ? 100 : 0);
        rewardXp = 30 + lvl * 5 + (leveledUp ? 50 : 0);
        a.addCoins(rewardCoins);
      }
      rewardXp = won ? rewardXp : 8;
      a.addXp(rewardXp);
      a.recordMatch(
          mode: 'Journey ♟ L$lvl',
          opponent: botName,
          result: won ? 'W' : (draw ? 'D' : 'L'));
    } else {
      delta = a.applyElo(botRating, won ? 1 : (draw ? 0.5 : 0));
      // Wager coins only move against a REAL human — bot matches would be
      // farmable, so they pay XP only.
      if (widget.wager > 0 && isOnline) {
        if (won) a.addCoins(widget.wager * 2);
        if (draw) a.addCoins(widget.wager);
      }
      a.addXp(won ? 40 : (draw ? 20 : 10));
      a.recordMatch(
          mode: (isOnline || widget.botMatch) ? 'Chess ♟ online' : 'Chess ♟',
          opponent: botName,
          result: won ? 'W' : (draw ? 'D' : 'L'),
          delta: delta);
    }
    widget.arenaScore?.call(won
        ? 100000 + myClockMs ~/ 100
        : draw
            ? 50000 + myClockMs ~/ 200
            : 0);
    AccountService.instance.updatePublicProfile();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: DC.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (won) const ConfettiBurst(height: 70),
            Icon(won ? Icons.emoji_events : Icons.psychology_alt,
                size: 60, color: won ? DC.amber : DC.violet),
            const SizedBox(height: 10),
            Text(
                leveledUp
                    ? 'LEVEL UP! 🚀'
                    : won
                        ? 'VICTORY!'
                        : (draw ? 'DRAW' : 'DEFEAT'),
                style: Theme.of(context).textTheme.displayMedium),
            Text('$how · vs $botName ($botRating)',
                style: TextStyle(color: DC.dim)),
            const SizedBox(height: 8),
            if (isJourney)
              Text(
                  leveledUp
                      ? 'Level ${widget.journeyLevel! + 1} unlocked — ${AppData.chessLevelElo(AppData.i.chessLevel)} Elo awaits'
                      : won
                          ? 'Game ${AppData.i.chessWins}/5 of Level ${widget.journeyLevel} ✅ +$rewardCoins 🪙 +$rewardXp XP'
                          : 'No progress lost — run it back 😤 (+$rewardXp XP)',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: won ? DC.lime : DC.dim,
                      fontWeight: FontWeight.w700,
                      fontSize: 13))
            else
              Text('${delta >= 0 ? '+' : ''}$delta rating',
                  style: TextStyle(
                      color: delta >= 0 ? DC.lime : DC.danger,
                      fontWeight: FontWeight.w900,
                      fontSize: 18)),
            if (widget.wager > 0 && isOnline)
              Text(
                  won
                      ? '+${widget.wager} coins 🪙'
                      : draw
                          ? 'wager returned'
                          : '−${widget.wager} coins',
                  style: TextStyle(color: DC.amber)),
            const SizedBox(height: 8),
            const ReactionBar(),
            TextButton.icon(
              onPressed: () => shareResult(
                  context,
                  won
                      ? 'Checkmated $botName ($botRating) in ${game.fullmove} moves on MYNDASH ♟🔥 Who wants some?'
                      : 'Played real chess vs $botName ($botRating) on MYNDASH ♟ Running it back.'),
              icon: Icon(Icons.ios_share, size: 16, color: DC.cyan),
              label: Text('Share result',
                  style: TextStyle(color: DC.cyan, fontSize: 13)),
            ),
            const SizedBox(height: 6),
            if (isOnline)
              RematchButton(room: widget.room!, amHost: widget.amHost)
            else if (widget.journeyLevel == null)
              NeonButton(
                // A disguised bot-fallback match ("online" but no room)
                // must not offer an instant guaranteed rematch with the
                // same bot — that's a tell it wasn't a real opponent.
                // Re-run matchmaking instead so it looks for a fresh one.
                label: widget.botMatch ? 'FIND NEW MATCH' : 'PLAY AGAIN',
                icon: Icons.refresh,
                height: 46,
                colors: [DC.magenta, DC.violet],
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (_) => widget.botMatch
                              ? MatchmakingScreen(
                                  game: 'chess',
                                  sub: 'std',
                                  label: 'Chess ',
                                  timeMinutes: widget.timeMinutes,
                                )
                              : ChessDuelScreen(
                                  practiceRating: widget.practiceRating,
                                  botName: widget.botName,
                                  botMatch: widget.botMatch,
                                  timeMinutes: widget.timeMinutes)));
                },
              ),
            if (widget.journeyLevel == null) const SizedBox(height: 8),
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

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    if (searching) {
      return Scaffold(
        body: ShaderBackground(
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(color: DC.cyan),
              const SizedBox(height: 18),
              Text('Finding a chess rival…',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(
                  'Wager: ${widget.wager == 0 ? 'friendly' : '${widget.wager} 🪙'}',
                  style: TextStyle(color: DC.dim, fontSize: 12)),
            ]),
          ),
        ),
      );
    }
    final a = AppData.i;
    final checkSq = game.inCheck ? game.kingSquare(game.whiteToMove) : -1;
    return Scaffold(
      body: ShaderBackground(
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(children: [
                Glass(
                    radius: 16,
                    padding: const EdgeInsets.all(8),
                    onTap: _resign,
                    child: Icon(Icons.flag, size: 18, color: DC.danger)),
                const SizedBox(width: 12),
                Text(
                    isJourney
                        ? 'JOURNEY · L${widget.journeyLevel} · G$journeyGame'
                        : 'REAL CHESS',
                    style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                if (widget.wager > 0)
                  Pill(
                      icon: Icons.monetization_on,
                      label: '${widget.wager}',
                      color: DC.amber),
              ]),
            ),
            const SizedBox(height: 8),
            _playerRow(
                name: botName,
                rating: botRating,
                white: !iPlayWhite,
                active: !myTurn && !finished,
                captured: game.capturedBy(!iPlayWhite),
                subtitle: thinking ? 'thinking…' : null,
                clockMs: timed ? botClockMs : null),
            const SizedBox(height: 8),
            Expanded(
              child: Center(
                child: LayoutBuilder(builder: (context, box) {
                  final side = min(box.maxWidth, box.maxHeight) - 16;
                  return SizedBox(
                    width: side,
                    height: side,
                    child: _board(side, checkSq),
                  );
                }),
              ),
            ),
            const SizedBox(height: 8),
            _playerRow(
                name: a.username.isEmpty ? a.name : '@${a.username}',
                rating: a.elo,
                white: iPlayWhite,
                active: myTurn,
                captured: game.capturedBy(iPlayWhite),
                subtitle: myTurn
                    ? (game.inCheck ? 'CHECK — defend your king!' : 'your move')
                    : null,
                clockMs: timed ? myClockMs : null),
            const SizedBox(height: 14),
          ]),
        ),
      ),
    );
  }

  Widget _playerRow({
    required String name,
    required int rating,
    required bool white,
    required bool active,
    required String captured,
    String? subtitle,
    int? clockMs,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Glass(
        radius: 18,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        border: active ? Border.all(color: DC.cyan, width: 1.5) : null,
        child: Row(children: [
          Text(white ? '♔' : '♚', style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$name · $rating',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 13)),
              if (subtitle != null)
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 11,
                        color:
                            subtitle.startsWith('CHECK') ? DC.danger : DC.cyan))
              else if (captured.isNotEmpty)
                Text(captured, style: TextStyle(fontSize: 12, color: DC.dim)),
            ]),
          ),
          if (clockMs != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: (clockMs <= 20000 ? DC.danger : DC.cyan)
                    .withOpacity(active ? 0.22 : 0.10),
                border: Border.all(
                    color: (clockMs <= 20000 ? DC.danger : DC.cyan)
                        .withOpacity(active ? 0.7 : 0.3)),
              ),
              child: Text(_fmtClock(clockMs),
                  style: TextStyle(
                      fontFeatures: const [FontFeature.tabularFigures()],
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: clockMs <= 20000 ? DC.danger : DC.text)),
            ),
            const SizedBox(width: 8),
          ],
          if (active)
            SizedBox(
                width: 14,
                height: 14,
                child:
                    CircularProgressIndicator(strokeWidth: 2, color: DC.cyan)),
        ]),
      ),
    );
  }

  Widget _board(double side, int checkSq) {
    final cell = (side - 12) / 8;
    // Walnut frame around the playing field — real-board feel.
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF5C3A1B), Color(0xFF3E2712), Color(0xFF57371A)]),
        boxShadow: const [
          BoxShadow(
              color: Colors.black54, blurRadius: 18, offset: Offset(0, 8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Column(children: [
          for (var row = 0; row < 8; row++)
            Row(children: [
              for (var col = 0; col < 8; col++)
                _square(_toIndex(row, col), cell, checkSq),
            ]),
        ]),
      ),
    );
  }

  /// Screen (row,col) → board index, flipping when playing black.
  int _toIndex(int row, int col) =>
      iPlayWhite ? row * 8 + col : (7 - row) * 8 + (7 - col);

  /// Vector piece — guaranteed pure white / pitch black on every device
  /// (see ChessPieceGlyph). Same silhouette both sides, only fill differs.
  Widget _piece(int p, double cell) =>
      ChessPieceGlyph(type: p.abs(), white: p > 0, size: cell * 0.9);

  Widget _square(int sq, double cell, int checkSq) {
    final light = (sq ~/ 8 + sq % 8) % 2 == 0;
    final p = game.board[sq];
    final isSel = selected == sq;
    final isHint = hints.any((m) => m.to == sq);
    final isCaptureHint =
        isHint && (p != 0 || hints.any((m) => m.to == sq && m.isEnPassant));
    final isLast =
        lastMove != null && (lastMove!.from == sq || lastMove!.to == sq);

    // Wooden board: warm oak / dark walnut with a soft in-square grain.
    Color bg = light ? const Color(0xFFD9B27E) : const Color(0xFF7B4F28);
    Color bg2 = light ? const Color(0xFFC9A069) : const Color(0xFF6A421F);
    if (isLast) {
      bg = Color.alphaBlend(DC.amber.withOpacity(0.38), bg);
      bg2 = Color.alphaBlend(DC.amber.withOpacity(0.30), bg2);
    }
    if (isSel) {
      bg = Color.alphaBlend(DC.cyan.withOpacity(0.42), bg);
      bg2 = Color.alphaBlend(DC.cyan.withOpacity(0.34), bg2);
    }
    if (sq == checkSq) {
      bg = Color.alphaBlend(DC.danger.withOpacity(0.55), bg);
      bg2 = Color.alphaBlend(DC.danger.withOpacity(0.45), bg2);
    }
    final labelColor =
        light ? const Color(0xAA5A3B18) : const Color(0xAAEBD9BC);

    return GestureDetector(
      onTap: () => _tapSquare(sq),
      child: Container(
        width: cell,
        height: cell,
        decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [bg, bg2]),
        ),
        child: Stack(alignment: Alignment.center, children: [
          if (sq % 8 == (iPlayWhite ? 0 : 7))
            Positioned(
              top: 2,
              left: 3,
              child: Text('${8 - sq ~/ 8}',
                  style: TextStyle(
                      fontSize: cell * 0.18,
                      color: labelColor,
                      fontWeight: FontWeight.w700)),
            ),
          if (sq ~/ 8 == (iPlayWhite ? 7 : 0))
            Positioned(
              bottom: 1,
              right: 3,
              child: Text(String.fromCharCode(97 + sq % 8),
                  style: TextStyle(
                      fontSize: cell * 0.18,
                      color: labelColor,
                      fontWeight: FontWeight.w700)),
            ),
          if (p != 0) _piece(p, cell),
          if (isHint && !isCaptureHint)
            Container(
              width: cell * 0.28,
              height: cell * 0.28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: DC.cyan.withOpacity(0.6),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 2)
                ],
              ),
            ),
          if (isCaptureHint)
            Container(
              width: cell * 0.92,
              height: cell * 0.92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border:
                    Border.all(color: DC.danger.withOpacity(0.85), width: 2.5),
              ),
            ),
        ]),
      ),
    );
  }
}

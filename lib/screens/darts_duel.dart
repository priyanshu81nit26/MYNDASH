import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../core/fx.dart';
import '../core/state.dart';
import '../services/account_service.dart';
import '../theme_district.dart';
import '../ui/extras.dart';
import '../ui/glass.dart';
import 'online_play.dart';
import 'darts_game.dart';

/// ============================================================
/// DARTS 1v1 — real swipe-throw physics (same engine as the
/// journey): 5 darts each, highest total wins.
/// Modes: rated bot, or ONLINE (matchmade / friend room) with
/// live opponent throws.
/// ============================================================
class DartsDuelScreen extends StatefulWidget {
  final int wager;
  final int? botRating;

  /// Online match room (host/guest). Wagers are bot-mode only.
  final Map<String, dynamic>? room;
  final bool amHost;

  /// True only when this is the disguised bot-fallback from online
  /// matchmaking (no human found in time) — as opposed to a kid-mode
  /// or practice "vs bot" pick, which are genuinely intentional.
  final bool matchmaking;

  const DartsDuelScreen(
      {super.key,
      this.wager = 0,
      this.botRating,
      this.room,
      this.amHost = true,
      this.matchmaking = false});

  @override
  State<DartsDuelScreen> createState() => _DartsDuelScreenState();
}

class _DartsDuelScreenState extends State<DartsDuelScreen> {
  static const throwsTotal = 5;
  final rng = Random();

  bool get isOnline => widget.room != null;
  late final String mySide = widget.amHost ? 'host' : 'guest';
  late final String oppSide = widget.amHost ? 'guest' : 'host';
  StreamSubscription? roomSub;

  late String oppName;
  late int oppRating;
  bool searching = true;
  bool finished = false;
  bool between = false;

  int myThrows = 0, myScore = 0;
  int oppThrows = 0, oppScore = 0;
  int? lastOppScore;

  static const _names = [
    'Nova',
    'Zephyr',
    'Kira',
    'Axel',
    'Mira',
    'Dash',
    'Rehan',
    'Tara',
  ];

  @override
  void initState() {
    super.initState();
    final a = AppData.i;
    if (isOnline) {
      final opp = Map<String, dynamic>.from(widget.room![oppSide] as Map);
      oppName = '@${opp['u']}';
      oppRating = (opp['elo'] as num?)?.toInt() ?? 800;
      searching = false;
      roomSub = AccountService.instance
          .roomStream(widget.room!['id'])
          .listen(_onRoom);
      AccountService.instance.pinRoom(widget.room!['id'], true);
      return;
    }
    oppName = _names[rng.nextInt(_names.length)];
    oppRating = widget.botRating ??
        (a.elo + rng.nextInt(300) - 150).clamp(500, 2600).toInt();
    // Bot matches are friendly — no coin stake (XP + rating only).
    // Bot mode is only ever reached via the Showdown "get ready" reveal,
    // which already introduced the opponent — a second spinner here just
    // stacks a redundant wait on top and reads as the match being stuck.
    searching = false;
  }

  @override
  void dispose() {
    roomSub?.cancel();
    if (isOnline && !finished) {
      AccountService.instance
          .roomWrite(widget.room!['id'], 'state/left', mySide);
      AccountService.instance.pinRoom(widget.room!['id'], false);
    }
    super.dispose();
  }

  // ---------------- online sync ----------------

  void _onRoom(Map<String, dynamic>? r) {
    if (r == null || finished || !mounted) return;
    final st = r['state'] as Map?;
    final o = st?[oppSide] as Map?;
    if (o != null) {
      // idx helpers: RTDB may hand throws back as a List OR a Map.
      final throws = o['throws'];
      var count = 0;
      var total = 0;
      int? last;
      while (true) {
        final v = idxValue(throws, count);
        if (v == null) break;
        last = (v as num).toInt();
        total += last;
        count++;
      }
      if (count != oppThrows) {
        setState(() {
          oppThrows = count;
          oppScore = total;
          lastOppScore = last;
        });
      }
    }
    if (st?['left'] == oppSide && !finished) {
      _finish(forfeitWin: true);
      return;
    }
    if (myThrows >= throwsTotal && oppThrows >= throwsTotal) _finish();
  }

  // ---------------- throws ----------------

  void _onThrow(DartHit hit) {
    if (finished || between || myThrows >= throwsTotal) return;
    between = true;
    myScore += hit.score;
    myThrows++;
    if (isOnline) {
      // 't' prefix avoids RTDB numeric-key list coercion.
      AccountService.instance.roomWrite(widget.room!['id'],
          'state/$mySide/throws/t${myThrows - 1}', hit.score);
    }
    setState(() {});
    Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      between = false;
      if (!isOnline) _botThrow();
      if (myThrows >= throwsTotal && (!isOnline || oppThrows >= throwsTotal)) {
        _finish();
      } else {
        setState(() {});
      }
    });
  }

  void _botThrow() {
    if (oppThrows >= throwsTotal) return;
    // rating 500→2600 maps to a 35..92 average with jitter
    final skill =
        (35 + (oppRating - 500) / 2100 * 57).clamp(20.0, 95.0).toDouble();
    final s = (skill + rng.nextDouble() * 24 - 12).clamp(0.0, 100.0).round();
    oppThrows++;
    oppScore += s;
    lastOppScore = s;
  }

  // ---------------- finish ----------------

  void _finish({bool forfeitWin = false}) {
    if (finished) return;
    finished = true;
    final a = AppData.i;
    final won = forfeitWin || myScore > oppScore;
    final draw = !forfeitWin && myScore == oppScore;
    if (won) {
      Fx.win();
    } else if (!draw) {
      Fx.lose();
    }
    final delta = a.applyElo(oppRating, won ? 1 : (draw ? 0.5 : 0));
    // Wager coins only move against a real human — bots pay XP only.
    if (isOnline && widget.wager > 0) {
      if (won) a.addCoins(widget.wager * 2);
      if (draw) a.addCoins(widget.wager);
    }
    a.addXp(won ? 35 : (draw ? 18 : 8));
    a.recordMatch(
        mode: isOnline ? 'Darts 🎯 online' : 'Darts 🎯',
        opponent: oppName,
        result: won ? 'W' : (draw ? 'D' : 'L'),
        delta: delta);
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
            Icon(won ? Icons.emoji_events : Icons.gps_off,
                size: 60, color: won ? DC.amber : DC.violet),
            const SizedBox(height: 10),
            Text(won ? 'VICTORY!' : (draw ? 'DRAW' : 'DEFEAT'),
                style: Theme.of(context).textTheme.displayMedium),
            Text(
                forfeitWin
                    ? '$oppName left the oche'
                    : '$myScore — $oppScore vs $oppName ($oppRating)',
                style: TextStyle(color: DC.dim)),
            const SizedBox(height: 8),
            Text('${delta >= 0 ? '+' : ''}$delta rating',
                style: TextStyle(
                    color: delta >= 0 ? DC.lime : DC.danger,
                    fontWeight: FontWeight.w900,
                    fontSize: 18)),
            if (isOnline && widget.wager > 0)
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
                      ? 'Out-thrown: $myScore–$oppScore vs $oppName in MYNDASH darts 🎯🔥'
                      : 'Darts went $myScore–$oppScore vs $oppName on MYNDASH. Reloading 😤'),
              icon: Icon(Icons.ios_share, size: 16, color: DC.cyan),
              label: Text('Share result',
                  style: TextStyle(color: DC.cyan, fontSize: 13)),
            ),
            const SizedBox(height: 6),
            if (widget.room != null)
              RematchButton(room: widget.room!, amHost: widget.amHost)
            else
              NeonButton(
                // A disguised bot-fallback match must not offer an instant
                // guaranteed rematch with the same bot — re-run
                // matchmaking instead so it looks for a fresh opponent.
                label: widget.matchmaking ? 'FIND NEW MATCH' : 'PLAY AGAIN',
                icon: Icons.refresh,
                height: 46,
                colors: [DC.magenta, DC.violet],
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (_) => widget.matchmaking
                              ? MatchmakingScreen(
                                  game: 'darts',
                                  sub: 'std',
                                  label: 'Darts ',
                                  botScreen: () => const DartsDuelScreen(),
                                )
                              : const DartsDuelScreen()));
                },
              ),
            const SizedBox(height: 8),
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
              CircularProgressIndicator(color: DC.amber),
              const SizedBox(height: 18),
              Text('Finding a darts rival…',
                  style: Theme.of(context).textTheme.titleLarge),
            ]),
          ),
        ),
      );
    }
    final doneThrowing = myThrows >= throwsTotal;
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
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.flag, size: 18, color: DC.danger)),
                const SizedBox(width: 10),
                Text(isOnline ? 'LIVE DARTS' : 'DARTS 1v1',
                    style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                if (!isOnline && widget.wager > 0)
                  Pill(
                      icon: Icons.monetization_on,
                      label: '${widget.wager}',
                      color: DC.amber),
              ]),
            ),
            const SizedBox(height: 6),
            // scoreboard
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Glass(
                radius: 18,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(children: [
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('YOU',
                              style: TextStyle(
                                  fontSize: 10,
                                  letterSpacing: 2,
                                  color: DC.cyan)),
                          Text('$myScore',
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.w900)),
                          _dots(myThrows, DC.cyan),
                        ]),
                  ),
                  Text('VS',
                      style: TextStyle(
                          color: DC.dim, fontWeight: FontWeight.w900)),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('$oppName · $oppRating',
                              style: TextStyle(
                                  fontSize: 10,
                                  letterSpacing: 1,
                                  color: DC.magenta)),
                          Text('$oppScore',
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.w900)),
                          _dots(oppThrows, DC.magenta),
                        ]),
                  ),
                ]),
              ),
            ),
            if (lastOppScore != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('$oppName threw +$lastOppScore',
                    style: TextStyle(fontSize: 11, color: DC.magenta)),
              ),
            Expanded(
              child: doneThrowing
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        CircularProgressIndicator(color: DC.magenta),
                        const SizedBox(height: 12),
                        Text(
                            isOnline
                                ? 'Waiting for $oppName… ($oppThrows/$throwsTotal darts)'
                                : 'Counting up…',
                            style: TextStyle(color: DC.dim)),
                      ]),
                    )
                  : DartThrowBoard(
                      config:
                          const DartConfig(boardScale: 0.85, boardSpeed: 0.18),
                      enabled: !finished && !between && !doneThrowing,
                      onThrow: _onThrow,
                    ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _dots(int filled, Color color) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 0; i < throwsTotal; i++)
        Container(
          margin: const EdgeInsets.only(right: 3, top: 3),
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: i < filled ? color : DC.fg24,
          ),
        ),
    ]);
  }
}

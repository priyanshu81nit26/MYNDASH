import 'dart:async';

import 'package:flutter/material.dart';

import '../game/rounds.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';
import '../theme.dart';
import '../widgets/glass.dart';
import 'result_screen.dart';

/// The online duel. Best of 7 — first to 4 round wins.
///
/// The host publishes each round spec (type + seed + a shared
/// server-clock "go" timestamp). Both phones render the identical
/// challenge, measure the player's reaction locally, and submit it.
/// The host compares reaction times — so network lag never decides
/// a round.
class GameScreen extends StatefulWidget {
  final String code;
  const GameScreen({super.key, required this.code});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final svc = FirebaseService.instance;
  StreamSubscription<Room?>? _sub;
  Room? _room;

  int _publishedIndex = -1; // host: last round index published
  int _resolvedIndex = -1; // host: last round index resolved
  bool _submitted = false;
  int _submittedIndex = -1;
  Timer? _nextRoundTimer;
  Timer? _timeoutTimer;
  bool _navigatedOut = false;

  bool get _isHost => _room?.hostUid == svc.uid;

  @override
  void initState() {
    super.initState();
    _sub = svc.roomStream(widget.code).listen(_onRoom);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _nextRoundTimer?.cancel();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  void _onRoom(Room? room) {
    if (!mounted || _navigatedOut) return;
    setState(() => _room = room);

    if (room == null) {
      _navigatedOut = true;
      Navigator.popUntil(context, (r) => r.isFirst);
      return;
    }

    if (room.state == 'done') {
      _navigatedOut = true;
      _nextRoundTimer?.cancel();
      _timeoutTimer?.cancel();
      Navigator.pushReplacement(context,
          MaterialPageRoute(builder: (_) => ResultScreen(code: widget.code)));
      return;
    }

    if (room.state != 'playing') return;

    final round = room.currentRound;

    // Reset per-round submission flag.
    if (round != null && round.index != _submittedIndex) {
      _submitted = false;
    }

    // ---------- host duties ----------
    if (!_isHost) return;

    if (round == null) {
      // Need to publish the next round (with a short interstitial gap).
      final nextIndex = (room.lastRound?['i'] as num?)?.toInt() != null
          ? ((room.lastRound!['i'] as num).toInt() + 1)
          : 0;
      if (_publishedIndex >= nextIndex) return;
      _publishedIndex = nextIndex;
      final delay = room.lastRound == null ? 900 : 3000;
      _nextRoundTimer?.cancel();
      _nextRoundTimer = Timer(Duration(milliseconds: delay), () {
        if (!mounted || _navigatedOut) return;
        svc.publishRound(widget.code,
            RoundSpec.generate(index: nextIndex, serverNowMs: svc.nowMs()));
      });
      return;
    }

    // Round in progress: resolve when both results are in, or on timeout.
    final haveBoth = room.guestUid != null &&
        room.results.containsKey(room.hostUid) &&
        room.results.containsKey(room.guestUid);

    if (haveBoth && round.index > _resolvedIndex) {
      _resolvedIndex = round.index;
      _timeoutTimer?.cancel();
      _resolve(room, round);
    } else if (round.index > _resolvedIndex) {
      _timeoutTimer?.cancel();
      final msLeft = (round.goAtMs + 13000) - svc.nowMs();
      _timeoutTimer =
          Timer(Duration(milliseconds: msLeft.clamp(500, 20000).toInt()), () {
        final r = _room;
        if (!mounted ||
            _navigatedOut ||
            r == null ||
            r.currentRound?.index != round.index) {
          return;
        }
        if (r.currentRound!.index > _resolvedIndex) {
          _resolvedIndex = r.currentRound!.index;
          _resolve(r, r.currentRound!);
        }
      });
    }
  }

  void _resolve(Room room, RoundSpec round) {
    final host = room.hostUid;
    final guest = room.guestUid!;
    final tHost = room.results[host]?.timeMs ?? -1;
    final tGuest = room.results[guest]?.timeMs ?? -1;

    String? winner;
    if (tHost >= 0 && (tGuest < 0 || tHost < tGuest)) winner = host;
    if (tGuest >= 0 && (tHost < 0 || tGuest < tHost)) winner = guest;
    // both invalid or exactly equal → draw (winner stays null)

    final scores = <String, int>{
      host: room.players[host]?.score ?? 0,
      guest: room.players[guest]?.score ?? 0,
    };
    if (winner != null) scores[winner] = (scores[winner] ?? 0) + 1;

    svc.resolveRound(
      code: widget.code,
      room: room,
      newScores: scores,
      roundWinner: winner,
      times: {host: tHost, guest: tGuest},
    );
  }

  void _onRoundFinish(RoundSpec round, int timeMs) {
    if (_submitted && _submittedIndex == round.index) return;
    _submitted = true;
    _submittedIndex = round.index;
    svc.submitResult(widget.code, timeMs);
  }

  Future<void> _leave() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Forfeit the duel?'),
        content: const Text('Leaving now counts as a loss.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Stay')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Forfeit')),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    final room = _room;
    final opp = room?.opponent(svc.uid);
    if (room != null && opp != null) {
      await svc.roomRef(widget.code).update({
        'state': 'done',
        'winner': opp.uid,
      });
    } else {
      _navigatedOut = true;
      if (mounted) Navigator.popUntil(context, (r) => r.isFirst);
    }
  }

  Future<void> _claimWin() async {
    await svc.roomRef(widget.code).update({
      'state': 'done',
      'winner': svc.uid,
    });
  }

  @override
  Widget build(BuildContext context) {
    final room = _room;
    if (room == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final me = room.me(svc.uid);
    final opp = room.opponent(svc.uid);
    final round = room.currentRound;
    final roundNo =
        (round?.index ?? (room.lastRound?['i'] as num?)?.toInt() ?? 0) + 1;

    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          child: Column(
            children: [
              // ---------- header ----------
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  children: [
                    GlassCard(
                      padding: const EdgeInsets.all(8),
                      radius: 16,
                      onTap: _leave,
                      child: const Icon(Icons.close, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GlassCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        radius: 20,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _scoreSide(context, me?.name ?? 'You',
                                me?.score ?? 0, RDColors.cyan, true),
                            Column(
                              children: [
                                Text('ROUND $roundNo',
                                    style: const TextStyle(
                                        fontSize: 10, letterSpacing: 2)),
                                Text('FIRST TO ${room.targetScore}',
                                    style: TextStyle(
                                        fontSize: 9,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.5))),
                              ],
                            ),
                            _scoreSide(context, opp?.name ?? '…',
                                opp?.score ?? 0, RDColors.magenta, false),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (opp != null && !opp.connected)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GlassCard(
                    tint: RDColors.danger,
                    padding: const EdgeInsets.all(10),
                    radius: 16,
                    child: Row(
                      children: [
                        const Icon(Icons.wifi_off,
                            color: RDColors.danger, size: 18),
                        const SizedBox(width: 8),
                        const Expanded(
                            child: Text('Opponent disconnected…',
                                style: TextStyle(fontSize: 13))),
                        TextButton(
                            onPressed: _claimWin,
                            child: const Text('Claim win')),
                      ],
                    ),
                  ),
                ),
              // ---------- arena ----------
              Expanded(
                child: round != null
                    ? RoundPlayer(
                        key: ValueKey('round-${round.index}'),
                        spec: round,
                        nowMs: svc.nowMs,
                        onFinish: (t) => _onRoundFinish(round, t),
                      )
                    : _interstitial(context, room),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scoreSide(
      BuildContext context, String name, int score, Color c, bool alignLeft) {
    return Column(
      crossAxisAlignment:
          alignLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Text(name.length > 10 ? '${name.substring(0, 10)}…' : name,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        Text('$score',
            style:
                TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: c)),
      ],
    );
  }

  Widget _interstitial(BuildContext context, Room room) {
    final last = room.lastRound;
    if (last == null) {
      return const Center(
          child: Text('GET READY…',
              style: TextStyle(letterSpacing: 4, fontSize: 18)));
    }
    final winner = last['winner'] as String?;
    final times = (last['times'] as Map<dynamic, dynamic>?) ?? {};
    final myT = (times[svc.uid] as num?)?.toInt() ?? -1;
    final opp = room.opponent(svc.uid);
    final oppT = (times[opp?.uid] as num?)?.toInt() ?? -1;

    final won = winner == svc.uid;
    final draw = winner == null;
    final color =
        draw ? RDColors.amber : (won ? RDColors.lime : RDColors.danger);
    final label = draw ? 'DRAW!' : (won ? 'ROUND WON!' : 'ROUND LOST');

    return Center(
      child: GlassCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
                draw
                    ? Icons.balance
                    : (won ? Icons.emoji_events : Icons.sentiment_dissatisfied),
                color: color,
                size: 52),
            const SizedBox(height: 10),
            Text(label,
                style: Theme.of(context)
                    .textTheme
                    .displayMedium
                    ?.copyWith(color: color)),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScorePill(
                    label: 'YOU',
                    value: myT < 0 ? 'FAULT' : '$myT ms',
                    color: RDColors.cyan),
                const SizedBox(width: 12),
                ScorePill(
                    label: opp?.name ?? 'RIVAL',
                    value: oppT < 0 ? 'FAULT' : '$oppT ms',
                    color: RDColors.magenta),
              ],
            ),
            const SizedBox(height: 12),
            Text('Next round incoming…',
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.5))),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';
import '../theme.dart';
import '../widgets/glass.dart';
import 'game_screen.dart';

/// Match over: victory/defeat, XP + rank progress, rematch.
class ResultScreen extends StatefulWidget {
  final String code;
  const ResultScreen({super.key, required this.code});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final svc = FirebaseService.instance;
  final app = AppState.instance;
  StreamSubscription<Room?>? _sub;
  Room? _room;
  bool _recorded = false;
  bool _navigated = false;
  int _xpBefore = 0;

  @override
  void initState() {
    super.initState();
    _xpBefore = app.profile.xp;
    _sub = svc.roomStream(widget.code).listen((room) async {
      if (!mounted || _navigated) return;
      setState(() => _room = room);
      if (room == null) return;

      // Record stats exactly once when we see the finished room.
      if (room.state == 'done' && !_recorded) {
        _recorded = true;
        final won = room.winnerUid == svc.uid;
        final myScore = room.me(svc.uid)?.score ?? 0;
        app.profile = await svc.recordMatch(
            profile: app.profile, won: won, roundsWon: myScore);
        app.persistLocal();
        if (mounted) setState(() {});
      }

      // Opponent (or we) triggered a rematch.
      if (room.state == 'playing') {
        _navigated = true;
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => GameScreen(code: widget.code)));
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final room = _room;
    if (room == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final won = room.winnerUid == svc.uid;
    final me = room.me(svc.uid);
    final opp = room.opponent(svc.uid);
    final xpGain = app.profile.xp - _xpBefore;
    final rank = Rank.forXp(app.profile.xp);
    final next = Rank.next(app.profile.xp);
    final oppHere = opp?.connected ?? false;

    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(),
                Icon(won ? Icons.emoji_events : Icons.shield_moon,
                    size: 88, color: won ? RDColors.amber : RDColors.violet),
                const SizedBox(height: 12),
                ShaderMask(
                  shaderCallback: (r) => LinearGradient(
                          colors: won
                              ? [RDColors.amber, RDColors.magenta]
                              : [RDColors.violet, RDColors.cyan])
                      .createShader(r),
                  child: Text(won ? 'VICTORY!' : 'DEFEAT',
                      style: Theme.of(context)
                          .textTheme
                          .displayLarge
                          ?.copyWith(color: Colors.white)),
                ),
                const SizedBox(height: 8),
                Text(
                  won
                      ? (app.profile.streak > 1
                          ? '${app.profile.streak} WIN STREAK 🔥'
                          : 'Well played, ${me?.name ?? ''}!')
                      : 'Revenge is one tap away.',
                  style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.7)),
                ),
                const SizedBox(height: 28),
                GlassCard(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ScorePill(
                              label: me?.name ?? 'YOU',
                              value: '${me?.score ?? 0}',
                              color: RDColors.cyan),
                          const Text('VS',
                              style: TextStyle(
                                  fontWeight: FontWeight.w900, fontSize: 16)),
                          ScorePill(
                              label: opp?.name ?? 'RIVAL',
                              value: '${opp?.score ?? 0}',
                              color: RDColors.magenta),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ScorePill(
                              label: 'XP EARNED',
                              value: '+$xpGain',
                              color: RDColors.lime),
                          ScorePill(
                              label: next == null
                                  ? 'MAX RANK'
                                  : '${next.minXp - app.profile.xp} XP TO ${next.name.toUpperCase()}',
                              value: rank.name.toUpperCase(),
                              color: rank.color),
                        ],
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                NeonButton(
                  label: oppHere ? 'REMATCH' : 'OPPONENT LEFT',
                  icon: Icons.replay,
                  onPressed: oppHere ? () => svc.rematch(widget.code) : null,
                ),
                const SizedBox(height: 12),
                GlassButton(
                  label: 'BACK TO HOME',
                  height: 50,
                  onPressed: () {
                    _navigated = true;
                    Navigator.popUntil(context, (r) => r.isFirst);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

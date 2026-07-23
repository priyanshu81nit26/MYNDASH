import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../core/state.dart';
import '../game/rounds.dart';
import '../models/models.dart';
import '../services/account_service.dart';
import '../services/firebase_service.dart';
import '../theme.dart';
import '../widgets/glass.dart';

/// Offline duel vs an AI bot — same rounds, same rules.
/// Works with or without Firebase configured.
class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  final app = AppState.instance;
  final bot = DuelBot();

  // Present the practice/fallback opponent as a normal rival — no "BOT"
  // label or robot icon giving it away.
  static const _oppNames = [
    'Aarav',
    'Zoya',
    'Kabir',
    'Mira',
    'Rohan',
    'Ishaan',
    'Anaya',
    'Vikram',
    'Neha',
    'Arjun',
    'Sara',
    'Dev',
  ];
  late final String oppName = _oppNames[Random().nextInt(_oppNames.length)];

  int myScore = 0;
  int botScore = 0;
  int roundIndex = 0;
  RoundSpec? spec;
  bool done = false;

  // interstitial data
  int? lastMyT;
  int? lastBotT;
  bool? lastWon;
  bool? lastDraw;
  Timer? _next;

  int _now() => DateTime.now().millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    _startRound(first: true);
  }

  @override
  void dispose() {
    _next?.cancel();
    super.dispose();
  }

  void _startRound({bool first = false}) {
    _next?.cancel();
    _next = Timer(Duration(milliseconds: first ? 600 : 2600), () {
      if (!mounted) return;
      setState(() {
        spec = RoundSpec.generate(index: roundIndex, serverNowMs: _now());
        lastMyT = null;
      });
    });
  }

  void _onFinish(int t) {
    final s = spec;
    if (s == null) return;
    final botT = bot.reactFor(s.type, roundIndex);

    bool? won;
    if (t >= 0 && (botT < 0 || t < botT)) won = true;
    if (botT >= 0 && (t < 0 || botT < t)) won = false;

    setState(() {
      lastMyT = t;
      lastBotT = botT;
      lastDraw = won == null;
      lastWon = won;
      if (won == true) myScore++;
      if (won == false) botScore++;
      roundIndex++;
      spec = null;
      if (myScore >= 4 || botScore >= 4) {
        done = true;
        _recordXp(myScore >= 4);
      }
    });
    if (!done) _startRound();
  }

  void _recordXp(bool won) {
    app.profile.xp += won ? 30 : 10;
    if (won) {
      app.profile.wins++;
    }
    app.persistLocal();
    if (app.online) FirebaseService.instance.saveProfile(app.profile);
    // MYNDASH platform: match history + activity heatmap + earned XP
    AppData.i.addXp(won ? 30 : 10);
    AppData.i.recordMatch(
        mode: 'Reflex ⚡', opponent: 'BOT', result: won ? 'W' : 'L');
    AccountService.instance.updatePublicProfile();
  }

  void _rematch() {
    setState(() {
      myScore = 0;
      botScore = 0;
      roundIndex = 0;
      done = false;
      lastMyT = null;
      spec = null;
    });
    _startRound(first: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuroraBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  children: [
                    GlassCard(
                      padding: const EdgeInsets.all(8),
                      radius: 16,
                      onTap: () => Navigator.pop(context),
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
                            _side(context, app.profile.name, myScore,
                                RDColors.cyan),
                            const Text('PRACTICE',
                                style:
                                    TextStyle(fontSize: 10, letterSpacing: 2)),
                            _side(context, oppName, botScore, RDColors.magenta),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: done
                    ? _doneView(context)
                    : (spec != null
                        ? RoundPlayer(
                            key: ValueKey('p-$roundIndex'),
                            spec: spec!,
                            nowMs: _now,
                            onFinish: _onFinish,
                          )
                        : _interstitial(context)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _side(BuildContext context, String name, int score, Color c) => Column(
        children: [
          Text(name.length > 10 ? '${name.substring(0, 10)}…' : name,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          Text('$score',
              style: TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w900, color: c)),
        ],
      );

  Widget _interstitial(BuildContext context) {
    if (lastMyT == null) {
      return const Center(
          child: Text('GET READY…',
              style: TextStyle(letterSpacing: 4, fontSize: 18)));
    }
    final color = lastDraw == true
        ? RDColors.amber
        : (lastWon == true ? RDColors.lime : RDColors.danger);
    final label = lastDraw == true
        ? 'DRAW!'
        : (lastWon == true ? 'ROUND WON!' : 'ROUND LOST');
    return Center(
      child: GlassCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
                    value: lastMyT! < 0 ? 'FAULT' : '$lastMyT ms',
                    color: RDColors.cyan),
                const SizedBox(width: 12),
                ScorePill(
                    label: 'BOT',
                    value: lastBotT! < 0 ? 'FAULT' : '$lastBotT ms',
                    color: RDColors.magenta),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _doneView(BuildContext context) {
    final won = myScore >= 4;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: GlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(won ? Icons.emoji_events : Icons.flag_rounded,
                  size: 64, color: won ? RDColors.amber : RDColors.magenta),
              const SizedBox(height: 12),
              Text(won ? 'VICTORY!' : '$oppName WINS',
                  style: Theme.of(context).textTheme.displayMedium),
              const SizedBox(height: 6),
              Text('$myScore — $botScore',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text('+${won ? 30 : 10} XP',
                  style: const TextStyle(color: RDColors.cyan, fontSize: 14)),
              const SizedBox(height: 20),
              NeonButton(
                  label: 'PLAY AGAIN', icon: Icons.replay, onPressed: _rematch),
              const SizedBox(height: 12),
              GlassButton(
                  label: 'HOME',
                  height: 48,
                  onPressed: () => Navigator.pop(context)),
            ],
          ),
        ),
      ),
    );
  }
}

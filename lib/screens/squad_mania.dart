import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../core/state.dart';
import '../engine/generators.dart';
import '../engine/question.dart';
import '../services/account_service.dart';
import '../theme_district.dart';
import '../ui/art.dart';
import '../ui/glass.dart';

/// ============================================================
/// SQUAD MANIA 🏆 — the monthly inter-squad war.
/// Kicks off on the 1st of every month:
///   entry 10 🪙 per squad → base league → top 16 → top 8 →
///   semis → final. Prize pot = 10 × squads entered:
///   🥇 ½ · 🥈 ¼ · 🥉 & 4th ⅛ each.
/// Every member's score adds to the squad total. Challenges are
/// short, TIMED and visual (memory flashes, stroop, rotations,
/// speed chains) — physically impossible to outsource to ChatGPT
/// inside the clock.
/// ============================================================

String maniaMonthKey([DateTime? d]) {
  final n = d ?? DateTime.now();
  return '${n.year}-${n.month.toString().padLeft(2, '0')}';
}

/// Stage of the month. Everything is derived from the calendar so
/// every device agrees without a server.
enum ManiaStage { registration, base, r16, qf, sf, finals, results }

(ManiaStage, String, DateTime) maniaStageFor(DateTime now) {
  DateTime day(int d) => DateTime(now.year, now.month, d);
  final d = now.day;
  if (d <= 3) return (ManiaStage.registration, 'base', day(4));
  if (d <= 14) return (ManiaStage.base, 'base', day(15));
  if (d <= 18) return (ManiaStage.r16, 'r16', day(19));
  if (d <= 22) return (ManiaStage.qf, 'qf', day(23));
  if (d <= 25) return (ManiaStage.sf, 'sf', day(26));
  if (d <= 28) return (ManiaStage.finals, 'final', day(29));
  // results until next month's 1st
  final next = now.month == 12
      ? DateTime(now.year + 1, 1, 1)
      : DateTime(now.year, now.month + 1, 1);
  return (ManiaStage.results, 'final', next);
}

String maniaStageLabel(ManiaStage s) => switch (s) {
      ManiaStage.registration => 'REGISTRATION OPEN',
      ManiaStage.base => 'BASE LEAGUE',
      ManiaStage.r16 => 'ROUND OF 16',
      ManiaStage.qf => 'QUARTER-FINALS',
      ManiaStage.sf => 'SEMI-FINALS',
      ManiaStage.finals => 'GRAND FINAL',
      ManiaStage.results => 'RESULTS',
    };

/// How many squads survive INTO a round.
int maniaCut(String round) => switch (round) {
      'r16' => 16,
      'qf' => 8,
      'sf' => 4,
      'final' => 2,
      _ => 1 << 30,
    };

String fmtLeftLong(Duration d) {
  if (d.isNegative) return 'now';
  if (d.inDays >= 1) return '${d.inDays}d ${d.inHours % 24}h';
  if (d.inHours >= 1) return '${d.inHours}h ${d.inMinutes % 60}m';
  return '${d.inMinutes}m ${d.inSeconds % 60}s';
}

/// ============================================================
/// MAIN SCREEN
/// ============================================================
class SquadManiaScreen extends StatefulWidget {
  const SquadManiaScreen({super.key});

  @override
  State<SquadManiaScreen> createState() => _SquadManiaScreenState();
}

class _SquadManiaScreenState extends State<SquadManiaScreen> {
  final svc = AccountService.instance;
  Timer? ticker;
  bool loading = true;
  bool busy = false;

  Map<String, dynamic> squadsIn = {}; // squadId -> {name, tag}
  Map<String, dynamic> roundScores = {}; // squadId -> {user: score}
  Map<String, dynamic> prevRoundScores = {}; // for eligibility
  bool claimed = false;

  String get month => maniaMonthKey();
  (ManiaStage, String, DateTime) get stage => maniaStageFor(DateTime.now());
  bool get inSquad => AppData.i.squadId.isNotEmpty;
  bool get registered => squadsIn.containsKey(AppData.i.squadId);

  @override
  void initState() {
    super.initState();
    _load();
    ticker = Timer.periodic(
        const Duration(seconds: 1), (_) => mounted ? setState(() {}) : null);
  }

  @override
  void dispose() {
    ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final (_, round, __) = stage;
    final s = await svc.maniaFetch('squad_mania/$month/squads');
    final sc = await svc.maniaFetch('squad_mania/$month/scores/$round');
    final prev =
        await svc.maniaFetch('squad_mania/$month/scores/${_prevRound(round)}');
    final cl = (AppData.i.squadId.isEmpty || AppData.i.username.isEmpty)
        ? null
        : await svc.maniaFetch(
            'squad_mania/$month/claims/${AppData.i.squadId}/${AppData.i.username}');
    if (!mounted) return;
    setState(() {
      squadsIn = s ?? {};
      roundScores = sc ?? {};
      prevRoundScores = prev ?? {};
      claimed = cl != null;
      loading = false;
    });
  }

  String _prevRound(String r) => switch (r) {
        'r16' => 'base',
        'qf' => 'r16',
        'sf' => 'qf',
        'final' => 'sf',
        _ => 'base',
      };

  /// Team totals for a score map: squadId → summed member scores.
  List<MapEntry<String, int>> _totals(Map<String, dynamic> scores) {
    final out = <MapEntry<String, int>>[];
    scores.forEach((sid, users) {
      var sum = 0;
      ((users as Map?) ?? {}).forEach((_, v) => sum += (v as num).toInt());
      out.add(MapEntry('$sid', sum));
    });
    out.sort((a, b) => b.value.compareTo(a.value));
    return out;
  }

  /// Is my squad still alive in the current round?
  bool _eligible(String round) {
    if (!registered) return false;
    if (round == 'base') return true;
    final prev = _totals(prevRoundScores);
    final cut = maniaCut(round);
    final idx = prev.indexWhere((e) => e.key == AppData.i.squadId);
    // squads that never scored in the previous round are out
    return idx >= 0 && idx < cut;
  }

  bool get _playedThisRound {
    final mine = roundScores[AppData.i.squadId] as Map?;
    return mine?.containsKey(AppData.i.username) == true;
  }

  Future<void> _register() async {
    if (!inSquad) return;
    if (!AppData.i.isSquadLeader) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Only the squad admin (creator) can register the squad for events.')));
      return;
    }
    if (AppData.i.coins < 10) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Registration costs 10 🪙 — you need 10 coins.')));
      return;
    }
    setState(() => busy = true);
    final err = await svc.maniaRegister(month);
    if (!mounted) return;
    setState(() => busy = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } else {
      AppData.i.spendCoins(10);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '🏆 ${AppData.i.squadName} is IN! Base league starts on the 4th.')));
    }
    _load();
  }

  Future<void> _play() async {
    final (_, round, __) = stage;
    final score = await Navigator.push<int>(
        context,
        MaterialPageRoute(
            builder: (_) => ManiaPlayScreen(month: month, round: round)));
    if (score == null || !mounted) return;
    setState(() => busy = true);
    final err = await svc.maniaSubmitScore(month, round, score);
    if (!mounted) return;
    setState(() => busy = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err ??
            '+$score pts banked for ${AppData.i.squadName}! Every point counts.')));
    _load();
  }

  // ---- final ranking + prize logic (results stage) ----

  List<(String, int, int)> _finalRanking() {
    // 1st & 2nd from the final; 3rd & 4th are the semi losers by score
    final fin = _totals(roundScores.isEmpty ? {} : roundScores);
    final sf = _totals(prevRoundScores);
    final pot = 10 * squadsIn.length;
    final out = <(String, int, int)>[];
    if (fin.isNotEmpty) out.add((fin[0].key, 1, pot ~/ 2));
    if (fin.length > 1) out.add((fin[1].key, 2, pot ~/ 4));
    final finIds = fin.map((e) => e.key).toSet();
    final losers = sf.where((e) => !finIds.contains(e.key)).toList();
    if (losers.isNotEmpty) out.add((losers[0].key, 3, pot ~/ 8));
    if (losers.length > 1) out.add((losers[1].key, 4, pot ~/ 8));
    return out;
  }

  Future<void> _claim(int squadPrize) async {
    setState(() => busy = true);
    final err = await svc.maniaClaim(month, squadPrize, maxShare: squadPrize);
    if (!mounted) return;
    setState(() => busy = false);
    if (err == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prize share added to your wallet 🪙')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final (st, round, nextAt) = stage;
    final left = nextAt.difference(DateTime.now());
    final totals = _totals(roundScores);
    final pot = 10 * squadsIn.length;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ShaderBackground(
        child: SafeArea(
          child: RefreshIndicator(
            color: DC.amber,
            onRefresh: _load,
            child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  Row(children: [
                    Glass(
                        radius: 16,
                        padding: const EdgeInsets.all(8),
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.arrow_back, size: 18)),
                    const SizedBox(width: 12),
                    Text('SQUAD MANIA',
                        style: Theme.of(context).textTheme.titleLarge),
                    const Spacer(),
                    Pill(
                        icon: Icons.monetization_on,
                        label: 'pot $pot',
                        color: DC.amber),
                  ]),
                  const SizedBox(height: 14),
                  // ---------- hero: stage + countdown ----------
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      gradient: LinearGradient(colors: [
                        DC.amber.withOpacity(0.25),
                        DC.magenta.withOpacity(0.14),
                      ]),
                      border: Border.all(color: DC.amber.withOpacity(0.5)),
                    ),
                    child: Row(children: [
                      const MyndArt(theme: 'mania', size: 76),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(maniaStageLabel(st),
                                  style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 17,
                                      color: DC.amber)),
                              const SizedBox(height: 2),
                              Text(
                                  st == ManiaStage.results
                                      ? 'next war starts in ${fmtLeftLong(left)}'
                                      : '${st == ManiaStage.registration ? 'base league' : 'next stage'} in ${fmtLeftLong(left)}',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Text(
                                  '${squadsIn.length} squads in · 🥇 ${pot ~/ 2} · 🥈 ${pot ~/ 4} · 🥉+4th ${pot ~/ 8} each',
                                  style:
                                      TextStyle(fontSize: 11, color: DC.dim)),
                            ]),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  // ---------- the road ----------
                  Glass(
                    radius: 20,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (final (s, label) in const [
                          (ManiaStage.registration, 'ENTRY'),
                          (ManiaStage.base, 'LEAGUE'),
                          (ManiaStage.r16, 'TOP 16'),
                          (ManiaStage.qf, 'TOP 8'),
                          (ManiaStage.sf, 'SEMIS'),
                          (ManiaStage.finals, 'FINAL'),
                        ])
                          Column(children: [
                            Icon(
                                st.index > s.index
                                    ? Icons.check_circle
                                    : st == s
                                        ? Icons.radio_button_checked
                                        : Icons.circle_outlined,
                                size: 16,
                                color: st.index > s.index
                                    ? DC.lime
                                    : st == s
                                        ? DC.amber
                                        : DC.dim),
                            const SizedBox(height: 3),
                            Text(label,
                                style: TextStyle(
                                    fontSize: 8,
                                    letterSpacing: 0.5,
                                    fontWeight: st == s
                                        ? FontWeight.w900
                                        : FontWeight.w500,
                                    color: st == s ? DC.amber : DC.dim)),
                          ]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  // ---------- my squad's status / actions ----------
                  if (loading)
                    Center(
                        child: Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator(color: DC.amber)))
                  else if (!inSquad)
                    Glass(
                      child: Text(
                          'You need a squad to enter Squad Mania.\nCreate or join one from the Squads page — max 10 minds per squad.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: DC.dim, height: 1.5)),
                    )
                  else ...[
                    if (st == ManiaStage.registration) ...[
                      if (registered)
                        Glass(
                          tint: DC.lime,
                          child: Row(children: [
                            Icon(Icons.verified, color: DC.lime),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                  '${AppData.i.squadName} is registered! War begins on the 4th.',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13)),
                            ),
                          ]),
                        )
                      else
                        NeonButton(
                          label: busy
                              ? '…'
                              : 'REGISTER ${AppData.i.squadName.toUpperCase()} · 10 🪙',
                          icon: Icons.how_to_reg,
                          colors: [DC.amber, DC.magenta],
                          onPressed: busy ? null : _register,
                        ),
                    ] else if (st == ManiaStage.results) ...[
                      Text('FINAL STANDINGS',
                          style: TextStyle(
                              fontSize: 10, letterSpacing: 2, color: DC.dim)),
                      const SizedBox(height: 8),
                      for (final (sid, place, prize) in _finalRanking())
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Glass(
                            tint: sid == AppData.i.squadId ? DC.amber : null,
                            radius: 18,
                            child: Row(children: [
                              Text(['🥇', '🥈', '🥉', '4️⃣'][place - 1],
                                  style: const TextStyle(fontSize: 22)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                    '${(squadsIn[sid] as Map?)?['name'] ?? 'squad'}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800)),
                              ),
                              Text('+$prize 🪙',
                                  style: TextStyle(
                                      color: DC.amber,
                                      fontWeight: FontWeight.w900)),
                            ]),
                          ),
                        ),
                      if (_finalRanking()
                              .any((e) => e.$1 == AppData.i.squadId) &&
                          !claimed) ...[
                        const SizedBox(height: 6),
                        NeonButton(
                            label: 'CLAIM MY SHARE 🪙',
                            colors: [DC.amber, DC.lime],
                            onPressed: busy
                                ? null
                                : () => _claim(_finalRanking()
                                    .firstWhere(
                                        (e) => e.$1 == AppData.i.squadId)
                                    .$3)),
                      ],
                    ] else ...[
                      // an actual playing round
                      if (!registered)
                        Glass(
                            child: Text(
                                'Your squad didn\'t register this month.\nRegistration reopens on the 1st.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: DC.dim)))
                      else if (!_eligible(round))
                        Glass(
                            child: Text(
                                'The run ended at ${maniaStageLabel(st)} — top ${maniaCut(round)} moved on.\nRegroup, grind, and come back on the 1st. 💪',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: DC.dim, height: 1.5)))
                      else if (_playedThisRound)
                        Glass(
                          tint: DC.lime,
                          child: Column(children: [
                            const Text('✓ Your score is banked for this round',
                                style: TextStyle(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            Text(
                                'Rally the squad — every member\'s run adds to the team total before ${fmtLeftLong(left)} runs out.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, color: DC.dim)),
                          ]),
                        )
                      else
                        NeonButton(
                          label: 'PLAY ${maniaStageLabel(st)} · 3 MIN',
                          icon: Icons.bolt,
                          colors: [DC.amber, DC.magenta],
                          onPressed: busy ? null : _play,
                        ),
                    ],
                    const SizedBox(height: 16),
                    // ---------- live standings ----------
                    if (totals.isNotEmpty) ...[
                      Text(
                          st == ManiaStage.registration
                              ? 'SQUADS ENTERED'
                              : 'LIVE STANDINGS · ${maniaStageLabel(st)}',
                          style: TextStyle(
                              fontSize: 10, letterSpacing: 2, color: DC.dim)),
                      const SizedBox(height: 8),
                      for (var i = 0; i < totals.length && i < 16; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Glass(
                            radius: 16,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 9),
                            tint: totals[i].key == AppData.i.squadId
                                ? DC.amber
                                : null,
                            child: Row(children: [
                              Text('#${i + 1}',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: DC.dim,
                                      fontSize: 12)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                    '${(squadsIn[totals[i].key] as Map?)?['name'] ?? 'squad'}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13)),
                              ),
                              Text('${totals[i].value}',
                                  style: TextStyle(
                                      color: DC.amber,
                                      fontWeight: FontWeight.w900)),
                            ]),
                          ),
                        ),
                    ],
                  ],
                  const SizedBox(height: 14),
                  Glass(
                    radius: 20,
                    child: Text(
                        '⚡ Challenges are 10–15s each: memory flashes, ink-vs-word '
                        'stroop traps, rotation puzzles and speed chains. The clock '
                        'is too tight to ask an AI — only trained brains survive.',
                        style: TextStyle(
                            fontSize: 11, color: DC.dim, height: 1.5)),
                  ),
                  const SizedBox(height: 40),
                ]),
          ),
        ),
      ),
    );
  }
}

/// ============================================================
/// PLAY SCREEN — 12 rapid anti-AI challenges, seeded per
/// (month, round) so every player faces the identical set.
/// ============================================================
class ManiaPlayScreen extends StatefulWidget {
  final String month;
  final String round;
  const ManiaPlayScreen({super.key, required this.month, required this.round});

  @override
  State<ManiaPlayScreen> createState() => _ManiaPlayScreenState();
}

class _ManiaPlayScreenState extends State<ManiaPlayScreen> {
  static const totalItems = 12;
  late final Random rng =
      Random('${widget.month}|${widget.round}'.hashCode ^ 0x5A9AD);
  int index = 0;
  int score = 0;
  Widget? current;

  @override
  void initState() {
    super.initState();
    _next();
  }

  void _next() {
    if (index >= totalItems) {
      Navigator.pop(context, score);
      return;
    }
    final kind = index % 4; // rotate through the 4 challenge types
    final key = ValueKey('m$index');
    void onDone(int pts) {
      score += pts;
      index++;
      if (mounted) _next();
    }

    setState(() {
      current = switch (kind) {
        0 => _FlashGridRound(key: key, rng: rng, onDone: onDone),
        1 => _StroopRound(key: key, rng: rng, onDone: onDone),
        2 => _SpeedChainRound(key: key, rng: rng, onDone: onDone),
        _ => _RotationRound(key: key, rng: rng, onDone: onDone),
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ShaderBackground(
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Glass(
                    radius: 16,
                    padding: const EdgeInsets.all(8),
                    onTap: () => Navigator.pop(context, score),
                    child: const Icon(Icons.flag, size: 18)),
                const Spacer(),
                Text(
                    '${index + 1 > totalItems ? totalItems : index + 1}/$totalItems',
                    style: TextStyle(color: DC.dim)),
                const Spacer(),
                Pill(icon: Icons.star, label: '$score', color: DC.amber),
              ]),
            ),
            Expanded(child: Center(child: current)),
          ]),
        ),
      ),
    );
  }
}

/// Shared countdown chrome for a round.
class _RoundShell extends StatelessWidget {
  final String title;
  final int seconds;
  final int elapsedMs;
  final Widget child;
  const _RoundShell(
      {required this.title,
      required this.seconds,
      required this.elapsedMs,
      required this.child});

  @override
  Widget build(BuildContext context) {
    final frac = (1 - elapsedMs / (seconds * 1000)).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(title,
            style: TextStyle(fontSize: 11, letterSpacing: 2, color: DC.dim)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            width: 180,
            child: LinearProgressIndicator(
              value: frac.toDouble(),
              minHeight: 7,
              backgroundColor: DC.fg10,
              valueColor:
                  AlwaysStoppedAnimation(frac > 0.33 ? DC.amber : DC.danger),
            ),
          ),
        ),
        const SizedBox(height: 18),
        child,
      ]),
    );
  }
}

/// Base class handling the tick + timeout for every round type.
abstract class _TimedRoundState<T extends StatefulWidget> extends State<T> {
  int get roundSeconds;
  void Function(int) get onDone;
  int elapsedMs = 0;
  Timer? _t;
  bool finished = false;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      setState(() => elapsedMs += 100);
      if (elapsedMs >= roundSeconds * 1000) finish(0);
    });
  }

  void finish(int pts) {
    if (finished) return;
    finished = true;
    _t?.cancel();
    onDone(pts);
  }

  /// speed bonus: up to +5 based on time left
  int bonus() => ((roundSeconds * 1000 - elapsedMs) / (roundSeconds * 1000) * 5)
      .clamp(0, 5)
      .round();

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }
}

/// ---------- 1) MEMORY FLASH: recall the lit cells ----------
class _FlashGridRound extends StatefulWidget {
  final Random rng;
  final void Function(int) onDone;
  const _FlashGridRound({super.key, required this.rng, required this.onDone});

  @override
  State<_FlashGridRound> createState() => _FlashGridRoundState();
}

class _FlashGridRoundState extends _TimedRoundState<_FlashGridRound> {
  @override
  int get roundSeconds => 12;
  @override
  void Function(int) get onDone => widget.onDone;

  late final Set<int> lit = () {
    final s = <int>{};
    while (s.length < 5) {
      s.add(widget.rng.nextInt(16));
    }
    return s;
  }();
  final picked = <int>{};
  bool showing = true;

  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => showing = false);
    });
  }

  void _tap(int i) {
    if (showing || finished) return;
    setState(() => picked.add(i));
    if (picked.length >= 5) {
      final correct = picked.where(lit.contains).length;
      finish(correct * 3 + (correct == 5 ? bonus() : 0));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _RoundShell(
      title: showing ? 'MEMORIZE THE PATTERN' : 'TAP THE 5 LIT CELLS',
      seconds: roundSeconds,
      elapsedMs: elapsedMs,
      child: SizedBox(
        width: 240,
        height: 240,
        child: GridView.count(
          crossAxisCount: 4,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (var i = 0; i < 16; i++)
              GestureDetector(
                onTap: () => _tap(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: (showing && lit.contains(i))
                        ? DC.amber
                        : picked.contains(i)
                            ? (lit.contains(i)
                                ? DC.lime
                                : DC.danger.withOpacity(0.7))
                            : DC.fgo(0.08),
                    border: Border.all(color: DC.fgo(0.15)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// ---------- 2) STROOP: tap the INK colour, not the word ----------
class _StroopRound extends StatefulWidget {
  final Random rng;
  final void Function(int) onDone;
  const _StroopRound({super.key, required this.rng, required this.onDone});

  @override
  State<_StroopRound> createState() => _StroopRoundState();
}

class _StroopRoundState extends _TimedRoundState<_StroopRound> {
  @override
  int get roundSeconds => 7;
  @override
  void Function(int) get onDone => widget.onDone;

  static const names = ['RED', 'BLUE', 'GREEN', 'YELLOW'];
  static const colors = [
    Color(0xFFFF5252),
    Color(0xFF448AFF),
    Color(0xFF69F0AE),
    Color(0xFFFFD740)
  ];
  late final int word = widget.rng.nextInt(4);
  late final int ink = () {
    var i = widget.rng.nextInt(4);
    while (i == word) {
      i = widget.rng.nextInt(4);
    }
    return i;
  }();

  @override
  Widget build(BuildContext context) {
    return _RoundShell(
      title: 'TAP THE INK COLOUR — IGNORE THE WORD',
      seconds: roundSeconds,
      elapsedMs: elapsedMs,
      child: Column(children: [
        Text(names[word],
            style: TextStyle(
                fontSize: 52, fontWeight: FontWeight.w900, color: colors[ink])),
        const SizedBox(height: 24),
        Wrap(spacing: 12, runSpacing: 12, children: [
          for (var i = 0; i < 4; i++)
            GestureDetector(
              onTap: () => finish(i == ink ? 10 + bonus() : 0),
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors[i],
                  boxShadow: [
                    BoxShadow(color: colors[i].withOpacity(0.5), blurRadius: 12)
                  ],
                ),
              ),
            ),
        ]),
      ]),
    );
  }
}

/// ---------- 3) SPEED CHAIN: a×b±c, typed, 10s ----------
class _SpeedChainRound extends StatefulWidget {
  final Random rng;
  final void Function(int) onDone;
  const _SpeedChainRound({super.key, required this.rng, required this.onDone});

  @override
  State<_SpeedChainRound> createState() => _SpeedChainRoundState();
}

class _SpeedChainRoundState extends _TimedRoundState<_SpeedChainRound> {
  @override
  int get roundSeconds => 12;
  @override
  void Function(int) get onDone => widget.onDone;

  late final Question q =
      generate('speedmath', 1400 + widget.rng.nextInt(600), widget.rng);
  final c = TextEditingController();

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _RoundShell(
      title: 'SPEED CHAIN — TYPE IT',
      seconds: roundSeconds,
      elapsedMs: elapsedMs,
      child: Column(children: [
        Text(q.prompt,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
        const SizedBox(height: 16),
        SizedBox(
          width: 160,
          child: TextField(
            controller: c,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(
                decimal: true, signed: true),
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 26, fontWeight: FontWeight.w900, color: DC.cyan),
            decoration: const InputDecoration(hintText: '?'),
            onSubmitted: (v) => finish(q.check(v) ? 10 + bonus() : 0),
          ),
        ),
        const SizedBox(height: 10),
        NeonButton(
            label: 'GO',
            height: 44,
            colors: [DC.amber, DC.magenta],
            onPressed: () => finish(q.check(c.text) ? 10 + bonus() : 0)),
      ]),
    );
  }
}

/// ---------- 4) ROTATION: arrows after a 90° CW turn ----------
class _RotationRound extends StatefulWidget {
  final Random rng;
  final void Function(int) onDone;
  const _RotationRound({super.key, required this.rng, required this.onDone});

  @override
  State<_RotationRound> createState() => _RotationRoundState();
}

class _RotationRoundState extends _TimedRoundState<_RotationRound> {
  @override
  int get roundSeconds => 10;
  @override
  void Function(int) get onDone => widget.onDone;

  static const dirs = ['↑', '→', '↓', '←'];
  late final List<int> arrows = List.generate(4, (_) => widget.rng.nextInt(4));
  late final int target = widget.rng.nextInt(4);
  int get answer => (arrows[target] + 1) % 4; // 90° clockwise

  @override
  Widget build(BuildContext context) {
    return _RoundShell(
      title:
          'ROTATE THE WHOLE ROW 90° CLOCKWISE.\nWHERE DOES ARROW #${target + 1} POINT?',
      seconds: roundSeconds,
      elapsedMs: elapsedMs,
      child: Column(children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < 4; i++)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: i == target ? DC.amber.withOpacity(0.25) : DC.fgo(0.06),
                border: Border.all(color: i == target ? DC.amber : DC.fg12),
              ),
              child: Text(dirs[arrows[i]],
                  style: const TextStyle(
                      fontSize: 30, fontWeight: FontWeight.w900)),
            ),
        ]),
        const SizedBox(height: 22),
        Wrap(spacing: 10, children: [
          for (var i = 0; i < 4; i++)
            GestureDetector(
              onTap: () => finish(i == answer ? 10 + bonus() : 0),
              child: Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: DC.fgo(0.08),
                  border: Border.all(color: DC.fg24),
                ),
                child: Center(
                    child: Text(dirs[i],
                        style: const TextStyle(
                            fontSize: 24, fontWeight: FontWeight.w900))),
              ),
            ),
        ]),
      ]),
    );
  }
}

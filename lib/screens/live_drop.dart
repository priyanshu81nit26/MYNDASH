import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../core/state.dart';
import '../engine/banks.dart';
import '../engine/event_calendar.dart';
import '../engine/generators.dart';
import '../engine/question.dart';
import '../services/account_service.dart';
import '../theme_district.dart';
import '../ui/extras.dart';
import '../ui/glass.dart';
import 'event_leaderboard.dart';

/// ============================================================
/// LIVE DROP — twice a day (1 PM & 9 PM local) a 10-minute window
/// opens. Everyone worldwide gets the SAME 15 seeded questions.
/// Score → global drop board. Miss the window, wait for the next.
/// ============================================================

const _dropHours = [13, 21];
const _windowMin = 10;
const _dropCats = [
  'mental',
  'patterns',
  'quant',
  'clock',
  'probability',
  'numtheory',
  'geometry',
  'words',
];

/// The drop window that is open right now, or null.
String? currentDropKey() {
  final n = DateTime.now();
  for (final h in _dropHours) {
    final start = DateTime(n.year, n.month, n.day, h);
    if (n.isAfter(start) &&
        n.isBefore(start.add(const Duration(minutes: _windowMin)))) {
      return '${AppData.todayKey()}-$h';
    }
  }
  return null;
}

/// The next window start after now.
DateTime nextDropTime() {
  final n = DateTime.now();
  for (final h in _dropHours) {
    final start = DateTime(n.year, n.month, n.day, h);
    if (n.isBefore(start)) return start;
  }
  return DateTime(n.year, n.month, n.day + 1, _dropHours.first);
}

class LiveDropScreen extends StatefulWidget {
  const LiveDropScreen({super.key});

  @override
  State<LiveDropScreen> createState() => _LiveDropScreenState();
}

class _LiveDropScreenState extends State<LiveDropScreen> {
  Timer? ticker;

  @override
  void initState() {
    super.initState();
    ticker = Timer.periodic(
        const Duration(seconds: 1), (_) => mounted ? setState(() {}) : null);
  }

  @override
  void dispose() {
    ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final key = currentDropKey();
    final played = key != null && AppData.i.lastDropKey == key;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ShaderBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: ListView(children: [
              Row(children: [
                Glass(
                    radius: 16,
                    padding: const EdgeInsets.all(8),
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back, size: 18)),
                const SizedBox(width: 12),
                Text('LIVE DROP ⚡',
                    style: Theme.of(context).textTheme.titleLarge),
              ]),
              const SizedBox(height: 56),
              if (key != null && !played) ...[
                Text('🔴 LIVE NOW',
                    style: TextStyle(
                        color: DC.danger,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2)),
                const SizedBox(height: 8),
                Text(
                    'The whole world is on these exact\n15 questions right now.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: DC.dim)),
                const SizedBox(height: 20),
                NeonButton(
                  label: 'DROP IN',
                  icon: Icons.bolt,
                  colors: [DC.danger, DC.magenta],
                  onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => _DropPlayScreen(dropKey: key)))
                      .then((_) => setState(() {})),
                ),
              ] else if (played) ...[
                const Text('✅ You dropped in this window',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 14),
                NeonButton(
                  label: 'VIEW DROP BOARD',
                  icon: Icons.leaderboard,
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              _DropBoardScreen(dropKey: key, myScore: null))),
                ),
              ] else ...[
                Text('NEXT DROP IN',
                    style: TextStyle(
                        fontSize: 11, letterSpacing: 3, color: DC.dim)),
                const SizedBox(height: 10),
                Text(_countdown(),
                    style: Theme.of(context)
                        .textTheme
                        .displayLarge
                        ?.copyWith(fontSize: 44, letterSpacing: 2)),
                const SizedBox(height: 10),
                Text(
                    'Every day at ${_dropHours.map((h) => '$h:00').join(' & ')} — a 10-minute window.\nSame 15 questions for everyone. Top scores flex on the board.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: DC.dim)),
              ],
              const SizedBox(height: 28),
              Glass(
                radius: 22,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'RECENT DROP BOARDS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Completed windows stay available.',
                      style: TextStyle(color: DC.dim, fontSize: 10),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final dropKey in _completedDropKeys())
                          _DropHistoryButton(
                            dropKey: dropKey,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EventLeaderboardScreen(
                                  title: 'LIVE DROP',
                                  subtitle: '$dropKey · final standings',
                                  loadScores: () => AccountService.instance
                                      .fetchDropScores(dropKey),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 60),
            ]),
          ),
        ),
      ),
    );
  }

  String _countdown() {
    final d = nextDropTime().difference(DateTime.now());
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  List<String> _completedDropKeys() {
    final now = DateTime.now();
    final keys = <String>[];
    for (var daysAgo = 0; daysAgo < 5 && keys.length < 6; daysAgo++) {
      final day = DateTime(now.year, now.month, now.day - daysAgo);
      for (final hour in _dropHours.reversed) {
        final end = DateTime(day.year, day.month, day.day, hour).add(
          const Duration(minutes: _windowMin),
        );
        if (!now.isBefore(end)) {
          keys.add('${eventDateKey(day)}-$hour');
        }
        if (keys.length == 6) break;
      }
    }
    return keys;
  }
}

class _DropHistoryButton extends StatelessWidget {
  final String dropKey;
  final VoidCallback onTap;

  const _DropHistoryButton({
    required this.dropKey,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final parts = dropKey.split('-');
    final hour = parts.isEmpty ? '' : parts.last;
    final date = parts.length >= 3 ? '${parts[2]}/${parts[1]}' : dropKey;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.leaderboard_outlined, size: 16),
      label: Text('$date · $hour:00'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(112, 44),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

/// ---------------- the 15-question blitz ----------------
class _DropPlayScreen extends StatefulWidget {
  final String dropKey;
  const _DropPlayScreen({required this.dropKey});

  @override
  State<_DropPlayScreen> createState() => _DropPlayScreenState();
}

class _DropPlayScreenState extends State<_DropPlayScreen> {
  static const total = 15;
  late final List<Question> qs;
  int index = 0;
  int score = 0;
  int qStart = 0;
  bool answered = false;
  bool right = false;
  bool finished = false;

  @override
  void initState() {
    super.initState();
    // deterministic: same questions for every player in this window
    // Global bank: same 8 questions for everyone in this drop window.
    qs = List.generate(total, (i) => bankDrop(bankDayIndex(), i));
    // legacy generator path kept for reference:
    // ignore: dead_code
    if (false) {
      final rng = Random(widget.dropKey.hashCode);
      qs = List.generate(total, (i) {
        final rating = (900 + i * 100).clamp(800, 2400).toInt();
        return generate(_dropCats[i % _dropCats.length], rating, rng);
      });
    }
    qStart = DateTime.now().millisecondsSinceEpoch;
  }

  void _answer(String input) {
    if (answered || finished) return;
    final q = qs[index];
    final ms = DateTime.now().millisecondsSinceEpoch - qStart;
    answered = true;
    right = q.check(input);
    if (right) {
      score += 10 + ((q.parMs - ms) > 0 ? 5 : 0); // pace bonus inside par
    }
    setState(() {});
    Timer(const Duration(milliseconds: 650), () {
      if (!mounted) return;
      if (index + 1 >= total) {
        _finish();
      } else {
        setState(() {
          index++;
          answered = false;
          qStart = DateTime.now().millisecondsSinceEpoch;
        });
      }
    });
  }

  void _finish() {
    if (finished) return;
    finished = true;
    final a = AppData.i;
    a.lastDropKey = widget.dropKey;
    a.earnCoins((score ~/ 4).clamp(0, 25)); // solo → capped faucet
    a.addXp(score); // XP stays full
    a.recordMatch(
        mode: 'Live Drop ⚡',
        opponent: 'THE WORLD',
        result: score >= 100 ? 'W' : 'D');
    AccountService.instance.submitDropScore(widget.dropKey, score);
    AccountService.instance.updatePublicProfile();
    Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) =>
                _DropBoardScreen(dropKey: widget.dropKey, myScore: score)));
  }

  @override
  Widget build(BuildContext context) {
    final q = qs[index];
    return Scaffold(
      body: ShaderBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              Row(children: [
                Text('Q${index + 1}/$total',
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 16)),
                const Spacer(),
                Pill(icon: Icons.bolt, label: '$score', color: DC.danger),
              ]),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: (index + 1) / total,
                backgroundColor: DC.fg10,
                color: DC.danger,
                minHeight: 4,
              ),
              const Spacer(),
              Glass(
                radius: 24,
                padding: const EdgeInsets.all(22),
                border: answered
                    ? Border.all(color: right ? DC.lime : DC.danger, width: 2)
                    : null,
                child: Text(q.prompt,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 16),
              if (q.options != null)
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final o in q.options!)
                      GestureDetector(
                        onTap: () => _answer(o),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            color: answered && q.check(o)
                                ? DC.lime.withOpacity(0.25)
                                : DC.fgo(0.07),
                            border: Border.all(color: DC.fgo(0.14)),
                          ),
                          child: Text(o,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w700)),
                        ),
                      ),
                  ],
                )
              else
                _TypedAnswer(onSubmit: _answer, enabled: !answered),
              const Spacer(flex: 2),
            ]),
          ),
        ),
      ),
    );
  }
}

class _TypedAnswer extends StatefulWidget {
  final ValueChanged<String> onSubmit;
  final bool enabled;
  const _TypedAnswer({required this.onSubmit, required this.enabled});

  @override
  State<_TypedAnswer> createState() => _TypedAnswerState();
}

class _TypedAnswerState extends State<_TypedAnswer> {
  final c = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: TextField(
          controller: c,
          enabled: widget.enabled,
          autofocus: true,
          onSubmitted: widget.enabled ? (v) => _go() : null,
          decoration: const InputDecoration(hintText: 'your answer'),
        ),
      ),
      const SizedBox(width: 10),
      NeonButton(
          label: 'GO', height: 46, onPressed: widget.enabled ? _go : null),
    ]);
  }

  void _go() {
    if (c.text.trim().isEmpty) return;
    widget.onSubmit(c.text);
    c.clear();
  }
}

/// ---------------- the drop board ----------------
class _DropBoardScreen extends StatefulWidget {
  final String dropKey;
  final int? myScore; // null = just viewing
  const _DropBoardScreen({required this.dropKey, this.myScore});

  @override
  State<_DropBoardScreen> createState() => _DropBoardScreenState();
}

class _DropBoardScreenState extends State<_DropBoardScreen> {
  List<MapEntry<String, int>>? scores;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await AccountService.instance.fetchDropScores(widget.dropKey);
    if (mounted) {
      setState(() {
        scores = r;
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = AppData.i.username;
    return Scaffold(
      body: ShaderBackground(
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(children: [
                Glass(
                    radius: 16,
                    padding: const EdgeInsets.all(8),
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back, size: 18)),
                const SizedBox(width: 12),
                Text('DROP BOARD',
                    style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                Glass(
                    radius: 16,
                    padding: const EdgeInsets.all(8),
                    onTap: _load,
                    child: const Icon(Icons.refresh, size: 18)),
              ]),
            ),
            if (widget.myScore != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Glass(
                  tint: DC.danger,
                  child: Column(children: [
                    const ConfettiBurst(height: 50),
                    Text('YOUR SCORE: ${widget.myScore}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 20)),
                    Text('+${widget.myScore} 🪙 · +${widget.myScore} XP',
                        style: TextStyle(color: DC.amber, fontSize: 12)),
                    TextButton.icon(
                      onPressed: () => shareResult(context,
                          'Scored ${widget.myScore} in today\'s MYNDASH Live Drop ⚡ vs the world. Catch the next one at ${_dropHours.map((h) => '$h:00').join(' / ')}.'),
                      icon: Icon(Icons.ios_share, size: 15, color: DC.cyan),
                      label: Text('Share',
                          style: TextStyle(color: DC.cyan, fontSize: 12)),
                    ),
                  ]),
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: loading
                  ? Center(child: CircularProgressIndicator(color: DC.danger))
                  : scores == null
                      ? Center(
                          child: Text(
                              'Board unavailable offline —\nyour score is saved locally.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: DC.dim)))
                      : scores!.isEmpty
                          ? Center(
                              child: Text('You\'re the first — flex it 😎',
                                  style: TextStyle(color: DC.dim)))
                          : ListView(
                              padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                              children: [
                                for (var i = 0;
                                    i < min(scores!.length, 50);
                                    i++)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Glass(
                                      radius: 16,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 10),
                                      tint:
                                          scores![i].key == me ? DC.cyan : null,
                                      child: Row(children: [
                                        SizedBox(
                                          width: 34,
                                          child: Text(
                                              switch (i) {
                                                0 => '🥇',
                                                1 => '🥈',
                                                2 => '🥉',
                                                _ => '#${i + 1}',
                                              },
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w900)),
                                        ),
                                        Expanded(
                                          child: Text('@${scores![i].key}',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 13)),
                                        ),
                                        Text('${scores![i].value}',
                                            style: TextStyle(
                                                color: DC.danger,
                                                fontWeight: FontWeight.w900)),
                                      ]),
                                    ),
                                  ),
                              ],
                            ),
            ),
          ]),
        ),
      ),
    );
  }
}

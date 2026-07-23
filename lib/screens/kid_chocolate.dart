import 'dart:math';

import 'package:flutter/material.dart';

import '../core/fx.dart';
import '../core/state.dart';
import '../engine/kid_generators.dart';
import '../engine/question.dart';
import '../services/account_service.dart';
import '../theme_district.dart';
import '../ui/glass.dart';

/// ============================================================
/// CHOCOLATE HOUR — a fresh problem unlocks every hour (24 a day).
/// Miss one? It stays unwrapped and waits for you (stackable). Every
/// solve pays coins + XP and climbs a global leaderboard; yesterday's
/// final standings are crowned the next day.
/// ============================================================

const _chocTopics = [
  'addsub',
  'patterns',
  'compare',
  'oddone',
  'missing',
  'skipcount',
  'evenodd',
  'tables',
  'fractions',
  'counting',
  'shapes',
  'money',
];

String _topicForHour(int h) => _chocTopics[h % _chocTopics.length];
int _diffForHour(int h) =>
    (1 + h ~/ 2).clamp(1, 12); // tougher later in the day

/// Same problem for every kid, keyed by day + hour.
Question chocQuestion(String dayKey, int hour) {
  final rng = Random(dayKey.hashCode ^ ((hour + 1) * 7919));
  return generateKid(_topicForHour(hour), _diffForHour(hour), rng);
}

String _yesterdayKey() {
  final y = DateTime.now().subtract(const Duration(days: 1));
  return '${y.year}-${y.month.toString().padLeft(2, '0')}-${y.day.toString().padLeft(2, '0')}';
}

class KidChocolateScreen extends StatefulWidget {
  const KidChocolateScreen({super.key});
  @override
  State<KidChocolateScreen> createState() => _KidChocolateScreenState();
}

class _KidChocolateScreenState extends State<KidChocolateScreen> {
  @override
  Widget build(BuildContext context) {
    final a = AppData.i;
    final nowHour = DateTime.now().hour;
    final solved = a.chocSolvedToday().toSet();
    final collected = solved.length;

    return Scaffold(
      body: ShaderBackground(
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(children: [
                Glass(
                    radius: 16,
                    padding: const EdgeInsets.all(8),
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back, size: 18)),
                const SizedBox(width: 12),
                Text('CHOCOLATE HOUR',
                    style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                Glass(
                  radius: 16,
                  padding: const EdgeInsets.all(8),
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const KidChocLeaderboardScreen())),
                  child: const Icon(Icons.leaderboard_rounded,
                      size: 18, color: Color(0xFFC98A00)),
                ),
              ]),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Glass(
                tint: const Color(0xFF8B5A2B),
                child: Row(children: [
                  const Text('🍫', style: TextStyle(fontSize: 34)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$collected / 24 collected today',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900, fontSize: 16)),
                          Text(
                              'A new chocolate unlocks every hour. Miss one? It waits for you!',
                              style: TextStyle(fontSize: 11, color: DC.dim)),
                        ]),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: collected / 24,
                  minHeight: 7,
                  backgroundColor: DC.fgo(0.06),
                  color: const Color(0xFFC98A00),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12),
                itemCount: 24,
                itemBuilder: (context, h) {
                  final isSolved = solved.contains(h);
                  final unlocked = h <= nowHour;
                  return _ChocSquare(
                    hour: h,
                    solved: isSolved,
                    unlocked: unlocked,
                    onTap: (unlocked && !isSolved) ? () => _solve(h) : null,
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _solve(int hour) async {
    final ok = await Navigator.push<bool>(context,
        MaterialPageRoute(builder: (_) => _ChocSolveScreen(hour: hour)));
    if (ok == true && mounted) {
      final total = AppData.i.recordChoc(hour);
      AccountService.instance.submitChoc(AppData.todayKey(), total);
      setState(() {});
    }
  }
}

class _ChocSquare extends StatelessWidget {
  final int hour;
  final bool solved, unlocked;
  final VoidCallback? onTap;
  const _ChocSquare(
      {required this.hour,
      required this.solved,
      required this.unlocked,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    final Gradient grad = solved
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFD86B), Color(0xFFC98A00)])
        : unlocked
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF7A4A22), Color(0xFF4A2C14)])
            : LinearGradient(colors: [DC.fgo(0.05), DC.fgo(0.02)]);
    return Press3D(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: grad,
          border: Border.all(
              color: solved
                  ? const Color(0xFFFFD86B)
                  : unlocked
                      ? const Color(0xFF3A2110)
                      : DC.fg12,
              width: 1.5),
          boxShadow: unlocked && !solved
              ? [
                  BoxShadow(
                      color: const Color(0xFF8B5A2B).withOpacity(0.5),
                      blurRadius: 10)
                ]
              : null,
        ),
        child: Center(
          child: solved
              ? const Icon(Icons.check_rounded, color: Colors.white, size: 26)
              : unlocked
                  ? const Text('🍫', style: TextStyle(fontSize: 26))
                  : Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.lock_rounded, size: 16, color: DC.fg38),
                      Text('${hour.toString().padLeft(2, '0')}:00',
                          style: TextStyle(fontSize: 9, color: DC.fg38)),
                    ]),
        ),
      ),
    );
  }
}

/// One chocolate problem.
class _ChocSolveScreen extends StatefulWidget {
  final int hour;
  const _ChocSolveScreen({required this.hour});
  @override
  State<_ChocSolveScreen> createState() => _ChocSolveScreenState();
}

class _ChocSolveScreenState extends State<_ChocSolveScreen> {
  late final Question q = chocQuestion(AppData.todayKey(), widget.hour);
  final _input = TextEditingController();
  bool? _correct;

  void _answer(String v) {
    if (_correct == true) return;
    final ok = q.check(v);
    setState(() => _correct = ok);
    if (ok) {
      Fx.win();
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) Navigator.pop(context, true);
      });
    } else {
      Fx.lose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ShaderBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              Row(children: [
                Glass(
                    radius: 16,
                    padding: const EdgeInsets.all(8),
                    onTap: () => Navigator.pop(context, false),
                    child: const Icon(Icons.close, size: 18)),
                const SizedBox(width: 12),
                Text('🍫 ${widget.hour.toString().padLeft(2, '0')}:00',
                    style: Theme.of(context).textTheme.titleLarge),
              ]),
              const Spacer(),
              Glass(
                tint: const Color(0xFF8B5A2B),
                padding: const EdgeInsets.all(22),
                child: Text(q.prompt,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 20),
              if (q.options != null)
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final o in q.options!)
                      SizedBox(
                        width: 150,
                        child: NeonButton(
                            label: o,
                            height: 52,
                            colors: const [
                              Color(0xFF8B5A2B),
                              Color(0xFFC98A00)
                            ],
                            onPressed: () => _answer(o)),
                      ),
                  ],
                )
              else
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      autofocus: true,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.text,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800),
                      decoration: InputDecoration(
                        hintText: 'your answer',
                        filled: true,
                        fillColor: DC.fgo(0.05),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none),
                      ),
                      onSubmitted: _answer,
                    ),
                  ),
                  const SizedBox(width: 10),
                  NeonButton(
                      label: 'GO',
                      height: 52,
                      colors: const [Color(0xFF8B5A2B), Color(0xFFC98A00)],
                      onPressed: () => _answer(_input.text)),
                ]),
              const SizedBox(height: 16),
              if (_correct != null)
                Text(
                    _correct!
                        ? 'Sweet! Chocolate collected 🍫'
                        : 'Not quite — try again!',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: _correct! ? DC.lime : DC.danger)),
              const Spacer(flex: 2),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Global Chocolate Hour leaderboard — yesterday's champions + today's live.
class KidChocLeaderboardScreen extends StatefulWidget {
  const KidChocLeaderboardScreen({super.key});
  @override
  State<KidChocLeaderboardScreen> createState() =>
      _KidChocLeaderboardScreenState();
}

class _KidChocLeaderboardScreenState extends State<KidChocLeaderboardScreen> {
  List<Map<String, dynamic>>? _yesterday;
  List<Map<String, dynamic>>? _today;

  @override
  void initState() {
    super.initState();
    final svc = AccountService.instance;
    svc.chocLeaderboard(_yesterdayKey()).then((r) {
      if (mounted) setState(() => _yesterday = r);
    });
    svc.chocLeaderboard(AppData.todayKey()).then((r) {
      if (mounted) setState(() => _today = r);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ShaderBackground(
        child: SafeArea(
          child: ListView(padding: const EdgeInsets.all(16), children: [
            Row(children: [
              Glass(
                  radius: 16,
                  padding: const EdgeInsets.all(8),
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back, size: 18)),
              const SizedBox(width: 12),
              Text('CHOCOLATE BOARD',
                  style: Theme.of(context).textTheme.titleLarge),
            ]),
            const SizedBox(height: 16),
            _section("YESTERDAY'S CHAMPIONS 🏆", _yesterday, crown: true),
            const SizedBox(height: 18),
            _section('TODAY · LIVE', _today, crown: false),
          ]),
        ),
      ),
    );
  }

  Widget _section(String title, List<Map<String, dynamic>>? rows,
      {required bool crown}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title,
          style: TextStyle(fontSize: 10, letterSpacing: 2, color: DC.dim)),
      const SizedBox(height: 8),
      if (rows == null)
        const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (rows.isEmpty)
        Glass(
          child: Text('No entries yet — be the first!',
              style: TextStyle(fontSize: 12, color: DC.dim)),
        )
      else
        for (var i = 0; i < rows.length && i < 20; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Glass(
              tint: crown && i == 0 ? const Color(0xFFC98A00) : null,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(children: [
                SizedBox(
                  width: 28,
                  child: Text(
                      crown && i < 3 ? ['🥇', '🥈', '🥉'][i] : '${i + 1}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 14)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${rows[i]['name'] ?? rows[i]['user']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                Text('${rows[i]['count'] ?? 0} 🍫',
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFC98A00))),
              ]),
            ),
          ),
    ]);
  }
}

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../core/state.dart';
import '../daily_challenge/daily_bank.dart';
import '../daily_challenge/daily_game_screen.dart';
import '../engine/banks.dart';
import '../engine/generators.dart';
import '../engine/question.dart';
import '../puzzles/boards.dart';
import '../theme_district.dart';
import '../ui/extras.dart';
import '../ui/glass.dart';

/// ---------------- per-category tutorials ----------------

const Map<String, String> _catTutorials = {
  'mental':
      'Pure speed arithmetic. Work left→right, round then correct (98×7 = 700−14), and split numbers (47+38 = 47+40−2). Type with the keypad and SUBMIT — the field clears itself each question. Beat the par time for star pace.',
  'quant':
      'Percentages, ratios, profit & loss, speed-distance-time. Translate words into one equation before touching numbers. Remember: x% of y = y% of x, and average speed = total distance ÷ total time (never the average of speeds).',
  'numtheory':
      'Divisibility, primes, HCF/LCM, remainders, last digits. Digit-sum test for 9, alternating sum for 11. HCF×LCM = product of the two numbers. Last digits cycle with period 4 (e.g. 7¹,7²,7³,7⁴ → 7,9,3,1).',
  'patterns':
      'Find the rule, predict the next term. Check in order: constant difference → constant ratio → differences of differences → alternating/interleaved sequences → squares, cubes, primes, Fibonacci. The rule must fit EVERY given term.',
  'geometry':
      'Angles, areas, triangles, circles. Draw it mentally: angles on a line = 180°, in a triangle = 180°, around a point = 360°. Area formulas: △ = ½bh, circle = πr², and Pythagoras a²+b²=c² for right triangles.',
  'probability':
      'P = favourable ÷ total. Count carefully — dice pairs are 36, cards are 52 (13 per suit). "At least one" is usually easier as 1 − P(none). Independent events multiply; mutually exclusive events add.',
  'clock':
      'Clock angles: hour hand moves 0.5°/min, minute hand 6°/min → angle = |30H − 5.5M|. Calendar: odd days shift +1 per normal year, +2 after a leap year; century years need ÷400 for leap.',
  'words':
      'Word problems hide simple equations. Name the unknown (let age = x), convert each sentence to math, then solve. Check the answer against the story — units and sanity first, algebra second.',
  'knights':
      'Knights always tell the truth, knaves always lie. Test each speaker: assume knight → does everything stay consistent? A statement like "we are both knaves" can only come from a knave. Contradiction = wrong assumption.',
  'crypta':
      'Letters are digits (same letter = same digit, no leading zeros). Start from the leftmost carry — a carried column often forces M=1 style deductions. Work column by column tracking carries.',
};

/// Shows the "how to solve" sheet for a category (boards get a generic
/// control guide since each board explains its own rules on-screen).
void showCatTutorial(BuildContext context, Cat cat) {
  final body = _catTutorials[cat.id] ??
      'Interactive board: the goal and controls are shown on the board itself. Fill every cell / clear every target, use the live validation colors, and finish before par for ★★★. 3 free hints per level, then 25 🪙.';
  showDialog(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: DC.bg2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(children: [
        Icon(cat.icon, color: cat.color, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text('How to solve · ${cat.name}')),
      ]),
      content: SingleChildScrollView(
        child: Text(body,
            style: TextStyle(fontSize: 13.5, height: 1.55, color: DC.text)),
      ),
      actions: [
        FilledButton(
            onPressed: () => Navigator.pop(c), child: const Text('Got it')),
      ],
    ),
  );
}

/// ============================ SOLVE TAB ============================
class SolveTab extends StatelessWidget {
  const SolveTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        children: [
          Text('SOLVE', style: Theme.of(context).textTheme.displayMedium),
          Text('25 disciplines · levels 800 → 2500',
              style: TextStyle(color: DC.dim, fontSize: 13)),
          const SizedBox(height: 16),
          // Own listener: this whole tab is a `const` subtree under a
          // StatelessWidget that Flutter skips rebuilding once mounted
          // (identical const instances never get build() called again), so
          // unlocked-level badges would otherwise freeze at launch-time
          // values. AnimatedBuilder subscribes independently of that.
          AnimatedBuilder(
            animation: AppData.i,
            builder: (context, _) => GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.55,
              children: [for (final c in cats) _catCard(context, c)],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _catCard(BuildContext context, Cat c) {
    final a = AppData.i;
    final unlocked = a.unlockedLevel(c.id);
    return Glass(
      onTap: c.ready
          ? () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => LevelMapScreen(cat: c)))
          : null,
      radius: 22,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(c.icon, color: c.ready ? c.color : DC.dim, size: 22),
            const Spacer(),
            if (!c.ready)
              Text('SOON',
                  style:
                      TextStyle(fontSize: 9, letterSpacing: 2, color: DC.dim))
            else
              Text('★${a.totalStars(c.id)}',
                  style: TextStyle(fontSize: 11, color: DC.amber)),
          ]),
          const Spacer(),
          Text(c.name,
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: c.ready ? DC.text : DC.dim)),
          if (c.ready)
            Text('$unlocked rating · ${DC.bandName(unlocked)}',
                style: TextStyle(fontSize: 11, color: DC.band(unlocked))),
        ],
      ),
    );
  }
}

/// ============================ LEVEL MAP ============================
class LevelMapScreen extends StatefulWidget {
  final Cat cat;
  const LevelMapScreen({super.key, required this.cat});

  @override
  State<LevelMapScreen> createState() => _LevelMapScreenState();
}

class _LevelMapScreenState extends State<LevelMapScreen> {
  Cat get cat => widget.cat;

  @override
  void initState() {
    super.initState();
    // First visit → walk the player through the tutorial level.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!AppData.i.seenGuide('tut_${cat.id}')) {
        Navigator.push(context,
                MaterialPageRoute(builder: (_) => TutorialScreen(cat: cat)))
            .then((_) {
          if (mounted) setState(() {});
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final a = AppData.i;
    final unlocked = a.unlockedLevel(cat.id);
    return Scaffold(
      body: ShaderBackground(
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Glass(
                    radius: 16,
                    padding: const EdgeInsets.all(8),
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back, size: 18)),
                const SizedBox(width: 12),
                Icon(cat.icon, color: cat.color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(cat.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                Glass(
                    radius: 16,
                    padding: const EdgeInsets.all(8),
                    onTap: () => showCatTutorial(context, cat),
                    child: Icon(Icons.help_outline, size: 18, color: DC.amber)),
              ]),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: levels.length + 1,
                itemBuilder: (context, i) {
                  if (i == 0) return _tutorialCard(context);
                  final lv = levels[i - 1];
                  final stars = a.starsAt(cat.id, lv);
                  final open = lv <= unlocked;
                  final dailyRecords = a.dailyArchive
                      .where((record) =>
                          record['category'] == cat.id &&
                          record['rating'] == lv)
                      .toList()
                    ..sort((left, right) =>
                        ((right['completedAt'] as num?)?.toInt() ?? 0)
                            .compareTo(
                                (left['completedAt'] as num?)?.toInt() ?? 0));
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Glass(
                      onTap: open
                          ? () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => cat.board
                                      ? BoardSessionScreen(cat: cat, level: lv)
                                      : FeedSessionScreen(cat: cat, level: lv),
                                ),
                              );
                              if (mounted) setState(() {});
                            }
                          : null,
                      radius: 20,
                      tint: open ? null : Colors.black,
                      child: Row(children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: open
                                ? LinearGradient(colors: [
                                    DC.band(lv).withOpacity(0.8),
                                    DC.band(lv).withOpacity(0.4)
                                  ])
                                : null,
                            color: open ? null : DC.fg10,
                          ),
                          child: Center(
                            child: open
                                ? Text('$lv',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900))
                                : Icon(Icons.lock, size: 16, color: DC.dim),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Rating $lv · ${DC.bandName(lv)}',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: open ? DC.text : DC.dim)),
                              Text(
                                  cat.board
                                      ? '$boardsPerLevel boards'
                                      : '30 questions',
                                  style:
                                      TextStyle(fontSize: 11, color: DC.dim)),
                              if (dailyRecords.isNotEmpty)
                                Text(
                                  '+${dailyRecords.length} completed Daily ${dailyRecords.length == 1 ? 'board' : 'boards'}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: DC.lime,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Row(children: [
                          for (var s = 0; s < 3; s++)
                            Icon(Icons.star_rounded,
                                size: 18,
                                color: s < stars ? DC.amber : DC.fg12),
                          if (dailyRecords.isNotEmpty)
                            IconButton(
                              tooltip: 'Replay completed Daily boards',
                              visualDensity: VisualDensity.compact,
                              onPressed: () =>
                                  _showDailyBoards(context, dailyRecords),
                              icon: Icon(Icons.today_rounded,
                                  size: 18, color: DC.lime),
                            ),
                        ]),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _showDailyBoards(
    BuildContext context,
    List<Map<String, dynamic>> records,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: DC.bg2,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            'COMPLETED DAILY BOARDS',
            style: Theme.of(sheetContext).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Appended to this rating · reward-free replay',
            style: TextStyle(fontSize: 11, color: DC.dim),
          ),
          const SizedBox(height: 10),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: records.length,
              itemBuilder: (_, index) {
                final record = records[index];
                final item = dailyChallengeItemForArchive(record);
                final day = ((record['day'] as num?)?.toInt() ?? 0) + 1;
                return ListTile(
                  leading: Icon(Icons.replay_circle_filled_rounded,
                      color: cat.color),
                  title: Text(item.title,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('Daily day $day · ${item.rating}'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            DailyGameScreen(item: item, replay: true),
                      ),
                    ).then((_) {
                      if (mounted) setState(() {});
                    });
                  },
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  /// Level 0 — guided tutorial: how-to steps + easy warm-up practice.
  Widget _tutorialCard(BuildContext context) {
    final done = AppData.i.seenGuide('tut_${cat.id}');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Glass(
        onTap: () async {
          await Navigator.push(context,
              MaterialPageRoute(builder: (_) => TutorialScreen(cat: cat)));
          if (mounted) setState(() {});
        },
        radius: 20,
        tint: DC.amber,
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [
                DC.amber.withOpacity(0.8),
                DC.amber.withOpacity(0.4)
              ]),
            ),
            child:
                const Center(child: Text('🎓', style: TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('TUTORIAL · UNRATED',
                    style:
                        TextStyle(fontWeight: FontWeight.w700, color: DC.text)),
                Text('learn the tricks · easy warm-up · no pressure',
                    style: TextStyle(fontSize: 11, color: DC.dim)),
              ],
            ),
          ),
          Icon(done ? Icons.replay_rounded : Icons.play_arrow_rounded,
              color: DC.amber),
        ]),
      ),
    );
  }
}

/// ============================ TUTORIAL LEVEL (Level 0) ============================
/// A no-pressure guided intro for every discipline: the solving tricks
/// as swipeable steps, then 5 easy warm-up questions (or one easy board)
/// with instant explanations. No stars, no coins, no timer stress.
class TutorialScreen extends StatefulWidget {
  final Cat cat;
  const TutorialScreen({super.key, required this.cat});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  bool practising = false;

  // ----- practice state (feed categories) -----
  static const totalQ = 5;
  final Random rng = Random();
  late final int boardSeed = Random().nextInt(1 << 20);
  Question? q;
  int index = 0;
  int correct = 0;
  bool answered = false;
  bool wasRight = false;
  String typedInput = '';

  List<String> get _steps {
    final raw = _catTutorials[widget.cat.id] ??
        'Interactive board: the goal and controls are shown on the board '
            'itself. Fill every cell / clear every target and use the live '
            'validation colors. Finish before par time for ★★★.';
    return raw
        .split(RegExp(r'(?<=[.!?])\s+'))
        .where((s) => s.trim().isNotEmpty)
        .toList();
  }

  void _startPractice() {
    setState(() {
      practising = true;
      if (!widget.cat.board) _nextQ();
    });
  }

  void _nextQ() {
    q = generate(widget.cat.id, 800, rng);
    typedInput = '';
    answered = false;
    setState(() {});
  }

  void _answer(String input) {
    if (answered || q == null) return;
    answered = true;
    wasRight = q!.check(input);
    if (wasRight) correct++;
    setState(() {});
  }

  void _advance() {
    index++;
    if (index >= totalQ) {
      _finish();
    } else {
      _nextQ();
    }
  }

  void _finish() {
    AppData.i.markGuideSeen('tut_${widget.cat.id}');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => Dialog(
        backgroundColor: DC.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('🎓', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 10),
            Text('TUTORIAL COMPLETE',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
                widget.cat.board
                    ? 'You know the board now — Level 800 awaits!'
                    : '$correct / $totalQ warm-ups solved. Level 800 awaits!',
                textAlign: TextAlign.center,
                style: TextStyle(color: DC.dim, fontSize: 13)),
            const SizedBox(height: 18),
            NeonButton(
                label: 'START LEVEL 800',
                height: 46,
                onPressed: () {
                  Navigator.pop(c); // dialog
                  Navigator.pop(context); // tutorial
                }),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ShaderBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: practising ? _practice() : _intro(),
          ),
        ),
      ),
    );
  }

  Widget _intro() {
    final steps = _steps;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Glass(
            radius: 16,
            padding: const EdgeInsets.all(8),
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.close, size: 18)),
        const SizedBox(width: 12),
        Icon(widget.cat.icon, color: widget.cat.color),
        const SizedBox(width: 8),
        Expanded(
          child: Text('Tutorial · ${widget.cat.name}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge),
        ),
      ]),
      const SizedBox(height: 16),
      Expanded(
        child: ListView(children: [
          Glass(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('HOW TO SOLVE',
                  style:
                      TextStyle(fontSize: 11, letterSpacing: 2, color: DC.dim)),
              const SizedBox(height: 12),
              for (var i = 0; i < steps.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient:
                              LinearGradient(colors: [DC.violet, DC.cyan]),
                        ),
                        child: Center(
                          child: Text('${i + 1}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(steps[i],
                            style: TextStyle(
                                fontSize: 13.5, height: 1.5, color: DC.text)),
                      ),
                    ],
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 12),
          Glass(
            tint: DC.lime,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('THE RULES',
                  style:
                      TextStyle(fontSize: 11, letterSpacing: 2, color: DC.dim)),
              const SizedBox(height: 10),
              Text(
                  '• Clear a level with 2★ (80%+ accuracy) to unlock the next\n'
                  '• Beat the par time on answers for star pace\n'
                  '• Stuck? 50:50 hints — 3 free per level, then 25 🪙\n'
                  '• Levels climb 800 → 2500, boss questions at the end',
                  style: TextStyle(fontSize: 13, height: 1.7, color: DC.text)),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      NeonButton(
          label: widget.cat.board
              ? 'TRY AN EASY BOARD'
              : 'WARM-UP · 5 EASY QUESTIONS',
          icon: Icons.play_arrow_rounded,
          onPressed: _startPractice),
      const SizedBox(height: 8),
    ]);
  }

  Widget _practice() {
    if (widget.cat.board) {
      return Column(children: [
        Row(children: [
          Glass(
              radius: 16,
              padding: const EdgeInsets.all(8),
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.close, size: 18)),
          const SizedBox(width: 12),
          Text('Practice board · easy',
              style: const TextStyle(fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 12),
        Expanded(
            child: boardFor(widget.cat.id, 800, boardSeed, (r) {
          _finish();
        })),
      ]);
    }
    final qq = q;
    if (qq == null) return const SizedBox();
    return Column(children: [
      Row(children: [
        Glass(
            radius: 16,
            padding: const EdgeInsets.all(8),
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.close, size: 18)),
        const SizedBox(width: 12),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: index / totalQ,
              minHeight: 8,
              backgroundColor: DC.fg10,
              valueColor: AlwaysStoppedAnimation(DC.amber),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text('${index + 1}/$totalQ',
            style: TextStyle(fontSize: 12, color: DC.dim)),
      ]),
      const SizedBox(height: 8),
      Text('warm-up · no timer, no pressure',
          style: TextStyle(fontSize: 11, color: DC.dim)),
      Expanded(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Glass(
            radius: 24,
            padding: const EdgeInsets.all(22),
            border: answered
                ? Border.all(color: wasRight ? DC.lime : DC.danger, width: 2)
                : null,
            child: Column(children: [
              Text(qq.prompt,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: qq.prompt.length > 60 ? 17 : 24,
                      fontWeight: FontWeight.w700,
                      height: 1.4)),
              if (answered) ...[
                const SizedBox(height: 10),
                Text(wasRight ? 'Correct! 🎯' : 'Answer: ${qq.answer}',
                    style: TextStyle(
                        color: wasRight ? DC.lime : DC.danger,
                        fontWeight: FontWeight.w800)),
                if (qq.note != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(qq.note!,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12.5, color: DC.dim)),
                  ),
              ],
            ]),
          ),
          const SizedBox(height: 20),
          if (answered)
            NeonButton(
                label: index + 1 >= totalQ ? 'FINISH' : 'NEXT',
                height: 48,
                onPressed: _advance)
          else if (qq.typed)
            _tutKeypad()
          else
            Column(children: [
              for (final opt in qq.options!)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GhostButton(label: opt, onPressed: () => _answer(opt)),
                ),
            ]),
        ]),
      ),
    ]);
  }

  Widget _tutKeypad() {
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '.', '0', '⌫'];
    return Column(children: [
      Glass(
        radius: 18,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Text(typedInput.isEmpty ? '…' : typedInput,
            style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.w900, color: DC.cyan)),
      ),
      const SizedBox(height: 12),
      for (var row = 0; row < 4; row++)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var col = 0; col < 3; col++)
              Padding(
                padding: const EdgeInsets.all(4),
                child: Press3D(
                  onTap: () {
                    final k = keys[row * 3 + col];
                    setState(() {
                      if (k == '⌫') {
                        if (typedInput.isNotEmpty) {
                          typedInput =
                              typedInput.substring(0, typedInput.length - 1);
                        }
                      } else {
                        typedInput += k;
                      }
                    });
                  },
                  child: Container(
                    width: 64,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: DC.fgo(0.06),
                      border: Border.all(color: DC.fg12),
                    ),
                    child: Center(
                        child: Text(keys[row * 3 + col],
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w800))),
                  ),
                ),
              ),
          ],
        ),
      const SizedBox(height: 10),
      NeonButton(
          label: 'CHECK',
          height: 48,
          onPressed: typedInput.isEmpty ? null : () => _answer(typedInput)),
    ]);
  }
}

/// ============================ FEED SESSION (30 Q) ============================
class FeedSessionScreen extends StatefulWidget {
  final Cat cat;
  final int level;
  const FeedSessionScreen({super.key, required this.cat, required this.level});

  @override
  State<FeedSessionScreen> createState() => _FeedSessionScreenState();
}

class _FeedSessionScreenState extends State<FeedSessionScreen> {
  static const total = 30;
  late final Random rng = Random(widget.cat.id.hashCode ^ widget.level * 7919);

  /// Real past papers (expired Daily/Drop/Contest/Arena questions) for this
  /// category at this rating band — folded in among the generated set so the
  /// questions you missed reappear at their proper level. A separate seeded
  /// shuffle keeps the generated stream identical to before.
  late final List<Question> _pastPool =
      pastFeedQuestions(widget.cat.id, widget.level)
        ..shuffle(Random(widget.cat.id.hashCode ^ widget.level * 104729));
  late Question q;
  int index = 0;
  int correct = 0;
  int inPar = 0;
  int qStart = 0;
  String typedInput = '';
  bool answered = false;
  bool wasRight = false;
  Set<int> burned = {}; // 50:50 removed options
  bool finished = false;

  @override
  void initState() {
    super.initState();
    AppData.i.freeHints = 3;
    _next();
  }

  int get _effRating {
    var r = widget.level + (index ~/ 10) * 33;
    if (index >= 27) r = widget.level + 100; // boss questions
    return min(r, 2500);
  }

  void _next() {
    if (index >= total) {
      _finish();
      return;
    }
    // Fold in a real past question roughly every 3rd non-boss slot when the
    // pool has them; the rest stay freshly generated at the ramping rating.
    if (_pastPool.isNotEmpty && index < 27 && index % 3 == 1) {
      q = _pastPool.removeLast();
    } else {
      q = generate(widget.cat.id, _effRating, rng);
    }
    typedInput = '';
    answered = false;
    burned = {};
    qStart = DateTime.now().millisecondsSinceEpoch;
    setState(() {});
  }

  void _answer(String input) {
    if (answered) return;
    final t = DateTime.now().millisecondsSinceEpoch - qStart;
    answered = true;
    wasRight = q.check(input);
    if (wasRight) {
      correct++;
      if (t <= q.parMs) inPar++;
    }
    // feed the AI coach
    AppData.i.recordAnswer(widget.cat.id, wasRight, t, q.parMs,
        prompt: q.prompt, answer: q.answer);
    setState(() {});
    Timer(Duration(milliseconds: wasRight ? 650 : 1600), () {
      if (!mounted) return;
      index++;
      _next();
    });
  }

  void _fifty() {
    if (answered || q.options == null || burned.isNotEmpty) return;
    final a = AppData.i;
    if (a.freeHints > 0) {
      a.freeHints--;
      a.save();
    } else if (!a.spendCoins(25)) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not enough coins (25).')));
      return;
    }
    final wrong = <int>[];
    for (var i = 0; i < q.options!.length; i++) {
      if (q.options![i] != q.answer) wrong.add(i);
    }
    wrong.shuffle();
    setState(() => burned = wrong.take(2).toSet());
  }

  void _finish() {
    if (finished) return;
    finished = true;
    final acc = correct / total;
    final onPar = correct == 0 ? 0.0 : inPar / max(correct, 1);
    final stars = starsFor(acc, onPar);
    // +5 for finishing a 30-question section, +10 more for clearing it
    // A one-star pass unlocks the next rating; stronger clears pay a bonus.
    final coins = (widget.level ~/ 10) * stars + 5 + (stars >= 2 ? 10 : 0);
    AppData.i.recordLevel(widget.cat.id, widget.level, stars);
    if (coins > 0) AppData.i.earnCoins(coins);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => LevelResultDialog(
          cat: widget.cat,
          level: widget.level,
          stars: stars,
          detail: '$correct / $total correct',
          coins: coins),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ShaderBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Row(children: [
                Glass(
                    radius: 16,
                    padding: const EdgeInsets.all(8),
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, size: 18)),
                const SizedBox(width: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: index / total,
                      minHeight: 8,
                      backgroundColor: DC.fg10,
                      valueColor: AlwaysStoppedAnimation(DC.cyan),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text('${index + 1}/$total',
                    style: TextStyle(fontSize: 12, color: DC.dim)),
                const SizedBox(width: 8),
                Glass(
                    radius: 16,
                    padding: const EdgeInsets.all(8),
                    onTap: () => showCatTutorial(context, widget.cat),
                    child: Icon(Icons.help_outline, size: 18, color: DC.amber)),
              ]),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${widget.level} · effective $_effRating',
                      style: TextStyle(fontSize: 11, color: DC.dim)),
                  if (index >= 27)
                    Text('⚡ BOSS QUESTION',
                        style: TextStyle(
                            fontSize: 11,
                            color: DC.magenta,
                            fontWeight: FontWeight.w800)),
                  Text('✓ $correct',
                      style: TextStyle(fontSize: 12, color: DC.lime)),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Glass(
                      radius: 24,
                      padding: const EdgeInsets.all(22),
                      border: answered
                          ? Border.all(
                              color: wasRight ? DC.lime : DC.danger, width: 2)
                          : null,
                      child: Column(children: [
                        Text(q.prompt,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: q.prompt.length > 60 ? 17 : 24,
                                fontWeight: FontWeight.w700,
                                height: 1.4)),
                        if (answered && !wasRight) ...[
                          const SizedBox(height: 10),
                          Text('Answer: ${q.answer}',
                              style: TextStyle(
                                  color: DC.lime, fontWeight: FontWeight.w800)),
                          if (q.note != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(q.note!,
                                  textAlign: TextAlign.center,
                                  style:
                                      TextStyle(fontSize: 12, color: DC.dim)),
                            ),
                        ],
                      ]),
                    ),
                    const SizedBox(height: 20),
                    if (q.typed) _keypad() else _options(),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _options() {
    return Column(children: [
      for (var i = 0; i < q.options!.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Opacity(
            opacity: burned.contains(i) ? 0.25 : 1,
            child: GhostButton(
              label: q.options![i],
              onPressed: burned.contains(i) || answered
                  ? null
                  : () => _answer(q.options![i]),
            ),
          ),
        ),
      TextButton.icon(
        onPressed: _fifty,
        icon: Icon(Icons.lightbulb, size: 16, color: DC.amber),
        label: Text(
            AppData.i.freeHints > 0
                ? '50:50 (${AppData.i.freeHints} free)'
                : '50:50 (25 coins)',
            style: TextStyle(color: DC.amber, fontSize: 13)),
      ),
    ]);
  }

  Widget _keypad() {
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '.', '0', '⌫'];
    return Column(children: [
      Glass(
        radius: 18,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Text(typedInput.isEmpty ? '…' : typedInput,
            style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.w900, color: DC.cyan)),
      ),
      const SizedBox(height: 12),
      for (var row = 0; row < 4; row++)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var col = 0; col < 3; col++)
              Padding(
                padding: const EdgeInsets.all(4),
                child: GestureDetector(
                  onTap: answered
                      ? null
                      : () {
                          final k = keys[row * 3 + col];
                          setState(() {
                            if (k == '⌫') {
                              if (typedInput.isNotEmpty) {
                                typedInput = typedInput.substring(
                                    0, typedInput.length - 1);
                              }
                            } else {
                              typedInput += k;
                            }
                          });
                        },
                  child: Container(
                    width: 64,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: DC.fgo(0.06),
                      border: Border.all(color: DC.fgo(0.12)),
                    ),
                    child: Center(
                        child: Text(keys[row * 3 + col],
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w800))),
                  ),
                ),
              ),
          ],
        ),
      const SizedBox(height: 10),
      NeonButton(
          label: 'SUBMIT',
          height: 48,
          onPressed: answered || typedInput.isEmpty
              ? null
              : () => _answer(typedInput)),
    ]);
  }
}

/// ============================ BOARD SESSION ============================
class BoardSessionScreen extends StatefulWidget {
  final Cat cat;
  final int level;
  const BoardSessionScreen({super.key, required this.cat, required this.level});

  @override
  State<BoardSessionScreen> createState() => _BoardSessionScreenState();
}

class _BoardSessionScreenState extends State<BoardSessionScreen> {
  int index = 0;
  int wins = 0;
  int fastWins = 0;
  bool between = false;
  BoardResult? last;
  bool finished = false;

  @override
  void initState() {
    super.initState();
    AppData.i.freeHints = 3;
  }

  void _onBoardDone(BoardResult r) {
    last = r;
    if (r.won) {
      wins++;
      if (r.timeMs <= 120000) fastWins++;
    }
    setState(() => between = true);
    Timer(const Duration(milliseconds: 1300), () {
      if (!mounted) return;
      index++;
      if (index >= boardsPerLevel) {
        _finish();
      } else {
        setState(() => between = false);
      }
    });
  }

  void _finish() {
    if (finished) return;
    finished = true;
    final acc = wins / boardsPerLevel;
    final onPar = wins == 0 ? 0.0 : fastWins / wins;
    final stars = starsFor(acc, onPar);
    final coins = (widget.level ~/ 10) * stars;
    AppData.i.recordLevel(widget.cat.id, widget.level, stars);
    if (coins > 0) AppData.i.earnCoins(coins);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => LevelResultDialog(
          cat: widget.cat,
          level: widget.level,
          stars: stars,
          detail: '$wins / $boardsPerLevel boards solved',
          coins: coins),
    );
  }

  @override
  Widget build(BuildContext context) {
    final seed = widget.cat.id.hashCode ^ (widget.level * 131) ^ (index * 7907);
    // slight intra-level ramp for boards
    final eff =
        min(widget.level + (index >= boardsPerLevel - 2 ? 100 : 0), 2500);
    return Scaffold(
      body: ShaderBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Row(children: [
                Glass(
                    radius: 16,
                    padding: const EdgeInsets.all(8),
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, size: 18)),
                const SizedBox(width: 12),
                Text('${widget.cat.name} · ${widget.level}',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const Spacer(),
                Text('Board ${min(index + 1, boardsPerLevel)}/$boardsPerLevel',
                    style: TextStyle(fontSize: 12, color: DC.dim)),
              ]),
              const SizedBox(height: 12),
              Expanded(
                child: between
                    ? Center(
                        child: Glass(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                  last?.won == true
                                      ? Icons.check_circle
                                      : Icons.cancel,
                                  size: 54,
                                  color:
                                      last?.won == true ? DC.lime : DC.danger),
                              const SizedBox(height: 8),
                              Text(
                                  last?.won == true
                                      ? 'SOLVED in ${((last?.timeMs ?? 0) / 1000).toStringAsFixed(0)}s'
                                      : 'FAILED',
                                  style:
                                      Theme.of(context).textTheme.titleLarge),
                              if (index + 2 >= boardsPerLevel &&
                                  index + 1 < boardsPerLevel)
                                Padding(
                                  padding: EdgeInsets.only(top: 6),
                                  child: Text('⚡ boss board next',
                                      style: TextStyle(
                                          color: DC.magenta, fontSize: 12)),
                                ),
                            ],
                          ),
                        ),
                      )
                    : index < boardsPerLevel
                        ? boardFor(widget.cat.id, eff, seed, _onBoardDone)
                        : const SizedBox(),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// ============================ RESULT DIALOG ============================
class LevelResultDialog extends StatelessWidget {
  final Cat cat;
  final int level;
  final int stars;
  final String detail;
  final int coins;
  const LevelResultDialog(
      {super.key,
      required this.cat,
      required this.level,
      required this.stars,
      required this.detail,
      required this.coins});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: DC.bg2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (stars == 3) const ConfettiBurst(height: 60),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var s = 0; s < 3; s++)
              Icon(Icons.star_rounded,
                  size: 44, color: s < stars ? DC.amber : DC.fg12),
          ]),
          const SizedBox(height: 10),
          Text(
              stars == 3
                  ? 'FLAWLESS!'
                  : stars == 2
                      ? 'LEVEL CLEARED!'
                      : stars == 1
                          ? 'PASSED'
                          : 'NOT YET…',
              style: Theme.of(context).textTheme.displayMedium),
          const SizedBox(height: 6),
          Text(detail, style: TextStyle(color: DC.dim)),
          if (coins > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('+$coins coins 🪙',
                  style:
                      TextStyle(color: DC.amber, fontWeight: FontWeight.w800)),
            ),
          if (stars >= 1 && level < 2500)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Rating ${level + 100} unlocked!',
                  style:
                      TextStyle(color: DC.cyan, fontWeight: FontWeight.w700)),
            ),
          const SizedBox(height: 18),
          NeonButton(
              label: 'CONTINUE',
              height: 48,
              onPressed: () {
                Navigator.pop(context); // dialog
                Navigator.pop(context); // session
              }),
        ]),
      ),
    );
  }
}

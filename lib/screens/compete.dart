import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../core/fx.dart';
import '../core/state.dart';
import '../engine/chess_puzzles.dart';
import '../engine/generators.dart';
import '../engine/question.dart';
import '../engine/rating_catalog.dart';
import '../services/account_service.dart';
import '../theme_district.dart';
import '../ui/extras.dart';
import '../ui/glass.dart';
import 'art_race.dart';
import 'arrow_screen.dart';
import 'chess_duel.dart';
import 'cross_math_screen.dart';
import 'crossword_screen.dart';
import 'cube_screens.dart';
import 'darts_duel.dart';
import 'hanoi_screen.dart';
import 'mind_games.dart';
import 'numpuzzle_screen.dart';
import 'online_play.dart';
import 'scribble.dart';
import 'showdown_screen.dart';
import 'sudoku_screen.dart';
import 'word_finder.dart';

const _feedCats = [
  'mental',
  'quant',
  'numtheory',
  'patterns',
  'geometry',
  'probability',
  'clock',
  'words',
];

/// Every game supported by the shared online-room router, plus every ready
/// question feed. Keeping this generated prevents the navbar's 1v1 page from
/// silently falling behind the Games hub again.
List<String> get _duelCats {
  final ids = <String>[
    'chess',
    'darts',
    'cube',
    'art',
    'scribble',
    'wordfind',
    'sudoku',
    'hanoi',
    'numpz',
    'arrow',
    'crossword',
    ...cats.where((cat) => cat.ready && !cat.board).map((cat) => cat.id),
    'tactics',
  ];
  return ids.toSet().toList();
}

String duelCatName(String id) => switch (id) {
      'chess' => 'Chess ♟',
      'cube' => "Rubik's Cube",
      'art' => 'Art Heist',
      'scribble' => 'Scribble',
      'wordfind' => 'Word Finder',
      'sudoku' => 'Sudoku',
      'hanoi' => 'Tower of Hanoi',
      'numpz' => 'Number Puzzle',
      'arrow' => 'Arrow Puzzle',
      'crossword' => 'Crossword',
      'tactics' => 'Tactics',
      'darts' => 'Darts',
      _ => catById(id).name,
    };

IconData duelCatIcon(String id) => switch (id) {
      'chess' => Icons.grid_4x4_rounded,
      'darts' => Icons.gps_fixed_rounded,
      'cube' => Icons.view_in_ar_rounded,
      'art' => Icons.image_search_rounded,
      'scribble' => Icons.draw_rounded,
      'wordfind' => Icons.manage_search_rounded,
      'sudoku' => Icons.grid_on_rounded,
      'hanoi' => Icons.layers_rounded,
      'numpz' => Icons.grid_3x3_rounded,
      'arrow' => Icons.explore_rounded,
      'crossword' => Icons.view_module_rounded,
      'tactics' => Icons.psychology_alt_rounded,
      _ => catById(id).icon,
    };

const _botNames = [
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

/// ============================ DAILY ============================
class DailyScreen extends StatefulWidget {
  const DailyScreen({super.key});

  @override
  State<DailyScreen> createState() => _DailyScreenState();
}

class _DailyScreenState extends State<DailyScreen> {
  late Question q;
  bool answered = false;
  bool right = false;

  @override
  void initState() {
    super.initState();
    final key = AppData.todayKey();
    final rng = Random(key.hashCode);
    final cat = _feedCats[key.hashCode.abs() % _feedCats.length];
    final rating = min(AppData.i.overallRating + 100, 2500);
    q = generate(cat, rating, rng);
  }

  void _answer(String input) {
    if (answered || AppData.i.dailyDone) return;
    setState(() {
      answered = true;
      right = q.check(input);
    });
    if (right)
      AppData.i.addCoins(100); // legacy screen — Daily5Screen is the real daily
  }

  @override
  Widget build(BuildContext context) {
    final a = AppData.i;
    final done = a.dailyDone;
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
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back, size: 18)),
                const SizedBox(width: 12),
                Text('DAILY PROBLEM',
                    style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                Pill(
                    icon: Icons.local_fire_department,
                    label: '${a.streak}',
                    color: DC.amber),
              ]),
              const SizedBox(height: 10),
              Text('The whole world gets this exact problem today.',
                  style: TextStyle(fontSize: 12, color: DC.dim)),
              const Spacer(),
              if (done && !answered)
                Glass(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.check_circle, size: 60, color: DC.lime),
                    const SizedBox(height: 10),
                    Text('Done for today!',
                        style: Theme.of(context).textTheme.displayMedium),
                    const SizedBox(height: 6),
                    Text('Streak: ${a.streak} 🔥 · come back tomorrow',
                        style: TextStyle(color: DC.dim)),
                  ]),
                )
              else ...[
                Glass(
                  radius: 24,
                  padding: const EdgeInsets.all(22),
                  border: answered
                      ? Border.all(color: right ? DC.lime : DC.danger, width: 2)
                      : null,
                  child: Column(children: [
                    Text(q.prompt,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            height: 1.4)),
                    if (answered) ...[
                      const SizedBox(height: 12),
                      Text(
                          right
                              ? '+${100 + (a.streak >= 7 ? 50 : 0)} coins · streak ${a.streak} 🔥'
                              : 'Answer: ${q.answer}',
                          style: TextStyle(
                              color: right ? DC.lime : DC.danger,
                              fontWeight: FontWeight.w800)),
                    ],
                  ]),
                ),
                const SizedBox(height: 18),
                if (!answered && q.options != null)
                  for (final o in q.options!)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GhostButton(label: o, onPressed: () => _answer(o)),
                    ),
                if (!answered && q.options == null)
                  _TypedAnswer(onSubmit: _answer),
              ],
              const Spacer(),
            ]),
          ),
        ),
      ),
    );
  }
}

class _TypedAnswer extends StatefulWidget {
  final void Function(String) onSubmit;
  const _TypedAnswer({required this.onSubmit});

  @override
  State<_TypedAnswer> createState() => _TypedAnswerState();
}

class _TypedAnswerState extends State<_TypedAnswer> {
  final c = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Glass(
        radius: 18,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(
              decimal: true, signed: true),
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 24, fontWeight: FontWeight.w900, color: DC.cyan),
          decoration:
              const InputDecoration(border: InputBorder.none, hintText: '?'),
        ),
      ),
      const SizedBox(height: 12),
      NeonButton(
          label: 'SUBMIT',
          height: 48,
          onPressed: () {
            if (c.text.trim().isEmpty) return;
            widget.onSubmit(c.text);
            c.clear(); // fresh field for the next question
          }),
    ]);
  }
}

/// ============================ 1v1 DUEL ============================
class DuelTab extends StatefulWidget {
  const DuelTab({super.key});

  @override
  State<DuelTab> createState() => _DuelTabState();
}

class _DuelTabState extends State<DuelTab> {
  String catId = 'mental';
  int wager = 0;

  @override
  Widget build(BuildContext context) {
    // This tab sits under a `const FirstTimeGuide(...)` in DistrictHome, so
    // Flutter skips rebuilding it once mounted (identical const instances
    // never get build() called again) — the elo badge would otherwise
    // freeze at launch-time. AnimatedBuilder subscribes independently.
    return AnimatedBuilder(
      animation: AppData.i,
      builder: (context, _) => _duelTabBody(context),
    );
  }

  Widget _duelTabBody(BuildContext context) {
    final a = AppData.i;
    return SafeArea(
      child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          children: [
            Glass(
              radius: 28,
              padding: const EdgeInsets.all(18),
              tint: ThemeCtl.isDark ? DC.violet : DC.cyan,
              child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(19),
                      gradient: LinearGradient(
                        colors: [DC.cyan, DC.violet],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Icon(
                      Icons.sports_kabaddi_rounded,
                      color: Colors.white,
                      size: 29,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '1V1 ARENA',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8,
                                  ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${_duelCats.length + 1} games · bot, online or friend',
                          style: TextStyle(color: DC.dim, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: DC.band(a.elo).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${a.elo}',
                          style: TextStyle(
                            color: DC.band(a.elo),
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          DC.bandName(a.elo).toUpperCase(),
                          style: TextStyle(
                            color: DC.band(a.elo),
                            fontSize: 7,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.7,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Reflex Duel — the action challenge
            Glass(
              tint: DC.magenta,
              onTap: () => showReflexCompete(context),
              child: Row(children: [
                Icon(Icons.bolt, color: DC.magenta, size: 34),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('REFLEX DUEL ⚡',
                          style: TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 16)),
                      Text('The action arena — reaction rounds, online rooms',
                          style: TextStyle(fontSize: 12, color: DC.dim)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: DC.dim),
              ]),
            ),
            const SizedBox(height: 20),
            Text('MIND DUEL — pick your weapon',
                style:
                    TextStyle(fontSize: 11, letterSpacing: 2, color: DC.dim)),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 9,
                crossAxisSpacing: 9,
                childAspectRatio: 1.08,
              ),
              itemCount: _duelCats.length,
              itemBuilder: (_, index) {
                final id = _duelCats[index];
                return _DuelGameTile(
                  icon: duelCatIcon(id),
                  label: duelCatName(id),
                  selected: catId == id,
                  onTap: () => setState(() {
                    catId = id;
                    if (!_supportsWager(id)) wager = 0;
                  }),
                );
              },
            ),
            if (catId == 'chess')
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                    '♟ You\'ll pick a time control next (5m–2h or untimed).',
                    style: TextStyle(fontSize: 11, color: DC.cyan)),
              ),
            const SizedBox(height: 18),
            if (_supportsWager(catId)) ...[
              Text('WAGER',
                  style:
                      TextStyle(fontSize: 11, letterSpacing: 2, color: DC.dim)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, children: [
                for (final w in [0, 50, 100, 250])
                  _chip(w == 0 ? 'Free' : '$w 🪙', wager == w,
                      () => setState(() => wager = w)),
              ]),
            ] else
              Glass(
                radius: 16,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                tint: ThemeCtl.isDark ? DC.violet : DC.cyan,
                child: Row(
                  children: [
                    Icon(Icons.shield_outlined, color: DC.cyan, size: 18),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Skill-only match · no coin wager for this game',
                        style: TextStyle(color: DC.dim, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            NeonButton(
              label: 'PLAY VS BOT',
              icon: Icons.smart_toy,
              onPressed: () async {
                if (wager > 0 && a.coins < wager) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Not enough coins for that wager.')));
                  return;
                }
                final selectedRating =
                    await pickMindBotLevel(context, duelCatName(catId));
                if (selectedRating == null || !context.mounted) return;
                if (catId == 'chess') {
                  final tMin = await pickTimeControl(context, 'Chess ♟');
                  if (tMin == null || !context.mounted) return;
                  final botName = _botNames[Random().nextInt(_botNames.length)];
                  ShowdownScreen.go(context,
                      title: '1V1 · BOT',
                      oppName: botName,
                      detail: '$selectedRating · ${timeControlLabel(tMin)}',
                      autoStart: false,
                      game: () => ChessDuelScreen(
                          wager: wager,
                          timeMinutes: tMin,
                          botName: botName,
                          practiceRating: selectedRating));
                  return;
                }
                startBotMatch(context,
                    label: duelCatName(catId),
                    detail: 'Bot rating $selectedRating',
                    game: () => _botGame(
                          catId,
                          selectedRating,
                          selectedWager: wager,
                        ));
              },
            ),
            const SizedBox(height: 10),
            NeonButton(
              label: 'SEARCH ONLINE',
              icon: Icons.public,
              colors: [DC.magenta, DC.violet],
              onPressed: () async {
                final (game, sub) = _onlineKey(catId);
                final cat = catId;
                var t = 0;
                if (cat == 'chess') {
                  final picked = await pickTimeControl(context, 'Chess ♟');
                  if (picked == null || !context.mounted) return;
                  t = picked;
                }
                if (!context.mounted) return;
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => MatchmakingScreen(
                            game: game,
                            sub: sub,
                            label: duelCatName(catId),
                            timeMinutes: t,
                            botScreen: () => cat == 'chess'
                                ? ChessDuelScreen(wager: 0, timeMinutes: t)
                                : _botGame(cat, AppData.i.elo))));
              },
            ),
            const SizedBox(height: 10),
            GhostButton(
              label: 'PLAY A FRIEND (CODE / LINK)',
              icon: Icons.group,
              onPressed: () {
                final (game, sub) = _onlineKey(catId);
                // showFriendPlayDialog pops its own time picker for chess.
                showFriendPlayDialog(context, game, sub, duelCatName(catId));
              },
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                  'Online and friend matches let you choose an 800–2500 rating range. Rated online games are wager-free.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: DC.dim)),
            ),
          ]),
    );
  }

  bool _supportsWager(String id) =>
      id == 'chess' ||
      id == 'darts' ||
      id == 'tactics' ||
      cats.any((cat) => cat.id == id && !cat.board);

  Widget _botGame(
    String id,
    int rating, {
    int selectedWager = 0,
  }) {
    final level = RatingCatalog.legacyLevelForRating(rating);
    return switch (id) {
      'darts' => DartsDuelScreen(wager: selectedWager, botRating: rating),
      'cube' => CubeBotRaceScreen(n: rating < 1700 ? 3 : 4),
      'art' => ArtRaceScreen(
          size: rating < 1300
              ? 3
              : rating < 1800
                  ? 4
                  : 5,
        ),
      'scribble' => const ScribbleScreen(),
      'wordfind' => WordFinderScreen(rating: rating),
      'sudoku' => SudokuScreen(
          level: level,
          botLevel: level,
          displayRating: rating,
        ),
      'hanoi' => HanoiScreen(
          level: level,
          botLevel: level,
          displayRating: rating,
        ),
      'numpz' => NumPuzzleScreen(
          level: level,
          botLevel: level,
          displayRating: rating,
        ),
      'arrow' => ArrowPuzzleScreen(
          level: level,
          botLevel: level,
          displayRating: rating,
        ),
      'crossword' => CrosswordScreen(
          level: level,
          botLevel: level,
          displayRating: rating,
        ),
      'crossmath' => CrossMathGameScreen(
          level: level,
          botLevel: level,
          displayRating: rating,
        ),
      _ => DuelMatchScreen(
          catId: id,
          wager: selectedWager,
          botRating: rating,
        ),
    };
  }

  /// Maps a duel category to the online room (game, sub) key.
  (String, String) _onlineKey(String cat) => switch (cat) {
        'chess' => ('chess', 'std'),
        'darts' => ('darts', 'std'),
        'cube' => ('cube', 'std'),
        'art' => ('art', 'std'),
        'scribble' => ('scribble', 'std'),
        'wordfind' => ('wordfind', 'std'),
        'sudoku' => ('sudoku', 'std'),
        'hanoi' => ('hanoi', 'std'),
        'numpz' => ('numpz', 'std'),
        'arrow' => ('arrow', 'std'),
        'crossword' => ('crossword', 'std'),
        'crossmath' => ('crossmath', 'std'),
        _ => ('duel', cat),
      };

  Widget _chip(String label, bool sel, VoidCallback onTap) {
    final accent = ThemeCtl.isDark ? DC.cyan : DC.electric;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: sel ? accent.withOpacity(0.14) : DC.fgo(0.06),
            border: Border.all(
              color: sel ? accent.withOpacity(0.65) : DC.fgo(0.12),
            ),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 13,
                  color: sel ? accent : DC.text,
                  fontWeight: sel ? FontWeight.w800 : FontWeight.w500)),
        ),
      ),
    );
  }
}

class _DuelGameTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DuelGameTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = ThemeCtl.isDark ? DC.cyan : DC.electric;
    return Semantics(
      button: true,
      selected: selected,
      label: '$label duel',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? accent.withOpacity(0.14) : DC.fgo(0.045),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? accent.withOpacity(0.72) : DC.fgo(0.12),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: selected ? accent : DC.dim, size: 23),
                const SizedBox(height: 7),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? accent : DC.text,
                    fontSize: 10,
                    height: 1.15,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DuelMatchScreen extends StatefulWidget {
  final String catId;
  final int wager;
  final int? botRating;
  const DuelMatchScreen(
      {super.key, required this.catId, required this.wager, this.botRating});

  @override
  State<DuelMatchScreen> createState() => _DuelMatchScreenState();
}

class _DuelMatchScreenState extends State<DuelMatchScreen> {
  static const total = 7;
  final rng = Random();
  late String botName;
  late int botRating;
  bool searching = true;

  late Question q;
  int index = 0;
  int myScore = 0, botScore = 0;
  int qStart = 0;
  bool answered = false;
  bool finished = false;
  Timer? botTimer;
  int? botTime; // bot's time this question, null = hasn't answered
  bool botRight = false;
  int myTime = 0;
  bool myRight = false;

  @override
  void initState() {
    super.initState();
    final a = AppData.i;
    botName = _botNames[rng.nextInt(_botNames.length)];
    botRating = widget.botRating ??
        (a.elo + rng.nextInt(300) - 150).clamp(500, 2600).toInt();
    // Duel bots are friendly — no coin stake (XP + rating only).
    // Only ever reached via the Showdown "get ready" reveal, which already
    // introduced the opponent — skip the redundant second spinner here.
    // (Zero-delay Timer, not a direct call: setState can't run synchronously
    // inside initState, same pattern chess already uses for this.)
    Timer(Duration.zero, () {
      if (!mounted) return;
      setState(() => searching = false);
      _next();
    });
  }

  @override
  void dispose() {
    botTimer?.cancel();
    super.dispose();
  }

  void _next() {
    if (index >= total) {
      _finish();
      return;
    }
    final matchRating =
        ((AppData.i.elo + botRating) ~/ 2).clamp(800, 2500).toInt();
    q = widget.catId == 'tactics'
        ? chessQuestion(matchRating, rng)
        : generate(widget.catId, matchRating, rng);
    answered = false;
    botTime = null;
    qStart = DateTime.now().millisecondsSinceEpoch;
    // simulate bot
    final p = (0.55 + (botRating - 800) / 3400).clamp(0.35, 0.95);
    botRight = rng.nextDouble() < p;
    // Human-like reading+answering time, scaled by bot skill: strong
    // bots answer fast (~0.4× par), weak bots take longer (~1.05× par)
    // but with a hard cap so it never feels like an eternal "thinking…".
    final skill = ((botRating - 800) / 1800).clamp(0.0, 1.0);
    final frac = 1.05 - 0.65 * skill; // weak → 1.05, strong → 0.40
    final jitter = 0.85 + rng.nextDouble() * 0.4;
    final t = (q.parMs * frac * jitter).round().clamp(700, 6500);
    botTimer = Timer(Duration(milliseconds: t), () {
      if (!mounted || finished) return;
      setState(() => botTime = t);
      _maybeResolve();
    });
    setState(() {});
  }

  void _answer(String input) {
    if (answered) return;
    answered = true;
    myTime = DateTime.now().millisecondsSinceEpoch - qStart;
    myRight = q.check(input);
    setState(() {});
    _maybeResolve();
  }

  void _maybeResolve() {
    if (!answered || botTime == null || finished) return;
    // point: correct beats wrong; both correct → faster wins; both wrong → nobody
    if (myRight && (!botRight || myTime <= botTime!)) myScore++;
    if (botRight && (!myRight || botTime! < myTime)) botScore++;
    Timer(const Duration(milliseconds: 1100), () {
      if (!mounted) return;
      index++;
      _next();
    });
  }

  void _finish() {
    if (finished) return;
    finished = true;
    final a = AppData.i;
    final won = myScore > botScore;
    final draw = myScore == botScore;
    if (won) {
      Fx.win();
    } else if (!draw) {
      Fx.lose();
    }
    final delta = a.applyElo(botRating, won ? 1 : (draw ? 0.5 : 0));
    // Duel bots are friendly — XP + rating only, no wager coins to farm.
    a.addXp(won ? 30 : (draw ? 15 : 8));
    a.recordMatch(
        mode: 'Duel · ${duelCatName(widget.catId)}',
        opponent: botName,
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
            Icon(won ? Icons.emoji_events : Icons.psychology_alt,
                size: 60, color: won ? DC.amber : DC.violet),
            const SizedBox(height: 10),
            Text(won ? 'VICTORY!' : (draw ? 'DRAW' : 'DEFEAT'),
                style: Theme.of(context).textTheme.displayMedium),
            Text('$myScore — $botScore vs $botName ($botRating)',
                style: TextStyle(color: DC.dim)),
            const SizedBox(height: 8),
            Text('${delta >= 0 ? '+' : ''}$delta rating',
                style: TextStyle(
                    color: delta >= 0 ? DC.lime : DC.danger,
                    fontWeight: FontWeight.w900,
                    fontSize: 18)),
            const SizedBox(height: 8),
            const ReactionBar(),
            TextButton.icon(
              onPressed: () => shareResult(
                  context,
                  won
                      ? 'Just beat $botName $myScore–$botScore in ${duelCatName(widget.catId)} on MYNDASH ⚔️ Rating: ${a.elo}. Who\'s next?'
                      : 'Went $myScore–$botScore vs $botName in ${duelCatName(widget.catId)} on MYNDASH. Running it back 😤'),
              icon: Icon(Icons.ios_share, size: 16, color: DC.cyan),
              label: Text('Share result',
                  style: TextStyle(color: DC.cyan, fontSize: 13)),
            ),
            const SizedBox(height: 6),
            NeonButton(
              label: 'PLAY AGAIN',
              icon: Icons.refresh,
              height: 46,
              colors: [DC.magenta, DC.violet],
              onPressed: () {
                Navigator.pop(context); // close result dialog
                Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            DuelMatchScreen(catId: widget.catId, wager: 0)));
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

  @override
  Widget build(BuildContext context) {
    if (searching) {
      return Scaffold(
        body: ShaderBackground(
          child: Center(
            child: Glass(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                SizedBox(
                    width: 54,
                    height: 54,
                    child: CircularProgressIndicator(
                        strokeWidth: 3, color: DC.cyan)),
                const SizedBox(height: 16),
                Text('Finding opponent…',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                Text(
                    '${duelCatName(widget.catId)} · ${widget.wager > 0 ? '${widget.wager} 🪙 wager' : 'friendly'}',
                    style: TextStyle(color: DC.dim, fontSize: 12)),
              ]),
            ),
          ),
        ),
      );
    }
    return Scaffold(
      body: ShaderBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Glass(
                radius: 20,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(children: [
                      Text(AppData.i.name,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700)),
                      Text('$myScore',
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: DC.cyan)),
                    ]),
                    Text('Q${min(index + 1, total)}/$total',
                        style: TextStyle(fontSize: 11, color: DC.dim)),
                    Column(children: [
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        LetterAvatar(name: botName, size: 20),
                        const SizedBox(width: 6),
                        Text(botName,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700)),
                      ]),
                      Text('$botScore',
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: DC.magenta)),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: Text(
                      answered
                          ? (myRight ? '✓ you answered' : '✗ you missed')
                          : 'answer fast…',
                      style: TextStyle(
                          fontSize: 11,
                          color: answered
                              ? (myRight ? DC.lime : DC.danger)
                              : DC.dim)),
                ),
                Text(
                    botTime != null
                        ? '$botName answered!'
                        : '$botName is thinking…',
                    style: TextStyle(
                        fontSize: 11,
                        color: botTime != null ? DC.magenta : DC.dim)),
              ]),
              const SizedBox(height: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Glass(
                      radius: 24,
                      padding: const EdgeInsets.all(20),
                      child: Text(q.prompt,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: q.prompt.length > 60 ? 16 : 22,
                              fontWeight: FontWeight.w700,
                              height: 1.4)),
                    ),
                    const SizedBox(height: 18),
                    if (q.options != null)
                      for (final o in q.options!)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: GhostButton(
                              label: o,
                              height: 46,
                              onPressed: answered ? null : () => _answer(o)),
                        )
                    else
                      _TypedAnswer(onSubmit: _answer),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// ============================ ARENA ============================
class ArenaTab extends StatelessWidget {
  const ArenaTab({super.key});

  static List<(String, int, Color)> get rooms => [
        ('CASUAL ARENA', 0, DC.lime),
        ('RISER · 50', 50, DC.cyan),
        ('CHALLENGER · 200', 200, DC.violet),
        ('ELITE · 500', 500, DC.amber),
      ];

  @override
  Widget build(BuildContext context) {
    final a = AppData.i;
    return SafeArea(
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Text('ARENA', style: Theme.of(context).textTheme.displayMedium),
        Text('8 minds · 10 questions · winner takes the pot',
            style: TextStyle(color: DC.dim, fontSize: 13)),
        const SizedBox(height: 16),
        for (final (name, fee, color) in rooms)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Glass(
              onTap: () {
                if (fee > 0 && a.coins < fee) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Not enough coins for this arena.')));
                  return;
                }
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => ArenaMatchScreen(fee: fee)));
              },
              child: Row(children: [
                Icon(Icons.stadium, color: color, size: 30),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w900, letterSpacing: 1)),
                        Text(
                            fee == 0
                                ? 'Free entry · glory only'
                                : 'Entry $fee 🪙 · pot ${fee * 8} → 🥇 ${(fee * 8 * 0.6).round()} · 🥈 ${(fee * 8 * 0.25).round()}',
                            style: TextStyle(fontSize: 11, color: DC.dim)),
                      ]),
                ),
                Icon(Icons.chevron_right, color: DC.dim),
              ]),
            ),
          ),
        const SizedBox(height: 4),
        Center(
          child: Text(
              'Prize pools are simulated in this build.\nReal-money entry needs payments + compliance (see docs/PLAN.md).',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: DC.dim)),
        ),
      ]),
    );
  }
}

class ArenaMatchScreen extends StatefulWidget {
  final int fee;

  /// Topic the questions come from: 'mixed' or any feed category id
  /// (mental, quant, finance, speedmath, …).
  final String category;

  /// Up to 5 topics blended together (one drawn at random per question).
  /// Null/empty falls back to [category] (or every feed topic if that's
  /// 'mixed').
  final List<String>? categories;

  /// 10–30 questions, 10–30 minutes — set by the arena's host.
  final int questionCount;
  final int durationMin;
  final int gameRating;

  /// Field size including you.
  final int players;

  /// Prize pool in coins; -1 = classic fee × players pot.
  final int prizePool;

  /// Percent of the pot for 1st / 2nd place. Hosted-arena rules:
  /// public arenas 100/0 (winner takes all), private 75/25.
  final int split1;
  final int split2;
  final String? eventId;

  /// Shared seed: every entrant of the same arena draws the SAME
  /// questions from the topic's bank. Null = solo random paper.
  final int? seed;

  const ArenaMatchScreen({
    super.key,
    required this.fee,
    this.category = 'mixed',
    this.categories,
    this.questionCount = 10,
    this.durationMin = 10,
    this.gameRating = 800,
    this.players = 8,
    this.prizePool = -1,
    this.split1 = 60,
    this.split2 = 25,
    this.seed,
    this.eventId,
  });

  @override
  State<ArenaMatchScreen> createState() => _ArenaMatchScreenState();
}

class _Contender {
  final String name;
  final int rating;
  final bool me;
  int score = 0;
  _Contender(this.name, this.rating, {this.me = false});
}

class _ArenaMatchScreenState extends State<ArenaMatchScreen> {
  late final int total = widget.questionCount;

  /// Per-question clock: the arena's total time split evenly,
  /// clamped to a sane 8–60s window.
  late final int perQMs =
      (widget.durationMin * 60000 ~/ total).clamp(8000, 60000).toInt();

  /// Seeded → identical paper for every entrant of this arena.
  late final Random rng = widget.seed != null ? Random(widget.seed!) : Random();
  final Random _simRng = Random(); // bot behaviour stays organic
  late List<_Contender> field;
  late Question q;
  int index = 0;
  int qStart = 0;
  bool answered = false;
  bool showStandings = false;
  bool finished = false;
  Timer? qTimer;

  int get _bots => (widget.players - 1).clamp(1, 127).toInt();

  /// Topics this arena's questions are drawn from — a host-picked combo of
  /// up to 5, a single topic, or every feed topic when set to 'mixed'.
  late final List<String> _topicPool = () {
    final list = widget.categories ?? [widget.category];
    if (list.length == 1 && list.first == 'mixed') return _feedCats;
    return list;
  }();

  @override
  void initState() {
    super.initState();
    final a = AppData.i;
    if (widget.fee > 0) a.spendCoins(widget.fee);
    final names = <String>[];
    while (names.length < _bots) {
      names.addAll(List<String>.from(_botNames)..shuffle(_simRng));
    }
    field = [
      _Contender(a.name, a.elo, me: true),
      for (var i = 0; i < _bots; i++)
        _Contender(
            names[i] +
                (i >= _botNames.length ? '_${i ~/ _botNames.length}' : ''),
            (widget.gameRating + _simRng.nextInt(300) - 150)
                .clamp(800, 2500)
                .toInt()),
    ];
    _next();
  }

  @override
  void dispose() {
    qTimer?.cancel();
    super.dispose();
  }

  void _next() {
    if (index >= total) {
      _finish();
      return;
    }
    // A single topic draws every question from that topic's bank; a combo
    // (or 'mixed') draws a random topic from the pool per question.
    final catId = _topicPool.length > 1
        ? _topicPool[rng.nextInt(_topicPool.length)]
        : _topicPool.first;
    q = generate(catId, widget.gameRating.clamp(800, 2500).toInt(), rng);
    answered = false;
    showStandings = false;
    qStart = DateTime.now().millisecondsSinceEpoch;
    qTimer = Timer(Duration(milliseconds: perQMs), () {
      if (!mounted || answered) return;
      _resolve(0, false); // timed out
    });
    setState(() {});
  }

  void _answer(String input) {
    if (answered) return;
    qTimer?.cancel();
    final t = DateTime.now().millisecondsSinceEpoch - qStart;
    _resolve(t, q.check(input));
  }

  void _resolve(int myT, bool myRight) {
    answered = true;
    // my points
    if (myRight) {
      field[0].score +=
          100 + ((perQMs - myT) / perQMs * 50).clamp(0, 50).round();
    }
    // bots
    for (final b in field.skip(1)) {
      final p = (0.5 + (b.rating - 800) / 3000).clamp(0.3, 0.95);
      if (_simRng.nextDouble() < p) {
        final t = (q.parMs * (0.5 + _simRng.nextDouble())).clamp(800, perQMs);
        b.score += 100 + ((perQMs - t) / perQMs * 50).clamp(0, 50).round();
      }
    }
    setState(() => showStandings = true);
    Timer(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      index++;
      _next();
    });
  }

  void _finish() {
    if (finished) return;
    finished = true;
    final a = AppData.i;
    final sorted = List<_Contender>.from(field)
      ..sort((x, y) => y.score.compareTo(x.score));
    final place = sorted.indexWhere((c) => c.me) + 1;
    final pot =
        widget.prizePool >= 0 ? widget.prizePool : widget.fee * widget.players;
    var prize = 0;
    if (pot > 0) {
      if (place == 1) prize = pot * widget.split1 ~/ 100;
      if (place == 2) prize = pot * widget.split2 ~/ 100;
      if (prize > 0) a.addCoins(prize);
    }
    final avgRating =
        field.skip(1).fold<int>(0, (s, c) => s + c.rating) ~/ _bots;
    final scoreFrac =
        (1.0 - (place - 1) / max(field.length - 1, 1)).clamp(0.0, 1.0);
    final delta = a.applyElo(avgRating, place == 1 ? 1.0 : scoreFrac * 0.8);
    a.recordMatch(
        mode: 'Arena',
        opponent: '${field.length}-player field',
        result: place == 1 ? 'W' : (place <= 3 ? 'D' : 'L'),
        delta: delta);
    if (widget.eventId != null) {
      AccountService.instance
          .submitHostedArenaScore(widget.eventId!, field.first.score);
    }
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
            if (place == 1) const ConfettiBurst(height: 70),
            Text(
                place == 1
                    ? '🥇'
                    : place == 2
                        ? '🥈'
                        : place == 3
                            ? '🥉'
                            : '#$place',
                style: const TextStyle(fontSize: 52)),
            Text(place <= 2 ? 'PODIUM!' : 'FINISHED #$place',
                style: Theme.of(context).textTheme.displayMedium),
            const SizedBox(height: 6),
            if (prize > 0)
              Text('+$prize coins 🪙',
                  style: TextStyle(
                      color: DC.amber,
                      fontWeight: FontWeight.w900,
                      fontSize: 18)),
            Text('${delta >= 0 ? '+' : ''}$delta rating',
                style: TextStyle(
                    color: delta >= 0 ? DC.lime : DC.danger,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            for (var i = 0; i < 3 && i < sorted.length; i++)
              Text(
                  '${i + 1}. ${sorted[i].name}${sorted[i].me ? ' (you)' : ''} — ${sorted[i].score}',
                  style: TextStyle(
                      fontSize: 13, color: sorted[i].me ? DC.cyan : DC.dim)),
            const SizedBox(height: 18),
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

  @override
  Widget build(BuildContext context) {
    final sorted = List<_Contender>.from(field)
      ..sort((x, y) => y.score.compareTo(x.score));
    return Scaffold(
      body: ShaderBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: showStandings
                ? Column(children: [
                    Text('STANDINGS · Q${min(index + 1, total)}/$total',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView(children: [
                        for (var i = 0; i < sorted.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Glass(
                              radius: 16,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              tint: sorted[i].me ? DC.cyan : null,
                              child: Row(children: [
                                Text('${i + 1}',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: DC.dim)),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: Text(
                                        '${sorted[i].name}${sorted[i].me ? ' (you)' : ''}',
                                        style: TextStyle(
                                            fontWeight: sorted[i].me
                                                ? FontWeight.w900
                                                : FontWeight.w500))),
                                Text('${sorted[i].score}',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: DC.amber)),
                              ]),
                            ),
                          ),
                      ]),
                    ),
                  ])
                : Column(children: [
                    Row(children: [
                      Glass(
                          radius: 16,
                          padding: const EdgeInsets.all(8),
                          onTap: () => Navigator.pop(context),
                          child: const Icon(Icons.close, size: 18)),
                      const Spacer(),
                      Text('Q${min(index + 1, total)}/$total',
                          style: TextStyle(color: DC.dim)),
                      const Spacer(),
                      _CountdownBar(key: ValueKey(index), totalMs: perQMs),
                    ]),
                    const SizedBox(height: 20),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Glass(
                            radius: 24,
                            padding: const EdgeInsets.all(20),
                            child: Text(q.prompt,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: q.prompt.length > 60 ? 16 : 22,
                                    fontWeight: FontWeight.w700,
                                    height: 1.4)),
                          ),
                          const SizedBox(height: 18),
                          if (q.options != null)
                            for (final o in q.options!)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: GhostButton(
                                    label: o,
                                    height: 46,
                                    onPressed:
                                        answered ? null : () => _answer(o)),
                              )
                          else
                            _TypedAnswer(onSubmit: _answer),
                        ],
                      ),
                    ),
                  ]),
          ),
        ),
      ),
    );
  }
}

class _CountdownBar extends StatefulWidget {
  final int totalMs;
  const _CountdownBar({super.key, required this.totalMs});

  @override
  State<_CountdownBar> createState() => _CountdownBarState();
}

class _CountdownBarState extends State<_CountdownBar> {
  final int start = DateTime.now().millisecondsSinceEpoch;
  Timer? t;

  @override
  void initState() {
    super.initState();
    t = Timer.periodic(
        const Duration(milliseconds: 100), (_) => setState(() {}));
  }

  @override
  void dispose() {
    t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left =
        1 - (DateTime.now().millisecondsSinceEpoch - start) / widget.totalMs;
    return SizedBox(
      width: 90,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(
          value: left.clamp(0.0, 1.0).toDouble(),
          minHeight: 8,
          backgroundColor: DC.fg10,
          valueColor: AlwaysStoppedAnimation(left > 0.33 ? DC.cyan : DC.danger),
        ),
      ),
    );
  }
}

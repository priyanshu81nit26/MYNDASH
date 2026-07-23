import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../core/fx.dart';
import '../core/state.dart';
import '../daily_challenge/daily_bank.dart';
import '../daily_challenge/daily_game_screen.dart';
import '../engine/game_progression.dart';
import '../engine/mind_engines.dart';
import '../engine/rating_catalog.dart';
import '../services/account_service.dart';
import '../theme_district.dart';
import '../ui/extras.dart';
import '../ui/glass.dart';
import 'online_play.dart';

/// ============================================================
/// MIND GAMES FRAMEWORK — shared scaffolding for the 5 mind-fun
/// games (Sudoku, Hanoi, Number Puzzle, Arrow Puzzle, Crossword).
/// One consistent flow everywhere:
///   · PRACTICE — rating bands with increasing difficulty, ★ by time
///   · VS BOT — pick an 800–2500 bot rating
///   · ONLINE / FRIEND — identical seeded puzzle, live progress,
///     FIRST TO SOLVE ENDS THE MATCH.
/// A count-up timer runs in every mode.
/// ============================================================

typedef MindScreenBuilder = Widget Function(
    {int level,
    int? botLevel,
    Map<String, dynamic>? room,
    bool amHost,
    int? progressionStep,
    int? puzzleSeed,
    int? displayRating});

/// ---------------- 3D helpers ----------------

/// Subtle perspective tilt that gives flat boards a table-top 3D feel,
/// with a slow idle "breathing" float.
class Tilt3D extends StatefulWidget {
  final Widget child;
  final double tilt; // radians of X rotation
  const Tilt3D({super.key, required this.child, this.tilt = 0.10});

  @override
  State<Tilt3D> createState() => _Tilt3DState();
}

class _Tilt3DState extends State<Tilt3D> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 5))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) => Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0012)
          ..rotateX(widget.tilt + _c.value * 0.02),
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// ---------------- race controller mixin ----------------

/// Mix into a game screen's State. Call [initRace] in initState,
/// [reportProgress] whenever your solve % changes, and [solvedNow]
/// the instant the puzzle is complete. Everything else — timers, bot
/// simulation, Firebase sync, first-solve-wins resolution and the
/// result dialog — is handled here.
mixin MindRace<T extends StatefulWidget> on State<T> {
  late String raceGame; // 'sudoku' | 'hanoi' | ...
  late String raceLabel;
  int raceLevel = 1;
  int raceProgressStep = 1;
  int raceDisplayRating = RatingCatalog.min;
  int? raceLocalSeed;
  int? raceBotLevel;
  Map<String, dynamic>? raceRoom;
  bool raceAmHost = true;

  bool get isOnline => raceRoom != null;
  bool get isBot => raceBotLevel != null;
  bool get isPractice => !isOnline && !isBot;

  // timing
  int _startMs = 0;
  int _pausedMs = 0; // accumulated paused time
  int? _pauseAt;
  Timer? _ticker;
  bool paused = false;

  // opponent
  double oppProgress = 0;
  String oppName = 'Rival';
  int _botTotalS = 60;
  Timer? _botTimer;

  // online
  StreamSubscription? _roomSub;
  String get _mySide => raceAmHost ? 'host' : 'guest';
  String get _oppSide => raceAmHost ? 'guest' : 'host';
  int _lastProgWrite = 0;

  bool raceOver = false;
  bool iSolved = false;
  ValueChanged<int>? _arenaScore;

  /// Seed shared online and stable for rated practice variants.
  int get raceSeed => isOnline
      ? ((raceRoom!['seed'] as num?)?.toInt() ?? 7)
      : raceLocalSeed ?? Random().nextInt(1 << 31);

  int get elapsedS {
    if (_startMs == 0) return 0;
    final now = _pauseAt ?? DateTime.now().millisecondsSinceEpoch;
    return ((now - _startMs - _pausedMs) / 1000).floor();
  }

  String get clock {
    final s = elapsedS;
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  /// Highest practice level for this game (50 default; Hanoi journey = 45).
  int raceMaxLevel = 50;

  void initRace({
    required String game,
    required String label,
    required int level,
    int? botLevel,
    Map<String, dynamic>? room,
    bool amHost = true,
    int maxLevel = 50,
    int? progressionStep,
    int? progressMaxLevel,
    int? displayRating,
    int? localSeed,
    int? botPar,
    ValueChanged<int>? arenaScore,
  }) {
    raceGame = game;
    raceLabel = label;
    raceLevel = level;
    raceProgressStep = progressionStep ?? level;
    raceDisplayRating = displayRating ??
        RatingCatalog.ratingForLegacyLevel(level, maxLevel: maxLevel);
    raceLocalSeed = localSeed;
    raceBotLevel = botLevel;
    raceRoom = room;
    raceAmHost = amHost;
    raceMaxLevel = progressMaxLevel ?? maxLevel;
    _arenaScore = arenaScore;
    _startMs = DateTime.now().millisecondsSinceEpoch;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !raceOver && !paused) setState(() {});
    });
    if (isBot) {
      final rng = Random();
      _botTotalS = MindDifficulty.botSolveSeconds(game, botLevel!, rng,
          parOverride: botPar);
      oppName = _mindBotNames[rng.nextInt(_mindBotNames.length)];
      _botTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
        if (!mounted || raceOver) return;
        final p = (elapsedS / _botTotalS).clamp(0.0, 1.0).toDouble();
        // bots surge at the end — feels like a real solver locking in
        final eased = p < 0.75 ? p * 0.85 : 0.6375 + (p - 0.75) * 1.45;
        setState(() => oppProgress = eased.clamp(0.0, 1.0).toDouble());
        if (p >= 1 && !iSolved) _oppSolvedFirst();
      });
    }
    if (isOnline) {
      final opp = raceRoom![_oppSide] as Map?;
      if (opp?['u'] != null) oppName = '@${opp!['u']}';
      AccountService.instance.pinRoom(raceRoom!['id'], true);
      _roomSub =
          AccountService.instance.roomStream(raceRoom!['id']).listen(_onRoom);
    }
  }

  void disposeRace() {
    _ticker?.cancel();
    _botTimer?.cancel();
    _roomSub?.cancel();
    if (isOnline) {
      AccountService.instance.pinRoom(raceRoom!['id'], false);
      if (!raceOver) {
        AccountService.instance
            .roomWrite(raceRoom!['id'], 'state/left', _mySide);
      }
    }
  }

  void _onRoom(Map<String, dynamic>? r) {
    if (r == null || !mounted || raceOver) return;
    final st = r['state'] as Map?;
    final o = st?[_oppSide] as Map?;
    final p = (o?['prog'] as num?)?.toDouble() ?? 0;
    if (p != oppProgress) setState(() => oppProgress = p);
    if (o?['done'] != null && !iSolved) _oppSolvedFirst();
    if (st?['left'] == _oppSide) _resolve(won: true, forfeit: true);
  }

  /// Only meaningful in practice mode.
  void togglePause() {
    if (!isPractice || raceOver) return;
    setState(() {
      if (paused) {
        _pausedMs += DateTime.now().millisecondsSinceEpoch - (_pauseAt ?? 0);
        _pauseAt = null;
        paused = false;
      } else {
        _pauseAt = DateTime.now().millisecondsSinceEpoch;
        paused = true;
      }
    });
  }

  /// Adds a time penalty (hints etc.).
  void penalise(int seconds) => _startMs -= seconds * 1000;

  /// Report solve progress 0..1 (throttled online).
  void reportProgress(double p) {
    if (!isOnline || raceOver) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastProgWrite < 900) return;
    _lastProgWrite = now;
    AccountService.instance.roomWrite(raceRoom!['id'], 'state/$_mySide/prog',
        double.parse(p.toStringAsFixed(2)));
  }

  /// Call the moment the local player completes the puzzle.
  void solvedNow() {
    if (raceOver || iSolved) return;
    iSolved = true;
    if (isOnline) {
      AccountService.instance
          .roomWrite(raceRoom!['id'], 'state/$_mySide/prog', 1.0);
      AccountService.instance
          .roomWrite(raceRoom!['id'], 'state/$_mySide/done', elapsedS * 1000);
    }
    _resolve(won: true);
  }

  void _oppSolvedFirst() => _resolve(won: false);

  /// Stars for a practice clear — override per game (e.g. Hanoi rates
  /// by moves instead of time).
  int practiceStars() => MindDifficulty.stars(raceGame, raceLevel, elapsedS);

  /// The detail line under the stars — override per game.
  String practiceScoreLine(int stars) =>
      'Time $clock · under ${_fmtPar(MindDifficulty.parSeconds(raceGame, raceLevel))} = 3★';

  /// Call when the player FAILS a practice level (e.g. ran out of the
  /// guided move budget). Shows a lose dialog with TRY AGAIN. A little
  /// XP is still awarded for the attempt.
  void failedNow({String title = 'OUT OF MOVES!', String? line}) {
    if (raceOver) return;
    raceOver = true;
    _ticker?.cancel();
    _botTimer?.cancel();
    final a = AppData.i;
    a.addXp(3);
    a.bumpActivity();
    Fx.lose();
    onRaceFinished(false);
    _arenaScore?.call(0);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: DC.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.replay_circle_filled, size: 56, color: DC.danger),
            const SizedBox(height: 8),
            Text(title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displayMedium),
            const SizedBox(height: 6),
            if (line != null)
              Text(line,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: DC.dim, fontSize: 12)),
            Text('+3 XP for the attempt',
                style: TextStyle(color: DC.amber, fontSize: 12)),
            const SizedBox(height: 14),
            NeonButton(
              label: 'TRY AGAIN',
              icon: Icons.refresh,
              height: 46,
              colors: [DC.magenta, DC.violet],
              onPressed: () {
                Navigator.pop(context);
                onPlayAgain(raceLevel);
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

  void _resolve({required bool won, bool forfeit = false}) {
    if (raceOver) return;
    raceOver = true;
    _ticker?.cancel();
    _botTimer?.cancel();
    final a = AppData.i;
    var delta = 0;
    int stars = 0;
    var unlockedNext = false;
    if (isPractice) {
      stars = practiceStars();
      unlockedNext = a.recordMindLevel(
        raceGame,
        raceProgressStep,
        stars,
        maxLevel: raceMaxLevel,
      );
      final bandBonus = (raceDisplayRating - RatingCatalog.min) ~/ 100;
      a.addCoins(8 + stars * 6 + bandBonus);
      a.addXp(10 + stars * 8);
      if (unlockedNext) Fx.unlock();
    } else if (isOnline) {
      final opp = Map<String, dynamic>.from(raceRoom![_oppSide] as Map? ?? {});
      final oppElo = (opp['elo'] as num?)?.toInt() ?? 800;
      delta = a.applyElo(oppElo, won ? 1 : 0);
      a.recordMatch(
          mode: '$raceLabel online',
          opponent: oppName,
          result: won ? 'W' : 'L',
          delta: delta);
      a.addXp(won ? 15 : 4);
      AccountService.instance.updatePublicProfile();
    } else {
      final botElo = RatingCatalog.ratingForLegacyLevel(raceBotLevel!);
      delta = a.applyElo(botElo, won ? 1 : 0);
      a.recordMatch(
          mode: '$raceLabel vs bot $botElo',
          opponent: oppName,
          result: won ? 'W' : 'L',
          delta: delta);
      a.addXp(won ? 15 : 4);
    }
    a.bumpActivity();
    won ? Fx.win() : Fx.lose();
    onRaceFinished(won);
    _arenaScore?.call(won ? max(1, 100000 - elapsedS * 10) : 0);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: DC.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (won && (!isPractice || stars >= 2))
              const ConfettiBurst(height: 64),
            Icon(
                won
                    ? (isPractice ? Icons.stars : Icons.emoji_events)
                    : Icons.hourglass_bottom,
                size: 56,
                color: won ? DC.amber : DC.violet),
            const SizedBox(height: 8),
            Text(
                isPractice
                    ? '$raceDisplayRating CLEAR!'
                    : won
                        ? 'SOLVED FIRST! 🏆'
                        : forfeit
                            ? 'RIVAL LEFT'
                            : '$oppName SOLVED FIRST',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displayMedium),
            const SizedBox(height: 6),
            if (isPractice) ...[
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (var i = 0; i < 3; i++)
                  Icon(i < stars ? Icons.star : Icons.star_border,
                      size: 34, color: DC.amber),
              ]),
              const SizedBox(height: 4),
              Text(practiceScoreLine(stars),
                  style: TextStyle(color: DC.dim, fontSize: 12)),
              Text(
                  '+${8 + stars * 6 + (raceDisplayRating - RatingCatalog.min) ~/ 100} 🪙 · +${10 + stars * 8} XP',
                  style: TextStyle(color: DC.amber, fontSize: 13)),
            ] else ...[
              Text(
                  won ? 'Your time: $clock' : 'They beat you to it — $clock in',
                  style: TextStyle(color: DC.dim)),
              Text('${delta >= 0 ? '+' : ''}$delta rating',
                  style: TextStyle(
                      color: delta >= 0 ? DC.lime : DC.danger,
                      fontWeight: FontWeight.w900,
                      fontSize: 18)),
            ],
            const SizedBox(height: 14),
            if (isOnline)
              RematchButton(room: raceRoom!, amHost: raceAmHost)
            else if (isPractice)
              NeonButton(
                label: unlockedNext
                    ? 'NEXT VARIANT UNLOCKED'
                    : won && stars > 0
                        ? 'BACK TO RATINGS'
                        : 'TRY AGAIN',
                height: 46,
                colors: [DC.lime, DC.cyan],
                onPressed: () {
                  Navigator.pop(context);
                  if (won && stars > 0) {
                    Navigator.pop(context);
                  } else {
                    onPlayAgain(raceLevel);
                  }
                },
              )
            else if (isBot)
              NeonButton(
                label: 'REMATCH BOT ⚔',
                height: 46,
                colors: [DC.magenta, DC.violet],
                onPressed: () {
                  Navigator.pop(context);
                  onPlayAgain(raceLevel);
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

  String _fmtPar(int s) =>
      s >= 60 ? '${(s / 60).toStringAsFixed(s % 60 == 0 ? 0 : 1)}m' : '${s}s';

  /// Board can animate a win/lose state (confetti waves, dim-out…).
  void onRaceFinished(bool won) {}

  /// Practice "next level" / bot rematch — push a fresh screen.
  void onPlayAgain(int level) {}

  /// ---------------- shared HUD ----------------

  /// Top bar: close · (help) · timer · rival progress. Drop-in for every
  /// game screen so all five feel like one family.
  Widget raceHud(BuildContext context, {Widget? help, Color? accent}) {
    final ac = accent ?? DC.cyan;
    return Column(children: [
      Row(children: [
        Glass(
            radius: 16,
            padding: const EdgeInsets.all(8),
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.close, size: 18)),
        if (help != null) ...[const SizedBox(width: 8), help],
        const SizedBox(width: 10),
        Expanded(
          child: Glass(
            radius: 18,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(children: [
              Text(
                  isPractice
                      ? '$raceDisplayRating'
                      : isBot
                          ? 'BOT ${RatingCatalog.ratingForLegacyLevel(raceBotLevel!)}'
                          : 'ONLINE',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                      color: ac)),
              const Spacer(),
              Icon(Icons.timer, size: 15, color: DC.dim),
              Text(' $clock',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 15)),
            ]),
          ),
        ),
        if (isPractice) ...[
          const SizedBox(width: 8),
          Glass(
              radius: 16,
              padding: const EdgeInsets.all(8),
              onTap: togglePause,
              child: Icon(paused ? Icons.play_arrow : Icons.pause, size: 18)),
        ],
      ]),
      if (!isPractice) ...[
        const SizedBox(height: 8),
        Glass(
          radius: 16,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(children: [
            Icon(isBot ? Icons.smart_toy : Icons.person,
                size: 15, color: DC.magenta),
            const SizedBox(width: 8),
            Text(oppName,
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
            const SizedBox(width: 10),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: oppProgress),
                  duration: const Duration(milliseconds: 500),
                  builder: (_, v, __) => LinearProgressIndicator(
                    value: v,
                    minHeight: 6,
                    backgroundColor: DC.fg10,
                    color: DC.magenta,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text('${(oppProgress * 100).round()}%',
                style: TextStyle(
                    color: DC.magenta,
                    fontWeight: FontWeight.w900,
                    fontSize: 12)),
          ]),
        ),
      ],
    ]);
  }

  /// Full-screen pause curtain (practice only).
  Widget pauseCurtain() {
    if (!paused) return const SizedBox.shrink();
    return Positioned.fill(
      child: GestureDetector(
        onTap: togglePause,
        child: Container(
          color: DC.bg.withOpacity(0.94),
          alignment: Alignment.center,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.pause_circle, size: 70, color: DC.cyan),
            const SizedBox(height: 12),
            Text('PAUSED', style: Theme.of(context).textTheme.displayMedium),
            const SizedBox(height: 6),
            Text('Board hidden — no peeking!\nTap anywhere to resume.',
                textAlign: TextAlign.center,
                style: TextStyle(color: DC.dim, fontSize: 12)),
          ]),
        ),
      ),
    );
  }
}

const _mindBotNames = [
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

/// ---------------- rating select (800–2500 + game-aware variants) ----------------
class MindLevelSelect extends StatefulWidget {
  final String game, title;
  final Color accent;
  final String subtitle;
  final MindScreenBuilder builder;
  const MindLevelSelect({
    super.key,
    required this.game,
    required this.title,
    required this.accent,
    required this.subtitle,
    required this.builder,
  });

  @override
  State<MindLevelSelect> createState() => _MindLevelSelectState();
}

class _MindLevelSelectState extends State<MindLevelSelect> {
  @override
  Widget build(BuildContext context) {
    final a = AppData.i;
    final variants = RatingCatalog.variantsFor(widget.game);
    final total = RatedProgression.totalSteps(variants);
    final unlocked = a.mindLevel(widget.game).clamp(1, total).toInt();
    final suggested = RatedProgression.ratingForStep(
      unlocked,
      variantsPerRating: variants,
    );
    return Scaffold(
      body: ShaderBackground(
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Row(children: [
                Glass(
                    radius: 16,
                    padding: const EdgeInsets.all(8),
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back, size: 18)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(widget.title,
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                Pill(
                    icon: Icons.star,
                    label:
                        '${a.mindTotalStars(widget.game, maxLevel: total)}/${total * 3}',
                    color: DC.amber),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(widget.subtitle,
                    style: TextStyle(fontSize: 11, color: DC.dim)),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10),
                itemCount: RatingCatalog.bands.length,
                itemBuilder: (_, i) {
                  final rating = RatingCatalog.bands[i];
                  final firstStep = RatedProgression.stepFor(
                    rating,
                    1,
                    variantsPerRating: variants,
                  );
                  final open = firstStep <= unlocked;
                  var cleared = 0;
                  for (var variant = 1; variant <= variants; variant++) {
                    final step = RatedProgression.stepFor(
                      rating,
                      variant,
                      variantsPerRating: variants,
                    );
                    if (a.mindStarsAt(widget.game, step) > 0) cleared++;
                  }
                  final dailyCount = a.dailyArchive
                      .where((record) =>
                          record['category'] == widget.game &&
                          record['rating'] == rating)
                      .length;
                  return InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: open
                        ? () async {
                            Fx.tap();
                            final variant = await _pickRatingVariant(
                              context,
                              widget.game,
                              rating,
                              widget.accent,
                              unlocked: unlocked,
                            );
                            if (variant == null || !context.mounted) return;
                            final step = RatedProgression.stepFor(
                              rating,
                              variant,
                              variantsPerRating: variants,
                            );
                            final level = RatedProgression.engineLevelForStep(
                              step,
                              variantsPerRating: variants,
                            );
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => widget.builder(
                                  level: level,
                                  progressionStep: step,
                                  puzzleSeed: RatedProgression.seedForStep(
                                      widget.game, step),
                                  displayRating: rating,
                                ),
                              ),
                            );
                            if (mounted) setState(() {});
                          }
                        : () => Fx.error(),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: cleared > 0
                              ? [
                                  widget.accent.withOpacity(0.30),
                                  widget.accent.withOpacity(0.10)
                                ]
                              : open
                                  ? [DC.fgo(0.10), DC.fgo(0.04)]
                                  : [DC.fgo(0.035), DC.fgo(0.02)],
                        ),
                        border: Border.all(
                            color: rating == suggested
                                ? widget.accent
                                : DC.fgo(open ? 0.16 : 0.07)),
                      ),
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (open)
                              Text('$rating',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: DC.text))
                            else
                              Icon(Icons.lock_rounded,
                                  size: 18, color: DC.fg38),
                            const SizedBox(height: 2),
                            Text(
                                open
                                    ? '$cleared/$variants variants'
                                    : '$variants locked variants',
                                style: TextStyle(fontSize: 8, color: DC.dim)),
                            if (dailyCount > 0)
                              Text(
                                '+$dailyCount Daily',
                                style: TextStyle(
                                  fontSize: 8,
                                  color: DC.lime,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
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
}

Future<int?> _pickRatingVariant(
    BuildContext context, String game, int rating, Color accent,
    {required int unlocked}) {
  final count = RatingCatalog.variantsFor(game);
  final a = AppData.i;
  final dailyRecords = a.dailyArchive
      .where(
          (record) => record['category'] == game && record['rating'] == rating)
      .toList()
    ..sort((left, right) => ((right['completedAt'] as num?)?.toInt() ?? 0)
        .compareTo((left['completedAt'] as num?)?.toInt() ?? 0));
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: DC.bg2,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (c) => Padding(
      padding: const EdgeInsets.all(22),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('$rating · CHOOSE A VERSION',
            style: Theme.of(c).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text('$count fresh configurations at this rating',
            style: TextStyle(fontSize: 11, color: DC.dim)),
        const SizedBox(height: 14),
        SizedBox(
          height: min(280, ((count + 4) ~/ 5) * 56).toDouble(),
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5, mainAxisSpacing: 8, crossAxisSpacing: 8),
            itemCount: count,
            itemBuilder: (_, i) {
              final variant = i + 1;
              final step = RatedProgression.stepFor(
                rating,
                variant,
                variantsPerRating: count,
              );
              final open = step <= unlocked;
              final stars = a.mindStarsAt(game, step);
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: open ? () => Navigator.pop(c, variant) : null,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: open ? accent.withOpacity(0.12) : DC.fgo(0.025),
                    border: Border.all(
                        color: open ? accent.withOpacity(0.35) : DC.fgo(0.07)),
                  ),
                  alignment: Alignment.center,
                  child: !open
                      ? Icon(Icons.lock_rounded,
                          size: 16,
                          color: DC.fg38,
                          semanticLabel: 'Variant $variant locked')
                      : Stack(alignment: Alignment.center, children: [
                          Text('$variant',
                              style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: stars > 0 ? DC.lime : accent)),
                          if (stars > 0)
                            Positioned(
                              top: 2,
                              right: 4,
                              child: Icon(Icons.check_rounded,
                                  size: 10, color: DC.lime),
                            ),
                        ]),
                ),
              );
            },
          ),
        ),
        if (dailyRecords.isNotEmpty) ...[
          const SizedBox(height: 14),
          Row(children: [
            Icon(Icons.today_rounded, size: 17, color: DC.lime),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                'COMPLETED DAILY BOARDS · APPENDED HERE',
                style: TextStyle(
                  color: DC.lime,
                  fontSize: 10,
                  letterSpacing: 0.7,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          SizedBox(
            height: min(112, dailyRecords.length * 54).toDouble(),
            child: ListView.builder(
              itemCount: dailyRecords.length,
              itemBuilder: (_, index) {
                final record = dailyRecords[index];
                final item = dailyChallengeItemForArchive(record);
                final day = ((record['day'] as num?)?.toInt() ?? 0) + 1;
                return ListTile(
                  dense: true,
                  minTileHeight: 48,
                  contentPadding: EdgeInsets.zero,
                  leading:
                      Icon(Icons.replay_circle_filled_rounded, color: accent),
                  title: Text(
                    item.title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text('Daily day $day · reward-free replay'),
                  onTap: () {
                    Navigator.pop(c);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            DailyGameScreen(item: item, replay: true),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ]),
    ),
  );
}

/// ---------------- bot rating picker (800–2500) ----------------
Future<int?> pickMindBotLevel(BuildContext context, String label,
    {Color accent = const Color(0xFF38BDF8)}) {
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: DC.bg2,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (c) {
      final suggested = RatingCatalog.normalize(AppData.i.elo);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('BOT RATING · $label',
                style: Theme.of(c).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Choose the exact strength you want to face.',
                style: TextStyle(fontSize: 11, color: DC.dim)),
            const SizedBox(height: 14),
            SizedBox(
              height: 300,
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8),
                itemCount: RatingCatalog.bands.length,
                itemBuilder: (_, i) {
                  final lvl = RatingCatalog.bands[i];
                  final serious = lvl >= 1700;
                  return GestureDetector(
                    onTap: () {
                      Fx.tap();
                      Navigator.pop(c, lvl);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: serious
                            ? LinearGradient(colors: [
                                DC.magenta.withOpacity(0.22),
                                DC.violet.withOpacity(0.12)
                              ])
                            : LinearGradient(colors: [
                                accent.withOpacity(0.20),
                                accent.withOpacity(0.08)
                              ]),
                        border: Border.all(
                            color: lvl == suggested ? DC.amber : DC.fgo(0.14)),
                      ),
                      child: Stack(children: [
                        Center(
                            child: Text('$lvl',
                                style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                    color: DC.text))),
                        if (serious)
                          Positioned(
                              top: 3,
                              right: 4,
                              child: Text('🔥', style: TextStyle(fontSize: 9))),
                        if (lvl == suggested)
                          Positioned(
                              bottom: 2,
                              left: 0,
                              right: 0,
                              child: Text('FOR YOU',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 6,
                                      fontWeight: FontWeight.w900,
                                      color: DC.amber))),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ]),
        ),
      );
    },
  );
}

/// ---------------- compete sheet (bot / online / friend) ----------------
void mindCompeteSheet(
  BuildContext context, {
  required String game,
  required String label,
  required Color accent,
  required MindScreenBuilder builder,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: DC.bg2,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (c) => SafeArea(
      child: SingleChildScrollView(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom + 12),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('COMPETE · $label',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Same puzzle, live progress — first to solve wins.',
                style: TextStyle(fontSize: 11, color: DC.dim)),
            const SizedBox(height: 16),
            NeonButton(
              label: 'VS BOT',
              icon: Icons.smart_toy,
              onPressed: () async {
                Navigator.pop(c);
                final lvl =
                    await pickMindBotLevel(context, label, accent: accent);
                if (lvl == null || !context.mounted) return;
                final legacyLevel = RatingCatalog.legacyLevelForRating(lvl);
                startBotMatch(context,
                    label: label,
                    detail: 'Bot rating $lvl${lvl >= 1700 ? ' 🔥' : ''}',
                    game: () =>
                        builder(level: legacyLevel, botLevel: legacyLevel));
              },
            ),
            const SizedBox(height: 10),
            NeonButton(
              label: 'SEARCH ONLINE',
              icon: Icons.public,
              colors: [DC.magenta, DC.violet],
              onPressed: () {
                Navigator.pop(c);
                final fallbackLvl = RatingCatalog.legacyLevelForRating(
                    RatingCatalog.normalize(AppData.i.elo));
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => MatchmakingScreen(
                            game: game,
                            sub: 'std',
                            label: label,
                            botScreen: () => builder(
                                level: fallbackLvl, botLevel: fallbackLvl))));
              },
            ),
            const SizedBox(height: 10),
            GhostButton(
              label: 'PLAY A FRIEND',
              icon: Icons.group,
              onPressed: () {
                Navigator.pop(c);
                showFriendPlayDialog(context, game, 'std', label);
              },
            ),
          ]),
        ),
      ),
    ),
  );
}

/// Online engine difficulty for a room. Both sides derive it from the chosen
/// public rating range; older rooms fall back to their shared seed.
int mindOnlineLevel(Map<String, dynamic> room) {
  final lo = (room['ratingMin'] as num?)?.toInt();
  final hi = (room['ratingMax'] as num?)?.toInt();
  if (lo != null && hi != null) {
    return RatingCatalog.legacyLevelForRating((lo + hi) ~/ 2);
  }
  return 10 + (((room['seed'] as num?)?.toInt() ?? 7) % 16);
}

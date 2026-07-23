import 'dart:math';

import 'package:flutter/material.dart';

import '../core/fx.dart';
import '../core/state.dart';
import '../engine/game_progression.dart';
import '../engine/mind_engines.dart';
import '../engine/rating_catalog.dart';
import '../theme_district.dart';
import '../ui/game_tutorial.dart';
import '../ui/glass.dart';
import 'mind_games.dart';
import 'online_play.dart';

/// ============================================================
/// TOWER OF HANOI 🗼 — every valid rings×pegs combination
/// (3-8 rings on 3-5 pegs), distributed across shared rating bands.
/// Run out of the move budget → you lose (try again!). Rainbow
/// discs lift, hover and arc between wooden pegs. In races the
/// combo is picked (or random) and first to solve wins.
/// ============================================================

const _hanoiTutorial = [
  TutorialStep('Tap a peg — its top disc lifts into the air.',
      gesture: TutorialGesture.tap),
  TutorialStep('Tap another peg to drop it there.',
      gesture: TutorialGesture.tap),
  TutorialStep('A disc can never sit on a SMALLER disc.',
      gesture: TutorialGesture.none),
  TutorialStep('Rebuild the tower on the RIGHT peg — within the move budget!',
      gesture: TutorialGesture.none),
];

Widget hanoiBuilder(
        {int level = 1,
        int? botLevel,
        Map<String, dynamic>? room,
        bool amHost = true,
        int? progressionStep,
        int? puzzleSeed,
        int? displayRating}) =>
    HanoiScreen(
      level: level,
      botLevel: botLevel,
      room: room,
      amHost: amHost,
      progressionStep: progressionStep,
      puzzleSeed: puzzleSeed,
      displayRating: displayRating,
    );

class HanoiScreen extends StatefulWidget {
  final int level; // journey level 1..HanoiCombo.levelCount
  final int? botLevel;
  final Map<String, dynamic>? room;
  final bool amHost;
  final int? progressionStep;
  final int? puzzleSeed;
  final int? displayRating;

  /// Board for bot/race play; null = derive (from journey level, room sub,
  /// or randomly for a bot match).
  final HanoiCombo? combo;
  const HanoiScreen(
      {super.key,
      this.level = 1,
      this.botLevel,
      this.room,
      this.amHost = true,
      this.progressionStep,
      this.puzzleSeed,
      this.displayRating,
      this.combo});

  @override
  State<HanoiScreen> createState() => _HanoiScreenState();
}

class _HanoiScreenState extends State<HanoiScreen>
    with TickerProviderStateMixin, MindRace {
  late HanoiCombo combo;
  int tier = 0; // internal move-budget tier; UI uses rating bands
  int? budget; // max moves allowed (practice only)
  late HanoiGame game;
  int picked = -1; // peg index of lifted disc, -1 = none

  // hover bob for the lifted disc
  late final AnimationController _bob = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  // move animation — a touch slower so the arc reads nicely
  late final AnimationController _move = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 470));
  int? _animDisc, _animFrom, _animTo, _animFromH, _animToH;

  // illegal-drop shake
  late final AnimationController _deny = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 300));
  int _denyPeg = -1;

  @override
  void initState() {
    super.initState();
    if (widget.room != null) {
      final seed = (widget.room!['seed'] as num?)?.toInt() ?? 7;
      combo = HanoiCombo.fromSub(widget.room!['sub'] as String?) ??
          HanoiCombo.bySeed(seed);
    } else if (widget.botLevel != null) {
      combo = widget.combo ??
          HanoiCombo.all[Random().nextInt(HanoiCombo.all.length)];
    } else {
      final (c, t) = HanoiCombo.forLevel(widget.level);
      combo = c;
      tier = t;
      budget = c.budgetFor(t);
    }
    initRace(
        game: 'hanoi',
        label: 'Hanoi 🗼',
        level: widget.level,
        botLevel: widget.botLevel,
        room: widget.room,
        amHost: widget.amHost,
        maxLevel: HanoiCombo.levelCount,
        progressionStep: widget.progressionStep,
        progressMaxLevel:
            widget.progressionStep == null ? null : HanoiCombo.levelCount,
        displayRating: widget.displayRating,
        localSeed: widget.puzzleSeed,
        botPar: (combo.minMoves * 2.4).round() + 12);
    game = HanoiGame(combo.rings, pegCount: combo.pegCount);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        GameTutorial.showOnce(context,
            tutKey: 'hanoi', title: 'TOWER OF HANOI', steps: _hanoiTutorial);
      }
    });
  }

  @override
  void dispose() {
    disposeRace();
    _bob.dispose();
    _move.dispose();
    _deny.dispose();
    super.dispose();
  }

  // Practice stars rate the SOLVE by moves: perfect = 3★,
  // within +2 = 2★, within the budget = 1★.
  @override
  int practiceStars() {
    if (game.moves <= combo.minMoves) return 3;
    if (game.moves <= combo.minMoves + 2) return 2;
    return 1;
  }

  @override
  String practiceScoreLine(int stars) =>
      'Solved in ${game.moves} moves · perfect is ${combo.minMoves} · $clock';

  @override
  void onPlayAgain(int level) {
    Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => HanoiScreen(
                level: isBot ? widget.level : level,
                botLevel: isBot ? raceBotLevel : null,
                combo: isBot ? combo : null,
                progressionStep: widget.progressionStep,
                puzzleSeed: widget.puzzleSeed,
                displayRating: widget.displayRating)));
  }

  int get movesLeft => (budget ?? 999) - game.moves;

  void _tapPeg(int p) {
    if (raceOver || paused || _move.isAnimating) return;
    if (picked < 0) {
      if (game.pegs[p].isEmpty) {
        Fx.error();
        _denyPeg = p;
        _deny.forward(from: 0);
        return;
      }
      Fx.impact();
      setState(() => picked = p); // lift!
      return;
    }
    if (p == picked) {
      Fx.light();
      setState(() => picked = -1); // put back down
      return;
    }
    if (!game.canMove(picked, p)) {
      Fx.fail();
      _denyPeg = p;
      _deny.forward(from: 0);
      setState(() {});
      return;
    }
    // legal drop — animate the arc
    final from = picked;
    final disc = game.topOf(from)!;
    final fromH = game.pegs[from].length - 1;
    game.move(from, p);
    final toH = game.pegs[p].length - 1;
    setState(() {
      picked = -1;
      _animDisc = disc;
      _animFrom = from;
      _animTo = p;
      _animFromH = fromH;
      _animToH = toH;
    });
    Fx.tap();
    _move.forward(from: 0).whenComplete(() {
      if (!mounted) return;
      setState(() => _animDisc = null);
      Fx.light();
      reportProgress(game.progress);
      if (game.solved) {
        solvedNow();
      } else if (isPractice && budget != null && game.moves >= budget!) {
        failedNow(
            line:
                'The budget was $budget moves — perfect play needs ${combo.minMoves}.');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final lowMoves = isPractice && movesLeft <= 2;
    return Scaffold(
      body: ShaderBackground(
        child: SafeArea(
          child: Stack(children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                raceHud(context,
                    accent: DC.amber,
                    help: GameTutorial.helpButton(context,
                        title: 'TOWER OF HANOI', steps: _hanoiTutorial)),
                const SizedBox(height: 6),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Pill(
                      icon: Icons.tag,
                      label:
                          '${combo.rings}R × ${combo.pegCount}P${isPractice ? ' · L$tier' : ''}',
                      color: DC.violet),
                  const SizedBox(width: 8),
                  if (isPractice)
                    Pill(
                        icon: Icons.bolt,
                        label: '$movesLeft left',
                        color: lowMoves ? DC.danger : DC.cyan)
                  else
                    Pill(
                        icon: Icons.swap_horiz,
                        label: '${game.moves} moves',
                        color: DC.cyan),
                  const SizedBox(width: 8),
                  Pill(
                      icon: Icons.flag,
                      label: 'best ${combo.minMoves}',
                      color: DC.amber),
                ]),
                const Spacer(),
                Expanded(
                  flex: 10,
                  child: Tilt3D(
                    tilt: 0.05,
                    child: AnimatedBuilder(
                      animation: Listenable.merge([_bob, _move, _deny]),
                      builder: (_, __) => LayoutBuilder(
                        builder: (context, box) => GestureDetector(
                          onTapDown: (d) {
                            final p = (d.localPosition.dx /
                                    box.maxWidth *
                                    combo.pegCount)
                                .floor()
                                .clamp(0, combo.pegCount - 1)
                                .toInt();
                            _tapPeg(p);
                          },
                          child: CustomPaint(
                            size: Size(box.maxWidth, box.maxHeight),
                            painter: _HanoiPainter(
                              game: game,
                              picked: picked,
                              bob: _bob.value,
                              animDisc: _animDisc,
                              animFrom: _animFrom,
                              animTo: _animTo,
                              animFromH: _animFromH,
                              animToH: _animToH,
                              animT:
                                  Curves.easeInOutCubic.transform(_move.value),
                              denyPeg: _deny.isAnimating ? _denyPeg : -1,
                              denyT: _deny.value,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                    picked >= 0
                        ? 'Disc lifted — tap a peg to drop it'
                        : isPractice
                            ? 'Solve within $budget moves — no wasted taps!'
                            : 'Tap a peg to pick up its top disc',
                    style: TextStyle(fontSize: 11, color: DC.dim)),
                const SizedBox(height: 8),
              ]),
            ),
            pauseCurtain(),
          ]),
        ),
      ),
    );
  }
}

/// Pseudo-3D painter: wooden base + pegs, rainbow cylinder discs.
class _HanoiPainter extends CustomPainter {
  final HanoiGame game;
  final int picked;
  final double bob;
  final int? animDisc, animFrom, animTo, animFromH, animToH;
  final double animT;
  final int denyPeg;
  final double denyT;

  _HanoiPainter({
    required this.game,
    required this.picked,
    required this.bob,
    required this.animDisc,
    required this.animFrom,
    required this.animTo,
    required this.animFromH,
    required this.animToH,
    required this.animT,
    required this.denyPeg,
    required this.denyT,
  });

  /// Rainbow, smallest → largest: red → violet. 7 rings = full rainbow;
  /// fewer rings sample it evenly so the spread always reads rainbow.
  static const rainbow = [
    Color(0xFFFF3B30), // red
    Color(0xFFFF9500), // orange
    Color(0xFFFFD60A), // yellow
    Color(0xFF34C759), // green
    Color(0xFF0A84FF), // blue
    Color(0xFF5856D6), // indigo
    Color(0xFFBF5AF2), // violet
  ];

  Color _discColor(int d) {
    final n = game.discs;
    final idx = n <= 1 ? 0 : ((d - 1) * (rainbow.length - 1) / (n - 1)).round();
    return rainbow[idx.clamp(0, rainbow.length - 1).toInt()];
  }

  int get k => game.pegCount;

  double _pegX(Size s, int p) {
    var x = s.width * (2 * p + 1) / (2 * k);
    if (p == denyPeg) x += sin(denyT * pi * 4) * 5 * (1 - denyT);
    return x;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final baseY = h - 24;
    final n = game.discs;
    final discH = min(26.0, (h * 0.62) / (n + 1));
    final colW = w / k;
    final maxDiscW = colW * 0.92;
    final minDiscW = maxDiscW * (k >= 5 ? 0.42 : 0.34);
    final pegTop = baseY - discH * (n + 1) - 26;

    // ---- wooden base (3D slab) ----
    final baseRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.02, baseY, w * 0.96, 16), const Radius.circular(8));
    canvas.drawRRect(baseRect.shift(const Offset(0, 5)),
        Paint()..color = Colors.black.withOpacity(0.35)); // drop shadow
    canvas.drawRRect(
        baseRect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF9C6B3C), Color(0xFF5D3A1A)],
          ).createShader(baseRect.outerRect));
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.02, baseY, w * 0.96, 4),
            const Radius.circular(8)),
        Paint()..color = Colors.white.withOpacity(0.18));

    // ---- pegs ----
    for (var p = 0; p < k; p++) {
      final x = _pegX(size, p);
      final pegRect = RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(x, (pegTop + baseY) / 2),
              width: 10,
              height: baseY - pegTop),
          const Radius.circular(5));
      canvas.drawRRect(
          pegRect,
          Paint()
            ..shader = const LinearGradient(
              colors: [Color(0xFFB08050), Color(0xFF6B4423)],
            ).createShader(pegRect.outerRect));
      // peg cap
      canvas.drawOval(
          Rect.fromCenter(center: Offset(x, pegTop), width: 14, height: 8),
          Paint()..color = const Color(0xFFC49362));
      // target-peg glow
      if (p == game.target) {
        canvas.drawOval(
            Rect.fromCenter(
                center: Offset(x, baseY + 8), width: maxDiscW + 14, height: 14),
            Paint()
              ..color = const Color(0xFF69F0AE).withOpacity(0.14)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      }
    }

    double discW(int d) =>
        minDiscW + (maxDiscW - minDiscW) * (d - 1) / max(1, n - 1);

    void drawDisc(int d, Offset center, {double lift = 0}) {
      final dw = discW(d);
      final rect =
          Rect.fromCenter(center: center, width: dw, height: discH * 0.86);
      final rr = RRect.fromRectAndRadius(rect, Radius.circular(discH * 0.43));
      final color = _discColor(d);
      // shadow (stronger when lifted)
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(center.dx, center.dy + discH * 0.55 + lift),
              width: dw * (1 - lift / 260),
              height: 8),
          Paint()
            ..color = Colors.black.withOpacity(0.30 + lift / 400)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      // cylinder body
      canvas.drawRRect(
          rr,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.lerp(color, Colors.white, 0.35)!,
                color,
                Color.lerp(color, Colors.black, 0.35)!,
              ],
              stops: const [0, 0.45, 1],
            ).createShader(rect));
      // gloss stripe
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(rect.left + dw * 0.08,
                  rect.top + rect.height * 0.12, dw * 0.84, rect.height * 0.22),
              Radius.circular(rect.height * 0.11)),
          Paint()..color = Colors.white.withOpacity(0.34));
      // rim
      canvas.drawRRect(
          rr,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = Colors.black.withOpacity(0.25));
    }

    // ---- resting discs ----
    for (var p = 0; p < k; p++) {
      final x = _pegX(size, p);
      for (var i = 0; i < game.pegs[p].length; i++) {
        final d = game.pegs[p][i];
        // skip: lifted top disc & currently-animating disc at destination
        final isTop = i == game.pegs[p].length - 1;
        if (p == picked && isTop) continue;
        if (animDisc != null && p == animTo && d == animDisc) continue;
        drawDisc(d, Offset(x, baseY - discH * 0.5 - discH * i));
      }
    }

    // ---- lifted disc (hovers with a bob) ----
    if (picked >= 0 && game.pegs[picked].isNotEmpty) {
      final x = _pegX(size, picked);
      final d = game.pegs[picked].last;
      final y = pegTop - 26 - bob * 7;
      drawDisc(d, Offset(x, y), lift: 60);
    }

    // ---- animating disc: up → across → down arc ----
    if (animDisc != null) {
      final x0 = _pegX(size, animFrom!), x1 = _pegX(size, animTo!);
      final y0 = baseY - discH * 0.5 - discH * animFromH!;
      final y1 = baseY - discH * 0.5 - discH * animToH!;
      final hoverY = pegTop - 30;
      final t = animT;
      double x, y;
      if (t < 0.3) {
        x = x0;
        y = y0 + (hoverY - y0) * (t / 0.3);
      } else if (t < 0.7) {
        x = x0 + (x1 - x0) * ((t - 0.3) / 0.4);
        y = hoverY - sin((t - 0.3) / 0.4 * pi) * 10;
      } else {
        x = x1;
        y = hoverY + (y1 - hoverY) * ((t - 0.7) / 0.3);
      }
      drawDisc(animDisc!, Offset(x, y), lift: (1 - (t - 0.5).abs() * 2) * 50);
    }
  }

  @override
  bool shouldRepaint(covariant _HanoiPainter old) => true;
}

/// ============================================================
/// HANOI JOURNEY — every combo as a card with its three games.
/// ============================================================
class HanoiJourneyScreen extends StatefulWidget {
  const HanoiJourneyScreen({super.key});

  @override
  State<HanoiJourneyScreen> createState() => _HanoiJourneyScreenState();
}

class _HanoiJourneyScreenState extends State<HanoiJourneyScreen> {
  static const variantsPerRating = 5;

  @override
  Widget build(BuildContext context) {
    final a = AppData.i;
    final unlocked =
        a.mindLevel('hanoi').clamp(1, HanoiCombo.levelCount).toInt();
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
                  child: const Icon(Icons.arrow_back_rounded, size: 18),
                ),
                const SizedBox(width: 12),
                Icon(Icons.account_tree_rounded, color: DC.amber),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('HANOI RATINGS',
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                Pill(
                  icon: Icons.star_rounded,
                  label:
                      '${a.mindTotalStars('hanoi', maxLevel: HanoiCombo.levelCount)}/${HanoiCombo.levelCount * 3}',
                  color: DC.amber,
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Five unique ring, peg and move-budget challenges per rating. Complete each to unlock the next.',
                  style: TextStyle(fontSize: 11, color: DC.dim),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                itemCount: RatingCatalog.bands.length,
                itemBuilder: (_, band) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ratingCard(a, band, unlocked),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _ratingCard(AppData a, int band, int unlocked) {
    final rating = RatingCatalog.bands[band];
    final firstStep = band * variantsPerRating + 1;
    final bandOpen = firstStep <= unlocked;
    final cleared = [
      for (var v = 0; v < variantsPerRating; v++)
        if (a.mindStarsAt('hanoi', firstStep + v) > 0) v,
    ].length;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: bandOpen
            ? LinearGradient(colors: [
                DC.band(rating).withOpacity(0.16),
                DC.fgo(0.035),
              ])
            : null,
        color: bandOpen ? null : DC.fgo(0.02),
        border: Border.all(
          color: firstStep <= unlocked && unlocked < firstStep + 5
              ? DC.amber
              : DC.fgo(bandOpen ? 0.18 : 0.07),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              color: DC.band(rating).withOpacity(bandOpen ? 0.16 : 0.05),
            ),
            alignment: Alignment.center,
            child: bandOpen
                ? Text('$rating',
                    style: TextStyle(
                        color: DC.band(rating),
                        fontWeight: FontWeight.w900,
                        fontSize: 12))
                : Icon(Icons.lock_rounded, color: DC.fg38, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bandOpen ? '$rating RATING' : 'LOCKED RATING',
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: bandOpen ? DC.text : DC.dim)),
                Text('$cleared/$variantsPerRating configurations cleared',
                    style: TextStyle(fontSize: 11, color: DC.dim)),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: variantsPerRating,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.25,
          ),
          itemBuilder: (_, index) {
            final step = firstStep + index;
            final (combo, tier) = HanoiCombo.forLevel(step);
            return _variantButton(
              a,
              step: step,
              variant: index + 1,
              rating: rating,
              combo: combo,
              tier: tier,
              unlocked: unlocked,
            );
          },
        ),
      ]),
    );
  }

  Widget _variantButton(
    AppData a, {
    required int step,
    required int variant,
    required int rating,
    required HanoiCombo combo,
    required int tier,
    required int unlocked,
  }) {
    final open = SequentialProgression.canPlay(step, unlocked);
    final stars = a.mindStarsAt('hanoi', step);
    return Semantics(
      button: true,
      enabled: open,
      label: open
          ? 'Hanoi $rating variant $variant, ${combo.rings} rings and ${combo.pegCount} pegs'
          : 'Hanoi $rating variant $variant locked',
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: open
            ? () async {
                Fx.tap();
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HanoiScreen(
                      level: step,
                      progressionStep: step,
                      displayRating: rating,
                      puzzleSeed: RatedProgression.seedForStep('hanoi', step),
                    ),
                  ),
                );
                if (mounted) setState(() {});
              }
            : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: open ? DC.fgo(0.055) : DC.fgo(0.02),
            border: Border.all(
              color: step == unlocked ? DC.amber : DC.fgo(open ? 0.14 : 0.05),
            ),
          ),
          child: open
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text('V$variant · ${combo.rings}R × ${combo.pegCount}P',
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w900)),
                      const Spacer(),
                      if (stars > 0)
                        Icon(Icons.check_circle_rounded,
                            size: 14, color: DC.lime),
                    ]),
                    Text(
                        '≤${combo.budgetFor(tier)} moves · perfect ${combo.minMoves}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 9, color: DC.dim)),
                  ],
                )
              : Center(
                  child: Icon(Icons.lock_rounded, size: 16, color: DC.fg38),
                ),
        ),
      ),
    );
  }
}

/// ============================================================
/// COMPETE — bot / online / friend, with a combo picker
/// (specific rings×pegs, or random) shared by all three paths.
/// ============================================================

/// Pick a board: returns (sub, combo) — ('rnd', null) for random,
/// null if dismissed.
Future<(String, HanoiCombo?)?> pickHanoiCombo(BuildContext context) {
  return showModalBottomSheet<(String, HanoiCombo?)>(
    context: context,
    backgroundColor: DC.bg2,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('PICK YOUR BOARD · Hanoi 🗼',
              style: Theme.of(c).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('Both players get the same board — first to solve wins.',
              style: TextStyle(fontSize: 11, color: DC.dim)),
          const SizedBox(height: 14),
          NeonButton(
            label: '🎲 RANDOM BOARD',
            height: 46,
            colors: [DC.violet, DC.cyan],
            onPressed: () => Navigator.pop(c, ('rnd', null)),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 320,
            child: ListView(children: [
              for (final combo in HanoiCombo.all)
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Glass(
                    radius: 14,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    onTap: () => Navigator.pop(c, (combo.sub, combo)),
                    child: Row(children: [
                      Text(combo.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 13)),
                      const Spacer(),
                      Text(
                          '${combo.minMoves} moves · ~${((combo.minMoves * 2.4 + 12) / 60).ceil()} min',
                          style: TextStyle(fontSize: 11, color: DC.dim)),
                    ]),
                  ),
                ),
            ]),
          ),
        ]),
      ),
    ),
  );
}

void hanoiCompeteSheet(BuildContext context) {
  const label = 'Hanoi 🗼';
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
            Text('Pick rings × pegs (or random) — first to solve wins.',
                style: TextStyle(fontSize: 11, color: DC.dim)),
            const SizedBox(height: 16),
            NeonButton(
              label: 'VS BOT',
              icon: Icons.smart_toy,
              onPressed: () async {
                Navigator.pop(c);
                final rating = await pickMindBotLevel(context, label,
                    accent: const Color(0xFFFFC400));
                if (rating == null || !context.mounted) return;
                final lvl = RatingCatalog.legacyLevelForRating(rating);
                final pick = await pickHanoiCombo(context);
                if (pick == null || !context.mounted) return;
                final combo = pick.$2 ??
                    HanoiCombo.all[Random().nextInt(HanoiCombo.all.length)];
                startBotMatch(context,
                    label: label,
                    detail:
                        'Bot $rating${rating >= 1700 ? ' 🔥' : ''} · ${combo.title}',
                    game: () => HanoiScreen(botLevel: lvl, combo: combo));
              },
            ),
            const SizedBox(height: 10),
            NeonButton(
              label: 'SEARCH ONLINE',
              icon: Icons.public,
              colors: [DC.magenta, DC.violet],
              onPressed: () async {
                Navigator.pop(c);
                final pick = await pickHanoiCombo(context);
                if (pick == null || !context.mounted) return;
                final fallbackLvl = RatingCatalog.legacyLevelForRating(
                    RatingCatalog.normalize(AppData.i.elo));
                final fallbackCombo = pick.$2 ??
                    HanoiCombo.all[Random().nextInt(HanoiCombo.all.length)];
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => MatchmakingScreen(
                            game: 'hanoi',
                            sub: pick.$1,
                            label: label,
                            botScreen: () => HanoiScreen(
                                botLevel: fallbackLvl, combo: fallbackCombo))));
              },
            ),
            const SizedBox(height: 10),
            GhostButton(
              label: 'PLAY A FRIEND',
              icon: Icons.group,
              onPressed: () async {
                Navigator.pop(c);
                final pick = await pickHanoiCombo(context);
                if (pick == null || !context.mounted) return;
                showFriendPlayDialog(context, 'hanoi', pick.$1, label);
              },
            ),
          ]),
        ),
      ),
    ),
  );
}

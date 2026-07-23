import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../core/fx.dart';
import '../core/state.dart';
import '../daily_challenge/daily_bank.dart';
import '../daily_challenge/daily_game_screen.dart';
import '../engine/game_progression.dart';
import '../engine/rating_catalog.dart';
import '../services/account_service.dart';
import '../theme_district.dart';
import '../ui/extras.dart';
import '../ui/game_tutorial.dart';
import '../ui/glass.dart';
import 'online_play.dart';

/// Level-0 "how to play" for Art Heist.
const _artTutorial = [
  TutorialStep(
      'The full artwork is shown small at the top — that\'s your target.',
      gesture: TutorialGesture.sequence),
  TutorialStep('Tap one tile, then tap another to swap their places.',
      gesture: TutorialGesture.tap),
  TutorialStep('Rebuild the picture in as few moves as you can to win!',
      gesture: TutorialGesture.none),
];

/// ============================================================
/// ART HEIST 🖼 — a procedurally-painted neon artwork is sliced
/// into tiles and jumbled; tap two tiles to swap until the piece
/// is restored. Solo (par moves → stars) or online race on the
/// identical artwork — first to restore it wins (atomic claim).
/// ============================================================
class ArtRaceScreen extends StatefulWidget {
  final Map<String, dynamic>? room;
  final bool amHost;
  final int size; // solo board size (3/4/5)
  /// When set (1..180) this is a rated Journey run with a stable artwork.
  final int? journeyLevel;
  final int? puzzleSeed;
  final ValueChanged<int>? arenaScore;
  const ArtRaceScreen(
      {super.key,
      this.room,
      this.amHost = true,
      this.size = 3,
      this.journeyLevel,
      this.puzzleSeed,
      this.arenaScore});

  @override
  State<ArtRaceScreen> createState() => _ArtRaceScreenState();
}

class _ArtRaceScreenState extends State<ArtRaceScreen> {
  late int n;
  late int seed;
  late List<int> perm; // tile at slot i shows piece perm[i]
  late int par;
  int? selA;
  int moves = 0;
  bool finished = false;
  bool _unlockedNext = false;
  final watch = Stopwatch()..start();

  bool get isOnline => widget.room != null;
  late final String mySide = widget.amHost ? 'host' : 'guest';
  late final String oppSide = widget.amHost ? 'guest' : 'host';
  StreamSubscription? sub;
  int oppMoves = 0;

  @override
  void initState() {
    super.initState();
    if (isOnline) {
      seed = (widget.room!['seed'] as num?)?.toInt() ?? 5;
      n = int.tryParse('${widget.room!['sub']}') ?? 3;
      AccountService.instance.pinRoom(widget.room!['id'], true);
      sub = AccountService.instance
          .roomStream(widget.room!['id'])
          .listen(_onRoom);
    } else {
      seed = widget.journeyLevel != null
          ? ArtHeistCatalog.seedForStep(widget.journeyLevel!)
          : widget.puzzleSeed ?? Random().nextInt(1 << 31);
      n = widget.journeyLevel != null
          ? AppData.artGridForLevel(widget.journeyLevel!)
          : widget.size;
    }
    final rng = Random(seed);
    perm = List.generate(n * n, (i) => i);
    do {
      perm.shuffle(rng);
    } while (_solved); // never start solved
    par = _minimumSwapsToSolve(perm);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        GameTutorial.showOnce(context,
            tutKey: 'art', title: 'ART HEIST', steps: _artTutorial);
      }
    });
  }

  @override
  void dispose() {
    sub?.cancel();
    if (isOnline) {
      AccountService.instance.pinRoom(widget.room!['id'], false);
      if (!finished) {
        AccountService.instance
            .roomWrite(widget.room!['id'], 'state/left', mySide);
      }
    }
    super.dispose();
  }

  bool get _solved {
    for (var i = 0; i < perm.length; i++) {
      if (perm[i] != i) return false;
    }
    return true;
  }

  int _minimumSwapsToSolve(List<int> values) {
    final visited = List<bool>.filled(values.length, false);
    var cycles = 0;
    for (var start = 0; start < values.length; start++) {
      if (visited[start]) continue;
      cycles++;
      var at = start;
      while (!visited[at]) {
        visited[at] = true;
        at = values[at];
      }
    }
    return values.length - cycles;
  }

  void _onRoom(Map<String, dynamic>? r) {
    if (r == null || finished || !mounted) return;
    final st = r['state'] as Map?;
    final o = st?[oppSide] as Map?;
    final m = (o?['moves'] as num?)?.toInt() ?? 0;
    if (m != oppMoves) setState(() => oppMoves = m);
    final w = st?['winner'];
    if (w == oppSide) _finish(false);
    if (st?['left'] == oppSide) _finish(true, forfeit: true);
  }

  void _tap(int i) {
    if (finished) return;
    if (selA == null) {
      Fx.tap();
      setState(() => selA = i);
      return;
    }
    if (selA == i) {
      setState(() => selA = null);
      return;
    }
    Fx.impact();
    setState(() {
      final t = perm[selA!];
      perm[selA!] = perm[i];
      perm[i] = t;
      selA = null;
      moves++;
    });
    if (isOnline) {
      AccountService.instance
          .roomWrite(widget.room!['id'], 'state/$mySide/moves', moves);
    }
    if (_solved) {
      if (isOnline) {
        AccountService.instance
            .claimRoomWin(widget.room!['id'], mySide)
            .then((won) {
          if (mounted && !finished) _finish(won);
        });
      } else {
        _finish(true);
      }
    }
  }

  void _finish(bool won, {bool forfeit = false}) {
    if (finished) return;
    finished = true;
    watch.stop();
    final a = AppData.i;
    var delta = 0;
    var stars = 0;
    if (isOnline) {
      final opp = Map<String, dynamic>.from(widget.room![oppSide] as Map);
      delta = a.applyElo((opp['elo'] as num?)?.toInt() ?? 800, won ? 1 : 0);
      a.recordMatch(
          mode: 'Art Heist 🖼 online',
          opponent: '@${opp['u']}',
          result: won ? 'W' : 'L',
          delta: delta);
    } else {
      stars = moves <= par
          ? 3
          : moves <= par + max(2, n - 2)
              ? 2
              : 1;
      a.addCoins(20 * n * stars);
      a.addXp(10 * n * stars);
      if (widget.journeyLevel != null) {
        _unlockedNext = a.recordArtJourney(widget.journeyLevel!, stars);
      } else {
        a.recordTrainingSession('art',
            value: stars / 3, durationMs: watch.elapsedMilliseconds);
      }
    }
    if (won) Fx.win();
    widget.arenaScore?.call(won
        ? max(1, 100000 - watch.elapsedMilliseconds ~/ 10 - moves * 100)
        : 0);
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
            if (won) const ConfettiBurst(height: 60),
            Text(
                isOnline
                    ? (won
                        ? (forfeit ? 'RIVAL FLED 🖼' : 'MASTERPIECE! 🏆')
                        : 'OUT-ARTED')
                    : 'RESTORED! 🖼',
                style: Theme.of(context).textTheme.displayMedium),
            const SizedBox(height: 6),
            Text(
                '$moves moves · ${(watch.elapsedMilliseconds / 1000).toStringAsFixed(1)}s',
                style: TextStyle(color: DC.dim)),
            if (isOnline)
              Text('${delta >= 0 ? '+' : ''}$delta rating',
                  style: TextStyle(
                      color: delta >= 0 ? DC.lime : DC.danger,
                      fontWeight: FontWeight.w900,
                      fontSize: 18))
            else
              Row(mainAxisSize: MainAxisSize.min, children: [
                for (var s = 0; s < 3; s++)
                  Icon(Icons.star_rounded,
                      color: s < stars ? DC.amber : DC.fg12),
              ]),
            if (widget.journeyLevel != null && _unlockedNext)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                    '${ArtHeistCatalog.ratingForStep(widget.journeyLevel! + 1)} · variant ${ArtHeistCatalog.variantForStep(widget.journeyLevel! + 1)} unlocked!',
                    style:
                        TextStyle(color: DC.lime, fontWeight: FontWeight.w800)),
              ),
            const SizedBox(height: 14),
            if (isOnline)
              RematchButton(room: widget.room!, amHost: widget.amHost)
            else if (widget.journeyLevel == null)
              NeonButton(
                label: 'PLAY AGAIN',
                icon: Icons.refresh,
                height: 46,
                colors: [DC.magenta, DC.violet],
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ArtRaceScreen(size: widget.size)));
                },
              ),
            if (widget.journeyLevel == null) const SizedBox(height: 8),
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
    return Scaffold(
      body: ShaderBackground(
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Row(children: [
                Glass(
                    radius: 16,
                    padding: const EdgeInsets.all(8),
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, size: 18)),
                const SizedBox(width: 8),
                GameTutorial.helpButton(context,
                    title: 'ART HEIST', steps: _artTutorial),
                const SizedBox(width: 12),
                Text('ART HEIST 🖼',
                    style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                Text(
                    isOnline
                        ? 'you $moves · rival $oppMoves'
                        : '$moves / par $par',
                    style: TextStyle(fontSize: 12, color: DC.dim)),
              ]),
            ),
            Text('Tap two tiles to swap — restore the artwork',
                style: TextStyle(fontSize: 11, color: DC.dim)),
            const SizedBox(height: 8),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: LayoutBuilder(builder: (context, box) {
                      final side = box.maxWidth;
                      final cell = side / n;
                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: DC.fgo(0.15)),
                          boxShadow: const [
                            BoxShadow(color: Colors.black54, blurRadius: 20)
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Column(children: [
                            for (var r = 0; r < n; r++)
                              Expanded(
                                child: Row(children: [
                                  for (var c = 0; c < n; c++)
                                    _tile(r * n + c, cell, side),
                                ]),
                              ),
                          ]),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
            // mini preview of the target
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(children: [
                Text('TARGET',
                    style: TextStyle(
                        fontSize: 9, letterSpacing: 2, color: DC.dim)),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 84,
                    height: 84,
                    child:
                        CustomPaint(painter: ArtPainter(seed, Size.square(84))),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _tile(int slot, double cell, double full) {
    final piece = perm[slot];
    final sel = selA == slot;
    final correct = piece == slot;
    return Expanded(
      child: GestureDetector(
        onTap: () => _tap(slot),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: EdgeInsets.all(sel ? 3 : 0.7),
          decoration: BoxDecoration(
            border: sel
                ? Border.all(color: DC.cyan, width: 2.5)
                : correct
                    ? Border.all(color: DC.lime.withOpacity(0.35), width: 1)
                    : null,
          ),
          child: ClipRect(
            child: CustomPaint(
              painter: _TilePainter(seed, piece, n, Size.square(full)),
              size: Size.square(cell),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints one tile: the full artwork translated so the tile's slice shows.
class _TilePainter extends CustomPainter {
  final int seed, piece, n;
  final Size full;
  _TilePainter(this.seed, this.piece, this.n, this.full);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width * n / full.width;
    final ox = (piece % n) * full.width / n;
    final oy = (piece ~/ n) * full.height / n;
    canvas.scale(scale);
    canvas.translate(-ox, -oy);
    ArtPainter(seed, full).paint(canvas, full);
  }

  @override
  bool shouldRepaint(covariant _TilePainter old) =>
      old.piece != piece || old.seed != seed;
}

/// Deterministic neon generative artwork — same seed, same painting,
/// on every phone (that's what makes online races fair).
class ArtPainter extends CustomPainter {
  final int seed;
  final Size full;
  ArtPainter(this.seed, this.full);

  static List<Color> get _palette => [
        DC.cyan,
        DC.violet,
        DC.magenta,
        DC.amber,
        DC.lime,
        const Color(0xFFFF8A65),
        const Color(0xFF80D8FF),
      ];

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(seed);
    final w = size.width, h = size.height;
    // deep space base
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: const [Color(0xFF0B0B16), Color(0xFF1A0E2E)])
              .createShader(Offset.zero & size));
    // glowing orbs
    for (var i = 0; i < 5; i++) {
      final c = _palette[rng.nextInt(_palette.length)];
      final center = Offset(rng.nextDouble() * w, rng.nextDouble() * h);
      final rad = (0.12 + rng.nextDouble() * 0.22) * w;
      canvas.drawCircle(
          center,
          rad,
          Paint()
            ..shader = RadialGradient(
                    colors: [c.withOpacity(0.85), c.withOpacity(0)])
                .createShader(Rect.fromCircle(center: center, radius: rad)));
    }
    // sweeping arcs
    for (var i = 0; i < 6; i++) {
      final c = _palette[rng.nextInt(_palette.length)];
      final rect = Rect.fromCircle(
          center: Offset(rng.nextDouble() * w, rng.nextDouble() * h),
          radius: (0.15 + rng.nextDouble() * 0.4) * w);
      canvas.drawArc(
          rect,
          rng.nextDouble() * pi * 2,
          pi * (0.5 + rng.nextDouble()),
          false,
          Paint()
            ..color = c
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = 2 + rng.nextDouble() * 6);
    }
    // constellation dots + links
    Offset? prev;
    for (var i = 0; i < 9; i++) {
      final p = Offset(rng.nextDouble() * w, rng.nextDouble() * h);
      canvas.drawCircle(p, 2.5 + rng.nextDouble() * 3,
          Paint()..color = Colors.white.withOpacity(0.9));
      if (prev != null && rng.nextBool()) {
        canvas.drawLine(
            prev,
            p,
            Paint()
              ..color = DC.fgo(0.25)
              ..strokeWidth = 1);
      }
      prev = p;
    }
  }

  @override
  bool shouldRepaint(covariant ArtPainter old) => old.seed != seed;
}

/// ============================================================
/// ART HEIST RATINGS — 18 rating bands with ten deterministic artworks each.
/// ============================================================
class ArtHeistJourneyScreen extends StatefulWidget {
  const ArtHeistJourneyScreen({super.key});

  @override
  State<ArtHeistJourneyScreen> createState() => _ArtHeistJourneyScreenState();
}

class _ArtHeistJourneyScreenState extends State<ArtHeistJourneyScreen> {
  @override
  Widget build(BuildContext context) {
    final a = AppData.i;
    final unlocked = a.artLevel.clamp(1, ArtHeistCatalog.totalSteps).toInt();
    final totalStars =
        a.artStars.values.fold<int>(0, (sum, value) => sum + (value as int));
    return Scaffold(
      body: ShaderBackground(
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Row(children: [
                Glass(
                    radius: 16,
                    padding: const EdgeInsets.all(8),
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_rounded, size: 18)),
                const SizedBox(width: 12),
                Icon(Icons.image_search_rounded, color: DC.cyan),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('ART HEIST RATINGS',
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                Pill(
                    icon: Icons.star_rounded,
                    label: '$totalStars/${ArtHeistCatalog.totalSteps * 3}',
                    color: DC.amber),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Ten fresh artworks per rating. Restore one to unlock the next variant.',
                  style: TextStyle(fontSize: 11, color: DC.dim),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
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
    final first = ArtHeistCatalog.stepFor(rating, 1);
    final bandOpen = first <= unlocked;
    final cleared = [
      for (var variant = 1;
          variant <= ArtHeistCatalog.variantsPerRating;
          variant++)
        if (a.artStarsAt(ArtHeistCatalog.stepFor(rating, variant)) > 0) variant,
    ].length;
    final grid = ArtHeistCatalog.gridForStep(first);
    final dailyRecords = a.dailyArchive
        .where((record) =>
            record['category'] == 'art' && record['rating'] == rating)
        .toList()
      ..sort((left, right) => ((right['completedAt'] as num?)?.toInt() ?? 0)
          .compareTo((left['completedAt'] as num?)?.toInt() ?? 0));
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: bandOpen
            ? LinearGradient(colors: [
                DC.band(rating).withOpacity(0.16),
                DC.violet.withOpacity(0.05),
              ])
            : null,
        color: bandOpen ? null : DC.fgo(0.02),
        border: Border.all(
          color: first <= unlocked &&
                  unlocked < first + ArtHeistCatalog.variantsPerRating
              ? DC.cyan
              : DC.fgo(bandOpen ? 0.16 : 0.06),
        ),
      ),
      child: Column(children: [
        Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              color: DC.band(rating).withOpacity(bandOpen ? 0.16 : 0.04),
            ),
            alignment: Alignment.center,
            child: bandOpen
                ? Text('$rating',
                    style: TextStyle(
                        color: DC.band(rating),
                        fontSize: 12,
                        fontWeight: FontWeight.w900))
                : Icon(Icons.lock_rounded, color: DC.fg38, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bandOpen ? '$rating · $grid×$grid ARTWORKS' : 'LOCKED',
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: bandOpen ? DC.text : DC.dim)),
                Text('$cleared/${ArtHeistCatalog.variantsPerRating} restored',
                    style: TextStyle(fontSize: 11, color: DC.dim)),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: ArtHeistCatalog.variantsPerRating,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.05,
          ),
          itemBuilder: (_, i) {
            final variant = i + 1;
            final step = ArtHeistCatalog.stepFor(rating, variant);
            final open = SequentialProgression.canPlay(step, unlocked);
            final stars = a.artStarsAt(step);
            return Semantics(
              button: true,
              enabled: open,
              label: open
                  ? 'Art Heist $rating variant $variant'
                  : 'Art Heist $rating variant $variant locked',
              child: InkWell(
                borderRadius: BorderRadius.circular(13),
                onTap: open
                    ? () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ArtRaceScreen(journeyLevel: step),
                          ),
                        ).then((_) => setState(() {}))
                    : null,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(13),
                    color: open ? DC.fgo(0.055) : DC.fgo(0.02),
                    border: Border.all(
                      color: step == unlocked
                          ? DC.cyan
                          : DC.fgo(open ? 0.13 : 0.05),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: !open
                      ? Icon(Icons.lock_rounded, size: 15, color: DC.fg38)
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('$variant',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900)),
                            if (stars > 0)
                              Icon(Icons.check_rounded,
                                  size: 13, color: DC.lime),
                          ],
                        ),
                ),
              ),
            );
          },
        ),
        if (dailyRecords.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(children: [
            Icon(Icons.today_rounded, size: 16, color: DC.lime),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                'COMPLETED DAILY ART · APPENDED HERE',
                style: TextStyle(
                  color: DC.lime,
                  fontSize: 10,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final record in dailyRecords)
                Builder(builder: (context) {
                  final item = dailyChallengeItemForArchive(record);
                  final day = ((record['day'] as num?)?.toInt() ?? 0) + 1;
                  return ActionChip(
                    avatar: Icon(Icons.replay_rounded,
                        size: 16, color: DC.band(rating)),
                    label: Text('Daily $day'),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            DailyGameScreen(item: item, replay: true),
                      ),
                    ).then((_) {
                      if (mounted) setState(() {});
                    }),
                  );
                }),
            ],
          ),
        ],
      ]),
    );
  }
}

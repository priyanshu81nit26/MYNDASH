import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../core/fx.dart';
import '../core/state.dart';
import '../engine/game_progression.dart';
import '../engine/rating_catalog.dart';
import '../engine/word_grid.dart';
import '../engine/wordlist.dart';
import '../services/account_service.dart';
import '../theme_district.dart';
import '../ui/extras.dart';
import '../ui/game_tutorial.dart';
import '../ui/glass.dart';
import 'online_play.dart';

/// Level-0 "how to play" for Word Finder.
const _wfTutorial = [
  TutorialStep('Drag your finger across touching letters to spell a word.',
      gesture: TutorialGesture.dragAcross),
  TutorialStep('Letters must be neighbours — sideways, up/down or diagonal.',
      gesture: TutorialGesture.dragAcross),
  TutorialStep(
      'Lift your finger to submit. 3+ letters score — longer = way more!',
      gesture: TutorialGesture.dragAcross),
];

/// ============================================================
/// WORD FINDER 🔤 — rated 4×4 to 6×6 Boggle-style boards with a guaranteed
/// core of playable words. DRAG across adjacent letters and release to submit.
/// Solo (high score) or online race: identical grid, both hunt,
/// higher score wins. Live rival score syncs through the room.
/// ============================================================
class WordFinderScreen extends StatefulWidget {
  final Map<String, dynamic>? room;
  final bool amHost;
  final int? journeyStep;
  final int? rating;
  final int? seedOverride;
  const WordFinderScreen({
    super.key,
    this.room,
    this.amHost = true,
    this.journeyStep,
    this.rating,
    this.seedOverride,
  });

  @override
  State<WordFinderScreen> createState() => _WordFinderScreenState();
}

class _WordFinderScreenState extends State<WordFinderScreen> {
  late int gridN;
  late int gameMs;
  late int gameRating;
  late WordGridSpec gridSpec;
  late List<String> grid;
  final found = <String>[];
  final path = <int>[]; // current selection (grid indexes)
  int score = 0;
  int combo = 1;
  int lastFoundMs = -99999;
  late final int startMs = DateTime.now().millisecondsSinceEpoch;
  Timer? ticker;
  bool finished = false;
  String flash = '';
  int hintsUsed = 0;
  bool unlockedNext = false;

  // online
  bool get isOnline => widget.room != null;
  late final String mySide = widget.amHost ? 'host' : 'guest';
  late final String oppSide = widget.amHost ? 'guest' : 'host';
  StreamSubscription? sub;
  int oppScore = 0;
  int? oppFinal;
  int? myFinal;

  @override
  void initState() {
    super.initState();
    final roomMin = (widget.room?['ratingMin'] as num?)?.toInt();
    final roomMax = (widget.room?['ratingMax'] as num?)?.toInt();
    gameRating = widget.journeyStep != null
        ? WordFinderCatalog.ratingForStep(widget.journeyStep!)
        : widget.rating ??
            (roomMin != null && roomMax != null
                ? RatingCatalog.normalize((roomMin + roomMax) ~/ 2)
                : RatingCatalog.normalize(AppData.i.elo));
    final seed = isOnline
        ? ((widget.room!['seed'] as num?)?.toInt() ?? 7)
        : widget.seedOverride ??
            (widget.journeyStep != null
                ? WordFinderCatalog.seedForStep(widget.journeyStep!)
                : Random().nextInt(1 << 31));
    gridN = WordFinderCatalog.gridForRating(gameRating);
    gameMs = WordFinderCatalog.durationMs(gameRating);
    gridSpec = WordGridGenerator.generate(
      size: gridN,
      seed: seed,
      minimumWords: WordFinderCatalog.embeddedWordTarget(gameRating),
    );
    grid = List<String>.from(gridSpec.letters);
    if (isOnline) {
      AccountService.instance.pinRoom(widget.room!['id'], true);
      sub = AccountService.instance
          .roomStream(widget.room!['id'])
          .listen(_onRoom);
    }
    ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (leftMs <= 0) {
        _finishMe();
      } else {
        setState(() {});
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        GameTutorial.showOnce(context,
            tutKey: 'wordfinder', title: 'WORD FINDER', steps: _wfTutorial);
      }
    });
  }

  @override
  void dispose() {
    ticker?.cancel();
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

  int get leftMs => gameMs - (DateTime.now().millisecondsSinceEpoch - startMs);

  void _onRoom(Map<String, dynamic>? r) {
    if (r == null || !mounted) return;
    final st = r['state'] as Map?;
    final o = st?[oppSide] as Map?;
    final os = (o?['score'] as num?)?.toInt() ?? 0;
    if (os != oppScore) setState(() => oppScore = os);
    final of = (o?['final'] as num?)?.toInt();
    if (of != null && of != oppFinal) {
      oppFinal = of;
      _maybeResolve();
    }
    if (st?['left'] == oppSide && !finished) _resolve(winByForfeit: true);
  }

  // ---------------- selection ----------------

  bool _adjacent(int a, int b) {
    final dr = (a ~/ gridN - b ~/ gridN).abs();
    final dc = (a % gridN - b % gridN).abs();
    return dr <= 1 && dc <= 1 && a != b;
  }

  void _tap(int i) {
    if (finished || leftMs <= 0) return;
    setState(() {
      if (path.isNotEmpty && path.last == i) {
        path.removeLast(); // backspace
      } else if (!path.contains(i) &&
          (path.isEmpty || _adjacent(path.last, i))) {
        Fx.tap();
        path.add(i);
      }
    });
  }

  // ---- drag selection: swipe across adjacent letters, release to submit ----

  /// Grid cell under a drag point [p] within a [side]-wide square, or null.
  int? _cellAt(Offset p, double side) {
    if (p.dx < 0 || p.dy < 0 || p.dx >= side || p.dy >= side) return null;
    final cs = side / gridN;
    final c = (p.dx / cs).floor().clamp(0, gridN - 1);
    final r = (p.dy / cs).floor().clamp(0, gridN - 1);
    return r * gridN + c;
  }

  void _dragStart(int i) {
    if (finished || leftMs <= 0) return;
    Fx.tap();
    setState(() => path
      ..clear()
      ..add(i));
  }

  void _dragTo(int i) {
    if (finished || leftMs <= 0 || path.isEmpty || path.last == i) return;
    // retrace: dragging back onto the previous cell pops the last letter
    if (path.length >= 2 && path[path.length - 2] == i) {
      setState(() => path.removeLast());
      return;
    }
    if (!path.contains(i) && _adjacent(path.last, i)) {
      Fx.tap();
      setState(() => path.add(i));
    }
  }

  void _dragEnd() {
    if (path.length >= 3) {
      _submit();
    } else {
      setState(() => path.clear());
    }
  }

  String get currentWord => path.map((i) => grid[i]).join();
  int get clearTarget =>
      WordFinderCatalog.clearTarget(gridSpec.guaranteedWords.length);

  void _hint() {
    if (finished || hintsUsed >= 3) return;
    final available = gridSpec.guaranteedWords
        .where((word) => !found.contains(word))
        .toList();
    if (available.isEmpty) {
      _flash('Every embedded hint word is already found');
      return;
    }
    final word = available[hintsUsed % available.length].toUpperCase();
    hintsUsed++;
    setState(() {
      path.clear();
      flash = 'HINT · find $word';
    });
  }

  void _submit() {
    final w = currentWord;
    if (w.length < 3) return _flash('too short');
    if (found.contains(w)) return _flash('already found');
    if (!wordSet.contains(w)) return _flash('not a word');
    final now = DateTime.now().millisecondsSinceEpoch;
    combo = (now - lastFoundMs < 8000) ? (combo + 1).clamp(1, 3).toInt() : 1;
    lastFoundMs = now;
    final pts = w.length * w.length * 10 * combo;
    Fx.success();
    setState(() {
      found.insert(0, w);
      score += pts;
      path.clear();
      flash = '+$pts${combo > 1 ? '  🔥x$combo' : ''}';
    });
    if (isOnline) {
      AccountService.instance
          .roomWrite(widget.room!['id'], 'state/$mySide/score', score);
    }
  }

  void _flash(String m) {
    Fx.error();
    setState(() {
      flash = m;
      path.clear();
    });
  }

  // ---------------- finishing ----------------

  void _finishMe() {
    if (myFinal != null) return;
    myFinal = score;
    ticker?.cancel();
    if (isOnline) {
      AccountService.instance
          .roomWrite(widget.room!['id'], 'state/$mySide/final', score);
      setState(() {});
      _maybeResolve();
    } else {
      _resolve();
    }
  }

  void _maybeResolve() {
    if (myFinal != null && oppFinal != null) _resolve();
  }

  void _resolve({bool winByForfeit = false}) {
    if (finished) return;
    finished = true;
    ticker?.cancel();
    final a = AppData.i;
    bool? won;
    var delta = 0;
    var stars = 0;
    var coinReward = 0;
    if (isOnline) {
      final opp = Map<String, dynamic>.from(widget.room![oppSide] as Map);
      final oppElo = (opp['elo'] as num?)?.toInt() ?? 800;
      won = winByForfeit ? true : score > (oppFinal ?? 0);
      final draw = !winByForfeit && score == (oppFinal ?? 0);
      delta = a.applyElo(oppElo, won ? 1 : (draw ? 0.5 : 0));
      a.recordMatch(
          mode: 'WordFind 🔤 online',
          opponent: '@${opp['u']}',
          result: won
              ? 'W'
              : draw
                  ? 'D'
                  : 'L',
          delta: delta);
      if (won) Fx.win();
    } else {
      if (widget.journeyStep != null) {
        stars = found.length >= clearTarget * 2
            ? 3
            : found.length >= (clearTarget * 1.5).ceil()
                ? 2
                : found.length >= clearTarget
                    ? 1
                    : 0;
        unlockedNext = a.recordMindLevel(
          'wordfind',
          widget.journeyStep!,
          stars,
          maxLevel: WordFinderCatalog.totalSteps,
        );
      }
      coinReward = a.earnCoins((score ~/ 100).clamp(0, 50).toInt());
      a.addXp(score ~/ 30);
      a.bumpActivity();
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
            if (won == true || (!isOnline && stars >= 2))
              const ConfettiBurst(height: 60),
            Text(
                isOnline
                    ? (won == true ? 'WORD WIZARD! 🏆' : 'OUT-WORDED')
                    : widget.journeyStep != null
                        ? stars > 0
                            ? 'RATING CLEARED'
                            : 'TARGET MISSED'
                        : 'TIME! 🔤',
                style: Theme.of(context).textTheme.displayMedium),
            const SizedBox(height: 6),
            Text(
                isOnline
                    ? 'You $score — ${oppFinal ?? 0} rival'
                    : widget.journeyStep != null
                        ? '${found.length}/$clearTarget target words · $score points'
                        : '$score points · ${found.length} words',
                style: TextStyle(color: DC.dim)),
            if (isOnline)
              Text('${delta >= 0 ? '+' : ''}$delta rating',
                  style: TextStyle(
                      color: delta >= 0 ? DC.lime : DC.danger,
                      fontWeight: FontWeight.w900,
                      fontSize: 18))
            else
              Column(children: [
                if (widget.journeyStep != null)
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    for (var i = 0; i < 3; i++)
                      Icon(Icons.star_rounded,
                          size: 22, color: i < stars ? DC.amber : DC.fg12),
                  ]),
                Text('+$coinReward coins · +${score ~/ 30} XP',
                    style: TextStyle(color: DC.amber)),
                if (unlockedNext)
                  Text('Next rated variant unlocked',
                      style: TextStyle(
                          color: DC.lime, fontWeight: FontWeight.w800)),
              ]),
            const SizedBox(height: 14),
            if (isOnline)
              RematchButton(room: widget.room!, amHost: widget.amHost)
            else
              NeonButton(
                label: unlockedNext ? 'BACK TO RATINGS' : 'PLAY AGAIN',
                icon: unlockedNext ? Icons.lock_open_rounded : Icons.refresh,
                height: 46,
                colors: [DC.magenta, DC.violet],
                onPressed: () {
                  Navigator.pop(context);
                  if (unlockedNext) {
                    Navigator.pop(context);
                  } else {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => WordFinderScreen(
                          journeyStep: widget.journeyStep,
                          rating: widget.rating,
                          seedOverride: widget.seedOverride,
                        ),
                      ),
                    );
                  }
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

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    final secs = (leftMs / 1000).ceil().clamp(0, 999);
    final waiting = myFinal != null && !finished;
    return Scaffold(
      body: ShaderBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: waiting
                ? Center(
                    child: Glass(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                    CircularProgressIndicator(color: DC.cyan),
                    SizedBox(height: 14),
                    Text('Rival is still hunting…',
                        style: TextStyle(color: DC.dim)),
                  ])))
                : Column(children: [
                    Row(children: [
                      Glass(
                          radius: 16,
                          padding: const EdgeInsets.all(8),
                          onTap: () => Navigator.pop(context),
                          child: const Icon(Icons.close, size: 18)),
                      const SizedBox(width: 8),
                      GameTutorial.helpButton(context,
                          title: 'WORD FINDER', steps: _wfTutorial),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Glass(
                          radius: 18,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          child: Row(children: [
                            Text('$score',
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: DC.cyan)),
                            if (combo > 1)
                              Text('  🔥x$combo',
                                  style:
                                      TextStyle(color: DC.amber, fontSize: 12)),
                            const Spacer(),
                            if (isOnline)
                              Text('rival $oppScore  ·  ',
                                  style: TextStyle(
                                      fontSize: 12, color: DC.magenta)),
                            Icon(Icons.timer,
                                size: 15,
                                color: secs < 15 ? DC.danger : DC.dim),
                            Text(' $secs',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: secs < 15 ? DC.danger : DC.text)),
                          ]),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 44,
                      child: Row(children: [
                        Icon(Icons.military_tech_rounded,
                            size: 16, color: DC.band(gameRating)),
                        const SizedBox(width: 5),
                        Text('$gameRating',
                            style: TextStyle(
                                color: DC.band(gameRating),
                                fontWeight: FontWeight.w900)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${found.length}/$clearTarget target · ${gridSpec.guaranteedWords.length}+ embedded',
                            style: TextStyle(fontSize: 11, color: DC.dim),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: hintsUsed < 3 ? _hint : null,
                          icon: const Icon(Icons.lightbulb_outline_rounded,
                              size: 16),
                          label: Text('HINT ${3 - hintsUsed}'),
                        ),
                      ]),
                    ),
                    // current word + flash
                    SizedBox(
                      height: 34,
                      child: Center(
                        child: Text(
                          path.isEmpty ? flash : currentWord.toUpperCase(),
                          style: TextStyle(
                              fontSize: 20,
                              letterSpacing: 3,
                              fontWeight: FontWeight.w900,
                              color: path.isEmpty
                                  ? (flash.startsWith('+') ? DC.lime : DC.dim)
                                  : DC.cyan),
                        ),
                      ),
                    ),
                    // grid — drag across letters (pan), or tap cell-by-cell
                    AspectRatio(
                      aspectRatio: 1,
                      child: Glass(
                        padding: const EdgeInsets.all(8),
                        radius: 22,
                        child: LayoutBuilder(builder: (context, box) {
                          final side = box.maxWidth;
                          return GestureDetector(
                            onPanStart: (d) {
                              final i = _cellAt(d.localPosition, side);
                              if (i != null) _dragStart(i);
                            },
                            onPanUpdate: (d) {
                              final i = _cellAt(d.localPosition, side);
                              if (i != null) _dragTo(i);
                            },
                            onPanEnd: (_) => _dragEnd(),
                            child: Column(children: [
                              for (var r = 0; r < gridN; r++)
                                Expanded(
                                  child: Row(children: [
                                    for (var c = 0; c < gridN; c++)
                                      Expanded(child: _cell(r * gridN + c)),
                                  ]),
                                ),
                            ]),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                        child: NeonButton(
                            label: 'SUBMIT WORD',
                            height: 48,
                            onPressed: path.length >= 3 ? _submit : null),
                      ),
                      const SizedBox(width: 8),
                      GhostButton(
                          label: 'CLEAR',
                          height: 48,
                          onPressed: () => setState(() => path.clear())),
                    ]),
                    const SizedBox(height: 8),
                    // found words ribbon
                    SizedBox(
                      height: 30,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final w in found)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Glass(
                                radius: 14,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                child: Text(w.toUpperCase(),
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: DC.lime,
                                        fontWeight: FontWeight.w700)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ]),
          ),
        ),
      ),
    );
  }

  Widget _cell(int i) {
    final sel = path.contains(i);
    final order = path.indexOf(i);
    return GestureDetector(
      onTap: () => _tap(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: sel ? LinearGradient(colors: [DC.cyan, DC.violet]) : null,
          color: sel ? null : DC.fgo(0.05),
          border: Border.all(color: DC.fgo(sel ? 0.4 : 0.12)),
          boxShadow: sel
              ? [BoxShadow(color: DC.cyan.withOpacity(0.4), blurRadius: 12)]
              : null,
        ),
        child: Stack(children: [
          Center(
            child: Text(grid[i].toUpperCase(),
                style: TextStyle(
                    fontSize: gridN >= 6 ? 18 : 26,
                    fontWeight: FontWeight.w900,
                    color: sel ? Colors.white : DC.text)),
          ),
          if (sel)
            Positioned(
              top: 3,
              right: 6,
              child: Text('${order + 1}',
                  style: TextStyle(fontSize: 9, color: DC.fg70)),
            ),
        ]),
      ),
    );
  }
}

class WordFinderJourneyScreen extends StatefulWidget {
  const WordFinderJourneyScreen({super.key});

  @override
  State<WordFinderJourneyScreen> createState() =>
      _WordFinderJourneyScreenState();
}

class _WordFinderJourneyScreenState extends State<WordFinderJourneyScreen> {
  @override
  Widget build(BuildContext context) {
    final a = AppData.i;
    final unlocked =
        a.mindLevel('wordfind').clamp(1, WordFinderCatalog.totalSteps).toInt();
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
                  child: const Icon(Icons.arrow_back_rounded, size: 18),
                ),
                const SizedBox(width: 12),
                Icon(Icons.spellcheck_rounded, color: DC.lime),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('WORD FINDER RATINGS',
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                Pill(
                  icon: Icons.star_rounded,
                  label:
                      '${a.mindTotalStars('wordfind', maxLevel: WordFinderCatalog.totalSteps)}/${WordFinderCatalog.totalSteps * 3}',
                  color: DC.amber,
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Every board contains guaranteed dictionary paths. Reach the word target to unlock the next variant.',
                  style: TextStyle(fontSize: 11, color: DC.dim),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
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
    final first = WordFinderCatalog.stepFor(rating, 1);
    final bandOpen = first <= unlocked;
    final cleared = [
      for (var variant = 1;
          variant <= WordFinderCatalog.variantsPerRating;
          variant++)
        if (a.mindStarsAt(
                'wordfind', WordFinderCatalog.stepFor(rating, variant)) >
            0)
          variant,
    ].length;
    final size = WordFinderCatalog.gridForRating(rating);
    final embedded = WordFinderCatalog.embeddedWordTarget(rating);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: bandOpen
            ? LinearGradient(colors: [
                DC.band(rating).withOpacity(0.16),
                DC.lime.withOpacity(0.035),
              ])
            : null,
        color: bandOpen ? null : DC.fgo(0.02),
        border: Border.all(
          color: first <= unlocked &&
                  unlocked < first + WordFinderCatalog.variantsPerRating
              ? DC.lime
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
                Text(bandOpen ? '$rating · $size×$size GRID' : 'LOCKED',
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: bandOpen ? DC.text : DC.dim)),
                Text('$cleared/15 cleared · $embedded+ embedded words',
                    style: TextStyle(fontSize: 11, color: DC.dim)),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: WordFinderCatalog.variantsPerRating,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.05,
          ),
          itemBuilder: (_, i) {
            final variant = i + 1;
            final step = WordFinderCatalog.stepFor(rating, variant);
            final open = SequentialProgression.canPlay(step, unlocked);
            final stars = a.mindStarsAt('wordfind', step);
            return Semantics(
              button: true,
              enabled: open,
              label: open
                  ? 'Word Finder $rating variant $variant'
                  : 'Word Finder $rating variant $variant locked',
              child: InkWell(
                borderRadius: BorderRadius.circular(13),
                onTap: open
                    ? () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => WordFinderScreen(
                              journeyStep: step,
                              rating: rating,
                              seedOverride: WordFinderCatalog.seedForStep(step),
                            ),
                          ),
                        ).then((_) => setState(() {}))
                    : null,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(13),
                    color: open ? DC.fgo(0.055) : DC.fgo(0.02),
                    border: Border.all(
                      color: step == unlocked
                          ? DC.lime
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
      ]),
    );
  }
}

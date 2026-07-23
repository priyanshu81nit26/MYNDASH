import 'dart:async';

import 'package:flutter/material.dart';

import '../core/fx.dart';
import '../core/state.dart';
import '../engine/mind_engines.dart';
import '../theme_district.dart';
import '../ui/extras.dart';
import '../ui/glass.dart';
import 'mind_games.dart';

/// ============================================================
/// KIDS CROSSWORD 🧩 — a full 3D gamified word puzzle for the
/// kids section. Candy board, big emoji clues, chunky keys,
/// rainbow words that lock in with sparkles.
/// 18 rating bands (800 → 2500), progressive difficulty,
/// 15 puzzles inside every band = 270 seeded games.
/// ============================================================

/// ---------------- kid word bank (emoji-first clues) ----------------
/// Clue format: first token is the BIG emoji, the rest is the hint text.

const _tierA = <CrosswordWord>[
  CrosswordWord('CAT', '🐱 Says meow'),
  CrosswordWord('DOG', '🐶 Says woof'),
  CrosswordWord('SUN', '☀️ Shines in the day'),
  CrosswordWord('BEE', '🐝 Makes honey'),
  CrosswordWord('COW', '🐮 Gives us milk'),
  CrosswordWord('PIG', '🐷 Pink farm friend'),
  CrosswordWord('HEN', '🐔 Lays eggs'),
  CrosswordWord('EGG', '🥚 Cracks for breakfast'),
  CrosswordWord('ICE', '🧊 Frozen water'),
  CrosswordWord('CAR', '🚗 Beep beep!'),
  CrosswordWord('BUS', '🚌 Big yellow ride to school'),
  CrosswordWord('HAT', '🎩 Wear it on your head'),
  CrosswordWord('BED', '🛏️ Where you sleep'),
  CrosswordWord('CUP', '☕ Drink from it'),
  CrosswordWord('KEY', '🔑 Opens a lock'),
  CrosswordWord('MAP', '🗺️ Shows the way'),
  CrosswordWord('PEN', '🖊️ Write with it'),
  CrosswordWord('BOX', '📦 Put things inside'),
  CrosswordWord('FOX', '🦊 Clever orange animal'),
  CrosswordWord('OWL', '🦉 Hoots at night'),
  CrosswordWord('ANT', '🐜 Tiny strong worker'),
  CrosswordWord('BAT', '🦇 Flies in the dark'),
  CrosswordWord('JAM', '🍓 Sweet spread for bread'),
  CrosswordWord('KITE', '🪁 Flies on a string'),
  CrosswordWord('FISH', '🐟 Swims with fins'),
  CrosswordWord('FROG', '🐸 Jumps and says ribbit'),
  CrosswordWord('MOON', '🌙 Night-sky light'),
  CrosswordWord('STAR', '⭐ Twinkles up high'),
  CrosswordWord('TREE', '🌳 Birds build nests in it'),
  CrosswordWord('CAKE', '🎂 Birthday treat'),
  CrosswordWord('MILK', '🥛 White drink from cows'),
  CrosswordWord('DUCK', '🦆 Says quack'),
  CrosswordWord('LION', '🦁 King of the jungle'),
  CrosswordWord('BEAR', '🐻 Loves honey, sleeps all winter'),
  CrosswordWord('SHIP', '🚢 Sails the sea'),
  CrosswordWord('RAIN', '🌧️ Wet drops from clouds'),
];

const _tierB = <CrosswordWord>[
  CrosswordWord('APPLE', '🍎 Red fruit, one a day!'),
  CrosswordWord('TIGER', '🐯 Big cat with stripes'),
  CrosswordWord('ZEBRA', '🦓 Black and white stripes'),
  CrosswordWord('SNAKE', '🐍 Slithers with no legs'),
  CrosswordWord('HORSE', '🐴 Gallops and neighs'),
  CrosswordWord('MOUSE', '🐭 Small and loves cheese'),
  CrosswordWord('TRAIN', '🚂 Choo choo on rails'),
  CrosswordWord('PLANE', '✈️ Flies in the sky'),
  CrosswordWord('HOUSE', '🏠 Where a family lives'),
  CrosswordWord('CLOUD', '☁️ Fluffy in the sky'),
  CrosswordWord('BREAD', '🍞 Baker makes it'),
  CrosswordWord('HONEY', '🍯 Sweet — bees make it'),
  CrosswordWord('PIZZA', '🍕 Cheesy slice'),
  CrosswordWord('ROBOT', '🤖 Metal helper that beeps'),
  CrosswordWord('CANDY', '🍬 Sweet treat'),
  CrosswordWord('SMILE', '😊 Happy face curve'),
  CrosswordWord('BEACH', '🏖️ Sand and waves'),
  CrosswordWord('SHARK', '🦈 Fin above the water'),
  CrosswordWord('WHALE', '🐋 Biggest sea animal'),
  CrosswordWord('CAMEL', '🐫 Desert animal with humps'),
  CrosswordWord('GRAPE', '🍇 Small purple fruit in bunches'),
  CrosswordWord('LEMON', '🍋 Sour and yellow'),
  CrosswordWord('MANGO', '🥭 Sweet king of fruits'),
  CrosswordWord('CROWN', '👑 A king wears it'),
  CrosswordWord('CLOCK', '⏰ Tick tock, tells time'),
  CrosswordWord('PANDA', '🐼 Black-and-white bamboo eater'),
  CrosswordWord('KOALA', '🐨 Sleepy tree hugger'),
  CrosswordWord('IGLOO', '🧊 Snow-block house'),
  CrosswordWord('OCEAN', '🌊 Huge salty water'),
  CrosswordWord('TOAST', '🍞 Warm crispy breakfast bread'),
];

const _tierC = <CrosswordWord>[
  CrosswordWord('ROCKET', '🚀 Blasts off to space'),
  CrosswordWord('PLANET', '🪐 Earth is one'),
  CrosswordWord('GARDEN', '🌷 Flowers grow here'),
  CrosswordWord('FLOWER', '🌸 Bloom on a stem'),
  CrosswordWord('MONKEY', '🐵 Swings and loves bananas'),
  CrosswordWord('RABBIT', '🐰 Hops and loves carrots'),
  CrosswordWord('TURTLE', '🐢 Slow with a shell'),
  CrosswordWord('SPIDER', '🕷️ Spins a web'),
  CrosswordWord('PENGUIN', '🐧 Bird in a tuxedo'),
  CrosswordWord('DOLPHIN', '🐬 Smart sea jumper'),
  CrosswordWord('VOLCANO', '🌋 Mountain that erupts'),
  CrosswordWord('RAINBOW', '🌈 Seven colours after rain'),
  CrosswordWord('CASTLE', '🏰 Home of kings and queens'),
  CrosswordWord('DRAGON', '🐉 Breathes fire in stories'),
  CrosswordWord('WIZARD', '🧙 Casts magic spells'),
  CrosswordWord('JUNGLE', '🌴 Thick wild forest'),
  CrosswordWord('DESERT', '🏜️ Hot, sandy and dry'),
  CrosswordWord('ISLAND', '🏝️ Land with water all around'),
  CrosswordWord('BRIDGE', '🌉 Crosses a river'),
  CrosswordWord('GUITAR', '🎸 Strum its six strings'),
  CrosswordWord('VIOLIN', '🎻 Play it with a bow'),
  CrosswordWord('WINDOW', '🪟 Glass you look through'),
  CrosswordWord('MIRROR', '🪞 Shows your reflection'),
  CrosswordWord('SHADOW', '🌑 Follows you in sunlight'),
  CrosswordWord('CIRCUS', '🎪 Clowns and acrobats show'),
  CrosswordWord('PIRATE', '🏴‍☠️ Sails looking for treasure'),
  CrosswordWord('TUNNEL', '🚇 A road through a mountain'),
  CrosswordWord('MUSEUM', '🏛️ Old treasures on display'),
];

const _tierD = <CrosswordWord>[
  CrosswordWord('ELEPHANT', '🐘 Biggest land animal, long trunk'),
  CrosswordWord('DINOSAUR', '🦖 Roamed Earth long ago'),
  CrosswordWord('TREASURE', '💰 X marks the spot'),
  CrosswordWord('KANGAROO', '🦘 Hops with a pouch'),
  CrosswordWord('OCTOPUS', '🐙 Eight clever arms'),
  CrosswordWord('GIRAFFE', '🦒 Tallest animal of all'),
  CrosswordWord('PYRAMID', '🔺 Ancient Egyptian wonder'),
  CrosswordWord('TORNADO', '🌪️ Spinning wind storm'),
  CrosswordWord('ASTEROID', '☄️ Space rock zooming by'),
  CrosswordWord('SUBMARINE', '🤿 Ship that dives underwater'),
  CrosswordWord('PARACHUTE', '🪂 Floats you down from the sky'),
  CrosswordWord('SKELETON', '💀 All your bones together'),
  CrosswordWord('COMPASS', '🧭 Always points north'),
  CrosswordWord('LANTERN', '🏮 Light you can carry'),
  CrosswordWord('ECLIPSE', '🌒 Moon hides the sun'),
  CrosswordWord('GALAXY', '🌌 Billions of stars together'),
  CrosswordWord('METEOR', '💫 Shooting star'),
  CrosswordWord('FOSSIL', '🦴 Ancient bone in stone'),
  CrosswordWord('CANYON', '🏞️ Deep valley with cliffs'),
  CrosswordWord('LAGOON', '🏝️ Calm blue shallow water'),
  CrosswordWord('BLIZZARD', '❄️ Huge snow storm'),
  CrosswordWord('AVOCADO', '🥑 Green fruit for guacamole'),
  CrosswordWord('CHIMNEY', '🏠 Smoke goes up through it'),
  CrosswordWord('HAMMOCK', '🌴 Nap net between two trees'),
  CrosswordWord('UNICORN', '🦄 Magical horse with a horn'),
  CrosswordWord('MAGNET', '🧲 Pulls metal things close'),
];

/// ---------------- band configuration ----------------
class KidCross {
  static const bandCount = 18; // 800..2500
  static const perBand = 15; // puzzles inside each band
  static const maxLevel = bandCount * perBand; // 270

  static int rating(int band) => 800 + band * 100;

  static const bandNames = [
    'WORD SPROUT', 'LETTER CUB', 'SPELL PUP', 'WORD SCOUT',
    'LETTER FOX', 'SPELL STAR', 'WORD RANGER', 'LETTER ACE',
    'SPELL KNIGHT', 'WORD NINJA', 'LETTER SAGE', 'SPELL CAPTAIN',
    'WORD CHAMP', 'LETTER HERO', 'SPELL MASTER', 'WORD LEGEND',
    'LETTER TITAN', 'WORD WIZARD',
  ];

  static const bandEmojis = [
    '🌱', '🐻', '🐶', '🧭', '🦊', '⭐', '🏕️', '🎯',
    '🛡️', '🥷', '📜', '⚓', '🏅', '🦸', '✨', '🏆', '⚡', '🧙',
  ];

  /// Board grows 5×5 → 10×10 across the bands.
  static int gridFor(int band) => (5 + band ~/ 3).clamp(5, 10).toInt();

  /// Words to place grows 3 → 11.
  static int wordsFor(int band) => (3 + band ~/ 2).clamp(3, 11).toInt();

  /// Harder bands draw from harder word tiers.
  static List<CrosswordWord> poolFor(int band) {
    if (band < 4) return _tierA;
    if (band < 8) return [..._tierA, ..._tierB];
    if (band < 12) return [..._tierB, ..._tierC];
    return [..._tierC, ..._tierD];
  }

  /// Generous kid par (seconds) for 3★.
  static int parFor(int band) => 45 + wordsFor(band) * 22 + band * 6;

  /// Stable seed so every kid worldwide gets the same 270 puzzles.
  static int seedFor(int band, int variant) =>
      (band * 97 + variant) * 7919 + 4242;

  static Crossword puzzle(int band, int variant) => CrosswordGen.generate(
      seedFor(band, variant), gridFor(band), wordsFor(band),
      wordPool: poolFor(band));
}

/// Candy rainbow for word colouring.
const _kidRainbow = [
  Color(0xFFFF6B81), // pink-red
  Color(0xFFFFA94D), // orange
  Color(0xFFFFD43B), // yellow
  Color(0xFF51CF66), // green
  Color(0xFF4DABF7), // blue
  Color(0xFF9775FA), // purple
  Color(0xFFFF8FAB), // rose
];

/// ============================================================
/// JOURNEY — 18 rating bands, 15 puzzle bubbles in each.
/// ============================================================
class KidCrosswordJourney extends StatefulWidget {
  const KidCrosswordJourney({super.key});

  @override
  State<KidCrosswordJourney> createState() => _KidCrosswordJourneyState();
}

class _KidCrosswordJourneyState extends State<KidCrosswordJourney> {
  @override
  Widget build(BuildContext context) {
    final a = AppData.i;
    final unlocked = a.kidLevel('kidcross');
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
                  child: Text('CROSSWORD QUEST 🧩',
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                Pill(
                    icon: Icons.flag,
                    label: '${unlocked - 1}/${KidCross.maxLevel}',
                    color: DC.violet),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                    'Climb 800 → 2500! Get 2★ to unlock the next puzzle.',
                    style: TextStyle(fontSize: 11, color: DC.dim)),
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: KidCross.bandCount,
                itemBuilder: (_, b) => _bandCard(context, a, b, unlocked),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _bandCard(BuildContext context, AppData a, int b, int unlocked) {
    final color = _kidRainbow[b % _kidRainbow.length];
    final firstLevel = b * KidCross.perBand + 1;
    final bandOpen = firstLevel <= unlocked;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: bandOpen
                ? [color.withOpacity(0.20), color.withOpacity(0.06)]
                : [DC.fgo(0.04), DC.fgo(0.02)]),
        border: Border.all(
            color: bandOpen ? color.withOpacity(0.55) : DC.fgo(0.08)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(KidCross.bandEmojis[b], style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${KidCross.rating(b)} · ${KidCross.bandNames[b]}',
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 0.5,
                          color: bandOpen ? DC.text : DC.dim)),
                  Text(
                      '${KidCross.gridFor(b)}×${KidCross.gridFor(b)} board · ${KidCross.wordsFor(b)} words',
                      style: TextStyle(fontSize: 10, color: DC.dim)),
                ]),
          ),
          if (!bandOpen) Icon(Icons.lock, size: 16, color: DC.fg38),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 7, runSpacing: 7, children: [
          for (var v = 0; v < KidCross.perBand; v++)
            _bubble(context, a, b, v, color, unlocked),
        ]),
      ]),
    );
  }

  Widget _bubble(BuildContext context, AppData a, int b, int v, Color color,
      int unlocked) {
    final level = b * KidCross.perBand + v + 1;
    final open = level <= unlocked;
    final stars =
        (a.kidProgress['kidcross_s$level'] as int?) ?? 0; // best stars
    return GestureDetector(
      onTap: open
          ? () async {
              Fx.tap();
              await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => KidCrosswordScreen(level: level)));
              if (mounted) setState(() {});
            }
          : () => Fx.error(),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: open
              ? LinearGradient(colors: [
                  color.withOpacity(stars > 0 ? 0.85 : 0.35),
                  color.withOpacity(stars > 0 ? 0.55 : 0.15),
                ])
              : null,
          color: open ? null : DC.fgo(0.05),
          border: Border.all(
              color: level == unlocked ? Colors.white : DC.fgo(0.14),
              width: level == unlocked ? 2 : 1),
          boxShadow: open && stars > 0
              ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8)]
              : null,
        ),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(open ? '${v + 1}' : '🔒',
                  style: TextStyle(
                      fontSize: open ? 13 : 11,
                      fontWeight: FontWeight.w900,
                      color: open
                          ? (stars > 0 ? Colors.white : DC.text)
                          : DC.fg38)),
              if (open && stars > 0)
                Text('⭐' * stars, style: const TextStyle(fontSize: 5)),
            ]),
      ),
    );
  }
}

/// ============================================================
/// GAME SCREEN — candy 3D board with emoji clues.
/// ============================================================
class KidCrosswordScreen extends StatefulWidget {
  final int level; // 1..270
  const KidCrosswordScreen({super.key, required this.level});

  @override
  State<KidCrosswordScreen> createState() => _KidCrosswordScreenState();
}

class _KidCrosswordScreenState extends State<KidCrosswordScreen> {
  late final int band = (widget.level - 1) ~/ KidCross.perBand;
  late final int variant = (widget.level - 1) % KidCross.perBand;

  Crossword? cw;
  late List<String> letters;
  final locked = <int>{}; // solved entry indexes
  int selCell = -1;
  int selEntry = -1;
  int hints = 3;
  int elapsed = 0;
  Timer? ticker;
  bool done = false;

  @override
  void initState() {
    super.initState();
    ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !done) setState(() => elapsed++);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = KidCross.puzzle(band, variant);
      if (!mounted) return;
      setState(() {
        cw = c;
        letters = List<String>.filled(c.n * c.n, '');
        if (c.words.isNotEmpty) {
          selEntry = 0;
          selCell = c.words[0].row * c.n + c.words[0].col;
        }
      });
    });
  }

  @override
  void dispose() {
    ticker?.cancel();
    super.dispose();
  }

  // ---------------- helpers ----------------

  List<int> _entriesAt(int cell) => [
        for (var e = 0; e < cw!.words.length; e++)
          if (cw!.words[e].cellsIn(cw!.n).contains(cell)) e
      ];

  bool _cellLocked(int cell) {
    for (final e in locked) {
      if (cw!.words[e].cellsIn(cw!.n).contains(cell)) return true;
    }
    return false;
  }

  /// (emoji, text) split of a clue.
  (String, String) _clueBits(String clue) {
    final sp = clue.indexOf(' ');
    return sp < 0 ? (clue, '') : (clue.substring(0, sp), clue.substring(sp + 1));
  }

  void _selectCell(int cell) {
    if (done || cw!.solution[cell].isEmpty) return;
    Fx.light();
    final es = _entriesAt(cell);
    if (es.isEmpty) return;
    setState(() {
      if (cell == selCell && es.length > 1) {
        selEntry = es[(es.indexOf(selEntry) + 1) % es.length];
      } else {
        if (!es.contains(selEntry)) selEntry = es.first;
      }
      selCell = cell;
    });
  }

  void _selectEntry(int e) {
    Fx.light();
    setState(() {
      selEntry = e;
      final cells = cw!.words[e].cellsIn(cw!.n);
      selCell = cells.firstWhere((c) => letters[c].isEmpty,
          orElse: () => cells.first);
    });
  }

  void _type(String ch) {
    if (done || cw == null || selCell < 0) return;
    if (_cellLocked(selCell)) return _advance();
    Fx.tap();
    setState(() => letters[selCell] = ch);
    for (final e in _entriesAt(selCell)) {
      _checkEntry(e);
    }
    if (_solvedAll) {
      _finish();
      return;
    }
    _advance();
  }

  void _advance() {
    final cells = cw!.words[selEntry].cellsIn(cw!.n);
    final at = cells.indexOf(selCell);
    for (var k = at + 1; k < cells.length; k++) {
      if (!_cellLocked(cells[k])) {
        setState(() => selCell = cells[k]);
        return;
      }
    }
  }

  void _backspace() {
    if (done || cw == null || selCell < 0) return;
    Fx.light();
    setState(() {
      if (letters[selCell].isNotEmpty && !_cellLocked(selCell)) {
        letters[selCell] = '';
      } else {
        final cells = cw!.words[selEntry].cellsIn(cw!.n);
        final at = cells.indexOf(selCell);
        if (at > 0) {
          selCell = cells[at - 1];
          if (!_cellLocked(selCell)) letters[selCell] = '';
        }
      }
    });
  }

  void _checkEntry(int e) {
    if (locked.contains(e)) return;
    final w = cw!.words[e];
    final cells = w.cellsIn(cw!.n);
    if (cells.any((c) => letters[c].isEmpty)) return;
    final typed = cells.map((c) => letters[c]).join();
    if (typed == w.word) {
      locked.add(e);
      Fx.success();
    }
  }

  void _hint() {
    if (done || cw == null || hints <= 0) return;
    var i = selCell;
    if (i < 0 ||
        cw!.solution[i].isEmpty ||
        letters[i] == cw!.solution[i]) {
      i = List.generate(cw!.solution.length, (k) => k).firstWhere(
          (k) =>
              cw!.solution[k].isNotEmpty && letters[k] != cw!.solution[k],
          orElse: () => -1);
    }
    if (i < 0) return;
    hints--;
    Fx.unlock();
    setState(() {
      selCell = i;
      letters[i] = cw!.solution[i];
    });
    for (final e in _entriesAt(i)) {
      _checkEntry(e);
    }
    if (_solvedAll) _finish();
  }

  bool get _solvedAll => locked.length >= cw!.words.length;

  void _finish() {
    if (done) return;
    done = true;
    ticker?.cancel();
    final par = KidCross.parFor(band);
    final stars = elapsed <= par ? 3 : (elapsed <= par * 1.6 ? 2 : 1);
    final a = AppData.i;
    a.recordKidLevel('kidcross', widget.level, stars,
        max: KidCross.maxLevel);
    final prevBest = (a.kidProgress['kidcross_s${widget.level}'] as int?) ?? 0;
    if (stars > prevBest) {
      a.kidProgress['kidcross_s${widget.level}'] = stars;
    }
    a.save();
    if (stars >= 2) {
      Fx.win();
    } else {
      Fx.lose();
    }
    final unlocked = a.kidLevel('kidcross');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: DC.bg2,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (stars >= 2) const ConfettiBurst(height: 60),
            Text(['💪', '🙂', '🌟', '🏆'][stars],
                style: const TextStyle(fontSize: 44)),
            const SizedBox(height: 6),
            Text(stars >= 2 ? 'WORD-TASTIC!' : 'GOOD TRY!',
                style: Theme.of(context).textTheme.displayMedium),
            Text(
                'All ${cw!.words.length} words · ${elapsed}s (3★ under ${par}s)',
                textAlign: TextAlign.center,
                style: TextStyle(color: DC.dim, fontSize: 12)),
            const SizedBox(height: 4),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 0; i < 3; i++)
                Icon(i < stars ? Icons.star : Icons.star_border,
                    size: 32, color: DC.amber),
            ]),
            Text('+${stars * 8} XP · +${5 + stars * 5} 🪙',
                style: TextStyle(color: DC.amber, fontSize: 12)),
            const SizedBox(height: 14),
            if (widget.level < KidCross.maxLevel &&
                widget.level + 1 <= unlocked)
              NeonButton(
                label: 'NEXT PUZZLE →',
                height: 46,
                colors: [DC.lime, DC.cyan],
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              KidCrosswordScreen(level: widget.level + 1)));
                },
              )
            else
              NeonButton(
                label: 'PLAY AGAIN',
                height: 46,
                colors: [DC.magenta, DC.violet],
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (_) =>
                              KidCrosswordScreen(level: widget.level)));
                },
              ),
            const SizedBox(height: 8),
            NeonButton(
                label: 'MAP',
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
    return Scaffold(
      body: ShaderBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: cw == null
                ? Center(
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: DC.violet),
                          const SizedBox(height: 12),
                          Text('Mixing the letters… 🎨',
                              style:
                                  TextStyle(color: DC.dim, fontSize: 12)),
                        ]))
                : Column(children: [
                    _header(),
                    const SizedBox(height: 8),
                    Expanded(
                        child:
                            Center(child: Tilt3D(tilt: 0.08, child: _board()))),
                    const SizedBox(height: 6),
                    _clueBar(),
                    const SizedBox(height: 6),
                    _keyboard(),
                  ]),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(children: [
      Glass(
          radius: 16,
          padding: const EdgeInsets.all(8),
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.close, size: 18)),
      const SizedBox(width: 8),
      Pill(
          icon: Icons.military_tech,
          label:
              '${KidCross.rating(band)} · ${variant + 1}/${KidCross.perBand}',
          color: _kidRainbow[band % _kidRainbow.length]),
      const Spacer(),
      Pill(icon: Icons.timer, label: '${elapsed}s', color: DC.cyan),
      const SizedBox(width: 6),
      Glass(
        radius: 16,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        onTap: _hint,
        child: Text('💡 $hints',
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w900)),
      ),
    ]);
  }

  Widget _board() {
    final n = cw!.n;
    final selCells =
        selEntry >= 0 ? cw!.words[selEntry].cellsIn(n) : const <int>[];
    final numbers = <int, int>{};
    for (final w in cw!.words) {
      numbers.putIfAbsent(w.row * n + w.col, () => w.number);
    }
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: ThemeCtl.isDark
                  ? [const Color(0xFF241A3F), const Color(0xFF120B22)]
                  : [const Color(0xFFBDE3FF), const Color(0xFFE3D5FF)]),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 20,
                offset: const Offset(0, 12)),
          ],
          border: Border.all(
              color: _kidRainbow[band % _kidRainbow.length]
                  .withOpacity(0.55),
              width: 1.5),
        ),
        child: Column(children: [
          for (var r = 0; r < n; r++)
            Expanded(
              child: Row(children: [
                for (var c = 0; c < n; c++)
                  Expanded(
                      child: _cell(r * n + c,
                          inSel: selCells.contains(r * n + c),
                          number: numbers[r * n + c])),
              ]),
            ),
        ]),
      ),
    );
  }

  Widget _cell(int i, {required bool inSel, int? number}) {
    if (cw!.solution[i].isEmpty) {
      return const SizedBox.expand();
    }
    final v = letters[i];
    final sel = i == selCell;
    final lockedCell = _cellLocked(i);
    // colour of the first locked entry covering this cell
    Color lockColor = DC.lime;
    for (final e in locked) {
      if (cw!.words[e].cellsIn(cw!.n).contains(i)) {
        lockColor = _kidRainbow[e % _kidRainbow.length];
        break;
      }
    }
    return GestureDetector(
      onTap: () => _selectCell(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(7),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: lockedCell
                ? [
                    lockColor.withOpacity(0.9),
                    lockColor.withOpacity(0.6)
                  ]
                : sel
                    ? [Colors.white, const Color(0xFFFFF3BF)]
                    : inSel
                        ? [Colors.white, const Color(0xFFE7F5FF)]
                        : [
                            Colors.white.withOpacity(0.92),
                            Colors.white.withOpacity(0.78)
                          ],
          ),
          border: Border.all(
              color: sel
                  ? const Color(0xFFFFB020)
                  : lockedCell
                      ? lockColor
                      : Colors.black.withOpacity(0.12),
              width: sel ? 2 : 1),
          boxShadow: [
            BoxShadow(
                color: lockedCell
                    ? lockColor.withOpacity(0.45)
                    : Colors.black.withOpacity(0.18),
                blurRadius: lockedCell ? 8 : 3,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Stack(children: [
          if (number != null)
            Positioned(
              top: 1,
              left: 2,
              child: Text('$number',
                  style: TextStyle(
                      fontSize: 7,
                      fontWeight: FontWeight.w900,
                      color: Colors.black.withOpacity(0.45))),
            ),
          Center(
            child: v.isEmpty
                ? null
                : TweenAnimationBuilder<double>(
                    key: ValueKey('$i-$v'),
                    tween: Tween(begin: 0.3, end: 1),
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.elasticOut,
                    builder: (_, s, child) =>
                        Transform.scale(scale: s, child: child),
                    child: Text(v,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: lockedCell
                                ? Colors.white
                                : const Color(0xFF2B2B4A))),
                  ),
          ),
        ]),
      ),
    );
  }

  Widget _clueBar() {
    final w = selEntry >= 0 ? cw!.words[selEntry] : null;
    if (w == null) return const SizedBox.shrink();
    final (emoji, text) = _clueBits(w.clue);
    final color = _kidRainbow[selEntry % _kidRainbow.length];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
            colors: [color.withOpacity(0.30), color.withOpacity(0.12)]),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Row(children: [
        GestureDetector(
          onTap: () => _selectEntry(
              (selEntry - 1 + cw!.words.length) % cw!.words.length),
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(Icons.chevron_left, size: 22),
          ),
        ),
        Text(emoji, style: const TextStyle(fontSize: 26)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(children: [
            Text(
                '${w.word.length} letters · ${w.across ? 'ACROSS' : 'DOWN'}${locked.contains(selEntry) ? ' · SOLVED ✔' : ''}',
                style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w900,
                    color: DC.dim)),
            Text(text,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w800)),
          ]),
        ),
        GestureDetector(
          onTap: () => _selectEntry((selEntry + 1) % cw!.words.length),
          child: const Padding(
            padding: EdgeInsets.all(4),
            child: Icon(Icons.chevron_right, size: 22),
          ),
        ),
      ]),
    );
  }

  Widget _keyboard() {
    const rows = ['QWERTYUIOP', 'ASDFGHJKL', 'ZXCVBNM'];
    return Column(children: [
      for (var r = 0; r < rows.length; r++)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var k = 0; k < rows[r].length; k++)
                _key(rows[r][k], (r * 10 + k) % _kidRainbow.length),
              if (r == 2) _key('⌫', 5, wide: true),
            ],
          ),
        ),
    ]);
  }

  Widget _key(String ch, int ci, {bool wide = false}) {
    final color = _kidRainbow[ci];
    return GestureDetector(
      onTap: () => ch == '⌫' ? _backspace() : _type(ch),
      child: Container(
        width: wide ? 46 : 32,
        height: 42,
        margin: const EdgeInsets.symmetric(horizontal: 1.5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withOpacity(0.85),
                color.withOpacity(0.55)
              ]),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.30),
                blurRadius: 3,
                offset: const Offset(0, 2)),
          ],
        ),
        alignment: Alignment.center,
        child: Text(ch,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: Colors.white)),
      ),
    );
  }
}

import 'dart:math';

import 'package:flutter/material.dart';

import '../theme_district.dart';
import '../ui/glass.dart';
import 'board_core.dart';

// ============================================================ SET CARDS

class _SetCard {
  final int count, shape, color, fill; // each 0..2
  const _SetCard(this.count, this.shape, this.color, this.fill);
}

bool _isSet(_SetCard a, _SetCard b, _SetCard c) {
  bool ok(int x, int y, int z) =>
      (x == y && y == z) || (x != y && y != z && x != z);
  return ok(a.count, b.count, c.count) &&
      ok(a.shape, b.shape, c.shape) &&
      ok(a.color, b.color, c.color) &&
      ok(a.fill, b.fill, c.fill);
}

class SetBoard extends StatefulWidget {
  final int rating;
  final int seed;
  final BoardDone onDone;
  const SetBoard(
      {super.key,
      required this.rating,
      required this.seed,
      required this.onDone});

  @override
  State<SetBoard> createState() => _SetBoardState();
}

class _SetBoardState extends State<SetBoard> {
  late Random rng;
  late int dealSize, setsToWin;
  List<_SetCard> table = [];
  final Set<int> sel = {};
  final int start = DateTime.now().millisecondsSinceEpoch;
  int found = 0;
  int mistakes = 0;
  bool done = false;

  @override
  void initState() {
    super.initState();
    rng = Random(widget.seed);
    dealSize = widget.rating < 1300 ? 9 : (widget.rating < 1900 ? 12 : 15);
    setsToWin = widget.rating < 1300 ? 2 : 3;
    _deal();
  }

  void _deal() {
    while (true) {
      final deck = <_SetCard>[
        for (var a = 0; a < 3; a++)
          for (var b = 0; b < 3; b++)
            for (var c = 0; c < 3; c++)
              for (var d = 0; d < 3; d++) _SetCard(a, b, c, d)
      ]..shuffle(rng);
      table = deck.take(dealSize).toList();
      if (_anySet()) break;
    }
    sel.clear();
    setState(() {});
  }

  bool _anySet() {
    for (var i = 0; i < table.length; i++) {
      for (var j = i + 1; j < table.length; j++) {
        for (var k = j + 1; k < table.length; k++) {
          if (_isSet(table[i], table[j], table[k])) return true;
        }
      }
    }
    return false;
  }

  void _tap(int i) {
    if (done) return;
    setState(() => sel.contains(i) ? sel.remove(i) : sel.add(i));
    if (sel.length == 3) {
      final l = sel.toList();
      if (_isSet(table[l[0]], table[l[1]], table[l[2]])) {
        found++;
        if (found >= setsToWin) {
          done = true;
          widget.onDone(BoardResult(won: true, timeMs: elapsedSince(start)));
        } else {
          _deal();
        }
      } else {
        mistakes++;
        sel.clear();
        setState(() {});
        if (mistakes >= 3) {
          done = true;
          widget.onDone(BoardResult(won: false, timeMs: elapsedSince(start)));
        }
      }
    }
  }

  void _hint() {
    if (done || !chargeHint(context)) return;
    for (var i = 0; i < table.length; i++) {
      for (var j = i + 1; j < table.length; j++) {
        for (var k = j + 1; k < table.length; k++) {
          if (_isSet(table[i], table[j], table[k])) {
            setState(() {
              sel.clear();
              sel.add(i);
            });
            return;
          }
        }
      }
    }
  }

  List<Color> get _colors => [DC.cyan, DC.magenta, DC.amber];
  static const _shapes = [Icons.circle, Icons.square, Icons.change_history];

  @override
  Widget build(BuildContext context) {
    final cols = dealSize <= 9 ? 3 : (dealSize <= 12 ? 3 : 3);
    return Column(children: [
      BoardHud(
          title: 'SET · find $setsToWin (${found} done)',
          mistakes: mistakes,
          onHint: _hint),
      const SizedBox(height: 6),
      Text('Pick 3 cards: every feature all-same or all-different',
          style: TextStyle(fontSize: 11, color: DC.dim)),
      const SizedBox(height: 8),
      Expanded(
        child: GridView.count(
          crossAxisCount: cols,
          childAspectRatio: 1.5,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (var i = 0; i < table.length; i++) _card(i),
          ],
        ),
      ),
    ]);
  }

  Widget _card(int i) {
    final c = table[i];
    final color = _colors[c.color];
    return GestureDetector(
      onTap: () => _tap(i),
      child: Glass(
        radius: 14,
        padding: EdgeInsets.zero,
        border: Border.all(
            color: sel.contains(i) ? DC.lime : DC.fgo(0.12),
            width: sel.contains(i) ? 2 : 1),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var k = 0; k <= c.count; k++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Icon(
                    _shapes[c.shape],
                    size: 20,
                    color: color.withOpacity(
                        c.fill == 0 ? 1.0 : (c.fill == 1 ? 0.45 : 0.15)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================ RIVER CROSSING

class _RiverPuzzle {
  final String name;
  final List<String> items; // emoji entities (first = the ferryman if any)
  final int boatCap;
  final bool needsFerryman; // index 0 must be aboard to cross
  final bool Function(Set<int> bank, bool ferrymanHere) safe;
  final int par;
  const _RiverPuzzle(this.name, this.items, this.boatCap, this.needsFerryman,
      this.safe, this.par);
}

final _riverPuzzles = <_RiverPuzzle>[
  _RiverPuzzle(
    'Wolf · Goat · Cabbage',
    ['🧑‍🌾', '🐺', '🐐', '🥬'],
    2,
    true,
    (bank, fHere) {
      if (fHere) return true;
      if (bank.contains(1) && bank.contains(2)) return false; // wolf+goat
      if (bank.contains(2) && bank.contains(3)) return false; // goat+cabbage
      return true;
    },
    7,
  ),
  _RiverPuzzle(
    'Missionaries & Cannibals',
    ['🧑‍🦳', '🧑‍🦳', '🧑‍🦳', '🧟', '🧟', '🧟'],
    2,
    false,
    (bank, _) {
      final m = bank.where((i) => i < 3).length;
      final c = bank.where((i) => i >= 3).length;
      return m == 0 || m >= c;
    },
    11,
  ),
];

class RiverBoard extends StatefulWidget {
  final int rating;
  final int seed;
  final BoardDone onDone;
  const RiverBoard(
      {super.key,
      required this.rating,
      required this.seed,
      required this.onDone});

  @override
  State<RiverBoard> createState() => _RiverBoardState();
}

class _RiverBoardState extends State<RiverBoard> {
  late _RiverPuzzle p;
  late Set<int> left, right, boat;
  bool boatLeft = true;
  final int start = DateTime.now().millisecondsSinceEpoch;
  int crossings = 0;
  int fails = 0;
  bool done = false;

  @override
  void initState() {
    super.initState();
    p = _riverPuzzles[widget.rating < 1500 ? 0 : 1];
    _reset();
  }

  void _reset() {
    left = {for (var i = 0; i < p.items.length; i++) i};
    right = {};
    boat = {};
    boatLeft = true;
    setState(() {});
  }

  void _toggle(int i) {
    if (done) return;
    final bank = boatLeft ? left : right;
    setState(() {
      if (boat.contains(i)) {
        boat.remove(i);
        bank.add(i);
      } else if (bank.contains(i) && boat.length < p.boatCap) {
        bank.remove(i);
        boat.add(i);
      }
    });
  }

  void _cross() {
    if (done || boat.isEmpty) return;
    if (p.needsFerryman && !boat.contains(0)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('The farmer must row the boat!'),
          duration: Duration(milliseconds: 900)));
      return;
    }
    setState(() {
      boatLeft = !boatLeft;
      crossings++;
      final dest = boatLeft ? left : right;
      dest.addAll(boat);
      boat.clear();
    });
    // safety check on both banks
    final okL = p.safe(left, p.needsFerryman ? left.contains(0) : false);
    final okR = p.safe(right, p.needsFerryman ? right.contains(0) : false);
    if (!okL || !okR) {
      fails++;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Disaster on the bank! Resetting…'),
          duration: Duration(milliseconds: 1100)));
      if (fails >= 3) {
        done = true;
        widget.onDone(BoardResult(won: false, timeMs: elapsedSince(start)));
        return;
      }
      _reset();
      return;
    }
    if (right.length == p.items.length) {
      done = true;
      widget.onDone(BoardResult(won: true, timeMs: elapsedSince(start)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      BoardHud(
          title: p.name,
          mistakes: fails,
          extra: '$crossings crossings · par ${p.par}'),
      const SizedBox(height: 10),
      Expanded(
        child: Row(children: [
          Expanded(child: _bank(left, 'THIS BANK')),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Glass(
                radius: 16,
                padding: const EdgeInsets.all(10),
                child: Column(children: [
                  Text(boatLeft ? '⛵ ←' : '→ ⛵',
                      style: const TextStyle(fontSize: 18)),
                  const SizedBox(height: 6),
                  Wrap(children: [
                    for (final i in boat)
                      GestureDetector(
                        onTap: () => _toggle(i),
                        child: Text(p.items[i],
                            style: const TextStyle(fontSize: 26)),
                      ),
                    if (boat.isEmpty)
                      Text('· ·', style: TextStyle(color: DC.dim)),
                  ]),
                ]),
              ),
              const SizedBox(height: 10),
              NeonButton(label: 'CROSS', height: 44, onPressed: _cross),
            ],
          ),
          Expanded(child: _bank(right, 'FAR BANK')),
        ]),
      ),
      const SizedBox(height: 6),
      Text('Tap creatures to load/unload the boat',
          style: TextStyle(fontSize: 11, color: DC.dim)),
    ]);
  }

  Widget _bank(Set<int> bank, String label) {
    final isBoatSide = (label == 'THIS BANK') == boatLeft;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Glass(
        radius: 18,
        tint: isBoatSide ? DC.cyan : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label,
                style:
                    TextStyle(fontSize: 10, letterSpacing: 1.5, color: DC.dim)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              children: [
                for (final i in bank.toList()..sort())
                  GestureDetector(
                    onTap: isBoatSide ? () => _toggle(i) : null,
                    child:
                        Text(p.items[i], style: const TextStyle(fontSize: 30)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================ LOGIC GRID

class _LGPuzzle {
  final List<String> people;
  final Map<String, List<String>> attrs; // attr name -> options
  final Map<String, Map<String, String>> sol; // person -> attr -> value
  final List<String> clues;
  const _LGPuzzle(this.people, this.attrs, this.sol, this.clues);
}

const _lgPuzzles = <_LGPuzzle>[
  _LGPuzzle(
    ['Maya', 'Ravi', 'Zoe'],
    {
      'Pet': ['Cat', 'Dog', 'Parrot'],
      'Drink': ['Tea', 'Coffee', 'Juice'],
    },
    {
      'Maya': {'Pet': 'Cat', 'Drink': 'Tea'},
      'Ravi': {'Pet': 'Dog', 'Drink': 'Juice'},
      'Zoe': {'Pet': 'Parrot', 'Drink': 'Coffee'},
    },
    [
      'Ravi is allergic to cats and birds.',
      'The cat owner drinks tea.',
      'Zoe never drinks juice.',
      'Maya drinks tea.',
    ],
  ),
  _LGPuzzle(
    ['Arjun', 'Bela', 'Chen'],
    {
      'Sport': ['Cricket', 'Tennis', 'Chess'],
      'City': ['Delhi', 'Mumbai', 'Pune'],
    },
    {
      'Arjun': {'Sport': 'Tennis', 'City': 'Mumbai'},
      'Bela': {'Sport': 'Chess', 'City': 'Delhi'},
      'Chen': {'Sport': 'Cricket', 'City': 'Pune'},
    },
    [
      'The chess player lives in Delhi.',
      'Arjun doesn\'t play cricket.',
      'Chen lives in Pune.',
      'Arjun lives in Mumbai.',
    ],
  ),
  _LGPuzzle(
    ['Ira', 'Jay', 'Kavi'],
    {
      'Flavour': ['Vanilla', 'Mango', 'Chocolate'],
      'Day': ['Monday', 'Wednesday', 'Friday'],
    },
    {
      'Ira': {'Flavour': 'Mango', 'Day': 'Wednesday'},
      'Jay': {'Flavour': 'Chocolate', 'Day': 'Friday'},
      'Kavi': {'Flavour': 'Vanilla', 'Day': 'Monday'},
    },
    [
      'The vanilla lover visited on Monday.',
      'Jay hates mango.',
      'Ira went on Wednesday.',
      'Kavi didn\'t go on Friday.',
    ],
  ),
  _LGPuzzle(
    ['Dev', 'Esha', 'Farhan', 'Gia'],
    {
      'Instrument': ['Guitar', 'Piano', 'Violin', 'Drums'],
      'Floor': ['1', '2', '3', '4'],
    },
    {
      'Dev': {'Instrument': 'Guitar', 'Floor': '3'},
      'Esha': {'Instrument': 'Piano', 'Floor': '1'},
      'Farhan': {'Instrument': 'Drums', 'Floor': '4'},
      'Gia': {'Instrument': 'Violin', 'Floor': '2'},
    },
    [
      'The pianist lives on floor 1.',
      'Farhan lives on the top floor.',
      'Gia lives directly below Dev.',
      'The drummer lives on floor 4.',
      'Esha plays the piano.',
      'Gia plays the string instrument with a bow.',
    ],
  ),
];

class LogicGridBoard extends StatefulWidget {
  final int rating;
  final int seed;
  final BoardDone onDone;
  const LogicGridBoard(
      {super.key,
      required this.rating,
      required this.seed,
      required this.onDone});

  @override
  State<LogicGridBoard> createState() => _LogicGridBoardState();
}

class _LogicGridBoardState extends State<LogicGridBoard> {
  late _LGPuzzle p;
  late Map<String, Map<String, String?>> picks;
  final int start = DateTime.now().millisecondsSinceEpoch;
  int mistakes = 0;
  bool done = false;
  Set<String> wrongCells = {};

  @override
  void initState() {
    super.initState();
    final pool = widget.rating < 1400
        ? [_lgPuzzles[0]]
        : widget.rating < 1800
            ? [_lgPuzzles[1], _lgPuzzles[2]]
            : [_lgPuzzles[3]];
    p = pool[Random(widget.seed).nextInt(pool.length)];
    picks = {
      for (final person in p.people)
        person: {for (final a in p.attrs.keys) a: null}
    };
  }

  void _cycle(String person, String attr) {
    if (done) return;
    final opts = p.attrs[attr]!;
    final cur = picks[person]![attr];
    final next = cur == null
        ? opts.first
        : (opts.indexOf(cur) + 1 < opts.length
            ? opts[opts.indexOf(cur) + 1]
            : null);
    setState(() {
      picks[person]![attr] = next;
      wrongCells.remove('$person|$attr');
    });
  }

  void _check() {
    if (done) return;
    final wrong = <String>{};
    var filled = true;
    for (final person in p.people) {
      for (final a in p.attrs.keys) {
        final v = picks[person]![a];
        if (v == null) {
          filled = false;
        } else if (v != p.sol[person]![a]) {
          wrong.add('$person|$a');
        }
      }
    }
    if (!filled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Fill every cell first.'),
          duration: Duration(milliseconds: 900)));
      return;
    }
    if (wrong.isEmpty) {
      done = true;
      widget.onDone(BoardResult(won: true, timeMs: elapsedSince(start)));
    } else {
      setState(() {
        wrongCells = wrong;
        mistakes++;
      });
      if (mistakes >= 3) {
        done = true;
        widget.onDone(BoardResult(won: false, timeMs: elapsedSince(start)));
      }
    }
  }

  void _hint() {
    if (done || !chargeHint(context)) return;
    for (final person in p.people) {
      for (final a in p.attrs.keys) {
        if (picks[person]![a] != p.sol[person]![a]) {
          setState(() {
            picks[person]![a] = p.sol[person]![a];
            wrongCells.remove('$person|$a');
          });
          return;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      BoardHud(title: 'LOGIC GRID', mistakes: mistakes, onHint: _hint),
      const SizedBox(height: 10),
      Expanded(
        child: SingleChildScrollView(
          child: Column(children: [
            Glass(
              radius: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CLUES',
                      style: TextStyle(
                          fontSize: 10, letterSpacing: 2, color: DC.amber)),
                  const SizedBox(height: 6),
                  for (var i = 0; i < p.clues.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('${i + 1}. ${p.clues[i]}',
                          style: const TextStyle(fontSize: 13)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Glass(
              radius: 18,
              padding: const EdgeInsets.all(10),
              child: Table(
                columnWidths: const {0: IntrinsicColumnWidth()},
                children: [
                  TableRow(children: [
                    const SizedBox(),
                    for (final a in p.attrs.keys)
                      Padding(
                        padding: const EdgeInsets.all(4),
                        child: Text(a.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 10, letterSpacing: 1, color: DC.dim)),
                      ),
                  ]),
                  for (final person in p.people)
                    TableRow(children: [
                      Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(person,
                            style:
                                const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                      for (final a in p.attrs.keys)
                        Padding(
                          padding: const EdgeInsets.all(3),
                          child: GestureDetector(
                            onTap: () => _cycle(person, a),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: wrongCells.contains('$person|$a')
                                    ? DC.danger.withOpacity(0.35)
                                    : picks[person]![a] == null
                                        ? DC.fgo(0.04)
                                        : DC.violet.withOpacity(0.25),
                                border: Border.all(color: DC.fgo(0.12)),
                              ),
                              child: Center(
                                child: Text(picks[person]![a] ?? '—',
                                    style: const TextStyle(fontSize: 13)),
                              ),
                            ),
                          ),
                        ),
                    ]),
                ],
              ),
            ),
            const SizedBox(height: 12),
            NeonButton(label: 'CHECK SOLUTION', height: 48, onPressed: _check),
            const SizedBox(height: 8),
            Text('Tap a cell to cycle through options',
                style: TextStyle(fontSize: 11, color: DC.dim)),
          ]),
        ),
      ),
    ]);
  }
}

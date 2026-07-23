import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../core/fx.dart';
import '../core/state.dart';
import '../services/account_service.dart';
import '../theme_district.dart';
import '../ui/extras.dart';
import '../ui/glass.dart';
import 'online_play.dart';

/// ============================================================
/// SCRIBBLE ✏️ — draw & guess, skribbl-style.
/// Online 1v1: 2 rounds (you draw one, you guess one). Strokes
/// stream live through the room (~7 flushes/sec, normalized
/// coords, list-coercion-safe keys). Guess right for 100+speed
/// bonus; the artist scores 60 when their drawing gets guessed.
/// Party mode: pass-the-phone with friends in the room. IRL.
/// ============================================================

const _scribbleWords = [
  'apple',
  'guitar',
  'rocket',
  'pizza',
  'elephant',
  'rainbow',
  'castle',
  'dragon',
  'bicycle',
  'penguin',
  'volcano',
  'wizard',
  'robot',
  'ghost',
  'cactus',
  'burger',
  'spider',
  'ladder',
  'anchor',
  'trophy',
  'candle',
  'diamond',
  'octopus',
  'tornado',
  'pirate',
  'mermaid',
  'helmet',
  'igloo',
  'kite',
  'lantern',
  'mustache',
  'ninja',
  'owl',
  'palm tree',
  'question',
  'rocket ship',
  'sandwich',
  'telescope',
  'umbrella',
  'violin',
  'whale',
  'xylophone',
  'yo-yo',
  'zebra',
  'balloon',
  'campfire',
  'dolphin',
  'earring',
  'firework',
  'glasses',
  'hammock',
  'iceberg',
  'jellyfish',
  'karate',
  'lighthouse',
  'moon',
  'nest',
  'orange',
  'parachute',
  'queen',
  'rainstorm',
  'snowman',
  'tractor',
  'unicorn',
  'vampire',
  'waterfall',
  'x-ray',
  'yacht',
  'zombie',
  'airplane',
  'butterfly',
  'crown',
  'donut',
  'eagle',
  'feather',
  'giraffe',
  'harp',
  'island',
  'jungle',
  'koala',
  'lemon',
  'mountain',
  'noodles',
  'ostrich',
  'piano',
  'quilt',
  'rooster',
  'sailboat',
  'tent',
  'ufo',
  'vase',
  'windmill',
  'skeleton',
  'cricket bat',
];

class ScribbleScreen extends StatefulWidget {
  final Map<String, dynamic>? room; // null = local party mode
  final bool amHost;
  const ScribbleScreen({super.key, this.room, this.amHost = true});

  @override
  State<ScribbleScreen> createState() => _ScribbleScreenState();
}

class _ScribbleScreenState extends State<ScribbleScreen> {
  static const roundMs = 75000;
  static const rounds = 2;

  bool get isOnline => widget.room != null;
  late final String mySide = widget.amHost ? 'host' : 'guest';
  late final String oppSide = widget.amHost ? 'guest' : 'host';
  late final int seed = isOnline
      ? ((widget.room!['seed'] as num?)?.toInt() ?? 3)
      : Random().nextInt(1 << 30);

  int round = 0;
  bool get iDraw => isOnline
      ? (round == 0) == widget.amHost
      : true; // party mode: current holder draws
  String get word =>
      _scribbleWords[(seed + round * 131) % _scribbleWords.length];

  // strokes: list of polylines in normalized 0..1000 int coords
  final strokes = <List<Offset>>[];
  List<Offset> live = [];
  int _sentStrokes = 0;
  int _clearCount = 0;
  Timer? _flusher;
  Timer? _ticker;
  int? roundStartMs; // shared via room
  bool roundOver = false;
  int myScore = 0, oppScore = 0;
  bool finished = false;
  final guessCtrl = TextEditingController();
  final guesses = <String>[];
  StreamSubscription? sub;

  @override
  void initState() {
    super.initState();
    if (isOnline) {
      AccountService.instance.pinRoom(widget.room!['id'], true);
      sub = AccountService.instance
          .roomStream(widget.room!['id'])
          .listen(_onRoom);
      if (iDraw) _startRound();
      _flusher =
          Timer.periodic(const Duration(milliseconds: 140), (_) => _flush());
    } else {
      roundStartMs = DateTime.now().millisecondsSinceEpoch;
    }
    _ticker = Timer.periodic(const Duration(milliseconds: 300), (_) {
      if (roundStartMs != null && leftMs <= 0 && !roundOver && iDraw) {
        _endRound('none', 0);
      } else if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _flusher?.cancel();
    _ticker?.cancel();
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

  int get leftMs => roundStartMs == null
      ? roundMs
      : roundMs - (DateTime.now().millisecondsSinceEpoch - roundStartMs!);

  void _startRound() {
    AccountService.instance.roomWrite(widget.room!['id'], 'state/r$round/at',
        DateTime.now().millisecondsSinceEpoch);
  }

  // ---------------- online sync ----------------

  void _onRoom(Map<String, dynamic>? r) {
    if (r == null || finished || !mounted) return;
    final st = r['state'] as Map?;
    final rd = st?['r$round'] as Map?;
    // round start
    final at = (rd?['at'] as num?)?.toInt();
    if (at != null && roundStartMs == null) {
      setState(() => roundStartMs = at);
    }
    // incoming strokes (guesser side)
    if (!iDraw && rd != null) {
      final sMap = rd['s'];
      var changed = false;
      while (true) {
        final data = idxValue(sMap, strokes.length) as String?;
        if (data == null) break;
        strokes.add(_decode(data));
        changed = true;
      }
      final clr = (rd['clr'] as num?)?.toInt() ?? 0;
      if (clr > _clearCount) {
        _clearCount = clr;
        strokes.clear();
        changed = true;
      }
      if (changed) setState(() {});
    }
    // round resolution
    final win = rd?['win'] as Map?;
    if (win != null && !roundOver) {
      _applyRoundResult('${win['by']}', (win['bonus'] as num?)?.toInt() ?? 0);
    }
    if (st?['left'] == oppSide && !finished) {
      _finishMatch(forfeitWin: true);
    }
  }

  String _encode(List<Offset> pts) => pts
      .map((p) =>
          '${(p.dx * 1000).round().clamp(0, 1000)},${(p.dy * 1000).round().clamp(0, 1000)}')
      .join(';');

  List<Offset> _decode(String s) =>
      s.split(';').where((e) => e.contains(',')).map((e) {
        final xy = e.split(',');
        return Offset(int.parse(xy[0]) / 1000.0, int.parse(xy[1]) / 1000.0);
      }).toList();

  void _flush() {
    if (!isOnline || !iDraw) return;
    while (_sentStrokes < strokes.length) {
      AccountService.instance.roomWrite(widget.room!['id'],
          'state/r$round/s/m$_sentStrokes', _encode(strokes[_sentStrokes]));
      _sentStrokes++;
    }
  }

  // ---------------- drawing ----------------

  void _panStart(Offset p) {
    if (!iDraw || roundOver) return;
    live = [p];
    setState(() {});
  }

  void _panUpdate(Offset p) {
    if (!iDraw || roundOver || live.isEmpty) return;
    // thin the stream: only keep points ≥1.5% apart
    if ((p - live.last).distance > 0.015) {
      setState(() => live.add(p));
    }
  }

  void _panEnd() {
    if (!iDraw || live.length < 2) {
      live = [];
      return;
    }
    setState(() {
      strokes.add(List.of(live));
      live = [];
    });
  }

  void _clear() {
    if (!iDraw) return;
    setState(() {
      strokes.clear();
      live = [];
      _sentStrokes = 0;
    });
    if (isOnline) {
      _clearCount++;
      AccountService.instance
          .roomWrite(widget.room!['id'], 'state/r$round/s', null);
      AccountService.instance
          .roomWrite(widget.room!['id'], 'state/r$round/clr', _clearCount);
    }
  }

  // ---------------- guessing ----------------

  void _guess() {
    final g = guessCtrl.text.trim().toLowerCase();
    guessCtrl.clear();
    if (g.isEmpty || roundOver) return;
    setState(() => guesses.insert(0, g));
    if (g == word.toLowerCase()) {
      final bonus = (leftMs / 1000).round().clamp(0, 75).toInt();
      Fx.win();
      _endRound(mySide, bonus);
    } else {
      Fx.error();
    }
  }

  void _endRound(String by, int bonus) {
    if (isOnline) {
      AccountService.instance.roomWrite(
          widget.room!['id'], 'state/r$round/win', {'by': by, 'bonus': bonus});
    }
    _applyRoundResult(by, bonus);
  }

  void _applyRoundResult(String by, int bonus) {
    if (roundOver) return;
    roundOver = true;
    if (by == mySide) {
      myScore += 100 + bonus;
      oppScore += 60; // artist assist
    } else if (by == oppSide) {
      oppScore += 100 + bonus;
      myScore += 60;
    }
    setState(() {});
    Timer(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      if (round + 1 >= rounds) {
        _finishMatch();
      } else {
        setState(() {
          round++;
          roundOver = false;
          roundStartMs = null;
          strokes.clear();
          live = [];
          guesses.clear();
          _sentStrokes = 0;
          _clearCount = 0;
        });
        if (isOnline && iDraw) _startRound();
      }
    });
  }

  void _finishMatch({bool forfeitWin = false}) {
    if (finished) return;
    finished = true;
    final a = AppData.i;
    final won = forfeitWin || myScore > oppScore;
    final draw = !forfeitWin && myScore == oppScore;
    var delta = 0;
    if (isOnline) {
      final opp = Map<String, dynamic>.from(widget.room![oppSide] as Map);
      delta = a.applyElo(
          (opp['elo'] as num?)?.toInt() ?? 800, won ? 1 : (draw ? 0.5 : 0));
      a.recordMatch(
          mode: 'Scribble ✏️ online',
          opponent: '@${opp['u']}',
          result: won
              ? 'W'
              : draw
                  ? 'D'
                  : 'L',
          delta: delta);
    }
    if (won) Fx.win();
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
            Text(won ? 'PICASSO! 🏆' : (draw ? 'DRAW ✏️' : 'SKETCHED OUT'),
                style: Theme.of(context).textTheme.displayMedium),
            const SizedBox(height: 6),
            Text('You $myScore — $oppScore rival',
                style: TextStyle(color: DC.dim)),
            if (isOnline)
              Text('${delta >= 0 ? '+' : ''}$delta rating',
                  style: TextStyle(
                      color: delta >= 0 ? DC.lime : DC.danger,
                      fontWeight: FontWeight.w900,
                      fontSize: 18)),
            const SizedBox(height: 14),
            if (isOnline)
              RematchButton(room: widget.room!, amHost: widget.amHost)
            else
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
                          builder: (_) => const ScribbleScreen()));
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
    final secs = (leftMs / 1000).ceil().clamp(0, 99);
    final waitingStart = isOnline && roundStartMs == null && !iDraw;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: ShaderBackground(
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
              child: Row(children: [
                Glass(
                    radius: 16,
                    padding: const EdgeInsets.all(8),
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, size: 18)),
                const SizedBox(width: 10),
                Expanded(
                  child: Glass(
                    radius: 18,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(children: [
                      Text('R${round + 1}/$rounds',
                          style: TextStyle(fontSize: 11, color: DC.dim)),
                      const Spacer(),
                      Text('$myScore',
                          style: TextStyle(
                              fontWeight: FontWeight.w900, color: DC.cyan)),
                      Text(' — ', style: TextStyle(color: DC.dim)),
                      Text('$oppScore',
                          style: TextStyle(
                              fontWeight: FontWeight.w900, color: DC.magenta)),
                      const Spacer(),
                      Icon(Icons.timer,
                          size: 14, color: secs < 15 ? DC.danger : DC.dim),
                      Text(' $secs',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: secs < 15 ? DC.danger : DC.text)),
                    ]),
                  ),
                ),
              ]),
            ),
            // word bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Glass(
                radius: 14,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                tint: iDraw ? DC.amber : DC.violet,
                child: Row(children: [
                  Text(iDraw ? '🎨 DRAW:' : '🕵️ GUESS:',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      roundOver
                          ? word.toUpperCase()
                          : iDraw
                              ? word.toUpperCase()
                              : word
                                  .split('')
                                  .map((c) => c == ' ' ? '  ' : '▬')
                                  .join(' '),
                      style: TextStyle(
                          fontSize: iDraw || roundOver ? 16 : 12,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w900,
                          color: roundOver ? DC.lime : DC.text),
                    ),
                  ),
                  if (iDraw && !roundOver)
                    GestureDetector(
                      onTap: _clear,
                      child: Icon(Icons.delete_outline,
                          size: 20, color: DC.danger),
                    ),
                ]),
              ),
            ),
            const SizedBox(height: 8),
            // canvas
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: waitingStart
                    ? Center(
                        child: Text('Waiting for the artist to start…',
                            style: TextStyle(color: DC.dim)))
                    : LayoutBuilder(builder: (context, box) {
                        return GestureDetector(
                          onPanStart: (d) => _panStart(Offset(
                              d.localPosition.dx / box.maxWidth,
                              d.localPosition.dy / box.maxHeight)),
                          onPanUpdate: (d) => _panUpdate(Offset(
                              d.localPosition.dx / box.maxWidth,
                              d.localPosition.dy / box.maxHeight)),
                          onPanEnd: (_) => _panEnd(),
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7F3EA), // paper
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: const [
                                BoxShadow(color: Colors.black45, blurRadius: 16)
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: CustomPaint(
                                painter: _InkPainter(strokes, live),
                                size: Size.infinite,
                              ),
                            ),
                          ),
                        );
                      }),
              ),
            ),
            // guess input / status
            Padding(
              padding: const EdgeInsets.all(12),
              child: iDraw
                  ? Text(
                      roundOver
                          ? 'Round over!'
                          : 'Draw it — no letters, no numbers! ✍️',
                      style: TextStyle(fontSize: 12, color: DC.dim))
                  : Row(children: [
                      Expanded(
                        child: Glass(
                          radius: 16,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: TextField(
                            controller: guessCtrl,
                            enabled: !roundOver,
                            onSubmitted: (_) => _guess(),
                            textInputAction: TextInputAction.send,
                            decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: 'type your guess…',
                                hintStyle: TextStyle(color: DC.dim)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      NeonButton(
                          label: 'GUESS',
                          height: 46,
                          onPressed: roundOver ? null : _guess),
                    ]),
            ),
            if (!iDraw && guesses.isNotEmpty)
              SizedBox(
                height: 26,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  children: [
                    for (final g in guesses.take(10))
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text('✗ $g',
                            style: TextStyle(fontSize: 11, color: DC.dim)),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }
}

class _InkPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Offset> live;
  _InkPainter(this.strokes, this.live);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1B1A2E)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 4.5;
    void draw(List<Offset> pts) {
      if (pts.length < 2) return;
      final path = Path()
        ..moveTo(pts.first.dx * size.width, pts.first.dy * size.height);
      for (final p in pts.skip(1)) {
        path.lineTo(p.dx * size.width, p.dy * size.height);
      }
      canvas.drawPath(path, paint);
    }

    for (final s in strokes) {
      draw(s);
    }
    draw(live);
  }

  @override
  bool shouldRepaint(covariant _InkPainter old) => true;
}

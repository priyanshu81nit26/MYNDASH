import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/state.dart';
import '../theme_district.dart';
import '../ui/glass.dart';
import '../ui/share_card.dart';

/// =====================================================================
/// MYNDASH WRAPPED — Spotify-style weekly wrap-up.
///
/// A short animated intro, then a 3D swipeable deck of story cards built
/// from real 7-day (or 30-day) play data. Every card has a living aurora
/// background (drifting neon-green / blue blobs — never a flat fill), and
/// the centrepiece is the tenure TITLE card, which reveals over the
/// player's earned rank artwork (assets/mynd_cards/…). A separate JOURNEY
/// view lays those ranks out as a vertical timeline. Shareable to stories.
/// =====================================================================
class WrapScreen extends StatefulWidget {
  const WrapScreen({super.key});

  @override
  State<WrapScreen> createState() => _WrapScreenState();
}

/// Profile entry for MYNDASH Wrapped. Visible from the player's first day
/// ([AppData.wrappedUnlocked] is always true) as an animated neon tile (no
/// gift box), and for the first 2 days of each new weekly drop it pulses
/// with a "NEW DROP" badge.
class WrappedEntryTile extends StatefulWidget {
  const WrappedEntryTile({super.key});

  @override
  State<WrappedEntryTile> createState() => _WrappedEntryTileState();
}

class _WrappedEntryTileState extends State<WrappedEntryTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = AppData.i;
    if (!a.wrappedUnlocked) return const SizedBox.shrink();
    final fresh = a.wrapDropFresh;
    final title = a.myndTitle;
    final accent = title.color;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final pulse = 0.5 + 0.5 * math.sin(_c.value * 2 * math.pi);
        return GestureDetector(
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const WrapScreen())),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF0B1E3B),
                  Color.lerp(_blue, _neonGreen, pulse)!.withOpacity(0.45),
                ],
              ),
              border: Border.all(
                  color: accent.withOpacity(fresh ? 0.4 + 0.5 * pulse : 0.5)),
              boxShadow: fresh
                  ? [
                      BoxShadow(
                          color: accent.withOpacity(0.35 * pulse),
                          blurRadius: 22)
                    ]
                  : null,
            ),
            child: Row(children: [
              // little animated aurora chip instead of an emoji
              SizedBox(
                width: 40,
                height: 40,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CustomPaint(
                    painter: _AuroraPainter(
                        t: _c.value, colors: const [_cyan, _neonGreen]),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Text('MYNDASH WRAPPED',
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                color: Colors.white)),
                        if (fresh) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: accent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text('NEW DROP',
                                style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black)),
                          ),
                        ],
                      ]),
                      Text(
                          fresh
                              ? 'Your Week ${a.wrapWeekIndex + 1} recap is ready — tap to open'
                              : '${title.label} · your weekly recap & journey',
                          style: const TextStyle(
                              fontSize: 11.5,
                              color: Colors.white70,
                              fontWeight: FontWeight.w600)),
                    ]),
              ),
              Icon(Icons.chevron_right, color: accent),
            ]),
          ),
        );
      },
    );
  }
}

class _WrapStats {
  int solves = 0;
  int activeDays = 0;
  String bestDay = '—';
  int bestDayCount = 0;
  int wins = 0, losses = 0, draws = 0;
  String topMode = '—';
  List<int> perDay = const []; // oldest → newest, for the mini bar chart
}

const _neonGreen = Color(0xFF4ADE80);
const _blue = Color(0xFF2E7BFF);
const _cyan = Color(0xFF22D3EE);
const _ink = Color(0xFF07070C);

class _WrapScreenState extends State<WrapScreen> with TickerProviderStateMixin {
  bool monthly = false;
  final ctrl = PageController(viewportFraction: 0.82);
  double _pageF = 0; // live fractional page for the 3D carousel
  int page = 0;

  // Ambient drift for every aurora background — slow, always running.
  late final AnimationController _ambient =
      AnimationController(vsync: this, duration: const Duration(seconds: 12))
        ..repeat();
  // One-shot intro reveal.
  late final AnimationController _intro = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400))
    ..forward();

  final keys = List.generate(5, (_) => GlobalKey());

  @override
  void initState() {
    super.initState();
    ctrl.addListener(() {
      if (ctrl.hasClients && ctrl.page != null) {
        setState(() => _pageF = ctrl.page!);
      }
    });
    // _carousel3d reads _intro.value to fade/scale each card in, but
    // PageView.builder only calls itemBuilder again when something asks it
    // to — without this, the very first (near-zero) frame of _intro would
    // be baked in forever and the whole deck would stay invisible until a
    // scroll happened to force a rebuild. This keeps it ticking every frame
    // for the ~1.4s reveal, then goes idle once the animation completes.
    _intro.addListener(() {
      if (mounted) setState(() {});
    });
    // Mark this week's drop as seen so the profile stops featuring it.
    final a = AppData.i;
    if (a.wrapWeekIndex > a.lastWrapWeekSeen) {
      a.lastWrapWeekSeen = a.wrapWeekIndex;
      a.save();
    }
  }

  @override
  void dispose() {
    _ambient.dispose();
    _intro.dispose();
    ctrl.dispose();
    super.dispose();
  }

  _WrapStats _compute() {
    final a = AppData.i;
    final days = monthly ? 30 : 7;
    final now = DateTime.now();
    final s = _WrapStats();
    final bars = <int>[];
    for (var i = days - 1; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      final k =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      final c = a.activityOn(k);
      bars.add(c);
      if (c > 0) {
        s.solves += c;
        s.activeDays++;
        if (c > s.bestDayCount) {
          s.bestDayCount = c;
          s.bestDay = '${d.day}/${d.month}';
        }
      }
    }
    s.perDay = monthly
        ? [
            for (var i = 0; i < 7; i++)
              bars
                  .sublist(i * 4, math.min((i + 1) * 4, bars.length))
                  .fold(0, (x, y) => x + y)
          ]
        : bars;
    final cutoff = now.subtract(Duration(days: days));
    final modeCount = <String, int>{};
    for (final m in a.matches) {
      final d = DateTime.tryParse('${m['date']}');
      if (d == null || d.isBefore(cutoff)) continue;
      switch ('${m['result']}') {
        case 'W':
          s.wins++;
        case 'L':
          s.losses++;
        default:
          s.draws++;
      }
      final mode = '${m['mode']}';
      modeCount[mode] = (modeCount[mode] ?? 0) + 1;
    }
    if (modeCount.isNotEmpty) {
      s.topMode = (modeCount.entries.toList()
            ..sort((x, y) => y.value.compareTo(x.value)))
          .first
          .key;
    }
    return s;
  }

  String get _period => monthly ? 'MONTH' : 'WEEK';

  Future<void> _share(String app) async {
    final a = AppData.i;
    final s = _compute();
    await shareCardImage(
      context,
      keys[page],
      filename: 'mynd_wrapped',
      text:
          'My $_period on MYNDASH 🧠 ${s.solves} solves · ${s.wins}W ${s.losses}L · '
          '${a.myndTitle.label} in ${a.tenureDays}d. '
          'Think you can beat @${a.username}? Get MYNDASH and find out!',
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Pick $app in the share sheet to post it as your '
              '${app == 'Instagram' ? 'story' : 'status'} 📲')));
    }
  }

  static const _cardCount = 5;

  /// Builds exactly ONE story card, on demand. [PageView.builder] only ever
  /// asks for the page(s) actually on/near screen, so keeping this lazy
  /// (instead of eagerly building all 5 cards on every rebuild — including
  /// the 60fps rebuilds while dragging or during the intro reveal) avoids
  /// throwing away 3-4 unused card subtrees, each with its own
  /// CustomPaint/RepaintBoundary, every single frame.
  Widget _buildCard(
      int i, AppData a, _WrapStats s, MyndTitle title, int winRate) {
    switch (i) {
      case 0: // hero
        return _card(0, [
          const Color(0xFF0B1E3B),
          _blue,
          _cyan
        ], [
          _kicker('YOUR $_period ON'),
          const _Wordmark(),
          const Spacer(),
          _CountUp(s.solves, _intro,
              style: const TextStyle(
                  fontSize: 92,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1)),
          const Text('puzzles crushed',
              style: TextStyle(fontSize: 16, color: Colors.white70)),
          const Spacer(),
          _WeekBars(s.perDay, _cyan),
          const SizedBox(height: 12),
          _handleText(a.username),
        ]);
      case 1: // the tenure TITLE card, over its rank artwork
        return _titleCard(1, title, a.tenureDays);
      case 2: // the grind
        return _card(2, [
          const Color(0xFF07231A),
          _neonGreen,
          const Color(0xFF16A34A)
        ], [
          _kicker('THE GRIND · $_period'),
          const Spacer(),
          _statLine('${s.activeDays}', 'days active'),
          const SizedBox(height: 16),
          _statLine('${a.streak}🔥', 'day streak'),
          const SizedBox(height: 16),
          _statLine(s.bestDay, 'biggest day · ${s.bestDayCount} solves'),
          const Spacer(),
          _WeekBars(s.perDay, _neonGreen),
          const SizedBox(height: 12),
          _handleText(a.username),
        ]);
      case 3: // battles, with a win-rate ring
        return _card(3, [
          const Color(0xFF07131F),
          _cyan,
          _neonGreen
        ], [
          _kicker('BATTLES · $_period'),
          const Spacer(),
          _WinRing(winRate.toDouble(), _intro),
          const SizedBox(height: 18),
          Text('${s.wins}W   ${s.losses}L   ${s.draws}D',
              style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Colors.white)),
          const SizedBox(height: 14),
          _statLine(s.topMode, 'favourite battleground'),
          const Spacer(),
          _handleText(a.username),
        ]);
      default: // the flex
        return _card(4, [
          const Color(0xFF10122B),
          const Color(0xFF7C4DFF),
          _blue
        ], [
          _kicker('THE FLEX'),
          const Spacer(),
          Text(DC.contestTitle(a.contestRating).toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: Colors.white)),
          const SizedBox(height: 16),
          _statLine('${a.contestRating}', 'contest rating'),
          const SizedBox(height: 16),
          _statLine('${a.elo}', 'duel elo'),
          const Spacer(),
          _handleText(a.username, tail: ' · beat me if you can'),
        ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = AppData.i;
    final s = _compute();
    final title = a.myndTitle;
    final games = s.wins + s.losses + s.draws;
    final winRate = games == 0 ? 0 : (s.wins * 100 ~/ games);

    return Scaffold(
      backgroundColor: _ink,
      body: Stack(children: [
        // full-screen living backdrop tinted to the current card
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _ambient,
            builder: (_, __) => CustomPaint(
              painter: _AuroraPainter(
                t: _ambient.value,
                colors: [_blue, _neonGreen, _cyan],
                opacity: 0.20,
              ),
            ),
          ),
        ),
        SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Row(children: [
                Glass(
                    radius: 16,
                    padding: const EdgeInsets.all(8),
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back, size: 18)),
                const SizedBox(width: 12),
                const Flexible(
                  child: Text('MYNDASH WRAPPED',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                          color: Colors.white,
                          shadows: [
                            Shadow(color: Colors.black, blurRadius: 10)
                          ])),
                ),
                const Spacer(),
                // Journey timeline
                Glass(
                    radius: 16,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const JourneyScreen())),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.timeline, size: 15, color: _neonGreen),
                      const SizedBox(width: 6),
                      const Text('JOURNEY',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w800)),
                    ])),
              ]),
            ),
            const SizedBox(height: 4),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (final (label, isMonthly) in [
                ('THIS WEEK', false),
                ('THIS MONTH', true)
              ])
                GestureDetector(
                  onTap: () => setState(() => monthly = isMonthly),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: monthly == isMonthly
                          ? const LinearGradient(colors: [_blue, _neonGreen])
                          : null,
                      // Unselected pill: a solid, clearly-visible chip (not a
                      // near-invisible 10% wash) with a border so both options
                      // read as tappable.
                      color: monthly == isMonthly
                          ? null
                          : Colors.white.withOpacity(0.14),
                      border: monthly == isMonthly
                          ? null
                          : Border.all(color: Colors.white24),
                    ),
                    child: Text(label,
                        style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.white,
                            letterSpacing: 0.5,
                            fontWeight: monthly == isMonthly
                                ? FontWeight.w900
                                : FontWeight.w700,
                            shadows: monthly == isMonthly
                                ? const [
                                    Shadow(color: Colors.black45, blurRadius: 6)
                                  ]
                                : null)),
                  ),
                ),
            ]),
            const SizedBox(height: 6),
            Expanded(
              child: PageView.builder(
                controller: ctrl,
                onPageChanged: (i) => setState(() => page = i),
                itemCount: _cardCount,
                itemBuilder: (_, i) =>
                    _carousel3d(i, _buildCard(i, a, s, title, winRate)),
              ),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 0; i < _cardCount; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == page ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: i == page ? _neonGreen : Colors.white24,
                  ),
                ),
            ]),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Expanded(
                  child: NeonButton(
                    label: 'INSTAGRAM',
                    icon: Icons.camera_alt,
                    height: 48,
                    colors: const [Color(0xFFE1306C), Color(0xFF833AB4)],
                    onPressed: () => _share('Instagram'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: NeonButton(
                    label: 'WHATSAPP',
                    icon: Icons.chat,
                    height: 48,
                    colors: const [Color(0xFF25D366), Color(0xFF128C7E)],
                    onPressed: () => _share('WhatsApp'),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }

  /// Perspective tilt + scale for the card at index [i] based on its
  /// distance from the centred page — the "3D deck" feel while swiping.
  Widget _carousel3d(int i, Widget child) {
    final delta = (i - _pageF);
    final absd = delta.abs().clamp(0.0, 1.0);
    // intro: cards rise + fade in on first open
    final introT = Curves.easeOutCubic
        .transform(((_intro.value - i * 0.08).clamp(0.0, 1.0)));
    final scale = (1 - absd * 0.14) * (0.9 + 0.1 * introT);
    final rotY = delta * -0.5; // radians
    final m = Matrix4.identity()
      ..setEntry(3, 2, 0.0012)
      ..rotateY(rotY)
      ..scale(scale);
    return Opacity(
      opacity: (introT).clamp(0.0, 1.0),
      child: Transform(
        alignment: Alignment.center,
        transform: m,
        child: Transform.translate(
            offset: Offset(0, (1 - introT) * 40), child: child),
      ),
    );
  }

  // -------------------- card scaffolding --------------------

  Widget _card(int i, List<Color> palette, List<Widget> children) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        child: RepaintBoundary(
          key: keys[i],
          child: AspectRatio(
            aspectRatio: 9 / 15.5,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Stack(children: [
                Positioned.fill(child: ColoredBox(color: palette.first)),
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _ambient,
                    builder: (_, __) => CustomPaint(
                      painter: _AuroraPainter(
                          t: _ambient.value,
                          colors: palette.sublist(1),
                          opacity: 0.9),
                    ),
                  ),
                ),
                // subtle vignette for text legibility
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.10),
                          Colors.black.withOpacity(0.34)
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: children),
                ),
              ]),
            ),
          ),
        ),
      );

  /// The tenure title card — rank artwork as a z-index background, neon
  /// scrim + border, the earned title revealing on top.
  Widget _titleCard(int i, MyndTitle title, int days) {
    final next = title.next;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      child: RepaintBoundary(
        key: keys[i],
        child: AspectRatio(
          aspectRatio: 9 / 15.5,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: title.color.withOpacity(0.9), width: 2),
              boxShadow: [
                BoxShadow(color: title.color.withOpacity(0.5), blurRadius: 28)
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: Stack(fit: StackFit.expand, children: [
                // z-index background: the rank artwork
                if (title.asset.isNotEmpty)
                  Image.asset(title.asset,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => ColoredBox(color: _ink))
                else
                  const ColoredBox(color: _ink),
                // dark scrim so text pops on any artwork
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.55),
                          Colors.black.withOpacity(0.20),
                          Colors.black.withOpacity(0.82),
                        ],
                        stops: const [0, 0.45, 1],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _kicker('YOUR RANK · ${days}D ON MYNDASH'),
                      const Spacer(),
                      // the title reveals with a scale + neon glow
                      AnimatedBuilder(
                        animation: _intro,
                        builder: (_, __) {
                          final t = Curves.easeOutBack
                              .transform((_intro.value).clamp(0.0, 1.0));
                          return Transform.scale(
                            scale: 0.6 + 0.4 * t,
                            child: Opacity(
                              opacity: t.clamp(0.0, 1.0),
                              child: Text(title.label.toUpperCase(),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      fontSize: 46,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 3,
                                      color: Colors.white,
                                      shadows: [
                                        Shadow(
                                            color: title.color, blurRadius: 24),
                                      ])),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: title.color.withOpacity(0.22),
                          borderRadius: BorderRadius.circular(20),
                          border:
                              Border.all(color: title.color.withOpacity(0.8)),
                        ),
                        child: Text(
                            next == null
                                ? 'MAX RANK — legend status'
                                : '${next.days - days} days to ${next.label}',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                      ),
                      const Spacer(),
                      Text('@${AppData.i.username}',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white70)),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  // -------------------- small pieces --------------------

  Widget _kicker(String s) => Text(s,
      textAlign: TextAlign.center,
      style: const TextStyle(
          fontSize: 13,
          letterSpacing: 3,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          shadows: [Shadow(color: Colors.black54, blurRadius: 8)]));

  Widget _handleText(String u, {String tail = ''}) => Text('@$u$tail',
      style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white70));

  Widget _statLine(String value, String caption) => Column(children: [
        Text(value,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 1.1,
                shadows: [Shadow(color: Colors.black54, blurRadius: 8)])),
        Text(caption,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 13,
                color: Colors.white,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(color: Colors.black45, blurRadius: 6)])),
      ]);
}

/// MYNDASH wordmark with a neon gradient sheen.
class _Wordmark extends StatelessWidget {
  const _Wordmark();
  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (r) =>
          const LinearGradient(colors: [_cyan, _neonGreen]).createShader(r),
      child: const Text('MYNDASH',
          style: TextStyle(
              fontSize: 33,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
              color: Colors.white)),
    );
  }
}

/// Number that counts up as the intro plays.
class _CountUp extends StatelessWidget {
  final int value;
  final Animation<double> anim;
  final TextStyle style;
  const _CountUp(this.value, this.anim, {required this.style});
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) {
        final v = (value * Curves.easeOut.transform(anim.value)).round();
        return Text('$v', style: style);
      },
    );
  }
}

/// Seven mini bars for the last 7 days (or weekly buckets over a month).
class _WeekBars extends StatelessWidget {
  final List<int> counts;
  final Color color;
  const _WeekBars(this.counts, this.color);
  @override
  Widget build(BuildContext context) {
    final maxV = counts.isEmpty ? 1 : math.max(1, counts.reduce(math.max));
    return SizedBox(
      height: 46,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final c in counts)
            Container(
              width: 12,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              height: 6 + 40 * (c / maxV),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [color.withOpacity(0.55), color]),
              ),
            ),
        ],
      ),
    );
  }
}

/// Animated circular win-rate ring.
class _WinRing extends StatelessWidget {
  final double percent; // 0..100
  final Animation<double> anim;
  const _WinRing(this.percent, this.anim);
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) {
        final p = percent / 100 * Curves.easeOut.transform(anim.value);
        return SizedBox(
          width: 128,
          height: 128,
          child: CustomPaint(
            painter: _RingPainter(p),
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('${(p * 100).round()}%',
                    style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: Colors.white)),
                const Text('win rate',
                    style: TextStyle(fontSize: 12, color: Colors.white70)),
              ]),
            ),
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  final double p;
  _RingPainter(this.p);
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 8;
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = Colors.white24
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12);
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * p,
      false,
      Paint()
        ..shader = const SweepGradient(colors: [_cyan, _neonGreen, _cyan])
            .createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 12,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.p != p;
}

/// Drifting radial blobs — the "living" background so cards are never flat.
class _AuroraPainter extends CustomPainter {
  final double t; // 0..1 loop
  final List<Color> colors;
  final double opacity;
  _AuroraPainter({required this.t, required this.colors, this.opacity = 1});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    for (var i = 0; i < colors.length; i++) {
      final phase = t * 2 * math.pi + i * 2.1;
      final cx = w * (0.5 + 0.34 * math.sin(phase + i));
      final cy = h * (0.5 + 0.34 * math.cos(phase * 0.9 + i * 1.3));
      final rad = math.max(w, h) * (0.42 + 0.08 * math.sin(phase * 1.7));
      final paint = Paint()
        ..shader = RadialGradient(colors: [
          colors[i].withOpacity(0.55 * opacity),
          colors[i].withOpacity(0),
        ]).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: rad));
      canvas.drawCircle(Offset(cx, cy), rad, paint);
    }
  }

  @override
  bool shouldRepaint(_AuroraPainter old) =>
      old.t != t || old.opacity != opacity;
}

/// =====================================================================
/// JOURNEY — the four tenure ranks as a vertical timeline (not a table).
/// Reached ranks show their artwork in full colour; locked ones are
/// dimmed with the days remaining to unlock them.
/// =====================================================================
class JourneyScreen extends StatelessWidget {
  const JourneyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final a = AppData.i;
    final days = a.tenureDays;
    final tiers = MyndTitle.values.toList();
    return Scaffold(
      backgroundColor: _ink,
      body: Stack(children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _AuroraPainter(
                t: 0.2, colors: const [_blue, _neonGreen], opacity: 0.18),
          ),
        ),
        SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Row(children: [
                Glass(
                    radius: 16,
                    padding: const EdgeInsets.all(8),
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back, size: 18)),
                const SizedBox(width: 12),
                const Text('YOUR JOURNEY',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Text('Day $days on MYNDASH · ${a.myndTitle.label}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                itemCount: tiers.length,
                itemBuilder: (_, i) {
                  final t = tiers[i];
                  final reached = days >= t.days;
                  final isCurrent = a.myndTitle == t;
                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // the timeline rail
                        Column(children: [
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: reached ? t.color : Colors.white24,
                              boxShadow: isCurrent
                                  ? [BoxShadow(color: t.color, blurRadius: 14)]
                                  : null,
                            ),
                          ),
                          if (i != tiers.length - 1)
                            Expanded(
                              child: Container(
                                width: 3,
                                color: reached
                                    ? t.color.withOpacity(0.6)
                                    : Colors.white12,
                              ),
                            ),
                        ]),
                        const SizedBox(width: 14),
                        Expanded(child: _tierCard(t, reached, isCurrent, days)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _tierCard(MyndTitle t, bool reached, bool current, int days) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      height: 118,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: current
                ? t.color
                : reached
                    ? t.color.withOpacity(0.5)
                    : Colors.white12,
            width: current ? 2 : 1),
        boxShadow: current
            ? [BoxShadow(color: t.color.withOpacity(0.4), blurRadius: 18)]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Stack(fit: StackFit.expand, children: [
          // artwork thumbnail as background
          ColorFiltered(
            colorFilter: reached
                ? const ColorFilter.mode(Colors.transparent, BlendMode.multiply)
                : const ColorFilter.matrix(<double>[
                    0.2126, 0.7152, 0.0722, 0, 0, //
                    0.2126, 0.7152, 0.0722, 0, 0, //
                    0.2126, 0.7152, 0.0722, 0, 0, //
                    0, 0, 0, 1, 0,
                  ]),
            child: Image.asset(t.asset,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => ColoredBox(color: _ink)),
          ),
          // Full-card scrim, strong enough that text stays legible no matter
          // how light the artwork underneath is — not just a left-to-right
          // fade that can leave text sitting on a bright patch of the photo.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.black.withOpacity(0.92),
                    Colors.black.withOpacity(0.62),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(children: [
                  Text(t.label.toUpperCase(),
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                          color: Colors.white,
                          shadows: [
                            Shadow(color: Colors.black, blurRadius: 10),
                          ])),
                  const SizedBox(width: 8),
                  if (current)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: t.color,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('YOU',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Colors.black)),
                    )
                  else if (reached)
                    Icon(Icons.check_circle, size: 16, color: t.color),
                ]),
                const SizedBox(height: 4),
                Text(
                    reached
                        ? (t.days == 0
                            ? 'Unlocked from day one'
                            : 'Unlocked · ${t.days}+ days')
                        : '${t.days - days} days to go',
                    style: TextStyle(
                        fontSize: 12,
                        color: reached ? t.color : Colors.white70,
                        fontWeight: FontWeight.w700,
                        shadows: const [
                          Shadow(color: Colors.black, blurRadius: 8),
                        ])),
              ],
            ),
          ),
          if (!reached)
            const Positioned(
              right: 14,
              top: 14,
              child: Icon(Icons.lock, size: 16, color: Colors.white38),
            ),
        ]),
      ),
    );
  }
}

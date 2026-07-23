import 'dart:async';

import 'package:flutter/material.dart';

import '../core/fx.dart';
import '../core/state.dart';
import '../theme_district.dart';
import '../ui/default_avatar.dart';
import '../ui/glass.dart';

/// Wrapper-card colours follow the app theme (white card in Arcade, dark
/// card in Night) instead of a fixed light-only panel.
Color get _cardBg => DC.bg2;
Color get _cardInk => DC.text;
Color get _cardDim => DC.dim;

/// The one accent colour on this screen — a soft, light blue used ONLY for
/// the decorative grid wash and the START button. Avatars, the VS mark, the
/// countdown digits and "GO" stay neutral ink/white — no more colourful
/// per-side rings.
const _showdownBlue = Color(0xFF4FA8E8);
const _showdownBlueLight = Color(0xFF8ED6FF);
const _showdownBlueWash = Color(0xFFE8F3FF);

/// Faint blue grid painted once behind the card content — the only place
/// colour appears besides the START button.
class _BlueGrid extends CustomPainter {
  const _BlueGrid();
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = _showdownBlue.withOpacity(0.10)
      ..strokeWidth = 1;
    const step = 22.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant _BlueGrid oldDelegate) => false;
}

/// A pre-game "get ready" beat so matches never start cold. Two modes:
///  • VS   — 1v1 / online: "You ⚡VS  Opponent" with avatars.
///  • solo — arena / contest: "<title> STARTING".
/// [autoStart] (default true) plays a reveal + 3·2·1 countdown and launches
/// on its own (~2s) — used online, where both sides are already paired.
/// [autoStart]=false parks after the reveal on a START button instead, so a
/// bot/friend match only launches when the player is actually ready.
class ShowdownScreen extends StatefulWidget {
  final String title; // e.g. '1V1 DUEL', 'ARENA', 'CONTEST'
  final String youName;
  final String youAvatarB64;
  final String? oppName; // null → solo "starting" mode
  final String? detail; // e.g. "10 min per side" — shown under the VS
  final bool autoStart;
  final Widget Function() game;

  const ShowdownScreen({
    super.key,
    required this.title,
    required this.youName,
    required this.game,
    this.youAvatarB64 = '',
    this.oppName,
    this.detail,
    this.autoStart = true,
  });

  /// Convenience: push the showdown, then the game replaces it.
  static void go(
    BuildContext context, {
    required String title,
    String? oppName,
    String? detail,
    bool autoStart = true,
    required Widget Function() game,
    bool replace = false,
  }) {
    final a = AppData.i;
    final route = MaterialPageRoute<void>(
      builder: (_) => ShowdownScreen(
        title: title,
        youName: a.username.isEmpty ? a.name : a.username,
        youAvatarB64: a.avatarB64,
        oppName: oppName,
        detail: detail,
        autoStart: autoStart,
        game: game,
      ),
    );
    if (replace) {
      Navigator.pushReplacement(context, route);
    } else {
      Navigator.push(context, route);
    }
  }

  @override
  State<ShowdownScreen> createState() => _ShowdownScreenState();
}

class _ShowdownScreenState extends State<ShowdownScreen>
    with TickerProviderStateMixin {
  // Reveal: avatars slide in, VS/title fade in. Plays once, 0 → 1.
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1300))
    ..forward();
  // Digit "pop": replayed from 0 each time the countdown advances, so every
  // digit gets its own clean scale-in instead of one animation stretched
  // (or compressed) across the whole 3·2·1·GO sequence.
  late final AnimationController _pulseC = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 260));

  bool _launched = false;
  bool _waitingForTap = false;
  // null = countdown hasn't started; 0/1/2/3 = '3'/'2'/'1'/'GO'.
  int? _countStep;
  Timer? _countTimer;

  static const _labels = ['3', '2', '1', 'GO'];
  // Real gaps between digits — the old version compressed the whole
  // countdown into under 2s by resuming a shared animation partway through.
  static const _stepMs = [750, 700, 650, 500]; // hold time for 3 / 2 / 1 / GO

  @override
  void initState() {
    super.initState();
    Fx.impact();
    _c.addStatusListener((s) {
      if (s != AnimationStatus.completed || !mounted) return;
      if (widget.autoStart) {
        _beginCountdown();
      } else {
        setState(() => _waitingForTap = true);
      }
    });
  }

  void _start() {
    setState(() => _waitingForTap = false);
    _beginCountdown();
  }

  void _beginCountdown() {
    setState(() => _countStep = 0);
    _pulseC.forward(from: 0);
    Fx.impact();
    _countTimer = Timer(Duration(milliseconds: _stepMs[0]), _advanceCountdown);
  }

  void _advanceCountdown() {
    if (!mounted || _launched) return;
    final next = (_countStep ?? 0) + 1;
    if (next >= _labels.length) {
      _launch();
      return;
    }
    setState(() => _countStep = next);
    _pulseC.forward(from: 0);
    Fx.impact();
    _countTimer =
        Timer(Duration(milliseconds: _stepMs[next]), _advanceCountdown);
  }

  void _launch() {
    _launched = true;
    Fx.success();
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => widget.game()));
  }

  @override
  void dispose() {
    _countTimer?.cancel();
    _pulseC.dispose();
    _c.dispose();
    super.dispose();
  }

  double _seg(double t, double a, double b) =>
      ((t - a) / (b - a)).clamp(0.0, 1.0);

  Widget _fighter(
      String name, String avatarB64, double slide, bool fromLeft) {
    return Transform.translate(
      offset: Offset((fromLeft ? -1 : 1) * (1 - slide) * 120, 0),
      child: Opacity(
        opacity: slide,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 88,
            height: 88,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _cardBg,
              border: Border.all(color: DC.fgo(0.5), width: 2),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.18), blurRadius: 16),
              ],
            ),
            child: ProfileAvatar(avatarB64: avatarB64, name: name, size: 82),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 110,
            child: Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: _cardInk)),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vs = widget.oppName != null;
    // Themed backdrop behind a centered light wrapper-card (not full-screen).
    return Scaffold(
      body: ShaderBackground(
        child: SafeArea(
          child: Center(
            child: AnimatedBuilder(
              animation: Listenable.merge([_c, _pulseC]),
              builder: (context, _) {
                final t = _c.value;
                final titleIn = _seg(t, 0.0, 0.3);
                final slideL =
                    Curves.easeOutBack.transform(_seg(t, 0.15, 0.65));
                final slideR = Curves.easeOutBack.transform(_seg(t, 0.3, 0.8));
                // Each digit gets its own scale-in "pop" via _pulseC,
                // replayed fresh on every step instead of one animation
                // stretched across the whole countdown.
                final label = _countStep == null ? '' : _labels[_countStep!];
                final numScale =
                    1.5 - 0.5 * Curves.easeOut.transform(_pulseC.value);

                return Container(
                  width: 340,
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: _cardBg,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(0.28),
                          blurRadius: 40,
                          offset: const Offset(0, 16)),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(children: [
                    // Soft blue wash + faint grid — the only colour on the
                    // card besides the START button.
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              _showdownBlueWash
                                  .withOpacity(ThemeCtl.isDark ? 0.05 : 0.5),
                              _showdownBlueWash.withOpacity(0),
                            ],
                          ),
                        ),
                        child: const CustomPaint(painter: _BlueGrid()),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 32),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Opacity(
                          opacity: titleIn,
                          child: Text(widget.title,
                              style: const TextStyle(
                                  fontSize: 12,
                                  letterSpacing: 4,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF7C4DFF))),
                        ),
                        const SizedBox(height: 22),
                        if (vs)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _fighter(widget.youName, widget.youAvatarB64,
                                  slideL, true),
                              Opacity(
                                opacity: _seg(t, 0.45, 0.7),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.bolt,
                                          size: 22, color: _showdownBlue),
                                      Text('VS',
                                          style: TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.w900,
                                              color: _cardInk)),
                                    ]),
                              ),
                              _fighter(widget.oppName!, '', slideR, false),
                            ],
                          )
                        else
                          Opacity(
                            opacity: _seg(t, 0.2, 0.6),
                            child: const MyndArtless(),
                          ),
                        if (widget.detail != null) ...[
                          const SizedBox(height: 12),
                          Opacity(
                            opacity: _seg(t, 0.35, 0.7),
                            child: Text(widget.detail!,
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1,
                                    color: _cardDim)),
                          ),
                        ],
                        const SizedBox(height: 28),
                        if (_waitingForTap)
                          _StartButton(onTap: _start)
                        else if (_countStep != null) ...[
                          Transform.scale(
                            scale: numScale,
                            child: Text(label,
                                style: TextStyle(
                                    fontSize: 52,
                                    fontWeight: FontWeight.w900,
                                    color: label == 'GO'
                                        ? const Color(0xFF16A34A)
                                        : _cardInk)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                              vs
                                  ? 'get ready…'
                                  : '${widget.title.toLowerCase()} is starting…',
                              style: TextStyle(fontSize: 12, color: _cardDim)),
                        ] else
                          // Reveal still playing (autoStart) — countdown begins
                          // the instant it completes, so this holds the layout's
                          // height steady without flashing any text.
                          const SizedBox(height: 66),
                      ]),
                    ),
                  ]),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Plain Material/InkWell button — deliberately simple (no custom Stack or
/// AnimatedPositioned) so its tap target is exactly its bounds with zero
/// room for a gesture-arena surprise. This is the one action that MUST
/// always land a tap.
class _StartButton extends StatelessWidget {
  final VoidCallback onTap;
  const _StartButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(26),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [_showdownBlueLight, _showdownBlue]),
            borderRadius: BorderRadius.circular(26),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(26),
            onTap: onTap,
            child: const Center(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
                SizedBox(width: 8),
                Text('START',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        letterSpacing: 1.0)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small decorative flourish for the solo (arena/contest) mode.
class MyndArtless extends StatelessWidget {
  const MyndArtless({super.key});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: Center(
        child: Icon(Icons.stadium_rounded, size: 64, color: DC.amber),
      ),
    );
  }
}

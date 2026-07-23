import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme_district.dart';

const _myndGreen = Color(0xFF16A34A);
const _introDuration = Duration(milliseconds: 4600);
const _reducedIntroDuration = Duration(milliseconds: 900);

bool _welcomeDone = false;

/// Re-arm the cold-start sequence after sign-out or account switching.
void resetWelcome() => _welcomeDone = false;

double _segment(double value, double start, double end) =>
    ((value - start) / (end - start)).clamp(0.0, 1.0);

class WelcomeGate extends StatefulWidget {
  final Widget child;

  const WelcomeGate({super.key, required this.child});

  @override
  State<WelcomeGate> createState() => _WelcomeGateState();
}

class _WelcomeGateState extends State<WelcomeGate>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  bool _show = !_welcomeDone;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    if (!_show) return;
    _welcomeDone = true;
    _controller = AnimationController(vsync: this);
    _controller!.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _show = false);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_show || _started || _controller == null) return;
    _started = true;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    _controller!
      ..duration = reduceMotion ? _reducedIntroDuration : _introDuration
      ..forward();
  }

  void _skip() {
    if (!_show) return;
    _controller?.stop();
    setState(() => _show = false);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animation = _controller ?? kAlwaysCompleteAnimation;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final progress = _show ? animation.value : 1.0;
        final reveal = Curves.easeOutCubic.transform(
          _segment(progress, 0.78, 1),
        );
        final homeOpacity = _show ? reveal : 1.0;
        final homeBlur = _show ? (1 - reveal) * 18 : 0.0;
        final homeScale = _show ? 0.97 + reveal * 0.03 : 1.0;

        // This hierarchy never changes when the intro completes. Keeping the
        // dashboard in a stable slot avoids destroying and rebuilding it at
        // the exact moment it becomes visible.
        return Stack(
          fit: StackFit.expand,
          children: [
            ExcludeSemantics(
              excluding: _show,
              child: IgnorePointer(
                ignoring: _show,
                child: Opacity(
                  opacity: homeOpacity,
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(
                      sigmaX: homeBlur,
                      sigmaY: homeBlur,
                    ),
                    child: Transform.scale(
                      scale: homeScale,
                      child: KeyedSubtree(
                        key: const ValueKey('welcome-home'),
                        child: widget.child,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_show)
              Positioned.fill(
                child: _WelcomeAnimation(
                  key: const ValueKey('welcome-intro'),
                  progress: progress,
                  onSkip: _skip,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _WelcomeAnimation extends StatelessWidget {
  final double progress;
  final VoidCallback onSkip;

  const _WelcomeAnimation({
    super.key,
    required this.progress,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.height < 650;
    final centerY = size.height * (compact ? 0.45 : 0.47);

    // One continuous story: arrive → charge → launch → become the MYNDASH mark
    // → reveal the already-mounted dashboard.
    final arrival = Curves.easeOutBack.transform(
      _segment(progress, 0.02, 0.19),
    );
    final settle = _segment(progress, 0.16, 0.36);
    final charge = Curves.easeInOutCubic.transform(
      _segment(progress, 0.30, 0.46),
    );
    final launch = Curves.easeInCubic.transform(
      _segment(progress, 0.43, 0.64),
    );
    final plateIn = Curves.easeOutBack.transform(
      _segment(progress, 0.58, 0.73),
    );
    final wordIn = Curves.easeOutCubic.transform(
      _segment(progress, 0.65, 0.82),
    );
    final handoff = Curves.easeInOutCubic.transform(
      _segment(progress, 0.78, 1),
    );

    final hover = math.sin(settle * math.pi * 3) *
        math.exp(-2.8 * settle) *
        10 *
        (1 - launch);
    final rocketY =
        centerY - (1 - arrival) * 150 + hover - launch * (size.height * 0.84);
    final rocketOpacity =
        (arrival * (1 - _segment(progress, 0.59, 0.68))).clamp(0.0, 1.0);
    final overlayOpacity = (1 - handoff).clamp(0.0, 1.0);
    final brandOpacity =
        (math.min(plateIn, wordIn) * (1 - handoff)).clamp(0.0, 1.0);

    return Semantics(
      label: 'MYNDASH launch intro',
      child: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: overlayOpacity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              RepaintBoundary(
                child: CustomPaint(
                  painter: _AtmospherePainter(
                    progress: progress,
                    charge: charge,
                    launch: launch,
                    handoff: handoff,
                    center: Offset(size.width / 2, centerY),
                  ),
                ),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: _ExhaustPainter(
                    x: size.width / 2,
                    nozzle: rocketY + (compact ? 45 : 55),
                    charge: charge,
                    launch: launch,
                    progress: progress,
                    fade: 1 - _segment(progress, 0.60, 0.68),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: rocketY - (compact ? 58 : 68),
                child: Opacity(
                  opacity: rocketOpacity,
                  child: Center(
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.0012)
                        ..rotateY(math.sin(progress * math.pi * 3) * 0.075)
                        ..rotateZ(
                          math.sin(settle * math.pi * 2) * 0.045 * (1 - launch),
                        )
                        ..scale(
                          0.72 + arrival * 0.28 - launch * 0.08,
                          0.78 + arrival * 0.22 + launch * 0.13,
                        ),
                      child: SizedBox(
                        width: compact ? 96 : 112,
                        height: compact ? 128 : 148,
                        child: CustomPaint(
                          painter: _PremiumRocketPainter(
                            shine: (progress * 2.1) % 1,
                            power: math.max(charge, launch),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment(0, compact ? -0.03 : -0.06),
                child: Opacity(
                  opacity: brandOpacity,
                  child: Transform.translate(
                    offset: Offset(0, (1 - wordIn) * 22 - handoff * 12),
                    child: Transform.scale(
                      scale: 0.91 + plateIn * 0.09 + handoff * 0.025,
                      child: _GlassMyndPlate(
                        plateProgress: plateIn,
                        wordProgress: wordIn,
                        shine: _segment(progress, 0.70, 0.96),
                        compact: compact,
                      ),
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Opacity(
                      opacity: (Curves.easeOut.transform(
                                _segment(progress, 0.08, 0.18),
                              ) *
                              (1 - handoff))
                          .clamp(0.0, 1.0),
                      child: _SkipButton(onPressed: onSkip),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkipButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _SkipButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Skip MYNDASH intro',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: TextButton(
            key: const ValueKey('welcome-skip'),
            onPressed: onPressed,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF1F2937),
              backgroundColor: Colors.white.withOpacity(0.82),
              minimumSize: const Size(64, 48),
              padding: const EdgeInsets.symmetric(horizontal: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: Colors.black.withOpacity(0.08)),
              ),
            ),
            child: const Text(
              'SKIP',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassMyndPlate extends StatelessWidget {
  final double plateProgress;
  final double wordProgress;
  final double shine;
  final bool compact;

  const _GlassMyndPlate({
    required this.plateProgress,
    required this.wordProgress,
    required this.shine,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final maxWidth = math.min(MediaQuery.sizeOf(context).width - 40, 370.0);
    // Hug the wordmark instead of a fixed-width pill, so the padding is even
    // and symmetric around MYNDASH rather than floating it in an oversized box.
    return ConstrainedBox(
      key: const ValueKey('welcome-glass-brand'),
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: IntrinsicWidth(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(34),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.98),
                const Color(0xFFEAF8F0).withOpacity(0.96),
                const Color(0xFFF2F8FF).withOpacity(0.94),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: _myndGreen.withOpacity(0.16 * plateProgress),
                blurRadius: 38,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: const Color(0xFF64748B).withOpacity(0.16),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(1.2),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(33),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                child: Stack(
                  children: [
                    Container(
                      // Balanced padding around the single MYNDASH wordmark now
                      // that the tagline below it is gone — equal on all sides.
                      padding: EdgeInsets.symmetric(
                        horizontal: 26,
                        vertical: compact ? 22 : 28,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(33),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.88),
                            const Color(0xFFF4FBF7).withOpacity(0.82),
                            const Color(0xFFEDF6FF).withOpacity(0.78),
                          ],
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _BrandBackdropPainter(progress: shine),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Scale the wordmark down to fit narrow screens
                              // so the 7-letter word never overflows the pill.
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: _AnimatedWordmark(
                                  progress: wordProgress,
                                  shine: shine,
                                  compact: compact,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _GlassSheenPainter(progress: shine),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedWordmark extends StatelessWidget {
  final double progress;
  final double shine;
  final bool compact;

  const _AnimatedWordmark({
    required this.progress,
    required this.shine,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    const letters = ['M', 'Y', 'N', 'D', 'A', 'S', 'H'];
    final word = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < letters.length; index++) ...[
          Builder(builder: (context) {
            final local = Curves.easeOutBack.transform(
              _segment(progress, index * 0.06, 0.42 + index * 0.06),
            );
            return Opacity(
              opacity: local.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, (1 - local) * 22),
                child: Transform.scale(
                  scale: 0.82 + local * 0.18,
                  child: Text(
                    letters[index],
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: compact ? 34 : 42,
                      height: 0.92,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                      decoration: TextDecoration.none,
                      shadows: [
                        Shadow(
                          color: _myndGreen.withOpacity(0.45 * local),
                          blurRadius: 24,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          if (index != letters.length - 1) SizedBox(width: compact ? 2.5 : 3.5),
        ],
      ],
    );

    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) {
        final travel = -1.8 + shine * 3.6;
        return LinearGradient(
          begin: Alignment(travel - 0.65, -0.4),
          end: Alignment(travel + 0.65, 0.4),
          colors: const [
            Color(0xFF075E2B),
            Color(0xFF129447),
            Color(0xFF63D991),
            Color(0xFF129447),
            Color(0xFF075E2B),
          ],
          stops: [0, 0.32, 0.5, 0.68, 1],
        ).createShader(bounds);
      },
      child: word,
    );
  }
}

class _AtmospherePainter extends CustomPainter {
  final double progress;
  final double charge;
  final double launch;
  final double handoff;
  final Offset center;

  const _AtmospherePainter({
    required this.progress,
    required this.charge,
    required this.launch,
    required this.handoff,
    required this.center,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [
            Color(0xFFFFFFFF),
            Color(0xFFF8FCFA),
            Color(0xFFEDF7F1),
          ],
        ).createShader(bounds),
    );

    void glow(Offset at, double radius, Color color, double opacity) {
      canvas.drawCircle(
        at,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withOpacity(opacity),
              color.withOpacity(0),
            ],
          ).createShader(Rect.fromCircle(center: at, radius: radius)),
      );
    }

    glow(
      Offset(size.width * 0.15, size.height * 0.20),
      size.width * 0.62,
      const Color(0xFFB8D9FF),
      0.22 * (1 - handoff),
    );
    glow(
      Offset(size.width * 0.86, size.height * 0.73),
      size.width * 0.70,
      const Color(0xFFA7E8C2),
      0.20 * (1 - handoff),
    );
    glow(
      center.translate(0, 82),
      90 + charge * 80,
      const Color(0xFF86DDAA),
      (0.08 + charge * 0.14) * (1 - launch),
    );

    final starPaint = Paint();
    for (var i = 0; i < 32; i++) {
      final x = ((i * 83) % 101) / 101 * size.width;
      final y = ((i * 47) % 97) / 97 * size.height;
      final twinkle =
          0.04 + 0.08 * (0.5 + 0.5 * math.sin(progress * 18 + i * 1.7));
      starPaint.color = (i.isEven ? _myndGreen : const Color(0xFF4FA8E8))
          .withOpacity(twinkle * (1 - handoff));
      canvas.drawCircle(Offset(x, y), i % 5 == 0 ? 1.35 : 0.7, starPaint);
    }

    final padCenter = center.translate(0, 82);
    final padFade = (1 - launch * 1.7).clamp(0.0, 1.0);
    canvas.drawOval(
      Rect.fromCenter(
        center: padCenter.translate(0, 14),
        width: 190 + charge * 32,
        height: 34 + charge * 8,
      ),
      Paint()
        ..color = const Color(0xFF64748B).withOpacity(0.20 * padFade)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: padCenter,
        width: 154 + charge * 22,
        height: 35 + charge * 7,
      ),
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withOpacity(0.82),
            _myndGreen.withOpacity(0.24 * padFade),
            Colors.white.withOpacity(0.58),
          ],
        ).createShader(Rect.fromCenter(
          center: padCenter,
          width: 180,
          height: 44,
        )),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: padCenter,
        width: 164 + charge * 28,
        height: 42 + charge * 10,
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = const Color(0xFF64748B).withOpacity(0.20 * padFade),
    );

    if (launch > 0) {
      for (var ring = 0; ring < 3; ring++) {
        final ringProgress = ((launch * 1.45) - ring * 0.18).clamp(0.0, 1.0);
        if (ringProgress == 0) continue;
        canvas.drawOval(
          Rect.fromCenter(
            center: padCenter,
            width: 160 + ringProgress * size.width * 0.75,
            height: 40 + ringProgress * 95,
          ),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2 * (1 - ringProgress)
            ..color = _myndGreen.withOpacity(
              0.28 * (1 - ringProgress) * (1 - handoff),
            ),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_AtmospherePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.charge != charge ||
      oldDelegate.launch != launch ||
      oldDelegate.handoff != handoff ||
      oldDelegate.center != center;
}

class _PremiumRocketPainter extends CustomPainter {
  final double shine;
  final double power;

  const _PremiumRocketPainter({
    required this.shine,
    required this.power,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final bodyRect = Rect.fromCenter(
      center: center.translate(0, -3),
      width: size.width * 0.49,
      height: size.height * 0.74,
    );
    final body = Path()
      ..moveTo(center.dx, bodyRect.top - 12)
      ..cubicTo(
        bodyRect.right + 8,
        bodyRect.top + 22,
        bodyRect.right + 5,
        bodyRect.bottom - 16,
        center.dx,
        bodyRect.bottom,
      )
      ..cubicTo(
        bodyRect.left - 5,
        bodyRect.bottom - 16,
        bodyRect.left - 8,
        bodyRect.top + 22,
        center.dx,
        bodyRect.top - 12,
      )
      ..close();

    canvas.drawCircle(
      center.translate(0, 8),
      size.width * 0.48,
      Paint()
        ..color = DC.cyan.withOpacity(0.10 + power * 0.10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
    );
    canvas.drawShadow(
        body, const Color(0xFF64748B).withOpacity(0.38), 18, true);
    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFF536171),
            Color(0xFFDCE6F1),
            Color(0xFFFFFFFF),
            Color(0xFF9DABB9),
            Color(0xFF3D4856),
          ],
          stops: [0, 0.20, 0.46, 0.75, 1],
        ).createShader(bodyRect),
    );

    final nose = Path()
      ..moveTo(center.dx, bodyRect.top - 12)
      ..cubicTo(
        bodyRect.right - 2,
        bodyRect.top + 10,
        bodyRect.right,
        bodyRect.top + 20,
        bodyRect.right,
        bodyRect.top + 27,
      )
      ..lineTo(bodyRect.left, bodyRect.top + 27)
      ..cubicTo(
        bodyRect.left,
        bodyRect.top + 19,
        bodyRect.left + 3,
        bodyRect.top + 9,
        center.dx,
        bodyRect.top - 12,
      )
      ..close();
    canvas.drawPath(
      nose,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [DC.cyan, Color(0xFFBDF7FF), DC.violet],
        ).createShader(nose.getBounds()),
    );

    final leftFin = Path()
      ..moveTo(bodyRect.left + 6, bodyRect.bottom - 36)
      ..lineTo(bodyRect.left - 20, bodyRect.bottom + 7)
      ..lineTo(center.dx - 6, bodyRect.bottom - 3)
      ..close();
    final rightFin = Path()
      ..moveTo(bodyRect.right - 6, bodyRect.bottom - 36)
      ..lineTo(bodyRect.right + 20, bodyRect.bottom + 7)
      ..lineTo(center.dx + 6, bodyRect.bottom - 3)
      ..close();
    final finPaint = Paint()
      ..shader = LinearGradient(
        colors: [Color(0xFF4338CA), DC.violet, DC.magenta],
      ).createShader(Rect.fromLTRB(
        bodyRect.left - 20,
        bodyRect.bottom - 36,
        bodyRect.right + 20,
        bodyRect.bottom + 8,
      ));
    canvas
      ..drawPath(leftFin, finPaint)
      ..drawPath(rightFin, finPaint);

    final windowCenter = Offset(center.dx, bodyRect.top + 39);
    canvas.drawCircle(
      windowCenter,
      15,
      Paint()
        ..color = const Color(0xFF0B1220)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawCircle(
      windowCenter,
      12.5,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.42, -0.45),
          colors: const [
            Colors.white,
            Color(0xFF67E8F9),
            Color(0xFF0369A1),
            Color(0xFF07111F),
          ],
        ).createShader(
          Rect.fromCircle(center: windowCenter, radius: 13),
        ),
    );
    canvas.drawCircle(
      windowCenter,
      13.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = Colors.white.withOpacity(0.42),
    );

    final badge = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center.translate(0, 23),
        width: bodyRect.width * 0.86,
        height: 18,
      ),
      const Radius.circular(9),
    );
    canvas.drawRRect(badge, Paint()..color = const Color(0xFF07120C));
    final badgeText = TextPainter(
      text: const TextSpan(
        text: 'MYNDASH',
        style: TextStyle(
          color: _myndGreen,
          fontSize: 6,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.3,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    badgeText.paint(
      canvas,
      badge.center - Offset(badgeText.width / 2, badgeText.height / 2),
    );

    final shineX = bodyRect.left - 8 + (bodyRect.width + 16) * shine;
    canvas.save();
    canvas.clipPath(body);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(shineX, center.dy),
          width: 10,
          height: bodyRect.height * 0.88,
        ),
        const Radius.circular(8),
      ),
      Paint()
        ..color = Colors.white.withOpacity(0.20 + power * 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PremiumRocketPainter oldDelegate) =>
      oldDelegate.shine != shine || oldDelegate.power != power;
}

class _ExhaustPainter extends CustomPainter {
  final double x;
  final double nozzle;
  final double charge;
  final double launch;
  final double progress;
  final double fade;

  const _ExhaustPainter({
    required this.x,
    required this.nozzle,
    required this.charge,
    required this.launch,
    required this.progress,
    required this.fade,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final power = math.max(charge * 0.52, launch) * fade;
    if (power <= 0.02) return;

    final coreLength = 18 + charge * 35 + launch * size.height * 0.36;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x, nozzle + coreLength / 2),
          width: 12 + power * 10,
          height: coreLength,
        ),
        const Radius.circular(18),
      ),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white,
            Color(0xFFFFF176),
            Color(0xFFFF8A00),
            Color(0x00FF3B30),
          ],
        ).createShader(
          Rect.fromLTWH(x - 15, nozzle, 30, coreLength),
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );

    final plume = 34 + charge * 46 + launch * size.height * 0.56;
    for (var index = 0; index < 46; index++) {
      final seed = ((index * 37) % 101) / 101;
      final travel = (progress * 14 + seed) % 1.0;
      final y = nozzle + travel * plume;
      final spread = 3 + travel * (15 + launch * 24);
      final px = x +
          math.sin(index * 2.31 + progress * 55) *
              spread *
              (0.35 + power * 0.65);
      final radius = (9 - travel * 6.8) * (0.5 + power * 0.72);
      final color = travel < 0.22
          ? const Color(0xFFFFF7B2)
          : travel < 0.50
              ? const Color(0xFFFFA21A)
              : travel < 0.74
                  ? const Color(0xFFFF3B30)
                  : const Color(0xFF8793A3);
      canvas.drawCircle(
        Offset(px, y),
        radius,
        Paint()
          ..color = color.withOpacity((1 - travel) * power * 0.82)
          ..maskFilter = travel < 0.74
              ? const MaskFilter.blur(BlurStyle.normal, 2)
              : const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }

    if (launch > 0.08) {
      for (var index = 0; index < 12; index++) {
        final seed = ((index * 53) % 103) / 103;
        final travel = (progress * 4 + seed) % 1.0;
        canvas.drawCircle(
          Offset(
            x + math.sin(index * 1.7 + travel * 4) * (12 + travel * 42),
            nozzle + 50 + travel * launch * size.height * 0.72,
          ),
          10 + travel * 18,
          Paint()
            ..color = const Color(0xFF9AA3B2)
                .withOpacity((1 - travel) * 0.12 * launch)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_ExhaustPainter oldDelegate) =>
      oldDelegate.x != x ||
      oldDelegate.nozzle != nozzle ||
      oldDelegate.charge != charge ||
      oldDelegate.launch != launch ||
      oldDelegate.progress != progress ||
      oldDelegate.fade != fade;
}

class _BrandBackdropPainter extends CustomPainter {
  final double progress;

  const _BrandBackdropPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final drift = math.sin(progress * math.pi * 2);
    final lift = math.cos(progress * math.pi * 2);
    final left = Offset(
      size.width * (0.22 + drift * 0.06),
      size.height * (0.26 + lift * 0.08),
    );
    final right = Offset(
      size.width * (0.80 - drift * 0.05),
      size.height * (0.76 - lift * 0.06),
    );

    void glow(Offset center, double radius, Color color) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withOpacity(0.20),
              color.withOpacity(0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    glow(left, size.width * 0.42, const Color(0xFF67D391));
    glow(right, size.width * 0.38, const Color(0xFF8BC5F5));
  }

  @override
  bool shouldRepaint(_BrandBackdropPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _GlassSheenPainter extends CustomPainter {
  final double progress;

  const _GlassSheenPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final x = -size.width * 0.55 + progress * size.width * 2.1;
    final sheen = Path()
      ..moveTo(x - 42, 0)
      ..lineTo(x + 10, 0)
      ..lineTo(x + 82, size.height)
      ..lineTo(x + 28, size.height)
      ..close();
    canvas.drawPath(
      sheen,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withOpacity(0),
            Colors.white.withOpacity(0.16),
            Colors.white.withOpacity(0),
          ],
        ).createShader(Offset.zero & size)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
  }

  @override
  bool shouldRepaint(_GlassSheenPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

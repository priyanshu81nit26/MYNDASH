import 'package:flutter/material.dart';

import '../core/fx.dart';
import '../theme_district.dart';

/// ---------------- Static arena background ----------------
/// PERF: the old animated fragment-shader background repainted at
/// 30fps forever, draining battery and dragging every screen down.
/// This version paints ONCE — a static gradient + decorative glow —
/// and never ticks again. Same class name, zero call-site changes.
class ShaderBackground extends StatelessWidget {
  final Widget child;
  const ShaderBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // Cross-fade the two backdrops by the animated theme position. At rest
    // (t == 0 or 1) only one is painted, so pushed screens pay no extra cost.
    final t = ThemeCtl.t.value;
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (t < 1)
                Opacity(opacity: 1 - t, child: const _ArcadeBackdrop()),
              if (t > 0) Opacity(opacity: t, child: const _NightBackdrop()),
            ],
          ),
        ),
        child,
      ],
    );
  }
}

/// Dark "Night" — deep space with faint static neon glows.
class _NightBackdrop extends StatelessWidget {
  const _NightBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-0.6, -0.8),
          radius: 1.6,
          colors: [Color(0xFF16102E), Color(0xFF050507)],
        ),
      ),
      child: IgnorePointer(
        child: Stack(children: [
          _blob(
              const Color(0xFF7C4DFF), const Alignment(-0.9, -0.9), 260, 0.16),
          _blob(const Color(0xFF00E5FF), const Alignment(1.0, -0.2), 200, 0.10),
          _blob(const Color(0xFFFF2E92), const Alignment(0.6, 1.0), 240, 0.10),
        ]),
      ),
    );
  }
}

/// Light "Arcade" — clean white with a soft grid + pastel glows.
class _ArcadeBackdrop extends StatelessWidget {
  const _ArcadeBackdrop();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF4F6FB),
      child: IgnorePointer(
        child: Stack(children: [
          const Positioned.fill(
            child: CustomPaint(painter: _GridPainter()),
          ),
          _blob(
              const Color(0xFF6A3DE8), const Alignment(-1.0, -1.0), 300, 0.07),
          _blob(const Color(0xFF0097C7), const Alignment(1.1, -0.4), 240, 0.06),
          _blob(const Color(0xFFE0197D), const Alignment(0.8, 1.1), 260, 0.05),
        ]),
      ),
    );
  }
}

Widget _blob(Color c, Alignment a, double size, double opacity) => Align(
      alignment: a,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
              colors: [c.withOpacity(opacity), c.withOpacity(0)]),
        ),
      ),
    );

/// Faint retro grid — painted once, arcade vibes for the light theme.
class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFF6A3DE8).withOpacity(0.045)
      ..strokeWidth = 1;
    const step = 36.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => false;
}

/// ---------------- 3D press effect ----------------
/// Every tappable surface sinks 2–3px into the page while pressed —
/// a physical "button push" instead of a flat ripple.
class Press3D extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double depth;
  const Press3D({super.key, required this.child, this.onTap, this.depth = 3});

  @override
  State<Press3D> createState() => _Press3DState();
}

class _Press3DState extends State<Press3D> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null) return widget.child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapCancel: () => _set(false),
      onTapUp: (_) => _set(false),
      onTap: () {
        Fx.tap();
        widget.onTap!();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _down ? widget.depth : 0, 0)
          ..scale(_down ? 0.98 : 1.0),
        transformAlignment: Alignment.center,
        child: widget.child,
      ),
    );
  }
}

/// ---------------- Card primitive ----------------
/// PERF: no more BackdropFilter blur (one of the most expensive ops
/// in Flutter — it forced a full-screen readback per card). Cards are
/// now cheap solid/translucent surfaces styled per theme.
class Glass extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? tint;
  final VoidCallback? onTap;
  final Border? border;

  const Glass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 26,
    this.tint,
    this.onTap,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final dark = ThemeCtl.isDark;
    final base = tint ?? (dark ? Colors.white : DC.violet);
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: dark ? null : Colors.white,
        gradient: dark
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [base.withOpacity(0.09), base.withOpacity(0.03)],
              )
            : null,
        border: border ??
            Border.all(
                color: dark
                    ? Colors.white.withOpacity(0.10)
                    : base.withOpacity(0.14),
                width: 1),
        boxShadow: dark
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF2A2F55).withOpacity(0.07),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
      ),
      child: child,
    );
    if (onTap == null) return card;
    return Press3D(onTap: onTap, child: card);
  }
}

class Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback? onTap;
  const Pill(
      {super.key,
      required this.icon,
      required this.label,
      this.color,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = color ?? DC.cyan;
    return Glass(
      onTap: onTap,
      radius: 30,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: c),
        const SizedBox(width: 6),
        Text(label,
            style:
                TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 13)),
      ]),
    );
  }
}

/// Gradient action button with a real 3D edge: the face sits on a
/// darker base and physically sinks into it while pressed.
class NeonButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final List<Color>? colors;
  final double height;

  const NeonButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.colors,
    this.height = 56,
  });

  @override
  State<NeonButton> createState() => _NeonButtonState();
}

class _NeonButtonState extends State<NeonButton> {
  bool _down = false;
  static const _edge = 5.0;

  @override
  Widget build(BuildContext context) {
    final cs = widget.colors ?? [DC.violet, DC.cyan];
    final enabled = widget.onPressed != null;
    final r = BorderRadius.circular(widget.height / 2);
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: enabled ? 1 : 0.4,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: enabled
            ? () {
                Fx.tap();
                widget.onPressed!();
              }
            : null,
        child: LayoutBuilder(builder: (context, c) {
          final label = Row(mainAxisSize: MainAxisSize.min, children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
            ],
            Text(widget.label,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    letterSpacing: 1.0)),
          ]);
          // Unbounded width (an inflexible child in a Row, e.g. the journey
          // "current level" cards) — a Stack of only positioned children
          // can't take infinite width, so size to the label instead. The
          // darker bottom border keeps the 3D read.
          if (!c.maxWidth.isFinite) {
            return Padding(
              padding: EdgeInsets.only(
                  top: _down ? _edge : 0, bottom: _down ? 0 : _edge),
              child: Container(
                height: widget.height,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: cs),
                  borderRadius: r,
                  border: Border(
                      bottom: BorderSide(
                          color: Color.lerp(cs.first, Colors.black, 0.45)!,
                          width: _edge)),
                ),
                child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [SizedBox(height: widget.height), label]),
              ),
            );
          }
          // Bounded width — fill it with the full 3D stack.
          return SizedBox(
            height: widget.height + _edge,
            child: Stack(children: [
              // darker 3D base edge
              Positioned(
                left: 0,
                right: 0,
                top: _edge,
                height: widget.height,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: r,
                    color: Color.lerp(cs.first, Colors.black, 0.45),
                  ),
                ),
              ),
              // face — sinks onto the base while pressed
              AnimatedPositioned(
                duration: const Duration(milliseconds: 70),
                curve: Curves.easeOut,
                left: 0,
                right: 0,
                top: _down ? _edge : 0,
                height: widget.height,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: cs),
                    borderRadius: r,
                    boxShadow: enabled && !_down
                        ? [
                            BoxShadow(
                                color: cs.first
                                    .withOpacity(ThemeCtl.isDark ? 0.4 : 0.3),
                                blurRadius: 14,
                                offset: const Offset(0, 6))
                          ]
                        : null,
                  ),
                  child: Center(child: label),
                ),
              ),
            ]),
          );
        }),
      ),
    );
  }
}

class GhostButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final double height;
  const GhostButton(
      {super.key,
      required this.label,
      this.icon,
      this.onPressed,
      this.height = 52});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Glass(
        onTap: onPressed,
        radius: height / 2,
        padding: EdgeInsets.zero,
        child: Center(
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: DC.text),
              const SizedBox(width: 8),
            ],
            Text(label,
                style: TextStyle(
                    color: DC.text, fontWeight: FontWeight.w700, fontSize: 14)),
          ]),
        ),
      ),
    );
  }
}

/// Stat chip used across results/headers.
class StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const StatChip(
      {super.key, required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Glass(
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(value,
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: color ?? DC.text)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(fontSize: 10, color: DC.dim, letterSpacing: 1.0)),
      ]),
    );
  }
}

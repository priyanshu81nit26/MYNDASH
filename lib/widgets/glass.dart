import 'package:flutter/material.dart';
import '../theme.dart';

/// ------------------------- Glass card -------------------------
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blur;
  final Color? tint;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 24,
    this.blur = 18,
    this.tint,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = tint ?? Colors.white;
    // PERF: no BackdropFilter blur — plain translucent surface.
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [base.withOpacity(0.10), base.withOpacity(0.04)]
              : [
                  Colors.white.withOpacity(0.92),
                  Colors.white.withOpacity(0.78)
                ],
        ),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.16)
              : Colors.white.withOpacity(0.9),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.35 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, child: card);
  }
}

/// ------------------------- Buttons -------------------------
class NeonButton extends StatelessWidget {
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
    this.height = 58,
  });

  @override
  Widget build(BuildContext context) {
    final cs = colors ?? [RDColors.cyan, RDColors.violet];
    final enabled = onPressed != null;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: cs),
            borderRadius: BorderRadius.circular(height / 2),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: cs.first.withOpacity(0.45),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    )
                  ]
                : null,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(height / 2),
            onTap: onPressed,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                  ],
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GlassButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final double height;

  const GlassButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.height = 58,
  });

  @override
  Widget build(BuildContext context) {
    final onBg = Theme.of(context).colorScheme.onSurface;
    return SizedBox(
      height: height,
      child: GlassCard(
        radius: height / 2,
        padding: EdgeInsets.zero,
        onTap: onPressed,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: onBg, size: 20),
                const SizedBox(width: 10),
              ],
              Text(
                label,
                style: TextStyle(
                  color: onBg,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ------------------- Static aurora background -------------------
/// PERF: previously animated 3 gradient blobs at 60fps forever,
/// repainting the whole screen. Now painted once — same look, no cost.
class AuroraBackground extends StatelessWidget {
  final Widget child;
  const AuroraBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [RDColors.darkBg1, RDColors.darkBg2]
              : [RDColors.lightBg1, RDColors.lightBg2],
        ),
      ),
      child: Stack(
        children: [
          RepaintBoundary(
            child: IgnorePointer(
              child: Stack(
                children: [
                  _blob(context, RDColors.violet, 260,
                      const Alignment(-0.7, -0.85)),
                  _blob(
                      context, RDColors.cyan, 220, const Alignment(0.95, -0.1)),
                  _blob(context, RDColors.magenta, 240,
                      const Alignment(0.6, 0.95)),
                ],
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }

  Widget _blob(BuildContext context, Color c, double size, Alignment a) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Align(
      alignment: a,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [
            c.withOpacity(isDark ? 0.30 : 0.20),
            c.withOpacity(0),
          ]),
        ),
      ),
    );
  }
}

/// ------------------------- Small helpers -------------------------
class ScorePill extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const ScorePill(
      {super.key, required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final onBg = Theme.of(context).colorScheme.onSurface;
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      radius: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: color ?? onBg)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: onBg.withOpacity(0.6),
                  letterSpacing: 0.5)),
        ],
      ),
    );
  }
}

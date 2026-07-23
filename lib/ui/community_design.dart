import 'package:flutter/material.dart';

import '../theme_district.dart';

/// Semantic green + sky-blue identity shared by Squad, College and Corporate.
class CommunityColors {
  CommunityColors._();

  static Color get mint =>
      ThemeCtl.isDark ? const Color(0xFF6EF2BA) : const Color(0xFF087F5B);
  static Color get sky =>
      ThemeCtl.isDark ? const Color(0xFF67D7FF) : const Color(0xFF087EAF);
  static Color get mintSoft =>
      ThemeCtl.isDark ? const Color(0xFF102A25) : const Color(0xFFE4F8EF);
  static Color get skySoft =>
      ThemeCtl.isDark ? const Color(0xFF0C2732) : const Color(0xFFE4F5FC);
  static Color get surface =>
      ThemeCtl.isDark ? const Color(0xFF091315) : const Color(0xFFFCFFFE);
  static Color get border =>
      ThemeCtl.isDark ? const Color(0xFF28484B) : const Color(0xFFB9DFD7);

  static List<Color> get heroGradient => ThemeCtl.isDark
      ? const [
          Color(0xFF123E33),
          Color(0xFF0D3445),
          Color(0xFF081116),
        ]
      : const [
          Color(0xFFC9F6DF),
          Color(0xFFC8EEFC),
          Color(0xFFF9FFFC),
        ];

  static List<Color> get actionGradient => [mint, sky];
}

class CommunityBackdrop extends StatelessWidget {
  const CommunityBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: DC.bg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0x08087F5B),
                    Colors.transparent,
                    Color(0x08087EAF),
                  ],
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  top: -110,
                  right: -100,
                  child: _GlowOrb(
                    color: CommunityColors.sky,
                    size: 270,
                  ),
                ),
                Positioned(
                  left: -120,
                  bottom: -90,
                  child: _GlowOrb(
                    color: CommunityColors.mint,
                    size: 290,
                  ),
                ),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: ThemeCtl.isDark ? 0.14 : 0.09),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

class CommunityPageHeader extends StatelessWidget {
  const CommunityPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 48,
          height: 48,
          child: Material(
            color: CommunityColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: CommunityColors.border),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.maybePop(context),
              child: const Icon(Icons.arrow_back_rounded, size: 20),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: DC.dim,
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing!,
        ],
      ],
    );
  }
}

class CommunityIconButton extends StatelessWidget {
  const CommunityIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(icon, color: CommunityColors.sky),
        style: IconButton.styleFrom(
          backgroundColor: CommunityColors.surface,
          side: BorderSide(color: CommunityColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class CommunityHeroCard extends StatelessWidget {
  const CommunityHeroCard({
    super.key,
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.metrics = const [],
    this.action,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String subtitle;
  final List<Widget> metrics;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: CommunityColors.heroGradient,
        ),
        border: Border.all(
          color: CommunityColors.mint.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: ThemeCtl.isDark
            ? null
            : [
                BoxShadow(
                  color: CommunityColors.sky.withValues(alpha: 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient:
                      LinearGradient(colors: CommunityColors.actionGradient),
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eyebrow,
                      style: TextStyle(
                        color: CommunityColors.mint,
                        fontSize: 10,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontSize: 22),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: TextStyle(color: DC.dim, fontSize: 13, height: 1.5),
          ),
          if (metrics.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: metrics),
          ],
          if (action != null) ...[
            const SizedBox(height: 16),
            action!,
          ],
        ],
      ),
    );
  }
}

class CommunityMetric extends StatelessWidget {
  const CommunityMetric({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? CommunityColors.mint;
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: ThemeCtl.isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: accent, size: 17),
          const SizedBox(width: 7),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(label, style: TextStyle(color: DC.dim, fontSize: 9.5)),
            ],
          ),
        ],
      ),
    );
  }
}

class CommunityCard extends StatelessWidget {
  const CommunityCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String status;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final accent = primary ? CommunityColors.mint : CommunityColors.sky;
    return Semantics(
      button: true,
      label: '$title. $subtitle. $status',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: CommunityColors.surface,
            border: Border.all(color: CommunityColors.border),
            boxShadow: ThemeCtl.isDark
                ? null
                : [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 7),
                    ),
                  ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(17),
                      color: accent.withValues(alpha: 0.12),
                    ),
                    child: Icon(icon, color: accent, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  color: accent,
                                  fontSize: 9,
                                  letterSpacing: 0.8,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: DC.dim,
                            fontSize: 11.5,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.chevron_right_rounded, color: accent),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CommunitySectionTitle extends StatelessWidget {
  const CommunitySectionTitle({
    super.key,
    required this.icon,
    required this.title,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: CommunityColors.mint, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: DC.dim,
              fontSize: 10.5,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

InputDecoration communityInputDecoration({
  required String label,
  required String hint,
  required IconData icon,
  String? helper,
}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(18),
    borderSide: BorderSide(color: CommunityColors.border),
  );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    helperText: helper,
    helperMaxLines: 2,
    prefixIcon: Icon(icon, color: CommunityColors.sky),
    filled: true,
    fillColor: ThemeCtl.isDark
        ? CommunityColors.surface
        : CommunityColors.skySoft.withValues(alpha: 0.55),
    border: border,
    enabledBorder: border,
    focusedBorder: border.copyWith(
      borderSide: BorderSide(color: CommunityColors.sky, width: 1.7),
    ),
  );
}

EdgeInsets communityPagePadding(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  final horizontal = width >= 900
      ? (width - 780) / 2
      : width >= 600
          ? 32.0
          : 20.0;
  return EdgeInsets.fromLTRB(horizontal, 16, horizontal, 32);
}

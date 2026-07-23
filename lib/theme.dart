import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Reflex Duel design system — premium glassy look, light & dark.
class RDColors {
  // Brand
  static const cyan = Color(0xFF00E5FF);
  static const magenta = Color(0xFFFF2E92);
  static const violet = Color(0xFF7C4DFF);
  static const lime = Color(0xFF69F0AE);
  static const amber = Color(0xFFFFC400);
  static const danger = Color(0xFFFF5252);

  // Dark scaffold
  static const darkBg1 = Color(0xFF0A0E21);
  static const darkBg2 = Color(0xFF141A38);
  // Light scaffold
  static const lightBg1 = Color(0xFFEDF1FB);
  static const lightBg2 = Color(0xFFDCE6F7);
}

class RDTheme {
  static ThemeData dark() => _base(Brightness.dark);
  static ThemeData light() => _base(Brightness.light);

  static ThemeData _base(Brightness b) {
    final isDark = b == Brightness.dark;
    final onBg = isDark ? Colors.white : const Color(0xFF16213E);
    final scheme = ColorScheme(
      brightness: b,
      primary: RDColors.cyan,
      onPrimary: const Color(0xFF00303A),
      secondary: RDColors.magenta,
      onSecondary: Colors.white,
      tertiary: RDColors.violet,
      onTertiary: Colors.white,
      error: RDColors.danger,
      onError: Colors.white,
      surface: isDark ? RDColors.darkBg2 : Colors.white,
      onSurface: onBg,
    );

    final text = GoogleFonts.interTextTheme(
      isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
    ).apply(bodyColor: onBg, displayColor: onBg);

    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark ? RDColors.darkBg1 : RDColors.lightBg1,
      textTheme: text.copyWith(
        displayLarge: GoogleFonts.orbitron(
            fontSize: 40, fontWeight: FontWeight.w800, color: onBg),
        displayMedium: GoogleFonts.orbitron(
            fontSize: 28, fontWeight: FontWeight.w700, color: onBg),
        titleLarge: GoogleFonts.orbitron(
            fontSize: 20, fontWeight: FontWeight.w600, color: onBg),
      ),
      splashFactory: InkRipple.splashFactory,
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? RDColors.darkBg2 : Colors.white,
        contentTextStyle: TextStyle(color: onBg),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

/// Rank tiers driven by XP.
class Rank {
  final String name;
  final Color color;
  final int minXp;
  const Rank(this.name, this.color, this.minXp);

  static const tiers = [
    Rank('Bronze', Color(0xFFCD7F32), 0),
    Rank('Silver', Color(0xFFB8C4D0), 500),
    Rank('Gold', Color(0xFFFFC400), 1500),
    Rank('Diamond', Color(0xFF00E5FF), 3500),
    Rank('Legend', Color(0xFFFF2E92), 7000),
  ];

  static Rank forXp(int xp) =>
      tiers.lastWhere((t) => xp >= t.minXp, orElse: () => tiers.first);

  static Rank? next(int xp) {
    for (final t in tiers) {
      if (xp < t.minXp) return t;
    }
    return null;
  }
}

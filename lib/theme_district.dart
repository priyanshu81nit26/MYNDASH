import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ============================================================
/// Theme controller — Light "Arcade" (default) & Dark "Night".
/// Persisted across launches; toggling rebuilds the whole app.
/// ============================================================
class ThemeCtl {
  ThemeCtl._();

  /// 0 = light (Arcade), 1 = dark (Night).
  static final ValueNotifier<int> mode = ValueNotifier(0);

  /// Animated position between themes (0.0 = Arcade, 1.0 = Night).
  /// Driven by the root app's AnimationController so every DC color
  /// cross-fades instead of snapping. Boolean call sites still use [mode].
  static final ValueNotifier<double> t = ValueNotifier(0);

  static bool get isDark => mode.value == 1;
  static bool get isLight => mode.value == 0;

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    mode.value = p.getInt('themeMode') ?? 0; // light by default
    t.value = mode.value.toDouble();
  }

  static Future<void> set(int m) async {
    mode.value = m;
    final p = await SharedPreferences.getInstance();
    await p.setInt('themeMode', m);
  }

  static Future<void> toggle() => set(isDark ? 0 : 1);
}

/// DISTRICT design system — theme-aware palette.
/// Every color adapts to the active theme; call sites never change.
class DC {
  static bool get _d => ThemeCtl.isDark;

  /// Cross-fade a light→dark color pair by the animated theme position.
  static Color _lerp(Color light, Color dark) =>
      Color.lerp(light, dark, ThemeCtl.t.value)!;

  // ---------------- scaffold ----------------
  static Color get bg =>
      _lerp(const Color(0xFFF4F6FB), const Color(0xFF050507));
  static Color get bg2 => _lerp(Colors.white, const Color(0xFF0B0B12));

  // ---------------- ink ----------------
  static Color get text =>
      _lerp(const Color(0xFF171B2D), const Color(0xFFF2F3F8));
  static Color get dim =>
      _lerp(const Color(0xFF6A7086), const Color(0xFF8A8FA3));

  /// Subtle foreground tints (replaces Colors.whiteXX so borders,
  /// dividers and placeholders stay visible on the light theme).
  static Color get fg => _lerp(const Color(0xFF171B2D), Colors.white);
  static Color fgo(double o) => fg.withOpacity(o);
  static Color get fg10 => fgo(0.06);
  static Color get fg12 => fgo(0.10);
  static Color get fg24 => fgo(0.20);
  static Color get fg38 => fgo(0.34);
  static Color get fg54 => fgo(0.50);
  static Color get fg70 => fgo(0.68);

  // ---------------- neon accents ----------------
  // Dark keeps the original neon; light uses deepened arcade shades
  // that stay readable on white.
  static Color get cyan =>
      _lerp(const Color(0xFF0097C7), const Color(0xFF00E5FF));
  static Color get violet =>
      _lerp(const Color(0xFF6A3DE8), const Color(0xFF7C4DFF));
  static Color get magenta =>
      _lerp(const Color(0xFFE0197D), const Color(0xFFFF2E92));
  static Color get lime =>
      _lerp(const Color(0xFF00A05A), const Color(0xFF69F0AE));
  static Color get amber =>
      _lerp(const Color(0xFFC98A00), const Color(0xFFFFC400));
  static Color get danger =>
      _lerp(const Color(0xFFD93636), const Color(0xFFFF5252));

  /// Vibrant electric blue — the MYNDASH wordmark color.
  static Color get electric =>
      _lerp(const Color(0xFF1F5FE0), const Color(0xFF2E7BFF));

  /// MYNDASH wordmark: blue on the light theme, neon green on the dark theme.
  static Color get wordmark =>
      _lerp(const Color(0xFF1F5FE0), const Color(0xFF16E37F));

  /// Rating band color (chess.com-style identity).
  static Color band(int rating) {
    if (rating < 1000) return const Color(0xFFCD7F32); // novice bronze
    if (rating < 1300)
      return _d ? const Color(0xFFB8C4D0) : const Color(0xFF7E8CA0);
    if (rating < 1600) return amber; // skilled gold
    if (rating < 1900) return cyan; // expert
    if (rating < 2200) return violet; // master
    return magenta; // grandmaster
  }

  static String bandName(int rating) {
    if (rating < 1000) return 'Novice';
    if (rating < 1300) return 'Learner';
    if (rating < 1600) return 'Skilled';
    if (rating < 1900) return 'Expert';
    if (rating < 2200) return 'Master';
    return 'Grandmaster';
  }

  /// Contest titles — earned in weekly contests (rating starts at 1500).
  static String contestTitle(int r) {
    if (r < 1700) return 'Beginner';
    if (r < 1900) return 'Specialist';
    if (r < 2100) return 'Expert';
    if (r < 2300) return 'Master';
    if (r < 2600) return 'Candidate Master';
    if (r < 2900) return 'Chakra';
    return 'Trishul';
  }

  static Color contestColor(int r) {
    if (r < 1700) return const Color(0xFF9E9E9E);
    if (r < 1900) return lime;
    if (r < 2100) return cyan;
    if (r < 2300) return amber;
    if (r < 2600) return violet;
    if (r < 2900) return magenta;
    return const Color(0xFFFF6D00); // Trishul — burning orange
  }
}

ThemeData districtTheme() {
  final dark = ThemeCtl.isDark;
  final base = dark ? ThemeData.dark().textTheme : ThemeData.light().textTheme;
  final text = GoogleFonts.interTextTheme(base)
      .apply(bodyColor: DC.text, displayColor: DC.text);
  return ThemeData(
    useMaterial3: true,
    brightness: dark ? Brightness.dark : Brightness.light,
    scaffoldBackgroundColor: DC.bg,
    colorScheme: dark
        ? ColorScheme.dark(
            primary: DC.cyan,
            onPrimary: const Color(0xFF00272E),
            secondary: DC.magenta,
            onSecondary: Colors.white,
            tertiary: DC.violet,
            surface: DC.bg2,
            onSurface: DC.text,
            error: DC.danger,
          )
        : ColorScheme.light(
            primary: DC.electric,
            onPrimary: Colors.white,
            secondary: DC.magenta,
            onSecondary: Colors.white,
            tertiary: DC.violet,
            surface: DC.bg2,
            onSurface: DC.text,
            error: DC.danger,
          ),
    textTheme: text.copyWith(
      displayLarge: GoogleFonts.spaceGrotesk(
          fontSize: 38, fontWeight: FontWeight.w700, color: DC.text),
      displayMedium: GoogleFonts.spaceGrotesk(
          fontSize: 26, fontWeight: FontWeight.w700, color: DC.text),
      titleLarge: GoogleFonts.spaceGrotesk(
          fontSize: 19, fontWeight: FontWeight.w600, color: DC.text),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: DC.bg2,
      surfaceTintColor: Colors.transparent,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? DC.bg2 : const Color(0xFF23283E),
      contentTextStyle: TextStyle(color: dark ? DC.text : Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}

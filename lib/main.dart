import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_state.dart';
import 'core/state.dart';
import 'firebase_options.dart';
import 'screens/district_home.dart';
import 'screens/kid_home.dart';
import 'screens/onboarding.dart';
import 'screens/welcome_screen.dart';
import 'services/account_service.dart';
import 'services/firebase_service.dart';
import 'theme_district.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Theme (light "Arcade" by default; user can toggle to dark "Night")
  await ThemeCtl.load();

  // DISTRICT platform data (coins, levels, streaks, orders)
  await AppData.i.load();
  // Anchor account age on first launch (drives tenure titles + Wrapped).
  AppData.i.seedFirstOpen();

  // Reflex Duel online layer (Firebase) — optional until configured
  final app = AppState.instance;
  app.prefs = await SharedPreferences.getInstance();
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    // Local disk cache + offline queue: moves render instantly from
    // cache and writes flush the moment the radio wakes up.
    if (!kIsWeb) {
      try {
        FirebaseDatabase.instanceFor(
                app: Firebase.app(),
                databaseURL: DefaultFirebaseOptions.currentPlatform.databaseURL)
            .setPersistenceEnabled(true);
      } catch (_) {/* already started elsewhere */}
    }
    await FirebaseService.instance.init();
    app.online = true;
    // admin devices mirror the question banks into /banks (fire & forget)
    AccountService.instance.maybeSeedBanks();
    app.profile = await FirebaseService.instance.loadProfile();
  } catch (e) {
    debugPrint('Reflex online mode off (see README to connect Firebase): $e');
  }
  app.restoreLocal();
  app.profile.name = AppData.i.name;

  runApp(const DistrictApp());
}

class DistrictApp extends StatefulWidget {
  const DistrictApp({super.key});

  @override
  State<DistrictApp> createState() => _DistrictAppState();
}

class _DistrictAppState extends State<DistrictApp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
    value: ThemeCtl.mode.value.toDouble(),
  );
  late final Animation<double> _curve =
      CurvedAnimation(parent: _c, curve: Curves.easeInOutCubic);

  @override
  void initState() {
    super.initState();
    _curve.addListener(() => ThemeCtl.t.value = _curve.value);
    ThemeCtl.mode.addListener(_onMode);
  }

  void _onMode() => _c.animateTo(ThemeCtl.mode.value.toDouble());

  @override
  void dispose() {
    ThemeCtl.mode.removeListener(_onMode);
    _c.dispose();
    super.dispose();
  }

  // First run → intro pages → auth → unique username → home.
  // Built fresh each frame so the home shell re-reads the cross-fading colors.
  Widget _start() {
    final a = AppData.i;
    // Non-const: while the theme animates, AnimatedBuilder rebuilds these so
    // their subtrees re-read the cross-fading DC colors (State is preserved).
    if (!a.onboarded) return OnboardingFlow();
    if (a.username.length < 6) return UsernameScreen();
    // WelcomeGate plays a one-time intro on cold start / first account,
    // then reveals the home underneath. Non-const so the home still
    // rebuilds with the cross-fading theme colors.
    if (a.kidMode) {
      return WelcomeGate(child: KidHomeScreen()); // under-12 zone
    }
    return WelcomeGate(child: DistrictHome());
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, _) => MaterialApp(
        title: 'MYNDASH',
        debugShowCheckedModeBanner: false,
        theme: districtTheme(),
        scrollBehavior: _SpringScroll(),
        builder: _mobileFrame,
        home: _start(),
      ),
    );
  }

  /// The whole app is designed for a phone-width portrait canvas. On wide
  /// (desktop web) viewports, frame it in a centered mobile column so
  /// Row/Expanded layouts get a bounded width instead of stretching — or,
  /// worse, collapsing an Expanded to zero (text wrapping one char per line).
  static Widget _mobileFrame(BuildContext context, Widget? child) {
    // Web-only: native Android/iOS builds never get framed/clipped, even on
    // a wide tablet screen — this wrapper exists purely for desktop-web.
    if (!kIsWeb) return child!;
    final mq = MediaQuery.of(context);
    if (mq.size.width <= 600) return child!; // narrow web: use the full screen
    const framedWidth = 460.0;
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: ClipRect(
          child: SizedBox(
            width: framedWidth,
            // Descendants must see the FRAMED width, not the full window —
            // otherwise MediaQuery-based layout (e.g. communityPagePadding)
            // computes padding for a 1440px screen inside a 460px box and
            // collapses the content to zero (text wrapping one char per line).
            child: MediaQuery(
              data: mq.copyWith(size: Size(framedWidth, mq.size.height)),
              child: child!,
            ),
          ),
        ),
      ),
    );
  }
}

/// App-wide iOS-style spring over-scroll on every scroll view, so pages
/// bounce back instead of resting on empty space.
class _SpringScroll extends MaterialScrollBehavior {
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
}

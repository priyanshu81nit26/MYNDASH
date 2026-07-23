import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/state.dart';
import '../services/account_service.dart';
import '../theme_district.dart';
import '../ui/glass.dart';
import 'district_home.dart';
import 'kid_home.dart';
import 'welcome_screen.dart';
import 'legal.dart';

/// =====================================================================
/// FIRST-RUN FLOW:  intro pages → sign in / create → verify → username
/// =====================================================================

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  final _page = PageController();
  int index = 0;

  static const _pages = <(IconData, String, String)>[
    (
      Icons.psychology_rounded,
      'Welcome to MYNDASH',
      'The mind arena. One app where puzzles are a sport — '
          'and your brain is the athlete.'
    ),
    (
      Icons.extension_rounded,
      'Train 25 disciplines',
      'Sudoku, Minesweeper, KenKen, mental math, logic riddles… '
          'levels from 800 to 2500, each with live validation and hints.'
    ),
    (
      Icons.sports_esports_rounded,
      'A full games arcade',
      'Real chess on a real board, flick-to-throw darts, a true 3D '
          'Rubik\'s cube, Scribble, Word Finder, Art Heist and Reflex Duel.'
    ),
    (
      Icons.bolt_rounded,
      'Compete every day',
      '5 daily challenges, 1v1 duels, 8-player arenas with entry fees '
          'and prize pots — plus live drops twice a day, worldwide.'
    ),
    (
      Icons.groups_rounded,
      'Squad up',
      'Build a squad of 10 minds, rep your college or company, and clash '
          'in SQUAD MANIA — the monthly inter-squad war.'
    ),
    (
      Icons.emoji_events_rounded,
      'Rise through the titles',
      'Weekly contests every Saturday & Sunday. Climb from Beginner '
          'to Chakra to the legendary Trishul — and spend winnings in the store.'
    ),
    (
      Icons.auto_awesome_rounded,
      'Made for every mind',
      'Under-12s get MYNDASH KIDS — fun brain games, kid squads and a nightly '
          '8PM drop. And everyone picks their vibe: Arcade or Night.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ShaderBackground(
        child: SafeArea(
          child: Column(children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _toAuth,
                child: Text('Skip', style: TextStyle(color: DC.dim)),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _page,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => index = i),
                itemBuilder: (context, i) {
                  final (icon, title, body) = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Hero3D(icon: icon),
                        const SizedBox(height: 28),
                        ShaderMask(
                          shaderCallback: (r) =>
                              LinearGradient(colors: [DC.cyan, DC.magenta])
                                  .createShader(r),
                          child: Text(title,
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .displayMedium
                                  ?.copyWith(color: Colors.white)),
                        ),
                        const SizedBox(height: 14),
                        Text(body,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: DC.dim, fontSize: 15, height: 1.6)),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 0; i < _pages.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: index == i ? 26 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: index == i ? DC.cyan : DC.fg24,
                  ),
                ),
            ]),
            Padding(
              padding: const EdgeInsets.all(24),
              child: NeonButton(
                label: index == _pages.length - 1 ? 'GET STARTED' : 'NEXT',
                icon: index == _pages.length - 1
                    ? Icons.rocket_launch
                    : Icons.arrow_forward,
                onPressed: () {
                  if (index == _pages.length - 1) {
                    _toAuth();
                  } else {
                    _page.nextPage(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOutCubic);
                  }
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _toAuth() => Navigator.pushReplacement(
      context, MaterialPageRoute(builder: (_) => const AuthGateway()));
}

/// ============================ ABOUT YOU ============================
/// Two quick, playful questions — asked once, right before a brand-new
/// account lands on the dashboard. The age answer decides the
/// experience: under-12s get the MYNDASH KIDS zone.
class AboutYouScreen extends StatefulWidget {
  const AboutYouScreen({super.key});

  @override
  State<AboutYouScreen> createState() => _AboutYouScreenState();
}

/// One extra "about you" question — single-choice, id-keyed so the
/// answer lands in [AppData.onboardingAnswers] with zero other code
/// changes. To add a question, just add an entry to [_AboutYouScreenState._questions].
class _OQuestion {
  final String id;
  final String title;
  final String? subtitle;
  final List<String> options;
  const _OQuestion(
      {required this.id,
      required this.title,
      this.subtitle,
      required this.options});
}

class _AboutYouScreenState extends State<AboutYouScreen> {
  final _page = PageController();
  int page = 0;
  int? age;
  final Map<String, String> answers = {};

  static const _ages = [
    ('Under 8', 7),
    ('8–11', 10),
    ('12–15', 14),
    ('16–24', 20),
    ('25–39', 30),
    ('40+', 45),
  ];

  /// Scalable question bank — append here, nothing else to touch.
  static const _questions = <_OQuestion>[
    _OQuestion(
      id: 'iq',
      title: 'Honestly — what do you think your IQ is?',
      subtitle: 'We\'ll find out the real one soon enough…',
      options: [
        'No idea — measure me',
        '~100 · certified normal',
        '~120 · quietly dangerous',
        '~140 · built different',
        'IQ is a social construct',
      ],
    ),
    _OQuestion(
      id: 'goal',
      title: 'What brings you to MYNDASH?',
      options: [
        'Compete & climb the ranks',
        'Sharpen my brain daily',
        'Chill puzzle breaks',
        'Beat my friends, obviously',
      ],
    ),
    _OQuestion(
      id: 'style',
      title: 'Pick your battle style',
      options: [
        'Speed demon — answer first, think later',
        'Deep thinker — measure twice, cut once',
        'Calculated risk-taker',
        'Steady grinder — slow and unstoppable',
      ],
    ),
    _OQuestion(
      id: 'game',
      title: 'Favorite mind sport?',
      options: ['Chess', 'Math & logic', 'Word puzzles', 'Darts'],
    ),
    _OQuestion(
      id: 'schedule',
      title: 'When do you play most?',
      options: [
        'Morning',
        'Afternoon',
        'Late night',
        'No schedule, just vibes',
      ],
    ),
    _OQuestion(
      id: 'rival',
      title: 'Your dream MYNDASH moment?',
      options: [
        'Beat a Grandmaster-tier bot',
        'Top the weekly leaderboard',
        'Win a MYNDASH arena',
        'Just get a little better every day',
      ],
    ),
  ];

  int get totalPages => 1 + _questions.length;

  bool get _answered =>
      page == 0 ? age != null : answers[_questions[page - 1].id] != null;

  void _next() {
    if (page < totalPages - 1) {
      _page.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic);
    } else {
      final a = AppData.i;
      a.age = age!;
      a.kidMode = age! < 12;
      a.iqGuess = answers['iq'] ?? '';
      a.onboardingAnswers = Map<String, String>.from(answers);
      a.save();
      finishOnboarding(context);
    }
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ShaderBackground(
        child: SafeArea(
          child: Column(children: [
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 0; i < totalPages; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: page == i ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: page == i ? DC.cyan : DC.fg24,
                  ),
                ),
            ]),
            Expanded(
              child: PageView.builder(
                controller: _page,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: totalPages,
                onPageChanged: (i) => setState(() => page = i),
                itemBuilder: (context, i) =>
                    i == 0 ? _agePage() : _questionPage(_questions[i - 1]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: NeonButton(
                label: page == totalPages - 1 ? 'LET\'S GO' : 'NEXT',
                icon: page == totalPages - 1
                    ? Icons.rocket_launch
                    : Icons.arrow_forward,
                onPressed: _answered ? _next : null,
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _agePage() {
    return _centeredQuestion(
      title: 'How old are you?',
      subtitle: 'So MYNDASH fits your brain. No wrong answers.',
      options: [
        for (final (label, value) in _ages)
          _optionRow(label, age == value, () => setState(() => age = value)),
        if (age != null && age! < 12) ...[
          const SizedBox(height: 8),
          Glass(
            child: Text(
                'We built a MYNDASH KIDS zone for you — fun topics, all the games, zero pressure.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: DC.text)),
          ),
        ],
      ],
    );
  }

  Widget _questionPage(_OQuestion q) {
    return _centeredQuestion(
      title: q.title,
      subtitle: q.subtitle,
      options: [
        for (final o in q.options)
          _optionRow(
              o, answers[q.id] == o, () => setState(() => answers[q.id] = o)),
      ],
    );
  }

  /// One question, vertically centered, plain bold title (no gradient).
  Widget _centeredQuestion({
    required String title,
    String? subtitle,
    required List<Widget> options,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                    color: DC.text)),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, height: 1.4, color: DC.dim)),
            ],
            const SizedBox(height: 28),
            ...options,
          ],
        ),
      ),
    );
  }

  /// Full-width tappable answer row — iOS-style, check on select.
  Widget _optionRow(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: selected ? DC.cyan.withOpacity(0.12) : DC.fg10,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? DC.cyan : DC.fg12,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(children: [
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: DC.text)),
            ),
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: 22,
              color: selected ? DC.cyan : DC.fg24,
            ),
          ]),
        ),
      ),
    );
  }
}

/// ============================ SIGN IN / CREATE ============================
class AuthGateway extends StatelessWidget {
  const AuthGateway({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ShaderBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(children: [
              const Spacer(),
              Text('MYNDASH',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: DC.electric,
                      fontWeight: FontWeight.w900,
                      fontSize: 34,
                      letterSpacing: 3)),
              Text('fastest mind wins',
                  style:
                      TextStyle(color: DC.dim, letterSpacing: 3, fontSize: 12)),
              const Spacer(),
              NeonButton(
                label: 'CREATE ACCOUNT',
                icon: Icons.person_add_alt_1,
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AuthScreen(create: true))),
              ),
              const SizedBox(height: 14),
              GhostButton(
                label: 'SIGN IN',
                icon: Icons.login,
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AuthScreen(create: false))),
              ),
              const SizedBox(height: 16),
              // Play-policy consent line with tappable legal links
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('By continuing you agree to our ',
                      style: TextStyle(fontSize: 11, color: DC.dim)),
                  GestureDetector(
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const TermsScreen())),
                    child: Text('Terms of Service',
                        style: TextStyle(
                            fontSize: 11,
                            color: DC.cyan,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline)),
                  ),
                  Text(' and ', style: TextStyle(fontSize: 11, color: DC.dim)),
                  GestureDetector(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const PrivacyScreen())),
                    child: Text('Privacy Policy',
                        style: TextStyle(
                            fontSize: 11,
                            color: DC.cyan,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Full policy hub remains reachable before sign-in.
              GestureDetector(
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const PoliciesHubScreen())),
                child: Text('Policies & Contact',
                    style: TextStyle(
                        fontSize: 11,
                        color: DC.dim,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline)),
              ),
              const SizedBox(height: 12),
            ]),
          ),
        ),
      ),
    );
  }
}

/// After auth: pick username if missing, then (new accounts only) the
/// two about-you questions, then the dashboard. Existing accounts that
/// signed back in skip straight through — no re-asking.
void goToUsername(BuildContext context, {required bool isNewUser}) {
  if (AppData.i.username.length >= 6) {
    _afterUsername(context, isNewUser: isNewUser);
  } else {
    Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => UsernameScreen(isNewUser: isNewUser)),
        (r) => false);
  }
}

void _afterUsername(BuildContext context, {required bool isNewUser}) {
  if (isNewUser && AppData.i.age == 0) {
    Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AboutYouScreen()),
        (r) => false);
  } else {
    finishOnboarding(context);
  }
}

void finishOnboarding(BuildContext context) {
  AppData.i.onboarded = true;
  AppData.i.save();
  // Persist the profile now (incl. the under-12 flag) so a brand-new kid who
  // signs out immediately still returns into MYNDASH KIDS on next login.
  AccountService.instance.updatePublicProfile();
  // Route through WelcomeGate so a brand-new account also gets the rocket
  // intro (it used to jump straight to home and skip it).
  Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
          builder: (_) => WelcomeGate(
              child: AppData.i.kidMode
                  ? const KidHomeScreen()
                  : const DistrictHome())),
      (r) => false);
}

/// ============================ AUTH SCREEN ============================
class AuthScreen extends StatefulWidget {
  final bool create;
  const AuthScreen({super.key, required this.create});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

enum _Method { pick, email, phone, otp, verifyEmail }

class _AuthScreenState extends State<AuthScreen> {
  final svc = AccountService.instance;
  _Method method = _Method.pick;
  bool busy = false;

  final email = TextEditingController();
  final pass = TextEditingController();
  final pass2 = TextEditingController();
  final phone = TextEditingController();
  final otp = TextEditingController();
  String verificationId = '';

  void _err(String? e) {
    if (e != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e)));
    }
  }

  Future<void> _google() async {
    setState(() => busy = true);
    final (e, isNewUser) = await svc.signInGoogle();
    setState(() => busy = false);
    if (e != null) {
      _err(e);
    } else if (mounted) {
      goToUsername(context, isNewUser: isNewUser);
    }
  }

  Future<void> _emailSubmit() async {
    if (widget.create) {
      if (pass.text.length < 6) return _err('Password: min 6 characters.');
      if (pass.text != pass2.text) return _err("Passwords don't match.");
      setState(() => busy = true);
      final (e, isNewUser) =
          await svc.signUpOrSignInEmail(email.text.trim(), pass.text);
      setState(() => busy = false);
      if (e != null) return _err(e);
      if (isNewUser) {
        setState(() => method = _Method.verifyEmail);
      } else if (mounted) {
        goToUsername(context, isNewUser: false);
      }
    } else {
      // Sign in — but an email we don't recognise is treated as a brand-new
      // account (create-or-sign-in), so a first-timer still gets email
      // verification + the onboarding questions instead of a dead-end error.
      setState(() => busy = true);
      final (e, isNewUser) =
          await svc.signUpOrSignInEmail(email.text.trim(), pass.text);
      setState(() => busy = false);
      if (e != null) return _err(e);
      if (isNewUser) {
        setState(() => method = _Method.verifyEmail);
      } else if (mounted) {
        goToUsername(context, isNewUser: false);
      }
    }
  }

  Future<void> _checkVerified() async {
    setState(() => busy = true);
    final ok = await svc.isEmailVerified();
    setState(() => busy = false);
    if (ok) {
      if (mounted) goToUsername(context, isNewUser: true);
    } else {
      _err('Not verified yet — tap the link in your email first.');
    }
  }

  Future<void> _phoneSubmit() async {
    var p = phone.text.trim();
    if (!p.startsWith('+')) p = '+91$p'; // default country code
    setState(() => busy = true);
    final e = await svc.startPhoneAuth(p, (id) {
      if (mounted) {
        setState(() {
          verificationId = id;
          method = _Method.otp;
        });
      }
    });
    setState(() => busy = false);
    if (e != null) _err(e);
  }

  Future<void> _otpSubmit() async {
    setState(() => busy = true);
    final (e, isNewUser) =
        await svc.confirmOtp(verificationId, otp.text.trim());
    setState(() => busy = false);
    if (e != null) return _err(e);
    if (mounted) goToUsername(context, isNewUser: isNewUser);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.create ? 'CREATE ACCOUNT' : 'SIGN IN';
    return Scaffold(
      body: ShaderBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              Row(children: [
                Glass(
                    radius: 16,
                    padding: const EdgeInsets.all(8),
                    onTap: () => method == _Method.pick
                        ? Navigator.pop(context)
                        : setState(() => method = _Method.pick),
                    child: const Icon(Icons.arrow_back, size: 18)),
                const SizedBox(width: 12),
                Text(title, style: Theme.of(context).textTheme.titleLarge),
              ]),
              const SizedBox(height: 32),
              if (busy) LinearProgressIndicator(color: DC.cyan),
              const SizedBox(height: 12),
              ...switch (method) {
                _Method.pick => _pick(),
                _Method.email => _emailForm(),
                _Method.verifyEmail => _verifyEmail(),
                _Method.phone => _phoneForm(),
                _Method.otp => _otpForm(),
              },
            ]),
          ),
        ),
      ),
    );
  }

  List<Widget> _pick() => [
        GhostButton(
          label: 'Continue with Google',
          icon: Icons.g_mobiledata,
          onPressed: busy ? null : _google,
        ),
        const SizedBox(height: 12),
        GhostButton(
          label: widget.create ? 'Sign up with Email' : 'Sign in with Email',
          icon: Icons.alternate_email,
          onPressed: () => setState(() => method = _Method.email),
        ),
        const SizedBox(height: 12),
        GhostButton(
          label: 'Use Phone number (OTP)',
          icon: Icons.smartphone,
          onPressed: () => setState(() => method = _Method.phone),
        ),
      ];

  Widget _field(TextEditingController c, String hint,
          {bool obscure = false, TextInputType? kb}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Glass(
          radius: 18,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: TextField(
            controller: c,
            obscureText: obscure,
            keyboardType: kb,
            decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hint,
                hintStyle: TextStyle(color: DC.dim)),
          ),
        ),
      );

  List<Widget> _emailForm() => [
        _field(email, 'Email address', kb: TextInputType.emailAddress),
        _field(pass, 'Password', obscure: true),
        if (widget.create) _field(pass2, 'Confirm password', obscure: true),
        const SizedBox(height: 8),
        NeonButton(
            label: widget.create ? 'CREATE & VERIFY EMAIL' : 'SIGN IN',
            onPressed: busy ? null : _emailSubmit),
      ];

  List<Widget> _verifyEmail() => [
        Icon(Icons.mark_email_unread, size: 60, color: DC.cyan),
        const SizedBox(height: 14),
        Text('Check your inbox',
            style: Theme.of(context).textTheme.displayMedium),
        const SizedBox(height: 8),
        Text(
          'We sent a verification link to\n${email.text.trim()}\nTap it, then come back here.',
          textAlign: TextAlign.center,
          style: TextStyle(color: DC.dim, height: 1.6),
        ),
        const SizedBox(height: 24),
        NeonButton(
            label: "I'VE VERIFIED", onPressed: busy ? null : _checkVerified),
        TextButton(
          onPressed: () async => _err(
              await svc.resendVerification() ?? 'Verification email re-sent.'),
          child: Text('Resend email', style: TextStyle(color: DC.dim)),
        ),
      ];

  List<Widget> _phoneForm() => [
        _field(phone, 'Phone (e.g. +91XXXXXXXXXX)', kb: TextInputType.phone),
        const SizedBox(height: 8),
        NeonButton(label: 'SEND OTP', onPressed: busy ? null : _phoneSubmit),
      ];

  List<Widget> _otpForm() => [
        Icon(Icons.sms, size: 54, color: DC.lime),
        const SizedBox(height: 12),
        Text('Enter the 6-digit code we texted you',
            style: TextStyle(color: DC.dim)),
        const SizedBox(height: 16),
        _field(otp, '······', kb: TextInputType.number),
        NeonButton(label: 'VERIFY', onPressed: busy ? null : _otpSubmit),
      ];
}

/// ============================ USERNAME ============================
class UsernameScreen extends StatefulWidget {
  final bool isNewUser;
  const UsernameScreen({super.key, this.isNewUser = false});

  @override
  State<UsernameScreen> createState() => _UsernameScreenState();
}

class _UsernameScreenState extends State<UsernameScreen> {
  final c = TextEditingController();
  String? hint;
  bool busy = false;

  // Instagram-style live availability: debounce keystrokes, then do a
  // single O(1) key lookup in the usernames index.
  Timer? _debounce;
  String _status = 'idle'; // idle|checking|available|taken|offline|error
  String _checkedName = '';

  bool get valid => AppData.usernameRx.hasMatch(c.text.trim().toLowerCase());

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String _) {
    hint = null;
    _debounce?.cancel();
    if (!valid) {
      setState(() => _status = 'idle');
      return;
    }
    setState(() => _status = 'checking');
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      final name = c.text.trim().toLowerCase();
      final r = await AccountService.instance.checkUsernameAvailable(name);
      if (!mounted || c.text.trim().toLowerCase() != name) return;
      _checkedName = name;
      setState(() {
        _status = switch (r) {
          'available' => 'available',
          'taken' => 'taken',
          'offline' => 'offline',
          'invalid' => 'idle',
          _ => 'error',
        };
        if (_status == 'error') hint = r;
      });
    });
  }

  Future<void> _claim() async {
    setState(() => busy = true);
    final e = await AccountService.instance.claimUsername(c.text);
    setState(() => busy = false);
    if (e != null) {
      setState(() {
        hint = e;
        _status = 'taken';
      });
      return;
    }
    AppData.i.name = c.text.trim();
    await AppData.i.save();
    if (mounted) _afterUsername(context, isNewUser: widget.isNewUser);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ShaderBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(children: [
              const Spacer(),
              const Text('🎯', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 16),
              Text('Claim your handle',
                  style: Theme.of(context).textTheme.displayMedium),
              const SizedBox(height: 8),
              Text(
                'At least 6 characters — letters, numbers, underscore.\nUnique across all of MYNDASH.',
                textAlign: TextAlign.center,
                style: TextStyle(color: DC.dim, height: 1.5),
              ),
              const SizedBox(height: 28),
              Glass(
                radius: 20,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                border: Border.all(
                  color: switch (_status) {
                    'available' => DC.lime,
                    'taken' => DC.danger,
                    _ => DC.fgo(0.10),
                  },
                  width: 1.4,
                ),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: c,
                      onChanged: _onChanged,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: DC.cyan),
                      decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: '@username',
                          hintStyle: TextStyle(color: DC.dim)),
                    ),
                  ),
                  SizedBox(
                    width: 26,
                    child: switch (_status) {
                      'checking' => SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: DC.cyan)),
                      'available' =>
                        Icon(Icons.check_circle, color: DC.lime, size: 22),
                      'taken' => Icon(Icons.cancel, color: DC.danger, size: 22),
                      _ => const SizedBox(),
                    },
                  ),
                ]),
              ),
              const SizedBox(height: 8),
              Text(
                hint ??
                    switch (_status) {
                      'checking' => 'checking availability…',
                      'available' => '✓ @$_checkedName is available!',
                      'taken' => '✗ taken — try another',
                      'offline' =>
                        'guest mode — username saved on this device only',
                      _ => c.text.isEmpty
                          ? ''
                          : valid
                              ? ''
                              : 'min 6 chars · a-z 0-9 _ only',
                    },
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12,
                    color: switch (hint != null ? 'taken' : _status) {
                      'available' => DC.lime,
                      'taken' => DC.danger,
                      _ => DC.dim,
                    }),
              ),
              const Spacer(),
              NeonButton(
                  label: busy ? 'CLAIMING…' : 'CLAIM USERNAME',
                  icon: Icons.verified,
                  onPressed: valid &&
                          !busy &&
                          (_status == 'available' || _status == 'offline')
                      ? _claim
                      : null),
              const SizedBox(height: 16),
            ]),
          ),
        ),
      ),
    );
  }
}

/// ============================ 3D HERO ============================
/// The onboarding showpiece: a glassy tile that floats, tilts and
/// spins in real 3D perspective, with a moving glow underneath.
/// Only used on transient screens (intro pages), so the animation
/// never costs anything once you're inside the app.
class Hero3D extends StatefulWidget {
  final IconData icon;
  final double size;
  const Hero3D({super.key, required this.icon, this.size = 150});

  @override
  State<Hero3D> createState() => _Hero3DState();
}

class _Hero3DState extends State<Hero3D> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 5))
        ..repeat();

  Offset _drag = Offset.zero; // finger tilt on top of the idle motion

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    // Listener (not GestureDetector) so finger-tilt never steals the
    // PageView's swipe gesture.
    return Listener(
      onPointerMove: (d) => setState(() => _drag = Offset(
            (_drag.dx + d.delta.dx * 0.008).clamp(-0.5, 0.5),
            (_drag.dy + d.delta.dy * 0.008).clamp(-0.5, 0.5),
          )),
      onPointerUp: (_) => setState(() => _drag = Offset.zero),
      onPointerCancel: (_) => setState(() => _drag = Offset.zero),
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value * 2 * math.pi;
          final rotY = math.sin(t) * 0.32 + _drag.dx;
          final rotX = math.cos(t * 0.7) * 0.16 - _drag.dy;
          final float = math.sin(t * 1.3) * 7;
          return SizedBox(
            width: s + 40,
            height: s + 56,
            child: Stack(alignment: Alignment.center, children: [
              // moving glow shadow under the tile
              Positioned(
                bottom: 0,
                child: Container(
                  width: s * (0.72 - float * 0.006),
                  height: 18,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(50),
                    gradient: RadialGradient(colors: [
                      DC.violet.withOpacity(0.45),
                      DC.violet.withOpacity(0),
                    ]),
                  ),
                ),
              ),
              Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0016) // perspective
                  ..translate(0.0, float)
                  ..rotateY(rotY)
                  ..rotateX(rotX),
                child: Container(
                  width: s,
                  height: s,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(34),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        DC.violet.withOpacity(0.55),
                        DC.cyan.withOpacity(0.35),
                        DC.magenta.withOpacity(0.45),
                      ],
                    ),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.35), width: 1.4),
                    boxShadow: [
                      BoxShadow(
                          color: DC.cyan.withOpacity(0.35),
                          blurRadius: 34,
                          offset: Offset(rotY * -18, 14)),
                    ],
                  ),
                  child: Center(
                    child: Transform(
                      alignment: Alignment.center,
                      // counter-tilt slightly so the emoji "pops" above
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001)
                        ..rotateY(rotY * 0.4)
                        ..rotateX(rotX * 0.4)
                        ..translate(0.0, 0.0, -26.0),
                      child: Icon(widget.icon,
                          size: s * 0.42, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }
}

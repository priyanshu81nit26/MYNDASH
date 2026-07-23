import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../core/fx.dart';
import '../core/state.dart';
import '../engine/banks.dart';
import '../engine/kid_generators.dart';
import '../engine/question.dart';
import '../services/account_service.dart';
import '../theme_district.dart';
import '../ui/extras.dart';
import '../ui/glass.dart';
import 'games_hub.dart';
import 'kid_chocolate.dart';
import 'kid_fun_games.dart';
import 'legal.dart';
import 'onboarding.dart';
import 'welcome_screen.dart';
import 'profile_screen.dart';
import 'squads_screen.dart';

/// ============================================================
/// MYNDASH KIDS — the under-12 zone. Same dark-glass DNA, zero
/// pressure: age-fit topics (50 levels × 50 questions), all the
/// games in practice mode, same profile & coins. No online
/// duels, arenas or store checkout — that unlocks at 12+.
/// ============================================================
class KidHomeScreen extends StatefulWidget {
  const KidHomeScreen({super.key});

  @override
  State<KidHomeScreen> createState() => _KidHomeScreenState();
}

class _KidHomeScreenState extends State<KidHomeScreen> {
  int tab = 0;
  final PageController _pager = PageController();

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  void _go(int i) => _pager.animateToPage(i,
      duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);

  @override
  Widget build(BuildContext context) {
    // Cross-fade the whole kid home on theme toggle.
    return ValueListenableBuilder<double>(
      valueListenable: ThemeCtl.t,
      builder: (context, _, __) => Scaffold(
        endDrawer: const _KidDrawer(),
        body: ShaderBackground(
          child: SafeArea(
            bottom: false,
            child: Column(children: [
              _header(context),
              Expanded(
                child: PageView(
                  controller: _pager,
                  physics: const ClampingScrollPhysics(),
                  onPageChanged: (i) => setState(() => tab = i),
                  children: [
                    _playTab(context),
                    _gamesTab(context),
                    _learnTab(context),
                    const ProfileScreen(embedded: true),
                  ],
                ),
              ),
            ]),
          ),
        ),
        bottomNavigationBar: _navbar(),
      ),
    );
  }

  // ---------------- header ----------------
  Widget _header(BuildContext context) {
    final a = AppData.i;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(children: [
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text('MYNDASH',
                maxLines: 1,
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    letterSpacing: 1.5, fontSize: 20, color: DC.wordmark)),
          ),
        ),
        const SizedBox(width: 8),
        StatWallet(streak: a.streak, xp: a.xp, coins: a.coins),
        const SizedBox(width: 6),
        Glass(
          radius: 30,
          padding: const EdgeInsets.all(10),
          onTap: () => ThemeCtl.toggle(),
          child: Icon(
              ThemeCtl.isDark
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
              size: 18,
              color: DC.amber),
        ),
        const SizedBox(width: 6),
        Builder(
          builder: (context) => Glass(
            radius: 30,
            padding: const EdgeInsets.all(10),
            onTap: () => Scaffold.of(context).openEndDrawer(),
            child: const Icon(Icons.menu_rounded, size: 18),
          ),
        ),
      ]),
    );
  }

  void _push(Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen))
          .then((_) => setState(() {}));

  Widget _bigCard({
    required IconData icon,
    required Color tint,
    required String title,
    required String sub,
    VoidCallback? onTap,
  }) {
    return Glass(
      tint: tint,
      onTap: onTap,
      child: Row(children: [
        Icon(icon, size: 30, color: tint),
        const SizedBox(width: 14),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w900, letterSpacing: 1)),
            Text(sub, style: TextStyle(fontSize: 11, color: DC.dim)),
          ]),
        ),
        if (onTap != null) Icon(Icons.chevron_right, color: DC.dim),
      ]),
    );
  }

  /// A gamified grid of [KidTile]s (2 columns) with staggered entrances.
  Widget _kidGrid(List<KidTile> tiles) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.98,
      children: [
        for (var i = 0; i < tiles.length; i++)
          KidTileView(tile: tiles[i], index: i),
      ],
    );
  }

  // ---------------- PLAY (daily & social) ----------------
  Widget _playTab(BuildContext context) {
    final a = AppData.i;
    final dropLive = DateTime.now().hour >= 20;
    final dropDone = a.lastKidDropKey == AppData.todayKey();
    final wd = DateTime.now().weekday;
    final isWeekend = wd == DateTime.saturday || wd == DateTime.sunday;
    final cKey = 'c${contestIndexFor(DateTime.now())}';
    final cDone = a.lastKidContestKey == cKey;
    final daily5Done = a.dailyMathProgress >= 5;
    final tiles = <KidTile>[
      KidTile(
        emoji: '🔥',
        icon: daily5Done ? Icons.verified_rounded : Icons.local_fire_department,
        color: daily5Done ? DC.lime : DC.amber,
        title: 'DAILY 5',
        sub: daily5Done
            ? 'All 5 done · streak ${a.streak}'
            : '${a.dailyMathProgress}/5 solved',
        badge: daily5Done ? '✅' : null,
        onTap: () => _push(const KidDaily5Screen()),
      ),
      KidTile(
        emoji: '🍫',
        icon: Icons.emoji_food_beverage_rounded,
        color: const Color(0xFFC98A00),
        title: 'CHOCOLATE HOUR',
        sub: '${a.chocSolvedToday().length}/24 collected',
        badge: 'NEW EVERY HR',
        onTap: () => _push(const KidChocolateScreen()),
      ),
      KidTile(
        emoji: '📡',
        icon: dropDone
            ? Icons.verified_rounded
            : (dropLive ? Icons.podcasts_rounded : Icons.schedule_rounded),
        color: dropDone ? DC.lime : (dropLive ? DC.danger : DC.cyan),
        title: '8PM DROP',
        sub: dropDone
            ? 'Back tomorrow 8pm!'
            : dropLive
                ? 'LIVE NOW!'
                : 'Every night · 8pm',
        badge: dropLive && !dropDone ? 'LIVE' : null,
        locked: !dropLive || dropDone,
        onTap:
            (!dropLive || dropDone) ? null : () => _push(const KidDropScreen()),
      ),
      KidTile(
        emoji: '🏆',
        icon: cDone ? Icons.military_tech_rounded : Icons.emoji_events_rounded,
        color: cDone ? DC.lime : (isWeekend ? DC.amber : DC.violet),
        title: 'WEEKEND CONTEST',
        sub: cDone
            ? 'See you next weekend!'
            : isWeekend
                ? '8 questions · same paper'
                : 'Sat & Sun',
        badge: isWeekend && !cDone ? 'OPEN' : null,
        locked: !isWeekend || cDone,
        onTap: (!isWeekend || cDone)
            ? null
            : () => _push(const KidContestScreen()),
      ),
      KidTile(
        emoji: '🧑‍🤝‍🧑',
        icon: Icons.groups_rounded,
        color: DC.lime,
        title: a.squadName.isEmpty ? 'KIDS SQUADS' : 'MY SQUAD',
        sub: a.squadName.isEmpty
            ? 'team up · under-12'
            : a.squadName,
        onTap: () => _push(const SquadsScreen()),
      ),
    ];
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('TODAY',
          style: TextStyle(fontSize: 10, letterSpacing: 2, color: DC.dim)),
      const SizedBox(height: 10),
      _kidGrid(tiles),
      const SizedBox(height: 16),
      Glass(
        child: Text(
            'Online duels, arenas and the store unlock at 12+.\nEverything you earn here counts on your profile forever!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: DC.dim)),
      ),
    ]);
  }

  // ---------------- GAMES ----------------
  Widget _gamesTab(BuildContext context) {
    final a = AppData.i;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('ALL GAMES',
          style: TextStyle(fontSize: 10, letterSpacing: 2, color: DC.dim)),
      const SizedBox(height: 10),
      _bigCard(
        icon: Icons.sports_esports_rounded,
        tint: DC.violet,
        title: 'ARCADE & DUELS',
        sub: 'chess · darts · cube · scribble · words · art · reflex',
        onTap: () => _push(const GamesHubScreen(kidsMode: true)),
      ),
      const SizedBox(height: 14),
      Text('BRAIN GAMES',
          style: TextStyle(fontSize: 10, letterSpacing: 2, color: DC.dim)),
      const SizedBox(height: 10),
      _kidGrid([
        for (final g in kidFunGames)
          KidTile(
            emoji: g.emoji,
            icon: Icons.sports_esports_rounded,
            color: g.color,
            title: g.name,
            sub: g.arcade
                ? 'Best ${a.kidBest(g.id)}'
                : 'Level ${a.kidLevel(g.id)}/${g.maxLevel}',
            badge: (g.arcade || g.journey != null) ? '3D' : null,
            onTap: () => _push(g.journey != null
                ? g.journey!()
                : g.arcade
                    ? g.builder(0)
                    : KidFunLevelScreen(game: g)),
          ),
      ]),
    ]);
  }

  // ---------------- LEARN (math topics, 50 levels) ----------------
  Widget _learnTab(BuildContext context) {
    final a = AppData.i;
    final topics = kidTopicsFor(a.age == 0 ? 10 : a.age);
    return ListView(padding: const EdgeInsets.all(16), children: [
      Text('LEARN — ${AppData.kidMaxLevel} levels, 50 questions each',
          style: TextStyle(fontSize: 10, letterSpacing: 2, color: DC.dim)),
      const SizedBox(height: 10),
      _kidGrid([
        for (final t in topics)
          KidTile(
            emoji: t.emoji,
            icon: Icons.school_rounded,
            color: t.color,
            title: t.name,
            sub: 'Level ${a.kidLevel(t.id)}/${AppData.kidMaxLevel}',
            onTap: () => _push(KidLevelScreen(topic: t)),
          ),
      ]),
    ]);
  }

  // ---------------- navbar ----------------
  Widget _navbar() {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: DC.bg2,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: DC.fg10),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.14),
                blurRadius: 22,
                offset: const Offset(0, 8)),
          ],
        ),
        child: Row(children: [
          _navItem(0, Icons.bolt_rounded, 'Play'),
          _navItem(1, Icons.sports_esports_rounded, 'Games'),
          _navItem(2, Icons.school_rounded, 'Learn'),
          _navItem(3, Icons.person_rounded, 'You'),
        ]),
      ),
    );
  }

  Widget _navItem(int i, IconData icon, String label) {
    final active = tab == i;
    final accent = DC.cyan;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _go(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: active ? accent.withOpacity(0.14) : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 22, color: active ? accent : DC.dim),
            const SizedBox(height: 3),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                    color: active ? accent : DC.dim)),
          ]),
        ),
      ),
    );
  }
}

/// ---------------- kids hamburger menu ----------------
/// Kid-sized: profile, games, squads, daily stuff, theme, help &
/// legal. NO college/corporate, NO store checkout, NO PRO upsell.
class _KidDrawer extends StatelessWidget {
  const _KidDrawer();

  @override
  Widget build(BuildContext context) {
    final a = AppData.i;
    return Drawer(
      backgroundColor: DC.bg2,
      child: SafeArea(
        child: Column(children: [
          const SizedBox(height: 20),
          Text('MYNDASH KIDS',
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: DC.electric,
                  fontWeight: FontWeight.w900,
                  fontSize: 19,
                  letterSpacing: 1.5)),
          Text('@${a.username.isEmpty ? 'explorer' : a.username}',
              style: TextStyle(fontSize: 12, color: DC.dim)),
          const SizedBox(height: 14),
          Divider(color: DC.fg12, height: 1),
          Expanded(
            child: ListView(padding: EdgeInsets.zero, children: [
              // theme toggle
              ListTile(
                dense: true,
                leading: Icon(
                    ThemeCtl.isDark
                        ? Icons.dark_mode_rounded
                        : Icons.light_mode_rounded,
                    color: DC.amber,
                    size: 22),
                title: Text(
                    ThemeCtl.isDark ? 'Theme · Night 🌙' : 'Theme · Arcade ☀️',
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w700)),
                trailing: Switch(
                  value: ThemeCtl.isDark,
                  activeColor: DC.violet,
                  onChanged: (_) => ThemeCtl.toggle(),
                ),
                onTap: () => ThemeCtl.toggle(),
              ),
              Divider(color: DC.fg12, height: 8),
              _nav(context, Icons.person_rounded, DC.cyan, 'My Profile',
                  () => const ProfileScreen()),
              _nav(context, Icons.local_fire_department, DC.amber, 'Daily 5 🔥',
                  () => const KidDaily5Screen()),
              _nav(context, Icons.sports_esports, DC.violet, 'All Games 🎮',
                  () => const GamesHubScreen(kidsMode: true)),
              _nav(
                  context,
                  Icons.groups_rounded,
                  DC.lime,
                  a.squadName.isEmpty
                      ? 'Kids Squads 👥'
                      : 'My Squad · ${a.squadName}',
                  () => const SquadsScreen()),
              ListTile(
                dense: true,
                leading: Icon(Icons.help_outline, color: DC.cyan),
                title: const Text('Help',
                    style:
                        TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                onTap: () {
                  Navigator.pop(context);
                  showDialog(
                    context: context,
                    builder: (c) => AlertDialog(
                      backgroundColor: DC.bg2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24)),
                      title: const Text('How MYNDASH KIDS works'),
                      content: SingleChildScrollView(
                        child: Text('''
🔥 DAILY 5 — five questions every day. Finish all 5 to grow your streak!

🕗 8PM DROP — one special question at 8pm for every kid on MYNDASH.

🏆 WEEKEND CONTEST — 8 questions every Saturday & Sunday.

🧱 FUN GAMES — Block Builder, Memory Match, Almanac facts & Cross Math.

🎮 ALL GAMES — chess, darts, cube, scribble, words, art & reflex — all free to practice.

👥 KIDS SQUADS — make a squad with other kids (under-12 only!).

📚 TOPICS — your school-age topics, 50 levels each. 2 stars unlocks the next level.

Everything you earn counts on your profile forever. Online duels, arenas and the store unlock at 12+.''',
                            style: TextStyle(
                                fontSize: 13, height: 1.5, color: DC.text)),
                      ),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(c),
                            child: const Text('Close')),
                      ],
                    ),
                  );
                },
              ),
              Divider(color: DC.fg12, height: 16),
              _nav(context, Icons.description_outlined, DC.dim,
                  'Terms of Service', () => const TermsScreen()),
              _nav(context, Icons.privacy_tip_outlined, DC.dim,
                  'Privacy Policy', () => const PrivacyScreen()),
            ]),
          ),
          Divider(color: DC.fg12, height: 1),
          ListTile(
            leading: Icon(Icons.logout, color: DC.danger),
            title: Text('Log out', style: TextStyle(color: DC.danger)),
            onTap: () => _logout(context),
          ),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }

  Widget _nav(BuildContext context, IconData icon, Color color, String label,
      Widget Function() builder) {
    return ListTile(
      dense: true,
      leading: Icon(icon, color: color, size: 22),
      title: Text(label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
      trailing: Icon(Icons.chevron_right, size: 16, color: DC.fg24),
      onTap: () {
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(builder: (_) => builder()));
      },
    );
  }

  Future<void> _logout(BuildContext context) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: DC.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Log out?'),
        content: const Text(
            'You\'ll return to the welcome screen. Progress on this device will be cleared.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Log out')),
        ],
      ),
    );
    if (sure != true || !context.mounted) return;
    await AccountService.instance.signOut();
    resetWelcome(); // rocket plays again on the next login
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingFlow()),
        (r) => false);
  }
}

/// ---------------- level picker for one topic ----------------
class KidLevelScreen extends StatefulWidget {
  final KidTopic topic;
  const KidLevelScreen({super.key, required this.topic});

  @override
  State<KidLevelScreen> createState() => _KidLevelScreenState();
}

class _KidLevelScreenState extends State<KidLevelScreen> {
  @override
  Widget build(BuildContext context) {
    final unlocked = AppData.i.kidLevel(widget.topic.id);
    return Scaffold(
      body: ShaderBackground(
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Glass(
                    radius: 16,
                    padding: const EdgeInsets.all(8),
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back, size: 18)),
                const SizedBox(width: 12),
                Text('${widget.topic.emoji}  ${widget.topic.name}',
                    style: Theme.of(context).textTheme.titleLarge),
              ]),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10),
                itemCount: AppData.kidMaxLevel,
                itemBuilder: (context, i) {
                  final level = i + 1;
                  final open = level <= unlocked;
                  return Press3D(
                    onTap: open
                        ? () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => KidSessionScreen(
                                    topic: widget.topic,
                                    level: level))).then((_) => setState(() {}))
                        : null,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: open
                            ? widget.topic.color.withOpacity(0.18)
                            : DC.fgo(0.03),
                        border: Border.all(
                            color: open ? widget.topic.color : DC.fg12),
                      ),
                      child: Center(
                        child: Text(open ? '$level' : '🔒',
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: open ? Colors.white : DC.fg38)),
                      ),
                    ),
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// ---------------- 30-question kid session ----------------
class KidSessionScreen extends StatefulWidget {
  final KidTopic topic;
  final int level;
  const KidSessionScreen({super.key, required this.topic, required this.level});

  @override
  State<KidSessionScreen> createState() => _KidSessionScreenState();
}

class _KidSessionScreenState extends State<KidSessionScreen> {
  static const total = 50;
  // 50 levels to play through, but keep the maths kid-sized: compress the
  // level fed to the generator into a gentle 1..13 difficulty curve so the
  // numbers never explode at high levels.
  int get _difficulty => (1 + (widget.level - 1) ~/ 4).clamp(1, 13);
  late final Random rng =
      Random(widget.topic.id.hashCode ^ widget.level * 4409);
  late Question q;
  int index = 0;
  int correct = 0;
  bool answered = false;
  bool right = false;
  bool finished = false;

  @override
  void initState() {
    super.initState();
    _next();
  }

  void _next() {
    if (index >= total) {
      _finish();
      return;
    }
    q = generateKid(widget.topic.id, _difficulty, rng);
    answered = false;
    setState(() {});
  }

  void _answer(String input) {
    if (answered || finished) return;
    answered = true;
    right = q.check(input);
    if (right) {
      correct++;
      Fx.success();
    } else {
      Fx.fail();
    }
    setState(() {});
    Timer(Duration(milliseconds: right ? 550 : 1400), () {
      if (!mounted) return;
      index++;
      _next();
    });
  }

  void _finish() {
    if (finished) return;
    finished = true;
    final acc = correct / total;
    final stars = acc >= 0.9 ? 3 : (acc >= 0.75 ? 2 : (acc >= 0.5 ? 1 : 0));
    AppData.i.recordKidLevel(widget.topic.id, widget.level, stars);
    if (stars >= 2) {
      Fx.win();
    } else {
      Fx.lose();
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: DC.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (stars >= 2) const ConfettiBurst(height: 60),
            Text(['💪', '🙂', '🌟', '🏆'][stars],
                style: const TextStyle(fontSize: 44)),
            const SizedBox(height: 8),
            Text(
                stars >= 2
                    ? 'AMAZING!'
                    : stars == 1
                        ? 'GOOD TRY!'
                        : 'KEEP GOING!',
                style: Theme.of(context).textTheme.displayMedium),
            Text('$correct / $total correct', style: TextStyle(color: DC.dim)),
            const SizedBox(height: 6),
            Row(mainAxisSize: MainAxisSize.min, children: [
              for (var i = 0; i < 3; i++)
                Icon(Icons.star_rounded,
                    size: 30, color: i < stars ? DC.amber : DC.fg24),
            ]),
            if (stars >= 2 && widget.level < AppData.kidMaxLevel)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Level ${widget.level + 1} unlocked! 🎉',
                    style:
                        TextStyle(color: DC.lime, fontWeight: FontWeight.w800)),
              ),
            const SizedBox(height: 14),
            NeonButton(
                label: 'DONE',
                height: 46,
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                }),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ShaderBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Row(children: [
                Glass(
                    radius: 16,
                    padding: const EdgeInsets.all(8),
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, size: 18)),
                const SizedBox(width: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: index / total,
                      minHeight: 8,
                      backgroundColor: DC.fg10,
                      valueColor: AlwaysStoppedAnimation(widget.topic.color),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text('${min(index + 1, total)}/$total',
                    style: TextStyle(fontSize: 12, color: DC.dim)),
              ]),
              const Spacer(),
              Glass(
                radius: 24,
                padding: const EdgeInsets.all(24),
                border: answered
                    ? Border.all(color: right ? DC.lime : DC.danger, width: 2)
                    : null,
                child: Column(children: [
                  Text(q.prompt,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          height: 1.5)),
                  if (answered && !right) ...[
                    const SizedBox(height: 8),
                    Text('Answer: ${q.answer}',
                        style: TextStyle(
                            color: DC.lime, fontWeight: FontWeight.w800)),
                  ],
                ]),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  for (final o in q.options ?? const <String>[])
                    Press3D(
                      onTap: answered ? null : () => _answer(o),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: answered && q.check(o)
                              ? DC.lime.withOpacity(0.3)
                              : DC.fgo(0.08),
                          border: Border.all(color: DC.fgo(0.15)),
                        ),
                        child: Text(o,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w800)),
                      ),
                    ),
                ],
              ),
              const Spacer(flex: 2),
            ]),
          ),
        ),
      ),
    );
  }
}

/// ---------------- KIDS 8PM DROP ----------------
class KidDropScreen extends StatefulWidget {
  const KidDropScreen({super.key});

  @override
  State<KidDropScreen> createState() => _KidDropScreenState();
}

class _KidDropScreenState extends State<KidDropScreen> {
  late final q =
      bankKidDrop(bankDayIndex(), AppData.i.age == 0 ? 9 : AppData.i.age);
  bool answered = false;
  bool right = false;

  void _answer(String o) {
    if (answered) return;
    setState(() {
      answered = true;
      right = q.check(o);
    });
    if (right) {
      AppData.i.earnCoins(15); // solo → capped faucet
      AppData.i.addXp(25);
    }
    AppData.i.lastKidDropKey = AppData.todayKey();
    AppData.i.save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ShaderBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              Row(children: [
                Glass(
                    radius: 16,
                    padding: const EdgeInsets.all(8),
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back, size: 18)),
                const SizedBox(width: 12),
                Text('🔴 8PM DROP',
                    style: Theme.of(context).textTheme.titleLarge),
              ]),
              const Spacer(),
              Glass(
                radius: 24,
                padding: const EdgeInsets.all(22),
                border: answered
                    ? Border.all(color: right ? DC.lime : DC.danger, width: 2)
                    : null,
                child: Column(children: [
                  Text(q.prompt,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          height: 1.5)),
                  if (answered)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                          right
                              ? '🎉 +60 coins · +25 XP'
                              : 'Answer: ${q.answer} — get it tomorrow!',
                          style: TextStyle(
                              color: right ? DC.lime : DC.danger,
                              fontWeight: FontWeight.w800)),
                    ),
                ]),
              ),
              const SizedBox(height: 16),
              if (!answered && q.options != null)
                for (final o in q.options!)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GhostButton(
                        label: o, height: 48, onPressed: () => _answer(o)),
                  ),
              const Spacer(),
            ]),
          ),
        ),
      ),
    );
  }
}

/// ---------------- KIDS WEEKEND CONTEST ----------------
class KidContestScreen extends StatefulWidget {
  const KidContestScreen({super.key});

  @override
  State<KidContestScreen> createState() => _KidContestScreenState();
}

class _KidContestScreenState extends State<KidContestScreen> {
  static const total = 8;
  late final int cIdx = contestIndexFor(DateTime.now());
  late final int age = AppData.i.age == 0 ? 9 : AppData.i.age;
  int index = 0;
  int correct = 0;
  bool answered = false;
  bool right = false;

  void _answer(String o) {
    if (answered) return;
    final q = bankKidContest(cIdx, index, age);
    setState(() {
      answered = true;
      right = q.check(o);
      if (right) correct++;
    });
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      if (index + 1 >= total) {
        _finish();
      } else {
        setState(() {
          index++;
          answered = false;
        });
      }
    });
  }

  void _finish() {
    final a = AppData.i;
    a.lastKidContestKey = 'c$cIdx';
    final stars = correct >= 7 ? 3 : (correct >= 5 ? 2 : 1);
    a.earnCoins(10 * stars); // solo → capped faucet
    a.addXp(20 * stars);
    a.save();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: DC.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(correct >= 5 ? '🏆' : '🌟',
                style: const TextStyle(fontSize: 50)),
            Text('$correct / $total',
                style: Theme.of(context).textTheme.displayMedium),
            Row(mainAxisSize: MainAxisSize.min, children: [
              for (var s = 0; s < 3; s++)
                Icon(Icons.star_rounded, color: s < stars ? DC.amber : DC.fg12),
            ]),
            Text('+${40 * stars} coins · +${20 * stars} XP',
                style: TextStyle(color: DC.amber, fontSize: 13)),
            const SizedBox(height: 16),
            NeonButton(
                label: 'DONE',
                height: 46,
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                }),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = bankKidContest(cIdx, index, age);
    return Scaffold(
      body: ShaderBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              Row(children: [
                Glass(
                    radius: 16,
                    padding: const EdgeInsets.all(8),
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, size: 18)),
                const SizedBox(width: 12),
                Text('CONTEST 🏆 ${index + 1}/$total',
                    style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                Text('✓ $correct', style: TextStyle(color: DC.lime)),
              ]),
              const Spacer(),
              Glass(
                radius: 24,
                padding: const EdgeInsets.all(22),
                border: answered
                    ? Border.all(color: right ? DC.lime : DC.danger, width: 2)
                    : null,
                child: Text(q.prompt,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        height: 1.5)),
              ),
              const SizedBox(height: 16),
              if (q.options != null)
                for (final o in q.options!)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GhostButton(
                        label: o,
                        height: 48,
                        onPressed: answered ? null : () => _answer(o)),
                  ),
              const Spacer(),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Data for one gamified kid tile.
class KidTile {
  final String emoji;
  final IconData icon;
  final Color color;
  final String title;
  final String sub;
  final String? badge;
  final bool locked;
  final VoidCallback? onTap;
  const KidTile({
    required this.emoji,
    required this.icon,
    required this.color,
    required this.title,
    required this.sub,
    this.badge,
    this.locked = false,
    this.onTap,
  });
}

/// A gamified, 3D-ish kid tile: bright gradient, glossy emoji medallion,
/// a gentle continuous float + glow, a springy staggered entrance, and a
/// squishy press. Built for under-12 delight.
class KidTileView extends StatefulWidget {
  final KidTile tile;
  final int index;
  const KidTileView({super.key, required this.tile, required this.index});

  @override
  State<KidTileView> createState() => _KidTileViewState();
}

class _KidTileViewState extends State<KidTileView>
    with TickerProviderStateMixin {
  late final AnimationController _bob = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2600))
    ..repeat();
  late final AnimationController _in = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 620));
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    // staggered entrance
    Future.delayed(Duration(milliseconds: 60 * widget.index), () {
      if (mounted) _in.forward();
    });
  }

  @override
  void dispose() {
    _bob.dispose();
    _in.dispose();
    super.dispose();
  }

  Color get _darker =>
      HSLColor.fromColor(widget.tile.color).withLightness(0.32).toColor();

  @override
  Widget build(BuildContext context) {
    final t = widget.tile;
    return GestureDetector(
      onTapDown: t.onTap == null ? null : (_) => setState(() => _pressed = true),
      onTapUp: t.onTap == null ? null : (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: t.onTap,
      child: AnimatedBuilder(
        animation: Listenable.merge([_bob, _in]),
        builder: (context, _) {
          final e = Curves.easeOutBack.transform(_in.value.clamp(0.0, 1.0));
          final bob = sin(_bob.value * 2 * pi + widget.index);
          final scale = (0.7 + 0.3 * e) * (_pressed ? 0.94 : 1.0);
          final ty = (1 - e) * 34 - bob * 2.5;
          final m = Matrix4.identity()
            ..setEntry(3, 2, 0.0015)
            ..translate(0.0, ty)
            ..rotateX(bob * 0.02)
            ..scale(scale);
          return Opacity(
            opacity: (e.clamp(0.0, 1.0)) * (t.locked ? 0.6 : 1.0),
            child: Transform(
              alignment: Alignment.center,
              transform: m,
              child: _card(t, bob),
            ),
          );
        },
      ),
    );
  }

  Widget _card(KidTile t, double bob) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [t.color, _darker],
        ),
        boxShadow: [
          BoxShadow(
              color: t.color.withOpacity(0.45 + 0.12 * (bob + 1) / 2),
              blurRadius: 20,
              offset: const Offset(0, 10)),
          const BoxShadow(
              color: Colors.black26, blurRadius: 10, offset: Offset(0, 6)),
        ],
      ),
      child: Stack(children: [
        // glossy top-left highlight
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.center,
                colors: [Colors.white.withOpacity(0.28), Colors.transparent],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                // glossy emoji medallion
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.22),
                    border:
                        Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                    boxShadow: const [
                      BoxShadow(color: Colors.black26, blurRadius: 6)
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(t.emoji, style: const TextStyle(fontSize: 26)),
                ),
                const Spacer(),
                if (t.locked)
                  const Icon(Icons.lock_rounded, size: 16, color: Colors.white70)
                else if (t.badge != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(t.badge!,
                        style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                            color: _darker)),
                  ),
              ]),
              const Spacer(),
              Text(t.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: Colors.white)),
              const SizedBox(height: 2),
              Text(t.sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.85))),
            ],
          ),
        ),
      ]),
    );
  }
}

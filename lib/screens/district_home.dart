import 'package:flutter/material.dart';

import '../core/state.dart';
import '../engine/question.dart';
import '../services/account_service.dart';
import '../theme_district.dart';
import '../ui/art.dart';
import '../ui/default_avatar.dart';
import '../ui/extras.dart';
import '../ui/glass.dart';
import 'ai_coach.dart';
import 'community_hub.dart';
import 'community_screen.dart';
import 'games_hub.dart';
import 'compete.dart';
import 'contest_screen.dart';
import 'daily5.dart';
import 'arena_redesign.dart';
import 'events_screen.dart' show AutoSlider;
import 'friends_search.dart';
import 'leaderboard_screen.dart';
import 'live_drop.dart';
import 'legal.dart';
import 'onboarding.dart';
import 'welcome_screen.dart';
import 'profile_screen.dart';
import 'solve_flow.dart';
import 'squads_screen.dart';
import 'store_screen.dart';

/// Root shell: bottom navigation over the aurora shader.
class DistrictHome extends StatefulWidget {
  const DistrictHome({super.key});

  @override
  State<DistrictHome> createState() => _DistrictHomeState();
}

class _DistrictHomeState extends State<DistrictHome> {
  int tab = 0;
  final PageController _pager = PageController();

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  /// Jump to a tab with the same swipe animation the navbar uses.
  void goTab(int i) => _pager.animateToPage(i,
      duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);

  @override
  Widget build(BuildContext context) {
    // Swipeable sections; the navbar and swipe stay in sync via _pager.
    final tabs = <Widget>[
      _HomeTab(), // non-const: rebuilds so colors cross-fade on toggle
      const FirstTimeGuide(
        id: 'solve',
        emoji: '',
        title: 'Welcome to Solve',
        steps: [
          'Pick a discipline — quick-fire question feeds or interactive boards like Sudoku & Minesweeper.',
          'Clear a level with 2 (80%+ accuracy) to unlock the next, from 800 all the way to 2500.',
          'Stuck? Use 50:50 hints — 3 free per level, then 25 coins.',
        ],
        child: SolveTab(),
      ),
      const FirstTimeGuide(
        id: 'duel',
        emoji: '',
        title: '1v1 Duels',
        steps: [
          'Pick your weapon — REAL chess on a full board, math feeds, tactics or darts — plus an optional coin wager.',
          'Chess: full rules vs a rated engine. Feeds: 7 questions, correct beats wrong; both correct faster wins.',
          'Win to climb your Elo rating and double your wager.',
        ],
        child: DuelTab(),
      ),
      const FriendsSearchScreen(embedded: true),
      // Profile replaces the Store in the navbar — the Store is still one tap
      // away from the Home tab's quick cards.
      const ProfileScreen(embedded: true),
    ];
    // Subscribe the home route to the animated theme value so its whole
    // subtree (background, cards, navbar) cross-fades on toggle. MaterialApp
    // rebuilds don't reach the home route, so we listen here directly.
    return ValueListenableBuilder<double>(
      valueListenable: ThemeCtl.t,
      builder: (context, _, __) => Scaffold(
        endDrawer: const _MyndDrawer(),
        body: ShaderBackground(
          child: AnimatedBuilder(
            animation: AppData.i,
            builder: (context, _) => PageView(
              controller: _pager,
              // Clamp: no bounce past Home (first) or Profile (last).
              physics: const ClampingScrollPhysics(),
              onPageChanged: (i) => setState(() => tab = i),
              children: tabs,
            ),
          ),
        ),
        bottomNavigationBar: _navBar(),
      ),
    );
  }

  /// Clean floating pill navbar — soft rounded highlight on the active item,
  /// icon over label, no heavy Material indicator. Sits off every edge.
  Widget _navBar() {
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
          _navItem(0, Icons.home_rounded, 'Home'),
          _navItem(1, Icons.school_rounded, 'Solve'),
          _navItem(2, Icons.sports_kabaddi, '1v1'),
          _navItem(3, Icons.search_rounded, 'Search'),
          _navProfile(4, 'You'),
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
        onTap: () => goTab(i),
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

  /// Profile nav item — the user's uploaded photo, or their default avatar.
  Widget _navProfile(int i, String label) {
    final active = tab == i;
    final accent = DC.cyan;
    final a = AppData.i;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => goTab(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: active ? accent.withOpacity(0.14) : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border:
                    Border.all(color: active ? accent : DC.fg24, width: 1.5),
              ),
              child:
                  ProfileAvatar(avatarB64: a.avatarB64, name: a.name, size: 24),
            ),
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

class _HomeTab extends StatefulWidget {
  const _HomeTab();

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  Map<String, dynamic>? trending; // hottest public arena right now

  @override
  void initState() {
    super.initState();
    AccountService.instance.listPublicEvents().then((r) {
      if (mounted && r != null && r.isNotEmpty) {
        setState(() => trending = r.first);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final a = AppData.i;
    return SafeArea(
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Row(children: [
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
          // Compact wallet — streak · XP · coins in one pill so the header
          // stays on one line (three separate pills squeezed MYNDASH vertical).
          StatWallet(streak: a.streak, xp: a.xp, coins: a.coins),
          const SizedBox(width: 8),
          // ---------- theme toggle (moon in Arcade, sun in Night) ----------
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
          const SizedBox(width: 8),
          Builder(
            builder: (context) => Glass(
              radius: 30,
              padding: const EdgeInsets.all(10),
              onTap: () => Scaffold.of(context).openEndDrawer(),
              child: const Icon(Icons.menu_rounded, size: 18),
            ),
          ),
        ]),
        const SizedBox(height: 16),
        // ---------- moving hero slider (Netflix-style) ----------
        AutoSlider(
          height: 148,
          children: [
            _heroCard(
              emoji: '',
              art: 'arena',
              badge: 'TRENDING',
              title: trending != null
                  ? '${trending!['title']}'
                  : 'Tonight\'s Arenas · 10pm',
              subtitle: trending != null
                  ? 'live public arena · ${(trending!['players'] as Map?)?.length ?? 1} playing · ${(trending!['fee'] as num?)?.toInt() ?? 0} entry'
                  : 'six rating venues · same paper worldwide · weekdays',
              colors: [DC.amber, DC.magenta],
              onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ArenaHubScreen()))
                  .then((_) => setState(() {})),
            ),
            _heroCard(
              emoji: '',
              art: 'games',
              badge: 'NEW',
              title: 'Real Chess is here',
              subtitle: 'full board, full rules, rated rivals — 1v1 tab',
              colors: [DC.cyan, DC.violet],
              onTap: () => _goTab(context, 2),
            ),
            _heroCard(
              emoji: '',
              art: 'mania',
              badge: 'WEEKEND',
              title: 'Rated Contest',
              subtitle:
                  'Sat & Sun · you: ${a.contestRating} ${DC.contestTitle(a.contestRating)}',
              colors: [DC.violet, DC.cyan],
              onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ContestScreen()))
                  .then((_) => setState(() {})),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Daily Arena — a dedicated contest-style space
        Glass(
          tint: DC.amber,
          onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const Daily5Screen()))
              .then((_) => setState(() {})),
          child: Row(children: [
            Text(a.dailyDone ? '' : '', style: const TextStyle(fontSize: 34)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('DAILY CHALLENGE',
                        style: TextStyle(
                            fontWeight: FontWeight.w900, letterSpacing: 1)),
                    Text(
                        a.dailyDone
                            ? 'All 11 cleared · streak ${a.streak}'
                            : '${a.dailyProgress}/11 cleared · 5 math + 6 open games',
                        style: TextStyle(fontSize: 12, color: DC.dim)),
                  ]),
            ),
            Icon(Icons.chevron_right, color: DC.dim),
          ]),
        ),
        const SizedBox(height: 12),
        // quick grid — contest / arenas / chess journey / live drop
        Row(children: [
          Expanded(
            child: _quickCard(
                icon: Icons.workspace_premium,
                color: DC.violet,
                title: 'CONTEST',
                subtitle: 'Sat & Sun · rated',
                onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ContestScreen()))
                    .then((_) => setState(() {}))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _quickCard(
                icon: Icons.stadium_rounded,
                color: DC.amber,
                title: 'ARENAS',
                subtitle: 'join · host · win pots',
                onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ArenaHubScreen()))
                    .then((_) => setState(() {}))),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: _quickCard(
                icon: Icons.sports_esports,
                color: DC.cyan,
                title: 'GAMES ',
                onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const GamesHubScreen()))
                    .then((_) => setState(() {}))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _quickCard(
                icon: Icons.bolt,
                color: DC.danger,
                title: 'LIVE DROP',
                onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const LiveDropScreen()))
                    .then((_) => setState(() {}))),
          ),
        ]),
        const SizedBox(height: 12),
        // squads & community — clan up, rep your campus/company
        Row(children: [
          Expanded(
            child: _quickCard(
                icon: Icons.groups_rounded,
                color: DC.lime,
                title: a.squadName.isEmpty ? 'SQUADS' : 'MY SQUAD',
                onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const SquadsScreen()))
                    .then((_) => setState(() {}))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _quickCard(
                icon: Icons.diversity_3,
                color: DC.cyan,
                title: 'COMMUNITY',
                subtitle: 'college · corporate · squad',
                onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const CommunityHubScreen()))
                    .then((_) => setState(() {}))),
          ),
        ]),
        const SizedBox(height: 20),
        Row(children: [
          Text('TRAIN',
              style: TextStyle(fontSize: 11, letterSpacing: 2, color: DC.dim)),
          const Spacer(),
          GestureDetector(
            onTap: () => _goTab(context, 1),
            child: Text('see all ',
                style: TextStyle(fontSize: 12, color: DC.cyan)),
          ),
        ]),
        const SizedBox(height: 10),
        SizedBox(
          height: 110,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final c in cats.where((c) => c.ready).take(8))
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: SizedBox(
                    width: 120,
                    child: Glass(
                      radius: 20,
                      padding: const EdgeInsets.all(12),
                      onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => LevelMapScreen(cat: c)))
                          .then((_) => setState(() {})),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(c.icon, color: c.color, size: 20),
                          const Spacer(),
                          Text(c.name,
                              maxLines: 2,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 12)),
                          Text('${AppData.i.unlockedLevel(c.id)} rating',
                              style: TextStyle(
                                  fontSize: 10,
                                  color:
                                      DC.band(AppData.i.unlockedLevel(c.id)))),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Glass(
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const StoreScreen())),
          child: Row(children: [
            Icon(Icons.storefront_rounded, color: DC.amber, size: 30),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Coin packs and reward previews · coming in v2',
                  style: TextStyle(fontSize: 13)),
            ),
            Icon(Icons.chevron_right, color: DC.dim),
          ]),
        ),
        const SizedBox(height: 16),
      ]),
    );
  }

  void _goTab(BuildContext context, int i) {
    context.findAncestorStateOfType<_DistrictHomeState>()?.goTab(i);
  }

  Widget _quickCard({
    required IconData icon,
    required Color color,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    // Fixed height + an always-present subtitle line so every tile is the
    // exact same size whether or not it has a subtitle.
    return SizedBox(
      height: 116,
      child: Glass(
        tint: color,
        onTap: onTap,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 8),
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w900, letterSpacing: 1)),
          const SizedBox(height: 2),
          Text(subtitle ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: DC.dim)),
        ]),
      ),
    );
  }

  Widget _heroCard({
    required String emoji,
    required String badge,
    required String title,
    required String subtitle,
    required List<Color> colors,
    required VoidCallback onTap,
    String? art, // animated MyndArt theme replaces the emoji
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colors[0].withOpacity(0.30),
                colors[1].withOpacity(0.16),
                DC.fgo(0.03),
              ]),
          border: Border.all(color: colors[0].withOpacity(0.45)),
        ),
        child: Row(children: [
          if (art != null)
            MyndArt(theme: art, size: 56)
          else
            Text(emoji, style: const TextStyle(fontSize: 44)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: colors[0].withOpacity(0.25),
                    ),
                    child: Text(badge,
                        style: TextStyle(
                            fontSize: 9,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.w900,
                            color: colors[0])),
                  ),
                  const SizedBox(height: 6),
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 18)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: DC.dim)),
                ]),
          ),
          Icon(Icons.chevron_right, color: DC.fg54),
        ]),
      ),
    );
  }
}

/// ---------------- right-side hamburger menu ----------------
class _MyndDrawer extends StatelessWidget {
  const _MyndDrawer();

  @override
  Widget build(BuildContext context) {
    final a = AppData.i;
    return Drawer(
      backgroundColor: DC.bg2,
      child: SafeArea(
        child: Column(children: [
          const SizedBox(height: 20),
          Text('MYNDASH',
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: DC.electric,
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                  letterSpacing: 2)),
          Text('@${a.username.isEmpty ? 'guest' : a.username}',
              style: TextStyle(fontSize: 12, color: DC.dim)),
          const SizedBox(height: 14),
          Divider(color: DC.fg12, height: 1),
          Expanded(
            child: ListView(padding: EdgeInsets.zero, children: [
              _nav(context, Icons.person_rounded, DC.cyan, 'My Profile',
                  () => const ProfileScreen()),
              _nav(context, Icons.sports_esports, DC.violet, 'Games',
                  () => const GamesHubScreen()),
              _nav(context, Icons.psychology_alt, DC.magenta, 'AI Trainer',
                  () => const AiCoachScreen()),
              _nav(
                  context,
                  Icons.groups_rounded,
                  DC.lime,
                  a.squadName.isEmpty ? 'Squads' : 'Squad · ${a.squadName}',
                  () => const SquadsScreen()),
              _nav(context, Icons.diversity_3, DC.cyan, 'Community',
                  () => const CommunityHubScreen()),
              _nav(context, Icons.bolt, DC.danger, 'Live Drop',
                  () => const LiveDropScreen()),
              _nav(context, Icons.stadium_rounded, DC.amber, 'Arenas & Events',
                  () => const ArenaHubScreen()),
              _nav(context, Icons.storefront_rounded, DC.magenta,
                  'Store · Upcoming', () => const StoreScreen()),
              _nav(context, Icons.leaderboard_rounded, DC.lime, 'Leaderboard',
                  () => const LeaderboardScreen()),
              _nav(context, Icons.person_search_rounded, DC.cyan,
                  'Find Friends', () => const FriendsSearchScreen()),
              _nav(
                  context,
                  Icons.school_rounded,
                  DC.cyan,
                  a.college.isEmpty ? 'College' : 'College · ${a.college}',
                  () => const CommunityScreen(type: 'college')),
              _nav(
                  context,
                  Icons.apartment_rounded,
                  DC.amber,
                  a.company.isEmpty ? 'Corporate' : 'Corporate · ${a.company}',
                  () => const CommunityScreen(type: 'company')),
              Divider(color: DC.fg12, height: 16),
              ListTile(
                dense: true,
                leading: Icon(Icons.help_outline, color: DC.cyan),
                title: const Text('Help'),
                onTap: () {
                  Navigator.pop(context);
                  _info(context, 'How MYNDASH works', '''
 SOLVE — train 25 disciplines across ratings 800–2500. Two clears unlock the next rating.

 DAILY ARENA — 5 progressively locked math questions plus 6 open games. Clear all 11 to complete the day.

 1v1 — duel rated rivals in math, chess tactics or darts. Win = Elo + coins.

 ARENA — 8 players, 10 questions, winner takes the pot.

 CONTEST — rated weekend contests. Climb Beginner Trishul.

 STORE — preview upcoming coin packs and rewards. Purchases and redemptions are not active yet.

 AI TRAINER — personalized training and game analysis for every player.

 CHESS JOURNEY — 30 levels of real chess, 1000 3900 Elo. Win 5 games per level.

 LIVE DROP — daily at 13:00 & 21:00, the whole world gets the same 15 questions.

 SQUADS · COLLEGE · CORPORATE — rep your crew, campus or company on ranked boards.''');
                },
              ),
              ListTile(
                dense: true,
                leading: Icon(Icons.info_outline, color: DC.violet),
                title: const Text('About'),
                onTap: () {
                  Navigator.pop(context);
                  _info(
                      context,
                      'About MYNDASH',
                      '''
MYNDASH — the mind arena. Puzzles as a sport; your brain is the athlete.

Version 2.0 · made with for sharp minds everywhere.'''
                          '\n\nIncludes Reflex Duel — the original reaction game.');
                },
              ),
              ListTile(
                dense: true,
                leading: Icon(Icons.feedback_outlined, color: DC.amber),
                title: const Text('Share Feedback'),
                onTap: () {
                  Navigator.pop(context);
                  _feedback(context);
                },
              ),
              Divider(color: DC.fg12, height: 16),
              ListTile(
                dense: true,
                leading: Icon(Icons.description_outlined, color: DC.dim),
                title: const Text('Terms of Service',
                    style: TextStyle(fontSize: 13)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const TermsScreen()));
                },
              ),
              ListTile(
                dense: true,
                leading: Icon(Icons.privacy_tip_outlined, color: DC.dim),
                title: const Text('Privacy Policy',
                    style: TextStyle(fontSize: 13)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const PrivacyScreen()));
                },
              ),
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

  void _info(BuildContext context, String title, String body) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: DC.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(body,
              style: TextStyle(fontSize: 13, height: 1.5, color: DC.text)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Close')),
        ],
      ),
    );
  }

  void _feedback(BuildContext context) {
    final c = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DC.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Share feedback'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: c,
            maxLines: 4,
            autofocus: true,
            decoration: InputDecoration(
                hintText: 'What should we improve?',
                hintStyle: TextStyle(color: DC.dim)),
          ),
          const SizedBox(height: 8),
          Text('Feedback is stored locally in this build.',
              style: TextStyle(fontSize: 11, color: DC.dim)),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final messenger = ScaffoldMessenger.of(ctx);
              Navigator.pop(ctx);
              messenger.showSnackBar(const SnackBar(
                  content: Text('Thanks! Your feedback means a lot ')));
            },
            child: const Text('Send'),
          ),
        ],
      ),
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

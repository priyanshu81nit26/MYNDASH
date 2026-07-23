import 'dart:math';

import 'package:flutter/material.dart';

import '../core/state.dart';
import '../engine/mind_engines.dart';
import '../theme_district.dart';
import '../ui/art.dart';
import '../ui/glass.dart';
import 'practice_screen.dart';
import 'arrow_screen.dart';
import 'chess_duel.dart';
import 'cross_math_screen.dart';
import 'hanoi_screen.dart';
import 'mind_games.dart';
import 'numpuzzle_screen.dart';
import 'sudoku_screen.dart';
import 'chess_journey.dart';
import 'cube_screens.dart';
import 'darts_duel.dart';
import 'darts_game.dart';
import 'daily_vault.dart';
import 'art_race.dart';
import 'online_play.dart';
import 'scribble.dart';
import 'showdown_screen.dart';
import 'word_finder.dart';

const _chessBotNames = [
  'Nova',
  'Zephyr',
  'Kira',
  'Axel',
  'Mira',
  'Dash',
  'Rehan',
  'Tara',
  'Vik',
  'Luna',
  'Omen',
  'Pixel',
  'Sage',
  'Rio',
  'Ivy',
  'Neo',
];

/// One uniform accent for every game card (was a different colour per game).
const _gamesAccent = Color(0xFF38BDF8); // soft light sky-blue

/// The 5 mind-fun games share the MindRace framework: rated practice variants,
/// rated bots, and online + friend races (first to solve wins).
class _MindGameDef {
  final String id, image, title, label, emoji, subtitle;
  final Color accent;
  final MindScreenBuilder builder;
  const _MindGameDef(this.id, this.image, this.title, this.label, this.emoji,
      this.subtitle, this.accent, this.builder);
}

final _mindGames = <_MindGameDef>[
  _MindGameDef(
      'crossmath',
      'crossmath',
      'CROSS MATH',
      'Cross Math',
      '123',
      'A full arithmetic crossword with six linked equations, givens, and missing crossings.',
      const Color(0xFFFFB020),
      crossMathBuilder),
  _MindGameDef(
      'arrow',
      'arrow',
      'ARROW PUZZLE',
      'Arrow Puzzle',
      '🧭',
      'Tap tiles to spin them (and their neighbours) — point every arrow up.',
      const Color(0xFF7C4DFF),
      arrowBuilder),
  _MindGameDef(
      'sudoku',
      'sudoku',
      'SUDOKU',
      'Sudoku',
      '🌿',
      'Classic 9×9 logic on a club-green felt board. 1-9 once per row/col/box.',
      const Color(0xFF35D07F),
      sudokuBuilder),
  _MindGameDef(
      'hanoi',
      'hanoi',
      'TOWER OF HANOI',
      'Hanoi',
      '🗼',
      'Lift and drop glossy discs — rebuild the tower without stacking big on small.',
      const Color(0xFFFFC400),
      hanoiBuilder),
  _MindGameDef(
      'numpz',
      'numpuzzle',
      'NUMBER PUZZLE',
      'Number Puzzle',
      '🔢',
      'Slide chunky 3D tiles into order. Boards grow 3×3 → 5×5.',
      const Color(0xFF2E7BFF),
      numpzBuilder),
];

/// ============================================================
/// GAMES — Chess · Darts · Rubik's Cube
/// Every game has Practice/Journey + Compete (bot / online /
/// friend with a shareable code & link) — one consistent flow.
/// ============================================================
class GamesHubScreen extends StatelessWidget {
  final bool kidsMode; // kids: practice yes, online no
  const GamesHubScreen({super.key, this.kidsMode = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // theme-aware backdrop (was a hardcoded dark gradient)
      body: ShaderBackground(
        child: SafeArea(
          child: ListView(padding: const EdgeInsets.all(20), children: [
            Row(children: [
              Glass(
                  radius: 16,
                  padding: const EdgeInsets.all(8),
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back, size: 18)),
              const SizedBox(width: 12),
              Text('GAMES ', style: Theme.of(context).textTheme.titleLarge),
            ]),
            const SizedBox(height: 16),
            const Center(child: MyndArt(theme: 'games', size: 92)),
            const SizedBox(height: 14),
            if (!kidsMode) ...[
              Glass(
                tint: DC.cyan,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DailyVaultScreen()),
                ),
                child: Row(children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: DC.cyan.withOpacity(0.14),
                    ),
                    child: Icon(Icons.inventory_2_outlined, color: DC.cyan),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('DAILY VAULT',
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8)),
                        Text(
                          '${AppData.i.dailyArchive.length} completed daily problems · grouped by game and rating',
                          style: TextStyle(fontSize: 11, color: DC.dim),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: DC.dim),
                ]),
              ),
              const SizedBox(height: 14),
            ],
            // 2-per-row grid — was one full-width card per row.
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.8,
              children: [
                // Reflex Duel — the original action game, front and centre
                _gameCard(
                  context,
                  image: 'reflex',
                  art: 'reflex',
                  title: 'REFLEX DUEL',
                  onPractice: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const PracticeScreen())),
                  onCompete: kidsMode
                      ? () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const PracticeScreen()))
                      : () => showReflexCompete(context),
                  competeLabel: kidsMode ? 'PLAY' : 'COMPETE',
                ),
                _gameCard(
                  context,
                  image: 'chess',
                  art: 'games',
                  title: 'CHESS',
                  onPractice: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ChessJourneyScreen())),
                  onCompete: kidsMode
                      ? () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ChessDuelScreen(wager: 0)))
                      : () => _competeSheet(context, 'chess', 'std', 'Chess ',
                          botScreen: () => const ChessDuelScreen(wager: 0)),
                  competeLabel: kidsMode ? 'VS BOT' : 'COMPETE',
                ),
                _gameCard(
                  context,
                  image: 'darts',
                  art: 'games',
                  title: 'DARTS',
                  onPractice: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const DartsJourneyScreen())),
                  onCompete: kidsMode
                      ? () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const DartsDuelScreen(wager: 0)))
                      : () => _competeSheet(context, 'darts', 'std', 'Darts ',
                          botScreen: () => const DartsDuelScreen(
                              wager: 0, matchmaking: true),
                          ratedBotScreen: (rating) => DartsDuelScreen(
                              wager: 0,
                              botRating: rating,
                              matchmaking: true)),
                  competeLabel: kidsMode ? 'VS BOT' : 'COMPETE',
                ),
                _gameCard(
                  context,
                  image: 'cube',
                  art: 'games',
                  title: 'RUBIK\'S CUBE',
                  // Cube is free for everyone now — no Pro paywall.
                  onPractice: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const CubeHomeScreen())),
                  onCompete: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const CubeHomeScreen())),
                  competeLabel: kidsMode ? 'PLAY' : 'OPEN',
                ),
                _gameCard(
                  context,
                  image: 'scribble',
                  art: 'games',
                  title: 'SCRIBBLE',
                  onPractice: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ScribbleScreen())),
                  onCompete: kidsMode
                      ? () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ScribbleScreen()))
                      : () => _competeSheet(
                          context, 'scribble', 'std', 'Scribble ',
                          botScreen: () => const ScribbleScreen()),
                  competeLabel: kidsMode ? 'PLAY' : 'COMPETE',
                ),
                _gameCard(
                  context,
                  image: 'word',
                  art: 'games',
                  title: 'WORD FINDER',
                  onPractice: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const WordFinderJourneyScreen())),
                  onCompete: kidsMode
                      ? () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const WordFinderScreen()))
                      : () => _competeSheet(
                          context, 'wordfind', 'std', 'Word Finder ',
                          botScreen: () => const WordFinderScreen()),
                  competeLabel: kidsMode ? 'PLAY' : 'COMPETE',
                ),
                _gameCard(
                  context,
                  image: 'art',
                  art: 'games',
                  title: 'ART HEIST',
                  onPractice: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ArtHeistJourneyScreen())),
                  onCompete: kidsMode
                      ? () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ArtRaceScreen(size: 4)))
                      : () => _competeSheet(context, 'art', '3', 'Art Heist ',
                          botScreen: () => const ArtRaceScreen(size: 4),
                          ratedBotScreen: (rating) => ArtRaceScreen(
                              size: rating < 1300
                                  ? 3
                                  : rating < 1800
                                      ? 4
                                      : 5)),
                  competeLabel: kidsMode ? 'RACE' : 'COMPETE',
                ),
                for (final g in _mindGames)
                  _gameCard(
                    context,
                    image: g.image,
                    art: 'games',
                    title: g.title,
                    onPractice: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => g.id == 'hanoi'
                                ? const HanoiJourneyScreen()
                                : MindLevelSelect(
                                    game: g.id,
                                    title: '${g.title} ${g.emoji}',
                                    accent: g.accent,
                                    subtitle: g.subtitle,
                                    builder: g.builder))),
                    onCompete: kidsMode
                        ? () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => g.id == 'hanoi'
                                    ? HanoiScreen(
                                        botLevel: 3, combo: HanoiCombo(3, 3))
                                    : g.builder(level: 3, botLevel: 3)))
                        : g.id == 'hanoi'
                            ? () => hanoiCompeteSheet(context)
                            : () => mindCompeteSheet(context,
                                game: g.id,
                                label: '${g.label} ${g.emoji}',
                                accent: g.accent,
                                builder: g.builder),
                    competeLabel: kidsMode ? 'VS BOT' : 'COMPETE',
                  ),
              ],
            ),
            const SizedBox(height: 4),
            if (!kidsMode)
              Center(
                child: Text(
                    'Compete online pairs you with the closest rating.\nFriend rooms share one code + link across every game.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: DC.dim)),
              )
            else
              Center(
                child: Text('Practice all games — online duels unlock at 12+.',
                    style: TextStyle(fontSize: 11, color: DC.dim)),
              ),
          ]),
        ),
      ),
    );
  }

  /// Uniform card: gamified name plate + Practice/Compete. No photos for
  /// now — every card is the game's name in display type on a tinted
  /// plate, so cards work identically before/after real art is dropped in.
  Widget _gameCard(
    BuildContext context, {
    required String image,
    required String art,
    required String title,
    required VoidCallback onPractice,
    required VoidCallback onCompete,
    String competeLabel = 'COMPETE',
  }) {
    // Theme-adaptive action colour: light blue on Arcade (light), green on
    // Night (dark) — same on both buttons, white text either way.
    final btnBg =
        ThemeCtl.isDark ? const Color(0xFF22C55E) : const Color(0xFF4FA8E8);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: DC.fgo(0.04),
        border: Border.all(color: _gamesAccent.withOpacity(0.30)),
      ),
      child: Column(children: [
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _gamesAccent.withOpacity(0.20),
                  DC.violet.withOpacity(0.14),
                ],
              ),
            ),
            alignment: Alignment.center,
            child: Text(title,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 15,
                    letterSpacing: 0.6,
                    height: 1.15,
                    shadows: [
                      Shadow(
                          color: _gamesAccent.withOpacity(0.45),
                          blurRadius: 10),
                    ])),
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _miniButton('PRACTICE', onPractice, btnBg)),
          const SizedBox(width: 6),
          Expanded(child: _miniButton(competeLabel, onCompete, btnBg)),
        ]),
      ]),
    );
  }

  /// Small compact button for the grid card — deliberately its own local
  /// widget (not NeonButton/GhostButton) so its size and font are tuned to
  /// the narrower grid cell without touching those shared components.
  Widget _miniButton(String label, VoidCallback onTap, Color bg) {
    return SizedBox(
      height: 30,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(15),
        child: Ink(
          decoration:
              BoxDecoration(color: bg, borderRadius: BorderRadius.circular(15)),
          child: InkWell(
            borderRadius: BorderRadius.circular(15),
            onTap: onTap,
            child: Center(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                      color: Colors.white)),
            ),
          ),
        ),
      ),
    );
  }

  void _competeSheet(
      BuildContext context, String game, String sub, String label,
      {required Widget Function() botScreen,
      Widget Function(int rating)? ratedBotScreen}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: DC.bg2,
      isScrollControlled: true, // small screens / button-nav phones
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (c) => SafeArea(
        // keep every option above the system button-navigation bar
        child: SingleChildScrollView(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom + 12),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('COMPETE · $label',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              NeonButton(
                label: 'VS BOT',
                icon: Icons.smart_toy,
                onPressed: () async {
                  Navigator.pop(c);
                  final selectedRating = await pickMindBotLevel(context, label);
                  if (selectedRating == null || !context.mounted) return;
                  if (game == 'chess') {
                    final tMin = await pickTimeControl(context, label);
                    if (tMin == null || !context.mounted) return;
                    final botName =
                        _chessBotNames[Random().nextInt(_chessBotNames.length)];
                    ShowdownScreen.go(context,
                        title: '1V1 · BOT',
                        oppName: botName,
                        detail: '$selectedRating · ${timeControlLabel(tMin)}',
                        autoStart: false,
                        game: () => ChessDuelScreen(
                            timeMinutes: tMin,
                            botName: botName,
                            practiceRating: selectedRating));
                    return;
                  }
                  // Every other game gets the same get-ready lobby.
                  startBotMatch(context,
                      label: label,
                      detail: 'Bot rating $selectedRating',
                      game: () =>
                          ratedBotScreen?.call(selectedRating) ?? botScreen());
                },
              ),
              const SizedBox(height: 10),
              NeonButton(
                label: 'SEARCH ONLINE',
                icon: Icons.public,
                colors: [DC.magenta, DC.violet],
                onPressed: () async {
                  Navigator.pop(c);
                  var tMin = 0;
                  if (game == 'chess') {
                    final picked = await pickTimeControl(context, label);
                    if (picked == null || !context.mounted) return;
                    tMin = picked;
                  }
                  if (!context.mounted) return;
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => MatchmakingScreen(
                              game: game,
                              sub: sub,
                              label: label,
                              timeMinutes: tMin,
                              botScreen: botScreen)));
                },
              ),
              const SizedBox(height: 10),
              GhostButton(
                label: 'PLAY A FRIEND',
                icon: Icons.group,
                onPressed: () {
                  Navigator.pop(c);
                  showFriendPlayDialog(context, game, sub, label);
                },
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

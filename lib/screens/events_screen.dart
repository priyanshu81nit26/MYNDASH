import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../core/state.dart';
import '../engine/arena_game_catalog.dart';
import '../engine/banks.dart';
import '../engine/event_calendar.dart';
import '../engine/question.dart';
import '../engine/rating_catalog.dart';
import '../services/account_service.dart';
import '../theme_district.dart';
import '../ui/extras.dart';
import '../ui/glass.dart';
import '../ui/share_card.dart';
import 'art_race.dart' show ArtPainter, ArtRaceScreen;
import 'chess_duel.dart';
import 'compete.dart';
import 'crossword_screen.dart';
import 'event_leaderboard.dart';
import 'numpuzzle_screen.dart';
import 'store_screen.dart';
import 'sudoku_screen.dart';

/// ============================================================
/// ARENAS 3.0 — rating-range esports arenas.
///  · MYNDASH OFFICIAL: six named venues by rating bracket, every
///    weekday. Register before 10 pm — play starts 10 pm sharp,
///    30 questions / 30 minutes, the whole world gets the same
///    seeded paper. Ended papers land in REVISE automatically.
///  · PLAYER-HOSTED: public (scheduled and discoverable) or
///    winner takes all, up to 32/64/128 players by plan) or
///    private (code-join, rating-range gated, ¾-¼ prize split,
///    up to 10/30/100 players by plan). Any topic in the app,
///    10–30 questions, 10–30 minutes.
/// ============================================================

/// Display name for an arena topic id.
String topicLabel(String id) => ArenaGameCatalog.byId(id).label;

int _joinedCount(Map<String, dynamic> e) => (e['players'] as Map?)?.length ?? 0;

/// Live pot: entry fee × entrants (min 2 so a pot always shows).
int _pot(Map<String, dynamic> e) {
  final fee = (e['fee'] as num?)?.toInt() ?? 0;
  return fee * max(_joinedCount(e), 2);
}

String _fmtLeft(Duration d) {
  if (d.isNegative) return 'now';
  if (d.inDays >= 1) return '${d.inDays}d ${d.inHours % 24}h';
  if (d.inHours >= 1) return '${d.inHours}h ${d.inMinutes % 60}m';
  if (d.inMinutes >= 1) return '${d.inMinutes}m ${d.inSeconds % 60}s';
  return '${d.inSeconds}s';
}

/// Shared join flow: eligibility → confirm → (register | pay & play).
Future<void> joinArena(BuildContext context, Map<String, dynamic> e,
    {VoidCallback? onDone}) async {
  final a = AppData.i;
  final service = AccountService.instance;
  final fee = (e['fee'] as num?)?.toInt() ?? 0;
  final isPublic = e['public'] == true;

  final organization = e['org'] as String?;
  if (organization != null) {
    final split = organization.indexOf(':');
    final type = split < 0 ? '' : organization.substring(0, split);
    final name = split < 0 ? organization : organization.substring(split + 1);
    final mine = type == 'college' ? a.college : a.company;
    if (mine.trim().toLowerCase() != name.trim().toLowerCase()) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('Only verified members of $name can join this arena.')));
      return;
    }
  }

  final startAt = (e['startAt'] as num?)?.toInt();
  if (startAt == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'This legacy arena has no scheduled start. Ask the host to create a new hourly arena.',
        ),
      ),
    );
    return;
  }
  final eventDurationMin = ((e['durationMin'] as num?)?.toInt() ?? 10)
      .clamp(AccountService.arenaMinMinutes, AccountService.arenaMaxMinutes)
      .toInt();
  final now = DateTime.now().millisecondsSinceEpoch;
  final lobbyEndsAt = startAt + arenaLobbyDuration.inMilliseconds;
  final completed = now >= lobbyEndsAt + eventDurationMin * 60 * 1000;
  if (completed) {
    final eventId = '${e['id'] ?? ''}';
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventLeaderboardScreen(
          title: '${e['title'] ?? 'ARENA'}'.toUpperCase(),
          subtitle: 'Final player-hosted Arena standings',
          loadScores: () =>
              AccountService.instance.fetchHostedArenaScores(eventId),
        ),
      ),
    );
    return;
  }

  // Every hosted arena may define an eligibility range.
  final lo = (e['ratingMin'] as num?)?.toInt() ?? 0;
  final hi = (e['ratingMax'] as num?)?.toInt() ?? 9999;
  if (lo > 0 && (a.contestRating < lo || a.contestRating > hi)) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('This arena is for rating ${AccountService.rangeLabel((
          lo,
          hi
        ))} — yours is ${a.contestRating}.')));
    return;
  }

  final joined = _joinedCount(e);
  final maxP = (e['maxPlayers'] as num?)?.toInt() ?? 8;
  final already = await service.isHostedArenaRegistered(e);
  if (!context.mounted) return;
  if (!already && joined >= maxP) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('This arena is full.')));
    return;
  }

  final notStarted = now < startAt;
  final split1 = (e['split1'] as num?)?.toInt() ?? (isPublic ? 100 : 75);
  final split2 = (e['split2'] as num?)?.toInt() ?? (isPublic ? 0 : 25);
  final qCount = ((e['questionCount'] as num?)?.toInt() ?? 10)
      .clamp(AccountService.arenaMinQuestions, AccountService.arenaMaxQuestions)
      .toInt();
  final durMin = eventDurationMin;
  final category = (e['category'] as String?) ?? 'mixed';
  final categories = (e['categories'] as List?)?.cast<String>();
  final gameSpec = ArenaGameCatalog.byId(category);
  final gameRating =
      ((e['gameRating'] as num?)?.toInt() ?? 800).clamp(800, 2500).toInt();

  // Pay to register/enter. A player who already paid to register isn't
  // charged again when they return to play. Short on coins → offer top-up.
  if (notStarted && fee > 0 && !already) {
    if (!await ensureCoins(context, fee, 'enter ${e['title']}')) return;
    if (!context.mounted) return;
  }

  if (notStarted && already) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Registered. ${e['title']} opens at ${fmtEventDateTime(startAt)}.',
        ),
      ),
    );
    onDone?.call();
    return;
  }

  if (!notStarted && !already) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Registration is closed. Only players registered before the start time can compete.',
        ),
      ),
    );
    return;
  }

  final sure = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: DC.bg2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
          notStarted ? 'Register for ${e['title']}?' : 'Enter ${e['title']}?'),
      content: Text([
        '${categories != null && categories.length > 1 ? '${categories.length} topics combined' : topicLabel(category)} · level $gameRating · '
            '${gameSpec.usesQuestionCount ? '$qCount questions' : '1 seeded board'} · '
            '$durMin min',
        if (fee == 0) 'Free entry.' else 'Entry: $fee 🪙',
        'Players: $joined/$maxP',
        split2 > 0
            ? 'Prize: 🥇 $split1% · 🥈 $split2% of the pot (${_pot(e)} 🪙 so far)'
            : 'Prize: 🥇 winner takes the whole pot (${_pot(e)} 🪙 so far)',
        if (notStarted)
          '⏳ Starts in ${_fmtLeft(Duration(milliseconds: startAt - now))} — it can NOT start before that.',
      ].join('\n')),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(notStarted ? 'Register' : 'Enter')),
      ],
    ),
  );
  if (sure != true || !context.mounted) return;

  // -------- not started yet: register (pay now), play later --------
  if (notStarted) {
    final error = await service.registerHostedArena(e);
    if (!context.mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    if (fee > 0) a.spendCoins(fee);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Registered! ${e['title']} starts in ${_fmtLeft(Duration(milliseconds: startAt - now))} — come back then.')));
    onDone?.call();
    return;
  }

  // -------- live: shared 2-minute lobby → the seeded paper --------
  final access = await service.authorizeHostedArena(e);
  if (!context.mounted) return;
  if (!access.allowed) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(access.message ?? 'Could not verify your registration.'),
      ),
    );
    return;
  }
  Widget buildGame() => _buildHostedArenaGame(
        event: e,
        fee: fee,
        category: category,
        categories: categories,
        questionCount: qCount,
        durationMin: durMin,
        gameRating: gameRating,
        players: max(joined, 2),
        prizePool: _pot(e),
        split1: split1,
        split2: split2,
        seed: (e['seed'] as num?)?.toInt(),
      );
  final verifiedLobbyEnd = access.lobbyEndsAt ?? lobbyEndsAt;
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => DateTime.now().millisecondsSinceEpoch < verifiedLobbyEnd
          ? ArenaLobbyScreen.forEvent(
              e: e,
              lobbyEndsAt: verifiedLobbyEnd,
              buildGame: buildGame,
            )
          : buildGame(),
    ),
  );
  final gained = 50 + fee ~/ 5;
  a.addXp(gained);
  if (context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Arena complete: +$gained XP')));
  }
  onDone?.call();
}

Widget _buildHostedArenaGame({
  required Map<String, dynamic> event,
  required int fee,
  required String category,
  List<String>? categories,
  required int questionCount,
  required int durationMin,
  required int gameRating,
  required int players,
  required int prizePool,
  required int split1,
  required int split2,
  required int? seed,
}) {
  final eventId = '${event['id'] ?? ''}';
  final mode = ArenaGameCatalog.byId(category).mode;
  if (mode == ArenaGameMode.questions) {
    return ArenaMatchScreen(
      fee: fee,
      category: category,
      categories: categories,
      questionCount: questionCount,
      durationMin: durationMin,
      gameRating: gameRating,
      players: players,
      prizePool: prizePool,
      split1: split1,
      split2: split2,
      seed: seed,
      eventId: eventId,
    );
  }

  final variant = ((seed ?? 1).abs() % 15) + 1;
  final legacyLevel = RatingCatalog.legacyLevelForRating(
    gameRating,
    variant: variant,
  );
  return _TimedArenaChallenge(
    duration: Duration(minutes: durationMin),
    eventId: eventId,
    builder: (submitScore) => switch (mode) {
      ArenaGameMode.sudoku => SudokuScreen(
          level: legacyLevel,
          botLevel: legacyLevel,
          puzzleSeed: seed,
          displayRating: gameRating,
          arenaScore: submitScore,
        ),
      ArenaGameMode.artHeist => ArtRaceScreen(
          size: gameRating < 1300
              ? 3
              : gameRating < 1900
                  ? 4
                  : 5,
          puzzleSeed: seed,
          arenaScore: submitScore,
        ),
      ArenaGameMode.crossword => CrosswordScreen(
          level: legacyLevel,
          botLevel: legacyLevel,
          puzzleSeed: seed,
          displayRating: gameRating,
          arenaScore: submitScore,
        ),
      ArenaGameMode.chess => ChessDuelScreen(
          practiceRating: gameRating,
          botMatch: true,
          timeMinutes: durationMin,
          arenaScore: submitScore,
        ),
      ArenaGameMode.numberPuzzle => NumPuzzleScreen(
          level: legacyLevel,
          botLevel: legacyLevel,
          puzzleSeed: seed,
          displayRating: gameRating,
          arenaScore: submitScore,
        ),
      ArenaGameMode.questions => const SizedBox.shrink(),
    },
  );
}

class _TimedArenaChallenge extends StatefulWidget {
  final Duration duration;
  final String eventId;
  final Widget Function(ValueChanged<int> submitScore) builder;

  const _TimedArenaChallenge({
    required this.duration,
    required this.eventId,
    required this.builder,
  });

  @override
  State<_TimedArenaChallenge> createState() => _TimedArenaChallengeState();
}

class _TimedArenaChallengeState extends State<_TimedArenaChallenge> {
  late final int _endsAt =
      DateTime.now().millisecondsSinceEpoch + widget.duration.inMilliseconds;
  Timer? _timer;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _submitted) return;
      if (_left <= Duration.zero) {
        _expire();
      } else {
        setState(() {});
      }
    });
  }

  Duration get _left => Duration(
        milliseconds: max(0, _endsAt - DateTime.now().millisecondsSinceEpoch),
      );

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _submit(int score) {
    if (_submitted) return;
    _submitted = true;
    _timer?.cancel();
    AccountService.instance.submitHostedArenaScore(widget.eventId, score);
    if (mounted) setState(() {});
  }

  Future<void> _expire() async {
    _submit(0);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Arena time complete'),
        content: const Text(
          'Your current board has been closed and the final score is saved.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('VIEW EVENT'),
          ),
        ],
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: widget.builder(_submit)),
        if (!_submitted)
          Positioned(
            top: MediaQuery.paddingOf(context).top + 10,
            right: 16,
            child: IgnorePointer(
              child: Material(
                color: Colors.transparent,
                child: Glass(
                  radius: 16,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  tint: _left < const Duration(minutes: 2) ? DC.danger : null,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 16,
                        color: _left < const Duration(minutes: 2)
                            ? DC.danger
                            : DC.cyan,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _fmtLeft(_left),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// ============================================================
/// ARENA / TOURNAMENT LOBBY — a two-minute "who's here" screen shown before the
/// questions open, so nobody drops straight into the paper cold. Streams the
/// entrant list live and counts down, then replaces itself with the game.
/// ============================================================
class ArenaLobbyScreen extends StatefulWidget {
  final String title;
  final DecorationImage? bgImage;
  final int lobbyEndsAt;
  final List<String> initialPlayers;
  final Stream<List<String>>? playersStream;
  final Widget Function() buildGame;
  const ArenaLobbyScreen({
    super.key,
    required this.title,
    required this.buildGame,
    required this.lobbyEndsAt,
    this.bgImage,
    this.initialPlayers = const [],
    this.playersStream,
  });

  /// Build a lobby for an events-collection arena/tournament from its map.
  factory ArenaLobbyScreen.forEvent(
      {Key? key,
      required Map<String, dynamic> e,
      required int lobbyEndsAt,
      required Widget Function() buildGame}) {
    final id = e['id'] as String?;
    return ArenaLobbyScreen(
      key: key,
      title: '${e['title'] ?? 'ARENA'}',
      lobbyEndsAt: lobbyEndsAt,
      bgImage: eventBgImage(e, darken: 0.62),
      initialPlayers: arenaPlayerNames(e['players']).isNotEmpty
          ? arenaPlayerNames(e['players'])
          : [AppData.i.username],
      playersStream: (id != null && id != 'local')
          ? AccountService.instance.eventPlayersStream(id)
          : null,
      buildGame: buildGame,
    );
  }

  @override
  State<ArenaLobbyScreen> createState() => _ArenaLobbyScreenState();
}

class _ArenaLobbyScreenState extends State<ArenaLobbyScreen> {
  Timer? _timer;
  StreamSubscription? _sub;
  List<String> _players = [];
  bool _launched = false;

  int get _left => max(
        0,
        ((widget.lobbyEndsAt - DateTime.now().millisecondsSinceEpoch) / 1000)
            .ceil(),
      );

  @override
  void initState() {
    super.initState();
    _players = widget.initialPlayers.isNotEmpty
        ? widget.initialPlayers
        : [AppData.i.username];
    _sub = widget.playersStream?.listen((p) {
      if (mounted && p.isNotEmpty) setState(() => _players = p);
    });
    if (_left <= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _start());
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_left <= 0) {
        _start();
      } else {
        setState(() {});
      }
    });
  }

  void _start() {
    if (_launched || !mounted) return;
    _launched = true;
    _timer?.cancel();
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => widget.buildGame()));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = widget.bgImage;
    return Scaffold(
      backgroundColor: const Color(0xFF07070C),
      body: Container(
        decoration: BoxDecoration(
          image: bg,
          gradient: bg == null
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [DC.violet.withOpacity(0.4), const Color(0xFF07070C)])
              : null,
        ),
        child: SafeArea(
          child: Column(children: [
            const SizedBox(height: 20),
            Text(widget.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white)),
            const SizedBox(height: 6),
            const Text('GET READY',
                style: TextStyle(
                    letterSpacing: 4,
                    fontSize: 12,
                    color: Colors.white70,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 18),
            // countdown ring
            Container(
              width: 96,
              height: 96,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.4),
                border: Border.all(color: DC.cyan, width: 3),
                boxShadow: [
                  BoxShadow(color: DC.cyan.withOpacity(0.5), blurRadius: 20)
                ],
              ),
              child: Text(
                  '${(_left ~/ 60).toString().padLeft(2, '0')}:${(_left % 60).toString().padLeft(2, '0')}',
                  style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: Colors.white)),
            ),
            const SizedBox(height: 8),
            Text('questions open when the shared timer reaches 00:00',
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 20),
            Text(
                '${_players.length} PLAYER${_players.length == 1 ? '' : 'S'} IN',
                style: TextStyle(
                    letterSpacing: 2,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: DC.cyan)),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.82,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12),
                itemCount: _players.length,
                itemBuilder: (_, i) => _playerChip(_players[i]),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Only registered players are shown here.',
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _playerChip(String name) {
    final me = name == AppData.i.username;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
              colors: me ? [DC.lime, DC.cyan] : [DC.violet, DC.magenta]),
          boxShadow: [
            BoxShadow(
                color: (me ? DC.lime : DC.violet).withOpacity(0.5),
                blurRadius: 12)
          ],
        ),
        child: Center(
          child: Text(name.isEmpty ? '?' : name.characters.first.toUpperCase(),
              style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  color: Colors.white)),
        ),
      ),
      const SizedBox(height: 6),
      SizedBox(
        width: 84,
        child: Text(me ? 'You' : '@$name',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white)),
      ),
    ]);
  }
}

/// ============================================================
/// ARENAS HUB
/// ============================================================
class EventsScreen extends StatefulWidget {
  /// When embedded as the bottom-nav ARENAS tab there is nothing
  /// to pop, so the back arrow is hidden.
  final bool embedded;
  const EventsScreen({super.key, this.embedded = false});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final svc = AccountService.instance;
  List<Map<String, dynamic>>? public; // null = loading/offline
  List<Map<String, dynamic>> myEvents = []; // arenas I've hosted
  bool loading = true;
  Timer? ticker;
  final Set<int> registered = {}; // brackets registered today (local)

  @override
  void initState() {
    super.initState();
    _load();
    // 1s tick keeps every countdown honest
    ticker = Timer.periodic(
        const Duration(seconds: 1), (_) => mounted ? setState(() {}) : null);
  }

  @override
  void dispose() {
    ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final r = await svc.listPublicEvents();
    final mine = await svc.listMyEvents();
    // Rehydrate today's official-bracket registrations from the server so
    // "registered" survives an app restart (was a local-only flag).
    final regs = await svc.myOfficialRegs(AppData.todayKey());
    if (mounted) {
      setState(() {
        public = r;
        myEvents = mine ?? [];
        registered.addAll(regs);
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = AppData.i;
    final now = DateTime.now();
    final myBracket = bracketIndexFor(a.contestRating);
    final livePublic = (public ?? [])
        .where((e) => (e['startAt'] as num?) != null)
        .toList()
      ..sort((x, y) =>
          ((x['startAt'] as num?) ?? 0).compareTo((y['startAt'] as num?) ?? 0));

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: widget.embedded ? 70 : 0),
        child: FloatingActionButton.extended(
          onPressed: () => _hostArena(context),
          backgroundColor: DC.violet,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('HOST ARENA',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        ),
      ),
      body: ShaderBackground(
        child: SafeArea(
          child: RefreshIndicator(
            color: DC.cyan,
            onRefresh: _load,
            child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                children: [
                  Row(children: [
                    if (!widget.embedded) ...[
                      Glass(
                          radius: 16,
                          padding: const EdgeInsets.all(8),
                          onTap: () => Navigator.pop(context),
                          child: const Icon(Icons.arrow_back, size: 18)),
                      const SizedBox(width: 12),
                    ],
                    Text('ARENAS',
                        style: Theme.of(context).textTheme.titleLarge),
                    const Spacer(),
                    Pill(
                        icon: Icons.monetization_on,
                        label: '${a.coins}',
                        color: DC.amber),
                  ]),
                  const SizedBox(height: 16),
                  // ============ TOURNAMENTS slider (upcoming public) ============
                  if (livePublic.isNotEmpty) ...[
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 22, vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient:
                              LinearGradient(colors: [DC.amber, DC.magenta]),
                          boxShadow: [
                            BoxShadow(
                                color: DC.amber.withOpacity(0.4),
                                blurRadius: 16),
                          ],
                        ),
                        child: const Text('🏟 TOURNAMENTS',
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                letterSpacing: 1,
                                color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    AutoSlider(
                      height: 172,
                      children: [
                        for (final e in livePublic.take(8))
                          _TournamentSlide(
                            e: e,
                            onTap: () =>
                                joinArena(context, e, onDone: () => _load()),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                  // ============ MY ARENAS (hosted by me) ============
                  if (myEvents.isNotEmpty) ...[
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 22, vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient:
                              LinearGradient(colors: [DC.violet, DC.magenta]),
                          boxShadow: [
                            BoxShadow(
                                color: DC.violet.withOpacity(0.4),
                                blurRadius: 16),
                          ],
                        ),
                        child: const Text('🏆 MY ARENAS',
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                letterSpacing: 1,
                                color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    AutoSlider(
                      height: 190,
                      children: [
                        for (final e in myEvents)
                          _MyArenaTile(
                            e: e,
                            onTap: () =>
                                joinArena(context, e, onDone: () => _load()),
                            onDelete: () => _deleteMyArena(e),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                  // ============ MYNDASH OFFICIAL DAILY ARENAS ============
                  Row(children: [
                    Text('🏟️ MYNDASH OFFICIAL · EVERY WEEKDAY 10 PM',
                        style: TextStyle(
                            fontSize: 10, letterSpacing: 2, color: DC.dim)),
                    const Spacer(),
                    _officialStatusChip(now),
                  ]),
                  const SizedBox(height: 8),
                  AutoSlider(
                    height: 172,
                    children: [
                      for (var b = 0; b < officialBrackets.length; b++)
                        _officialCard(context, b, b == myBracket, now),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '30 questions · 30 minutes · identical worldwide paper · '
                    'ended papers reappear in Solve 📚 at their rating level.',
                    style: TextStyle(fontSize: 10, color: DC.dim, height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  // ============ live public arenas slider ============
                  if (livePublic.isNotEmpty) ...[
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 22, vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: LinearGradient(colors: [DC.cyan, DC.lime]),
                          boxShadow: [
                            BoxShadow(
                                color: DC.cyan.withOpacity(0.35),
                                blurRadius: 16),
                          ],
                        ),
                        child: const Text('PUBLIC ARENAS',
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                letterSpacing: 1,
                                color: Colors.black)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    AutoSlider(
                      height: 190,
                      children: [
                        for (final e in livePublic.take(6))
                          _HeroEventCard(
                              e: e,
                              onJoin: () =>
                                  joinArena(context, e, onDone: () => _load())),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                  // ============ community join ============
                  Text('PLAYER ARENAS',
                      style: TextStyle(
                          fontSize: 10, letterSpacing: 2, color: DC.dim)),
                  const SizedBox(height: 8),
                  Glass(
                    tint: DC.cyan,
                    onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const PublicEventsScreen()))
                        .then((_) => _load()),
                    child: Row(children: [
                      const Text('🌐', style: TextStyle(fontSize: 28)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('JOIN PUBLIC ARENAS',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14)),
                              Text(
                                  loading
                                      ? 'loading…'
                                      : public == null
                                          ? 'offline — pull to retry'
                                          : '${public!.length} open now · browse & filter',
                                  style:
                                      TextStyle(fontSize: 11, color: DC.dim)),
                            ]),
                      ),
                      Icon(Icons.chevron_right, color: DC.dim),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  Glass(
                    tint: DC.magenta,
                    onTap: () => _joinPrivate(context),
                    child: Row(children: [
                      Text('🔐', style: TextStyle(fontSize: 28)),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('JOIN PRIVATE ARENA',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14)),
                              Text('got a code? enter it here',
                                  style:
                                      TextStyle(fontSize: 11, color: DC.dim)),
                            ]),
                      ),
                      Icon(Icons.chevron_right, color: DC.dim),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  // hosting rules explainer
                  Glass(
                    radius: 20,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('HOSTING RULES',
                              style: TextStyle(
                                  fontSize: 10,
                                  letterSpacing: 2,
                                  color: DC.dim)),
                          SizedBox(height: 8),
                          Text(
                              '🔐 Private — join by code · rating-range gated · '
                              '¾ of the pot to 🥇, ¼ to 🥈 · up to 100 players',
                              style: TextStyle(
                                  fontSize: 12, color: DC.dim, height: 1.5)),
                          SizedBox(height: 6),
                          Text(
                              '🌐 Public — open to every rating · starts at YOUR set time, never before · '
                              '🥇 takes the whole pot · up to 128 players',
                              style: TextStyle(
                                  fontSize: 12, color: DC.dim, height: 1.5)),
                          SizedBox(height: 6),
                          Text(
                              '🎯 Both — any game/topic in MYNDASH · 10–30 questions · 10–30 minutes · '
                              'everyone gets the identical seeded paper.',
                              style: TextStyle(
                                  fontSize: 12, color: DC.dim, height: 1.5)),
                        ]),
                  ),
                  const SizedBox(height: 16),
                ]),
          ),
        ),
      ),
    );
  }

  // ---------------- official arenas ----------------

  Widget _officialStatusChip(DateTime now) {
    if (!isArenaDay(now)) {
      return Pill(icon: Icons.event_busy, label: 'weekend off', color: DC.dim);
    }
    final start = arenaStartFor(now);
    final end = arenaEndsAt(
      start,
      const Duration(minutes: arenaMinutes),
    );
    if (now.isBefore(start)) {
      return Pill(
          icon: Icons.timer,
          label: _fmtLeft(start.difference(now)),
          color: DC.amber);
    }
    if (now.isBefore(end)) {
      return Pill(icon: Icons.play_circle, label: 'LIVE', color: DC.lime);
    }
    return Pill(icon: Icons.check, label: 'ended', color: DC.dim);
  }

  Widget _officialCard(BuildContext context, int b, bool mine, DateTime now) {
    final a = AppData.i;
    final br = officialBrackets[b];
    final start = arenaStartFor(now);
    final end = arenaEndsAt(
      start,
      const Duration(minutes: arenaMinutes),
    );
    final isDay = isArenaDay(now);
    final live = isDay && !now.isBefore(start) && now.isBefore(end);
    final played = a.lastArenaDayKey == AppData.todayKey();
    final accent = mine ? DC.cyan : DC.amber;

    String status;
    if (!isDay) {
      status = 'back Monday · 10 pm';
    } else if (now.isBefore(start)) {
      status = registered.contains(b)
          ? 'registered · starts in ${_fmtLeft(start.difference(now))}'
          : 'register · starts in ${_fmtLeft(start.difference(now))}';
    } else if (live) {
      status = played
          ? 'played today'
          : 'LIVE · ${_fmtLeft(end.difference(now))} left';
    } else {
      status = 'ended — practise in Solve';
    }

    return GestureDetector(
      onTap: !mine
          ? () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(
                  '${br.name} is for rating ${br.range} — your contest rating is ${a.contestRating}.')))
          : () => _officialAction(context, b, now),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
              color: accent.withOpacity(mine ? 0.85 : 0.4),
              width: mine ? 2 : 1),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 14)],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(fit: StackFit.expand, children: [
          CustomPaint(painter: ArtPainter(br.name.hashCode, Size.zero)),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.25, 1.0],
                colors: [Colors.transparent, Colors.black.withOpacity(0.82)],
              ),
            ),
          ),
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(colors: [DC.amber, DC.magenta]),
              ),
              child: const Text('OFFICIAL',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                      color: Colors.white)),
            ),
          ),
          if (mine)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: DC.lime.withOpacity(0.9),
                ),
                child: const Text('YOUR VENUE',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: Colors.black)),
              ),
            ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(br.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: Colors.white)),
              const SizedBox(height: 2),
              Text('rating ${br.range}',
                  style: TextStyle(fontSize: 10, color: DC.fg70)),
              const SizedBox(height: 6),
              Text(status,
                  style: TextStyle(
                      fontSize: 11,
                      color: mine ? DC.lime : accent,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
        ]),
      ),
    );
  }

  Future<void> _officialAction(
      BuildContext context, int b, DateTime now) async {
    final a = AppData.i;
    if (!isArenaDay(now)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Official arenas run Monday–Friday. Weekends belong to the CONTESTS 🏆')));
      return;
    }
    final start = arenaStartFor(now);
    final end = arenaEndsAt(
      start,
      const Duration(minutes: arenaMinutes),
    );
    if (now.isBefore(start)) {
      // registration window
      if (registered.contains(b)) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Already registered — ${officialBrackets[b].name} starts in ${_fmtLeft(start.difference(now))}.')));
        return;
      }
      final error = await svc.registerOfficialArena(AppData.todayKey(), b);
      if (!context.mounted) return;
      if (error != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error)));
        return;
      }
      setState(() => registered.add(b));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '✓ Registered for ${officialBrackets[b].name}! Doors open at 10 pm sharp.')));
      return;
    }
    if (now.isBefore(end)) {
      if (!registered.contains(b)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Registration is closed. Only registered players can compete.')));
        return;
      }
      if (a.lastArenaDayKey == AppData.todayKey()) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('You already played today\'s arena — see you tomorrow!')));
        return;
      }
      final access = await svc.authorizeOfficialArena(AppData.todayKey(), b);
      if (!context.mounted) return;
      if (!access.allowed) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(access.message ??
                'Could not verify your arena registration.')));
        return;
      }
      final lobbyEndsAt = access.lobbyEndsAt ??
          arenaQuestionsOpenAt(start).millisecondsSinceEpoch;
      await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => DateTime.now().millisecondsSinceEpoch <
                      lobbyEndsAt
                  ? ArenaLobbyScreen(
                      lobbyEndsAt: lobbyEndsAt,
                      title: '${officialBrackets[b].name} · MYNDASH OFFICIAL',
                      initialPlayers: [AppData.i.username],
                      playersStream: AccountService.instance
                          .officialArenaPlayersStream(AppData.todayKey(), b),
                      buildGame: () => OfficialArenaPlayScreen(bracket: b),
                    )
                  : OfficialArenaPlayScreen(bracket: b)));
      if (mounted) setState(() {});
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Today\'s arena has ended — its questions now live in Solve 📚 at their level.')));
  }

  // ---------------- private join ----------------

  Future<void> _joinPrivate(BuildContext context) async {
    final c = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: DC.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Enter arena code'),
        content: TextField(
          controller: c,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          maxLength: 6,
          decoration:
              const InputDecoration(hintText: 'e.g. 7KQ2ZX', counterText: ''),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              child: const Text('Find')),
        ],
      ),
    );
    if (code == null || code.isEmpty || !mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Looking up arena…')));
    final e = await svc.findEventByCode(code);
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    if (e == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('No arena with that code — check it and your internet.')));
      return;
    }
    joinArena(context, e, onDone: () => setState(() {}));
  }

  // ---------------- hosting ----------------

  Future<void> _hostArena(BuildContext context) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: DC.bg2,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => const _ArenaCreateSheet(),
    );
    if (created == true) _load();
  }

  Future<void> _deleteMyArena(Map<String, dynamic> e) async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: DC.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Delete this arena?'),
        content: Text(
            '"${e['title']}" will be removed for everyone. This can\'t be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              style: FilledButton.styleFrom(backgroundColor: DC.danger),
              child: const Text('Delete')),
        ],
      ),
    );
    if (sure != true || !mounted) return;
    final err = await svc.deleteArena(e);
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Arena deleted.')));
    _load();
  }
}

/// ============================================================
/// OFFICIAL ARENA PLAY — today's seeded 30-question paper.
/// ============================================================
class OfficialArenaPlayScreen extends StatefulWidget {
  final int bracket;
  const OfficialArenaPlayScreen({super.key, required this.bracket});

  @override
  State<OfficialArenaPlayScreen> createState() =>
      _OfficialArenaPlayScreenState();
}

class _OfficialArenaPlayScreenState extends State<OfficialArenaPlayScreen> {
  late final int day = bankDayIndex();
  late final int endsAt = arenaStartFor(DateTime.now())
      .add(const Duration(minutes: arenaMinutes))
      .millisecondsSinceEpoch;
  late Question q;
  int index = 0;
  int correct = 0;
  int score = 0;
  bool answered = false;
  bool wasRight = false;
  bool finished = false;
  Timer? _tick;
  final typed = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (DateTime.now().millisecondsSinceEpoch >= endsAt) {
        _finish();
      } else {
        setState(() {});
      }
    });
    _load();
  }

  @override
  void dispose() {
    _tick?.cancel();
    typed.dispose();
    super.dispose();
  }

  void _load() {
    q = bankArena(day, widget.bracket, index);
    answered = false;
    typed.clear();
    setState(() {});
  }

  void _answer(String input) {
    if (answered || finished) return;
    answered = true;
    wasRight = q.check(input);
    if (wasRight) {
      correct++;
      score += 100;
    }
    setState(() {});
    Timer(const Duration(milliseconds: 700), () {
      if (!mounted || finished) return;
      index++;
      if (index >= arenaQuestionCount) {
        _finish();
      } else {
        _load();
      }
    });
  }

  Future<void> _finish() async {
    if (finished) return;
    finished = true;
    _tick?.cancel();
    final a = AppData.i;
    final br = officialBrackets[widget.bracket];
    final frac = correct / arenaQuestionCount;
    final delta = (300 * (frac - 0.5)).round().clamp(-150, 150).toInt();
    a.contestRating = (a.contestRating + delta).clamp(1000, 3200).toInt();
    a.lastArenaDayKey = AppData.todayKey();
    a.addXp(correct * 15);
    a.addCoins(correct * 10);
    a.recordMatch(
        mode: 'Arena · ${br.name}',
        opponent: 'the ${br.range} field',
        result: delta > 0 ? 'W' : (delta == 0 ? 'D' : 'L'),
        delta: delta);
    final svc = AccountService.instance;
    svc.submitOfficialArenaScore(AppData.todayKey(), widget.bracket, score);
    svc.updatePublicProfile();
    a.save();
    final top =
        await svc.fetchOfficialArenaScores(AppData.todayKey(), widget.bracket);
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: DC.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (delta > 0) const ConfettiBurst(height: 60),
            Text(br.emoji, style: const TextStyle(fontSize: 44)),
            Text('${br.name.toUpperCase()} · DONE',
                style: Theme.of(context).textTheme.displayMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text('$correct / $arenaQuestionCount solved · score $score',
                style: TextStyle(color: DC.dim)),
            const SizedBox(height: 8),
            Text('${delta >= 0 ? '+' : ''}$delta → ${a.contestRating}',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: delta >= 0 ? DC.lime : DC.danger)),
            Text('+${correct * 15} XP · +${correct * 10} coins',
                style: TextStyle(color: DC.amber, fontSize: 13)),
            if (top != null && top.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('TONIGHT\'S TOP',
                  style:
                      TextStyle(fontSize: 9, letterSpacing: 2, color: DC.dim)),
              const SizedBox(height: 4),
              for (final (i, s) in top.take(5).indexed)
                Text('${i + 1}. @${s.key} — ${s.value}',
                    style: TextStyle(
                        fontSize: 12,
                        color: s.key == a.username ? DC.cyan : DC.dim)),
            ],
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => shareResult(context,
                  '${br.emoji} ${br.name} arena on MYNDASH — $correct/$arenaQuestionCount solved, rating ${a.contestRating}. Tomorrow 10pm, be there.'),
              icon: Icon(Icons.ios_share, size: 16, color: DC.cyan),
              label: Text('Share result',
                  style: TextStyle(color: DC.cyan, fontSize: 13)),
            ),
            const SizedBox(height: 6),
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
    final leftMs =
        (endsAt - DateTime.now().millisecondsSinceEpoch).clamp(0, 1 << 31);
    final mm = (leftMs ~/ 60000).toString().padLeft(2, '0');
    final ss = ((leftMs % 60000) ~/ 1000).toString().padLeft(2, '0');
    final urgent = leftMs < 5 * 60000;
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
                    onTap: _finish,
                    child: const Icon(Icons.flag, size: 18)),
                const Spacer(),
                Glass(
                  radius: 20,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  tint: urgent ? DC.danger : null,
                  child: Text('$mm:$ss',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: urgent ? DC.danger : DC.cyan)),
                ),
                const Spacer(),
                Text('${index + 1}/$arenaQuestionCount · ✓$correct',
                    style: TextStyle(fontSize: 12, color: DC.dim)),
              ]),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Glass(
                        radius: 24,
                        padding: const EdgeInsets.all(20),
                        border: answered
                            ? Border.all(
                                color: wasRight ? DC.lime : DC.danger, width: 2)
                            : null,
                        child: Column(children: [
                          Text(q.prompt,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: q.prompt.length > 60 ? 16 : 22,
                                  fontWeight: FontWeight.w700,
                                  height: 1.4)),
                          if (answered && !wasRight)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text('Answer: ${q.answer}',
                                  style: TextStyle(
                                      color: DC.lime,
                                      fontWeight: FontWeight.w700)),
                            ),
                        ]),
                      ),
                      const SizedBox(height: 18),
                      if (q.options != null)
                        for (final o in q.options!)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: GhostButton(
                                label: o,
                                height: 46,
                                onPressed: answered ? null : () => _answer(o)),
                          )
                      else ...[
                        Glass(
                          radius: 18,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: TextField(
                            controller: typed,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true, signed: true),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: DC.cyan),
                            decoration: const InputDecoration(
                                border: InputBorder.none, hintText: '?'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        NeonButton(
                            label: 'SUBMIT',
                            height: 46,
                            onPressed:
                                answered ? null : () => _answer(typed.text)),
                      ],
                    ],
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// A host-uploaded event background as a [DecorationImage], or null. Dimmed
/// so overlaid text stays legible. Bad/oversized data is ignored safely.
DecorationImage? eventBgImage(Map e, {double darken = 0.5}) {
  final bg = e['bg'] as String?;
  if (bg == null || bg.isEmpty) return null;
  try {
    return DecorationImage(
      image: MemoryImage(base64Decode(bg)),
      fit: BoxFit.cover,
      colorFilter:
          ColorFilter.mode(Colors.black.withOpacity(darken), BlendMode.darken),
    );
  } catch (_) {
    return null;
  }
}

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

/// "Sat 12 Jul · 9:00 PM" from an epoch-ms timestamp.
String fmtEventDateTime(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final ap = d.hour < 12 ? 'AM' : 'PM';
  final mm = d.minute.toString().padLeft(2, '0');
  return '${_weekdays[d.weekday - 1]} ${d.day} ${_months[d.month - 1]} · $h12:$mm $ap';
}

/// A tournament slide (upcoming public arena) — background image if the host
/// uploaded one, the title, and its DATE + TIME front and centre.
class _TournamentSlide extends StatelessWidget {
  final Map<String, dynamic> e;
  final VoidCallback onTap;
  const _TournamentSlide({required this.e, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fee = (e['fee'] as num?)?.toInt() ?? 0;
    final startAt = (e['startAt'] as num?)?.toInt();
    final joined = (e['players'] as Map?)?.length ?? 0;
    final maxP = (e['maxPlayers'] as num?)?.toInt() ?? 32;
    final bg = eventBgImage(e, darken: 0.55);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: DC.amber.withOpacity(0.55)),
          image: bg,
          gradient: bg == null
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                      DC.amber.withOpacity(0.30),
                      DC.magenta.withOpacity(0.18),
                      DC.fgo(0.03)
                    ])
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  _chip(fee == 0 ? '🎟 FREE' : '🪙 $fee', DC.amber),
                  const Spacer(),
                  _chip('$joined/$maxP', DC.cyan),
                ]),
                Column(children: [
                  Text('${e['title'] ?? 'Tournament'}',
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: Colors.white)),
                  const SizedBox(height: 8),
                  if (startAt != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.black.withOpacity(0.45),
                        border: Border.all(color: DC.amber.withOpacity(0.7)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.event, size: 14, color: DC.amber),
                        const SizedBox(width: 6),
                        Text(fmtEventDateTime(startAt),
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                      ]),
                    ),
                ]),
                Text('tap to join →',
                    style: TextStyle(
                        fontSize: 11, color: Colors.white.withOpacity(0.85))),
              ]),
        ),
      ),
    );
  }

  Widget _chip(String s, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.black.withOpacity(0.4),
          border: Border.all(color: c.withOpacity(0.7)),
        ),
        child: Text(s,
            style:
                TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: c)),
      );
}

/// ---------------- hero card used inside the slider ----------------
/// Grid-style arena card with a unique generative neon artwork as its
/// "image" (same deterministic painter as Art Heist, seeded per arena —
/// no external image assets needed, and it's fair/reproducible).
class _HeroEventCard extends StatelessWidget {
  final Map<String, dynamic> e;
  final VoidCallback onJoin;
  const _HeroEventCard({required this.e, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    final fee = (e['fee'] as num?)?.toInt() ?? 0;
    final startAt = (e['startAt'] as num?)?.toInt();
    final now = DateTime.now().millisecondsSinceEpoch;
    final pending = startAt != null && now < startAt;
    final already =
        (e['players'] as Map?)?.containsKey(AppData.i.username) == true;
    final color = already ? DC.cyan : (pending ? DC.amber : DC.lime);
    final seed = (e['seed'] as num?)?.toInt() ?? e.hashCode;
    return GestureDetector(
      onTap: onJoin,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color.withOpacity(0.55)),
          boxShadow: const [
            BoxShadow(color: Colors.black45, blurRadius: 14),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(fit: StackFit.expand, children: [
          CustomPaint(painter: ArtPainter(seed, Size.zero)),
          // gradient scrim so the info stays legible over the art
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.3, 1.0],
                colors: [Colors.transparent, Colors.black.withOpacity(0.82)],
              ),
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: already
                ? Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: DC.lime,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('✓ REGISTERED',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: Colors.black)),
                  )
                : Icon(Icons.play_circle_fill,
                    color: Colors.white.withOpacity(0.92), size: 28),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${e['title']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: Colors.white)),
                const SizedBox(height: 2),
                Text(
                    'by @${e['organizer']} · ${topicLabel((e['category'] as String?) ?? 'mixed')} · ${_joinedCount(e)}/${(e['maxPlayers'] as num?)?.toInt() ?? 8} in',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: DC.fg70)),
                const SizedBox(height: 6),
                Row(children: [
                  _chip(fee == 0 ? 'FREE' : '$fee 🪙', color),
                  const SizedBox(width: 6),
                  _chip('pot ${_pot(e)} 🪙', DC.lime),
                  const SizedBox(width: 6),
                  _chip(
                      pending
                          ? '⏳ ${_fmtLeft(Duration(milliseconds: startAt - now))}'
                          : '🔴 LIVE',
                      pending ? DC.amber : DC.danger),
                ]),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _chip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: color.withOpacity(0.22),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w800, color: color)),
      );
}

/// ---------------- compact event row ----------------
/// ---------------- "my arenas" row: live countdown + delete ----------------
class _MyArenaTile extends StatelessWidget {
  final Map<String, dynamic> e;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _MyArenaTile(
      {required this.e, required this.onTap, required this.onDelete});

  static const _deleteCutoffMs = 15 * 60 * 1000;

  @override
  Widget build(BuildContext context) {
    final fee = (e['fee'] as num?)?.toInt() ?? 0;
    final maxP = (e['maxPlayers'] as num?)?.toInt() ?? 8;
    final startAt = (e['startAt'] as num?)?.toInt();
    final now = DateTime.now().millisecondsSinceEpoch;
    final pending = startAt != null && now < startAt;
    final live = startAt != null && !pending;
    final color = pending ? DC.amber : (live ? DC.danger : DC.cyan);

    // status text + whether deletion is currently allowed
    String status;
    bool canDelete;
    if (startAt == null) {
      status = 'private · instant join';
      canDelete = true;
    } else if (pending) {
      final remain = startAt - now;
      status = 'starts in ${_fmtLeft(Duration(milliseconds: remain))}';
      canDelete = remain >= _deleteCutoffMs;
    } else {
      status = 'LIVE NOW';
      canDelete = false;
    }
    final seed = (e['seed'] as num?)?.toInt() ?? e.hashCode;

    // Large themed card — art background + scrim, shown in a horizontal slider.
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color.withOpacity(0.55)),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 14)],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(fit: StackFit.expand, children: [
          CustomPaint(painter: ArtPainter(seed, Size.zero)),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.25, 1.0],
                colors: [Colors.transparent, Colors.black.withOpacity(0.82)],
              ),
            ),
          ),
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(colors: [DC.violet, DC.magenta]),
              ),
              child: const Text('MY ARENA',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                      color: Colors.white)),
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: IconButton(
              icon: Icon(Icons.delete_outline,
                  color: canDelete ? Colors.white : Colors.white24, size: 22),
              onPressed: canDelete ? onDelete : null,
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${e['title']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: Colors.white)),
              const SizedBox(height: 2),
              Text(
                  '${topicLabel((e['category'] as String?) ?? 'mixed')} · ${_joinedCount(e)}/$maxP in',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, color: DC.fg70)),
              const SizedBox(height: 6),
              Row(children: [
                _cardChip(fee == 0 ? 'FREE' : '$fee 🪙', color),
                const SizedBox(width: 6),
                _cardChip('pot ${_pot(e)} 🪙', DC.lime),
              ]),
              const SizedBox(height: 4),
              Text(status,
                  style: TextStyle(
                      fontSize: 11, color: color, fontWeight: FontWeight.w700)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _cardChip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: color.withOpacity(0.22),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w800, color: color)),
      );
}

class _EventTile extends StatelessWidget {
  final Map<String, dynamic> e;
  final VoidCallback onTap;
  const _EventTile({required this.e, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final fee = (e['fee'] as num?)?.toInt() ?? 0;
    final maxP = (e['maxPlayers'] as num?)?.toInt() ?? 8;
    final startAt = (e['startAt'] as num?)?.toInt();
    final now = DateTime.now().millisecondsSinceEpoch;
    final pending = startAt != null && now < startAt;
    final color = pending ? DC.amber : DC.cyan;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Glass(
        onTap: onTap,
        child: Row(children: [
          Text(pending ? '⏳' : '🎪', style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${e['title']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 15)),
              Text(
                  '@${e['organizer'] ?? '?'} · ${topicLabel((e['category'] as String?) ?? 'mixed')} · '
                  '${(e['questionCount'] as num?)?.toInt() ?? 10}q/${(e['durationMin'] as num?)?.toInt() ?? 10}m · '
                  '${_joinedCount(e)}/$maxP in',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: DC.dim)),
              if (pending)
                Text(
                    '⏳ starts in ${_fmtLeft(Duration(milliseconds: startAt - now))}',
                    style: TextStyle(
                        fontSize: 11,
                        color: DC.amber,
                        fontWeight: FontWeight.w700)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: color.withOpacity(0.15),
                border: Border.all(color: color.withOpacity(0.5)),
              ),
              child: Text(fee == 0 ? 'FREE' : '$fee 🪙',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w800, color: color)),
            ),
            const SizedBox(height: 3),
            Text('pot ${_pot(e)}',
                style: TextStyle(fontSize: 10, color: DC.lime)),
          ]),
        ]),
      ),
    );
  }
}

/// ---------------- auto-advancing slider (Netflix-style) ----------------
class AutoSlider extends StatefulWidget {
  final List<Widget> children;
  final double height;
  const AutoSlider({super.key, required this.children, this.height = 130});

  @override
  State<AutoSlider> createState() => _AutoSliderState();
}

class _AutoSliderState extends State<AutoSlider> {
  /// Infinite left-to-right carousel: auto-advances forever and wraps
  /// around. We start deep in a huge virtual range and index the real
  /// cards with modulo, so the user can also swipe both ways endlessly.
  static const int _base = 100000;
  late final PageController ctrl;
  Timer? timer;
  int page = 0;

  int get _n => widget.children.length;

  @override
  void initState() {
    super.initState();
    // Align the start to a multiple of n so the first visible dot is 0.
    final start = _n > 1 ? _base - (_base % _n) : 0;
    page = start;
    ctrl = PageController(viewportFraction: 0.88, initialPage: start);
    if (_n > 1) {
      timer = Timer.periodic(const Duration(milliseconds: 3600), (t) {
        if (!mounted || !ctrl.hasClients) return;
        ctrl.nextPage(
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutCubic);
      });
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = _n;
    if (n == 0) return const SizedBox.shrink();
    return Column(children: [
      SizedBox(
        height: widget.height,
        child: PageView.builder(
          controller: ctrl,
          // null itemCount = unbounded → infinite scroll.
          itemCount: n > 1 ? null : 1,
          onPageChanged: (i) => setState(() => page = i),
          itemBuilder: (context, i) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: widget.children[i % n],
          ),
        ),
      ),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var i = 0; i < n; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == page % n ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: i == page % n ? DC.cyan : DC.fg24,
            ),
          ),
      ]),
    ]);
  }
}

/// ============================================================
/// PUBLIC ARENAS BROWSER — dropdown filters + pagination
/// ============================================================
class PublicEventsScreen extends StatefulWidget {
  const PublicEventsScreen({super.key});

  @override
  State<PublicEventsScreen> createState() => _PublicEventsScreenState();
}

class _PublicEventsScreenState extends State<PublicEventsScreen> {
  static const perPage = 6;
  List<Map<String, dynamic>>? all;
  bool loading = true;
  int page = 0;
  bool filtersOpen = false;

  String catFilter = 'all';
  String statusFilter = 'all'; // all | upcoming | live
  String sizeFilter = 'any'; // any | small | medium | large
  String feeFilter = 'any'; // any | free | paid

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final r = await AccountService.instance.listPublicEvents();
    if (mounted) {
      setState(() {
        all = r;
        loading = false;
        page = 0;
      });
    }
  }

  List<Map<String, dynamic>> get filtered {
    var list = all ?? [];
    final now = DateTime.now().millisecondsSinceEpoch;
    if (catFilter != 'all') {
      list =
          list.where((e) => (e['category'] ?? 'mixed') == catFilter).toList();
    }
    if (statusFilter != 'all') {
      list = list.where((e) {
        final s = (e['startAt'] as num?)?.toInt();
        final pending = s != null && now < s;
        return statusFilter == 'upcoming' ? pending : !pending;
      }).toList();
    }
    if (sizeFilter != 'any') {
      list = list.where((e) {
        final m = (e['maxPlayers'] as num?)?.toInt() ?? 8;
        return switch (sizeFilter) {
          'small' => m <= 16,
          'medium' => m > 16 && m <= 64,
          _ => m > 64,
        };
      }).toList();
    }
    if (feeFilter != 'any') {
      list = list.where((e) {
        final f = (e['fee'] as num?)?.toInt() ?? 0;
        return feeFilter == 'free' ? f == 0 : f > 0;
      }).toList();
    }
    return list;
  }

  int get activeFilters =>
      (catFilter != 'all' ? 1 : 0) +
      (statusFilter != 'all' ? 1 : 0) +
      (sizeFilter != 'any' ? 1 : 0) +
      (feeFilter != 'any' ? 1 : 0);

  @override
  Widget build(BuildContext context) {
    final list = filtered;
    final pages = max(1, (list.length + perPage - 1) ~/ perPage);
    final safePage = page.clamp(0, pages - 1).toInt();
    final visible = list.skip(safePage * perPage).take(perPage).toList();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ShaderBackground(
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(children: [
                Glass(
                    radius: 16,
                    padding: const EdgeInsets.all(8),
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back, size: 18)),
                const SizedBox(width: 12),
                Text('PUBLIC ARENAS',
                    style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                Glass(
                    radius: 16,
                    padding: const EdgeInsets.all(8),
                    onTap: _load,
                    child: const Icon(Icons.refresh, size: 18)),
              ]),
            ),
            const SizedBox(height: 10),
            // ---------- collapsible dropdown filters ----------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Glass(
                radius: 18,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                onTap: () => setState(() => filtersOpen = !filtersOpen),
                child: Row(children: [
                  Icon(Icons.filter_list, size: 18, color: DC.cyan),
                  const SizedBox(width: 8),
                  Text(
                      activeFilters == 0
                          ? 'FILTERS'
                          : 'FILTERS ($activeFilters active)',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  Icon(
                      filtersOpen
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: DC.dim),
                ]),
              ),
            ),
            if (filtersOpen)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Glass(
                  radius: 18,
                  child: Column(children: [
                    _dd(
                        'GAME',
                        catFilter,
                        {
                          'all': 'All games',
                          for (final t in AccountService.arenaTopics)
                            t: topicLabel(t),
                        },
                        (v) => setState(() {
                              catFilter = v;
                              page = 0;
                            })),
                    _dd(
                        'STATUS',
                        statusFilter,
                        const {
                          'all': 'All',
                          'upcoming': '⏳ Upcoming (not started)',
                          'live': '🔴 Live now',
                        },
                        (v) => setState(() {
                              statusFilter = v;
                              page = 0;
                            })),
                    _dd(
                        'SIZE',
                        sizeFilter,
                        const {
                          'any': 'Any size',
                          'small': 'Up to 16 players',
                          'medium': '17–64 players',
                          'large': '65+ players',
                        },
                        (v) => setState(() {
                              sizeFilter = v;
                              page = 0;
                            })),
                    _dd(
                        'ENTRY',
                        feeFilter,
                        const {
                          'any': 'Any entry',
                          'free': 'Free only',
                          'paid': 'Paid (coins pot)',
                        },
                        (v) => setState(() {
                              feeFilter = v;
                              page = 0;
                            })),
                  ]),
                ),
              ),
            const SizedBox(height: 8),
            // ---------- list ----------
            Expanded(
              child: loading
                  ? Center(child: CircularProgressIndicator(color: DC.cyan))
                  : all == null
                      ? Center(
                          child: Padding(
                          padding: EdgeInsets.all(30),
                          child: Text(
                              'Can\'t reach the arena server.\nCheck your connection and tap refresh.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: DC.dim)),
                        ))
                      : visible.isEmpty
                          ? Center(
                              child: Text(
                                  'No arenas match these filters.\nHost one and start the party 🎪',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: DC.dim)))
                          : ListView(
                              padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
                              children: [
                                for (final e in visible)
                                  _EventTile(
                                      e: e,
                                      onTap: () =>
                                          joinArena(context, e, onDone: _load)),
                              ],
                            ),
            ),
            // ---------- pagination ----------
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                GhostButton(
                    label: '← Prev',
                    onPressed: safePage > 0
                        ? () => setState(() => page = safePage - 1)
                        : null),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('Page ${safePage + 1} / $pages',
                      style: TextStyle(fontSize: 12, color: DC.dim)),
                ),
                GhostButton(
                    label: 'Next →',
                    onPressed: safePage < pages - 1
                        ? () => setState(() => page = safePage + 1)
                        : null),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _dd(String label, String value, Map<String, String> options,
      ValueChanged<String> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        SizedBox(
          width: 64,
          child: Text(label,
              style: TextStyle(fontSize: 9, letterSpacing: 1.5, color: DC.dim)),
        ),
        Expanded(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              isDense: true,
              dropdownColor: DC.bg2,
              borderRadius: BorderRadius.circular(14),
              style: TextStyle(
                  fontSize: 13, color: DC.text, fontWeight: FontWeight.w600),
              items: [
                for (final e in options.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
      ]),
    );
  }
}

/// ============================================================
/// HOST ARENA SHEET — public/private, topic, size, paper, time
/// ============================================================
class _ArenaCreateSheet extends StatefulWidget {
  const _ArenaCreateSheet();

  @override
  State<_ArenaCreateSheet> createState() => _ArenaCreateSheetState();
}

class _ArenaCreateSheetState extends State<_ArenaCreateSheet> {
  final title = TextEditingController();
  bool isPublic = true;
  String category = 'mixed';
  bool wagered = false; // free vs coin-entry arena
  int fee = 0;
  int maxPlayers = 10;
  String? bgB64; // optional uploaded background (base64 jpeg)
  int questionCount = 15;
  int durationMin = 15;
  int rangeIdx = 0; // into AccountService.ratingRanges (private)
  int startInMin = 60; // public ultimatum preset
  bool busy = false;

  static const _startPresets = [
    (15, 'in 15 min'),
    (30, 'in 30 min'),
    (60, 'in 1 hour'),
    (120, 'in 2 hours'),
    (360, 'in 6 hours'),
    (720, 'in 12 hours'),
    (1440, 'in 24 hours'),
  ];

  int get _cap => isPublic
      ? AccountService.publicHostCap()
      : AccountService.privateHostCap();

  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  /// Pick + downscale a background image → small base64 jpeg. Kept tight
  /// (720px, q45) so it rides on the event node without bloating the list;
  /// anything over the cap is rejected rather than stored.
  Future<void> _pickBg() async {
    try {
      final x = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 720,
        maxHeight: 720,
        imageQuality: 45,
      );
      if (x == null) return;
      final bytes = await File(x.path).readAsBytes();
      if (bytes.length > 110 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('That image is too large — pick a smaller one.')));
        }
        return;
      }
      setState(() => bgB64 = base64Encode(bytes));
    } catch (_) {/* cancelled / unavailable */}
  }

  Future<void> _create() async {
    setState(() => busy = true);
    final range = AccountService.ratingRanges[rangeIdx];
    final requestedHours = max(1, (startInMin / 60).ceil());
    final startAt = nextHourlyArenaSlot(
      DateTime.now(),
      additionalHours: requestedHours - 1,
    ).millisecondsSinceEpoch;
    final (err, code) = await AccountService.instance.createArena(
      title: title.text.trim(),
      fee: fee,
      isPublic: isPublic,
      category: category,
      maxPlayers: maxPlayers,
      questionCount: questionCount,
      durationMin: durationMin,
      ratingMin: range.$1,
      ratingMax: range.$2,
      startAt: startAt,
      bgBase64: bgB64,
    );
    if (!mounted) return;
    setState(() => busy = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    if (code != null) {
      // private → beautiful shareable invite card
      await showDialog(
        context: context,
        builder: (c) => _InviteCardDialog(
          code: code,
          title: title.text.trim(),
          topic: topicLabel(category),
          range: AccountService.rangeLabel(range),
          fee: fee,
          maxPlayers: maxPlayers,
          questions: questionCount,
          minutes: durationMin,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '🌐 ${title.text.trim()} is up! It starts ${_startPresets.firstWhere((p) => p.$1 == startInMin).$2} — players can register until then.')));
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final a = AppData.i;
    final range = AccountService.ratingRanges[rangeIdx];
    return Padding(
      padding: EdgeInsets.only(
          left: 22,
          right: 22,
          top: 18,
          bottom: MediaQuery.of(context).viewInsets.bottom + 22),
      child: SingleChildScrollView(
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                        color: DC.fg24,
                        borderRadius: BorderRadius.circular(3))),
              ),
              const SizedBox(height: 14),
              Text('HOST AN ARENA',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              // -------- public / private --------
              Row(children: [
                for (final (pub, label, emoji) in [
                  (true, 'PUBLIC', '🌐'),
                  (false, 'PRIVATE', '🔐')
                ])
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        isPublic = pub;
                        maxPlayers = min(maxPlayers, _cap);
                      }),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: isPublic == pub
                              ? (pub ? DC.cyan : DC.magenta).withOpacity(0.18)
                              : DC.fgo(0.05),
                          border: Border.all(
                              color: isPublic == pub
                                  ? (pub ? DC.cyan : DC.magenta)
                                  : DC.fg12),
                        ),
                        child: Column(children: [
                          Text(emoji, style: const TextStyle(fontSize: 18)),
                          Text(label,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: isPublic == pub
                                      ? (pub ? DC.cyan : DC.magenta)
                                      : DC.dim)),
                        ]),
                      ),
                    ),
                  ),
              ]),
              const SizedBox(height: 6),
              Text(
                  isPublic
                      ? 'Open to every rating · 🥇 takes the WHOLE pot · starts at your set time, never before · up to ${AccountService.publicHostCap()} players on your plan'
                      : 'Join by code · rating-range gated · 🥇 gets ¾, 🥈 gets ¼ · up to ${AccountService.privateHostCap()} players on your plan',
                  style: TextStyle(fontSize: 11, color: DC.dim, height: 1.4)),
              const SizedBox(height: 12),
              TextField(
                  controller: title,
                  maxLength: 28,
                  decoration: const InputDecoration(
                      hintText: 'Arena name — e.g. Friday Night Minds',
                      counterText: '')),
              const SizedBox(height: 8),
              // optional background image
              GestureDetector(
                onTap: _pickBg,
                child: Container(
                  height: 84,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: DC.fgo(0.05),
                    border: Border.all(color: DC.fgo(0.14)),
                    image: bgB64 != null
                        ? DecorationImage(
                            image: MemoryImage(base64Decode(bgB64!)),
                            fit: BoxFit.cover)
                        : null,
                  ),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color:
                            Colors.black.withOpacity(bgB64 != null ? 0.5 : 0),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.image_outlined, size: 16, color: DC.cyan),
                        const SizedBox(width: 6),
                        Text(
                            bgB64 != null
                                ? 'Change background'
                                : 'Add a background image (optional)',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // -------- game / topic dropdown --------
              Text('GAME / TOPIC',
                  style:
                      TextStyle(fontSize: 10, letterSpacing: 2, color: DC.dim)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: DC.fgo(0.06),
                  border: Border.all(color: DC.fg12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: category,
                    isExpanded: true,
                    dropdownColor: DC.bg2,
                    borderRadius: BorderRadius.circular(14),
                    style: TextStyle(
                        fontSize: 14,
                        color: DC.text,
                        fontWeight: FontWeight.w700),
                    items: [
                      for (final t in AccountService.arenaTopics)
                        DropdownMenuItem(value: t, child: Text(topicLabel(t))),
                    ],
                    onChanged: (v) => setState(() => category = v ?? 'mixed'),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // -------- private: rating range dropdown --------
              if (!isPublic) ...[
                Text('WHO CAN JOIN — RATING RANGE',
                    style: TextStyle(
                        fontSize: 10, letterSpacing: 2, color: DC.dim)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: DC.fgo(0.06),
                    border: Border.all(color: DC.fg12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: rangeIdx,
                      isExpanded: true,
                      dropdownColor: DC.bg2,
                      borderRadius: BorderRadius.circular(14),
                      style: TextStyle(
                          fontSize: 14,
                          color: DC.text,
                          fontWeight: FontWeight.w700),
                      items: [
                        for (var i = 0;
                            i < AccountService.ratingRanges.length;
                            i++)
                          DropdownMenuItem(
                              value: i,
                              child: Text(AccountService.rangeLabel(
                                  AccountService.ratingRanges[i]))),
                      ],
                      onChanged: (v) => setState(() => rangeIdx = v ?? 0),
                    ),
                  ),
                ),
                if (range.$1 > 0 &&
                    (a.contestRating < range.$1 || a.contestRating > range.$2))
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                        'Heads-up: your own rating (${a.contestRating}) is outside this range.',
                        style: TextStyle(fontSize: 10, color: DC.amber)),
                  ),
                const SizedBox(height: 12),
              ],
              // -------- public: ultimatum start time --------
              if (isPublic) ...[
                Text('STARTS (ULTIMATUM — can\'t start earlier)',
                    style: TextStyle(
                        fontSize: 10, letterSpacing: 2, color: DC.dim)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: DC.fgo(0.06),
                    border: Border.all(color: DC.fg12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: startInMin,
                      isExpanded: true,
                      dropdownColor: DC.bg2,
                      borderRadius: BorderRadius.circular(14),
                      style: TextStyle(
                          fontSize: 14,
                          color: DC.text,
                          fontWeight: FontWeight.w700),
                      items: [
                        for (final (m, label) in _startPresets)
                          DropdownMenuItem(value: m, child: Text(label)),
                      ],
                      onChanged: (v) => setState(() => startInMin = v ?? 60),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              // -------- free vs wagered --------
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  Text('ENTRY',
                      style: TextStyle(
                          fontSize: 10, letterSpacing: 2, color: DC.dim)),
                  const Spacer(),
                  for (final (label, wag) in const [
                    ('🎟 FREE', false),
                    ('🪙 WAGERED', true)
                  ])
                    GestureDetector(
                      onTap: () => setState(() {
                        wagered = wag;
                        fee = wag ? (fee == 0 ? 50 : fee) : 0;
                      }),
                      child: Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: wagered == wag
                              ? LinearGradient(colors: [DC.amber, DC.magenta])
                              : null,
                          color: wagered == wag ? null : DC.fgo(0.06),
                        ),
                        child: Text(label,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: wagered == wag
                                    ? FontWeight.w900
                                    : FontWeight.w500)),
                      ),
                    ),
                ]),
              ),
              // entry-fee stepper only shows for wagered arenas
              if (wagered)
                _stepperRow('ENTRY FEE 🪙', fee, 25, 999, 25,
                    (v) => setState(() => fee = v)),
              _stepperRow('MAX PLAYERS', maxPlayers, 2, _cap, 1,
                  (v) => setState(() => maxPlayers = v)),
              _stepperRow(
                  'QUESTIONS (10–30)',
                  questionCount,
                  AccountService.arenaMinQuestions,
                  AccountService.arenaMaxQuestions,
                  1,
                  (v) => setState(() => questionCount = v)),
              _stepperRow(
                  'DURATION MIN (10–30)',
                  durationMin,
                  AccountService.arenaMinMinutes,
                  AccountService.arenaMaxMinutes,
                  1,
                  (v) => setState(() => durationMin = v)),
              const SizedBox(height: 4),
              Text(
                  'Pot: entry × players — ${isPublic ? 'winner takes 100%' : '🥇 75% · 🥈 25%'} · questions come from the ${topicLabel(category)} bank, identical for every entrant.',
                  style: TextStyle(fontSize: 10, color: DC.dim, height: 1.4)),
              const SizedBox(height: 14),
              NeonButton(
                label: busy ? 'CREATING…' : 'CREATE ARENA',
                icon: Icons.rocket_launch,
                onPressed: busy ? null : _create,
              ),
            ]),
      ),
    );
  }

  Widget _stepperRow(String label, int value, int lo, int hi, int step,
      ValueChanged<int> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Expanded(
          child: Text(label,
              style: TextStyle(fontSize: 10, letterSpacing: 2, color: DC.dim)),
        ),
        GhostButton(
            label: '−',
            onPressed:
                value - step >= lo ? () => onChanged(value - step) : null),
        SizedBox(
          width: 56,
          child: Text('$value',
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        ),
        GhostButton(
            label: '+',
            onPressed:
                value + step <= hi ? () => onChanged(value + step) : null),
      ]),
    );
  }
}

/// ============================================================
/// PRIVATE ARENA INVITE CARD — a designed, story-ready card with
/// the join code, shareable straight to WhatsApp. It sells the
/// app to whoever receives it.
/// ============================================================
class _InviteCardDialog extends StatelessWidget {
  final String code;
  final String title;
  final String topic;
  final String range;
  final int fee;
  final int maxPlayers;
  final int questions;
  final int minutes;
  _InviteCardDialog({
    required this.code,
    required this.title,
    required this.topic,
    required this.range,
    required this.fee,
    required this.maxPlayers,
    required this.questions,
    required this.minutes,
  });

  final GlobalKey cardKey = GlobalKey();

  String get _inviteText =>
      '🧠⚔️ You\'re challenged! Join my private arena "$title" on MYNDASH.\n'
      '🎯 $topic · $questions questions · $minutes min · rating $range\n'
      '🔑 CODE: $code\n'
      'Get MYNDASH → Arenas → JOIN PRIVATE → enter the code. Loser buys snacks 😤';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          RepaintBoundary(
            key: cardKey,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1A0B33),
                      Color(0xFF6C2BD9),
                      Color(0xFF00C2FF)
                    ]),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('MYNDASH',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4,
                        color: Colors.white)),
                Text('PRIVATE ARENA INVITE',
                    style: TextStyle(
                        fontSize: 10, letterSpacing: 3, color: DC.fg70)),
                const SizedBox(height: 14),
                Text(title.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white)),
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: Colors.black.withOpacity(0.35),
                    border: Border.all(color: DC.fg38),
                  ),
                  child: Text(code,
                      style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 8,
                          color: Colors.white)),
                ),
                const SizedBox(height: 4),
                Text('JOIN CODE',
                    style: TextStyle(
                        fontSize: 9, letterSpacing: 3, color: DC.fg70)),
                const SizedBox(height: 14),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _chip('🎯 $topic'),
                    _chip('📊 rating $range'),
                    _chip('❓ $questions questions'),
                    _chip('⏱ $minutes min'),
                    _chip(fee == 0 ? '🎟 free entry' : '🪙 $fee entry'),
                    _chip('👥 up to $maxPlayers'),
                  ],
                ),
                const SizedBox(height: 14),
                const Text('🥇 75% of the pot · 🥈 25%',
                    style: TextStyle(fontSize: 12, color: Colors.white)),
                const SizedBox(height: 10),
                Text(
                    'Get the MYNDASH app → ARENAS → JOIN PRIVATE → enter the code',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 10, color: DC.fg70)),
              ]),
            ),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: NeonButton(
                label: 'WHATSAPP',
                icon: Icons.chat,
                height: 46,
                colors: const [Color(0xFF25D366), Color(0xFF128C7E)],
                onPressed: () => shareCardImage(context, cardKey,
                    text: _inviteText, filename: 'mynd_arena_invite'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: NeonButton(
                label: 'COPY CODE',
                icon: Icons.copy,
                height: 46,
                colors: [DC.violet, DC.cyan],
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _inviteText));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Invite copied — paste it anywhere!')));
                },
              ),
            ),
          ]),
          const SizedBox(height: 8),
          GhostButton(
              label: 'DONE',
              height: 44,
              onPressed: () => Navigator.pop(context)),
        ]),
      ),
    );
  }

  Widget _chip(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: DC.fgo(0.15),
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white)),
      );
}

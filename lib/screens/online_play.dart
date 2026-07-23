import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../core/fx.dart';
import '../core/state.dart';
import '../engine/chess_puzzles.dart';
import '../engine/generators.dart';
import '../engine/question.dart';
import '../engine/rating_catalog.dart';
import '../services/account_service.dart';
import '../services/firebase_service.dart';
import '../theme_district.dart';
import '../ui/art.dart';
import '../ui/default_avatar.dart';
import '../ui/extras.dart';
import '../ui/glass.dart';
import 'arrow_screen.dart';
import 'chess_duel.dart';
import 'cross_math_screen.dart';
import 'crossword_screen.dart';
import 'cube_screens.dart';
import 'hanoi_screen.dart';
import 'numpuzzle_screen.dart';
import 'sudoku_screen.dart';
import 'art_race.dart';
import 'darts_duel.dart';
import 'lobby_screen.dart';
import 'practice_screen.dart';
import 'showdown_screen.dart';
import 'scribble.dart';
import 'word_finder.dart';

/// ============================================================
/// ONLINE PLAY — one consistent flow for every game:
/// search online (closest rating), invite a friend (code + link
/// you can paste into WhatsApp), or join with a code.
/// Games: 'duel' (question feeds/tactics), 'chess', 'darts', 'cube'.
/// ============================================================

/// Routes a matched/joined room to the right game screen, after a quick
/// "You VS Opponent" showdown so online matches never start cold.
void openOnlineGame(BuildContext context, Map<String, dynamic> room,
    {required bool amHost, bool replace = true}) {
  final chessMinutes = (room['t'] as num?)?.toInt() ?? 0;
  Widget buildGame() => switch (room['game']) {
        'chess' => ChessDuelScreen(
            room: room, amHost: amHost, timeMinutes: chessMinutes),
        'darts' => DartsDuelScreen(room: room, amHost: amHost),
        'cube' => CubeRaceScreen(room: room, amHost: amHost),
        'scribble' => ScribbleScreen(room: room, amHost: amHost),
        'wordfind' => WordFinderScreen(room: room, amHost: amHost),
        'art' => ArtRaceScreen(room: room, amHost: amHost),
        'sudoku' => SudokuScreen(room: room, amHost: amHost),
        'hanoi' => HanoiScreen(room: room, amHost: amHost),
        'numpz' => NumPuzzleScreen(room: room, amHost: amHost),
        'arrow' => ArrowPuzzleScreen(room: room, amHost: amHost),
        'crossmath' => CrossMathGameScreen(room: room, amHost: amHost),
        'crossword' => CrosswordScreen(room: room, amHost: amHost),
        // Reflex real-time sync lives in its own room system; a stray
        // account_service match just plays the local bot game safely.
        'reflex' => const PracticeScreen(),
        _ => OnlineDuelScreen(room: room, amHost: amHost),
      };
  final opp = room[amHost ? 'guest' : 'host'] as Map?;
  final oppName = opp?['u'] != null ? '@${opp!['u']}' : 'Rival';
  ShowdownScreen.go(context,
      title: '1V1 · ONLINE',
      oppName: oppName,
      detail: room['game'] == 'chess' ? timeControlLabel(chessMinutes) : null,
      game: buildGame,
      replace: replace);
}

/// "Play a friend" chooser — create an invite or enter a code.
/// [timeMinutes] pre-selects a chess time control (from an inline picker) so
/// the create flow doesn't ask again; null means ask via the popup.
Future<void> showFriendPlayDialog(
    BuildContext context, String game, String sub, String label,
    {int? timeMinutes}) async {
  await showDialog(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: DC.bg2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text('Play a friend · $label'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        NeonButton(
          label: 'CREATE INVITE',
          icon: Icons.add_link,
          height: 48,
          onPressed: () async {
            Navigator.pop(c);
            var tMin = timeMinutes ?? 0;
            if (game == 'chess' && timeMinutes == null) {
              final picked = await pickTimeControl(context, label);
              if (picked == null || !context.mounted) return;
              tMin = picked;
            }
            if (!context.mounted) return;
            final range = await pickRatingRange(context, label);
            if (range == null || !context.mounted) return;
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => InviteRoomScreen(
                        game: game,
                        sub: sub,
                        label: label,
                        timeMinutes: tMin,
                        ratingMin: range.$1,
                        ratingMax: range.$2)));
          },
        ),
        const SizedBox(height: 10),
        GhostButton(
          label: 'I HAVE A CODE',
          icon: Icons.key,
          onPressed: () {
            Navigator.pop(c);
            promptJoinByCode(context);
          },
        ),
      ]),
    ),
  );
}

/// Time-control picker for timed games (chess, cube). Returns minutes per
/// side, or null if cancelled.
Future<int?> pickTimeControl(BuildContext context, String label) {
  return showDialog<int>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: DC.bg2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text('$label · time control'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final (m, name) in const [
            (0, '♾  Untimed'),
            (5, '⏱  5 min'),
            (10, '⏱  10 min'),
            (20, '⏱  20 min'),
            (30, '⏱  30 min'),
            (60, '⏱  1 hr'),
            (120, '⏱  2 hr'),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: double.infinity,
                child: NeonButton(
                  label: name,
                  height: 46,
                  onPressed: () => Navigator.pop(ctx, m),
                ),
              ),
            ),
        ]),
      ),
    ),
  );
}

/// "10 min per side" / "Untimed" label for a time control, shown as the
/// showdown-lobby detail line.
String timeControlLabel(int minutes) =>
    minutes == 0 ? 'Untimed' : '$minutes min per side';

/// Shared rating-range chooser for online search and friend rooms.
Future<(int, int)?> pickRatingRange(BuildContext context, String label) async {
  var values = RangeValues(
    RatingCatalog.normalize(AppData.i.elo - 200).toDouble(),
    RatingCatalog.normalize(AppData.i.elo + 200).toDouble(),
  );
  return showDialog<(int, int)>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setLocal) => AlertDialog(
        backgroundColor: DC.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('$label · rating range'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            '${values.start.round()}–${values.end.round()}',
            style: TextStyle(
              color: DC.cyan,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'The match and puzzle difficulty stay inside this range.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: DC.dim),
          ),
          const SizedBox(height: 12),
          RangeSlider(
            values: values,
            min: RatingCatalog.min.toDouble(),
            max: RatingCatalog.max.toDouble(),
            divisions: RatingCatalog.bands.length - 1,
            labels: RangeLabels(
              '${values.start.round()}',
              '${values.end.round()}',
            ),
            onChanged: (next) => setLocal(() => values = next),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
                dialogContext, (values.start.round(), values.end.round())),
            child: const Text('Use range'),
          ),
        ],
      ),
    ),
  );
}

const _friendlyBotNames = [
  'Aarav',
  'Zoya',
  'Kabir',
  'Mira',
  'Rohan',
  'Ishaan',
  'Anaya',
  'Vikram',
  'Neha',
  'Arjun',
  'Sara',
  'Dev',
  'Nova',
  'Kira',
  'Axel',
  'Luna',
];

/// Route a VS-BOT match through the same get-ready lobby as online play:
/// theme-flat "You ⚡VS Rival" reveal that parks on a START button, so the
/// board only opens when the player taps. [detail] shows e.g. the time
/// control. Used by every game's compete sheet for a consistent feel.
void startBotMatch(BuildContext context,
    {required String label, String? detail, required Widget Function() game}) {
  final name = _friendlyBotNames[Random().nextInt(_friendlyBotNames.length)];
  ShowdownScreen.go(context,
      title: '1V1 · BOT',
      oppName: name,
      detail: detail,
      autoStart: false,
      game: game);
}

/// Reflex Duel compete sheet — same look as every other game (VS BOT /
/// SEARCH ONLINE / PLAY A FRIEND), no separate hub page. Used by both the
/// 1v1 tab and the Games hub.
Future<void> showReflexCompete(BuildContext context) async {
  await showModalBottomSheet(
    context: context,
    backgroundColor: DC.bg2,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (c) => SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
            left: 22,
            right: 22,
            top: 22,
            bottom: MediaQuery.of(c).viewInsets.bottom + 22),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('COMPETE · Reflex Duel ⚡',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          NeonButton(
            label: 'VS BOT',
            icon: Icons.smart_toy,
            onPressed: () {
              Navigator.pop(c);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const PracticeScreen()));
            },
          ),
          const SizedBox(height: 10),
          NeonButton(
            label: 'SEARCH ONLINE',
            icon: Icons.public,
            colors: [DC.magenta, DC.violet],
            onPressed: () {
              Navigator.pop(c);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => MatchmakingScreen(
                          game: 'reflex',
                          sub: 'std',
                          label: 'Reflex Duel ⚡',
                          botScreen: () => const PracticeScreen())));
            },
          ),
          const SizedBox(height: 10),
          GhostButton(
            label: 'PLAY A FRIEND',
            icon: Icons.group,
            onPressed: () {
              Navigator.pop(c);
              _reflexFriend(context);
            },
          ),
        ]),
      ),
    ),
  );
}

/// Reflex friend play uses the original real-time reflex room system
/// (FirebaseService + LobbyScreen): create a room to share, or join by code.
Future<void> _reflexFriend(BuildContext context) async {
  if (!AppState.instance.online) {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reflex online needs a connection.')));
    return;
  }
  final choice = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: DC.bg2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Play a friend · Reflex ⚡'),
      content: const Text('Create a room to share, or join with a code.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, 'create'),
            child: const Text('Create room')),
        TextButton(
            onPressed: () => Navigator.pop(ctx, 'join'),
            child: const Text('Join with code')),
      ],
    ),
  );
  if (choice == null || !context.mounted) return;
  final name = AppState.instance.profile.name;
  if (choice == 'create') {
    try {
      final code = await FirebaseService.instance.createRoom(name);
      if (!context.mounted) return;
      Navigator.push(
          context, MaterialPageRoute(builder: (_) => LobbyScreen(code: code)));
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not create the room — try again.')));
      }
    }
    return;
  }
  final codeC = TextEditingController();
  final code = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: DC.bg2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Enter room code'),
      content: TextField(
          controller: codeC,
          autofocus: true,
          maxLength: 6,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(hintText: 'CODE', counterText: '')),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, codeC.text.trim()),
            child: const Text('Join')),
      ],
    ),
  );
  if (code == null || code.isEmpty || !context.mounted) return;
  final err = await FirebaseService.instance.joinRoom(code.toUpperCase(), name);
  if (!context.mounted) return;
  if (err != null) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    return;
  }
  Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => LobbyScreen(code: code.toUpperCase(), joined: true)));
}

/// Code-entry → join → jump into the game (works for any game).
Future<void> promptJoinByCode(BuildContext context) async {
  final c = TextEditingController();
  final code = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: DC.bg2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Enter room code'),
      content: TextField(
          controller: c,
          autofocus: true,
          maxLength: 6,
          textCapitalization: TextCapitalization.characters,
          decoration:
              const InputDecoration(hintText: 'e.g. 7KQ2ZX', counterText: '')),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim()),
            child: const Text('Join')),
      ],
    ),
  );
  if (code == null || code.isEmpty || !context.mounted) return;
  final (err, room) = await AccountService.instance.joinRoomByCode(code);
  if (!context.mounted) return;
  if (err != null || room == null) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(err ?? 'Join failed.')));
    return;
  }
  // Chess gets the host-start lobby (both sides ready up before the board
  // opens); every other game keeps the old instant-join behaviour.
  if (room['game'] == 'chess') {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => InviteRoomScreen(
                game: 'chess',
                sub: room['sub'] as String? ?? 'std',
                label: 'Chess ♟',
                timeMinutes: (room['t'] as num?)?.toInt() ?? 0,
                joinedRoom: room)));
    return;
  }
  openOnlineGame(context, room, amHost: false, replace: false);
}

/// ---------------- invite room (host waits here) ----------------
/// Also doubles as the guest's waiting lobby when [joinedRoom] is set.
class InviteRoomScreen extends StatefulWidget {
  final String game, sub, label;
  final int timeMinutes; // host-chosen time control (chess only)
  final int ratingMin;
  final int ratingMax;
  final Map<String, dynamic>? joinedRoom; // non-null → I'm the guest
  const InviteRoomScreen(
      {super.key,
      required this.game,
      required this.sub,
      required this.label,
      this.timeMinutes = 0,
      this.ratingMin = RatingCatalog.min,
      this.ratingMax = RatingCatalog.max,
      this.joinedRoom});

  @override
  State<InviteRoomScreen> createState() => _InviteRoomScreenState();
}

class _InviteRoomScreenState extends State<InviteRoomScreen> {
  Map<String, dynamic>? room;
  String? error;
  StreamSubscription? sub;
  bool started = false;

  bool get isHost => widget.joinedRoom == null;
  // Chess ready-checks both sides with an explicit host "START MATCH" tap —
  // same waiting-lobby-with-code shape as the original Reflex Duel room,
  // just themed to match. Every other game keeps the old instant-start.
  bool get manualStart => widget.game == 'chess';

  @override
  void initState() {
    super.initState();
    if (widget.joinedRoom != null) {
      room = widget.joinedRoom;
      _listen(widget.joinedRoom!['id'] as String);
    } else {
      _create();
    }
  }

  Future<void> _create() async {
    final (err, r) = await AccountService.instance.createRoom(
        widget.game, widget.sub,
        timeMinutes: widget.timeMinutes,
        ratingMin: widget.ratingMin,
        ratingMax: widget.ratingMax);
    if (!mounted) return;
    if (err != null || r == null) {
      setState(() => error = err ?? 'Could not create the room.');
      return;
    }
    setState(() => room = r);
    _listen(r['id'] as String);
  }

  void _listen(String id) {
    sub = AccountService.instance.roomStream(id).listen((snap) {
      if (snap == null || started || !mounted) return;
      final fresh = Map<String, dynamic>.from(snap)..['id'] = id;
      setState(() => room = fresh);
      if (manualStart) {
        final st = snap['state'] as Map?;
        if (st?['started'] == true) {
          started = true;
          Fx.success();
          openOnlineGame(context, fresh, amHost: isHost);
        }
      } else if (isHost && snap['guest'] != null) {
        started = true;
        Fx.success();
        openOnlineGame(context, fresh, amHost: true);
      }
    });
  }

  void _startMatch() {
    final id = room?['id'] as String?;
    if (id == null) return;
    AccountService.instance.roomWrite(id, 'state/started', true);
  }

  Widget _lobbyRow(String name, bool isMe) {
    return Row(children: [
      DefaultAvatar(name: name.replaceFirst('@', ''), size: 38),
      const SizedBox(width: 12),
      Expanded(
        child: Text(isMe ? '$name (you)' : name,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
      ),
      Icon(Icons.circle, size: 10, color: DC.lime),
    ]);
  }

  @override
  void dispose() {
    sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final code = room?['code'] as String?;
    final guest = room?['guest'] as Map?;
    final host = room?['host'] as Map?;
    final me = AppData.i;
    final myLabel = me.username.isEmpty ? me.name : '@${me.username}';
    final oppLabel = isHost
        ? (guest?['u'] != null ? '@${guest!['u']}' : null)
        : (host?['u'] != null ? '@${host!['u']}' : null);
    final full = guest != null;
    return Scaffold(
      body: ShaderBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              Row(children: [
                Glass(
                    radius: 16,
                    padding: const EdgeInsets.all(8),
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back, size: 18)),
                const SizedBox(width: 12),
                Text(
                    isHost
                        ? 'INVITE · ${widget.label.toUpperCase()}'
                        : 'LOBBY · ${widget.label.toUpperCase()}',
                    style: Theme.of(context).textTheme.titleLarge),
              ]),
              const Spacer(),
              if (error != null)
                Glass(child: Text(error!, textAlign: TextAlign.center))
              else if (room == null)
                CircularProgressIndicator(color: DC.cyan)
              else ...[
                if (isHost && code != null) ...[
                  Text('Send this to your rival 👇',
                      style: TextStyle(color: DC.dim)),
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: () {
                      Fx.tap();
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Code copied!')));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: LinearGradient(colors: [DC.violet, DC.cyan]),
                      ),
                      child: Text(code,
                          style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 8)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  GhostButton(
                    label: 'COPY WHATSAPP INVITE',
                    icon: Icons.share,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(
                          text: AccountService.inviteMessage(
                              widget.label, code)));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text(
                              'Invite copied — paste it in WhatsApp or anywhere!')));
                    },
                  ),
                  const SizedBox(height: 20),
                ],
                if (widget.timeMinutes > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Pill(
                        icon: Icons.timer,
                        label: timeControlLabel(widget.timeMinutes),
                        color: DC.cyan),
                  ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Pill(
                    icon: Icons.monitor_heart_outlined,
                    label:
                        '${(room?['ratingMin'] as num?)?.toInt() ?? widget.ratingMin}–${(room?['ratingMax'] as num?)?.toInt() ?? widget.ratingMax}',
                    color: DC.violet,
                  ),
                ),
                Glass(
                  radius: 18,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(children: [
                    _lobbyRow(myLabel, true),
                    const SizedBox(height: 10),
                    if (oppLabel != null)
                      _lobbyRow(oppLabel, false)
                    else
                      Row(children: [
                        const DefaultAvatar(name: '', size: 38),
                        const SizedBox(width: 12),
                        Text('Waiting for opponent…',
                            style: TextStyle(color: DC.dim, fontSize: 13)),
                      ]),
                  ]),
                ),
                const SizedBox(height: 24),
                if (!manualStart || !full) ...[
                  CircularProgressIndicator(color: DC.magenta),
                  const SizedBox(height: 10),
                  Text(full ? 'Starting…' : 'Waiting for your rival to join…',
                      style: TextStyle(color: DC.dim, fontSize: 12)),
                ] else if (isHost)
                  NeonButton(
                    label: 'START MATCH',
                    icon: Icons.sports_mma,
                    colors: [DC.lime, DC.cyan],
                    onPressed: _startMatch,
                  )
                else ...[
                  CircularProgressIndicator(color: DC.magenta),
                  const SizedBox(height: 10),
                  Text('Waiting for host to start…',
                      style: TextStyle(color: DC.dim, fontSize: 12)),
                ],
              ],
              const Spacer(flex: 2),
            ]),
          ),
        ),
      ),
    );
  }
}

/// ---------------- quick match (search online) ----------------
class MatchmakingScreen extends StatefulWidget {
  final String game, sub, label;

  /// Local bot game to drop into when no human is found within the
  /// search window. Provided so EVERY game (not just chess) falls back
  /// to a bot instead of dead-ending.
  final Widget Function()? botScreen;

  /// Chess time control (minutes/side). Pairs only with same-time rivals
  /// and carries into the room + the bot fallback.
  final int timeMinutes;
  const MatchmakingScreen(
      {super.key,
      required this.game,
      required this.sub,
      required this.label,
      this.botScreen,
      this.timeMinutes = 0});

  @override
  State<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends State<MatchmakingScreen> {
  String? error;
  Timer? _rotator;
  int _msgIdx = 0;
  int? ratingMin;
  int? ratingMax;

  // Clean, creative rotating lines — no raw rating-band internals.
  static const _messages = [
    'Scanning the arena…',
    'Reading the room…',
    'Finding a worthy mind…',
    'Sizing up challengers…',
    'Warming up the board…',
  ];

  @override
  void initState() {
    super.initState();
    _rotator = Timer.periodic(const Duration(milliseconds: 1800), (_) {
      if (mounted && error == null) {
        setState(() => _msgIdx = (_msgIdx + 1) % _messages.length);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _chooseRange());
  }

  @override
  void dispose() {
    _rotator?.cancel();
    super.dispose();
  }

  Future<void> _search() async {
    if (ratingMin == null || ratingMax == null) return;
    setState(() => error = null);
    // Never dead-ends: search humans for 10s, then a bot steps in.
    // Give real humans a genuine chance to pair before a bot steps in.
    final (err, room, amHost) = await AccountService.instance.quickMatch(
      widget.game,
      widget.sub,
      timeMinutes: widget.timeMinutes,
      ratingMin: ratingMin!,
      ratingMax: ratingMax!,
      searchWindow: const Duration(seconds: 10),
    );
    if (!mounted) return;
    if (err != null || room == null) {
      await _botFallback();
      return;
    }
    Fx.success();
    openOnlineGame(context, room, amHost: amHost);
  }

  Future<void> _chooseRange() async {
    final range = await pickRatingRange(context, widget.label);
    if (!mounted) return;
    if (range == null) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      ratingMin = range.$1;
      ratingMax = range.$2;
    });
    _search();
  }

  /// Pair the player with a demo bot. Chess uses the engine with a real
  /// leaderboard-bot identity; every other game drops into its own local
  /// bot screen so no online search ever dead-ends.
  Future<void> _botFallback() async {
    Fx.success();
    final target =
        ((ratingMin ?? AppData.i.elo) + (ratingMax ?? AppData.i.elo)) ~/ 2;
    final bot = await AccountService.instance.pickBotOpponent(target);
    if (!mounted) return;
    // Prefer the bot's full demo name (e.g. "Om Bose").
    final botName = bot == null
        ? 'Challenger'
        : ('${bot['name'] ?? ''}'.trim().isNotEmpty
            ? '${bot['name']}'
            : '@${bot['u']}');
    if (widget.game == 'chess') {
      final botElo = (bot?['elo'] as num?)?.toInt() ?? AppData.i.elo;
      ShowdownScreen.go(context,
          title: '1V1 · ONLINE',
          oppName: botName,
          detail: timeControlLabel(widget.timeMinutes),
          replace: true,
          game: () => ChessDuelScreen(
              practiceRating: botElo,
              botName: botName,
              botMatch: true,
              timeMinutes: widget.timeMinutes));
      return;
    }
    if (widget.botScreen != null) {
      ShowdownScreen.go(context,
          title: '1V1 · ONLINE',
          oppName: botName,
          replace: true,
          game: widget.botScreen!);
      return;
    }
    setState(() =>
        error = 'No rivals online right now — invite a friend with a code!');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ShaderBackground(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (error == null) ...[
                  // Animated signature art as the loader — creative, no
                  // raw internals.
                  const MyndArt(theme: 'duel', size: 120),
                  const SizedBox(height: 20),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: Text(_messages[_msgIdx],
                        key: ValueKey(_msgIdx),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge),
                  ),
                  const SizedBox(height: 6),
                  Text(widget.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12, letterSpacing: 2, color: DC.dim)),
                  if (ratingMin != null && ratingMax != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        '$ratingMin–$ratingMax',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: DC.cyan,
                        ),
                      ),
                    ),
                  const SizedBox(height: 28),
                  GhostButton(
                      label: 'CANCEL', onPressed: () => Navigator.pop(context)),
                ] else ...[
                  const Text('🛰', style: TextStyle(fontSize: 40)),
                  const SizedBox(height: 10),
                  Text(error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: DC.dim)),
                  const SizedBox(height: 18),
                  NeonButton(
                      label: 'SEARCH AGAIN', height: 48, onPressed: _search),
                  const SizedBox(height: 10),
                  GhostButton(
                      label: 'BACK', onPressed: () => Navigator.pop(context)),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// ============================================================
/// ONLINE QUESTION DUEL — 7 identical seeded questions, live
/// opponent progress, first to the higher score wins.
/// ============================================================
class OnlineDuelScreen extends StatefulWidget {
  final Map<String, dynamic> room;
  final bool amHost;
  const OnlineDuelScreen({super.key, required this.room, required this.amHost});

  @override
  State<OnlineDuelScreen> createState() => _OnlineDuelScreenState();
}

class _OnlineDuelScreenState extends State<OnlineDuelScreen> {
  static const total = 7;
  late final String roomId = widget.room['id'];
  late final String mySide = widget.amHost ? 'host' : 'guest';
  late final String oppSide = widget.amHost ? 'guest' : 'host';
  late final Map<String, dynamic> opp =
      Map<String, dynamic>.from(widget.room[oppSide] as Map);
  late final int matchRating;
  late final List<Question> qs;

  int index = 0;
  int score = 0;
  int qStart = 0;
  bool answered = false;
  bool right = false;
  int oppIdx = 0;
  int oppScore = 0;
  bool finished = false;
  bool oppLeft = false;
  StreamSubscription? sub;
  Timer? staleTimer;
  int lastOppUpdate = DateTime.now().millisecondsSinceEpoch;
  bool canClaim = false;

  @override
  void initState() {
    super.initState();
    final seed = (widget.room['seed'] as num?)?.toInt() ?? 1;
    final hostElo =
        ((widget.room['host'] as Map?)?['elo'] as num?)?.toInt() ?? 800;
    final guestElo =
        ((widget.room['guest'] as Map?)?['elo'] as num?)?.toInt() ?? 800;
    final roomMin = (widget.room['ratingMin'] as num?)?.toInt();
    final roomMax = (widget.room['ratingMax'] as num?)?.toInt();
    matchRating = roomMin != null && roomMax != null
        ? RatingCatalog.normalize((roomMin + roomMax) ~/ 2)
        : ((hostElo + guestElo) ~/ 2).clamp(800, 2500).toInt();
    final rng = Random(seed);
    final cat = widget.room['sub'] as String? ?? 'mental';
    qs = List.generate(
        total,
        (_) => cat == 'tactics'
            ? chessQuestion(matchRating, rng)
            : generate(cat, matchRating, rng));
    qStart = DateTime.now().millisecondsSinceEpoch;
    sub = AccountService.instance.roomStream(roomId).listen(_onRoom);
    staleTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || finished) return;
      final stale =
          DateTime.now().millisecondsSinceEpoch - lastOppUpdate > 60000;
      if (stale != canClaim) setState(() => canClaim = stale);
    });
  }

  void _onRoom(Map<String, dynamic>? r) {
    if (r == null || finished || !mounted) return;
    final st = r['state'] as Map?;
    final o = st?[oppSide] as Map?;
    if (o != null) {
      final ni = (o['idx'] as num?)?.toInt() ?? 0;
      final ns = (o['score'] as num?)?.toInt() ?? 0;
      if (ni != oppIdx || ns != oppScore) {
        lastOppUpdate = DateTime.now().millisecondsSinceEpoch;
        setState(() {
          oppIdx = ni;
          oppScore = ns;
        });
      }
    }
    if (st?['left'] == oppSide) {
      oppLeft = true;
      _finish(forfeit: true);
    } else if (index >= total && oppIdx >= total) {
      _finish();
    }
  }

  void _answer(String input) {
    if (answered || finished || index >= total) return;
    final q = qs[index];
    final ms = DateTime.now().millisecondsSinceEpoch - qStart;
    answered = true;
    right = q.check(input);
    if (right) {
      Fx.success();
      score += 100 +
          ((q.parMs - ms) > 0
              ? ((q.parMs - ms) / q.parMs * 50).clamp(0, 50).round()
              : 0);
    } else {
      Fx.fail();
    }
    setState(() {});
    Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() {
        index++;
        answered = false;
        qStart = DateTime.now().millisecondsSinceEpoch;
      });
      AccountService.instance
          .roomWrite(roomId, 'state/$mySide', {'idx': index, 'score': score});
      if (index >= total && oppIdx >= total) _finish();
    });
  }

  void _finish({bool forfeit = false}) {
    if (finished) return;
    finished = true;
    staleTimer?.cancel();
    final a = AppData.i;
    final won = forfeit || score > oppScore;
    final draw = !forfeit && score == oppScore;
    final oppElo = (opp['elo'] as num?)?.toInt() ?? 800;
    final delta = a.applyElo(oppElo, won ? 1 : (draw ? 0.5 : 0));
    if (won) {
      Fx.win();
    } else if (!draw) {
      Fx.lose();
    }
    a.recordMatch(
        mode: 'Online · ${duelCatLabel(widget.room['sub'] ?? 'mental')}',
        opponent: '@${opp['u']}',
        result: won ? 'W' : (draw ? 'D' : 'L'),
        delta: delta);
    AccountService.instance.updatePublicProfile();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: DC.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (won) const ConfettiBurst(height: 70),
            Icon(won ? Icons.emoji_events : Icons.psychology_alt,
                size: 60, color: won ? DC.amber : DC.violet),
            const SizedBox(height: 10),
            Text(won ? 'VICTORY!' : (draw ? 'DRAW' : 'DEFEAT'),
                style: Theme.of(context).textTheme.displayMedium),
            Text(
                forfeit
                    ? '@${opp['u']} left the match'
                    : '$score — $oppScore vs @${opp['u']} ($oppElo)',
                style: TextStyle(color: DC.dim)),
            const SizedBox(height: 8),
            Text('${delta >= 0 ? '+' : ''}$delta rating',
                style: TextStyle(
                    color: delta >= 0 ? DC.lime : DC.danger,
                    fontWeight: FontWeight.w900,
                    fontSize: 18)),
            const SizedBox(height: 8),
            const ReactionBar(),
            TextButton.icon(
              onPressed: () => shareResult(
                  context,
                  won
                      ? 'Beat a real human (@${opp['u']}) $score–$oppScore online on MYNDASH ⚔️🔥'
                      : 'Fought @${opp['u']} $score–$oppScore online on MYNDASH. Rematch pending 😤'),
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
  void dispose() {
    sub?.cancel();
    staleTimer?.cancel();
    if (!finished) {
      AccountService.instance.roomWrite(roomId, 'state/left', mySide);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final waiting = index >= total;
    final q = waiting ? null : qs[index];
    return Scaffold(
      body: ShaderBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              // opponent live bar
              Glass(
                radius: 18,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(children: [
                  Text('@${opp['u']}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 13)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: oppIdx / total,
                        minHeight: 6,
                        backgroundColor: DC.fg10,
                        color: DC.magenta,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('$oppScore',
                      style: TextStyle(
                          color: DC.magenta, fontWeight: FontWeight.w900)),
                ]),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Text('YOU  $score',
                    style: TextStyle(
                        color: DC.cyan,
                        fontWeight: FontWeight.w900,
                        fontSize: 15)),
                const Spacer(),
                Text('${min(index + 1, total)}/$total',
                    style: TextStyle(fontSize: 12, color: DC.dim)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: index / total,
                  minHeight: 6,
                  backgroundColor: DC.fg10,
                  color: DC.cyan,
                ),
              ),
              const Spacer(),
              if (waiting) ...[
                CircularProgressIndicator(color: DC.magenta),
                const SizedBox(height: 12),
                Text('Done! Waiting for @${opp['u']}… ($oppIdx/$total)',
                    style: TextStyle(color: DC.dim)),
                if (canClaim) ...[
                  const SizedBox(height: 16),
                  NeonButton(
                      label: 'CLAIM WIN (OPPONENT INACTIVE)',
                      height: 46,
                      colors: [DC.danger, DC.magenta],
                      onPressed: () => _finish(forfeit: true)),
                ],
              ] else ...[
                Glass(
                  radius: 24,
                  padding: const EdgeInsets.all(20),
                  border: answered
                      ? Border.all(color: right ? DC.lime : DC.danger, width: 2)
                      : null,
                  child: Text(q!.prompt,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: q.prompt.length > 60 ? 16 : 21,
                          fontWeight: FontWeight.w700,
                          height: 1.4)),
                ),
                const SizedBox(height: 14),
                if (q.options != null)
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final o in q.options!)
                        GestureDetector(
                          onTap: answered ? null : () => _answer(o),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 13),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: answered && q.check(o)
                                  ? DC.lime.withOpacity(0.25)
                                  : DC.fgo(0.07),
                              border: Border.all(color: DC.fgo(0.14)),
                            ),
                            child: Text(o,
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w700)),
                          ),
                        ),
                    ],
                  )
                else
                  _OnlineTypedAnswer(enabled: !answered, onSubmit: _answer),
              ],
              const Spacer(flex: 2),
            ]),
          ),
        ),
      ),
    );
  }
}

class _OnlineTypedAnswer extends StatefulWidget {
  final ValueChanged<String> onSubmit;
  final bool enabled;
  const _OnlineTypedAnswer({required this.onSubmit, required this.enabled});

  @override
  State<_OnlineTypedAnswer> createState() => _OnlineTypedAnswerState();
}

class _OnlineTypedAnswerState extends State<_OnlineTypedAnswer> {
  final c = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: TextField(
          controller: c,
          enabled: widget.enabled,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(
              decimal: true, signed: true),
          onSubmitted: widget.enabled ? (_) => _go() : null,
          decoration: const InputDecoration(hintText: 'your answer'),
        ),
      ),
      const SizedBox(width: 10),
      NeonButton(
          label: 'GO', height: 46, onPressed: widget.enabled ? _go : null),
    ]);
  }

  void _go() {
    if (c.text.trim().isEmpty) return;
    widget.onSubmit(c.text);
    c.clear();
  }
}

/// Friendly label for a duel sub-category.
String duelCatLabel(String id) => switch (id) {
      'tactics' => 'Tactics 🧩',
      'chess' => 'Chess ♟',
      'darts' => 'Darts 🎯',
      'cube' => 'Cube 🧊',
      _ => catById(id).name,
    };

/// ============================================================
/// UNIVERSAL REMATCH — drop into any online game's finish dialog.
/// Both players tap it → host resets the room (fresh seed, clean
/// state) → both relaunch into the same room. No more re-typing
/// codes after every game.
/// ============================================================
class RematchButton extends StatefulWidget {
  final Map<String, dynamic> room;
  final bool amHost;
  const RematchButton({super.key, required this.room, required this.amHost});

  @override
  State<RematchButton> createState() => _RematchButtonState();
}

class _RematchButtonState extends State<RematchButton> {
  StreamSubscription? sub;
  bool requested = false;
  bool oppWants = false;

  String get id => widget.room['id'];
  String get mySide => widget.amHost ? 'host' : 'guest';
  String get oppSide => widget.amHost ? 'guest' : 'host';

  @override
  void initState() {
    super.initState();
    sub = AccountService.instance.roomStream(id).listen((r) {
      if (r == null || !mounted) return;
      final rm = r['rematch'] as Map?;
      final oppIn = rm?[oppSide] == true;
      if (oppIn != oppWants) setState(() => oppWants = oppIn);
      final bothIn = requested && oppIn;
      if (bothIn && widget.amHost && r['state'] != null) {
        // host performs the reset exactly once
        AccountService.instance.roomWrite(id, 'state', null);
        AccountService.instance
            .roomWrite(id, 'seed', Random().nextInt(1 << 31));
        AccountService.instance.roomWrite(id, 'rematch', null);
      }
      // relaunch when the reset lands (state cleared + no flags)
      if (requested && r['rematch'] == null && r['state'] == null) {
        sub?.cancel();
        final fresh = Map<String, dynamic>.from(r);
        fresh['id'] = id;
        Navigator.pop(context); // close the result dialog
        openOnlineGame(context, fresh, amHost: widget.amHost);
      }
    });
  }

  @override
  void dispose() {
    sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      NeonButton(
        label: requested
            ? (oppWants ? 'STARTING…' : 'WAITING FOR RIVAL…')
            : (oppWants ? 'ACCEPT REMATCH ⚔' : 'REMATCH ⚔'),
        height: 46,
        colors: [DC.magenta, DC.violet],
        onPressed: requested
            ? null
            : () {
                setState(() => requested = true);
                AccountService.instance.roomWrite(id, 'rematch/$mySide', true);
              },
      ),
      if (oppWants && !requested)
        Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text('Your rival wants to run it back!',
              style: TextStyle(fontSize: 11, color: DC.magenta)),
        ),
      const SizedBox(height: 8),
    ]);
  }
}

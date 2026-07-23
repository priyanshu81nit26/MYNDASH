import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../core/fx.dart';
import '../core/state.dart';
import '../engine/arena_game_catalog.dart';
import '../engine/banks.dart';
import '../engine/event_calendar.dart';
import '../engine/rating_catalog.dart';
import '../services/account_service.dart';
import '../theme_district.dart';
import '../ui/glass.dart';
import 'event_leaderboard.dart';
import 'events_screen.dart'
    show ArenaLobbyScreen, OfficialArenaPlayScreen, fmtEventDateTime, joinArena;

Color get _arenaAccent => ThemeCtl.isDark ? DC.cyan : DC.electric;

String arenaGameLabel(String id) => ArenaGameCatalog.byId(id).label;

IconData arenaGameIcon(String id) => switch (id) {
      'mixed' => Icons.apps_rounded,
      'speedmath' => Icons.bolt_rounded,
      'finance' => Icons.account_balance_wallet_rounded,
      'mental' => Icons.calculate_rounded,
      'quant' => Icons.functions_rounded,
      'numtheory' => Icons.pin_rounded,
      'patterns' => Icons.grid_view_rounded,
      'geometry' => Icons.change_history_rounded,
      'probability' => Icons.casino_outlined,
      'clock' => Icons.schedule_rounded,
      'words' => Icons.spellcheck_rounded,
      'knights' => Icons.extension_rounded,
      'crypta' => Icons.lock_outline_rounded,
      'sudoku' => Icons.grid_4x4_rounded,
      'art_heist' => Icons.image_search_rounded,
      'crossword' => Icons.view_module_rounded,
      'chess' => Icons.sports_esports_rounded,
      'number_puzzle' => Icons.grid_3x3_rounded,
      _ => Icons.sports_esports_rounded,
    };

ImageProvider<Object>? _arenaCover(Map<String, dynamic> event) {
  final value = event['bg'] as String?;
  if (value == null || value.isEmpty) return null;
  try {
    return MemoryImage(base64Decode(value));
  } catch (_) {
    return null;
  }
}

/// Resizes and recompresses an arena cover below the database payload limit.
/// This accepts bytes from [XFile.readAsBytes], so it works on web and mobile.
Uint8List? compressArenaCoverForUpload(Uint8List source) {
  final decoded = img.decodeImage(source);
  if (decoded == null) return null;
  var working = img.bakeOrientation(decoded);
  const targetBytes = 108 * 1024;

  img.Image resizeTo(int maxSide) {
    if (max(working.width, working.height) <= maxSide) return working;
    return working.width >= working.height
        ? img.copyResize(working, width: maxSide)
        : img.copyResize(working, height: maxSide);
  }

  for (final maxSide in const [1200, 960, 760, 600]) {
    working = resizeTo(maxSide);
    for (final quality in const [76, 64, 52, 42, 34]) {
      final encoded = img.encodeJpg(working, quality: quality);
      if (encoded.length <= targetBytes) return encoded;
    }
  }
  final fallback = img.encodeJpg(resizeTo(480), quality: 30);
  return fallback.length <= 120 * 1024 ? fallback : null;
}

String _monthName(int month) => const [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ][month - 1];

class _WeekButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _WeekButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: label,
      onPressed: onTap,
      constraints: const BoxConstraints.tightFor(width: 48, height: 48),
      icon: Icon(icon, size: 21),
    );
  }
}

class ArenaHubScreen extends StatefulWidget {
  const ArenaHubScreen({super.key});

  @override
  State<ArenaHubScreen> createState() => _ArenaHubScreenState();
}

class _ArenaHubScreenState extends State<ArenaHubScreen> {
  final _service = AccountService.instance;
  final _registered = <String>{};
  Timer? _ticker;
  int _publicCount = 0;
  int _mineCount = 0;
  bool _loadingCounts = true;
  late int _weekday;
  late DateTime _weekMonday;

  DateTime get _selectedDate =>
      _weekMonday.add(Duration(days: _weekday - DateTime.monday));

  String _registrationKey(DateTime date, int bracket) =>
      '${eventDateKey(date)}:b$bracket';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = now.weekday;
    _weekday = today <= DateTime.friday ? today : DateTime.monday;
    _weekMonday = mondayOf(now);
    _load();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final values = await Future.wait([
      _service.listPublicEvents(),
      _service.listMyEvents(),
      _service.myOfficialRegs(eventDateKey(_selectedDate)),
    ]);
    if (!mounted) return;
    final public = values[0] as List<Map<String, dynamic>>?;
    final mine = values[1] as List<Map<String, dynamic>>?;
    final registrations = values[2] as Set<int>;
    final selectedKey = eventDateKey(_selectedDate);
    setState(() {
      _publicCount = public?.length ?? 0;
      _mineCount = mine?.length ?? 0;
      _registered
        ..removeWhere((key) => key.startsWith('$selectedKey:'))
        ..addAll(registrations.map((bracket) => '$selectedKey:b$bracket'));
      _loadingCounts = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return _ArenaScaffold(
      title: 'ARENA',
      subtitle: 'Competition, clearly organized.',
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _ArenaIntroCard(now: now),
          const SizedBox(height: 32),
          const _ArenaSectionTitle(
            title: 'MYNDASH OFFICIAL',
            subtitle: 'Six rating events. Monday to Friday.',
          ),
          const SizedBox(height: 16),
          _weekPicker(),
          const SizedBox(height: 10),
          _weekdayPicker(),
          const SizedBox(height: 16),
          _officialGrid(now),
          const SizedBox(height: 32),
          const _ArenaSectionTitle(
            title: 'YOUR ARENA SPACE',
            subtitle: 'Choose one clear destination.',
          ),
          const SizedBox(height: 16),
          _destinationGrid(),
          const SizedBox(height: 24),
          Glass(
            radius: 24,
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _IconPlate(icon: Icons.verified_user_outlined),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Fair by design',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Every entrant receives the same seeded paper. '
                        'Game rating and player eligibility are shown before joining.',
                        style:
                            TextStyle(fontSize: 12, color: DC.dim, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _weekPicker() {
    final friday = _weekMonday.add(const Duration(days: 4));
    final sameMonth = friday.month == _weekMonday.month;
    final label = sameMonth
        ? '${_weekMonday.day}–${friday.day} ${_monthName(friday.month)}'
        : '${_weekMonday.day} ${_monthName(_weekMonday.month)}–'
            '${friday.day} ${_monthName(friday.month)}';
    final currentWeek = mondayOf(DateTime.now()) == _weekMonday;
    return Glass(
      radius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        children: [
          _WeekButton(
            icon: Icons.chevron_left_rounded,
            label: 'Previous week',
            onTap: () => _moveWeek(-1),
          ),
          Expanded(
            child: Semantics(
              label: 'Selected week $label',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    currentWeek ? 'THIS WEEK' : '${_weekMonday.year}',
                    style: TextStyle(
                      color: currentWeek ? _arenaAccent : DC.dim,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!currentWeek)
            TextButton(
              onPressed: _goToThisWeek,
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text(
                'TODAY',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900),
              ),
            ),
          _WeekButton(
            icon: Icons.chevron_right_rounded,
            label: 'Next week',
            onTap: () => _moveWeek(1),
          ),
        ],
      ),
    );
  }

  void _moveWeek(int amount) {
    setState(() {
      _weekMonday = _weekMonday.add(Duration(days: amount * 7));
    });
    _loadSelectedRegistrations();
  }

  void _goToThisWeek() {
    final now = DateTime.now();
    setState(() {
      _weekMonday = mondayOf(now);
      _weekday = now.weekday <= DateTime.friday ? now.weekday : DateTime.monday;
    });
    _loadSelectedRegistrations();
  }

  Future<void> _loadSelectedRegistrations() async {
    final key = eventDateKey(_selectedDate);
    final registrations = await _service.myOfficialRegs(key);
    if (!mounted || eventDateKey(_selectedDate) != key) return;
    setState(() {
      _registered
        ..removeWhere((item) => item.startsWith('$key:'))
        ..addAll(registrations.map((bracket) => '$key:b$bracket'));
    });
  }

  Widget _weekdayPicker() {
    const days = ['MON', 'TUE', 'WED', 'THU', 'FRI'];
    return Glass(
      radius: 22,
      padding: const EdgeInsets.all(6),
      child: Row(
        children: [
          for (var index = 0; index < days.length; index++)
            Expanded(
              child: Semantics(
                button: true,
                selected: _weekday == index + 1,
                label: '${days[index]} official arenas',
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    setState(() => _weekday = index + 1);
                    _loadSelectedRegistrations();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: _weekday == index + 1
                          ? _arenaAccent.withOpacity(0.14)
                          : Colors.transparent,
                      border: _weekday == index + 1
                          ? Border.all(color: _arenaAccent.withOpacity(0.35))
                          : null,
                    ),
                    child: Text(
                      days[index],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: _weekday == index + 1 ? _arenaAccent : DC.dim,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _officialGrid(DateTime now) {
    final selectedDate = _selectedDate;
    final start = officialArenaStart(selectedDate);
    final phase = eventPhase(
      now,
      start,
      duration: arenaLobbyDuration + const Duration(minutes: arenaMinutes),
    );
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth >= 720 ? 3 : 2;
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: columns == 2 ? 0.88 : 1.1,
        ),
        itemCount: officialBrackets.length,
        itemBuilder: (_, index) => _OfficialArenaCard(
          bracket: officialBrackets[index],
          index: index,
          selectedWeekday: _weekday,
          phase: phase,
          startsAt: start,
          registered:
              _registered.contains(_registrationKey(selectedDate, index)),
          isMine: index == bracketIndexFor(AppData.i.contestRating),
          onTap: () => _officialAction(index, now),
        ),
      );
    });
  }

  Widget _destinationGrid() {
    final a = AppData.i;
    final destinations = <(IconData, String, String, VoidCallback)>[
      (
        Icons.public_rounded,
        'Public Arenas',
        _loadingCounts ? 'Loading…' : '$_publicCount open arenas',
        () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PublicArenasScreen()),
            ).then((_) => _load())
      ),
      (
        Icons.stadium_outlined,
        'My Arenas',
        _loadingCounts ? 'Loading…' : '$_mineCount hosted by you',
        () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyArenasScreen()),
            ).then((_) => _load())
      ),
      // Direct route to the arenas of the org(s) you've verified into — the
      // events you host for your college/company live and show up here.
      if (a.college.trim().isNotEmpty)
        (
          Icons.school_outlined,
          'My College Arena',
          a.college.trim(),
          () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OrganizationArenaScreen(
                    organizationTag: 'college:${a.college.trim()}',
                    organizationName: a.college.trim(),
                    college: true,
                  ),
                ),
              ).then((_) => _load())
        ),
      if (a.company.trim().isNotEmpty)
        (
          Icons.apartment_rounded,
          'My Company Arena',
          a.company.trim(),
          () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OrganizationArenaScreen(
                    organizationTag: 'company:${a.company.trim()}',
                    organizationName: a.company.trim(),
                    college: false,
                  ),
                ),
              ).then((_) => _load())
        ),
      (
        Icons.key_rounded,
        'Join by Code',
        'Enter a private arena',
        _joinPrivate
      ),
      (
        Icons.add_circle_outline_rounded,
        'Host Arena',
        'Games, levels and rules',
        () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HostArenaScreen()),
            ).then((_) => _load())
      ),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.76,
      ),
      itemCount: destinations.length,
      itemBuilder: (_, index) {
        final item = destinations[index];
        return _DestinationCard(
          icon: item.$1,
          title: item.$2,
          subtitle: item.$3,
          onTap: item.$4,
        );
      },
    );
  }

  Future<void> _officialAction(int bracket, DateTime now) async {
    final selectedDate = _selectedDate;
    final dayKey = eventDateKey(selectedDate);
    final start = officialArenaStart(selectedDate);
    final end = arenaEndsAt(
      start,
      const Duration(minutes: arenaMinutes),
    );
    if (!now.isBefore(end)) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EventLeaderboardScreen(
            title: officialBrackets[bracket].name.toUpperCase(),
            subtitle: '$dayKey · final official standings',
            loadScores: () =>
                _service.fetchOfficialArenaScores(dayKey, bracket),
          ),
        ),
      );
      return;
    }
    if (now.isBefore(start)) {
      final registrationKey = _registrationKey(selectedDate, bracket);
      if (_registered.contains(registrationKey)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You are already registered.')),
        );
        return;
      }
      final error = await _service.registerOfficialArena(dayKey, bracket);
      if (!mounted) return;
      if (error != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error)));
        return;
      }
      setState(() => _registered.add(registrationKey));
      final left = start.difference(now);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'Registered for ${officialBrackets[bracket].name}. '
          '${left < const Duration(hours: 24) ? 'Starts in ${compactCountdown(left)}' : 'Scheduled for $dayKey at 22:00'}.',
        ),
      ));
      return;
    }
    if (now.isBefore(end)) {
      if (!_registered.contains(_registrationKey(selectedDate, bracket))) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Registration is closed. Only registered players can compete.',
            ),
          ),
        );
        return;
      }
      final access = await _service.authorizeOfficialArena(dayKey, bracket);
      if (!mounted) return;
      if (!access.allowed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              access.message ?? 'Could not verify your arena registration.',
            ),
          ),
        );
        return;
      }
      final lobbyEndsAt = access.lobbyEndsAt ??
          arenaQuestionsOpenAt(start).millisecondsSinceEpoch;
      if (AppData.i.lastArenaDayKey == AppData.todayKey()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You already played today’s arena.')),
        );
        return;
      }
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DateTime.now().millisecondsSinceEpoch < lobbyEndsAt
              ? ArenaLobbyScreen(
                  lobbyEndsAt: lobbyEndsAt,
                  title: '${officialBrackets[bracket].name} · MYNDASH OFFICIAL',
                  initialPlayers: [AppData.i.username],
                  playersStream: _service.officialArenaPlayersStream(
                    dayKey,
                    bracket,
                  ),
                  buildGame: () => OfficialArenaPlayScreen(bracket: bracket),
                )
              : OfficialArenaPlayScreen(bracket: bracket),
        ),
      );
      if (mounted) setState(() {});
      return;
    }
  }

  Future<void> _joinPrivate() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Join private arena'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 6,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Arena code',
            hintText: 'Example: 7KQ2ZX',
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Find arena'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (code == null || code.isEmpty || !mounted) return;
    final event = await _service.findEventByCode(code);
    if (!mounted) return;
    if (event == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Arena not found. Check the code and try again.'),
        ),
      );
      return;
    }
    await joinArena(context, event, onDone: _load);
  }
}

class PublicArenasScreen extends StatefulWidget {
  const PublicArenasScreen({super.key});

  @override
  State<PublicArenasScreen> createState() => _PublicArenasScreenState();
}

class _PublicArenasScreenState extends State<PublicArenasScreen> {
  static const _pageSize = 7;
  List<Map<String, dynamic>>? _events;
  bool _loading = true;
  String _query = '';
  String _status = 'all';
  String _game = 'all';
  int _page = 0;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _load();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await AccountService.instance.listPublicEvents();
    if (!mounted) return;
    setState(() {
      _events = result;
      _loading = false;
    });
  }

  List<Map<String, dynamic>> get _filtered {
    final now = DateTime.now().millisecondsSinceEpoch;
    return (_events ?? []).where((event) {
      final title = '${event['title'] ?? ''}'.toLowerCase();
      final organizer = '${event['organizer'] ?? ''}'.toLowerCase();
      final matchesQuery = title.contains(_query.toLowerCase()) ||
          organizer.contains(_query.toLowerCase());
      final matchesGame =
          _game == 'all' || (event['category'] ?? 'mixed') == _game;
      final start = (event['startAt'] as num?)?.toInt();
      final duration =
          ((event['durationMin'] as num?)?.toInt() ?? 10) * 60 * 1000;
      final upcoming = start != null && start > now;
      final completed = start != null && start + duration <= now;
      final live = start == null || (!upcoming && !completed);
      final matchesStatus = _status == 'all' ||
          (_status == 'upcoming' && upcoming) ||
          (_status == 'live' && live) ||
          (_status == 'completed' && completed);
      return matchesQuery && matchesGame && matchesStatus;
    }).toList();
  }

  void _resetPage(VoidCallback change) {
    setState(() {
      change();
      _page = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final events = _filtered;
    final pageCount = max(1, (events.length / _pageSize).ceil());
    if (_page >= pageCount) _page = pageCount - 1;
    final visibleEvents =
        events.skip(_page * _pageSize).take(_pageSize).toList();
    return _ArenaScaffold(
      title: 'PUBLIC ARENAS',
      subtitle: 'Discover events hosted by players.',
      onRefresh: _load,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Glass(
              radius: 24,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    onChanged: (value) => _resetPage(() => _query = value),
                    decoration: const InputDecoration(
                      labelText: 'Search arenas or hosts',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _ArenaSelectField<String>(
                          label: 'Game',
                          value: _game,
                          icon: _game == 'all'
                              ? Icons.apps_rounded
                              : arenaGameIcon(_game),
                          options: [
                            const _ArenaSelectOption(
                              value: 'all',
                              label: 'All games',
                              icon: Icons.apps_rounded,
                            ),
                            for (final game in AccountService.arenaTopics)
                              _ArenaSelectOption(
                                value: game,
                                label: arenaGameLabel(game),
                                icon: arenaGameIcon(game),
                              ),
                          ],
                          onChanged: (value) => _resetPage(() => _game = value),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ArenaSelectField<String>(
                          label: 'Status',
                          value: _status,
                          icon: switch (_status) {
                            'upcoming' => Icons.schedule_rounded,
                            'live' => Icons.play_circle_outline_rounded,
                            'completed' => Icons.leaderboard_outlined,
                            _ => Icons.tune_rounded,
                          },
                          options: const [
                            _ArenaSelectOption(
                              value: 'all',
                              label: 'All status',
                              icon: Icons.tune_rounded,
                            ),
                            _ArenaSelectOption(
                              value: 'upcoming',
                              label: 'Upcoming',
                              icon: Icons.schedule_rounded,
                            ),
                            _ArenaSelectOption(
                              value: 'live',
                              label: 'Live now',
                              icon: Icons.play_circle_outline_rounded,
                            ),
                            _ArenaSelectOption(
                              value: 'completed',
                              label: 'Completed',
                              icon: Icons.leaderboard_outlined,
                            ),
                          ],
                          onChanged: (value) =>
                              _resetPage(() => _status = value),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const _ArenaLoading()
                : _events == null
                    ? _ArenaErrorState(onRetry: _load)
                    : events.isEmpty
                        ? const _ArenaEmptyState(
                            icon: Icons.search_off_rounded,
                            title: 'No matching arenas',
                            message:
                                'Try another game, status, or search term.',
                          )
                        : Column(
                            children: [
                              Expanded(
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final columns =
                                        constraints.maxWidth >= 760 ? 2 : 1;
                                    return GridView.builder(
                                      padding: const EdgeInsets.fromLTRB(
                                          20, 4, 20, 12),
                                      gridDelegate:
                                          SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: columns,
                                        mainAxisSpacing: 12,
                                        crossAxisSpacing: 12,
                                        childAspectRatio:
                                            columns == 1 ? 0.84 : 0.9,
                                      ),
                                      itemCount: visibleEvents.length,
                                      itemBuilder: (_, index) =>
                                          _ArenaEventCard(
                                        event: visibleEvents[index],
                                        actionLabel: 'VIEW & JOIN',
                                        onTap: () => joinArena(
                                          context,
                                          visibleEvents[index],
                                          onDone: _load,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              if (pageCount > 1)
                                _ArenaPagination(
                                  page: _page,
                                  pageCount: pageCount,
                                  onChanged: (page) =>
                                      setState(() => _page = page),
                                ),
                            ],
                          ),
          ),
        ],
      ),
    );
  }
}

class MyArenasScreen extends StatefulWidget {
  const MyArenasScreen({super.key});

  @override
  State<MyArenasScreen> createState() => _MyArenasScreenState();
}

class _MyArenasScreenState extends State<MyArenasScreen> {
  List<Map<String, dynamic>>? _events;
  bool _loading = true;
  int _tab = 0; // 0 = Upcoming, 1 = Ongoing, 2 = History

  /// Live status of a hosted arena: 0 upcoming, 1 ongoing, 2 finished.
  /// Private/instant arenas (no schedule) count as "upcoming" (always open).
  static int arenaStatus(Map<String, dynamic> e) {
    final startAt = (e['startAt'] as num?)?.toInt();
    if (startAt == null) return 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final durMin = (e['durationMin'] as num?)?.toInt() ?? 15;
    final end = startAt + durMin * 60000;
    if (now < startAt) return 0;
    if (now < end) return 1;
    return 2;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await AccountService.instance.listMyEvents();
    if (!mounted) return;
    setState(() {
      _events = result;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final events = _events ?? [];
    final buckets = <List<Map<String, dynamic>>>[[], [], []];
    for (final e in events) {
      buckets[arenaStatus(e)].add(e);
    }
    final shown = buckets[_tab];
    return _ArenaScaffold(
      title: 'MY ARENAS',
      subtitle: 'Manage every event you host.',
      onRefresh: _load,
      trailing: IconButton(
        tooltip: 'Host a new arena',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const HostArenaScreen()),
        ).then((_) => _load()),
        icon: const Icon(Icons.add_rounded),
      ),
      child: _loading
          ? const _ArenaLoading()
          : _events == null
              ? _ArenaErrorState(onRetry: _load)
              : Column(children: [
                  // Upcoming / Ongoing / History segmented control
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
                    child: Row(children: [
                      for (final (i, label) in const [
                        (0, 'Upcoming'),
                        (1, 'Ongoing'),
                        (2, 'History')
                      ])
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _tab = i),
                            child: Container(
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 3),
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: _tab == i
                                    ? LinearGradient(
                                        colors: [DC.violet, DC.cyan])
                                    : null,
                                color: _tab == i ? null : DC.fgo(0.06),
                              ),
                              child: Text(
                                  '$label (${buckets[i].length})',
                                  style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: _tab == i
                                          ? FontWeight.w900
                                          : FontWeight.w600,
                                      color: _tab == i ? Colors.white : null)),
                            ),
                          ),
                        ),
                    ]),
                  ),
                  Expanded(
                    child: shown.isEmpty
                        ? _ArenaEmptyState(
                            icon: _tab == 2
                                ? Icons.history_rounded
                                : _tab == 1
                                    ? Icons.play_circle_outline_rounded
                                    : Icons.stadium_outlined,
                            title: _tab == 0
                                ? 'No upcoming arenas'
                                : _tab == 1
                                    ? 'Nothing live right now'
                                    : 'No finished arenas yet',
                            message: _tab == 0
                                ? 'Host a public event or a private arena for friends.'
                                : _tab == 1
                                    ? 'Arenas appear here while they are running.'
                                    : 'Completed arenas land here — you can clear them anytime.',
                            actionLabel: _tab == 0 ? 'HOST AN ARENA' : null,
                            onAction: _tab == 0
                                ? () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const HostArenaScreen()),
                                    ).then((_) => _load())
                                : null,
                          )
                        : LayoutBuilder(builder: (context, constraints) {
                            final columns =
                                constraints.maxWidth >= 760 ? 2 : 1;
                            return GridView.builder(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 2, 20, 28),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: columns == 1 ? 0.84 : 0.9,
                              ),
                              itemCount: shown.length,
                              itemBuilder: (_, index) => _ArenaEventCard(
                                event: shown[index],
                                actionLabel:
                                    _tab == 2 ? 'VIEW BOARD' : 'OPEN ARENA',
                                onTap: () => joinArena(context, shown[index],
                                    onDone: _load),
                                // Ongoing arenas can't be deleted (only once
                                // finished). Upcoming + History can.
                                onDelete: _tab == 1
                                    ? null
                                    : () => _delete(shown[index]),
                              ),
                            );
                          }),
                  ),
                ]),
    );
  }

  Future<void> _delete(Map<String, dynamic> event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteArenaDialog(title: '${event['title'] ?? 'arena'}'),
    );
    if (confirmed != true || !mounted) return;
    final error = await AccountService.instance.deleteArena(event);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    await _load();
  }
}

/// Destructive-action confirmation: the Delete button only enables once the
/// host types the exact word "delete".
class _DeleteArenaDialog extends StatefulWidget {
  final String title;
  const _DeleteArenaDialog({required this.title});

  @override
  State<_DeleteArenaDialog> createState() => _DeleteArenaDialogState();
}

class _DeleteArenaDialogState extends State<_DeleteArenaDialog> {
  final _c = TextEditingController();
  bool get _ok => _c.text.trim().toLowerCase() == 'delete';

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: DC.bg2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Delete arena?'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(
          '“${widget.title}” will be removed for everyone. This can’t be undone.\n\n'
          'Type "delete" below to confirm.',
          style: const TextStyle(height: 1.4),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _c,
          autofocus: true,
          autocorrect: false,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
              hintText: 'type delete', border: OutlineInputBorder()),
        ),
      ]),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep arena')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: DC.danger),
          onPressed: _ok ? () => Navigator.pop(context, true) : null,
          child: const Text('Delete'),
        ),
      ],
    );
  }
}

class OrganizationArenaScreen extends StatefulWidget {
  final String organizationTag;
  final String organizationName;
  final bool college;

  const OrganizationArenaScreen({
    super.key,
    required this.organizationTag,
    required this.organizationName,
    required this.college,
  });

  @override
  State<OrganizationArenaScreen> createState() =>
      _OrganizationArenaScreenState();
}

class _OrganizationArenaScreenState extends State<OrganizationArenaScreen> {
  List<Map<String, dynamic>>? _events;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final result = await AccountService.instance
        .listPublicEvents(organization: widget.organizationTag);
    if (!mounted) return;
    setState(() {
      _events = result;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final events = _events ?? [];
    return _ArenaScaffold(
      title: 'ORGANIZATION ARENA',
      subtitle: widget.organizationName,
      onRefresh: _load,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Glass(
              radius: 24,
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  _IconPlate(
                    icon: widget.college
                        ? Icons.school_rounded
                        : Icons.apartment_rounded,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.organizationName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Only verified organization members can discover and join these arenas.',
                          style: TextStyle(
                              color: DC.dim, fontSize: 11, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'My hosted arenas',
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MyArenasScreen(),
                          ),
                        ).then((_) => _load()),
                        icon: const Icon(Icons.event_available_outlined),
                      ),
                      IconButton(
                        tooltip: 'Host organization arena',
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => HostArenaScreen(
                              organization: widget.organizationTag,
                              organizationLabel: widget.organizationName,
                            ),
                          ),
                        ).then((_) => _load()),
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const _ArenaSectionTitle(
            title: 'MEMBER EVENTS',
            subtitle: 'Private to your verified organization.',
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const _ArenaLoading()
                : _events == null
                    ? _ArenaErrorState(onRetry: _load)
                    : events.isEmpty
                        ? _ArenaEmptyState(
                            icon: Icons.groups_outlined,
                            title: 'No organization arenas',
                            message:
                                'Host the first event for your organization.',
                            actionLabel: 'HOST MEMBER EVENT',
                            onAction: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => HostArenaScreen(
                                  organization: widget.organizationTag,
                                  organizationLabel: widget.organizationName,
                                ),
                              ),
                            ).then((_) => _load()),
                          )
                        : LayoutBuilder(builder: (context, constraints) {
                            final columns = constraints.maxWidth >= 760 ? 2 : 1;
                            return GridView.builder(
                              padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: columns == 1 ? 0.84 : 0.9,
                              ),
                              itemCount: events.length,
                              itemBuilder: (_, index) => _ArenaEventCard(
                                event: events[index],
                                actionLabel: 'VIEW & JOIN',
                                onTap: () => joinArena(
                                  context,
                                  events[index],
                                  onDone: _load,
                                ),
                              ),
                            );
                          }),
          ),
        ],
      ),
    );
  }
}

class HostArenaScreen extends StatefulWidget {
  final String? organization;
  final String? organizationLabel;

  const HostArenaScreen({
    super.key,
    this.organization,
    this.organizationLabel,
  });

  @override
  State<HostArenaScreen> createState() => _HostArenaScreenState();
}

class _HostArenaScreenState extends State<HostArenaScreen> {
  final _title = TextEditingController();
  bool _isPublic = true;
  // Up to 5 quiz-style topics can be combined (one drawn per question).
  // Board games (chess, sudoku, art heist, crossword, number puzzle) are
  // exclusive — picking one clears the rest and locks out further picks.
  Set<String> _games = {'mixed'};
  int _gameRating = 1200;
  RangeValues _eligibility = const RangeValues(800, 2500);
  bool _wagered = false;
  int _fee = 0;
  int _players = 10;
  int _questions = 15;
  int _minutes = 15;
  int _startHourOffset = 0;
  Uint8List? _cover;
  bool _pickingImage = false;
  bool _creating = false;
  String? _imageError;

  static const _startHourOffsets = [0, 1, 2, 5, 11, 23];

  bool get _organizationOnly => widget.organization != null;
  int get _cap => _isPublic || _organizationOnly
      ? AccountService.publicHostCap()
      : AccountService.privateHostCap();

  static const _maxComboTopics = 5;

  void _toggleGame(String game) {
    final spec = ArenaGameCatalog.byId(game);
    if (!spec.usesQuestionCount || game == 'mixed') {
      // Board games are single-instance, and "Mixed Skills" already draws
      // from every topic — both are exclusive picks.
      setState(() => _games = {game});
      return;
    }
    if (_games.contains(game)) {
      if (_games.length > 1) setState(() => _games.remove(game));
      return; // keep at least one topic selected
    }
    if (_games.length >= _maxComboTopics) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('You can combine up to 5 topics in one arena.')));
      return;
    }
    setState(() {
      // adding a quiz topic drops "mixed" or any exclusive board game
      _games.removeWhere(
          (g) => g == 'mixed' || !ArenaGameCatalog.byId(g).usesQuestionCount);
      _games.add(game);
    });
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ArenaScaffold(
      title: 'HOST ARENA',
      subtitle: _organizationOnly
          ? '${widget.organizationLabel} members only'
          : 'Set the game, level and rules.',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _formSection(
            number: '01',
            title: 'ACCESS',
            subtitle: 'Choose who can discover and join.',
            child: Column(
              children: [
                if (_organizationOnly)
                  _FixedScopeCard(
                    icon: Icons.verified_user_rounded,
                    title: 'Organization members',
                    subtitle:
                        'Only verified members of ${widget.organizationLabel} can join.',
                  )
                else
                  _visibilitySelector(),
                const SizedBox(height: 16),
                TextField(
                  controller: _title,
                  maxLength: 36,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Arena name',
                    hintText: 'Friday Night Minds',
                    helperText: 'Use a clear, recognizable event name.',
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'ELIGIBLE PLAYER RATING',
                    style: TextStyle(
                      color: DC.dim,
                      fontSize: 10,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _RatingValue(value: _eligibility.start.round()),
                    Expanded(
                      child: RangeSlider(
                        values: _eligibility,
                        min: 800,
                        max: 2500,
                        divisions: 17,
                        labels: RangeLabels(
                          '${_eligibility.start.round()}',
                          '${_eligibility.end.round()}',
                        ),
                        onChanged: (value) =>
                            setState(() => _eligibility = value),
                      ),
                    ),
                    _RatingValue(value: _eligibility.end.round()),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _formSection(
            number: '02',
            title: 'GAME & LEVEL',
            subtitle: 'All entrants receive the same seeded challenge.',
            child: Column(
              children: [
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 2.65,
                  ),
                  itemCount: AccountService.arenaTopics.length,
                  itemBuilder: (_, index) {
                    final game = AccountService.arenaTopics[index];
                    return _GameChoice(
                      game: game,
                      selected: _games.contains(game),
                      onTap: () => _toggleGame(game),
                    );
                  },
                ),
                const SizedBox(height: 8),
                Text(
                  _games.length > 1
                      ? '${_games.length} topics combined · one drawn at random per question'
                      : 'Tap up to 5 quiz topics to combine them in one arena.',
                  style: TextStyle(color: DC.dim, fontSize: 10.5),
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'GAME LEVEL',
                    style: TextStyle(
                      color: DC.dim,
                      fontSize: 10,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.72,
                  ),
                  itemCount: RatingCatalog.bands.length,
                  itemBuilder: (_, index) {
                    final rating = RatingCatalog.bands[index];
                    return _RatingChoice(
                      rating: rating,
                      selected: rating == _gameRating,
                      onTap: () => setState(() => _gameRating = rating),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _formSection(
            number: '03',
            title: 'FORMAT',
            subtitle: 'Set timing, field size and rewards.',
            child: Column(
              children: [
                _ArenaSelectField<int>(
                  label: 'Hourly start',
                  value: _startHourOffset,
                  icon: Icons.schedule_rounded,
                  options: [
                    for (final offset in _startHourOffsets)
                      _ArenaSelectOption(
                        value: offset,
                        label: fmtEventDateTime(
                          nextHourlyArenaSlot(
                            DateTime.now(),
                            additionalHours: offset,
                          ).millisecondsSinceEpoch,
                        ),
                        icon: Icons.schedule_rounded,
                      ),
                  ],
                  onChanged: (value) =>
                      setState(() => _startHourOffset = value),
                ),
                const SizedBox(height: 14),
                _HostStepper(
                  label: 'Players',
                  value: _players,
                  minimum: 2,
                  maximum: _cap,
                  onChanged: (value) => setState(() => _players = value),
                ),
                if (ArenaGameCatalog.byId(_games.first).usesQuestionCount)
                  _HostStepper(
                    label: 'Questions',
                    value: _questions,
                    minimum: AccountService.arenaMinQuestions,
                    maximum: AccountService.arenaMaxQuestions,
                    onChanged: (value) => setState(() => _questions = value),
                  )
                else
                  const _FixedFormatLine(
                    label: 'Challenge',
                    value: '1 complete seeded board',
                  ),
                _HostStepper(
                  label: 'Minutes',
                  value: _minutes,
                  minimum: AccountService.arenaMinMinutes,
                  maximum: AccountService.arenaMaxMinutes,
                  onChanged: (value) => setState(() => _minutes = value),
                ),
                const SizedBox(height: 6),
                _entrySelector(),
                if (_wagered) ...[
                  const SizedBox(height: 12),
                  _HostStepper(
                    label: 'Entry coins',
                    value: _fee,
                    minimum: 25,
                    maximum: 1000,
                    step: 25,
                    onChanged: (value) => setState(() => _fee = value),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          _formSection(
            number: '04',
            title: 'COVER',
            subtitle: 'Optional. Images are resized for reliable upload.',
            child: _coverPicker(),
          ),
          const SizedBox(height: 24),
          Semantics(
            button: true,
            label: _creating ? 'Creating arena' : 'Create arena',
            child: SizedBox(
              height: 56,
              child: FilledButton.icon(
                onPressed: _creating ? null : _create,
                icon: _creating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_rounded),
                label: Text(_creating ? 'CREATING ARENA…' : 'CREATE ARENA'),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _isPublic || _organizationOnly
                ? 'Registration closes at the selected hour. A shared '
                    '2-minute lobby opens before the challenge.'
                : 'Private arenas use a six-character join code. '
                    'They use the same hourly cutoff and 2-minute lobby; '
                    'first place receives 75% and second place 25%.',
            textAlign: TextAlign.center,
            style: TextStyle(color: DC.dim, fontSize: 11, height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _formSection({
    required String number,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Column(
      children: [
        _ArenaSectionTitle(
          eyebrow: number,
          title: title,
          subtitle: subtitle,
        ),
        const SizedBox(height: 14),
        Glass(radius: 26, padding: const EdgeInsets.all(18), child: child),
      ],
    );
  }

  Widget _visibilitySelector() {
    final options = [
      (true, Icons.public_rounded, 'Public', 'Discoverable and scheduled'),
      (false, Icons.key_rounded, 'Private', 'Invite with a code'),
    ];
    return Row(
      children: [
        for (var index = 0; index < options.length; index++) ...[
          if (index > 0) const SizedBox(width: 10),
          Expanded(
            child: _SelectionCard(
              icon: options[index].$2,
              title: options[index].$3,
              subtitle: options[index].$4,
              selected: _isPublic == options[index].$1,
              onTap: () => setState(() {
                _isPublic = options[index].$1;
                _players = min(_players, _cap);
              }),
            ),
          ),
        ],
      ],
    );
  }

  Widget _entrySelector() {
    return Row(
      children: [
        Expanded(
          child: _SelectionCard(
            icon: Icons.confirmation_number_outlined,
            title: 'Free entry',
            subtitle: 'No coin requirement',
            selected: !_wagered,
            onTap: () => setState(() {
              _wagered = false;
              _fee = 0;
            }),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SelectionCard(
            icon: Icons.monetization_on_outlined,
            title: 'Coin entry',
            subtitle: 'Build a prize pool',
            selected: _wagered,
            onTap: () => setState(() {
              _wagered = true;
              if (_fee == 0) _fee = 50;
            }),
          ),
        ),
      ],
    );
  }

  Widget _coverPicker() {
    return Column(
      children: [
        Semantics(
          button: true,
          label: _cover == null
              ? 'Upload arena cover image'
              : 'Change arena cover image',
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: _pickingImage ? null : _pickCover,
            child: Container(
              height: 156,
              width: double.infinity,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: DC.fgo(0.045),
                border: Border.all(color: DC.fgo(0.14)),
                image: _cover == null
                    ? null
                    : DecorationImage(
                        image: MemoryImage(_cover!),
                        fit: BoxFit.cover,
                      ),
              ),
              child: _pickingImage
                  ? const Center(child: CircularProgressIndicator())
                  : DecoratedBox(
                      decoration: BoxDecoration(
                        color: _cover == null
                            ? Colors.transparent
                            : Colors.black.withOpacity(0.35),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _cover == null
                                  ? Icons.add_photo_alternate_outlined
                                  : Icons.edit_outlined,
                              size: 30,
                              color:
                                  _cover == null ? _arenaAccent : Colors.white,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _cover == null
                                  ? 'CHOOSE COVER IMAGE'
                                  : 'CHANGE COVER IMAGE',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                color: _cover == null ? DC.text : Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
        ),
        if (_imageError != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.error_outline, size: 16, color: DC.danger),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _imageError!,
                  style: TextStyle(color: DC.danger, fontSize: 11),
                ),
              ),
            ],
          ),
        ],
        if (_cover != null) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => setState(() {
              _cover = null;
              _imageError = null;
            }),
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text('Remove image'),
          ),
        ],
      ],
    );
  }

  Future<void> _pickCover() async {
    setState(() {
      _pickingImage = true;
      _imageError = null;
    });
    try {
      final selected = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 92,
      );
      if (selected == null) {
        if (mounted) setState(() => _pickingImage = false);
        return;
      }
      final source = await selected.readAsBytes();
      final compressed = await compute(compressArenaCoverForUpload, source);
      if (!mounted) return;
      if (compressed == null) {
        setState(() {
          _pickingImage = false;
          _imageError =
              'This image could not be prepared. Try a JPG or PNG image.';
        });
        return;
      }
      setState(() {
        _cover = compressed;
        _pickingImage = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _pickingImage = false;
        _imageError =
            'Image access failed. Check photo permissions and try again.';
      });
    }
  }

  Future<void> _create() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_title.text.trim().length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an arena name of 3+ characters.')),
      );
      return;
    }
    setState(() => _creating = true);
    final startAt = nextHourlyArenaSlot(
      DateTime.now(),
      additionalHours: _startHourOffset,
    ).millisecondsSinceEpoch;
    final (error, code) = await AccountService.instance.createArena(
      title: _title.text.trim(),
      fee: _fee,
      isPublic: _organizationOnly || _isPublic,
      category: _games.first,
      categories: _games.length > 1 ? _games.toList() : null,
      maxPlayers: _players,
      questionCount: _questions,
      durationMin: _minutes,
      ratingMin: _eligibility.start.round(),
      ratingMax: _eligibility.end.round(),
      gameRating: _gameRating,
      startAt: startAt,
      org: widget.organization,
      bgBase64: _cover == null ? null : base64Encode(_cover!),
    );
    if (!mounted) return;
    setState(() => _creating = false);
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    Fx.unlock();
    if (code != null) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => _ArenaCreatedDialog(
          title: _title.text.trim(),
          code: code,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_title.text.trim()} is scheduled for '
            '${fmtEventDateTime(startAt)}. Registration closes exactly at start time.',
          ),
        ),
      );
    }
    if (mounted) Navigator.pop(context, true);
  }
}

class _ArenaScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Future<void> Function()? onRefresh;
  final Widget? trailing;

  const _ArenaScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
    this.onRefresh,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ShaderBackground(
        child: SafeArea(
          child: Column(
            children: [
              SizedBox(
                height: 76,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      left: 20,
                      child: Glass(
                        radius: 16,
                        padding: EdgeInsets.zero,
                        onTap: () => Navigator.pop(context),
                        child: const SizedBox(
                          width: 48,
                          height: 48,
                          child: Icon(Icons.arrow_back_rounded, size: 20),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 78),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 10, color: DC.dim),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      right: 20,
                      child: trailing ??
                          (onRefresh == null
                              ? const SizedBox(width: 48)
                              : Glass(
                                  radius: 16,
                                  padding: EdgeInsets.zero,
                                  onTap: onRefresh,
                                  child: const SizedBox(
                                    width: 48,
                                    height: 48,
                                    child:
                                        Icon(Icons.refresh_rounded, size: 20),
                                  ),
                                )),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: onRefresh == null
                    ? child
                    : RefreshIndicator(
                        color: _arenaAccent,
                        onRefresh: onRefresh!,
                        child: child,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArenaIntroCard extends StatelessWidget {
  final DateTime now;
  const _ArenaIntroCard({required this.now});

  @override
  Widget build(BuildContext context) {
    final start = arenaStartFor(now);
    final live = isArenaDay(now) &&
        !now.isBefore(start) &&
        now.isBefore(start.add(const Duration(minutes: arenaMinutes)));
    final status = !isArenaDay(now)
        ? 'Returns Monday'
        : now.isBefore(start)
            ? 'Starts in ${_formatRemaining(start.difference(now))}'
            : live
                ? 'Live now'
                : 'Completed today';
    return Glass(
      radius: 28,
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          _IconPlate(icon: Icons.stadium_rounded, size: 56),
          const SizedBox(height: 14),
          Text(
            'A fair field for every mind.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  fontSize: 24,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Official events run across six skill levels every weekday. '
            'Player-hosted arenas live in their own focused spaces.',
            textAlign: TextAlign.center,
            style: TextStyle(color: DC.dim, height: 1.5, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: _arenaAccent.withOpacity(0.10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  live
                      ? Icons.play_circle_fill_rounded
                      : Icons.schedule_rounded,
                  color: _arenaAccent,
                  size: 17,
                ),
                const SizedBox(width: 7),
                Text(
                  status,
                  style: TextStyle(
                    color: _arenaAccent,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ArenaSectionTitle extends StatelessWidget {
  final String? eyebrow;
  final String title;
  final String subtitle;

  const _ArenaSectionTitle({
    this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (eyebrow != null) ...[
          Text(
            eyebrow!,
            style: TextStyle(
              color: _arenaAccent,
              fontSize: 10,
              letterSpacing: 2,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
        ],
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(color: DC.dim, fontSize: 11),
        ),
      ],
    );
  }
}

class _OfficialArenaCard extends StatelessWidget {
  final ArenaBracket bracket;
  final int index;
  final int selectedWeekday;
  final EventPhase phase;
  final DateTime startsAt;
  final bool registered;
  final bool isMine;
  final VoidCallback onTap;

  const _OfficialArenaCard({
    required this.bracket,
    required this.index,
    required this.selectedWeekday,
    required this.phase,
    required this.startsAt,
    required this.registered,
    required this.isMine,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bandColor = _arenaAccent;
    final left = startsAt.difference(DateTime.now());
    final status = switch (phase) {
      EventPhase.completed => 'LEADERBOARD',
      EventPhase.live => 'LIVE NOW',
      EventPhase.upcoming when registered => 'REGISTERED',
      EventPhase.upcoming when left <= const Duration(hours: 24) =>
        compactCountdown(left),
      EventPhase.upcoming => 'UPCOMING',
    };
    return Semantics(
      button: true,
      label:
          '${bracket.name}, rating ${bracket.range}${isMine ? ', recommended for you' : ''}',
      child: Glass(
        onTap: onTap,
        radius: 24,
        padding: const EdgeInsets.all(14),
        border: Border.all(
          color: isMine ? bandColor.withOpacity(0.7) : DC.fgo(0.12),
          width: isMine ? 1.5 : 1,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: bandColor.withOpacity(0.12),
              ),
              child: Icon(
                [
                  Icons.foundation_rounded,
                  Icons.route_rounded,
                  Icons.lock_open_rounded,
                  Icons.terrain_rounded,
                  Icons.trending_up_rounded,
                  Icons.workspace_premium_rounded,
                ][index],
                color: bandColor,
                size: 25,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              bracket.name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            const SizedBox(height: 3),
            Text(
              bracket.range,
              style: TextStyle(
                color: bandColor,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: registered ? DC.lime.withOpacity(0.11) : DC.fgo(0.045),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: phase == EventPhase.live
                      ? DC.danger
                      : registered
                          ? DC.lime
                          : phase == EventPhase.completed
                              ? bandColor
                              : isMine
                                  ? bandColor
                                  : DC.dim,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.7,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DestinationCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DestinationCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      child: Glass(
        onTap: onTap,
        radius: 24,
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _IconPlate(icon: icon),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: DC.dim, fontSize: 10, height: 1.35),
            ),
            const SizedBox(height: 8),
            Icon(Icons.arrow_forward_rounded, size: 17, color: _arenaAccent),
          ],
        ),
      ),
    );
  }
}

class _ArenaEventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final String actionLabel;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _ArenaEventCard({
    required this.event,
    required this.actionLabel,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cover = _arenaCover(event);
    final fee = (event['fee'] as num?)?.toInt() ?? 0;
    final players = (event['players'] as Map?)?.length ?? 0;
    final maxPlayers = (event['maxPlayers'] as num?)?.toInt() ?? 8;
    final rating =
        ((event['gameRating'] as num?)?.toInt() ?? 800).clamp(800, 2500);
    final startAt = (event['startAt'] as num?)?.toInt();
    final now = DateTime.now().millisecondsSinceEpoch;
    final durationMs =
        ((event['durationMin'] as num?)?.toInt() ?? 10) * 60 * 1000;
    final pending = startAt != null && startAt > now;
    final completed = startAt != null &&
        startAt + arenaLobbyDuration.inMilliseconds + durationMs <= now;
    final registered = arenaHasRegistered(
      event,
      uid: AccountService.instance.uid,
      username: AppData.i.username,
    );
    final startsIn =
        startAt == null ? Duration.zero : Duration(milliseconds: startAt - now);
    final public = event['public'] == true;
    final organization = '${event['org'] ?? ''}'.trim();
    final organizationName = organization.contains(':')
        ? organization.substring(organization.indexOf(':') + 1)
        : organization;
    final comboTopics = (event['categories'] as List?)?.cast<String>() ??
        const <String>[];

    return Glass(
      radius: 26,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 7,
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(25)),
              child: cover == null
                  ? Container(
                      color: DC.fgo(0.045),
                      child: Center(
                        child: _IconPlate(
                          icon: arenaGameIcon(
                              (event['category'] as String?) ?? 'mixed'),
                          size: 54,
                        ),
                      ),
                    )
                  : Image(
                      image: cover,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: DC.fgo(0.045),
                        child: const Icon(Icons.image_not_supported_outlined),
                      ),
                    ),
            ),
          ),
          Expanded(
            flex: 10,
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${event['title'] ?? 'Arena'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      if (onDelete != null)
                        SizedBox(
                          width: 44,
                          height: 44,
                          child: IconButton(
                            tooltip: 'Delete arena',
                            onPressed: onDelete,
                            icon: const Icon(Icons.delete_outline_rounded,
                                size: 20),
                          ),
                        ),
                    ],
                  ),
                  Text(
                    'by @${event['organizer'] ?? 'host'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: DC.dim, fontSize: 10),
                  ),
                  const SizedBox(height: 9),
                  _ArenaPrizeBanner(event: event),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (organizationName.isNotEmpty)
                        _MetaChip(
                          icon: organization.startsWith('college:')
                              ? Icons.school_outlined
                              : Icons.apartment_outlined,
                          label: organizationName,
                        ),
                      _MetaChip(
                        icon: comboTopics.length > 1
                            ? Icons.shuffle_rounded
                            : arenaGameIcon(
                                (event['category'] as String?) ?? 'mixed'),
                        label: comboTopics.length > 1
                            ? '${comboTopics.length} topics'
                            : arenaGameLabel(
                                (event['category'] as String?) ?? 'mixed'),
                      ),
                      _MetaChip(
                          icon: Icons.signal_cellular_alt_rounded,
                          label: '$rating'),
                      _MetaChip(
                        icon: Icons.groups_rounded,
                        label: '$players/$maxPlayers',
                      ),
                      _MetaChip(
                        icon: fee == 0
                            ? Icons.confirmation_number_outlined
                            : Icons.monetization_on_outlined,
                        label: fee == 0 ? 'Free' : '$fee coins',
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          pending
                              ? startsIn <= const Duration(hours: 24)
                                  ? 'UPCOMING · ${compactCountdown(startsIn)}'
                                  : 'UPCOMING · ${fmtEventDateTime(startAt)}'
                              : completed
                                  ? 'COMPLETED · FINAL BOARD'
                                  : public
                                      ? 'Open now'
                                      : 'Private code arena',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: pending ? DC.amber : DC.dim,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: onTap,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(44, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          completed
                              ? 'LEADERBOARD'
                              : pending && registered
                                  ? 'REGISTERED'
                                  : actionLabel,
                          style: const TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArenaPrizeBanner extends StatelessWidget {
  final Map<String, dynamic> event;

  const _ArenaPrizeBanner({required this.event});

  @override
  Widget build(BuildContext context) {
    final prize = arenaPrizePool(event);
    final split1 = (event['split1'] as num?)?.toInt() ??
        (event['public'] == true ? 100 : 75);
    final split2 = (event['split2'] as num?)?.toInt() ??
        (event['public'] == true ? 0 : 25);
    return Semantics(
      label: 'Prize pool $prize coins. First place $split1 percent'
          '${split2 > 0 ? ', second place $split2 percent' : ''}.',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          gradient: LinearGradient(
            colors: [
              DC.amber.withOpacity(0.18),
              DC.amber.withOpacity(0.06),
            ],
          ),
          border: Border.all(color: DC.amber.withOpacity(0.38)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.monetization_on_rounded,
              size: 38,
              color: DC.amber,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PRIZE POOL',
                    style: TextStyle(
                      color: DC.dim,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    '$prize COINS',
                    style: TextStyle(
                      color: DC.amber,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            Text(
              split2 > 0 ? '$split1 / $split2' : 'WINNER\nTAKES ALL',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: DC.text,
                fontSize: 8,
                height: 1.2,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconPlate extends StatelessWidget {
  final IconData icon;
  final double size;
  const _IconPlate({required this.icon, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.32),
        color: _arenaAccent.withOpacity(0.11),
        border: Border.all(color: _arenaAccent.withOpacity(0.18)),
      ),
      child: Icon(icon, color: _arenaAccent, size: size * 0.48),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: DC.fgo(0.045),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: DC.dim),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: DC.dim,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArenaSelectOption<T> {
  final T value;
  final String label;
  final IconData icon;

  const _ArenaSelectOption({
    required this.value,
    required this.label,
    required this.icon,
  });
}

class _ArenaSelectField<T> extends StatelessWidget {
  final String label;
  final T value;
  final IconData icon;
  final List<_ArenaSelectOption<T>> options;
  final ValueChanged<T> onChanged;

  const _ArenaSelectField({
    required this.label,
    required this.value,
    required this.icon,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final current = options.firstWhere((option) => option.value == value);
    return Semantics(
      button: true,
      label: '$label, ${current.label}',
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _open(context),
        child: Container(
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: DC.fgo(0.035),
            border: Border.all(color: DC.fgo(0.12)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 19, color: _arenaAccent),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: TextStyle(
                        color: DC.dim,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      current.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.expand_more_rounded, size: 19, color: DC.dim),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final picked = await showModalBottomSheet<T>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: DC.bg2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.72,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 14),
              child: Column(
                children: [
                  Text(
                    'SELECT ${label.toUpperCase()}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${options.length} available option${options.length == 1 ? '' : 's'}',
                    style: TextStyle(color: DC.dim, fontSize: 10),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: options.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (_, index) {
                  final option = options[index];
                  final selected = option.value == value;
                  return Semantics(
                    button: true,
                    selected: selected,
                    child: ListTile(
                      minTileHeight: 54,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(
                          color: selected
                              ? _arenaAccent.withOpacity(0.45)
                              : DC.fgo(0.08),
                        ),
                      ),
                      tileColor: selected
                          ? _arenaAccent.withOpacity(0.10)
                          : DC.fgo(0.025),
                      leading: Icon(
                        option.icon,
                        color: selected ? _arenaAccent : DC.dim,
                      ),
                      title: Text(
                        option.label,
                        style: TextStyle(
                          fontWeight:
                              selected ? FontWeight.w900 : FontWeight.w700,
                        ),
                      ),
                      trailing: selected
                          ? Icon(Icons.check_circle_rounded,
                              color: _arenaAccent)
                          : const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.pop(sheetContext, option.value),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
    if (picked != null) onChanged(picked);
  }
}

class _ArenaPagination extends StatelessWidget {
  final int page;
  final int pageCount;
  final ValueChanged<int> onChanged;

  const _ArenaPagination({
    required this.page,
    required this.pageCount,
    required this.onChanged,
  });

  List<int> get _visiblePages {
    if (pageCount <= 5) return List.generate(pageCount, (index) => index);
    final pages = <int>{0, page - 1, page, page + 1, pageCount - 1}
      ..removeWhere((item) => item < 0 || item >= pageCount);
    return pages.toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    final pages = _visiblePages;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: [
            _PageButton(
              label: 'Previous page',
              icon: Icons.chevron_left_rounded,
              onTap: page > 0 ? () => onChanged(page - 1) : null,
            ),
            for (var index = 0; index < pages.length; index++) ...[
              if (index > 0 && pages[index] - pages[index - 1] > 1)
                SizedBox(
                  width: 28,
                  height: 44,
                  child: Center(
                    child: Text('…', style: TextStyle(color: DC.dim)),
                  ),
                ),
              _PageNumber(
                number: pages[index] + 1,
                selected: pages[index] == page,
                onTap: () => onChanged(pages[index]),
              ),
            ],
            _PageButton(
              label: 'Next page',
              icon: Icons.chevron_right_rounded,
              onTap: page + 1 < pageCount ? () => onChanged(page + 1) : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _PageButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const _PageButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      tooltip: label,
      onPressed: onTap,
      constraints: const BoxConstraints.tightFor(width: 44, height: 44),
      icon: Icon(icon, size: 18),
    );
  }
}

class _PageNumber extends StatelessWidget {
  final int number;
  final bool selected;
  final VoidCallback onTap;

  const _PageNumber({
    required this.number,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Page $number',
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: selected ? _arenaAccent : DC.fgo(0.05),
            border: Border.all(
              color: selected ? _arenaAccent : DC.fgo(0.12),
            ),
          ),
          child: Text(
            '$number',
            style: TextStyle(
              color: selected ? Colors.white : DC.text,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _SelectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minHeight: 116),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: selected ? _arenaAccent.withOpacity(0.11) : DC.fgo(0.035),
            border: Border.all(
              color: selected ? _arenaAccent.withOpacity(0.45) : DC.fgo(0.1),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: selected ? _arenaAccent : DC.dim, size: 23),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: DC.dim, fontSize: 9, height: 1.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FixedScopeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FixedScopeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: _arenaAccent.withOpacity(0.10),
        border: Border.all(color: _arenaAccent.withOpacity(0.28)),
      ),
      child: Row(
        children: [
          Icon(icon, color: _arenaAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 13),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(color: DC.dim, fontSize: 10, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GameChoice extends StatelessWidget {
  final String game;
  final bool selected;
  final VoidCallback onTap;

  const _GameChoice({
    required this.game,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${arenaGameLabel(game)} game',
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: selected ? _arenaAccent.withOpacity(0.11) : DC.fgo(0.035),
            border: Border.all(
              color: selected ? _arenaAccent.withOpacity(0.45) : DC.fgo(0.09),
            ),
          ),
          child: Row(
            children: [
              Icon(
                arenaGameIcon(game),
                size: 19,
                color: selected ? _arenaAccent : DC.dim,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  arenaGameLabel(game),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RatingChoice extends StatelessWidget {
  final int rating;
  final bool selected;
  final VoidCallback onTap;

  const _RatingChoice({
    required this.rating,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = _arenaAccent;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Game level $rating',
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: selected ? color.withOpacity(0.14) : DC.fgo(0.03),
            border: Border.all(
              color: selected ? color.withOpacity(0.65) : DC.fgo(0.09),
            ),
          ),
          child: Text(
            '$rating',
            style: TextStyle(
              color: selected ? color : DC.dim,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _RatingValue extends StatelessWidget {
  final int value;
  const _RatingValue({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        color: _arenaAccent.withOpacity(0.10),
      ),
      child: Text(
        '$value',
        style: TextStyle(
          color: _arenaAccent,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _HostStepper extends StatelessWidget {
  final String label;
  final int value;
  final int minimum;
  final int maximum;
  final int step;
  final ValueChanged<int> onChanged;

  const _HostStepper({
    required this.label,
    required this.value,
    required this.minimum,
    required this.maximum,
    required this.onChanged,
    this.step = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: DC.fgo(0.07))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          _StepperButton(
            icon: Icons.remove_rounded,
            label: 'Decrease $label',
            onTap:
                value - step >= minimum ? () => onChanged(value - step) : null,
          ),
          SizedBox(
            width: 62,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
            ),
          ),
          _StepperButton(
            icon: Icons.add_rounded,
            label: 'Increase $label',
            onTap:
                value + step <= maximum ? () => onChanged(value + step) : null,
          ),
        ],
      ),
    );
  }
}

class _FixedFormatLine extends StatelessWidget {
  final String label;
  final String value;

  const _FixedFormatLine({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: DC.fgo(0.07))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
          Icon(Icons.lock_outline_rounded, size: 17, color: DC.dim),
          const SizedBox(width: 7),
          Text(
            value,
            style: TextStyle(
              color: DC.dim,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _StepperButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      child: SizedBox(
        width: 48,
        height: 48,
        child: IconButton.filledTonal(
          onPressed: onTap,
          icon: Icon(icon, size: 18),
        ),
      ),
    );
  }
}

class _ArenaCreatedDialog extends StatelessWidget {
  final String title;
  final String code;

  const _ArenaCreatedDialog({required this.title, required this.code});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Arena ready'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: _arenaAccent.withOpacity(0.10),
              border: Border.all(color: _arenaAccent.withOpacity(0.25)),
            ),
            child: Text(
              code,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _arenaAccent,
                fontWeight: FontWeight.w900,
                fontSize: 28,
                letterSpacing: 5,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Share this code with invited players.',
            style: TextStyle(color: DC.dim, fontSize: 11),
          ),
        ],
      ),
      actions: [
        TextButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: code));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Arena code copied.')),
            );
          },
          icon: const Icon(Icons.copy_rounded),
          label: const Text('Copy code'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

class _ArenaLoading extends StatelessWidget {
  const _ArenaLoading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(color: _arenaAccent),
    );
  }
}

class _ArenaErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ArenaErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return _ArenaEmptyState(
      icon: Icons.cloud_off_outlined,
      title: 'Arena server unavailable',
      message: 'Check your connection, then try again.',
      actionLabel: 'RETRY',
      onAction: onRetry,
    );
  }
}

class _ArenaEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _ArenaEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _IconPlate(icon: icon, size: 60),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: DC.dim, fontSize: 12, height: 1.45),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              FilledButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _formatRemaining(Duration duration) {
  if (duration.isNegative) return 'now';
  if (duration.inHours > 0) {
    return '${duration.inHours}h ${duration.inMinutes % 60}m';
  }
  if (duration.inMinutes > 0) {
    return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
  }
  return '${duration.inSeconds}s';
}

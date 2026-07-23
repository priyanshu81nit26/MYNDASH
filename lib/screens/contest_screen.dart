import 'dart:async';

import 'package:flutter/material.dart';

import '../contest/contest_bank.dart';
import '../contest/contest_leaderboard.dart';
import '../contest/contest_stages.dart';
import '../core/state.dart';
import '../engine/event_calendar.dart';
import '../engine/question.dart';
import '../services/account_service.dart';
import '../theme_district.dart';
import '../ui/extras.dart';
import '../ui/glass.dart';

/// LeetCode-style official weekend contest lobby: the next 2 upcoming
/// events, plus the last 3 finished ones with a tap-through to their
/// final leaderboard.
class ContestScreen extends StatefulWidget {
  const ContestScreen({super.key});

  @override
  State<ContestScreen> createState() => _ContestScreenState();
}

class _ContestScreenState extends State<ContestScreen> {
  final Set<String> _registered = <String>{};
  Timer? _clock;
  bool _loading = true;
  bool _entryBusy = false;
  String? _registering;
  final Set<String> _autoOpened = <String>{};
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadRegistrations();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
      _maybeAutoEnter();
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _loadRegistrations() async {
    final registrations =
        await AccountService.instance.myOfficialContestRegistrations();
    if (!mounted) return;
    setState(() {
      _registered
        ..clear()
        ..addAll(registrations ?? const <String>{});
      _loading = false;
    });
    _maybeAutoEnter();
  }

  /// Only the next 2 upcoming events — no calendar browsing.
  List<OfficialContestEvent> get _upcomingEvents => officialContestCalendar(
          _now,
          previous: 0,
          upcoming: 6)
      .where((event) => event.phaseAt(_now) != ContestEventPhase.finalStandings)
      .take(2)
      .toList();

  /// The 3 most recently finished official events, newest first — tap one
  /// to view its leaderboard directly.
  List<OfficialContestEvent> get _lastContests {
    final events = officialContestCalendar(_now, previous: 8, upcoming: 0)
        .where(
            (event) => event.phaseAt(_now) == ContestEventPhase.finalStandings)
        .toList()
      ..sort((a, b) => b.startsAt.compareTo(a.startsAt));
    return events.take(3).toList();
  }

  Future<void> _register(OfficialContestEvent event) async {
    if (!event.registrationOpenAt(DateTime.now()) ||
        _registering != null ||
        _registered.contains(event.eventKey)) {
      return;
    }
    setState(() => _registering = event.eventKey);
    final error = await AccountService.instance.registerOfficialContest(
      eventKey: event.eventKey,
      startsAt: event.startsAt.millisecondsSinceEpoch,
      kind: event.kind.name,
      paperIndex: event.paperIndex,
    );
    // Self-heal: a failed write can still mean "you're already registered"
    // (a race with an earlier attempt, another device, or a stale local
    // cache) — re-check the real server state before showing a scary
    // sign-in error for something that isn't actually broken.
    var alreadyRegistered = false;
    if (error != null) {
      final fresh =
          await AccountService.instance.myOfficialContestRegistrations();
      alreadyRegistered = fresh?.contains(event.eventKey) ?? false;
    }
    if (!mounted) return;
    setState(() {
      _registering = null;
      if (error == null || alreadyRegistered) {
        _registered.add(event.eventKey);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error == null
              ? 'Registered for ${event.shortTitle}.'
              : alreadyRegistered
                  ? 'You were already registered for ${event.shortTitle}.'
                  : error,
        ),
      ),
    );
  }

  Future<void> _maybeAutoEnter() async {
    if (!mounted || _loading || _entryBusy) return;
    OfficialContestEvent? liveEvent;
    for (final event in _upcomingEvents) {
      if (event.phaseAt(DateTime.now()) == ContestEventPhase.live &&
          _registered.contains(event.eventKey) &&
          !_autoOpened.contains(event.eventKey) &&
          AppData.i.lastContestKey != event.eventKey) {
        liveEvent = event;
        break;
      }
    }
    if (liveEvent == null) return;
    _autoOpened.add(liveEvent.eventKey);
    await _openEvent(liveEvent, automatic: true);
  }

  Future<void> _openEvent(
    OfficialContestEvent event, {
    bool automatic = false,
  }) async {
    final phase = event.phaseAt(DateTime.now());
    final registered = _registered.contains(event.eventKey);
    if (phase == ContestEventPhase.finalStandings) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ContestLeaderboardScreen(event: event),
        ),
      );
      return;
    }
    if (phase != ContestEventPhase.live || !registered) {
      _showEventDetails(event);
      return;
    }
    if (_entryBusy) return;
    setState(() => _entryBusy = true);
    final access =
        await AccountService.instance.authorizeOfficialContest(event.eventKey);
    if (!mounted) return;
    setState(() => _entryBusy = false);
    if (!access.allowed) {
      if (automatic) _autoOpened.remove(event.eventKey);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            access.message ?? 'Could not verify your contest registration.',
          ),
        ),
      );
      return;
    }
    if (AppData.i.lastContestKey == event.eventKey) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your submission is locked. Results open at 9:45 PM.'),
        ),
      );
      return;
    }
    Navigator.of(context)
        .push<bool>(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 420),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.035),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: ContestPlayScreen(event: event),
          ),
        ),
      ),
    )
        .then((_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  void _showEventDetails(OfficialContestEvent event) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: DC.bg2,
      builder: (context) => _ContestDetailsSheet(event: event, now: _now),
    );
  }

  Widget _sectionHeader(String title, String subtitle) => Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: DC.dim, fontSize: 10, height: 1.35),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final rating = AppData.i.contestRating;
    final title = DC.contestTitle(rating);
    final upcoming = _upcomingEvents;
    final nextEvent = upcoming.firstOrNull;
    final lastContests = _lastContests;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ShaderBackground(
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _ContestTopBar(
                  onBack: () => Navigator.pop(context),
                  onInfo: () => _showRules(context),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _ContestHero(
                    rating: rating,
                    title: title,
                    nextEvent: nextEvent,
                    now: _now,
                  ),
                ),
              ),
              if (_loading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
                  sliver: SliverToBoxAdapter(
                    child: _sectionHeader(
                      'UPCOMING',
                      'Register before 9:00 PM to unlock entry.',
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  sliver: SliverList.separated(
                    itemCount: upcoming.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final event = upcoming[index];
                      return _ContestEventCard(
                        event: event,
                        now: _now,
                        registered: _registered.contains(event.eventKey),
                        registering: _registering == event.eventKey,
                        onRegister: () => _register(event),
                        onOpen: () => _openEvent(event),
                        onDetails: () => _showEventDetails(event),
                      );
                    },
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                  sliver: SliverToBoxAdapter(
                    child: _sectionHeader(
                      'LAST 3 CONTESTS',
                      'Tap one to view its final leaderboard.',
                    ),
                  ),
                ),
                if (lastContests.isEmpty)
                  const SliverToBoxAdapter(child: _NoPastContests())
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                    sliver: SliverList.separated(
                      itemCount: lastContests.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) => _PastContestCard(
                        event: lastContests[index],
                        onTap: () => _openEvent(lastContests[index]),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showRules(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: DC.bg2,
      builder: (context) => const _ContestRulesSheet(),
    );
  }
}

class _ContestTopBar extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onInfo;

  const _ContestTopBar({required this.onBack, required this.onInfo});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 82,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 20,
            child: IconButton.outlined(
              tooltip: 'Back',
              onPressed: onBack,
              constraints: const BoxConstraints.tightFor(width: 48, height: 48),
              icon: const Icon(Icons.arrow_back_rounded, size: 20),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'CONTEST',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                'WEEKEND THINKING LEAGUE',
                style: TextStyle(
                  color: DC.dim,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          Positioned(
            right: 20,
            child: IconButton(
              tooltip: 'Contest guide',
              onPressed: onInfo,
              constraints: const BoxConstraints.tightFor(width: 48, height: 48),
              icon: const Icon(Icons.help_outline_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContestHero extends StatelessWidget {
  final int rating;
  final String title;
  final OfficialContestEvent? nextEvent;
  final DateTime now;

  const _ContestHero({
    required this.rating,
    required this.title,
    required this.nextEvent,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    final accent = DC.contestColor(rating);
    final phase = nextEvent?.phaseAt(now);
    final countdown = nextEvent == null
        ? ''
        : phase == ContestEventPhase.live
            ? 'ENDS IN ${compactCountdown(nextEvent!.endsAt.difference(now))}'
            : nextEvent!.startsAt.difference(now) <= const Duration(hours: 24)
                ? 'STARTS IN ${compactCountdown(nextEvent!.startsAt.difference(now))}'
                : '${_dateLabel(nextEvent!.date)} · 9:00 PM';
    return Glass(
      radius: 30,
      padding: const EdgeInsets.all(20),
      tint: accent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 370;
          return Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(19),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          accent.withValues(alpha: 0.24),
                          DC.bg2.withValues(alpha: 0.18),
                        ],
                      ),
                      border: Border.all(color: accent.withValues(alpha: 0.35)),
                    ),
                    child: Icon(Icons.emoji_events_rounded, color: accent),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'YOUR CONTEST RATING',
                          style: TextStyle(
                            color: DC.dim,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                        Text(
                          '$rating',
                          style: Theme.of(context)
                              .textTheme
                              .displayMedium
                              ?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w900,
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                        Text(
                          title.toUpperCase(),
                          style: TextStyle(
                            color: accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!compact)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _MetricPill(
                          icon: Icons.timer_outlined,
                          label: '45 MIN',
                          color: DC.cyan,
                        ),
                        const SizedBox(height: 7),
                        _MetricPill(
                          icon: Icons.view_carousel_outlined,
                          label: '24 ROUNDS',
                          color: DC.violet,
                        ),
                      ],
                    ),
                ],
              ),
              if (nextEvent != null) ...[
                const SizedBox(height: 17),
                Container(height: 1, color: DC.fg12),
                const SizedBox(height: 13),
                Row(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: phase == ContestEventPhase.live
                            ? DC.lime
                            : DC.amber,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (phase == ContestEventPhase.live
                                    ? DC.lime
                                    : DC.amber)
                                .withValues(alpha: 0.32),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        nextEvent!.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      countdown,
                      style: TextStyle(
                        color: phase == ContestEventPhase.live
                            ? DC.lime
                            : DC.amber,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.4,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MetricPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact row for a finished contest — date, title, tap through to its
/// final leaderboard. No registration state, no insight tags.
class _PastContestCard extends StatelessWidget {
  final OfficialContestEvent event;
  final VoidCallback onTap;

  const _PastContestCard({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = event.isSunday ? DC.magenta : DC.cyan;
    return Glass(
      radius: 20,
      padding: const EdgeInsets.fromLTRB(13, 11, 15, 11),
      onTap: onTap,
      child: Row(
        children: [
          _DateTile(date: event.date, accent: accent),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              event.title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
            ),
          ),
          Icon(Icons.leaderboard_rounded, size: 18, color: accent),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, color: DC.dim),
        ],
      ),
    );
  }
}

class _ContestEventCard extends StatelessWidget {
  final OfficialContestEvent event;
  final DateTime now;
  final bool registered;
  final bool registering;
  final VoidCallback onRegister;
  final VoidCallback onOpen;
  final VoidCallback onDetails;

  const _ContestEventCard({
    required this.event,
    required this.now,
    required this.registered,
    required this.registering,
    required this.onRegister,
    required this.onOpen,
    required this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    final phase = event.phaseAt(now);
    final live = phase == ContestEventPhase.live;
    final finalBoard = phase == ContestEventPhase.finalStandings;
    final submitted = registered && AppData.i.lastContestKey == event.eventKey;
    final accent = event.isSunday ? DC.magenta : DC.cyan;
    final left = (live ? event.endsAt : event.startsAt).difference(now);
    final showCountdown = left <= const Duration(hours: 24) && !finalBoard;
    final action = _actionFor(
      phase: phase,
      registered: registered,
      submitted: submitted,
    );
    return Glass(
      radius: 27,
      padding: EdgeInsets.zero,
      tint: live ? DC.lime : accent,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(17, 17, 17, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DateTile(date: event.date, accent: accent),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 7,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            event.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          // No pill at all for the plain "not yet registered"
                          // state — only call out LIVE / FINAL / REGISTERED.
                          if (finalBoard)
                            _StatusPill(label: 'FINAL', color: DC.violet)
                          else if (live)
                            _StatusPill(label: 'LIVE', color: DC.lime)
                          else if (registered)
                            _StatusPill(label: 'REGISTERED', color: DC.cyan),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        '9:00–9:45 PM',
                        style: TextStyle(
                          color: DC.dim,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Contest details',
                  onPressed: onDetails,
                  constraints:
                      const BoxConstraints.tightFor(width: 44, height: 44),
                  icon: const Icon(Icons.more_horiz_rounded),
                ),
              ],
            ),
          ),
          Container(height: 1, color: DC.fg12),
          Padding(
            padding: const EdgeInsets.fromLTRB(17, 13, 17, 16),
            child: Column(
              children: [
                if (showCountdown) ...[
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color:
                          (live ? DC.lime : DC.amber).withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Text(
                      '${live ? 'ENDS' : 'STARTS'} IN ${compactCountdown(left)}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: live ? DC.lime : DC.amber,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 13),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: action.enabled
                        ? action.register
                            ? onRegister
                            : onOpen
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: action.color,
                      foregroundColor:
                          ThemeCtl.isDark && action.color == DC.cyan
                              ? const Color(0xFF00272E)
                              : Colors.white,
                      disabledBackgroundColor: DC.fg10,
                      disabledForegroundColor: DC.dim,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17),
                      ),
                    ),
                    icon: registering
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(action.icon, size: 19),
                    label: Text(
                      registering ? 'REGISTERING…' : action.label,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _ContestAction _actionFor({
    required ContestEventPhase phase,
    required bool registered,
    required bool submitted,
  }) {
    if (phase == ContestEventPhase.finalStandings) {
      return _ContestAction(
        label: 'VIEW FINAL STANDINGS',
        icon: Icons.leaderboard_rounded,
        color: DC.violet,
        enabled: registered,
      );
    }
    if (phase == ContestEventPhase.live) {
      if (submitted) {
        return _ContestAction(
          label: 'SUBMITTED · RESULTS AT 9:45 PM',
          icon: Icons.lock_clock_rounded,
          color: DC.dim,
          enabled: false,
        );
      }
      return _ContestAction(
        label: registered ? 'ENTER CONTEST' : 'REGISTRATION CLOSED',
        icon:
            registered ? Icons.play_arrow_rounded : Icons.lock_outline_rounded,
        color: DC.lime,
        enabled: registered,
      );
    }
    if (registered) {
      return _ContestAction(
        label: 'REGISTERED · OPENS AT 9:00 PM',
        icon: Icons.check_circle_outline_rounded,
        color: DC.cyan,
        enabled: false,
      );
    }
    return _ContestAction(
      label: 'REGISTER FOR CONTEST',
      icon: Icons.add_circle_outline_rounded,
      color: event.isSunday ? DC.magenta : DC.cyan,
      enabled: true,
      register: true,
    );
  }
}

class _ContestAction {
  final String label;
  final IconData icon;
  final Color color;
  final bool enabled;
  final bool register;

  const _ContestAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.enabled,
    this.register = false,
  });
}

class _DateTile extends StatelessWidget {
  final DateTime date;
  final Color accent;

  const _DateTile({required this.date, required this.accent});

  @override
  Widget build(BuildContext context) {
    const days = <String>['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return Container(
      width: 56,
      height: 62,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.20)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            days[date.weekday - 1],
            style: TextStyle(
              color: accent,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            '${date.day}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _NoPastContests extends StatelessWidget {
  const _NoPastContests();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 10, 28, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: DC.cyan.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(Icons.leaderboard_outlined, color: DC.cyan, size: 32),
            ),
            const SizedBox(height: 16),
            const Text(
              'No contests finished yet',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              'Play an upcoming SatCo or SunCo — its leaderboard shows up here after.',
              textAlign: TextAlign.center,
              style: TextStyle(color: DC.dim, fontSize: 11, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContestDetailsSheet extends StatelessWidget {
  final OfficialContestEvent event;
  final DateTime now;

  const _ContestDetailsSheet({required this.event, required this.now});

  @override
  Widget build(BuildContext context) {
    final accent = event.isSunday ? DC.magenta : DC.cyan;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(22),
                ),
                child:
                    Icon(Icons.emoji_events_rounded, color: accent, size: 30),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              event.title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                '${_dateLabel(event.date)} · 9:00–9:45 PM',
                style: TextStyle(color: DC.dim, fontSize: 11),
              ),
            ),
            const SizedBox(height: 22),
            const _SheetSection(
              title: 'THE PAPER',
              child: Column(
                children: [
                  _LineupRow(
                    icon: Icons.calculate_outlined,
                    title: '20 thinking problems',
                    subtitle:
                        'Math, logical IQ, mental ability, patterns and reasoning',
                  ),
                  _LineupRow(
                    icon: Icons.grid_4x4_rounded,
                    title: 'Sudoku Sprint',
                    subtitle:
                        'Unique 9×9 board designed for a sub-10-minute solve',
                  ),
                  _LineupRow(
                    icon: Icons.layers_rounded,
                    title: 'Hanoi Precision',
                    subtitle: 'Plan legal moves and transfer the full tower',
                  ),
                  _LineupRow(
                    icon: Icons.spellcheck_rounded,
                    title: 'Number Words',
                    subtitle: 'Sort numbers by their written English form',
                  ),
                  _LineupRow(
                    icon: Icons.route_rounded,
                    title: 'Signal Path · special round',
                    subtitle: 'Infer a hidden cycle and continue its path',
                    last: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SheetSection(
              title: 'FAIR PLAY',
              child: Text(
                'Every player receives Paper ${event.paperIndex + 1}. The global clock ends at 9:45 PM even if you enter late. Answers are locked after submission, and equal scores are ranked by faster completion.',
                style: TextStyle(color: DC.dim, fontSize: 11, height: 1.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContestRulesSheet extends StatelessWidget {
  const _ContestRulesSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 30),
        child: Column(
          children: [
            Icon(Icons.rule_folder_outlined, size: 46, color: DC.cyan),
            const SizedBox(height: 12),
            Text(
              'How weekly contests work',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'One registration. One shared paper. One final board.',
              textAlign: TextAlign.center,
              style: TextStyle(color: DC.dim, fontSize: 11),
            ),
            const SizedBox(height: 22),
            const _ArrowStep(
              number: '01',
              icon: Icons.how_to_reg_outlined,
              title: 'Register before 9 PM',
              message: 'Your entry stays attached to your account.',
            ),
            const _ArrowConnector(),
            const _ArrowStep(
              number: '02',
              icon: Icons.play_circle_outline_rounded,
              title: 'Enter between 9:00 and 9:45 PM',
              message:
                  'The 45-minute official clock is shared, so entering late gives less time.',
            ),
            const _ArrowConnector(),
            const _ArrowStep(
              number: '03',
              icon: Icons.leaderboard_outlined,
              title: 'Final standings unlock at 9:45 PM',
              message:
                  'Score ranks first, completion time breaks ties, and standings are paginated.',
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _SheetSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Glass(
      radius: 23,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: DC.dim,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _LineupRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool last;

  const _LineupRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: DC.cyan.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: DC.cyan),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
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

class _ArrowStep extends StatelessWidget {
  final String number;
  final IconData icon;
  final String title;
  final String message;

  const _ArrowStep({
    required this.number,
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Glass(
      radius: 22,
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: DC.cyan.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: DC.cyan),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$number  ·  $title',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: TextStyle(color: DC.dim, fontSize: 10, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ArrowConnector extends StatelessWidget {
  const _ArrowConnector();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: Center(
        child: Icon(Icons.arrow_downward_rounded, color: DC.cyan, size: 20),
      ),
    );
  }
}

/// The shared 45-minute contest runner.
class ContestPlayScreen extends StatefulWidget {
  final OfficialContestEvent event;

  const ContestPlayScreen({super.key, required this.event});

  @override
  State<ContestPlayScreen> createState() => _ContestPlayScreenState();
}

enum _RoundStatus { unanswered, solved, attempted, skipped }

class _ContestPlayScreenState extends State<ContestPlayScreen>
    with SingleTickerProviderStateMixin {
  late final ContestPaper _paper =
      officialContestPaper(widget.event.paperIndex, widget.event.kind);
  late final List<_RoundStatus> _statuses =
      List<_RoundStatus>.filled(_paper.rounds.length, _RoundStatus.unanswered);
  late final _sudokuPuzzle = contestSudoku(
    _paper.rounds.singleWhere(
      (round) => round.kind == ContestRoundKind.sudoku,
    ),
    widget.event.kind,
  );
  late final _numWordsPuzzle = contestNumWords(
    _paper.rounds.singleWhere(
      (round) => round.kind == ContestRoundKind.numWords,
    ),
    widget.event.kind,
  );
  late final _signalPathPuzzle = contestSignalPath(
    _paper.rounds.singleWhere(
      (round) => round.kind == ContestRoundKind.signalPath,
    ),
    widget.event.kind,
  );
  late final AnimationController _urgentPulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
    lowerBound: 0.25,
    upperBound: 1,
  );

  final TextEditingController _typed = TextEditingController();
  final Set<ContestRoundKind> _tutorialsShown = <ContestRoundKind>{};
  Timer? _clock;
  int _index = 0;
  int _score = 0;
  int _solved = 0;
  bool _submitting = false;
  bool _finished = false;

  ContestRound get _round => _paper.rounds[_index];

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (DateTime.now().isAfter(widget.event.endsAt)) {
        _finish();
      } else if (mounted) {
        final urgent =
            widget.event.endsAt.difference(DateTime.now()).inMinutes < 5;
        if (urgent && !_urgentPulse.isAnimating) {
          _urgentPulse.repeat(reverse: true);
        }
        setState(() {});
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (DateTime.now().isAfter(widget.event.endsAt)) {
        _finish();
      } else {
        _maybeShowTutorial();
      }
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _urgentPulse.dispose();
    _typed.dispose();
    super.dispose();
  }

  void _answerQuestion(String input) {
    if (_finished ||
        _submitting ||
        _round.kind != ContestRoundKind.question ||
        _statuses[_index] != _RoundStatus.unanswered) {
      return;
    }
    final correct = _round.question!.check(input);
    setState(() {
      _statuses[_index] =
          correct ? _RoundStatus.solved : _RoundStatus.attempted;
      if (correct) {
        _score += _round.points;
        _solved++;
      }
    });
    _advanceSoon();
  }

  void _solveGame() {
    if (_finished || _statuses[_index] != _RoundStatus.unanswered) return;
    setState(() {
      _statuses[_index] = _RoundStatus.solved;
      _score += _round.points;
      _solved++;
    });
    _advanceSoon(delay: const Duration(milliseconds: 900));
  }

  void _advanceSoon({
    Duration delay = const Duration(milliseconds: 620),
  }) {
    _submitting = true;
    Future<void>.delayed(delay, () {
      if (!mounted || _finished) return;
      _submitting = false;
      _next();
    });
  }

  void _skip() {
    if (_finished || _submitting) return;
    if (_statuses[_index] == _RoundStatus.unanswered) {
      setState(() => _statuses[_index] = _RoundStatus.skipped);
    }
    _next();
  }

  void _next() {
    if (_index >= _paper.rounds.length - 1) {
      _finish();
      return;
    }
    setState(() {
      _index++;
      _typed.clear();
    });
    _maybeShowTutorial();
  }

  /// Jump straight to any round from the question navigator — the paper
  /// doesn't have to be answered in order.
  void _jumpTo(int target) {
    if (_finished || _submitting || target == _index) return;
    if (target < 0 || target >= _paper.rounds.length) return;
    setState(() {
      _index = target;
      _typed.clear();
    });
    _maybeShowTutorial();
  }

  Future<void> _openNavigator() async {
    final target = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => _QuestionNavigatorScreen(
          rounds: _paper.rounds,
          statuses: _statuses,
          current: _index,
        ),
      ),
    );
    if (target != null) _jumpTo(target);
  }

  void _maybeShowTutorial() {
    if (!mounted ||
        _round.kind == ContestRoundKind.question ||
        _tutorialsShown.contains(_round.kind)) {
      return;
    }
    _tutorialsShown.add(_round.kind);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _finished) return;
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        backgroundColor: DC.bg2,
        builder: (context) => _RoundTutorialSheet(kind: _round.kind),
      );
    });
  }

  Future<void> _confirmFinish() async {
    if (_finished) return;
    final finish = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit contest now?'),
        content: const Text(
          'Unanswered rounds will be locked. You cannot enter this contest again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('KEEP SOLVING'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('SUBMIT'),
          ),
        ],
      ),
    );
    if (finish == true) _finish();
  }

  Future<void> _finish() async {
    if (_finished) return;
    _finished = true;
    _clock?.cancel();
    _urgentPulse.stop();

    final a = AppData.i;
    final fraction = _score / _paper.maxScore;
    final delta = (320 * (fraction - 0.52)).round().clamp(-180, 220).toInt();
    final before = a.contestRating;
    a.contestRating = (a.contestRating + delta).clamp(1000, 3200).toInt();
    a.lastContestKey = widget.event.eventKey;
    final xp = (_score / 12).round();
    final coins = _solved * 10;
    a.addXp(xp);
    a.addCoins(coins);
    a.recordMatch(
      mode: 'Contest',
      opponent: widget.event.title,
      result: delta > 0
          ? 'W'
          : delta == 0
              ? 'D'
              : 'L',
      delta: delta,
    );
    final elapsed = DateTime.now()
        .difference(widget.event.startsAt)
        .inMilliseconds
        .clamp(0, officialContestDuration.inMilliseconds)
        .toInt();
    await Future.wait<void>([
      AccountService.instance.updatePublicProfile(),
      AccountService.instance.submitOfficialContestResult(
        eventKey: widget.event.eventKey,
        score: _score,
        solved: _solved,
        elapsedMs: elapsed,
      ),
      a.save(),
    ]);
    if (!mounted) return;

    final beforeTitle = DC.contestTitle(before);
    final afterTitle = DC.contestTitle(a.contestRating);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: DC.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (delta > 0) const ConfettiBurst(height: 58),
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: (delta >= 0 ? DC.lime : DC.danger)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(23),
                ),
                child: Icon(
                  delta >= 0
                      ? Icons.trending_up_rounded
                      : Icons.trending_down_rounded,
                  color: delta >= 0 ? DC.lime : DC.danger,
                  size: 34,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Submission locked',
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(height: 6),
              Text(
                '$_solved / ${_paper.rounds.length} rounds · $_score points',
                style: TextStyle(color: DC.dim, fontSize: 11),
              ),
              const SizedBox(height: 13),
              Text(
                '${delta >= 0 ? '+' : ''}$delta  →  ${a.contestRating}',
                style: TextStyle(
                  color: delta >= 0 ? DC.lime : DC.danger,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (beforeTitle != afterTitle)
                Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Text(
                    delta > 0
                        ? 'PROMOTED · $afterTitle'
                        : 'NEW TITLE · $afterTitle',
                    style: TextStyle(
                      color: DC.contestColor(a.contestRating),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              const SizedBox(height: 7),
              Text(
                '+$xp XP · +$coins coins',
                style: TextStyle(
                  color: DC.amber,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: DC.violet.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  DateTime.now().isBefore(widget.event.endsAt)
                      ? 'Final standings unlock at 9:45 PM.'
                      : 'Final standings are now available under Last 3 Contests.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: DC.violet,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    Navigator.pop(context, true);
                  },
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(17),
                    ),
                  ),
                  child: const Text(
                    'BACK TO MY CONTESTS',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final left = widget.event.endsAt.difference(DateTime.now());
    final leftMs =
        left.inMilliseconds.clamp(0, officialContestDuration.inMilliseconds);
    final minutes = leftMs ~/ 60000;
    final seconds = (leftMs % 60000) ~/ 1000;
    final urgent = leftMs < const Duration(minutes: 5).inMilliseconds;
    return PopScope(
      canPop: _finished,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmFinish();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: ShaderBackground(
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Row(
                    children: [
                      IconButton.outlined(
                        tooltip: 'Submit and leave',
                        onPressed: _confirmFinish,
                        constraints: const BoxConstraints.tightFor(
                            width: 48, height: 48),
                        icon: const Icon(Icons.flag_outlined, size: 19),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.event.shortTitle.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'PAPER ${_paper.index + 1} · ROUND ${_index + 1}/${_paper.rounds.length}',
                              style: TextStyle(
                                color: DC.dim,
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FadeTransition(
                        opacity: urgent
                            ? _urgentPulse
                            : const AlwaysStoppedAnimation<double>(1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: (urgent ? DC.danger : DC.cyan)
                                .withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: (urgent ? DC.danger : DC.cyan)
                                  .withValues(alpha: 0.24),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.timer_outlined,
                                size: 16,
                                color: urgent ? DC.danger : DC.cyan,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  color: urgent ? DC.danger : DC.cyan,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.outlined(
                        tooltip: 'All questions',
                        onPressed: _submitting ? null : _openNavigator,
                        constraints: const BoxConstraints.tightFor(
                            width: 48, height: 48),
                        icon: const Icon(Icons.menu_rounded, size: 19),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          minHeight: 6,
                          value: (_index + 1) / _paper.rounds.length,
                          backgroundColor: DC.fg10,
                          color: _roundColor(_round.kind),
                        ),
                      ),
                      const SizedBox(height: 9),
                      Row(
                        children: [
                          _RoundKindPill(round: _round),
                          const Spacer(),
                          Text(
                            '$_score PTS  ·  $_solved SOLVED',
                            style: TextStyle(
                              color: DC.dim,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 320),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.025, 0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: Padding(
                      key: ValueKey(_index),
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                      child: _roundBody(),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                  child: Row(
                    children: [
                      TextButton.icon(
                        onPressed: _submitting ? null : _skip,
                        icon: const Icon(Icons.skip_next_rounded, size: 18),
                        label: Text(
                          _index == _paper.rounds.length - 1
                              ? 'FINISH'
                              : 'SKIP',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '+${_round.points} POINTS',
                        style: TextStyle(
                          color: _roundColor(_round.kind),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _roundBody() {
    return switch (_round.kind) {
      ContestRoundKind.question => _QuestionRound(
          round: _round,
          controller: _typed,
          locked: _statuses[_index] != _RoundStatus.unanswered || _submitting,
          status: _statuses[_index],
          onAnswer: _answerQuestion,
        ),
      ContestRoundKind.sudoku => ContestSudokuRound(
          puzzle: _sudokuPuzzle,
          onSolved: _solveGame,
        ),
      ContestRoundKind.hanoi => ContestHanoiRound(
          discs: widget.event.isSunday ? 5 : 4,
          onSolved: _solveGame,
        ),
      ContestRoundKind.numWords => ContestNumWordsRound(
          puzzle: _numWordsPuzzle,
          onSolved: _solveGame,
        ),
      ContestRoundKind.signalPath => ContestSignalPathRound(
          puzzle: _signalPathPuzzle,
          onSolved: _solveGame,
        ),
    };
  }
}

class _QuestionRound extends StatelessWidget {
  final ContestRound round;
  final TextEditingController controller;
  final bool locked;
  final _RoundStatus status;
  final ValueChanged<String> onAnswer;

  const _QuestionRound({
    required this.round,
    required this.controller,
    required this.locked,
    required this.status,
    required this.onAnswer,
  });

  Question get question => round.question!;

  @override
  Widget build(BuildContext context) {
    final solved = status == _RoundStatus.solved;
    final attempted = status == _RoundStatus.attempted;
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 8),
          Text(
            '${round.category.toUpperCase()} · ${round.rating}',
            style: TextStyle(
              color: DC.dim,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 14),
          Glass(
            radius: 27,
            padding: const EdgeInsets.all(22),
            tint: solved
                ? DC.lime
                : attempted
                    ? DC.amber
                    : null,
            child: Column(
              children: [
                Text(
                  question.prompt,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: question.prompt.length > 90
                        ? 16
                        : question.prompt.length > 55
                            ? 18
                            : 21,
                    fontWeight: FontWeight.w800,
                    height: 1.42,
                  ),
                ),
                if (locked) ...[
                  const SizedBox(height: 13),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        solved
                            ? Icons.check_circle_rounded
                            : Icons.lock_rounded,
                        size: 17,
                        color: solved ? DC.lime : DC.amber,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        solved ? 'ANSWER LOCKED' : 'ATTEMPT LOCKED',
                        style: TextStyle(
                          color: solved ? DC.lime : DC.amber,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (question.options != null)
            for (var i = 0; i < question.options!.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton(
                    onPressed:
                        locked ? null : () => onAnswer(question.options![i]),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.centerLeft,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: DC.fg10,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Text(
                            String.fromCharCode(65 + i),
                            style: TextStyle(
                              color: DC.dim,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Text(
                            question.options![i],
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 39),
                      ],
                    ),
                  ),
                ),
              )
          else ...[
            Glass(
              radius: 19,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: controller,
                enabled: !locked,
                textAlign: TextAlign.center,
                textInputAction: TextInputAction.done,
                onSubmitted: locked ? null : onAnswer,
                style: TextStyle(
                  color: DC.cyan,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Type your answer',
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: locked ? null : () => onAnswer(controller.text),
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(17),
                  ),
                ),
                child: const Text(
                  'LOCK ANSWER',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RoundKindPill extends StatelessWidget {
  final ContestRound round;

  const _RoundKindPill({required this.round});

  @override
  Widget build(BuildContext context) {
    final color = _roundColor(round.kind);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        round.title.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _RoundTutorialSheet extends StatelessWidget {
  final ContestRoundKind kind;

  const _RoundTutorialSheet({required this.kind});

  @override
  Widget build(BuildContext context) {
    final data = switch (kind) {
      ContestRoundKind.sudoku => (
          Icons.grid_4x4_rounded,
          'Sudoku Sprint',
          'Select an empty cell',
          'Choose a number 1–9',
          'Complete every row, column and box',
          DC.cyan,
        ),
      ContestRoundKind.hanoi => (
          Icons.layers_rounded,
          'Hanoi Precision',
          'Tap the source rod',
          'Tap a legal destination',
          'Move the whole tower to rod C',
          DC.violet,
        ),
      ContestRoundKind.numWords => (
          Icons.spellcheck_rounded,
          'Number Words',
          'Convert each number to a word',
          'Compare alphabetically',
          'Tap the complete sorted order',
          DC.amber,
        ),
      ContestRoundKind.signalPath => (
          Icons.route_rounded,
          'Signal Path',
          'Read the first connected values',
          'Infer the repeating + step cycle',
          'Tap adjacent values to finish',
          DC.magenta,
        ),
      ContestRoundKind.question => (
          Icons.quiz_outlined,
          'Thinking problem',
          'Read',
          'Solve',
          'Lock the answer',
          DC.cyan,
        ),
    };
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: data.$6.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(21),
              ),
              child: Icon(data.$1, color: data.$6, size: 29),
            ),
            const SizedBox(height: 13),
            Text(
              data.$2,
              style: Theme.of(context).textTheme.displayMedium,
            ),
            const SizedBox(height: 5),
            Text(
              'HOW TO SOLVE THIS ROUND',
              style: TextStyle(
                color: DC.dim,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _TutorialNode(number: '1', text: data.$3)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(Icons.arrow_forward_rounded,
                      color: data.$6, size: 19),
                ),
                Expanded(child: _TutorialNode(number: '2', text: data.$4)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(Icons.arrow_forward_rounded,
                      color: data.$6, size: 19),
                ),
                Expanded(child: _TutorialNode(number: '3', text: data.$5)),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: data.$6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(17),
                  ),
                ),
                child: const Text(
                  'START ROUND',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TutorialNode extends StatelessWidget {
  final String number;
  final String text;

  const _TutorialNode({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: DC.fg10,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            number,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(color: DC.dim, fontSize: 9, height: 1.35),
        ),
      ],
    );
  }
}

Color _roundColor(ContestRoundKind kind) => switch (kind) {
      ContestRoundKind.question => DC.cyan,
      ContestRoundKind.sudoku => DC.cyan,
      ContestRoundKind.hanoi => DC.violet,
      ContestRoundKind.numWords => DC.amber,
      ContestRoundKind.signalPath => DC.magenta,
    };

/// Full-page question palette — every round in the paper, numbered and
/// colour-coded by status, so the player can jump anywhere instead of
/// only stepping through in order. Tapping a round pops back with its
/// index; the play screen does the actual jump.
class _QuestionNavigatorScreen extends StatelessWidget {
  final List<ContestRound> rounds;
  final List<_RoundStatus> statuses;
  final int current;

  const _QuestionNavigatorScreen({
    required this.rounds,
    required this.statuses,
    required this.current,
  });

  Color _statusColor(_RoundStatus status) => switch (status) {
        _RoundStatus.solved => DC.lime,
        _RoundStatus.attempted => DC.danger,
        _RoundStatus.skipped => DC.amber,
        _RoundStatus.unanswered => DC.fg24,
      };

  IconData _statusIcon(_RoundStatus status) => switch (status) {
        _RoundStatus.solved => Icons.check_rounded,
        _RoundStatus.attempted => Icons.close_rounded,
        _RoundStatus.skipped => Icons.remove_rounded,
        _RoundStatus.unanswered => Icons.circle_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ShaderBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Row(
                  children: [
                    IconButton.outlined(
                      tooltip: 'Back',
                      onPressed: () => Navigator.pop(context),
                      constraints:
                          const BoxConstraints.tightFor(width: 48, height: 48),
                      icon: const Icon(Icons.arrow_back_rounded, size: 19),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'ALL QUESTIONS',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                          ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
                child: Wrap(
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    _LegendDot(color: DC.lime, label: 'Solved'),
                    _LegendDot(color: DC.danger, label: 'Wrong'),
                    _LegendDot(color: DC.amber, label: 'Skipped'),
                    _LegendDot(color: DC.fg24, label: 'Unanswered'),
                  ],
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1,
                  ),
                  itemCount: rounds.length,
                  itemBuilder: (context, index) {
                    final status = statuses[index];
                    final color = _statusColor(status);
                    final isCurrent = index == current;
                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => Navigator.pop(context, index),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: color.withValues(alpha: 0.10),
                          border: Border.all(
                            color: isCurrent
                                ? DC.cyan
                                : color.withValues(alpha: 0.35),
                            width: isCurrent ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: DC.text,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Icon(_statusIcon(status), size: 14, color: color),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
              color: DC.dim, fontSize: 10, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

String _dateLabel(DateTime date) {
  const months = <String>[
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

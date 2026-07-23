import 'package:flutter/material.dart';

import '../core/state.dart';
import '../engine/question.dart';
import '../services/local_coach_engine.dart';
import '../theme_district.dart';
import '../ui/coach_charts.dart';
import '../ui/glass.dart';
import 'games_hub.dart';
import 'solve_flow.dart';

/// Offline, evidence-grounded personal trainer available to every player.
class AiCoachScreen extends StatefulWidget {
  const AiCoachScreen({super.key});

  @override
  State<AiCoachScreen> createState() => _AiCoachScreenState();
}

class _AiCoachScreenState extends State<AiCoachScreen> {
  late final LocalCoachEngine _coach = LocalCoachEngine(AppData.i);
  final _question = TextEditingController();
  late CoachReply _reply = _coach.answer('');

  @override
  void initState() {
    super.initState();
    AppData.i.addListener(_onDataChanged);
  }

  @override
  void dispose() {
    AppData.i.removeListener(_onDataChanged);
    _question.dispose();
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) setState(() {});
  }

  void _ask([String? prompt]) {
    final text = (prompt ?? _question.text).trim();
    if (text.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _question.clear();
      _reply = _coach.answer(text);
    });
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _coach.snapshot();
    final plan = _coach.plan();
    final firstName = AppData.i.name.trim().split(RegExp(r'\s+')).first;
    return Scaffold(
      body: ShaderBackground(
        child: SafeArea(
          child: ListView(
            padding: _pagePadding(context),
            children: [
              const _CoachHeader(title: 'AI TRAINER', showFree: true),
              const SizedBox(height: 20),
              _hero(context, firstName, snapshot),
              const SizedBox(height: 16),
              _conversation(context),
              const SizedBox(height: 24),
              _sectionLabel('TODAY’S PERSONAL SESSION', Icons.route_rounded),
              const SizedBox(height: 10),
              for (final item in plan)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PlanCard(
                    item: item,
                    onTap: () => _openDomain(context, item.domainId),
                  ),
                ),
              if (plan.isNotEmpty) ...[
                const SizedBox(height: 2),
                NeonButton(
                  label: 'OPEN FULL TRAINING PLAN',
                  icon: Icons.play_arrow_rounded,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PersonalTrainingScreen(
                        initialFocusId: _reply.focusDomainId,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 26),
              _sectionLabel('NEURAL SKILLPRINT', Icons.hub_rounded),
              const SizedBox(height: 10),
              Glass(
                tint: DC.violet,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Six dimensions, grounded in every game you play',
                            style: TextStyle(
                              color: DC.dim,
                              fontSize: 12,
                              height: 1.45,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const GameAnalysisScreen(),
                            ),
                          ),
                          icon: const Icon(Icons.open_in_new_rounded, size: 17),
                          label: const Text('DETAILS'),
                        ),
                      ],
                    ),
                    CoachSkillRadar(
                      scores: snapshot.groupScores,
                      height:
                          MediaQuery.sizeOf(context).width < 370 ? 245 : 275,
                    ),
                    _chartSummary(snapshot),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GhostButton(
                label: 'OPEN TELEMETRY LAB',
                icon: Icons.monitor_heart_outlined,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const GameAnalysisScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hero(BuildContext context, String firstName, CoachSnapshot snapshot) {
    final accuracy = snapshot.accuracy == null
        ? 'BASELINE'
        : '${(snapshot.accuracy! * 100).round()}%';
    return Glass(
      tint: DC.cyan,
      border: Border.all(color: DC.cyan.withValues(alpha: 0.34), width: 1.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(17),
                  gradient: LinearGradient(colors: [DC.violet, DC.cyan]),
                  boxShadow: [
                    BoxShadow(
                      color: DC.cyan.withValues(alpha: 0.28),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: const Icon(Icons.psychology_alt_rounded,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'I’m with you, $firstName.',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontSize: 22),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'I learn from your choices, timing, game progress and '
                      'match form. The analysis stays on this device.',
                      style: TextStyle(
                        color: DC.dim,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetricPill(
                icon: Icons.track_changes_rounded,
                value: accuracy,
                label: 'accuracy',
                color: DC.lime,
              ),
              _MetricPill(
                icon: Icons.local_fire_department_outlined,
                value: '${snapshot.activeDays14}/14',
                label: 'active days',
                color: DC.amber,
              ),
              _MetricPill(
                icon: Icons.sports_esports_outlined,
                value: '${snapshot.wins}/${snapshot.matches}',
                label: 'match form',
                color: DC.magenta,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _conversation(BuildContext context) {
    const prompts = [
      'Build my plan',
      'How am I improving?',
      'Why do I miss?',
      'Make me faster',
    ];
    return Glass(
      tint: DC.magenta,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.forum_outlined, color: DC.magenta, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'TALK TO YOUR TRAINER',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Tooltip(
                message: 'No internet or AI model key is used',
                child:
                    Icon(Icons.offline_bolt_outlined, color: DC.lime, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            child: _CoachReplyCard(
              key: ValueKey('${_reply.title}${_reply.message}'),
              reply: _reply,
              onStart: _reply.focusDomainId == null
                  ? null
                  : () => _openDomain(context, _reply.focusDomainId!),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final prompt in prompts)
                ActionChip(
                  avatar: Icon(Icons.auto_awesome_rounded,
                      size: 16, color: DC.violet),
                  label: Text(prompt),
                  onPressed: () => _ask(prompt),
                  side: BorderSide(color: DC.fg12),
                  backgroundColor: DC.fgo(0.04),
                  labelStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _question,
            minLines: 1,
            maxLines: 3,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _ask(),
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              labelText: 'Ask your trainer',
              hintText: 'e.g. Why am I slow in probability?',
              helperText: 'Understands games, progress, mistakes and pacing',
              helperMaxLines: 2,
              filled: true,
              fillColor: DC.fgo(0.045),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: DC.fg12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(color: DC.fg12),
              ),
              suffixIcon: IconButton(
                tooltip: 'Ask trainer',
                onPressed: _ask,
                icon: const Icon(Icons.arrow_upward_rounded),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chartSummary(CoachSnapshot snapshot) {
    final strong = snapshot.strongest;
    final focus = snapshot.focus;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DC.fgo(0.045),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        strong == null
            ? 'Play one short session to light up your skillprint.'
            : 'Strongest measured signal: ${strong.label} · '
                'highest improvement value: ${focus?.label ?? strong.label}.',
        style: TextStyle(color: DC.dim, fontSize: 12, height: 1.45),
      ),
    );
  }
}

class PersonalTrainingScreen extends StatefulWidget {
  const PersonalTrainingScreen({super.key, this.initialFocusId});

  final String? initialFocusId;

  @override
  State<PersonalTrainingScreen> createState() => _PersonalTrainingScreenState();
}

class _PersonalTrainingScreenState extends State<PersonalTrainingScreen> {
  late final LocalCoachEngine _coach = LocalCoachEngine(AppData.i);
  String? _focusId;

  @override
  void initState() {
    super.initState();
    _focusId = widget.initialFocusId;
    AppData.i.addListener(_refresh);
  }

  @override
  void dispose() {
    AppData.i.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _coach.snapshot();
    final plan = _coach.plan(count: 4, focusId: _focusId);
    final minutes = plan.fold<int>(0, (sum, item) => sum + item.minutes);
    return Scaffold(
      body: ShaderBackground(
        child: SafeArea(
          child: ListView(
            padding: _pagePadding(context),
            children: [
              const _CoachHeader(title: 'PERSONAL SESSION'),
              const SizedBox(height: 18),
              Glass(
                tint: DC.cyan,
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: DC.cyan.withValues(alpha: 0.15),
                      ),
                      child:
                          Icon(Icons.route_rounded, color: DC.cyan, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$minutes-MINUTE ADAPTIVE BLOCK',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.7,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Ordered by improvement value, confidence and skill balance.',
                            style: TextStyle(
                              color: DC.dim,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _sectionLabel(
                  'YOUR COACHING BLOCKS', Icons.view_timeline_outlined),
              const SizedBox(height: 10),
              if (plan.isEmpty)
                Glass(
                  child: Column(
                    children: [
                      Icon(Icons.query_stats_rounded, color: DC.cyan, size: 34),
                      const SizedBox(height: 10),
                      const Text(
                        'I need one completed game or a few answered questions '
                        'to build an honest plan.',
                        textAlign: TextAlign.center,
                        style: TextStyle(height: 1.5),
                      ),
                      const SizedBox(height: 12),
                      NeonButton(
                        label: 'COLLECT A BASELINE',
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const GamesHubScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                for (final item in plan)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _TrainingBlock(
                      item: item,
                      selected: _focusId == item.domainId,
                      onSelect: () => setState(() => _focusId = item.domainId),
                      onStart: () => _openDomain(context, item.domainId),
                    ),
                  ),
              const SizedBox(height: 14),
              _sectionLabel('RETRIEVED MISTAKES', Icons.manage_search_rounded),
              const SizedBox(height: 10),
              if (AppData.i.mistakes.isEmpty)
                Glass(
                  child: Row(
                    children: [
                      Icon(Icons.verified_outlined, color: DC.lime),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'No saved misses yet. New wrong answers will become '
                          'private study references here.',
                          style: TextStyle(
                              color: DC.dim, fontSize: 12, height: 1.45),
                        ),
                      ),
                    ],
                  ),
                )
              else
                for (final mistake in AppData.i.mistakes.take(6))
                  _MistakeCard(mistake: mistake),
              const SizedBox(height: 22),
              Glass(
                tint: DC.violet,
                child: Text(
                  'Coach confidence improves with variety. You currently have '
                  '${snapshot.insights.where((item) => item.measured).length} '
                  'measured games or skills out of '
                  '${LocalCoachEngine.allKnownGames.length}.',
                  style: TextStyle(color: DC.dim, fontSize: 12, height: 1.5),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}

class GameAnalysisScreen extends StatefulWidget {
  const GameAnalysisScreen({super.key});

  @override
  State<GameAnalysisScreen> createState() => _GameAnalysisScreenState();
}

class _GameAnalysisScreenState extends State<GameAnalysisScreen> {
  late final LocalCoachEngine _coach = LocalCoachEngine(AppData.i);
  bool _showAll = false;

  @override
  void initState() {
    super.initState();
    AppData.i.addListener(_refresh);
  }

  @override
  void dispose() {
    AppData.i.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _coach.snapshot();
    final measured = snapshot.insights.where((item) => item.measured).toList()
      ..sort((a, b) => b.confidence.compareTo(a.confidence));
    final domains = _showAll ? snapshot.insights : measured.take(10).toList();
    return Scaffold(
      body: ShaderBackground(
        child: SafeArea(
          child: ListView(
            padding: _pagePadding(context),
            children: [
              const _CoachHeader(title: 'TELEMETRY LAB'),
              const SizedBox(height: 18),
              _telemetryMetrics(snapshot),
              const SizedBox(height: 20),
              _sectionLabel('14-DAY TRAINING PULSE', Icons.show_chart_rounded),
              const SizedBox(height: 10),
              Glass(
                tint: DC.cyan,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _LegendDot(color: DC.violet, label: 'Volume'),
                        const SizedBox(width: 14),
                        _LegendDot(color: DC.lime, label: 'Quality'),
                        const Spacer(),
                        Text(
                          snapshot.momentumPercent >= 0
                              ? '+${snapshot.momentumPercent}%'
                              : '${snapshot.momentumPercent}%',
                          style: TextStyle(
                            color: snapshot.momentumPercent >= 0
                                ? DC.lime
                                : DC.danger,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    CoachPulseChart(days: snapshot.days),
                    Text(
                      '${snapshot.activeDays14} active days · bars show session '
                      'volume; the line shows result quality when available.',
                      style:
                          TextStyle(color: DC.dim, fontSize: 11, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              _sectionLabel('COGNITIVE SKILLPRINT', Icons.hub_rounded),
              const SizedBox(height: 10),
              Glass(
                tint: DC.violet,
                child: Column(
                  children: [
                    CoachSkillRadar(scores: snapshot.groupScores),
                    const SizedBox(height: 4),
                    for (final entry in snapshot.groupScores.entries)
                      _GroupScoreRow(name: entry.key, value: entry.value),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              _sectionLabel(
                  'GAME & SKILL COVERAGE', Icons.dashboard_customize_outlined),
              const SizedBox(height: 10),
              Text(
                '${measured.length}/${snapshot.insights.length} measured. '
                'Unmeasured games are shown as baseline opportunities—not fake scores.',
                style: TextStyle(color: DC.dim, fontSize: 12, height: 1.45),
              ),
              const SizedBox(height: 10),
              for (final insight in domains)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _DomainTelemetryRow(
                    insight: insight,
                    onTap: () => _openDomain(context, insight.id),
                  ),
                ),
              const SizedBox(height: 4),
              GhostButton(
                label: _showAll ? 'SHOW MEASURED ONLY' : 'SHOW ALL GAMES',
                icon: _showAll ? Icons.filter_alt_outlined : Icons.apps_rounded,
                onPressed: () => setState(() => _showAll = !_showAll),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _telemetryMetrics(CoachSnapshot snapshot) {
    final accuracy = snapshot.accuracy;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < 420
            ? (constraints.maxWidth - 8) / 2
            : (constraints.maxWidth - 24) / 4;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            SizedBox(
              width: width,
              child: StatChip(
                label: 'ANSWERED',
                value: '${snapshot.totalAnswers}',
                color: DC.cyan,
              ),
            ),
            SizedBox(
              width: width,
              child: StatChip(
                label: 'ACCURACY',
                value: accuracy == null ? '—' : '${(accuracy * 100).round()}%',
                color: DC.lime,
              ),
            ),
            SizedBox(
              width: width,
              child: StatChip(
                label: 'FAST MISSES',
                value: '${snapshot.blunders}',
                color: DC.danger,
              ),
            ),
            SizedBox(
              width: width,
              child: StatChip(
                label: 'SLOW-RIGHT',
                value: '${snapshot.deepThinks}',
                color: DC.violet,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CoachHeader extends StatelessWidget {
  const _CoachHeader({required this.title, this.showFree = false});

  final String title;
  final bool showFree;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 48,
          height: 48,
          child: Glass(
            radius: 16,
            padding: EdgeInsets.zero,
            onTap: () => Navigator.maybePop(context),
            child: const Center(
              child: Icon(Icons.arrow_back_rounded, size: 20),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        if (showFree)
          Pill(
            icon: Icons.lock_open_rounded,
            label: 'FREE · LOCAL',
            color: DC.lime,
          ),
      ],
    );
  }
}

class _CoachReplyCard extends StatelessWidget {
  const _CoachReplyCard({
    super.key,
    required this.reply,
    required this.onStart,
  });

  final CoachReply reply;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: DC.fgo(0.045),
        border: Border.all(color: DC.magenta.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            reply.title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 7),
          Text(
            reply.message,
            style: const TextStyle(fontSize: 13, height: 1.55),
          ),
          if (reply.steps.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (var i = 0; i < reply.steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: DC.violet.withValues(alpha: 0.15),
                      ),
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          color: DC.violet,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        reply.steps[i],
                        style: const TextStyle(fontSize: 12.5, height: 1.45),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.storage_outlined, color: DC.dim, size: 14),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  reply.evidence,
                  style: TextStyle(color: DC.dim, fontSize: 10.5),
                ),
              ),
              if (onStart != null)
                TextButton.icon(
                  onPressed: onStart,
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text('START'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.item, required this.onTap});

  final CoachPlanItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Glass(
      radius: 20,
      padding: const EdgeInsets.all(14),
      tint: item.priority == 1 ? DC.cyan : DC.violet,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: (item.priority == 1 ? DC.cyan : DC.violet)
                  .withValues(alpha: 0.14),
            ),
            child: Text(
              '${item.priority}',
              style: TextStyle(
                color: item.priority == 1 ? DC.cyan : DC.violet,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.minutes} MIN · ${item.title.toUpperCase()}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.reason,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: DC.dim, fontSize: 11.5, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right_rounded, color: DC.dim),
        ],
      ),
    );
  }
}

class _TrainingBlock extends StatelessWidget {
  const _TrainingBlock({
    required this.item,
    required this.selected,
    required this.onSelect,
    required this.onStart,
  });

  final CoachPlanItem item;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Glass(
      tint: selected ? DC.cyan : DC.violet,
      border: Border.all(
        color: selected ? DC.cyan : DC.fg12,
        width: selected ? 1.5 : 1,
      ),
      onTap: onSelect,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: DC.violet.withValues(alpha: 0.14),
                ),
                child: Text(
                  '${item.priority}',
                  style: TextStyle(
                    color: DC.violet,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                '${item.minutes} MIN',
                style: TextStyle(
                  color: DC.cyan,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(item.reason,
              style: TextStyle(color: DC.dim, fontSize: 12, height: 1.45)),
          const SizedBox(height: 8),
          Text(item.drill, style: const TextStyle(fontSize: 13, height: 1.5)),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: NeonButton(
              label: 'START THIS BLOCK',
              icon: Icons.play_arrow_rounded,
              height: 46,
              onPressed: onStart,
            ),
          ),
        ],
      ),
    );
  }
}

class _MistakeCard extends StatelessWidget {
  const _MistakeCard({required this.mistake});

  final Map<String, dynamic> mistake;

  @override
  Widget build(BuildContext context) {
    final id = '${mistake['cat']}';
    final label = _labelFor(id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Glass(
        radius: 18,
        tint: DC.danger,
        padding: const EdgeInsets.all(14),
        onTap: () => _openDomain(context, id),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline_rounded, color: DC.danger, size: 20),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${mistake['prompt']}'.split('\n').first,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, height: 1.4),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '$label · answer ${mistake['answer']} · ${mistake['date']}',
                    style: TextStyle(
                      color: DC.lime,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DomainTelemetryRow extends StatelessWidget {
  const _DomainTelemetryRow({
    required this.insight,
    required this.onTap,
  });

  final CoachDomainInsight insight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = !insight.measured
        ? DC.dim
        : insight.score >= 0.8
            ? DC.lime
            : insight.score >= 0.6
                ? DC.amber
                : DC.danger;
    return Glass(
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_iconFor(insight.id), color: color, size: 19),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  insight.label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                insight.measured ? '${insight.scorePercent}' : 'BASELINE',
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: insight.measured ? insight.score : 0,
              minHeight: 7,
              backgroundColor: DC.fg10,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${insight.group} · ${insight.evidence}',
            style: TextStyle(color: DC.dim, fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}

class _GroupScoreRow extends StatelessWidget {
  const _GroupScoreRow({required this.name, required this.value});

  final String name;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              name,
              style: TextStyle(color: DC.dim, fontSize: 11),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 6,
                backgroundColor: DC.fg10,
                color: value == 0 ? DC.fg24 : DC.cyan,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 32,
            child: Text(
              value == 0 ? '—' : '${(value * 100).round()}',
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: color.withValues(alpha: 0.09),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 7),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: DC.dim, fontSize: 10.5)),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

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
        Text(label, style: TextStyle(color: DC.dim, fontSize: 10.5)),
      ],
    );
  }
}

Widget _sectionLabel(String text, IconData icon) {
  return Row(
    children: [
      Icon(icon, color: DC.cyan, size: 17),
      const SizedBox(width: 7),
      Text(
        text,
        style: TextStyle(
          color: DC.dim,
          fontSize: 10.5,
          letterSpacing: 1.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );
}

EdgeInsets _pagePadding(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  final horizontal = width >= 900
      ? (width - 760) / 2
      : width >= 600
          ? 32.0
          : 20.0;
  return EdgeInsets.fromLTRB(horizontal, 16, horizontal, 28);
}

Future<void> _openDomain(BuildContext context, String id) async {
  Cat? cat;
  for (final candidate in cats) {
    if (candidate.id == id) {
      cat = candidate;
      break;
    }
  }
  if (cat != null && cat.ready) {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LevelMapScreen(cat: cat!)),
    );
    return;
  }
  await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const GamesHubScreen()),
  );
}

String _labelFor(String id) {
  for (final cat in cats) {
    if (cat.id == id) return cat.name;
  }
  return id.replaceAll('_', ' ').toUpperCase();
}

IconData _iconFor(String id) => switch (id) {
      'mental' || 'reflex' => Icons.bolt_rounded,
      'quant' || 'finance' => Icons.trending_up_rounded,
      'numtheory' || 'numpz' => Icons.numbers_rounded,
      'patterns' || 'setgame' => Icons.auto_awesome_rounded,
      'geometry' || 'sliding' || 'arrow' => Icons.change_history_rounded,
      'probability' => Icons.casino_outlined,
      'clock' => Icons.schedule_rounded,
      'knights' || 'logicgrid' || 'river' => Icons.account_tree_rounded,
      'sudoku' || 'kenken' || 'kakuro' => Icons.grid_on_rounded,
      'mines' => Icons.flag_outlined,
      'hanoi' => Icons.layers_rounded,
      'memory' || 'art' => Icons.visibility_outlined,
      'nonogram' => Icons.blur_on_rounded,
      'crypta' => Icons.password_rounded,
      'words' || 'crossword' || 'wordfind' => Icons.menu_book_rounded,
      'chess' || 'chess_iq' => Icons.extension_rounded,
      'darts' => Icons.adjust_rounded,
      'cube' => Icons.view_in_ar_rounded,
      'scribble' => Icons.draw_outlined,
      'contest' || 'arena' => Icons.emoji_events_outlined,
      _ => Icons.sports_esports_outlined,
    };

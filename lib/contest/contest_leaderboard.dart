import 'package:flutter/material.dart';

import '../core/state.dart';
import '../services/account_service.dart';
import '../theme_district.dart';
import '../ui/glass.dart';
import 'contest_bank.dart';

class ContestLeaderboardScreen extends StatefulWidget {
  final OfficialContestEvent event;

  const ContestLeaderboardScreen({super.key, required this.event});

  @override
  State<ContestLeaderboardScreen> createState() =>
      _ContestLeaderboardScreenState();
}

class _ContestLeaderboardScreenState extends State<ContestLeaderboardScreen> {
  static const _pageSize = 10;

  List<Map<String, dynamic>>? _rows;
  bool _loading = true;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final rows = await AccountService.instance
        .fetchOfficialContestResults(widget.event.eventKey);
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _loading = false;
      final pages = _pageCount(rows?.length ?? 0);
      if (_page >= pages) _page = pages - 1;
      if (_page < 0) _page = 0;
    });
  }

  int _pageCount(int count) => count == 0 ? 1 : (count / _pageSize).ceil();

  @override
  Widget build(BuildContext context) {
    final rows = _rows ?? const <Map<String, dynamic>>[];
    final pages = _pageCount(rows.length);
    final start = _page * _pageSize;
    final visible = rows.skip(start).take(_pageSize).toList();
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ShaderBackground(
        child: SafeArea(
          child: Column(
            children: [
              _Header(
                title: widget.event.title,
                subtitle:
                    'FINAL STANDINGS · PAPER ${widget.event.paperIndex + 1}',
                onBack: () => Navigator.pop(context),
                onRefresh: _loading ? null : _load,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                child: Glass(
                  radius: 24,
                  tint: DC.amber,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: DC.amber.withValues(alpha: 0.13),
                          borderRadius: BorderRadius.circular(17),
                        ),
                        child:
                            Icon(Icons.emoji_events_rounded, color: DC.amber),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'SCORE → SPEED → RANK',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.6,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Equal scores are ordered by the faster official submission.',
                              style: TextStyle(
                                color: DC.dim,
                                fontSize: 10,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  child: _loading
                      ? const Center(
                          key: ValueKey('loading'),
                          child: CircularProgressIndicator(),
                        )
                      : _rows == null
                          ? _EmptyBoard(
                              key: const ValueKey('offline'),
                              icon: Icons.cloud_off_outlined,
                              title: 'Standings unavailable',
                              message:
                                  'Check your connection and refresh the final board.',
                              retry: _load,
                            )
                          : rows.isEmpty
                              ? const _EmptyBoard(
                                  key: ValueKey('empty'),
                                  icon: Icons.leaderboard_outlined,
                                  title: 'No submitted scores',
                                  message:
                                      'Final submissions will appear here in rank order.',
                                )
                              : ListView.separated(
                                  key: ValueKey('page-$_page'),
                                  padding:
                                      const EdgeInsets.fromLTRB(20, 0, 20, 18),
                                  itemCount: visible.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    final rank = start + index + 1;
                                    return _RankRow(
                                      rank: rank,
                                      row: visible[index],
                                    );
                                  },
                                ),
                ),
              ),
              if (!_loading && rows.isNotEmpty)
                _PageBar(
                  page: _page,
                  pages: pages,
                  total: rows.length,
                  onPage: (page) => setState(() => _page = page),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final VoidCallback? onRefresh;

  const _Header({
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.onRefresh,
  });

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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 82),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: DC.dim,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 20,
            child: IconButton(
              tooltip: 'Refresh standings',
              onPressed: onRefresh,
              constraints: const BoxConstraints.tightFor(width: 48, height: 48),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  final int rank;
  final Map<String, dynamic> row;

  const _RankRow({required this.rank, required this.row});

  @override
  Widget build(BuildContext context) {
    final username = '${row['user'] ?? ''}';
    final mine = username == AppData.i.username;
    final score = (row['score'] as num?)?.toInt() ?? 0;
    final solved = (row['solved'] as num?)?.toInt() ?? 0;
    final elapsed = (row['elapsedMs'] as num?)?.toInt() ?? 2700000;
    final medal = rank <= 3
        ? <Color>[DC.amber, DC.dim, const Color(0xFFB87333)][rank - 1]
        : null;
    return Glass(
      radius: 19,
      tint: mine ? DC.cyan : medal,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            height: 42,
            child: medal == null
                ? Center(
                    child: Text(
                      '#$rank',
                      style: TextStyle(
                        color: DC.dim,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  )
                : Icon(Icons.workspace_premium_rounded, color: medal, size: 28),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '@$username${mine ? '  YOU' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: mine ? FontWeight.w900 : FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$solved rounds · ${_clock(elapsed)}',
                  style: TextStyle(color: DC.dim, fontSize: 10),
                ),
              ],
            ),
          ),
          Text(
            '$score',
            style: TextStyle(
              color: mine ? DC.cyan : DC.text,
              fontSize: 17,
              fontWeight: FontWeight.w900,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  static String _clock(int millis) {
    final total = (millis / 1000).round().clamp(0, 359999);
    final minutes = total ~/ 60;
    final seconds = total % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class _PageBar extends StatelessWidget {
  final int page;
  final int pages;
  final int total;
  final ValueChanged<int> onPage;

  const _PageBar({
    required this.page,
    required this.pages,
    required this.total,
    required this.onPage,
  });

  @override
  Widget build(BuildContext context) {
    final first = page * 10 + 1;
    final last = (first + 9).clamp(1, total);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Glass(
          radius: 20,
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Previous page',
                onPressed: page == 0 ? null : () => onPage(page - 1),
                constraints:
                    const BoxConstraints.tightFor(width: 48, height: 48),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'PAGE ${page + 1} OF $pages',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ranks $first–$last of $total',
                      style: TextStyle(color: DC.dim, fontSize: 9),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Next page',
                onPressed: page >= pages - 1 ? null : () => onPage(page + 1),
                constraints:
                    const BoxConstraints.tightFor(width: 48, height: 48),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyBoard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? retry;

  const _EmptyBoard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.retry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 46, color: DC.dim),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: DC.dim, fontSize: 11, height: 1.45),
            ),
            if (retry != null) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: retry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('TRY AGAIN'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

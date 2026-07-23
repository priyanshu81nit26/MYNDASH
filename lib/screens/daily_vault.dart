import 'package:flutter/material.dart';

import '../core/state.dart';
import '../daily_challenge/daily_bank.dart';
import '../daily_challenge/daily_game_screen.dart';
import '../engine/rating_catalog.dart';
import '../theme_district.dart';
import '../ui/glass.dart';

/// Completed Daily problems become permanent practice here, grouped by their
/// real game/category and the same 800–2500 rating language as the rest of
/// MYNDASH. Replays never pay rewards again.
class DailyVaultScreen extends StatefulWidget {
  const DailyVaultScreen({super.key});

  @override
  State<DailyVaultScreen> createState() => _DailyVaultScreenState();
}

class _DailyVaultScreenState extends State<DailyVaultScreen> {
  int? rating;

  @override
  Widget build(BuildContext context) {
    final records = [...AppData.i.dailyArchive]..sort((a, b) =>
        ((b['completedAt'] as num?)?.toInt() ?? 0)
            .compareTo((a['completedAt'] as num?)?.toInt() ?? 0));
    final visible = rating == null
        ? records
        : records.where((e) => e['rating'] == rating).toList();
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final record in visible) {
      grouped.putIfAbsent('${record['category']}', () => []).add(record);
    }

    return Scaffold(
      body: ShaderBackground(
        child: SafeArea(
          child: CustomScrollView(slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              sliver: SliverToBoxAdapter(
                child: Row(children: [
                  Glass(
                    radius: 16,
                    padding: const EdgeInsets.all(8),
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_rounded, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('DAILY VAULT',
                            style: Theme.of(context).textTheme.titleLarge),
                        Text(
                            '${records.length} completed problems · replayable',
                            style: TextStyle(fontSize: 11, color: DC.dim)),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 48,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  children: [
                    _filterChip(null, 'ALL'),
                    for (final band in RatingCatalog.bands)
                      _filterChip(band, '$band'),
                  ],
                ),
              ),
            ),
            if (visible.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      records.isEmpty
                          ? 'Complete a Daily Arena event and it will appear here under its game and rating.'
                          : 'No archived problem at this rating yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: DC.dim),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    for (final entry in grouped.entries) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
                        child: Text(
                          _categoryLabel(entry.key).toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            color: DC.dim,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ),
                      for (final record in entry.value) _recordCard(record),
                    ],
                  ]),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _filterChip(int? value, String label) {
    final selected = rating == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8, top: 6, bottom: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => rating = value),
        selectedColor: DC.cyan.withOpacity(0.22),
        side: BorderSide(color: selected ? DC.cyan : DC.fg12),
      ),
    );
  }

  Widget _recordCard(Map<String, dynamic> record) {
    final item = dailyChallengeItemForArchive(record);
    final value = (record['rating'] as num?)?.toInt() ?? item.rating;
    final dayNumber = ((record['day'] as num?)?.toInt() ?? 0) + 1;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Glass(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DailyGameScreen(item: item, replay: true),
          ),
        ),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: DC.band(value).withOpacity(0.14),
            ),
            alignment: Alignment.center,
            child: Text(
              '$value',
              style: TextStyle(
                color: DC.band(value),
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    style: const TextStyle(fontWeight: FontWeight.w900)),
                Text('Daily day $dayNumber',
                    style: TextStyle(fontSize: 11, color: DC.dim)),
              ],
            ),
          ),
          Icon(Icons.replay_rounded, color: DC.cyan),
        ]),
      ),
    );
  }

  String _categoryLabel(String id) => switch (id) {
        'numpz' => 'Number Puzzle',
        'art' => 'Art Heist',
        'crossmath' => 'Cross Math',
        'numtheory' => 'Number Theory',
        _ => id.replaceAll('-', ' '),
      };
}

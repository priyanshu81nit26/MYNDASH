import 'package:flutter/material.dart';

import '../core/state.dart';
import '../daily_challenge/daily_bank.dart';
import '../daily_challenge/daily_game_screen.dart';
import '../daily_challenge/daily_models.dart';
import '../theme_district.dart';
import '../ui/extras.dart';
import '../ui/glass.dart';

/// The new Daily Arena:
///   • five progressively locked maths questions;
///   • six independent games that are always available;
///   • one transparent cumulative XP/coin pool;
///   • every clear copied into the rating-tagged Daily Vault.
class Daily5Screen extends StatefulWidget {
  const Daily5Screen({super.key});

  @override
  State<Daily5Screen> createState() => _Daily5ScreenState();
}

class _Daily5ScreenState extends State<Daily5Screen> {
  final a = AppData.i;

  late final int dayIndex = dailyChallengeDayIndex();
  late final DailyChallengeDay day = dailyChallengeDay(dayIndex);

  void _open(DailyChallengeItem item) {
    final mathIndex =
        item.isMath ? int.tryParse(item.id.substring('math-'.length)) ?? 0 : -1;
    final locked = item.isMath && mathIndex > a.dailyMathProgress;
    if (locked) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DailyGameScreen(
          item: item,
          onSolved: () => a.recordDailyItem(
            id: item.id,
            category: item.category,
            rating: item.rating,
            xpReward: item.xp,
            coinReward: item.coins,
            dayIndex: dayIndex,
          ),
        ),
      ),
    ).then((_) => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final earnedXp = day.all
        .where((item) => a.dailyItemDone(item.id))
        .fold(0, (sum, item) => sum + item.xp);
    final earnedCoins = day.all
        .where((item) => a.dailyItemDone(item.id))
        .fold(0, (sum, item) => sum + item.coins);

    return Scaffold(
      body: ShaderBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
            children: [
              Row(children: [
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
                      Text('DAILY ARENA',
                          style: Theme.of(context).textTheme.titleLarge),
                      Text('Day ${dayIndex + 1} of $dailyChallengeDayCount',
                          style: TextStyle(fontSize: 11, color: DC.dim)),
                    ],
                  ),
                ),
                Pill(
                  icon: Icons.local_fire_department_rounded,
                  label: '${a.streak}',
                  color: DC.amber,
                ),
              ]),
              const SizedBox(height: 16),
              _rewardBoard(earnedXp, earnedCoins),
              const SizedBox(height: 22),
              _sectionTitle(
                'MATH LADDER',
                'Only these five lock progressively',
                Icons.functions_rounded,
              ),
              const SizedBox(height: 10),
              for (var i = 0; i < day.math.length; i++)
                _itemCard(day.math[i], mathIndex: i),
              const SizedBox(height: 18),
              _sectionTitle(
                'OPEN GAMES',
                'Play in any order · ratings shuffle daily',
                Icons.grid_view_rounded,
              ),
              const SizedBox(height: 10),
              for (final item in day.games) _itemCard(item),
              if (a.dailyDone) ...[
                const SizedBox(height: 14),
                Glass(
                  tint: DC.lime,
                  child: Column(children: [
                    const ConfettiBurst(height: 64),
                    Icon(Icons.emoji_events_rounded, size: 44, color: DC.amber),
                    const SizedBox(height: 6),
                    Text('Daily Arena cleared',
                        style: Theme.of(context).textTheme.titleLarge),
                    Text(
                      'All 11 saved to your rating-tagged Daily Vault.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: DC.dim),
                    ),
                  ]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _rewardBoard(int earnedXp, int earnedCoins) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            DC.violet.withOpacity(0.34),
            DC.cyan.withOpacity(0.18),
            DC.fgo(0.04),
          ],
        ),
        border: Border.all(color: DC.cyan.withOpacity(0.38)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.bolt_rounded, color: DC.cyan),
          const SizedBox(width: 8),
          const Text(
            'TODAY’S TOTAL POOL',
            style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2),
          ),
          const Spacer(),
          Text('${a.dailyProgress}/11',
              style: TextStyle(
                  color: DC.cyan, fontWeight: FontWeight.w900, fontSize: 16)),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: _rewardStat(
              Icons.auto_awesome_rounded,
              '$earnedXp / ${day.totalXp}',
              'XP earned',
              DC.violet,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _rewardStat(
              Icons.monetization_on_rounded,
              '$earnedCoins / ${day.totalCoins}',
              'coins earned',
              DC.amber,
            ),
          ),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: a.dailyProgress / 11,
            minHeight: 8,
            backgroundColor: DC.fg10,
            color: DC.lime,
          ),
        ),
      ]),
    );
  }

  Widget _rewardStat(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: color.withOpacity(0.10),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  maxLines: 1,
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 16)),
              Text(label, style: TextStyle(fontSize: 10, color: DC.dim)),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _sectionTitle(String title, String subtitle, IconData icon) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          color: DC.cyan.withOpacity(0.12),
        ),
        child: Icon(icon, color: DC.cyan, size: 21),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1)),
            Text(subtitle, style: TextStyle(fontSize: 11, color: DC.dim)),
          ],
        ),
      ),
    ]);
  }

  Widget _itemCard(DailyChallengeItem item, {int? mathIndex}) {
    final solved = a.dailyItemDone(item.id);
    final locked =
        mathIndex != null && mathIndex > a.dailyMathProgress && !solved;
    final active = !locked &&
        !solved &&
        (mathIndex == null || mathIndex == a.dailyMathProgress);
    final icon = switch (item.type) {
      DailyItemType.math => Icons.functions_rounded,
      DailyItemType.sudoku => Icons.grid_4x4_rounded,
      DailyItemType.artHeist => Icons.palette_outlined,
      DailyItemType.crossword => Icons.text_fields_rounded,
      DailyItemType.numberPuzzle => Icons.apps_rounded,
      DailyItemType.kenKen => Icons.calculate_outlined,
      DailyItemType.crossMath => Icons.add_box_outlined,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Glass(
        onTap: locked ? null : () => _open(item),
        tint: solved ? DC.lime : (active ? DC.cyan : null),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: solved
                  ? DC.lime.withOpacity(0.16)
                  : locked
                      ? DC.fgo(0.05)
                      : DC.cyan.withOpacity(0.12),
            ),
            child: Icon(
              solved
                  ? Icons.check_rounded
                  : locked
                      ? Icons.lock_rounded
                      : icon,
              color: solved
                  ? DC.lime
                  : locked
                      ? DC.dim
                      : DC.cyan,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: locked ? DC.dim : DC.text,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: DC.band(item.rating).withOpacity(0.14),
                    ),
                    child: Text(
                      '${item.rating}',
                      style: TextStyle(
                        fontSize: 10,
                        color: DC.band(item.rating),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 3),
                Text(
                  locked ? 'Clear Math $mathIndex first' : item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: DC.dim),
                ),
                const SizedBox(height: 5),
                Text(
                  '+${item.xp} XP · +${item.coins} coins',
                  style: TextStyle(
                    fontSize: 10,
                    color: solved ? DC.lime : DC.amber,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            solved ? Icons.archive_outlined : Icons.chevron_right_rounded,
            size: 19,
            color: solved ? DC.lime : DC.dim,
          ),
        ]),
      ),
    );
  }
}

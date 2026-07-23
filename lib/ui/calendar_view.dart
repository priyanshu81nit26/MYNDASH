import 'package:flutter/material.dart';

import '../core/state.dart';
import '../theme_district.dart';
import 'glass.dart';

/// ============================================================
/// PROFILE CALENDAR — month view with dot markers:
///   🟣 contests (every Sat & Sun) · 🔴 live drops (daily)
///   🔵 your reminders / scheduled matches (persisted locally)
/// Tap a day → see its agenda + add a reminder.
/// ============================================================
class ProfileCalendar extends StatefulWidget {
  const ProfileCalendar({super.key});

  @override
  State<ProfileCalendar> createState() => _ProfileCalendarState();
}

class _ProfileCalendarState extends State<ProfileCalendar> {
  late DateTime month; // first day of the shown month
  DateTime? selected;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    month = DateTime(n.year, n.month);
    selected = DateTime(n.year, n.month, n.day);
  }

  static String key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final a = AppData.i;
    final firstWeekday = month.weekday % 7; // Sun = 0
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final today = DateTime.now();
    const monthNames = [
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
      'DEC'
    ];

    return Glass(
      radius: 24,
      child: Column(children: [
        Row(children: [
          const Text('🗓', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          const Text('CALENDAR',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2)),
          const Spacer(),
          GestureDetector(
            onTap: () =>
                setState(() => month = DateTime(month.year, month.month - 1)),
            child: Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.chevron_left, size: 20, color: DC.dim),
            ),
          ),
          Text('${monthNames[month.month - 1]} ${month.year}',
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          GestureDetector(
            onTap: () =>
                setState(() => month = DateTime(month.year, month.month + 1)),
            child: Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.chevron_right, size: 20, color: DC.dim),
            ),
          ),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          for (final d in ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
            Expanded(
              child: Center(
                child: Text(d,
                    style: TextStyle(
                        fontSize: 10,
                        color: DC.dim,
                        fontWeight: FontWeight.w700)),
              ),
            ),
        ]),
        const SizedBox(height: 4),
        // day grid
        for (var row = 0; row < ((firstWeekday + daysInMonth + 6) ~/ 7); row++)
          Row(children: [
            for (var col = 0; col < 7; col++)
              Expanded(
                  child: _dayCell(
                      row * 7 + col - firstWeekday + 1, daysInMonth, today, a)),
          ]),
        const SizedBox(height: 8),
        // legend
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _Legend(color: DC.violet, label: 'contest'),
          SizedBox(width: 10),
          _Legend(color: DC.danger, label: 'live drop'),
          SizedBox(width: 10),
          _Legend(color: DC.cyan, label: 'yours'),
        ]),
        if (selected != null) ...[
          Divider(color: DC.fg12, height: 20),
          _agenda(a),
        ],
      ]),
    );
  }

  Widget _dayCell(int day, int daysInMonth, DateTime today, AppData a) {
    if (day < 1 || day > daysInMonth) return const SizedBox(height: 38);
    final date = DateTime(month.year, month.month, day);
    final isToday = date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
    final isSel = selected != null &&
        date.year == selected!.year &&
        date.month == selected!.month &&
        date.day == selected!.day;
    final isWeekend =
        date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
    final mine = a.notesOn(key(date)).isNotEmpty;
    return GestureDetector(
      onTap: () => setState(() => selected = date),
      child: Container(
        height: 38,
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: isSel
              ? DC.cyan.withOpacity(0.25)
              : isToday
                  ? DC.fgo(0.08)
                  : null,
          border: isToday ? Border.all(color: DC.cyan, width: 1) : null,
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('$day',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: isToday ? FontWeight.w900 : FontWeight.w600)),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (isWeekend) _dot(DC.violet),
            _dot(DC.danger),
            if (mine) _dot(DC.cyan),
          ]),
        ]),
      ),
    );
  }

  Widget _dot(Color c) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 1),
        width: 4,
        height: 4,
        decoration: BoxDecoration(shape: BoxShape.circle, color: c),
      );

  Widget _agenda(AppData a) {
    final d = selected!;
    final k = key(d);
    final isWeekend =
        d.weekday == DateTime.saturday || d.weekday == DateTime.sunday;
    final mine = a.notesOn(k);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('${d.day}/${d.month}',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
        const Spacer(),
        GestureDetector(
          onTap: _addReminder,
          child: Row(children: [
            Icon(Icons.add_circle_outline, size: 16, color: DC.cyan),
            SizedBox(width: 4),
            Text('add reminder',
                style: TextStyle(fontSize: 11, color: DC.cyan)),
          ]),
        ),
      ]),
      const SizedBox(height: 6),
      if (isWeekend)
        Text('🏆 Rated contest · Blitz & Classic windows',
            style: TextStyle(fontSize: 12, color: DC.violet)),
      Text('⚡ Live Drops · 13:00 & 21:00',
          style: TextStyle(fontSize: 12, color: DC.danger)),
      for (final n in mine)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(children: [
            Text(
                n['type'] == 'match'
                    ? '⚔️'
                    : n['type'] == 'event'
                        ? '🏟'
                        : '🔔',
                style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 6),
            Expanded(
              child: Text('${n['title']}',
                  style: TextStyle(fontSize: 12, color: DC.cyan)),
            ),
            GestureDetector(
              onTap: () => setState(() => a.removeCalendarNote(n)),
              child: Icon(Icons.close, size: 14, color: DC.fg38),
            ),
          ]),
        ),
      if (mine.isEmpty)
        Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text('No personal plans on this day.',
              style: TextStyle(fontSize: 11, color: DC.dim)),
        ),
    ]);
  }

  Future<void> _addReminder() async {
    final c = TextEditingController();
    var type = 'reminder';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: DC.bg2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('Plan for ${selected!.day}/${selected!.month}'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: c,
                autofocus: true,
                maxLength: 40,
                decoration: const InputDecoration(
                    hintText: 'e.g. Rematch @kaffota 8 pm', counterText: '')),
            const SizedBox(height: 8),
            Row(children: [
              for (final (t, label) in [
                ('reminder', '🔔 reminder'),
                ('match', '⚔️ match'),
                ('event', '🏟 event')
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(label, style: const TextStyle(fontSize: 11)),
                    selected: type == t,
                    onSelected: (_) => setD(() => type = t),
                  ),
                ),
            ]),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save')),
          ],
        ),
      ),
    );
    if (ok == true && c.text.trim().isNotEmpty) {
      AppData.i.addCalendarNote(key(selected!), c.text.trim(), type);
      setState(() {});
    }
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 10, color: DC.dim)),
    ]);
  }
}

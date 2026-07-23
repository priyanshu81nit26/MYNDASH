enum EventPhase { upcoming, live, completed }

/// Public and private hosted arenas share the same two-minute, server-timed
/// check-in lobby. Registration closes exactly when [startsAt] is reached;
/// the challenge itself opens when this lobby ends.
const Duration arenaLobbyDuration = Duration(minutes: 2);

String eventDateKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

DateTime mondayOf(DateTime date) {
  final localDay = DateTime(date.year, date.month, date.day);
  return localDay.subtract(Duration(days: localDay.weekday - DateTime.monday));
}

DateTime officialArenaStart(DateTime date) =>
    DateTime(date.year, date.month, date.day, 22);

/// Returns a clean hourly organizer slot. At 15:12 the first slot is 16:00;
/// [additionalHours] then offers 17:00, 18:00, and so on.
DateTime nextHourlyArenaSlot(
  DateTime now, {
  int additionalHours = 0,
}) =>
    DateTime(now.year, now.month, now.day, now.hour + 1 + additionalHours);

bool arenaRegistrationOpen(DateTime now, DateTime startsAt) =>
    now.isBefore(startsAt);

DateTime arenaQuestionsOpenAt(DateTime startsAt) =>
    startsAt.add(arenaLobbyDuration);

DateTime arenaEndsAt(DateTime startsAt, Duration gameDuration) =>
    arenaQuestionsOpenAt(startsAt).add(gameDuration);

EventPhase eventPhase(
  DateTime now,
  DateTime start, {
  required Duration duration,
}) {
  if (now.isBefore(start)) return EventPhase.upcoming;
  if (now.isBefore(start.add(duration))) return EventPhase.live;
  return EventPhase.completed;
}

String compactCountdown(Duration duration) {
  final safe = duration.isNegative ? Duration.zero : duration;
  final hours = safe.inHours.toString().padLeft(2, '0');
  final minutes = (safe.inMinutes % 60).toString().padLeft(2, '0');
  final seconds = (safe.inSeconds % 60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}

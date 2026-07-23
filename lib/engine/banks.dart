import 'dart:math';

import 'generators.dart';
import 'kid_generators.dart';
import 'question.dart';

/// ============================================================
/// GLOBAL QUESTION BANKS — 100 days of Daily-5 (500 questions),
/// 100 days of Live Drops, 20 weekend contests, plus the kids'
/// 8pm drop & weekend contest. Every question is derived from a
/// FIXED seed, so the whole world sees the identical bank — and
/// expired days fold back into the Solve section at their rating level.
/// The admin device also mirrors the bank to /banks in RTDB.
/// ============================================================

/// Day 0 of the bank era.
final bankEpoch = DateTime(2026, 7, 1);

int bankDayIndex([DateTime? when]) {
  final d = when ?? DateTime.now();
  return DateTime(d.year, d.month, d.day).difference(bankEpoch).inDays;
}

const _dailyCats = [
  'mental',
  'quant',
  'numtheory',
  'patterns',
  'geometry',
  'probability',
  'clock',
  'words',
  'knights',
  'crypta',
];
const _dropCats = [
  'mental',
  'patterns',
  'quant',
  'numtheory',
  'geometry',
  'probability',
];
const _contestCats = [
  'mental',
  'quant',
  'numtheory',
  'patterns',
  'geometry',
  'probability',
  'clock',
  'words',
  'knights',
];
const _kidCatCycle = [
  'counting',
  'addsub',
  'patterns',
  'compare',
  'shapes',
  'missing',
  'evenodd',
  'skipcount',
  'oddone',
  'tables',
];

String bankDailyCat(int day, int slot) =>
    _dailyCats[(day * 5 + slot * 3) % _dailyCats.length];

/// Daily-5: slot 0..4, difficulty ramps 900 → 1900 over the slots.
Question bankDaily(int day, int slot) {
  final rng = Random(0xDA117 * (day * 5 + slot) + 977);
  final rating = (900 + slot * 250).clamp(800, 2500).toInt();
  return generate(bankDailyCat(day, slot), rating, rng);
}

String bankDropCat(int day, int i) => _dropCats[(day + i) % _dropCats.length];

/// Live-drop set for a day (adults): 8 rapid questions ~1400 rated.
Question bankDrop(int day, int i) {
  final rng = Random(0xD809 * (day * 8 + i) + 431);
  return generate(bankDropCat(day, i), 1200 + (i % 4) * 200, rng);
}

/// Weekend contest [index]: deterministic paper of [count] questions.
Question bankContest(int index, int qIdx, int count) {
  final rng = Random(0xC0DE5 * (index * 64 + qIdx) + 89);
  final ramp = (qIdx / count * 700).round();
  final rating = (1000 + ramp).clamp(800, 2500).toInt();
  return generate(
      _contestCats[(index + qIdx) % _contestCats.length], rating, rng);
}

/// Contest index for a date (weekends only): number of the weekend
/// since the epoch. Sat & Sun of the same weekend share an index.
int contestIndexFor(DateTime d) {
  final days = bankDayIndex(d);
  return (days + bankEpoch.weekday) ~/ 7;
}

// ---------------------- OFFICIAL MYNDASH ARENAS 🏟️ ----------------------
//
// Daily rated arenas (Mon–Fri) in six rating brackets, 8-ball-pool
// style venues. Registration stays open until 10 pm; play starts at
// 10 pm sharp; 30 questions, 30 minutes. Every question comes from a
// FIXED seed — the entire world gets the identical paper, and the
// bank is pre-generated for 60+ days (it actually never runs out).
// Expired arena days fold into Solve at their rating level automatically.

class ArenaBracket {
  final String name;
  final String emoji;
  final int lo;
  final int hi; // exclusive upper bound; 9999 = open top
  const ArenaBracket(this.name, this.emoji, this.lo, this.hi);

  String get range => hi >= 9000 ? '$lo+' : '$lo–$hi';
}

const officialBrackets = <ArenaBracket>[
  ArenaBracket('Foundation', '', 800, 1100),
  ArenaBracket('Vector', '', 1100, 1400),
  ArenaBracket('Cipher', '', 1400, 1700),
  ArenaBracket('Summit', '', 1700, 2000),
  ArenaBracket('Apex', '', 2000, 2300),
  ArenaBracket('Zenith', '', 2300, 2600),
];

/// The bracket a player belongs to for their contest rating. Players
/// below 800 play Foundation (the entry venue).
int bracketIndexFor(int rating) {
  for (var i = officialBrackets.length - 1; i > 0; i--) {
    if (rating >= officialBrackets[i].lo) return i;
  }
  return 0;
}

const arenaQuestionCount = 30;
const arenaMinutes = 30;

/// Everything the app can serve as an arena question feed —
/// maths, logic, quant + speed modes. Board games can't be
/// served as a shared timed paper, so they stay out.
const arenaCats = [
  'mental',
  'quant',
  'numtheory',
  'patterns',
  'geometry',
  'probability',
  'clock',
  'words',
  'knights',
  'crypta',
  'finance',
  'speedmath',
];

String bankArenaCat(int day, int bracket, int qIdx) =>
    arenaCats[(day * 7 + bracket * 5 + qIdx * 3) % arenaCats.length];

/// Official arena paper: question [qIdx] of [day]'s arena in
/// [bracket]. Difficulty ramps across the bracket's rating range.
Question bankArena(int day, int bracket, int qIdx) {
  final rng = Random(0xA12E8A * (day * 6 + bracket) + qIdx * 7919 + 13);
  final b = officialBrackets[bracket];
  final hi = min(b.hi, 2500);
  final rating = (b.lo + ((hi - b.lo) * qIdx / arenaQuestionCount))
      .round()
      .clamp(800, 2500)
      .toInt();
  return generate(bankArenaCat(day, bracket, qIdx), rating, rng);
}

/// Official arenas run Monday–Friday only.
bool isArenaDay(DateTime d) =>
    d.weekday != DateTime.saturday && d.weekday != DateTime.sunday;

/// 10 pm start on arena days.
DateTime arenaStartFor(DateTime d) => DateTime(d.year, d.month, d.day, 22);

// ---------------------- KIDS 🧒 ----------------------

/// Kids' 8pm daily drop — ONE question, scaled by age band.
Question bankKidDrop(int day, int age) {
  final rng = Random(0x51D5 * day + age ~/ 4 + 17);
  final level = age < 8 ? 1 + day % 4 : 3 + day % 5;
  final cat = _kidCatCycle[day % _kidCatCycle.length];
  // under-8s skip minAge-8 topics
  final safeCat = (age < 8 && (cat == 'tables')) ? 'counting' : cat;
  return generateKid(safeCat, level, rng);
}

/// Kids weekend contest: 8 gentle questions, stars not ratings.
Question bankKidContest(int index, int qIdx, int age) {
  final rng = Random(0x51DC0 * (index * 8 + qIdx) + 5);
  final level = (age < 8 ? 1 : 3) + (qIdx ~/ 2);
  final cat = _kidCatCycle[(index + qIdx) % _kidCatCycle.length];
  final safeCat = (age < 8 && cat == 'tables') ? 'addsub' : cat;
  return generateKid(safeCat, level.clamp(1, 10).toInt(), rng);
}

/// Real past questions for a Solve *feed* category near a target rating.
///
/// Every expired Daily, Drop, Contest and official-Arena question already
/// carries a category and a difficulty rating (800–2500). This gathers the
/// ones matching [catId] within [band] of [targetRating] so the Solve level
/// for that category can fold real past papers in among its generated set —
/// "the paper you missed becomes the level you practise". Bounded by [cap]
/// and [lookback] so generation stays fast.
List<Question> pastFeedQuestions(
  String catId,
  int targetRating, {
  int band = 250,
  int lookback = 60,
  int cap = 18,
}) {
  final today = bankDayIndex();
  final out = <Question>[];
  bool near(int r) => (r - targetRating).abs() <= band;

  for (var day = today - 1;
      day >= 0 && day >= today - lookback && out.length < cap;
      day--) {
    for (var slot = 0; slot < 5; slot++) {
      if (bankDailyCat(day, slot) != catId) continue;
      final r = (900 + slot * 250).clamp(800, 2500).toInt();
      if (near(r)) out.add(bankDaily(day, slot));
    }
    for (var i = 0; i < 8; i++) {
      if (bankDropCat(day, i) != catId) continue;
      final r = 1200 + (i % 4) * 200;
      if (near(r)) out.add(bankDrop(day, i));
    }
  }

  // past weekend contests — difficulty ramps across the 12-question paper
  final curC = contestIndexFor(DateTime.now());
  for (var c = curC - 1; c >= 0 && c >= curC - 10 && out.length < cap; c--) {
    for (var qi = 0; qi < 12; qi++) {
      if (_contestCats[(c + qi) % _contestCats.length] != catId) continue;
      final r = (1000 + (qi / 12 * 700).round()).clamp(800, 2500).toInt();
      if (near(r)) out.add(bankContest(c, qi, 12));
    }
  }

  // past official arenas — read the bracket whose range covers this rating
  final bracket = bracketIndexFor(targetRating);
  var added = 0;
  for (var day = today - 1;
      day >= 0 && day >= today - lookback && added < 12 && out.length < cap;
      day--) {
    final date = bankEpoch.add(Duration(days: day));
    if (!isArenaDay(date)) continue;
    added++;
    for (var qi = 0; qi < arenaQuestionCount; qi++) {
      if (bankArenaCat(day, bracket, qi) != catId) continue;
      final b = officialBrackets[bracket];
      final hi = min(b.hi, 2500);
      final r = (b.lo + ((hi - b.lo) * qi / arenaQuestionCount))
          .round()
          .clamp(800, 2500)
          .toInt();
      if (near(r)) out.add(bankArena(day, bracket, qi));
    }
  }
  return out;
}

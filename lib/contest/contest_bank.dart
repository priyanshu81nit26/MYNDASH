import 'dart:math';

import '../engine/event_calendar.dart';
import '../engine/generators.dart';
import '../engine/mind_engines.dart';
import '../engine/question.dart';

const int officialContestPaperCount = 50;
const Duration officialContestDuration = Duration(minutes: 45);

enum OfficialContestKind { saturday, sunday }

enum ContestEventPhase { registration, live, finalStandings }

enum ContestRoundKind { question, sudoku, hanoi, numWords, signalPath }

class OfficialContestEvent {
  final DateTime date;

  const OfficialContestEvent(this.date);

  OfficialContestKind get kind => date.weekday == DateTime.sunday
      ? OfficialContestKind.sunday
      : OfficialContestKind.saturday;

  bool get isSunday => kind == OfficialContestKind.sunday;

  String get eventKey => 'weekly-${eventDateKey(date)}';

  String get title => isSunday ? 'SunCo' : 'SatCo';

  String get shortTitle => isSunday ? 'SunCo' : 'SatCo';

  DateTime get startsAt => DateTime(date.year, date.month, date.day, 21);

  DateTime get endsAt => startsAt.add(officialContestDuration);

  int get paperIndex {
    final epoch = DateTime(2026, 1, 3);
    final days =
        DateTime(date.year, date.month, date.day).difference(epoch).inDays;
    final weekend = days ~/ 7;
    final offset = isSunday ? 1 : 0;
    return ((weekend * 2 + offset) % officialContestPaperCount +
            officialContestPaperCount) %
        officialContestPaperCount;
  }

  ContestEventPhase phaseAt(DateTime now) {
    if (now.isBefore(startsAt)) return ContestEventPhase.registration;
    if (now.isBefore(endsAt)) return ContestEventPhase.live;
    return ContestEventPhase.finalStandings;
  }

  bool registrationOpenAt(DateTime now) => now.isBefore(startsAt);
}

/// A compact calendar window for the Contest hub. The UI filters this down to
/// upcoming official events or the signed-in player's registered events.
List<OfficialContestEvent> officialContestCalendar(
  DateTime now, {
  int previous = 14,
  int upcoming = 8,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final out = <OfficialContestEvent>[];

  var cursor = today.subtract(const Duration(days: 1));
  while (out.length < previous) {
    if (cursor.weekday == DateTime.saturday ||
        cursor.weekday == DateTime.sunday) {
      out.add(OfficialContestEvent(cursor));
    }
    cursor = cursor.subtract(const Duration(days: 1));
  }

  cursor = today;
  var futureCount = 0;
  while (futureCount < upcoming) {
    if (cursor.weekday == DateTime.saturday ||
        cursor.weekday == DateTime.sunday) {
      final event = OfficialContestEvent(cursor);
      if (event.phaseAt(now) != ContestEventPhase.finalStandings) {
        out.add(event);
        futureCount++;
      }
    }
    cursor = cursor.add(const Duration(days: 1));
  }

  out.sort((a, b) => a.startsAt.compareTo(b.startsAt));
  return out;
}

class ContestRound {
  final String id;
  final ContestRoundKind kind;
  final String title;
  final String category;
  final int rating;
  final int points;
  final int seed;
  final Question? question;

  const ContestRound({
    required this.id,
    required this.kind,
    required this.title,
    required this.category,
    required this.rating,
    required this.points,
    required this.seed,
    this.question,
  });
}

class ContestPaper {
  final int index;
  final OfficialContestKind kind;
  final List<ContestRound> rounds;

  const ContestPaper({
    required this.index,
    required this.kind,
    required this.rounds,
  });

  int get maxScore => rounds.fold(0, (sum, round) => sum + round.points);
}

/// Returns one of 50 prepared, deterministic papers for the selected day type.
///
/// The category plan is fixed, while values, distractors, rating order and
/// board states are freshly generated from stable seeds. This keeps papers
/// identical for every participant and gives the catalog 50 reusable events
/// without shipping a large hand-duplicated JSON payload.
ContestPaper officialContestPaper(
  int index,
  OfficialContestKind kind,
) {
  final paperIndex =
      ((index % officialContestPaperCount) + officialContestPaperCount) %
          officialContestPaperCount;
  final sunday = kind == OfficialContestKind.sunday;
  final rootSeed = 0x51A7C0 + paperIndex * 7919 + (sunday ? 104729 : 0);
  final rng = Random(rootSeed);
  final categories = <String>[
    'mental',
    'quant',
    'patterns',
    'numtheory',
    'knights',
    'geometry',
    'probability',
    'words',
    'clock',
    'crypta',
    'mental',
    'quant',
    'patterns',
    'knights',
    'numtheory',
    'probability',
    'quant',
    'patterns',
    'words',
    'mental',
  ]..shuffle(rng);

  final questions = <ContestRound>[];
  for (var i = 0; i < 20; i++) {
    final ratingBase = sunday ? 1800 : 1400;
    final band = sunday ? 401 : 401;
    final rating = ratingBase + rng.nextInt(band);
    final seed = rootSeed + i * 3571;
    final question = generate(categories[i], rating, Random(seed));
    questions.add(
      ContestRound(
        id: 'q${i + 1}',
        kind: ContestRoundKind.question,
        title: 'Problem ${i + 1}',
        category: catById(categories[i]).name,
        rating: rating,
        points: 100 + ((rating - ratingBase) ~/ 100) * 10,
        seed: seed,
        question: question,
      ),
    );
  }

  ContestRound game(
    ContestRoundKind roundKind,
    String id,
    String title,
    String category,
    int points,
    int seedOffset,
  ) =>
      ContestRound(
        id: id,
        kind: roundKind,
        title: title,
        category: category,
        rating: sunday ? 2050 : 1700,
        points: points,
        seed: rootSeed + seedOffset,
      );

  return ContestPaper(
    index: paperIndex,
    kind: kind,
    rounds: [
      ...questions.take(6),
      game(
        ContestRoundKind.sudoku,
        'sudoku',
        'Sudoku Sprint',
        'Board logic',
        600,
        70001,
      ),
      ...questions.skip(6).take(6),
      game(
        ContestRoundKind.hanoi,
        'hanoi',
        'Hanoi Precision',
        'Planning',
        350,
        70003,
      ),
      ...questions.skip(12).take(4),
      game(
        ContestRoundKind.numWords,
        'numwords',
        'Number Words',
        'Verbal ordering',
        350,
        70009,
      ),
      ...questions.skip(16),
      game(
        ContestRoundKind.signalPath,
        'signal',
        'Signal Path',
        'Special IQ round',
        500,
        70019,
      ),
    ],
  );
}

SudokuPuzzle contestSudoku(ContestRound round, OfficialContestKind kind) =>
    SudokuEngine.generate(
      round.seed,
      kind == OfficialContestKind.sunday ? 25 : 28,
    );

class NumWordsPuzzle {
  final List<int> values;
  final List<int> correctOrder;

  const NumWordsPuzzle(this.values, this.correctOrder);
}

NumWordsPuzzle contestNumWords(
  ContestRound round,
  OfficialContestKind kind,
) {
  final rng = Random(round.seed);
  final count = kind == OfficialContestKind.sunday ? 6 : 5;
  final pool = <int>{
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
    11,
    12,
    13,
    14,
    15,
    16,
    17,
    18,
    19,
    20,
    30,
    40,
    50,
    60,
    70,
    80,
    90,
  }.toList()
    ..shuffle(rng);
  final values = pool.take(count).toList()..shuffle(rng);
  final order = List<int>.from(values)
    ..sort((a, b) => numberWord(a).compareTo(numberWord(b)));
  return NumWordsPuzzle(values, order);
}

String numberWord(int value) {
  const small = <String>[
    'zero',
    'one',
    'two',
    'three',
    'four',
    'five',
    'six',
    'seven',
    'eight',
    'nine',
    'ten',
    'eleven',
    'twelve',
    'thirteen',
    'fourteen',
    'fifteen',
    'sixteen',
    'seventeen',
    'eighteen',
    'nineteen',
  ];
  if (value < 20) return small[value];
  const tens = <int, String>{
    20: 'twenty',
    30: 'thirty',
    40: 'forty',
    50: 'fifty',
    60: 'sixty',
    70: 'seventy',
    80: 'eighty',
    90: 'ninety',
  };
  return tens[value] ?? '$value';
}

class SignalPathPuzzle {
  final List<int> cells;
  final List<int> path;
  final List<int> steps;

  const SignalPathPuzzle({
    required this.cells,
    required this.path,
    required this.steps,
  });

  List<int> get pathValues => path.map((cell) => cells[cell]).toList();
}

SignalPathPuzzle contestSignalPath(
  ContestRound round,
  OfficialContestKind kind,
) {
  final rng = Random(round.seed);
  const paths = <List<int>>[
    [0, 1, 5, 9, 10, 14, 15],
    [3, 2, 6, 10, 9, 13, 12],
    [4, 5, 1, 2, 6, 7, 11],
    [12, 8, 9, 5, 6, 2, 3],
  ];
  final path = List<int>.from(paths[rng.nextInt(paths.length)]);
  final steps = kind == OfficialContestKind.sunday
      ? <int>[4 + rng.nextInt(3), 7 + rng.nextInt(3), 5 + rng.nextInt(3)]
      : <int>[3 + rng.nextInt(3), 6 + rng.nextInt(3)];
  final values = <int>[7 + rng.nextInt(8)];
  for (var i = 1; i < path.length; i++) {
    values.add(values.last + steps[(i - 1) % steps.length]);
  }

  final cells = List<int>.filled(16, 0);
  for (var i = 0; i < path.length; i++) {
    cells[path[i]] = values[i];
  }
  final used = values.toSet();
  for (var i = 0; i < cells.length; i++) {
    if (cells[i] != 0) continue;
    var distractor = 6 + rng.nextInt(values.last + 12);
    while (used.contains(distractor)) {
      distractor++;
    }
    cells[i] = distractor;
    used.add(distractor);
  }
  return SignalPathPuzzle(cells: cells, path: path, steps: steps);
}

enum DailyItemType {
  math,
  sudoku,
  artHeist,
  crossword,
  numberPuzzle,
  kenKen,
  crossMath,
}

class DailyChallengeItem {
  final String id;
  final DailyItemType type;
  final String title;
  final String subtitle;
  final String category;
  final int rating;
  final int xp;
  final int coins;
  final int seed;
  final String? prompt;
  final String? answer;
  final List<String>? options;
  final String? note;
  final String? pattern;
  final List<String> embeddedHints;

  const DailyChallengeItem({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.rating,
    required this.xp,
    required this.coins,
    required this.seed,
    this.prompt,
    this.answer,
    this.options,
    this.note,
    this.pattern,
    this.embeddedHints = const [],
  });

  bool check(String input) =>
      input.trim().toLowerCase() == answer?.trim().toLowerCase();

  bool get isMath => type == DailyItemType.math;
}

class DailyChallengeDay {
  final int dayIndex;
  final List<DailyChallengeItem> math;
  final List<DailyChallengeItem> games;

  const DailyChallengeDay({
    required this.dayIndex,
    required this.math,
    required this.games,
  });

  List<DailyChallengeItem> get all => [...math, ...games];
  int get totalXp => all.fold(0, (sum, item) => sum + item.xp);
  int get totalCoins => all.fold(0, (sum, item) => sum + item.coins);
}

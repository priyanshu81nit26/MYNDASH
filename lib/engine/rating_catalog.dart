/// One rating language for every MYNDASH game.
///
/// Public UI always uses these bands. Older game engines may still use a
/// compact 1-based difficulty internally; the conversion helpers keep that
/// implementation detail out of player-facing screens.
class RatingCatalog {
  RatingCatalog._();

  static const min = 800;
  static const max = 2500;
  static const step = 100;

  static const bands = <int>[
    800,
    900,
    1000,
    1100,
    1200,
    1300,
    1400,
    1500,
    1600,
    1700,
    1800,
    1900,
    2000,
    2100,
    2200,
    2300,
    2400,
    2500,
  ];

  static int normalize(int rating) =>
      (((rating.clamp(min, max) - min) / step).round() * step + min)
          .clamp(min, max)
          .toInt();

  static int ratingForLegacyLevel(int level, {int maxLevel = 50}) {
    final safe = level.clamp(1, maxLevel);
    final t = maxLevel <= 1 ? 0.0 : (safe - 1) / (maxLevel - 1);
    return normalize((min + (max - min) * t).round());
  }

  static int legacyLevelForRating(int rating,
      {int maxLevel = 50, int variant = 1}) {
    final normalized = normalize(rating);
    final band = bands.indexOf(normalized).clamp(0, bands.length - 1);
    final start = (band * maxLevel / bands.length).floor() + 1;
    final end =
        (((band + 1) * maxLevel / bands.length).ceil()).clamp(start, maxLevel);
    final width = end - start + 1;
    return start + ((variant - 1).clamp(0, 9999) % width);
  }

  /// Dense feed games can support more versions; constrained mechanical
  /// games deliberately expose fewer meaningful combinations.
  static int variantsFor(String game) => switch (game) {
        'hanoi' => 5,
        'art' => 10,
        'crossword' => 20,
        'crossmath' => 30,
        'sudoku' || 'kenken' || 'numpz' || 'wordfind' => 15,
        _ => 30,
      };

  static String rangeLabel(int low, int high) =>
      '${normalize(low)}–${normalize(high)}';
}

import 'rating_catalog.dart';

/// Progression surfaces covered by the shared previous-clear rule.
///
/// Solve and standalone journeys are namespaced because games such as Sudoku
/// and Hanoi have both a multi-board Solve track and a dedicated game track.
const sequentialGameTracks = <String>[
  'solve:mental',
  'solve:quant',
  'solve:numtheory',
  'solve:patterns',
  'solve:geometry',
  'solve:probability',
  'solve:clock',
  'solve:knights',
  'solve:sudoku',
  'solve:mines',
  'solve:sliding',
  'solve:hanoi',
  'solve:memory',
  'solve:kenken',
  'solve:nonogram',
  'solve:kakuro',
  'solve:logicgrid',
  'solve:setgame',
  'solve:river',
  'solve:crypta',
  'solve:words',
  'solve:finance',
  'game:sudoku',
  'game:hanoi',
  'game:numpz',
  'game:arrow',
  'game:crossmath',
  'game:art-heist',
  'game:word-finder',
  'game:darts',
  'game:chess',
];

/// Shared sequential-unlock rules for every rated journey.
///
/// A caller may only advance the currently unlocked step. Replaying an older
/// step can improve its score, but can never skip or jump the progression.
class SequentialProgression {
  SequentialProgression._();

  static bool canPlay(int step, int unlocked) => step >= 1 && step <= unlocked;

  static bool isCurrent(int step, int unlocked) => step == unlocked;

  static int advance({
    required int step,
    required int unlocked,
    required bool completed,
    required int maxStep,
  }) {
    if (!completed || step != unlocked || unlocked >= maxStep) return unlocked;
    return unlocked + 1;
  }
}

/// Maps rating bands to real, individually seeded game variants.
class RatedProgression {
  RatedProgression._();

  static int totalSteps(int variantsPerRating) =>
      RatingCatalog.bands.length * variantsPerRating;

  static int stepFor(
    int rating,
    int variant, {
    required int variantsPerRating,
  }) {
    final band = RatingCatalog.bands
        .indexOf(RatingCatalog.normalize(rating))
        .clamp(0, RatingCatalog.bands.length - 1)
        .toInt();
    final safeVariant = variant.clamp(1, variantsPerRating).toInt();
    return band * variantsPerRating + safeVariant;
  }

  static int ratingForStep(
    int step, {
    required int variantsPerRating,
  }) {
    final safe = step.clamp(1, totalSteps(variantsPerRating)).toInt();
    return RatingCatalog.bands[(safe - 1) ~/ variantsPerRating];
  }

  static int variantForStep(
    int step, {
    required int variantsPerRating,
  }) {
    final safe = step.clamp(1, totalSteps(variantsPerRating)).toInt();
    return (safe - 1) % variantsPerRating + 1;
  }

  /// Difficulty remains bounded for older engines while [seedForStep] makes
  /// every visible version a genuinely different puzzle.
  static int engineLevelForStep(
    int step, {
    required int variantsPerRating,
    int maxEngineLevel = 50,
  }) {
    final rating = ratingForStep(step, variantsPerRating: variantsPerRating);
    final variant = variantForStep(step, variantsPerRating: variantsPerRating);
    return RatingCatalog.legacyLevelForRating(
      rating,
      maxLevel: maxEngineLevel,
      variant: variant,
    );
  }

  static int seedForStep(String game, int step) {
    var hash = 0x811C9DC5;
    for (final unit in game.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    hash ^= step * 104729;
    return hash & 0x7fffffff;
  }
}

class ArtHeistCatalog {
  ArtHeistCatalog._();

  static const variantsPerRating = 10;
  static const totalSteps = 180;

  static int ratingForStep(int step) => RatedProgression.ratingForStep(
        step,
        variantsPerRating: variantsPerRating,
      );

  static int variantForStep(int step) => RatedProgression.variantForStep(
        step,
        variantsPerRating: variantsPerRating,
      );

  static int stepFor(int rating, int variant) => RatedProgression.stepFor(
        rating,
        variant,
        variantsPerRating: variantsPerRating,
      );

  static int seedForStep(int step) =>
      RatedProgression.seedForStep('art-heist', step);

  static int gridForStep(int step) {
    final band = RatingCatalog.bands.indexOf(ratingForStep(step));
    if (band <= 3) return 3;
    if (band <= 8) return 4;
    if (band <= 13) return 5;
    return 6;
  }
}

class WordFinderCatalog {
  WordFinderCatalog._();

  static const variantsPerRating = 15;
  static const totalSteps = 270;

  static int ratingForStep(int step) => RatedProgression.ratingForStep(
        step,
        variantsPerRating: variantsPerRating,
      );

  static int variantForStep(int step) => RatedProgression.variantForStep(
        step,
        variantsPerRating: variantsPerRating,
      );

  static int stepFor(int rating, int variant) => RatedProgression.stepFor(
        rating,
        variant,
        variantsPerRating: variantsPerRating,
      );

  static int seedForStep(int step) =>
      RatedProgression.seedForStep('word-finder', step);

  static int gridForRating(int rating) {
    final band = RatingCatalog.bands.indexOf(RatingCatalog.normalize(rating));
    if (band <= 5) return 4;
    if (band <= 11) return 5;
    return 6;
  }

  static int embeddedWordTarget(int rating) {
    final band = RatingCatalog.bands.indexOf(RatingCatalog.normalize(rating));
    return 10 + band;
  }

  static int clearTarget(int guaranteedWords) =>
      (guaranteedWords * 0.4).ceil().clamp(5, 14).toInt();

  static int durationMs(int rating) {
    final size = gridForRating(rating);
    return switch (size) {
      4 => 90000,
      5 => 105000,
      _ => 120000,
    };
  }
}

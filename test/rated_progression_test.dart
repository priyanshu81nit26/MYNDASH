import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:reflex_duel/core/state.dart';
import 'package:reflex_duel/engine/game_progression.dart';
import 'package:reflex_duel/engine/mind_engines.dart';
import 'package:reflex_duel/engine/rating_catalog.dart';
import 'package:reflex_duel/engine/word_grid.dart';

void main() {
  test('sequential progression never skips the previous step', () {
    expect(
      SequentialProgression.advance(
          step: 2, unlocked: 1, completed: true, maxStep: 10),
      1,
    );
    expect(
      SequentialProgression.advance(
          step: 1, unlocked: 1, completed: false, maxStep: 10),
      1,
    );
    expect(
      SequentialProgression.advance(
          step: 1, unlocked: 1, completed: true, maxStep: 10),
      2,
    );
    expect(sequentialGameTracks.toSet(), hasLength(greaterThanOrEqualTo(30)));
    expect(sequentialGameTracks, contains('game:crossmath'));
    expect(sequentialGameTracks, isNot(contains('game:crossword')));
  });

  test('Cross Math exposes a full level-wise rated journey', () {
    expect(RatingCatalog.variantsFor('crossmath'), 30);
    expect(
      RatedProgression.totalSteps(RatingCatalog.variantsFor('crossmath')),
      540,
    );
    expect(
      RatedProgression.ratingForStep(
        1,
        variantsPerRating: RatingCatalog.variantsFor('crossmath'),
      ),
      800,
    );
    expect(
      RatedProgression.ratingForStep(
        540,
        variantsPerRating: RatingCatalog.variantsFor('crossmath'),
      ),
      2500,
    );
  });

  test('Hanoi has five unique difficulty-ordered games per rating', () {
    expect(HanoiCombo.levelCount, RatingCatalog.bands.length * 5);
    final variants = <String>{};
    var previousScore = -1.0;
    for (var step = 1; step <= HanoiCombo.levelCount; step++) {
      final (combo, tier) = HanoiCombo.forLevel(step);
      expect(variants.add('${combo.rings}/${combo.pegCount}/$tier'), isTrue);
      final score = log(combo.minMoves + 1) * 100 + tier * 18;
      expect(score, greaterThanOrEqualTo(previousScore));
      previousScore = score;
      expect(
        RatedProgression.ratingForStep(step, variantsPerRating: 5),
        inInclusiveRange(800, 2500),
      );
    }
  });

  test('Art and Word Finder expose full rated variant catalogs', () {
    expect(ArtHeistCatalog.totalSteps, 180);
    expect(WordFinderCatalog.totalSteps, 270);
    expect(ArtHeistCatalog.ratingForStep(1), 800);
    expect(ArtHeistCatalog.ratingForStep(180), 2500);
    expect(WordFinderCatalog.ratingForStep(1), 800);
    expect(WordFinderCatalog.ratingForStep(270), 2500);
    expect(
      {
        for (var step = 1; step <= ArtHeistCatalog.totalSteps; step++)
          ArtHeistCatalog.seedForStep(step),
      },
      hasLength(ArtHeistCatalog.totalSteps),
    );
  });

  test('all 270 Word Finder boards contain their promised playable words', () {
    final boards = <String>{};
    for (var step = 1; step <= WordFinderCatalog.totalSteps; step++) {
      final rating = WordFinderCatalog.ratingForStep(step);
      final target = WordFinderCatalog.embeddedWordTarget(rating);
      final spec = WordGridGenerator.generate(
        size: WordFinderCatalog.gridForRating(rating),
        seed: WordFinderCatalog.seedForStep(step),
        minimumWords: target,
      );
      expect(spec.guaranteedWords.length, greaterThanOrEqualTo(target),
          reason: 'rated variant $step must reach its guaranteed-word target');
      expect(boards.add(spec.letters.join()), isTrue,
          reason: 'rated variant $step must have a fresh board');
      for (final word in spec.guaranteedWords) {
        expect(spec.containsWord(word), isTrue,
            reason: '$word must be traceable on rated variant $step');
      }
    }
  });

  test('state unlock APIs reject skips and accept a completed current step',
      () {
    final a = AppData.i;

    a.cats = {};
    a.recordLevel('mental', 900, 3);
    expect(a.unlockedLevel('mental'), 800);
    a.recordLevel('mental', 800, 1);
    expect(a.unlockedLevel('mental'), 900);
    a.recordLevel('mental', 800, 3);
    expect(a.unlockedLevel('mental'), 900);

    a.mindLevels = {'test': 1};
    a.mindStars = {};
    expect(a.recordMindLevel('test', 2, 3, maxLevel: 10), isFalse);
    expect(a.mindLevel('test'), 1);
    expect(a.recordMindLevel('test', 1, 1, maxLevel: 10), isTrue);
    expect(a.mindLevel('test'), 2);

    a.artLevel = 1;
    a.artStars = {};
    expect(a.recordArtJourney(2, 3), isFalse);
    expect(a.artLevel, 1);
    expect(a.recordArtJourney(1, 1), isTrue);
    expect(a.artLevel, 2);
  });
}

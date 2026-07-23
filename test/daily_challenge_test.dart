import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reflex_duel/daily_challenge/daily_bank.dart';
import 'package:reflex_duel/daily_challenge/daily_models.dart';
import 'package:reflex_duel/engine/rating_catalog.dart';
import 'package:reflex_duel/engine/word_grid.dart';
import 'package:reflex_duel/engine/wordlist.dart';
import 'package:reflex_duel/puzzles/cross_math_board.dart';
import 'package:reflex_duel/puzzles/grid_boards.dart';
import 'package:reflex_duel/puzzles/word_hunt_board.dart';

void main() {
  test('expanded daily bank contains 100 complete fresh days', () {
    final prompts = <String>{};
    for (var dayIndex = 0; dayIndex < dailyChallengeDayCount; dayIndex++) {
      final day = dailyChallengeDay(dayIndex);
      expect(day.math, hasLength(5));
      expect(day.games, hasLength(6));
      expect(day.all.map((item) => item.id).toSet(), hasLength(11));
      expect(day.totalXp, greaterThan(0));
      expect(day.totalCoins, greaterThan(0));

      var previousMathRating = 0;
      for (final item in day.all) {
        expect(item.rating, inInclusiveRange(800, 2500));
        if (item.isMath) {
          expect(item.rating, inInclusiveRange(1200, 1800));
          expect(item.rating, greaterThan(previousMathRating));
          previousMathRating = item.rating;
          expect(prompts.add(item.prompt!), isTrue,
              reason: 'Math prompts must be fresh across the 100-day bank.');
        }
      }

      final crossword =
          day.games.singleWhere((item) => item.type == DailyItemType.crossword);
      expect(crossword.answer, isNull);
      expect(crossword.pattern, isNull);
      final wordGrid = WordGridGenerator.generate(
        size: crossword.rating < 1300
            ? 4
            : crossword.rating < 2000
                ? 5
                : 6,
        seed: crossword.seed,
        minimumWords: 7,
      );
      expect(wordGrid.guaranteedWords.length, greaterThanOrEqualTo(7));
      for (final word in wordGrid.guaranteedWords) {
        expect(wordSet, contains(word));
        expect(wordGrid.containsWord(word), isTrue);
      }

      final crossMath =
          day.games.singleWhere((item) => item.type == DailyItemType.crossMath);
      final crossMathSpec = generateCrossMath(
        rating: crossMath.rating,
        seed: crossMath.seed,
      );
      expect(crossMath.answer, isNull);
      expect(crossMathSpec.editable.length, greaterThanOrEqualTo(4));
      expect(crossMathSpec.tokens.values.where((value) => value == '='),
          hasLength(6));
    }
    expect(prompts, hasLength(500));
  });

  test('daily Sudoku can be forced to the requested 8 by 8 board', () {
    final spec = generateSudoku(1400, Random(42), forceSize: 8);
    expect(spec.n, 8);
    expect(spec.boxW, 4);
    expect(spec.boxH, 2);
    expect(spec.solution, hasLength(64));
    expect(spec.given, hasLength(64));
  });

  test('Sudoku Light always generates a valid 6 by 6 board', () {
    final spec = generateSudoku(2200, Random(84), forceSize: 6);
    expect(spec.n, 6);
    expect(spec.boxW, 3);
    expect(spec.boxH, 2);
    expect(spec.solution, hasLength(36));
    for (var row = 0; row < 6; row++) {
      expect(spec.solution.skip(row * 6).take(6).toSet(), hasLength(6));
    }
    for (var col = 0; col < 6; col++) {
      expect(
        {for (var row = 0; row < 6; row++) spec.solution[row * 6 + col]},
        hasLength(6),
      );
    }
  });

  test('Cross Math always generates six valid connected equations', () {
    const lines = <List<int>>[
      [0, 1, 2, 3, 4],
      [4, 13, 22, 31, 40],
      [36, 37, 38, 39, 40],
      [36, 45, 54, 63, 72],
      [72, 73, 74, 75, 76],
      [76, 77, 78, 79, 80],
    ];
    for (final rating in RatingCatalog.bands) {
      for (var variant = 0; variant < 30; variant++) {
        final spec = generateCrossMath(
          rating: rating,
          seed: rating * 104729 + variant,
        );
        for (final line in lines) {
          final left = spec.answers[line[0]]!;
          final right = spec.answers[line[2]]!;
          final result = spec.answers[line[4]]!;
          final operation = spec.tokens[line[1]];
          final calculated = switch (operation) {
            '+' => left + right,
            '−' => left - right,
            '×' => left * right,
            '÷' => left ~/ right,
            _ => throw StateError('Unknown operation $operation'),
          };
          expect(calculated, result,
              reason: '$left $operation $right must equal $result');
        }
      }
    }
  });

  testWidgets('gamified Word Hunt and Cross Math fit a compact phone',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> render(Widget board) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    const SizedBox(height: 58),
                    Expanded(child: board),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    }

    await render(
      WordHuntBoard(
        rating: 1700,
        seed: 713,
        targetWords: 5,
        onSolved: () {},
      ),
    );
    await render(
      CrossMathBoard(
        rating: 2100,
        seed: 991,
        onSolved: () {},
      ),
    );
  });

  test('every game uses the shared 800 to 2500 rating catalog', () {
    expect(RatingCatalog.bands.first, 800);
    expect(RatingCatalog.bands.last, 2500);
    expect(RatingCatalog.bands, hasLength(18));
    expect(RatingCatalog.variantsFor('hanoi'), 5);
    expect(RatingCatalog.variantsFor('sudoku'), 15);
    expect(RatingCatalog.variantsFor('crossword'), 20);
    expect(RatingCatalog.variantsFor('crossmath'), 30);
    expect(RatingCatalog.variantsFor('mental'), 30);
    for (var i = 1; i <= 50; i++) {
      expect(
          RatingCatalog.ratingForLegacyLevel(i), inInclusiveRange(800, 2500));
    }
  });
}

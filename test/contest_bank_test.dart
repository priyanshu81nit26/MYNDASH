import 'package:flutter_test/flutter_test.dart';
import 'package:reflex_duel/contest/contest_bank.dart';

void main() {
  group('official contest catalog', () {
    test('contains 50 deterministic Saturday and Sunday papers', () {
      final saturdaySignatures = <String>{};
      final sundaySignatures = <String>{};

      for (var index = 0; index < officialContestPaperCount; index++) {
        for (final kind in OfficialContestKind.values) {
          final paper = officialContestPaper(index, kind);
          final replay = officialContestPaper(index, kind);
          final questions = paper.rounds
              .where((round) => round.kind == ContestRoundKind.question)
              .toList();

          expect(paper.index, index);
          expect(paper.rounds, hasLength(24));
          expect(questions, hasLength(20));
          expect(
            paper.rounds
                .where((round) => round.kind == ContestRoundKind.sudoku),
            hasLength(1),
          );
          expect(
            paper.rounds.where((round) => round.kind == ContestRoundKind.hanoi),
            hasLength(1),
          );
          expect(
            paper.rounds
                .where((round) => round.kind == ContestRoundKind.numWords),
            hasLength(1),
          );
          expect(
            paper.rounds
                .where((round) => round.kind == ContestRoundKind.signalPath),
            hasLength(1),
          );
          expect(paper.maxScore, greaterThan(3000));

          for (final round in questions) {
            expect(round.question, isNotNull);
            expect(round.question!.prompt, isNotEmpty);
            expect(round.question!.answer, isNotEmpty);
            expect(
              round.rating,
              inInclusiveRange(
                kind == OfficialContestKind.sunday ? 1800 : 1400,
                kind == OfficialContestKind.sunday ? 2200 : 1800,
              ),
            );
          }

          final signature = questions
              .map((round) =>
                  '${round.rating}:${round.question!.prompt}:${round.question!.answer}')
              .join('|');
          final replaySignature = replay.rounds
              .where((round) => round.kind == ContestRoundKind.question)
              .map((round) =>
                  '${round.rating}:${round.question!.prompt}:${round.question!.answer}')
              .join('|');
          expect(replaySignature, signature);
          (kind == OfficialContestKind.saturday
                  ? saturdaySignatures
                  : sundaySignatures)
              .add(signature);
        }
      }

      expect(saturdaySignatures, hasLength(officialContestPaperCount));
      expect(sundaySignatures, hasLength(officialContestPaperCount));
    });

    test('special rounds are deterministic and internally solvable', () {
      for (final kind in OfficialContestKind.values) {
        final paper = officialContestPaper(17, kind);

        final sudokuRound = paper.rounds
            .singleWhere((round) => round.kind == ContestRoundKind.sudoku);
        final sudoku = contestSudoku(sudokuRound, kind);
        expect(sudoku.solution, hasLength(81));
        expect(sudoku.given, hasLength(81));
        for (var i = 0; i < 81; i++) {
          if (sudoku.given[i] != 0) {
            expect(sudoku.given[i], sudoku.solution[i]);
          }
        }

        final wordsRound = paper.rounds
            .singleWhere((round) => round.kind == ContestRoundKind.numWords);
        final words = contestNumWords(wordsRound, kind);
        final sorted = List<int>.from(words.values)
          ..sort((a, b) => numberWord(a).compareTo(numberWord(b)));
        expect(words.correctOrder, sorted);
        expect(words.values.toSet(), hasLength(words.values.length));

        final signalRound = paper.rounds
            .singleWhere((round) => round.kind == ContestRoundKind.signalPath);
        final signal = contestSignalPath(signalRound, kind);
        expect(signal.cells, hasLength(16));
        expect(signal.path, hasLength(7));
        for (var i = 1; i < signal.path.length; i++) {
          final a = signal.path[i - 1];
          final b = signal.path[i];
          final rowDistance = (a ~/ 4 - b ~/ 4).abs();
          final colDistance = (a % 4 - b % 4).abs();
          expect(rowDistance + colDistance, 1);
          expect(
            signal.cells[b] - signal.cells[a],
            signal.steps[(i - 1) % signal.steps.length],
          );
        }
      }
    });
  });

  group('official contest calendar', () {
    test('starts at 9 PM and ends after one shared 45 minute window', () {
      final event = OfficialContestEvent(DateTime(2026, 7, 18));
      expect(event.kind, OfficialContestKind.saturday);
      expect(event.startsAt, DateTime(2026, 7, 18, 21));
      expect(event.endsAt, DateTime(2026, 7, 18, 21, 45));
      expect(
        event.phaseAt(DateTime(2026, 7, 18, 20, 59)),
        ContestEventPhase.registration,
      );
      expect(
        event.phaseAt(DateTime(2026, 7, 18, 21, 10)),
        ContestEventPhase.live,
      );
      expect(
        event.phaseAt(DateTime(2026, 7, 18, 21, 45)),
        ContestEventPhase.finalStandings,
      );
    });

    test('Saturday and Sunday use different stable papers', () {
      final saturday = OfficialContestEvent(DateTime(2026, 7, 18));
      final sunday = OfficialContestEvent(DateTime(2026, 7, 19));
      expect(saturday.kind, OfficialContestKind.saturday);
      expect(sunday.kind, OfficialContestKind.sunday);
      expect(saturday.paperIndex, isNot(sunday.paperIndex));
      expect(
        OfficialContestEvent(DateTime(2026, 7, 18)).paperIndex,
        saturday.paperIndex,
      );
    });
  });
}

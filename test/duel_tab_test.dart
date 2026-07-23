import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reflex_duel/screens/compete.dart';
import 'package:reflex_duel/theme_district.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      '1v1 arena exposes the full game catalog in ${dark ? 'dark' : 'light'} mode',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(375, 812));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        ThemeCtl.mode.value = dark ? 1 : 0;
        ThemeCtl.t.value = dark ? 1 : 0;

        await tester.pumpWidget(
          MaterialApp(
            theme: districtTheme(),
            home: const Scaffold(body: DuelTab()),
          ),
        );
        await tester.pump();

        expect(find.text('1V1 ARENA'), findsOneWidget);
        expect(find.text('Chess ♟'), findsOneWidget);
        expect(find.text('Scribble'), findsOneWidget);
        expect(find.text('Word Finder'), findsOneWidget);
        expect(find.text('Sudoku'), findsOneWidget);
        expect(find.text('Tower of Hanoi'), findsOneWidget);
        expect(find.text('Number Puzzle'), findsOneWidget);
        expect(find.text('Crossword'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reflex_duel/core/state.dart';
import 'package:reflex_duel/screens/ai_coach.dart';
import 'package:reflex_duel/services/local_coach_engine.dart';
import 'package:reflex_duel/theme_district.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await AppData.i.load();
  });

  setUp(() async {
    await AppData.i.resetAll();
  });

  test('local corpus covers math, problem solving and standalone games', () {
    final games = LocalCoachEngine.allKnownGames;
    expect(games.length, greaterThanOrEqualTo(35));
    expect(
      games,
      containsAll([
        'mental',
        'quant',
        'probability',
        'words',
        'sudoku',
        'chess',
        'darts',
        'cube',
        'reflex',
        'scribble',
        'wordfind',
        'art',
      ]),
    );
  });

  test('retrieval routes natural language to the correct game knowledge', () {
    AppData.i.catStats = {
      'mental': {
        'n': 12,
        'correct': 7,
        'ms': 96000,
        'fastWrong': 3,
        'slowRight': 1,
      },
    };
    final reply =
        LocalCoachEngine(AppData.i).answer('Why am I making math mistakes?');

    expect(reply.focusDomainId, 'mental');
    expect(reply.title, contains('Mental Math'));
    expect(reply.evidence, contains('7/12'));
    expect(reply.steps, isNotEmpty);
  });

  test('adaptive plan prioritizes reliable weak evidence', () {
    AppData.i.catStats = {
      'mental': {
        'n': 20,
        'correct': 19,
        'ms': 100000,
        'fastWrong': 0,
        'slowRight': 1,
      },
      'probability': {
        'n': 18,
        'correct': 7,
        'ms': 180000,
        'fastWrong': 4,
        'slowRight': 1,
      },
    };
    final plan = LocalCoachEngine(AppData.i).plan();

    expect(plan, isNotEmpty);
    expect(plan.first.domainId, 'probability');
    expect(plan.first.reason, contains('fast misses'));
  });

  test('snapshot creates private trend and multidimensional skill data', () {
    final now = DateTime.now().millisecondsSinceEpoch;
    AppData.i.catStats = {
      'mental': {
        'n': 10,
        'correct': 8,
        'ms': 70000,
        'fastWrong': 1,
        'slowRight': 2,
      },
    };
    AppData.i.trainingEvents = [
      {
        'type': 'answer',
        'domain': 'mental',
        'value': 1,
        'durationMs': 5000,
        'parMs': 8000,
        'ts': now,
      },
      {
        'type': 'practice',
        'domain': 'cube',
        'value': 1,
        'durationMs': 42000,
        'ts': now,
      },
    ];

    final snapshot = LocalCoachEngine(AppData.i).snapshot();
    expect(snapshot.days, hasLength(14));
    expect(snapshot.activeDays14, 1);
    expect(snapshot.groupScores['Calculation'], greaterThan(0));
    expect(snapshot.groupScores['Memory'], greaterThan(0));
  });

  test('compound game telemetry stays attached to its exact game', () {
    AppData.i.trainingEvents = [
      {
        'type': 'answer-set',
        'domain': 'chess_iq',
        'value': 0.8,
        'ts': DateTime.now().millisecondsSinceEpoch,
      },
    ];
    final snapshot = LocalCoachEngine(AppData.i).snapshot();
    final chessIq =
        snapshot.insights.firstWhere((item) => item.id == 'chess_iq');
    final chess = snapshot.insights.firstWhere((item) => item.id == 'chess');

    expect(chessIq.measured, isTrue);
    expect(chess.measured, isFalse);
  });

  testWidgets('trainer conversation works on a compact phone layout',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: districtTheme(),
        home: const AiCoachScreen(),
      ),
    );
    await tester.pump();

    expect(find.text('AI TRAINER'), findsOneWidget);
    expect(find.text('FREE · LOCAL'), findsOneWidget);
    expect(find.text('TALK TO YOUR TRAINER'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.enterText(
      find.byType(TextField),
      'How can I improve chess?',
    );
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Chess'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('telemetry lab renders cleanly in the dark theme',
      (tester) async {
    ThemeCtl.mode.value = 1;
    ThemeCtl.t.value = 1;
    addTearDown(() {
      ThemeCtl.mode.value = 0;
      ThemeCtl.t.value = 0;
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: districtTheme(),
        home: const GameAnalysisScreen(),
      ),
    );
    await tester.pump();

    expect(find.text('TELEMETRY LAB'), findsOneWidget);
    expect(find.text('14-DAY TRAINING PULSE'), findsOneWidget);
    expect(find.text('COGNITIVE SKILLPRINT'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:reflex_duel/core/state.dart';
import 'package:reflex_duel/engine/arena_game_catalog.dart';
import 'package:reflex_duel/engine/banks.dart';
import 'package:reflex_duel/engine/event_calendar.dart';
import 'package:reflex_duel/screens/arena_redesign.dart';
import 'package:reflex_duel/screens/events_screen.dart' show joinArena;
import 'package:reflex_duel/services/account_service.dart';
import 'package:reflex_duel/theme_district.dart';

void main() {
  test('official arena schedule contains six ordered rating events', () {
    expect(officialBrackets, hasLength(6));
    expect(officialBrackets.first.lo, 800);
    expect(officialBrackets.last.hi, 2600);
    for (var index = 1; index < officialBrackets.length; index++) {
      expect(officialBrackets[index].lo, officialBrackets[index - 1].hi);
    }
    for (var day = DateTime.monday; day <= DateTime.friday; day++) {
      final date = DateTime(2026, 7, 13 + day - 1);
      expect(isArenaDay(date), isTrue);
    }
  });

  test('event calendar maps weeks, phases and countdowns consistently', () {
    final thursday = DateTime(2026, 7, 16, 9);
    expect(mondayOf(thursday), DateTime(2026, 7, 13));
    expect(eventDateKey(thursday), '2026-07-16');

    final start = DateTime(2026, 7, 16, 22);
    expect(
      eventPhase(
        DateTime(2026, 7, 16, 21, 30),
        start,
        duration: const Duration(minutes: 30),
      ),
      EventPhase.upcoming,
    );
    expect(
      eventPhase(
        DateTime(2026, 7, 16, 22, 10),
        start,
        duration: const Duration(minutes: 30),
      ),
      EventPhase.live,
    );
    expect(
      eventPhase(
        DateTime(2026, 7, 16, 22, 31),
        start,
        duration: const Duration(minutes: 30),
      ),
      EventPhase.completed,
    );
    expect(
      compactCountdown(const Duration(hours: 2, minutes: 3, seconds: 4)),
      '02:03:04',
    );
  });

  test('hourly arenas close registration exactly at start and wait 2 minutes',
      () {
    final now = DateTime(2026, 7, 18, 15, 12, 45);
    final start = nextHourlyArenaSlot(now);

    expect(start, DateTime(2026, 7, 18, 16));
    expect(
      nextHourlyArenaSlot(now, additionalHours: 3),
      DateTime(2026, 7, 18, 19),
    );
    expect(
      arenaRegistrationOpen(DateTime(2026, 7, 18, 15, 59, 59), start),
      isTrue,
    );
    expect(arenaRegistrationOpen(start, start), isFalse);
    expect(
      arenaQuestionsOpenAt(start),
      DateTime(2026, 7, 18, 16, 2),
    );
    expect(
      arenaEndsAt(start, const Duration(minutes: 30)),
      DateTime(2026, 7, 18, 16, 32),
    );
  });

  test('arena game registry includes timed boards and discovered feeds', () {
    expect(
      ArenaGameCatalog.ids,
      containsAll([
        'finance',
        'sudoku',
        'art_heist',
        'crossword',
        'chess',
        'number_puzzle',
      ]),
    );
    expect(
      ArenaGameCatalog.byId('sudoku').usesQuestionCount,
      isFalse,
    );
    expect(
      ArenaGameCatalog.byId('finance').usesQuestionCount,
      isTrue,
    );
  });

  test('organization events retain stable My Arenas ownership', () {
    final collegeEvent = <String, dynamic>{
      'org': 'college:Example University',
      'hostUid': 'user-123',
      'createdByUid': 'user-123',
    };
    final corporateEvent = <String, dynamic>{
      'org': 'company:Example Labs',
      'createdByUid': 'user-123',
    };

    expect(arenaWasCreatedBy(collegeEvent, 'user-123'), isTrue);
    expect(arenaWasCreatedBy(corporateEvent, 'user-123'), isTrue);
    expect(arenaWasCreatedBy(collegeEvent, 'someone-else'), isFalse);
  });

  test('arena service rejects game levels outside 800 to 2500', () async {
    final (error, _) = await AccountService.instance.createArena(
      title: 'Invalid level',
      fee: 0,
      isPublic: true,
      category: 'mixed',
      maxPlayers: 8,
      questionCount: 15,
      durationMin: 15,
      gameRating: 850,
      startAt:
          DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch,
    );
    expect(error, contains('800 to 2500'));
  });

  test('arena service rejects non-hourly organizer starts', () async {
    final nonHourly = DateTime.now()
        .add(const Duration(hours: 2))
        .copyWith(minute: 15, second: 0, millisecond: 0);
    final (error, _) = await AccountService.instance.createArena(
      title: 'Quarter past arena',
      fee: 0,
      isPublic: false,
      category: 'mixed',
      maxPlayers: 8,
      questionCount: 15,
      durationMin: 15,
      gameRating: 800,
      startAt: nonHourly.millisecondsSinceEpoch,
    );
    expect(error, contains('hourly slot'));
  });

  test('large cover images are compressed below the arena payload limit', () {
    final source = img.Image(width: 1800, height: 1200);
    for (var y = 0; y < source.height; y++) {
      for (var x = 0; x < source.width; x++) {
        source.setPixelRgba(
          x,
          y,
          (x * 17 + y * 3) % 256,
          (x * 5 + y * 13) % 256,
          (x * 11 + y * 7) % 256,
          255,
        );
      }
    }
    final compressed =
        compressArenaCoverForUpload(img.encodePng(source, level: 1));
    expect(compressed, isNotNull);
    expect(compressed!.length, lessThanOrEqualTo(120 * 1024));
    expect(img.decodeImage(compressed), isNotNull);
  });

  testWidgets('arena home shows six official events and clear destinations',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(375, 812));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    ThemeCtl.mode.value = 0;
    ThemeCtl.t.value = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: districtTheme(),
        home: const ArenaHubScreen(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    for (final bracket in officialBrackets) {
      expect(find.text(bracket.name), findsOneWidget);
    }
    await tester.scrollUntilVisible(
      find.text('YOUR ARENA SPACE'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(find.text('Public Arenas'), findsOneWidget);
    expect(find.text('My Arenas'), findsOneWidget);
    expect(find.text('Join by Code'), findsOneWidget);
    expect(find.text('Host Arena'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('organization arenas reject non-members before joining',
      (tester) async {
    final previousCollege = AppData.i.college;
    AppData.i.college = 'Another College';
    addTearDown(() => AppData.i.college = previousCollege);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => joinArena(context, {
                'title': 'Member Arena',
                'public': true,
                'org': 'college:Example University',
              }),
              child: const Text('Join'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Join'));
    await tester.pump();
    expect(
      find.text(
          'Only verified members of Example University can join this arena.'),
      findsOneWidget,
    );
  });

  for (final dark in [false, true]) {
    testWidgets(
      'host arena is usable on a small phone in ${dark ? 'dark' : 'light'} mode',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(375, 812));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        ThemeCtl.mode.value = dark ? 1 : 0;
        ThemeCtl.t.value = dark ? 1 : 0;

        await tester.pumpWidget(
          MaterialApp(
            theme: districtTheme(),
            home: const HostArenaScreen(),
          ),
        );
        await tester.pump();

        expect(find.text('HOST ARENA'), findsOneWidget);
        expect(find.text('ACCESS'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.scrollUntilVisible(
          find.text('GAME & LEVEL'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();
        expect(find.text('GAME & LEVEL'), findsOneWidget);
        expect(find.text('800'), findsWidgets);
        expect(find.text('2500'), findsWidgets);
        expect(find.text('Sudoku'), findsOneWidget);
        expect(find.text('Art Heist'), findsOneWidget);
        expect(find.text('Crossword'), findsOneWidget);
        expect(find.text('Chess'), findsOneWidget);
        expect(find.text('Number Puzzle'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

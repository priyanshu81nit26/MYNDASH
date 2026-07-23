import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reflex_duel/core/state.dart';
import 'package:reflex_duel/screens/community_hub.dart';
import 'package:reflex_duel/screens/community_screen.dart';
import 'package:reflex_duel/screens/squads_screen.dart';
import 'package:reflex_duel/theme_district.dart';
import 'package:reflex_duel/ui/community_design.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await AppData.i.load();
  });

  setUp(() async {
    ThemeCtl.mode.value = 0;
    ThemeCtl.t.value = 0;
    await AppData.i.resetAll();
  });

  tearDown(() {
    ThemeCtl.mode.value = 0;
    ThemeCtl.t.value = 0;
  });

  Future<void> pumpPage(
    WidgetTester tester,
    Widget page, {
    bool dark = false,
  }) async {
    ThemeCtl.mode.value = dark ? 1 : 0;
    ThemeCtl.t.value = dark ? 1 : 0;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        key: UniqueKey(),
        theme: districtTheme(),
        home: page,
      ),
    );
    await tester.pump();
  }

  testWidgets('community hub is responsive in light and dark themes',
      (tester) async {
    for (final dark in [false, true]) {
      await pumpPage(tester, const CommunityHubScreen(), dark: dark);

      expect(find.text('COMMUNITY'), findsOneWidget);
      expect(find.textContaining('Build your circle.'), findsOneWidget);
      expect(find.text('CHOOSE YOUR SPACE'), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -420));
      await tester.pump();
      expect(find.text('Squad'), findsOneWidget);
      expect(find.text('College'), findsOneWidget);
      expect(find.text('Corporate'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('college verification gives clear labeled inputs',
      (tester) async {
    await pumpPage(
      tester,
      const CommunityScreen(type: 'college'),
      dark: true,
    );

    expect(find.text('COLLEGE'), findsOneWidget);
    expect(find.text('Represent your campus.'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -380));
    await tester.pump();
    expect(find.text('IDENTIFY YOUR ORGANIZATION'), findsOneWidget);
    expect(find.text('College name'), findsOneWidget);
    expect(find.text('College email'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('corporate verification uses the same accessible system',
      (tester) async {
    await pumpPage(
      tester,
      const CommunityScreen(type: 'company'),
    );

    expect(find.text('CORPORATE'), findsOneWidget);
    expect(find.text('Compete with your workplace.'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -380));
    await tester.pump();
    expect(find.text('Company name'), findsOneWidget);
    expect(find.text('Work email'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty squad state exposes all three join paths', (tester) async {
    await pumpPage(tester, const SquadsScreen(), dark: true);
    await tester.pump();

    expect(find.text('SQUADS'), findsOneWidget);
    expect(find.text('Stronger together.'), findsOneWidget);
    expect(find.text('FIND A SQUAD'), findsOneWidget);
    expect(find.text('CREATE A SQUAD'), findsOneWidget);
    expect(find.text('JOIN WITH CODE'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('created-space hero metrics fit compact dark layout',
      (tester) async {
    await pumpPage(
      tester,
      const Scaffold(
        body: CommunityBackdrop(
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CommunityHeroCard(
                icon: Icons.groups_3_rounded,
                eyebrow: 'SQUAD SPACE',
                title: 'Northern Lights',
                subtitle: 'Your crew, shared XP and member ranking.',
                metrics: [
                  CommunityMetric(
                    icon: Icons.people_alt_outlined,
                    value: '10',
                    label: 'members',
                  ),
                  CommunityMetric(
                    icon: Icons.bolt_outlined,
                    value: '24K',
                    label: 'squad power',
                  ),
                  CommunityMetric(
                    icon: Icons.emoji_events_outlined,
                    value: '8',
                    label: 'trophies',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      dark: true,
    );

    expect(find.text('Northern Lights'), findsOneWidget);
    expect(find.text('squad power'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

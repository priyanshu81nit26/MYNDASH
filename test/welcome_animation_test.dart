import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reflex_duel/screens/welcome_screen.dart';

void main() {
  setUp(() {
    resetWelcome();
    _StartupProbeState.initCount = 0;
  });

  testWidgets('startup animation keeps the dashboard mounted through handoff',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: WelcomeGate(child: _StartupProbe()),
      ),
    );

    expect(find.byKey(const ValueKey('welcome-intro')), findsOneWidget);
    expect(find.byKey(const ValueKey('startup-dashboard')), findsOneWidget);
    expect(_StartupProbeState.initCount, 1);

    await tester.pump(const Duration(milliseconds: 1700));
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 1600));
    expect(find.byKey(const ValueKey('welcome-glass-brand')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump();

    expect(find.byKey(const ValueKey('welcome-intro')), findsNothing);
    expect(find.byKey(const ValueKey('startup-dashboard')), findsOneWidget);
    expect(_StartupProbeState.initCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('intro is skippable and safe on a compact phone', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: WelcomeGate(child: _StartupProbe()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.byKey(const ValueKey('welcome-skip')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('welcome-skip')));
    await tester.pump();

    expect(find.byKey(const ValueKey('welcome-intro')), findsNothing);
    expect(find.byKey(const ValueKey('startup-dashboard')), findsOneWidget);
    expect(_StartupProbeState.initCount, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('glass brand reveal fits a landscape viewport', (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: WelcomeGate(child: _StartupProbe()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 3300));

    expect(find.byKey(const ValueKey('welcome-glass-brand')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _StartupProbe extends StatefulWidget {
  const _StartupProbe();

  @override
  State<_StartupProbe> createState() => _StartupProbeState();
}

class _StartupProbeState extends State<_StartupProbe> {
  static int initCount = 0;

  @override
  void initState() {
    super.initState();
    initCount++;
  }

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      key: ValueKey('startup-dashboard'),
      color: Color(0xFF111827),
      child: Center(child: Text('Dashboard')),
    );
  }
}

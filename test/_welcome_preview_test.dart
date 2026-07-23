import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reflex_duel/screens/welcome_screen.dart';

void main() {
  testWidgets('capture welcome animation phases', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    resetWelcome();

    await tester.pumpWidget(
      const MaterialApp(
        home: RepaintBoundary(
          key: ValueKey('preview'),
          child: WelcomeGate(
            child: ColoredBox(
              color: Color(0xFFF7FAFC),
              child: Center(child: Text('Dashboard')),
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 1500));
    await expectLater(
      find.byKey(const ValueKey('preview')),
      matchesGoldenFile('goldens/welcome_rocket.png'),
    );

    await tester.pump(const Duration(milliseconds: 1600));
    await expectLater(
      find.byKey(const ValueKey('preview')),
      matchesGoldenFile('goldens/welcome_mynd.png'),
    );
  });
}

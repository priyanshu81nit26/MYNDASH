import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reflex_duel/screens/kid_arcade.dart';

// Smoke test: the two arcade games can't be visually verified, so at least
// prove their ticker loop + custom painters run for a while without throwing.
// Durations stay short enough not to trigger game-over (which would hit
// plugin-backed save()).
void main() {
  testWidgets('Sky Stack ticks and paints without error', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: StackGameScreen()));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cube Dash ticks and paints without error', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: DashGameScreen()));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 900));
    expect(tester.takeException(), isNull);
  });
}

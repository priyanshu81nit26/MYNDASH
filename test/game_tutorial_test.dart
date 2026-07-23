import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reflex_duel/ui/game_tutorial.dart';

// The level-0 coach overlay must walk forward through its steps and show the
// "GOT IT!" affordance on the last one (that's what dismisses it in-app).
void main() {
  testWidgets('tutorial advances through steps to a final GOT IT', (t) async {
    const steps = [
      TutorialStep('Step one', gesture: TutorialGesture.tap),
      TutorialStep('Step two', gesture: TutorialGesture.swipeUp),
      TutorialStep('Step three', gesture: TutorialGesture.none),
    ];
    await t.pumpWidget(const MaterialApp(
        home: GameTutorial(title: 'HOW TO', steps: steps)));
    await t.pump(const Duration(milliseconds: 100));

    expect(find.text('Step one'), findsOneWidget);
    expect(find.text('NEXT'), findsOneWidget);

    await t.tap(find.text('NEXT'));
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('Step two'), findsOneWidget);

    await t.tap(find.text('NEXT'));
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('Step three'), findsOneWidget);
    // last step: the dismiss control, not another NEXT
    expect(find.text('GOT IT!'), findsOneWidget);
    expect(find.text('NEXT'), findsNothing);
  });
}

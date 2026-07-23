import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reflex_duel/ui/glass.dart';

// Reproduces the journey "current level" card: ShaderBackground body with
// a Row([emoji, Expanded(Column(texts)), NeonButton]) — the shape that
// renders as one-char-per-line vertical text in the app.
void main() {
  testWidgets('journey card layout does not collapse or throw',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ShaderBackground(
          child: SafeArea(
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Glass(
                  radius: 20,
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    const Text('⚔️', style: TextStyle(fontSize: 30)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Level 1 — 1000 Elo'),
                          Text('Game 1/5 · next bot: 1000 Elo'),
                        ],
                      ),
                    ),
                    NeonButton(label: 'PLAY', height: 40, onPressed: () {}),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    ));

    expect(tester.takeException(), isNull);

    // The Expanded's text must have real width, not ~1 char.
    final textSize = tester.getSize(find.text('Level 1 — 1000 Elo'));
    expect(textSize.width, greaterThan(60),
        reason: 'Expanded collapsed → vertical one-char-per-line text');
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:reflex_duel/models/models.dart';

// The shuffle-bag rotation must (a) never hand out the same round type twice
// in a row and (b) cycle through every type evenly — that's what kills the
// "same few keep coming up / it's predictable" problem the player reported.
void main() {
  test('round types never repeat back-to-back and cover all types', () {
    final counts = <RoundType, int>{};
    RoundType? prev;
    const rounds = 600; // 50 full bags of 12
    for (var i = 0; i < rounds; i++) {
      final spec = RoundSpec.generate(index: i, serverNowMs: 0);
      expect(spec.type, isNot(equals(prev)),
          reason: 'type repeated back-to-back at round $i');
      counts.update(spec.type, (v) => v + 1, ifAbsent: () => 1);
      prev = spec.type;
    }
    // every type shows up, and distribution is even (each ~600/12 = 50).
    expect(counts.length, RoundType.values.length);
    for (final c in counts.values) {
      expect(c, greaterThan(30));
      expect(c, lessThan(70));
    }
  });
}

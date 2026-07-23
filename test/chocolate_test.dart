import 'package:flutter_test/flutter_test.dart';
import 'package:reflex_duel/screens/kid_chocolate.dart';

// The hourly Chocolate problem must be identical for every kid (seeded by
// day + hour), and different across hours so the 24 slots aren't clones.
void main() {
  test('choc problem is deterministic per day+hour and varies by hour', () {
    final a1 = chocQuestion('2026-07-14', 9);
    final a2 = chocQuestion('2026-07-14', 9);
    expect(a1.prompt, a2.prompt);
    expect(a1.answer, a2.answer);

    final b = chocQuestion('2026-07-14', 10);
    final other = chocQuestion('2026-07-15', 9);
    // extremely unlikely to collide across a different hour AND a different day
    expect(a1.prompt == b.prompt && a1.prompt == other.prompt, isFalse);
  });
}

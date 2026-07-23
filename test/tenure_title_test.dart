import 'package:flutter_test/flutter_test.dart';
import 'package:reflex_duel/core/state.dart';

// Tenure titles must unlock at the right day thresholds and always report the
// HIGHEST rank reached — this is what gates MYND Wrapped and drives the
// journey timeline, so an off-by-one here would show the wrong rank. There's
// no "Rookie"/pre-rank state — every player is at least a Beginner from day 0.
void main() {
  test('MyndTitle.forDays crosses each milestone correctly', () {
    expect(MyndTitle.forDays(0), MyndTitle.beginner);
    expect(MyndTitle.forDays(29), MyndTitle.beginner);
    expect(MyndTitle.forDays(30), MyndTitle.practitioner);
    expect(MyndTitle.forDays(89), MyndTitle.practitioner);
    expect(MyndTitle.forDays(90), MyndTitle.challenger);
    expect(MyndTitle.forDays(179), MyndTitle.challenger);
    expect(MyndTitle.forDays(180), MyndTitle.hustler);
    expect(MyndTitle.forDays(9999), MyndTitle.hustler); // caps at max
  });

  test('next points to the following rank, null at the top', () {
    expect(MyndTitle.beginner.next, MyndTitle.practitioner);
    expect(MyndTitle.challenger.next, MyndTitle.hustler);
    expect(MyndTitle.hustler.next, isNull);
  });

  test('every title carries real card artwork', () {
    for (final t in MyndTitle.values) {
      expect(t.asset, startsWith('assets/mynd_cards/'));
      expect(t.asset, endsWith('.jpg'));
    }
  });
}

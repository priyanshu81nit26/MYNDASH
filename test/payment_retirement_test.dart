import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reflex_duel/screens/ai_coach.dart';
import 'package:reflex_duel/screens/pro_screen.dart';
import 'package:reflex_duel/screens/store_screen.dart';
import 'package:reflex_duel/services/account_service.dart';
import 'package:reflex_duel/services/payments.dart';
import 'package:reflex_duel/theme_district.dart';

void main() {
  test('paid memberships do not gate features or arena hosting', () {
    expect(requirePro, isNotNull);
    expect(AccountService.privateHostCap(), 100);
    expect(AccountService.publicHostCap(), 128);
    expect(Payments.live, isFalse);
  });

  testWidgets('AI Trainer is presented as free for every player',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: districtTheme(),
        home: const AiCoachScreen(),
      ),
    );
    await tester.pump();

    expect(find.text('AI TRAINER'), findsOneWidget);
    expect(find.text('FREE · LOCAL'), findsOneWidget);
    expect(find.text('PRO'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Store is preview-only with no checkout prices or order tab',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: districtTheme(),
        home: const Scaffold(body: StoreTab()),
      ),
    );
    await tester.pump();

    expect(find.text('UPCOMING'), findsWidgets);
    expect(find.text('COINS'), findsOneWidget);
    expect(find.text('REWARDS'), findsOneWidget);
    expect(find.textContaining('₹'), findsNothing);
    expect(find.text('ORDERS'), findsNothing);
    expect(find.textContaining('Buy'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

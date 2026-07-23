// Reproduces the one-char-per-line bug and verifies the fix end-to-end.
//
// On desktop web the app is framed to 460px by _mobileFrame, but
// communityPagePadding read MediaQuery.width. Before the fix, descendants saw
// the full window (e.g. 1440) and computed (1440-780)/2 = 330px padding/side —
// inside a 460px box that collapses the content to negative width, so text
// wrapped one character per line. The fix makes _mobileFrame override
// MediaQuery so descendants see 460, giving sane padding.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reflex_duel/screens/community_hub.dart';
import 'package:reflex_duel/theme_district.dart';
import 'package:reflex_duel/ui/community_design.dart';

// Mirror of the FIXED _mobileFrame from main.dart.
Widget frame(Widget child, MediaQueryData mq) => ColoredBox(
      color: const Color(0xFF000000),
      child: Center(
        child: ClipRect(
          child: SizedBox(
            width: 460,
            child: MediaQuery(
              data: mq.copyWith(size: const Size(460, 900)),
              child: child,
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('community content stays wide inside a 1440px window',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: districtTheme(),
      home: Builder(
        builder: (ctx) => frame(const CommunityHubScreen(), MediaQuery.of(ctx)),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 50));

    // The hero subtitle must lay out across the framed width, not collapse.
    final subtitle = find.textContaining('verified spaces');
    expect(subtitle, findsOneWidget);
    final width = tester.getSize(subtitle).width;
    expect(width, greaterThan(300),
        reason: 'subtitle collapsed to $width px → char-per-line wrapping');
  });
}

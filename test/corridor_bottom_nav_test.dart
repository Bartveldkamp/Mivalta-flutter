// BS-017 stage 2 — golden corridor invariant #1: BOTTOM NAV.
//
// `MivaltaBottomNav` (the TYPE, not BottomNavigationBar) is present on the
// three REAL tab screens (Today / Journey / You), pumped headless with the
// stage-1 binding seam + fakes, with three tabs carrying the exact labels
// and the correct active tab per screen.
//
// Tab styling/callback internals are already pinned in
// test/mivalta_bottom_nav_test.dart — this file asserts only the corridor
// contract (the nav is ON each real screen), not the widget internals.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mivalta_flutter/screens/journey_screen.dart';
import 'package:mivalta_flutter/screens/today_screen.dart';
import 'package:mivalta_flutter/screens/you_screen.dart';
import 'package:mivalta_flutter/widgets/mivalta_bottom_nav.dart';

import 'support/fake_engine_binding.dart';
import 'support/headless_env.dart';

void main() {
  /// The corridor contract for one screen: the nav TYPE is present, carries
  /// exactly the three tab labels, and marks [expectedActive] as active.
  void expectCorridorNav(WidgetTester tester, NavTab expectedActive) {
    final navFinder = find.byType(MivaltaBottomNav);
    expect(navFinder, findsOneWidget,
        reason: 'MivaltaBottomNav must be present (the TYPE — '
            'not BottomNavigationBar)');

    final nav = tester.widget<MivaltaBottomNav>(navFinder);
    expect(nav.activeTab, expectedActive,
        reason: 'the screen must mark its own tab active');

    for (final label in const ['Today', 'Journey', 'You']) {
      expect(
        find.descendant(of: navFinder, matching: find.text(label)),
        findsOneWidget,
        reason: 'nav must carry the exact tab label "$label"',
      );
    }
  }

  testWidgets('TodayScreen renders MivaltaBottomNav with today active',
      (tester) async {
    await installHeadlessEnv(tester, profileJson: kTestProfileJson);
    useTallTestViewport(tester);
    final binding = FakeEngineBinding(canned: cannedCorridorDefaults());

    await tester.pumpWidget(MaterialApp(
      home: TodayScreen(binding: binding, handle: binding.handle),
    ));
    await pumpUntilLoaded(tester);

    expectCorridorNav(tester, NavTab.today);
  });

  testWidgets('JourneyScreen renders MivaltaBottomNav with journey active',
      (tester) async {
    await installHeadlessEnv(tester, profileJson: kTestProfileJson);
    useTallTestViewport(tester);
    final binding = FakeEngineBinding(canned: cannedCorridorDefaults());

    await tester.pumpWidget(MaterialApp(
      home: JourneyScreen(binding: binding, handle: binding.handle),
    ));
    await pumpUntilLoaded(tester);

    expectCorridorNav(tester, NavTab.journey);
  });

  testWidgets('YouScreen renders MivaltaBottomNav with you active',
      (tester) async {
    await installHeadlessEnv(tester, profileJson: kTestProfileJson);
    useTallTestViewport(tester);
    final binding = FakeEngineBinding(canned: cannedCorridorDefaults());

    await tester.pumpWidget(MaterialApp(
      home: YouScreen(binding: binding, handle: binding.handle),
    ));
    await pumpUntilLoaded(tester);

    expectCorridorNav(tester, NavTab.you);
  });
}

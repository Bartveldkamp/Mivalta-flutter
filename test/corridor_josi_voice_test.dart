// BS-017 stage 2 — golden corridor invariant #4: JOSI VOICE CARD.
//
// On the REAL TodayScreen with the fake binding:
//   * the rendered Josi line is the engine's VERBATIM string (canned
//     RealizedLine JSON in → exact text out, safety items included);
//   * engine failure on the realize seam → the honest fallback (the
//     engine's own state_recommendation — never a Dart-composed line);
//   * degraded == normal: a degraded RealizedLine renders IDENTICALLY
//     (same style, no extra error chrome).
//
// Complements test/josi_card_degraded_test.dart (widget-level JosiCard
// contract) — this file pins the same rules through the full screen +
// binding-seam path, without duplicating the card's internals.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mivalta_flutter/screens/today_screen.dart';
import 'package:mivalta_flutter/widgets/today/josi_card.dart';

import 'support/fake_engine_binding.dart';
import 'support/headless_env.dart';

const String kVerbatimLine =
    'Legs say yes today - one quality block, then ease off.';
const String kVerbatimSafety = 'Keep an eye on sleep tonight.';

String realizedLineJson({required bool degraded}) =>
    '{"text":"$kVerbatimLine","safety":["$kVerbatimSafety"],'
    '"degraded":$degraded}';

Future<void> pumpToday(
  WidgetTester tester, {
  Map<String, Object> cannedOverrides = const {},
}) async {
  await installHeadlessEnv(tester, profileJson: kTestProfileJson);
  useTallTestViewport(tester);
  final binding = FakeEngineBinding(
    canned: {...cannedCorridorDefaults(), ...cannedOverrides},
  );
  await tester.pumpWidget(MaterialApp(
    home: TodayScreen(binding: binding, handle: binding.handle),
  ));
  await pumpUntilLoaded(tester);
}

/// The style of the rendered headline text inside the JosiCard.
TextStyle? josiLineStyle(WidgetTester tester, String line) {
  final finder = find.descendant(
      of: find.byType(JosiCard), matching: find.text(line));
  expect(finder, findsOneWidget);
  return tester.widget<Text>(finder).style;
}

void main() {
  testWidgets('the Josi line is the engine string VERBATIM',
      (tester) async {
    await pumpToday(tester, cannedOverrides: {
      'realizeAdvisorLine': realizedLineJson(degraded: false),
    });

    expect(find.byType(JosiCard), findsOneWidget);
    expect(
      find.descendant(
          of: find.byType(JosiCard), matching: find.text(kVerbatimLine)),
      findsOneWidget,
      reason: 'canned engine text in → exact text out — no interpolation, '
          'no truncation, no case changes',
    );
    expect(
      find.descendant(
          of: find.byType(JosiCard), matching: find.text(kVerbatimSafety)),
      findsOneWidget,
      reason: 'engine safety items always render, verbatim',
    );
  });

  testWidgets(
      'engine failure on realize seam → honest fallback: the engine\'s own '
      'state_recommendation, verbatim', (tester) async {
    await pumpToday(tester, cannedOverrides: {
      'realizeAdvisorLine': const EngineCallFailure('firewall refused'),
    });

    expect(find.byType(JosiCard), findsOneWidget,
        reason: 'the card falls back, it does not vanish');
    // The fallback is kCannedStateAdvisory's state_recommendation — an
    // ENGINE string, never a Dart-composed one.
    expect(
      find.descendant(
          of: find.byType(JosiCard),
          matching:
              find.text('Body is absorbing the work. Keep today light.')),
      findsOneWidget,
      reason: 'fallback line == engine state_recommendation, verbatim',
    );
    expect(find.text(kVerbatimLine), findsNothing,
        reason: 'the failed realize line must not appear from anywhere');
  });

  testWidgets('degraded render == normal render (no extra chrome)',
      (tester) async {
    // Normal pass.
    await pumpToday(tester, cannedOverrides: {
      'realizeAdvisorLine': realizedLineJson(degraded: false),
    });
    final normalStyle = josiLineStyle(tester, kVerbatimLine);
    final normalCardTextCount = find
        .descendant(of: find.byType(JosiCard), matching: find.byType(Text))
        .evaluate()
        .length;

    // Degraded pass — same text, degraded:true.
    await pumpToday(tester, cannedOverrides: {
      'realizeAdvisorLine': realizedLineJson(degraded: true),
    });
    final degradedStyle = josiLineStyle(tester, kVerbatimLine);
    final degradedCardTextCount = find
        .descendant(of: find.byType(JosiCard), matching: find.byType(Text))
        .evaluate()
        .length;

    expect(degradedStyle?.color, normalStyle?.color,
        reason: 'degraded line colour must equal normal');
    expect(degradedStyle?.fontSize, normalStyle?.fontSize,
        reason: 'degraded line size must equal normal');
    expect(degradedStyle?.fontWeight, normalStyle?.fontWeight,
        reason: 'degraded line weight must equal normal');
    expect(degradedCardTextCount, normalCardTextCount,
        reason: 'no extra chrome on the sad path — same text-node count');
    expect(find.textContaining('degraded'), findsNothing);
    expect(find.textContaining('limited'), findsNothing);
  });
}

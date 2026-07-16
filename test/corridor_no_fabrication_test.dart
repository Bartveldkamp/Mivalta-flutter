// BS-017 stage 2 — golden corridor invariant #3: NO FABRICATED VALUES.
//
// A rendered readiness score exists ONLY when the engine JSON carries one.
// Engine absence → honest absence: no number, no placeholder, never a
// composed value. Covered on the REAL TodayScreen, both absence paths:
//   * no stored profile at all (the profileJson == null early return);
//   * a profile PLUS the engine's explicit no-data verdict via canned JSON
//     (readiness_indicator with confidence 0 — the documented cold-start
//     contract) — the score field says 0 but confidence 0 gates it, so
//     even that 0 must NOT render as a number.
//
// SPEC DELTA (flagged, verified against lib/widgets/today/glow_hero.dart
// this session): the hero renders `'${widget.score}'` BARE — there is no
// '%' suffix, so the spec's `(\d+)\s*%` regex matches nothing real. The true
// format is pinned below instead. There is also NO Dart-side clamp on the
// readiness score (Dart is display-only — a clamp would be math in Dart);
// the 0–100 range is the ENGINE's contract (readiness_indicator, FFI
// contract §7). What Dart owes — and what is pinned — is VERBATIM rendering:
// the number on screen is exactly the engine's value, never composed,
// never exceeding 100 for any in-contract engine payload.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mivalta_flutter/screens/today_screen.dart';
import 'package:mivalta_flutter/widgets/today/glow_hero.dart';

import 'support/fake_engine_binding.dart';
import 'support/headless_env.dart';

/// All Text contents rendered inside the glow hero.
Iterable<String> heroTexts(WidgetTester tester) => tester
    .widgetList<Text>(find.descendant(
        of: find.byType(GlowHero), matching: find.byType(Text)))
    .map((w) => w.data ?? '');

/// Bare-integer texts inside the hero (the score render format).
Iterable<int> heroNumbers(WidgetTester tester) => heroTexts(tester)
    .where((t) => RegExp(r'^\d+$').hasMatch(t))
    .map(int.parse);

Future<FakeEngineBinding> pumpToday(
  WidgetTester tester, {
  required String? profileJson,
  Map<String, Object> cannedOverrides = const {},
}) async {
  await installHeadlessEnv(tester, profileJson: profileJson);
  useTallTestViewport(tester);
  final binding = FakeEngineBinding(
    canned: {...cannedCorridorDefaults(), ...cannedOverrides},
  );
  await tester.pumpWidget(MaterialApp(
    home: TodayScreen(binding: binding, handle: binding.handle),
  ));
  await pumpUntilLoaded(tester);
  return binding;
}

void main() {
  testWidgets('no stored profile → honest absence: no number in the hero',
      (tester) async {
    final binding = await pumpToday(tester, profileJson: null);

    expect(find.byType(GlowHero), findsOneWidget);
    expect(heroNumbers(tester), isEmpty,
        reason: 'no profile → no engine data → NO number may render');
    expect(find.text('Learning'), findsOneWidget,
        reason: 'the honest absent-hero label');
    expect(binding.calls, isEmpty,
        reason: 'the no-profile early return never reaches the engine — '
            'nothing to fabricate from');
  });

  testWidgets(
      'engine no-data verdict (confidence 0) → no number rendered, '
      'not even the verdict\'s own 0', (tester) async {
    await pumpToday(tester, profileJson: kTestProfileJson, cannedOverrides: {
      'readinessIndicator': kCannedIndicatorNoData,
      // Honest-empty prose surfaces alongside the no-data verdict.
      'stateAdvisory':
          '{"state_recommendation":"","confidence_advisory":""}',
      'realizeAdvisorLine': const EngineCallFailure('no line yet'),
      'viterbiFatigueState': '{}',
    });

    expect(find.byType(GlowHero), findsOneWidget);
    expect(heroNumbers(tester), isEmpty,
        reason: 'confidence 0 is the engine\'s no-data gate — rendering the '
            'placeholder 0 as a score would be a fabricated value');
    expect(find.text('0'), findsNothing,
        reason: 'the verdict\'s score:0 must never surface as a number');
    expect(find.text('Learning'), findsOneWidget,
        reason: 'honest absent-hero label when no score and no state word');
  });

  testWidgets('score present in engine JSON → it renders, verbatim',
      (tester) async {
    await pumpToday(tester, profileJson: kTestProfileJson);

    // cannedCorridorDefaults pins readiness_indicator score 87.
    expect(
      find.descendant(of: find.byType(GlowHero), matching: find.text('87')),
      findsOneWidget,
      reason: 'engine says 87 → the hero shows 87',
    );
  });

  testWidgets(
      'render format pin: bare integer, no % suffix, value never above 100 '
      '(spec-delta: the (\\d+)\\s*% regex assumption is wrong)',
      (tester) async {
    await pumpToday(tester, profileJson: kTestProfileJson, cannedOverrides: {
      // The engine contract's top of range.
      'readinessIndicator':
          '{"score":100.0,"level":"green","confidence":0.9,'
              '"contributions":[]}',
    });

    final numbers = heroNumbers(tester).toList();
    expect(numbers, [100],
        reason: 'exactly one score, rendered as the bare integer "100"');
    for (final n in numbers) {
      expect(n, lessThanOrEqualTo(100),
          reason: 'the rendered score never exceeds 100 for an in-contract '
              'engine payload (0-100 is the engine\'s range)');
    }
    expect(
      heroTexts(tester).any((t) => t.contains('%')),
      isFalse,
      reason: 'TRUE format is bare — glow_hero.dart renders '
          r"'${widget.score}' with no % suffix",
    );
  });
}

// BS-017 stage 2 — golden corridor invariant #5: TODAY EVENING SWAP.
//
// Through the DR-026 clock seam (`TodayScreen(now: ...)`) on the REAL screen
// with the fake binding:
//   * past the 19:00 threshold → the CLOSING THE DAY eyebrow + the
//     day-summary JosiCard appear, the workout-suggestion card does not;
//   * before the threshold → neither eyebrow nor summary (and the summary
//     seam is never even called), the workout card is back;
//   * the summary line is the ENGINE's line, verbatim — never composed in
//     Dart. Engine failure → the honest fallback.
//
// Complements test/evening_swap_test.dart, which pins the threshold constant
// and the JosiCard component behaviour in isolation — this file closes the
// invariant on the full screen through the binding seam.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mivalta_flutter/screens/today_screen.dart';
import 'package:mivalta_flutter/widgets/today/josi_card.dart';

import 'support/fake_engine_binding.dart';
import 'support/headless_env.dart';

const String kSummaryLine = 'Two sessions banked. Tomorrow asks for ease.';
const String kSummaryJson =
    '{"text":"$kSummaryLine","safety":[],"degraded":false}';

Future<FakeEngineBinding> pumpTodayAt(
  WidgetTester tester,
  DateTime now, {
  Map<String, Object> cannedOverrides = const {},
}) async {
  await installHeadlessEnv(tester, profileJson: kTestProfileJson);
  useTallTestViewport(tester);
  final binding = FakeEngineBinding(
    canned: {...cannedCorridorDefaults(), ...cannedOverrides},
  );
  await tester.pumpWidget(MaterialApp(
    home: TodayScreen(
      now: () => now,
      binding: binding,
      handle: binding.handle,
    ),
  ));
  await pumpUntilLoaded(tester);
  return binding;
}

void main() {
  // 20:00 is past the pinned 19:00 threshold; 10:00 is before it.
  final evening = DateTime(2026, 7, 16, 20, 0);
  final morning = DateTime(2026, 7, 16, 10, 0);

  testWidgets(
      'past threshold → CLOSING THE DAY eyebrow + day-summary JosiCard, '
      'engine line verbatim, workout card swapped out', (tester) async {
    await pumpTodayAt(tester, evening, cannedOverrides: {
      'realizeDaySummary': kSummaryJson,
    });

    expect(find.text('CLOSING THE DAY'), findsOneWidget,
        reason: 'the evening eyebrow appears past $kEveningThresholdHour:00');
    expect(
      find.descendant(
          of: find.byType(JosiCard), matching: find.text(kSummaryLine)),
      findsOneWidget,
      reason: 'the day summary is the engine line VERBATIM, in a JosiCard',
    );
    expect(find.text('Suggested workout'), findsNothing,
        reason: 'evening swaps the workout suggestion out');
  });

  testWidgets(
      'before threshold → no eyebrow, no summary, seam not even called, '
      'workout card present', (tester) async {
    final binding = await pumpTodayAt(tester, morning, cannedOverrides: {
      'realizeDaySummary': kSummaryJson,
    });

    expect(find.text('CLOSING THE DAY'), findsNothing,
        reason: 'no evening eyebrow before the threshold');
    expect(find.text(kSummaryLine), findsNothing,
        reason: 'no day summary before the threshold');
    expect(binding.calls, isNot(contains('realizeDaySummary')),
        reason: 'the screen must not fetch a summary during the day — '
            'the engine line cannot leak in early');
    expect(find.text('Suggested workout'), findsOneWidget,
        reason: 'daytime shows the workout suggestion card');
  });

  testWidgets(
      'evening + engine failure on the summary seam → honest fallback line',
      (tester) async {
    await pumpTodayAt(tester, evening, cannedOverrides: {
      'realizeDaySummary': const EngineCallFailure('no data for date'),
    });

    expect(find.text('CLOSING THE DAY'), findsOneWidget);
    expect(find.text(kSummaryLine), findsNothing,
        reason: 'a failed seam must never surface the engine line');
    // The screen's pinned honest fallback (today_screen.dart) — shown in
    // the same JosiCard, no error chrome.
    expect(
      find.descendant(
          of: find.byType(JosiCard),
          matching: find.text('Your day is winding down.')),
      findsOneWidget,
    );
    expect(find.textContaining('degraded'), findsNothing);
  });
}

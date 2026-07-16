// BS-017 stage 2 — golden corridor invariant #6: JOURNEY DAY RECORD.
//
// The REAL JourneyScreen, pumped headless with the fake binding, renders the
// day-record card through the SAME JosiCard contract as invariants #4/#5:
//   * canned realize_day_summary JSON in → the TODAY section with a JosiCard
//     carrying the engine line VERBATIM;
//   * engine failure → honest absence: no TODAY section, no JosiCard, no
//     fallback fabricated (Journey hides the section entirely — unlike the
//     Today evening slot, there is no fallback line here by design).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mivalta_flutter/screens/journey_screen.dart';
import 'package:mivalta_flutter/widgets/today/josi_card.dart';

import 'support/fake_engine_binding.dart';
import 'support/headless_env.dart';

const String kDayRecordLine =
    'You showed up today. The vault remembers the ride.';
const String kDayRecordSafety = 'Ease into tomorrow.';
const String kDayRecordJson =
    '{"text":"$kDayRecordLine","safety":["$kDayRecordSafety"],'
    '"degraded":false}';

Future<FakeEngineBinding> pumpJourney(
  WidgetTester tester, {
  Map<String, Object> cannedOverrides = const {},
}) async {
  await installHeadlessEnv(tester, profileJson: kTestProfileJson);
  useTallTestViewport(tester);
  final binding = FakeEngineBinding(
    canned: {...cannedCorridorDefaults(), ...cannedOverrides},
  );
  await tester.pumpWidget(MaterialApp(
    home: JourneyScreen(binding: binding, handle: binding.handle),
  ));
  await pumpUntilLoaded(tester);
  return binding;
}

void main() {
  testWidgets(
      'day record renders the engine line VERBATIM in a JosiCard under '
      'the TODAY eyebrow', (tester) async {
    await pumpJourney(tester, cannedOverrides: {
      'realizeDaySummary': kDayRecordJson,
    });

    expect(find.text('TODAY'), findsOneWidget,
        reason: 'the day-record section eyebrow');
    expect(find.byType(JosiCard), findsOneWidget,
        reason: 'the day record reuses the SAME JosiCard renderer as '
            'invariants #4/#5 — one voice presenter, not a parallel one');
    expect(
      find.descendant(
          of: find.byType(JosiCard), matching: find.text(kDayRecordLine)),
      findsOneWidget,
      reason: 'the engine line, verbatim',
    );
    expect(
      find.descendant(
          of: find.byType(JosiCard), matching: find.text(kDayRecordSafety)),
      findsOneWidget,
      reason: 'engine safety items always render, verbatim',
    );
  });

  testWidgets(
      'engine failure on the summary seam → honest absence: no TODAY '
      'section, no JosiCard, nothing composed in Dart', (tester) async {
    final binding = await pumpJourney(tester, cannedOverrides: {
      'realizeDaySummary': const EngineCallFailure('no data for date'),
    });

    expect(binding.calls, contains('realizeDaySummary'),
        reason: 'the seam WAS asked — absence comes from the engine, '
            'not from skipping the call');
    expect(find.text('TODAY'), findsNothing,
        reason: 'no engine line → the whole section collapses');
    expect(find.byType(JosiCard), findsNothing,
        reason: 'no fallback card is fabricated on Journey');
    expect(find.text(kDayRecordLine), findsNothing);
  });
}

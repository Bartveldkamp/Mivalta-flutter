// Overflow regression pins (final integration audit, 2026-07-16).
//
// The headless real-engine audit surfaced two RenderFlex overflows that only
// REAL engine payloads trigger (canned fixtures were too short):
//   1. AdvisorScreen._buildSpecsRow — specs + long tag list ("aerobic
//      endurance · aerobic efficiency") overflowed 54–68px.
//   2. JourneyScreen._rollupColumn row — long level labels ("Aerobic
//      endurance") in a half-width column overflowed 61px.
// Both fixed by ellipsizing the LABEL half, never the engine's number. These
// tests pump the screens at phone width with payloads shaped exactly like the
// real engine's (values copied from the audit run) — an overflow throws a
// FlutterError and fails the test.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mivalta_flutter/models/workout_option.dart';
import 'package:mivalta_flutter/screens/advisor_screen.dart';
import 'package:mivalta_flutter/screens/journey_screen.dart';

import 'support/fake_engine_binding.dart';
import 'support/headless_env.dart';

/// Phone-narrow viewport (iPhone 13 logical size) — the overflow reproduces
/// at real widths, not the default 800×600 test surface.
void usePhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets(
      'Advisor specs row: real-length tags do not overflow at phone width',
      (tester) async {
    await installHeadlessEnv(tester, profileJson: kTestProfileJson);
    usePhoneViewport(tester);

    // Shaped like the real engine option from the audit run: long tag list +
    // full specs. The sentence/tags lengths are the trigger.
    final option = WorkoutOption.fromJson(const {
      'title': 'Endurance Ride',
      'zone': 'Z2',
      'duration_min': 70,
      'target_watts': 163,
      'why': 'Aerobic base day — steady and sustainable.',
      'tags': ['aerobic endurance', 'aerobic efficiency', 'fat oxidation'],
      'coach_sentence':
          'Today your workout is aerobic endurance, aerobic efficiency, a Z2 '
              'workout in 70\' steady at 138–188 W. Comfortable. Slight effort '
              'but sustainable for hours. Long sentences possible.',
    });

    final binding = FakeEngineBinding(canned: cannedCorridorDefaults());
    await tester.pumpWidget(MaterialApp(
      home: AdvisorScreen(
        options: [option],
        binding: binding,
        handle: binding.handle,
        readinessLevel: 'Green',
      ),
    ));
    await pumpUntilLoaded(tester);
    // Completing without a RenderFlex overflow exception IS the assertion.
    expect(find.text('Endurance Ride'), findsWidgets);
  });

  testWidgets(
      'Journey rollup rows: real-length level labels do not overflow at '
      'phone width', (tester) async {
    await installHeadlessEnv(tester, profileJson: kTestProfileJson);
    usePhoneViewport(tester);

    // The exact rollup shape the real engine returned in the audit run —
    // long level keys with non-zero minutes in the half-width column.
    final binding = FakeEngineBinding(canned: {
      ...cannedCorridorDefaults(),
      'metabolicTimeInZoneRollup':
          '{"aerobic_base":1860.0,"aerobic_endurance":1740.0,"tempo":0.0,'
              '"threshold":0.0,"vo2max":0.0,"anaerobic_neuro":0.0,'
              '"unclassified":0.0}',
    });
    await tester.pumpWidget(MaterialApp(
      home: JourneyScreen(binding: binding, handle: binding.handle),
    ));
    await pumpUntilLoaded(tester);
    expect(find.byType(JourneyScreen), findsOneWidget);
  });
}

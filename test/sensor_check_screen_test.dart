// Step 4 (HOME_REDESIGN_BRIEF §4 item 5, §6): the sensor-check screen shows
// HONEST states only — no BLE/GPS plumbing exists, so "Not connected" /
// "coming" are the only truthful rows. The live-start action stays disabled
// until the staged live screen lands; manual logging is the working capture
// path so the screen is never a dead end.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mivalta_flutter/screens/sensor_check_screen.dart';
import 'package:mivalta_flutter/theme/tokens.dart';

Future<void> _pump(WidgetTester tester, {VoidCallback? onLogManually}) =>
    tester.pumpWidget(MaterialApp(
      theme: mivaltaDarkTheme(),
      home: SensorCheckScreen(onLogManually: onLogManually),
    ));

void main() {
  group('SensorCheckScreen — honest sensor states', () {
    testWidgets('renders "Not connected" HR and staged GPS rows, never a '
        'fabricated connected state', (tester) async {
      await _pump(tester);

      expect(find.text(kSensorHrLabel), findsOneWidget);
      expect(find.text(kSensorHrNotConnectedCopy), findsOneWidget);
      expect(find.text(kSensorGpsLabel), findsOneWidget);
      expect(find.text(kSensorGpsStagedCopy), findsOneWidget);

      // No fabricated states: nothing claims to be connected or scanning.
      expect(find.textContaining('Connected'), findsNothing);
      expect(find.textContaining('Scanning'), findsNothing);
      expect(find.textContaining('Searching'), findsNothing);
    });
  });

  group('SensorCheckScreen — staged live start', () {
    testWidgets('live-start button is disabled with the honest staged note',
        (tester) async {
      await _pump(tester);

      expect(find.text(kLiveWorkoutButtonLabel), findsOneWidget);
      expect(find.text(kLiveWorkoutStagedNote), findsOneWidget);

      // The FilledButton (incl. the .icon variant subtype) must be disabled.
      final button = tester.widget<FilledButton>(find.byWidgetPredicate(
        (w) => w is FilledButton,
      ));
      expect(button.onPressed, isNull);
      expect(button.enabled, isFalse);
    });
  });

  // LAST-TWO item 23 (FOUNDER_FEEDBACK_2026-06-12): on start, choose the
  // ACTIVITY — running variants, walking, cycling variants — mapped to the
  // engine's activity_type strings for THE WORKOUT (ingest path).
  // ⚠ FL-17: the profile Sport enum stays cycling/running only (pinned in
  // profile_service_test.dart) — this picker never touches it.
  group('SensorCheckScreen — activity picker (item 23)', () {
    testWidgets('renders the founder list in a horizontal SCROLLER: all '
        'running, walking, all cycling variants under ACTIVITY',
        (tester) async {
      await _pump(tester);

      expect(find.text(kActivitySectionLabel), findsOneWidget);
      expect(find.text('Outdoor run'), findsOneWidget);
      expect(find.text('Trail run'), findsOneWidget);
      expect(find.text('Treadmill run'), findsOneWidget);
      expect(find.text('Walk'), findsOneWidget);
      expect(find.text('Road ride'), findsOneWidget);
      expect(find.text('Indoor ride'), findsOneWidget);
      expect(find.text('Virtual ride'), findsOneWidget);
      expect(find.text('Mountain bike'), findsOneWidget);

      // Night-round polish: the picker is a horizontal scroller, not a
      // wrapped chip cloud.
      final scroller = tester.widget<SingleChildScrollView>(
        find
            .ancestor(
              of: find.text('Outdoor run'),
              matching: find.byType(SingleChildScrollView),
            )
            .first,
      );
      expect(scroller.scrollDirection, Axis.horizontal);

      // Raw engine activity_type strings never reach the user.
      expect(find.text('run'), findsNothing);
      expect(find.text('walk'), findsNothing);
      expect(find.text('ride'), findsNothing);
    });

    testWidgets('first choice selected by default; tapping another moves the '
        'selection (single-select)', (tester) async {
      await _pump(tester);

      // Selection language: green glyph on the chosen card (item-20 subtle
      // selection — the green lives in the glyph and hairline, not a fill).
      Color iconColorFor(String label) => tester
          .widget<Icon>(find.descendant(
            of: find
                .ancestor(of: find.text(label), matching: find.byType(InkWell))
                .first,
            matching: find.byType(Icon),
          ))
          .color!;

      expect(iconColorFor('Outdoor run'), MivaltaColors.primaryGreen);
      expect(iconColorFor('Mountain bike'), MivaltaColors.textMuted);

      // The last card sits off the right edge of the scroller — bring it in.
      await tester.ensureVisible(find.text('Mountain bike'));
      await tester.tap(find.text('Mountain bike'));
      await tester.pumpAndSettle();

      expect(iconColorFor('Mountain bike'), MivaltaColors.primaryGreen);
      expect(iconColorFor('Outdoor run'), MivaltaColors.textMuted);
    });

    test('engine contract: variants map to the ingest path activity_type '
        'strings health_ingest already writes — never invented', () {
      String typeOf(String label) => kActivityChoices
          .firstWhere((c) => c.label == label)
          .activityType;

      // Running family → 'run' (variant = display distinction only).
      expect(typeOf('Outdoor run'), 'run');
      expect(typeOf('Trail run'), 'run');
      expect(typeOf('Treadmill run'), 'run');
      // Walking → 'walk' (engine allowlist via universal baseline, FL-17).
      expect(typeOf('Walk'), 'walk');
      // Cycling family → 'ride'.
      expect(typeOf('Road ride'), 'ride');
      expect(typeOf('Indoor ride'), 'ride');
      expect(typeOf('Virtual ride'), 'ride');
      expect(typeOf('Mountain bike'), 'ride');

      // The full set is exactly the verified base strings — nothing else.
      expect(
        kActivityChoices.map((c) => c.activityType).toSet(),
        {'run', 'walk', 'ride'},
      );
    });
  });

  group('SensorCheckScreen — manual capture path', () {
    testWidgets('tapping "Log a workout manually" fires the callback',
        (tester) async {
      var fired = 0;
      await _pump(tester, onLogManually: () => fired++);

      // The activity picker (item 23) sits above; bring the button into view.
      await tester.ensureVisible(find.text(kLogManuallyButtonLabel));
      await tester.tap(find.text(kLogManuallyButtonLabel));
      await tester.pumpAndSettle();
      expect(fired, 1);
    });

    testWidgets('without a callback the manual action is absent (no dead tap '
        'target)', (tester) async {
      await _pump(tester);
      expect(find.text(kLogManuallyButtonLabel), findsNothing);
    });
  });
}

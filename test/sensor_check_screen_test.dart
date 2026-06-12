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

  group('SensorCheckScreen — manual capture path', () {
    testWidgets('tapping "Log a workout manually" fires the callback',
        (tester) async {
      var fired = 0;
      await _pump(tester, onLogManually: () => fired++);

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

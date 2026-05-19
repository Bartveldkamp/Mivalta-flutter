// Smoke test for the merged spike home screen — covers both the
// Day-1 V10.1 chat UI (model bootstrap → TextField → Run → latency
// labels) and the Day-2 rust-engine bridge status line. Neither the
// V10.1 model bootstrap nor `RustLib.init()` works on the host test
// harness, so this test only inspects the initial widget tree.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mivalta_flutter/main.dart';

void main() {
  testWidgets(
    'SpikeHome renders Day-1 chat UI and Day-2 engine-hello status',
    (WidgetTester tester) async {
      await tester.pumpWidget(const PerfSpikeApp());
      // Render one frame only — both bootstraps are in flight, do
      // not settle (native libraries are not loadable in the host
      // harness).
      await tester.pump();

      // --- Day-1 assertions ---------------------------------------

      // Default prompt text appears in the TextField's editing controller.
      final textFinder = find.byType(TextField);
      expect(textFinder, findsOneWidget);
      final field = tester.widget<TextField>(textFinder);
      expect(field.controller?.text, 'Should I train today?');

      // Run button exists and starts disabled while the model is
      // still being checked (stage = checking → canRun = false).
      final runFinder = find.widgetWithText(ElevatedButton, 'Run');
      expect(runFinder, findsOneWidget);
      expect(tester.widget<ElevatedButton>(runFinder).onPressed, isNull);

      // Two latency labels render placeholders before any run completes.
      expect(find.text('TTFT: - ms'), findsOneWidget);
      expect(find.text('Total: - ms'), findsOneWidget);

      // --- Day-2 assertion ----------------------------------------

      // The rust-engine bridge result line is present. Bootstrap is
      // still in flight on the first frame, so the placeholder copy
      // is rendered. Once the bridge succeeds on device the same
      // widget will display `Engine hello: hello`.
      expect(find.text('Engine hello: (loading)'), findsOneWidget);
    },
  );
}

// Smoke test for the V10.1 perf spike home screen.
//
// The model bootstrap (path_provider + http + sha256) starts in initState
// and runs asynchronously off the first frame, so this test only inspects
// the initial widget tree to keep it offline and deterministic.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mivalta_flutter/main.dart';

void main() {
  testWidgets(
    'SpikeHome renders default prompt, Run button, and latency labels',
    (WidgetTester tester) async {
      await tester.pumpWidget(const PerfSpikeApp());
      // Render one frame only — bootstrap is still in flight, do not settle.
      await tester.pump();

      // Default prompt text appears in the TextField's editing controller.
      final textFinder = find.byType(TextField);
      expect(textFinder, findsOneWidget);
      final field = tester.widget<TextField>(textFinder);
      expect(field.controller?.text, 'Should I train today?');

      // Run button exists and starts disabled while the model is still being
      // checked (stage = checking → canRun = false).
      final runFinder = find.widgetWithText(ElevatedButton, 'Run');
      expect(runFinder, findsOneWidget);
      expect(tester.widget<ElevatedButton>(runFinder).onPressed, isNull);

      // Two latency labels render placeholders before any run completes.
      expect(find.text('TTFT: - ms'), findsOneWidget);
      expect(find.text('Total: - ms'), findsOneWidget);
    },
  );
}

// Smoke test for the Day-3 smoketest screen's initial render. FFI is
// gated on Platform.isAndroid; on the host harness "Run smoketest"
// would short-circuit on UnsupportedError, so this test only inspects
// the pre-tap UI shape.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mivalta_flutter/smoketest_screen.dart';

void main() {
  testWidgets(
    'SmoketestScreen renders three sections and a Run button',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: SmoketestScreen()));
      await tester.pump();

      // App-bar title rendered.
      expect(find.text('Day 3 — real-data smoketest'), findsWidgets);

      // Run-smoketest button is the FilledButton entry point.
      expect(find.widgetWithText(FilledButton, 'Run smoketest'),
          findsOneWidget);

      // The three section headers are present even before any run.
      // ListView lays out children lazily, so include off-stage cards.
      expect(
        find.text('A. Seed (from android-client smoketest)',
            skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.text('B. Rust engine (real call, output as-is)',
            skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.text('C. Josi V10.1 (real prompt, response as-is)',
            skipOffstage: false),
        findsOneWidget,
      );

      // Seed JSON is present and contains the canonical athlete_id from
      // android-client's SmoketestApp.kt — proves the seed wasn't
      // silently swapped for a placeholder.
      expect(
        find.textContaining('"athlete_id":"smoketest-user"',
            skipOffstage: false),
        findsOneWidget,
      );
    },
  );
}

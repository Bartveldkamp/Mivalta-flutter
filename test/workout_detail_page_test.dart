// Tests for the shared WorkoutDetailPage (founder feedback 2026-06-12 item 2).
//
// One detail page for both call sites (home + explore), parsing the REAL
// `get_workout_detail(date)` contract keys defensively: valid JSON renders the
// shared card; JSON `null` (no workout that date) and malformed payloads
// degrade to "unavailable" — never an empty fabricated card, never a crash.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mivalta_flutter/rust_engine.dart';
import 'package:mivalta_flutter/screens/workout_detail_page.dart';
import 'package:mivalta_flutter/theme/tokens.dart';

/// Opaque handle stand-in — never dereferenced by the page.
class _FakeHandle implements EnginesHandle {
  @override
  Object? noSuchMethod(Invocation invocation) => null;
}

/// Binding fake: only `getWorkoutDetail` is exercised by the page.
class _FakeBinding implements RustEngineBinding {
  _FakeBinding(this.response);
  final String response;

  @override
  Future<String> getWorkoutDetail(EnginesHandle handle,
          {required String date}) async =>
      response;

  @override
  Object? noSuchMethod(Invocation invocation) => null;
}

Future<void> _pump(WidgetTester tester, String response) async {
  await tester.pumpWidget(MaterialApp(
    theme: mivaltaDarkTheme(),
    home: WorkoutDetailPage(
      binding: _FakeBinding(response),
      handle: _FakeHandle(),
      date: '2026-06-04',
    ),
  ));
  // Settle the FutureBuilder.
  await tester.pump();
}

void main() {
  group('WorkoutDetailPage', () {
    testWidgets('valid contract JSON → renders the shared card verbatim',
        (tester) async {
      await _pump(
        tester,
        '{"date":"2026-06-04","sport":"cycling","duration_min":60,'
        '"avg_watts":210,"avg_hr":142,"decoupling_pct":4.3,'
        '"efficiency_factor":1.42,"zone_compliance_pct":95.0,'
        '"grade":"Good"}',
      );

      expect(find.text('Cycling'), findsOneWidget);
      expect(find.text('2026-06-04'), findsOneWidget);
      expect(find.text('Good'), findsOneWidget);
      // Engine values verbatim, real contract keys (snake_case).
      expect(find.text('60 min'), findsOneWidget);
      expect(find.text('210W'), findsOneWidget);
      expect(find.text('142 bpm'), findsOneWidget);
      expect(find.text('4.3%'), findsOneWidget);
      expect(find.text('95%'), findsOneWidget);
    });

    testWidgets('JSON `null` (no workout that date) → unavailable, not an '
        'empty card', (tester) async {
      await _pump(tester, 'null');
      expect(find.text('Workout detail unavailable.'), findsOneWidget);
      expect(find.text('Workout'), findsWidgets); // app-bar title only
      expect(find.text('No metrics for this workout.'), findsNothing);
    });

    testWidgets('malformed payload → unavailable, no crash (FL-5)',
        (tester) async {
      await _pump(tester, 'not-json{{');
      expect(find.text('Workout detail unavailable.'), findsOneWidget);
    });
  });
}

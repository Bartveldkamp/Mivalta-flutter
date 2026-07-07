// WorkoutDetailScreen — display of the engine's get_workout_detail composite.
//
// Pins: every engine value the athlete cares about renders (device params +
// the metabolic distribution), and a null field is honest absence — it does
// NOT render and does NOT crash. The engine's numbers are shown as-is; the
// only Dart transform is the documented display formatting (m/s → km/h,
// seconds → minutes for the bar labels), never a re-derivation of physiology.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mivalta_flutter/rust_engine.dart';
import 'package:mivalta_flutter/screens/workout_detail_screen.dart';

class _FakeHandle implements EnginesHandle {
  @override
  Object? noSuchMethod(Invocation invocation) => null;
}

class _DetailBinding implements RustEngineBinding {
  _DetailBinding(this.detailJson);
  final String detailJson;

  @override
  Future<String> getWorkoutDetail(EnginesHandle handle,
          {required String date}) async =>
      detailJson;

  @override
  Object? noSuchMethod(Invocation invocation) => null;
}

Widget _host(RustEngineBinding binding) => MaterialApp(
      home: WorkoutDetailScreen(
        binding: binding,
        handle: _FakeHandle(),
        date: '2026-07-07',
        sportLabel: 'Cycling',
      ),
    );

void main() {
  testWidgets('renders device params + metabolic distribution from the engine',
      (tester) async {
    const json = '''
    {
      "date": "2026-07-07", "sport": "cycling", "duration_min": 62,
      "avg_hr": 141, "grade": "Good",
      "distance_km": 31.0, "calories": 700, "max_hr": 171, "source": "wahoo",
      "avg_power_watts": 215.0, "max_power_watts": 650.0,
      "avg_cadence": 88.0, "elevation_gain_m": 412.0,
      "time_in_zone": {
        "anchor": "power", "total_seconds": 3720.0,
        "seconds": [],
        "metabolic_seconds": {"aerobic_endurance": 3000.0, "threshold": 720.0}
      }
    }''';
    await tester.pumpWidget(_host(_DetailBinding(json)));
    await tester.pumpAndSettle();

    // Device parameters render with their display formatting.
    expect(find.text('215 W'), findsOneWidget); // avg power
    expect(find.text('650 W'), findsOneWidget); // max power
    expect(find.text('88'), findsOneWidget); // cadence
    expect(find.text('412 m'), findsOneWidget); // ascent
    expect(find.text('700'), findsOneWidget); // calories
    // Metabolic distribution: 3000 s → 50 min, 720 s → 12 min.
    expect(find.text('Aerobic endurance'), findsOneWidget);
    expect(find.text('50 min'), findsOneWidget);
    expect(find.text('Threshold'), findsOneWidget);
    expect(find.text('12 min'), findsOneWidget);
    // The grade chip.
    expect(find.text('Good'), findsOneWidget);
  });

  testWidgets('a bare workout renders honest absence, no crash', (tester) async {
    const json = '''
    {"date":"2026-07-08","sport":"running","duration_min":40,"grade":"Ungraded"}
    ''';
    await tester.pumpWidget(_host(_DetailBinding(json)));
    await tester.pumpAndSettle();

    // No device section, no metabolic section — but the screen stands.
    expect(find.text('From your device'), findsNothing);
    expect(find.text('ENERGY SYSTEMS TRAINED'), findsNothing);
    expect(find.text('40 min'), findsOneWidget); // session basics still show
    expect(tester.takeException(), isNull);
  });

  testWidgets('no activity on the day → honest empty message', (tester) async {
    await tester.pumpWidget(_host(_DetailBinding('null')));
    await tester.pumpAndSettle();
    expect(find.text('No workout on this day.'), findsOneWidget);
  });
}

// Tests for the Workout Detail model (UI tests stripped in clean-out).

import 'package:flutter_test/flutter_test.dart';
import 'package:mivalta_flutter/models/workout_detail.dart';

void main() {
  group('WorkoutDetail.fromJson', () {
    test('parses a full cycling workout', () {
      final w = WorkoutDetail.fromJson({
        'date': '2026-06-05',
        'sport': 'cycling',
        'duration_min': 75,
        'avg_watts': 240,
        'avg_hr': 148,
        'decoupling_pct': 4.2,
        'efficiency_factor': 1.82,
        'zone_compliance_pct': 88.0,
        'grade': 'Good',
      });
      expect(w.sport, 'cycling');
      expect(w.durationMin, 75);
      expect(w.avgWatts, 240);
      expect(w.decouplingPct, 4.2);
      expect(w.grade, 'Good');
      expect(w.avgPaceMss, isNull);
    });

    test('non-map → safe empty', () {
      final w = WorkoutDetail.fromJson('nope');
      expect(w.date, '');
      expect(w.durationMin, isNull);
    });
  });
}

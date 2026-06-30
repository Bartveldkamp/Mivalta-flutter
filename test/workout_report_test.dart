// Tests for the Post-Workout Report model (UI tests stripped in clean-out).

import 'package:flutter_test/flutter_test.dart';
import 'package:mivalta_flutter/models/workout_report.dart';

WorkoutReport _sample() => WorkoutReport.fromJson({
      'date': '2026-06-04',
      'sport': 'cycling',
      'zone': 'Z2',
      'duration_min': 60.0,
      'avg_hr': 142,
      'rpe': 5,
      'energy_system': 'aerobic endurance',
      'what_it_builds': 'Aerobic base and fat oxidation.',
      'stimulus_cost_note': 'Low cost, durable stimulus.',
      'quality_summary': 'Zone compliance 95% (on target).',
      'autocue': 'Z2 ride, 60 min.',
    });

void main() {
  group('WorkoutReport.fromJson', () {
    test('parses the engine report shape', () {
      final r = _sample();
      expect(r.zone, 'Z2');
      expect(r.durationMin, 60.0);
      expect(r.avgHr, 142);
      expect(r.rpe, 5);
      expect(r.whatItBuilds, 'Aerobic base and fat oxidation.');
      expect(r.qualitySummary, 'Zone compliance 95% (on target).');
      expect(r.isEmpty, isFalse);
    });

    test('empty / malformed → isEmpty, no fabrication', () {
      expect(WorkoutReport.fromJson(null).isEmpty, isTrue);
      expect(WorkoutReport.fromJson('x').isEmpty, isTrue);
      expect(WorkoutReport.fromJson(const {}).isEmpty, isTrue);
    });
  });
}

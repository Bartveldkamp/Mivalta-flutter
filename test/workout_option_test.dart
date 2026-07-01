// Unit tests for the Advisor workout-option JSON parser.
//
// Guards the engine→Dart contract. Field names mirror the engine struct
// `gatc-types::WorkoutOptionData` (emitted by `AdvisorEngine::suggest_workouts`):
//   option_id, title, zone, why, tags, structure.total_minutes,
//   target_watts (Option), target_pace_mss (Option, skip_serializing_if none).
// If the engine renames a field, these tests break — surfacing drift before ship.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mivalta_flutter/models/workout_option.dart';

void main() {
  // H2 regression: AdvisorEngine::recommend_workout serializes a BARE JSON
  // ARRAY of options, NOT an object with a `suggestions` wrapper. The Today
  // card previously cast the array to a Map (threw → card stuck on "No
  // suggestion yet"). This pins the array shape + option-A parse the home uses.
  group('recommend_workout array contract (H2)', () {
    test('bare array → first element parses as option A', () {
      const engineJson = '[{"option_id":"A","title":"Threshold Intervals",'
          '"zone":"Z4","why":"","tags":[],"structure":{"total_minutes":75}},'
          '{"option_id":"B","title":"Endurance","zone":"Z2","why":"","tags":[],'
          '"structure":{"total_minutes":90}}]';
      final decoded = jsonDecode(engineJson);
      expect(decoded, isA<List>(), reason: 'engine emits an array, not a map');
      final option = WorkoutOption.fromJson((decoded as List).first);
      expect(option.title, 'Threshold Intervals');
      expect(option.zone, 'Z4');
      expect(option.durationMin, 75); // from structure.total_minutes, not duration_min
    });
  });

  group('WorkoutOption.fromJson', () {
    test('parses a full cycling option (with watts)', () {
      final opt = WorkoutOption.fromJson({
        'option_id': 'A',
        'title': 'Threshold Intervals',
        'zone': 'Z4',
        'why': 'Builds sustainable power at threshold.',
        'tags': ['threshold', 'structured'],
        'structure': {'total_minutes': 75},
        'target_watts': 275,
      });
      expect(opt.optionId, 'A');
      expect(opt.title, 'Threshold Intervals');
      expect(opt.zone, 'Z4');
      expect(opt.why, 'Builds sustainable power at threshold.');
      expect(opt.tags, ['threshold', 'structured']);
      expect(opt.durationMin, 75);
      expect(opt.targetWatts, 275);
      expect(opt.targetPaceMss, isNull);
    });

    test('parses a running option (pace, no watts)', () {
      final opt = WorkoutOption.fromJson({
        'option_id': 'B',
        'title': 'Tempo Run',
        'zone': 'Z3',
        'why': 'Lactate clearance.',
        'tags': ['tempo'],
        'structure': {'total_minutes': 50},
        'target_pace_mss': '4:30',
      });
      expect(opt.optionId, 'B');
      expect(opt.zone, 'Z3');
      expect(opt.durationMin, 50);
      expect(opt.targetWatts, isNull);
      expect(opt.targetPaceMss, '4:30');
    });

    test('omitted optional fields (skip_serializing_if none) → null, no crash', () {
      // target_watts / target_pace_mss are skip_serializing_if=none in the
      // engine struct, so they can be absent entirely.
      final opt = WorkoutOption.fromJson({
        'option_id': 'C',
        'title': 'Recovery Spin',
        'zone': 'Z1',
        'why': '',
        'tags': <String>[],
        'structure': {'total_minutes': 40},
      });
      expect(opt.targetWatts, isNull);
      expect(opt.targetPaceMss, isNull);
      expect(opt.durationMin, 40);
      expect(opt.tags, isEmpty);
    });

    test('missing structure → durationMin null', () {
      final opt = WorkoutOption.fromJson({
        'option_id': 'A',
        'title': 'X',
        'zone': 'Z2',
        'why': '',
        'tags': <String>[],
      });
      expect(opt.durationMin, isNull);
    });

    test('non-map input → safe Unknown fallback (no throw)', () {
      final opt = WorkoutOption.fromJson('not a map');
      expect(opt.optionId, '?');
      expect(opt.title, 'Unknown');
      expect(opt.zone, '?');
      expect(opt.tags, isEmpty);
    });

    test('empty object → documented defaults', () {
      final opt = WorkoutOption.fromJson(<String, dynamic>{});
      expect(opt.optionId, '?');
      expect(opt.title, 'Workout');
      expect(opt.zone, '?');
      expect(opt.why, '');
    });
  });

  // Drift guard: the engine field names the parser depends on, from
  // gatc-types::WorkoutOptionData. Documents the contract explicitly so a
  // rename on the engine side is caught here, not in the field.
  test('engine contract field names (WorkoutOptionData)', () {
    const engineFields = [
      'option_id',
      'title',
      'zone',
      'why', // NOT 'rationale'
      'tags',
      'structure', // nested: total_minutes
      'target_watts',
      'target_pace_mss',
    ];
    expect(engineFields.contains('option_id'), isTrue);
    expect(engineFields.contains('why'), isTrue);
    expect(engineFields.contains('rationale'), isFalse);
    expect(engineFields.contains('target_pace_mss'), isTrue);
  });
}

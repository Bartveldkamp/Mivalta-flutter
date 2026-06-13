// MAC_BRIEF_WORKOUT_INGEST + NEXT_BUILD_BRIEF §B: Tests for workout and
// vault-first biometric ingestion.
//
// Tests the workout type mapping, activity JSON building, and raw observation
// JSON building. FFI calls (write_activity, record_activity,
// write_raw_observation, mark_raw_observation_processed) require the native
// engine, so those are tested via integration tests on-device.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';

import 'package:mivalta_flutter/services/health_ingest.dart';

void main() {
  group('Workout type mapping', () {
    test('BIKING maps to "ride"', () {
      expect(mapWorkoutType(HealthWorkoutActivityType.BIKING), 'ride');
    });

    test('BIKING_STATIONARY maps to "ride"', () {
      expect(mapWorkoutType(HealthWorkoutActivityType.BIKING_STATIONARY), 'ride');
    });

    test('RUNNING maps to "run"', () {
      expect(mapWorkoutType(HealthWorkoutActivityType.RUNNING), 'run');
    });

    test('RUNNING_TREADMILL maps to "run"', () {
      expect(mapWorkoutType(HealthWorkoutActivityType.RUNNING_TREADMILL), 'run');
    });

    test('SWIMMING maps to "swim"', () {
      expect(mapWorkoutType(HealthWorkoutActivityType.SWIMMING), 'swim');
    });

    test('SWIMMING_OPEN_WATER maps to "swim"', () {
      expect(mapWorkoutType(HealthWorkoutActivityType.SWIMMING_OPEN_WATER), 'swim');
    });

    test('SWIMMING_POOL maps to "swim"', () {
      expect(mapWorkoutType(HealthWorkoutActivityType.SWIMMING_POOL), 'swim');
    });

    test('STRENGTH_TRAINING maps to "strength"', () {
      expect(mapWorkoutType(HealthWorkoutActivityType.STRENGTH_TRAINING), 'strength');
    });

    test('WEIGHTLIFTING maps to "strength"', () {
      expect(mapWorkoutType(HealthWorkoutActivityType.WEIGHTLIFTING), 'strength');
    });

    test('WALKING maps to "walk"', () {
      expect(mapWorkoutType(HealthWorkoutActivityType.WALKING), 'walk');
    });

    test('HIKING maps to "hike"', () {
      expect(mapWorkoutType(HealthWorkoutActivityType.HIKING), 'hike');
    });

    test('ROWING maps to "row"', () {
      expect(mapWorkoutType(HealthWorkoutActivityType.ROWING), 'row');
    });

    test('ELLIPTICAL maps to "elliptical"', () {
      expect(mapWorkoutType(HealthWorkoutActivityType.ELLIPTICAL), 'elliptical');
    });

    test('YOGA maps to "yoga"', () {
      expect(mapWorkoutType(HealthWorkoutActivityType.YOGA), 'yoga');
    });

    test('PILATES maps to "yoga"', () {
      expect(mapWorkoutType(HealthWorkoutActivityType.PILATES), 'yoga');
    });

    test('HIGH_INTENSITY_INTERVAL_TRAINING maps to "hiit"', () {
      expect(
        mapWorkoutType(HealthWorkoutActivityType.HIGH_INTENSITY_INTERVAL_TRAINING),
        'hiit',
      );
    });

    test('CROSS_COUNTRY_SKIING maps to "ski"', () {
      expect(mapWorkoutType(HealthWorkoutActivityType.CROSS_COUNTRY_SKIING), 'ski');
    });

    test('MARTIAL_ARTS maps to "martial_arts"', () {
      expect(mapWorkoutType(HealthWorkoutActivityType.MARTIAL_ARTS), 'martial_arts');
    });

    test('BOXING maps to "martial_arts"', () {
      expect(mapWorkoutType(HealthWorkoutActivityType.BOXING), 'martial_arts');
    });

    test('TENNIS maps to "ball_sport"', () {
      expect(mapWorkoutType(HealthWorkoutActivityType.TENNIS), 'ball_sport');
    });

    test('BASKETBALL maps to "ball_sport"', () {
      expect(mapWorkoutType(HealthWorkoutActivityType.BASKETBALL), 'ball_sport');
    });

    test('SOCCER maps to "ball_sport"', () {
      expect(mapWorkoutType(HealthWorkoutActivityType.SOCCER), 'ball_sport');
    });

    test('SAILING maps to "water_sport"', () {
      expect(mapWorkoutType(HealthWorkoutActivityType.SAILING), 'water_sport');
    });

    test('SURFING maps to "water_sport"', () {
      expect(mapWorkoutType(HealthWorkoutActivityType.SURFING), 'water_sport');
    });

    test('JUMP_ROPE maps to "jump_rope"', () {
      expect(mapWorkoutType(HealthWorkoutActivityType.JUMP_ROPE), 'jump_rope');
    });

    test('COOLDOWN maps to "recovery"', () {
      expect(mapWorkoutType(HealthWorkoutActivityType.COOLDOWN), 'recovery');
    });

    test('OTHER maps to "other"', () {
      expect(mapWorkoutType(HealthWorkoutActivityType.OTHER), 'other');
    });

    // Fallback for unmapped types
    test('ARCHERY (unmapped) falls back to lowercase enum name', () {
      expect(mapWorkoutType(HealthWorkoutActivityType.ARCHERY), 'archery');
    });

    test('CURLING (unmapped) falls back to lowercase enum name', () {
      expect(mapWorkoutType(HealthWorkoutActivityType.CURLING), 'curling');
    });
  });

  group('HealthSyncResult', () {
    test('includes workoutsProcessed and skippedWorkouts', () {
      const result = HealthSyncResult(
        success: true,
        observationsProcessed: 5,
        workoutsProcessed: 3,
        skippedDays: 1,
        skippedWorkouts: 2,
      );

      expect(result.success, isTrue);
      expect(result.observationsProcessed, 5);
      expect(result.workoutsProcessed, 3);
      expect(result.skippedDays, 1);
      expect(result.skippedWorkouts, 2);
    });

    test('noData has zero workoutsProcessed', () {
      expect(HealthSyncResult.noData.workoutsProcessed, 0);
      expect(HealthSyncResult.noData.skippedWorkouts, 0);
    });

    test('denied has zero workoutsProcessed', () {
      expect(HealthSyncResult.denied.workoutsProcessed, 0);
      expect(HealthSyncResult.denied.skippedWorkouts, 0);
    });
  });

  group('buildHrActivityJson', () {
    test('returns JSON with hr_samples and hr_timestamps', () {
      final start = DateTime(2026, 6, 12, 10, 0, 0);
      final end = DateTime(2026, 6, 12, 11, 0, 0); // 1 hour workout

      final samples = [
        (t: start.add(const Duration(minutes: 5)), bpm: 120.0),
        (t: start.add(const Duration(minutes: 15)), bpm: 140.0),
        (t: start.add(const Duration(minutes: 30)), bpm: 155.0),
        (t: start.add(const Duration(minutes: 45)), bpm: 150.0),
        (t: start.add(const Duration(minutes: 55)), bpm: 130.0),
      ];

      final json = HealthIngestService.buildHrActivityJson(
        workoutStart: start,
        workoutEnd: end,
        hrSamples: samples,
      );

      expect(json, isNotNull);
      expect(json, contains('"hr_samples"'));
      expect(json, contains('"hr_timestamps"'));
      expect(json, contains('"sample_rate_hz"'));
      expect(json, contains('"completed_at"'));
    });

    test('returns null for fewer than 2 samples', () {
      final start = DateTime(2026, 6, 12, 10, 0, 0);
      final end = DateTime(2026, 6, 12, 10, 30, 0);

      final json = HealthIngestService.buildHrActivityJson(
        workoutStart: start,
        workoutEnd: end,
        hrSamples: [(t: start.add(const Duration(minutes: 5)), bpm: 120.0)],
      );

      expect(json, isNull);
    });

    test('returns null for zero duration', () {
      final start = DateTime(2026, 6, 12, 10, 0, 0);

      final json = HealthIngestService.buildHrActivityJson(
        workoutStart: start,
        workoutEnd: start, // same time = zero duration
        hrSamples: [
          (t: start, bpm: 120.0),
          (t: start, bpm: 130.0),
        ],
      );

      expect(json, isNull);
    });

    test('filters out zero/negative bpm values', () {
      final start = DateTime(2026, 6, 12, 10, 0, 0);
      final end = DateTime(2026, 6, 12, 10, 30, 0);

      final samples = [
        (t: start.add(const Duration(minutes: 5)), bpm: 0.0), // dropped
        (t: start.add(const Duration(minutes: 10)), bpm: 120.0),
        (t: start.add(const Duration(minutes: 15)), bpm: -5.0), // dropped
        (t: start.add(const Duration(minutes: 20)), bpm: 130.0),
        (t: start.add(const Duration(minutes: 25)), bpm: 125.0),
      ];

      final json = HealthIngestService.buildHrActivityJson(
        workoutStart: start,
        workoutEnd: end,
        hrSamples: samples,
      );

      // Should have 3 valid samples (120, 130, 125)
      expect(json, isNotNull);
      // The hr_samples array should contain exactly [120.0,130.0,125.0]
      expect(json, contains('"hr_samples":[120.0,130.0,125.0]'));
      // The negative sample should NOT appear anywhere
      expect(json, isNot(contains('-5.0')));
    });
  });

  // ==========================================================================
  // NEXT_BUILD_BRIEF §B: Vault-first ingest tests
  // ==========================================================================

  group('buildRawObservationJson (vault-first ingest §B)', () {
    test('builds JSON with required keys', () {
      final json = HealthIngestService.buildRawObservationJson(
        date: '2026-06-13',
        source: 'apple',
        dataType: 'biometric',
        payload: '{"rhr":60}',
      );

      final decoded = jsonDecode(json) as Map<String, dynamic>;

      expect(decoded['date'], '2026-06-13');
      expect(decoded['source'], 'apple');
      expect(decoded['data_type'], 'biometric');
      expect(decoded['payload'], '{"rhr":60}');
    });

    test('handles health_connect source', () {
      final json = HealthIngestService.buildRawObservationJson(
        date: '2026-06-13',
        source: 'health_connect',
        dataType: 'biometric',
        payload: '{"hrv_rmssd":42.5}',
      );

      final decoded = jsonDecode(json) as Map<String, dynamic>;

      expect(decoded['source'], 'health_connect');
      expect(decoded['payload'], '{"hrv_rmssd":42.5}');
    });

    test('preserves complex payload as string', () {
      const complexPayload = '''{"rhr":58,"hrv_rmssd":45.2,"sleep":{"total_mins":480,"deep_mins":90}}''';

      final json = HealthIngestService.buildRawObservationJson(
        date: '2026-06-13',
        source: 'apple',
        dataType: 'biometric',
        payload: complexPayload,
      );

      final decoded = jsonDecode(json) as Map<String, dynamic>;

      // Payload is stored as a string, not parsed
      expect(decoded['payload'], isA<String>());
      expect(decoded['payload'], complexPayload);

      // The nested structure can be re-parsed
      final payloadDecoded = jsonDecode(decoded['payload'] as String);
      expect(payloadDecoded['rhr'], 58);
      expect(payloadDecoded['sleep']['deep_mins'], 90);
    });

    test('returns valid JSON string', () {
      final json = HealthIngestService.buildRawObservationJson(
        date: '2026-06-13',
        source: 'apple',
        dataType: 'biometric',
        payload: '{}',
      );

      // Should not throw on decode
      expect(() => jsonDecode(json), returnsNormally);
    });

    test('escapes special characters in payload', () {
      const payloadWithSpecialChars = '{"note":"test\\"value\\nwith\\tspecial"}';

      final json = HealthIngestService.buildRawObservationJson(
        date: '2026-06-13',
        source: 'apple',
        dataType: 'biometric',
        payload: payloadWithSpecialChars,
      );

      // Should not throw — jsonEncode handles escaping
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      expect(decoded['payload'], payloadWithSpecialChars);
    });
  });
}

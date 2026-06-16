// PR-F: Tests for ProfileBuilder and ProfileService.
//
// Tests the zero-fabrication contract: "I don't know" → null anchors,
// not fabricated values. Also tests the profile JSON shape matches
// what the engine expects for construct_engines_fresh.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:mivalta_flutter/services/profile_service.dart';

void main() {
  group('ProfileBuilder', () {
    test('builds valid JSON with all required fields', () {
      final builder = ProfileBuilder()
        ..age = 35
        ..sex = 'male'
        ..level = 'intermediate'
        ..sport = 'cycling'
        ..goalType = 'general_fitness'
        ..weeklyHours = 6.0
        ..trainingYears = 4
        ..thresholdHr = 165
        ..ftpWatts = 250;

      expect(builder.isValid, isTrue);

      final json = builder.buildInputs();
      final decoded = jsonDecode(json) as Map<String, dynamic>;

      // Required fields
      expect(decoded['athlete_id'], isNotEmpty);
      expect(decoded['age'], 35);
      expect(decoded['sex'], 'male');
      expect(decoded['level'], 'intermediate');
      expect(decoded['sport'], 'cycling');
      expect(decoded['goal_type'], 'general_fitness');
      expect(decoded['weekly_hours'], 6.0);
      expect(decoded['training_years'], 4);

      // Anchors
      expect(decoded['threshold_hr'], 165);
      expect(decoded['ftp_watts'], 250);
    });

    test('isValid returns false when required fields missing', () {
      final builder = ProfileBuilder()
        ..age = 35
        ..sex = 'male';
      // Missing level, sport, goalType, weeklyHours, trainingYears

      expect(builder.isValid, isFalse);
    });

    test('athlete_id is a valid UUID v4 format', () {
      final builder = ProfileBuilder()
        ..age = 25
        ..sex = 'female'
        ..level = 'beginner'
        ..sport = 'running'
        ..goalType = 'weight_loss'
        ..weeklyHours = 3.0
        ..trainingYears = 0;

      final json = builder.buildInputs();
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      final athleteId = decoded['athlete_id'] as String;

      // UUID v4 format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
      expect(
        RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')
            .hasMatch(athleteId),
        isTrue,
        reason: 'athlete_id should be a valid UUID v4, got: $athleteId',
      );
    });

    // =========================================================================
    // ZERO-FABRICATION TESTS: "I don't know" → null, not fabricated
    // =========================================================================

    test('unknown threshold_hr persists as null, not fabricated', () {
      final builder = ProfileBuilder()
        ..age = 30
        ..sex = 'male'
        ..level = 'intermediate'
        ..sport = 'cycling'
        ..goalType = 'general_fitness'
        ..weeklyHours = 5.0
        ..trainingYears = 2
        ..thresholdHr = null; // User doesn't know

      final json = builder.buildInputs();
      final decoded = jsonDecode(json) as Map<String, dynamic>;

      // threshold_hr MUST be null, not a fabricated default
      expect(decoded['threshold_hr'], isNull,
          reason: 'ZERO-FABRICATION: unknown threshold_hr must be null, not fabricated');
    });

    test('unknown ftp_watts persists as null for cycling, not fabricated', () {
      final builder = ProfileBuilder()
        ..age = 28
        ..sex = 'female'
        ..level = 'advanced'
        ..sport = 'cycling'
        ..goalType = 'general_fitness'
        ..weeklyHours = 10.0
        ..trainingYears = 5
        ..thresholdHr = 172
        ..ftpWatts = null; // User doesn't know FTP

      final json = builder.buildInputs();
      final decoded = jsonDecode(json) as Map<String, dynamic>;

      // ftp_watts MUST be null, not a fabricated default
      expect(decoded['ftp_watts'], isNull,
          reason: 'ZERO-FABRICATION: unknown ftp_watts must be null, not fabricated');
    });

    test('unknown threshold_pace_sec_km persists as null for running, not fabricated', () {
      final builder = ProfileBuilder()
        ..age = 32
        ..sex = 'male'
        ..level = 'intermediate'
        ..sport = 'running'
        ..goalType = 'general_fitness'
        ..weeklyHours = 6.0
        ..trainingYears = 3
        ..thresholdHr = 165
        ..thresholdPaceSecKm = null; // User doesn't know threshold pace

      final json = builder.buildInputs();
      final decoded = jsonDecode(json) as Map<String, dynamic>;

      // threshold_pace_sec_km MUST be null, not a fabricated default
      expect(decoded['threshold_pace_sec_km'], isNull,
          reason: 'ZERO-FABRICATION: unknown threshold_pace_sec_km must be null, not fabricated');
    });

    test('all anchors unknown persists all as null', () {
      final builder = ProfileBuilder()
        ..age = 45
        ..sex = 'female'
        ..level = 'beginner'
        ..sport = 'cycling'
        ..goalType = 'general_fitness'
        ..weeklyHours = 4.0
        ..trainingYears = 0
        ..thresholdHr = null
        ..ftpWatts = null;

      final json = builder.buildInputs();
      final decoded = jsonDecode(json) as Map<String, dynamic>;

      // ALL anchors MUST be null
      expect(decoded['threshold_hr'], isNull);
      expect(decoded['ftp_watts'], isNull);
      expect(decoded['threshold_pace_sec_km'], isNull);
    });

    // =========================================================================
    // SPORT-SPECIFIC ANCHOR TESTS
    // =========================================================================

    test('cycling profile includes ftp_watts, excludes threshold_pace_sec_km', () {
      final builder = ProfileBuilder()
        ..age = 30
        ..sex = 'male'
        ..level = 'intermediate'
        ..sport = 'cycling'
        ..goalType = 'general_fitness'
        ..weeklyHours = 7.0
        ..trainingYears = 3
        ..ftpWatts = 280;

      final json = builder.buildInputs();
      final decoded = jsonDecode(json) as Map<String, dynamic>;

      expect(decoded['ftp_watts'], 280);
      expect(decoded['threshold_pace_sec_km'], isNull,
          reason: 'cycling profile should not have threshold_pace_sec_km');
    });

    test('running profile includes threshold_pace_sec_km, excludes ftp_watts', () {
      final builder = ProfileBuilder()
        ..age = 28
        ..sex = 'female'
        ..level = 'advanced'
        ..sport = 'running'
        ..goalType = 'general_fitness'
        ..weeklyHours = 8.0
        ..trainingYears = 6
        ..thresholdPaceSecKm = 270; // 4:30/km = 270 sec/km

      final json = builder.buildInputs();
      final decoded = jsonDecode(json) as Map<String, dynamic>;

      expect(decoded['threshold_pace_sec_km'], 270);
      expect(decoded['ftp_watts'], isNull,
          reason: 'running profile should not have ftp_watts');
    });

    test('anchors stay null when unknown — "I don\'t know" is a valid answer',
        () {
      final builder = ProfileBuilder()
        ..age = 55
        ..sex = 'male'
        ..level = 'beginner'
        ..sport = 'cycling'
        ..goalType = 'weight_loss'
        ..weeklyHours = 3.0
        ..trainingYears = 0;

      final json = builder.buildInputs();
      final decoded = jsonDecode(json) as Map<String, dynamic>;

      expect(decoded['ftp_watts'], isNull);
      expect(decoded['threshold_pace_sec_km'], isNull);
    });

    // =========================================================================
    // FL-16: derivation moved to the ENGINE — the client marshals RAW inputs
    // only. goal_class / mesocycle / meso_minutes / per-sport anchor gating are
    // now produced and tested in gatc-ffi::build_onboarding_profile, NOT here.
    // =========================================================================

    test('buildInputs marshals raw inputs only — no coaching derived in Dart', () {
      final builder = ProfileBuilder()
        ..age = 30
        ..sex = 'male'
        ..level = 'intermediate'
        ..sport = 'cycling'
        ..goalType = 'general_fitness'
        ..weeklyHours = 6.0
        ..trainingYears = 3;

      final decoded = jsonDecode(builder.buildInputs()) as Map<String, dynamic>;

      // Raw goal_type is passed straight through...
      expect(decoded['goal_type'], 'performance');
      // ...and NOTHING is derived client-side (the engine owns these).
      expect(decoded.containsKey('goal_class'), isFalse);
      expect(decoded.containsKey('meso_length'), isFalse);
      expect(decoded.containsKey('meso_minutes'), isFalse);
    });
  });

  group('Sport enum', () {
    test('offers ONLY end-to-end supported sports (FL-17)', () {
      // Regression pin: walking/hiking were the 2-week "Setup could not be
      // completed" dead-end — profiles built, then every engine construction
      // failed. A sport may only appear here once the engine serves it
      // end-to-end (see gatc-ffi/tests/onboarding_combos.rs).
      expect(Sport.values.map((s) => s.value).toList(), ['cycling', 'running']);
    });
  });

  group('Level enum', () {
    test('has expected values', () {
      expect(Level.values.map((l) => l.value),
          containsAll(['beginner', 'intermediate', 'advanced', 'elite']));
    });
  });

  // ===========================================================================
  // BETA-SCOPE GOAL FLOW — onboarding can ONLY emit engine-registered
  // goal_types. The bug this pins: the old GoalType enum offered `endurance`
  // (unregistered) and `performance` (a goal_CLASS, not a goal_type); either
  // reaching the engine made RuleResolver panic and bricked the app. The fix
  // guarantees BY CONSTRUCTION that every emittable goal_type is in the
  // goal_demands.md type_map.
  // ===========================================================================
  group('Beta-scope goal flow', () {
    // The complete set of goal_types the onboarding can emit:
    //   - general fitness intent → kGeneralFitnessGoalType
    //   - specific event intent  → an EventGoalType.value
    Set<String> emittableGoalTypes() => {
          kGeneralFitnessGoalType,
          ...EventGoalType.values.map((e) => e.value),
        };

    // The goal_types registered in mivalta-rust-engine/knowledge/cards/
    // goal_demands.md `type_map` for the two end-to-end sports (running,
    // cycling) PLUS the universal `general_fitness`. Transcribed from the card
    // (READ-ONLY SoT) so the test fails loudly if the Dart set ever drifts to
    // include an unregistered value.
    const registeredRunningCycling = <String>{
      // generic (any sport)
      'general_fitness',
      // running events
      '5k', '10k', '15k', 'half_marathon', 'marathon', 'ultra_marathon',
      'trail_50k', 'trail_marathon', 'mile', '1500m', '3000m', '5000m',
      '10000m', 'cross_country',
      // cycling events
      'century', 'gran_fondo', 'metric_century', 'time_trial', 'criterium',
      'hill_climb', 'cyclocross', 'gravel_race', 'road_race', 'sportive',
      'ultra_cycling',
    };

    test('every emittable goal_type is registered in the card type_map', () {
      for (final gt in emittableGoalTypes()) {
        expect(registeredRunningCycling.contains(gt), isTrue,
            reason: 'goal_type "$gt" is not in the goal_demands.md type_map — '
                'it would panic RuleResolver and brick the app');
      }
    });

    test('onboarding can NEVER emit `performance` or `endurance`', () {
      // `performance` is a goal_CLASS (not a goal_type); `endurance` is not in
      // the type_map at all. Both were the original brick-the-app values.
      expect(emittableGoalTypes().contains('performance'), isFalse,
          reason: '`performance` is a goal_class, never a selectable goal_type');
      expect(emittableGoalTypes().contains('endurance'), isFalse,
          reason: '`endurance` is not a registered goal_type');
    });

    test('GoalIntent.generalFitness carries the registered general_fitness goal_type',
        () {
      expect(kGeneralFitnessGoalType, 'general_fitness');
    });

    test('event lists are sport-scoped and non-empty for both supported sports',
        () {
      final running = EventGoalType.forSport('running');
      final cycling = EventGoalType.forSport('cycling');

      expect(running, isNotEmpty);
      expect(cycling, isNotEmpty);
      // No cross-contamination: a running pick can't appear under cycling.
      expect(running.every((e) => e.sport == 'running'), isTrue);
      expect(cycling.every((e) => e.sport == 'cycling'), isTrue);
      // A few concrete anchors (verbatim card values).
      expect(running.map((e) => e.value), containsAll(['5k', 'marathon']));
      expect(cycling.map((e) => e.value), containsAll(['century', 'criterium']));
      // And cross-sport leakage is impossible.
      expect(running.map((e) => e.value).contains('century'), isFalse);
      expect(cycling.map((e) => e.value).contains('5k'), isFalse);
    });

    test('unsupported sport yields no events (honest absence, no fabrication)',
        () {
      expect(EventGoalType.forSport('triathlon'), isEmpty);
      expect(EventGoalType.forSport(null), isEmpty);
    });

    test('a built profile from a specific-event pick marshals the registered goal_type',
        () {
      final event = EventGoalType.marathon;
      final builder = ProfileBuilder()
        ..age = 30
        ..sex = 'male'
        ..level = 'intermediate'
        ..sport = 'running'
        ..goalType = event.value
        ..weeklyHours = 6.0
        ..trainingYears = 3;

      final decoded = jsonDecode(builder.buildInputs()) as Map<String, dynamic>;
      expect(decoded['goal_type'], 'marathon');
      expect(registeredRunningCycling.contains(decoded['goal_type']), isTrue);
    });
  });
}

// Pure-Dart unit tests for CanonicalSeed. Address Day-3 review
// BLOCKER 4: the seed-shape contract must round-trip from
// SmoketestApp.kt's LocalUserProfile values through
// VaultProfileMapper.kt's transform and out as AthleteProfile JSON.
//
// Source pins (read-only this session):
//   mivalta-android-client/app/src/smoketest/java/com/mivalta/app/
//     SmoketestApp.kt:64-89 — LocalUserProfile fields.
//   mivalta-android-client/core/ai/src/main/java/com/mivalta/core/ai/
//     vault/VaultProfileMapper.kt:45-120 — transform.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:mivalta_flutter/canonical_seed.dart';

void main() {
  final json = CanonicalSeed.vaultProfileJson();
  final decoded = jsonDecode(json) as Map<String, dynamic>;

  group('CanonicalSeed.vaultProfileJson()', () {
    test('emits a non-empty JSON string', () {
      expect(json, isNotEmpty);
      expect(json.startsWith('{'), isTrue);
      expect(json.endsWith('}'), isTrue);
    });

    test('athlete_id matches SmoketestApp.SMOKETEST_USER_ID', () {
      expect(decoded['athlete_id'], 'smoketest-user');
    });

    test('personal-data fields match SmoketestApp LocalUserProfile', () {
      expect(decoded['name'], 'Lab User');
      expect(decoded['birth_date'], '1990-01-01');
      expect(decoded['height_cm'], 180);
      expect(decoded['weight_kg'], 75.0);
      expect(decoded['subscription_tier'], 'COACH');
      expect(decoded['fitness_goal'], 'GENERAL_FITNESS');
      expect(decoded['activity_level'], 'consistently_training');
      expect(decoded['available_minutes_per_day'], 60);
    });

    test('engine-side training axes match VaultProfileMapper transform', () {
      expect(decoded['sex'], 'male');
      expect(decoded['level'], 'intermediate');
      expect(decoded['goal_type'], 'general_fitness');
      expect(decoded['goal_class'], 'stay_fit');
      expect(decoded['sport'], 'cycling');
      expect(decoded['training_years'], 1);
      // 7 train-days × 60 min ÷ 60 = 7.0
      expect(decoded['weekly_hours'], 7.0);
    });

    test('meso structure: every day a train day, no off days', () {
      // SmoketestApp seeds trainMonday..trainSunday = true, so
      // VaultProfileMapper.calculateMesoTrainDays produces all 21
      // meso days as train days and zero off days. This is the
      // canonical smoketest profile, NOT a schema violation.
      expect(decoded['meso_length'], 21);
      final trainDays = (decoded['meso_train_days'] as List).cast<int>();
      final offDays = (decoded['meso_off_days'] as List).cast<int>();
      expect(trainDays.length, 21);
      expect(offDays, isEmpty);
      expect(trainDays, equals(List<int>.generate(21, (i) => i)));
      // 7 train days × 60 min × 3 weeks = 1260
      expect(decoded['meso_minutes'], 1260);
    });

    test('availability has one entry per meso day, all 60 minutes', () {
      final availability =
          (decoded['availability'] as Map).cast<String, dynamic>();
      expect(availability.length, 21);
      for (var d = 0; d < 21; d++) {
        expect(availability['$d'], 60, reason: 'availability[$d]');
      }
    });

    test('mood_zone_preferences are present and Z-bucketed', () {
      final m = (decoded['mood_zone_preferences'] as Map)
          .cast<String, dynamic>();
      expect(m.keys.toSet(),
          {'energized', 'normal', 'tired', 'stressed', 'recovering'});
      // Spot-check the lookups VaultProfileMapper.toVaultProfileJson
      // emits verbatim.
      expect((m['energized'] as List).cast<String>(),
          equals(['Z3', 'Z4', 'Z5']));
      expect((m['recovering'] as List).cast<String>(), equals(['Z1']));
    });

    test('age is a non-negative integer ≥ years-since-1990', () {
      // age is the only runtime-computed field. Don't pin to a specific
      // year (the test must keep passing as the calendar advances) but
      // ensure the value is sane.
      final age = decoded['age'] as int;
      expect(age, greaterThanOrEqualTo(0));
      // The athlete was born in 1990; today.year - 1990 is the upper
      // bound and (today.year - 1990 - 1) is the lower bound depending
      // on whether the birthday has passed this year.
      final now = DateTime.now();
      final yearsSince1990 = now.year - 1990;
      expect(age, anyOf(equals(yearsSince1990), equals(yearsSince1990 - 1)));
    });
  });

  group('CanonicalSeed pinning', () {
    test('android-client SHA is a 40-char lowercase hex', () {
      final sha = CanonicalSeed.androidClientPinnedSha;
      expect(sha.length, 40);
      expect(RegExp(r'^[0-9a-f]{40}$').hasMatch(sha), isTrue);
    });
  });
}

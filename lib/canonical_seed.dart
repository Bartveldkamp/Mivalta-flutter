// Canonical smoketest seed. Reused from the android-client smoketest
// flavour and run through android-client's own VaultProfileMapper
// transform to produce an AthleteProfile JSON gatc-ffi accepts.
//
// Sources (read-only this session):
// - SmoketestApp.kt at mivalta-android-client/app/src/smoketest/java/
//   com/mivalta/app/SmoketestApp.kt:64-89 — LocalUserProfile fields.
// - VaultProfileMapper.kt at mivalta-android-client/core/ai/src/main/
//   java/com/mivalta/core/ai/vault/VaultProfileMapper.kt:45-120 —
//   transform applied here.
//
// Only `age` is computed at runtime, from birth_date "1990-01-01"
// using the same year-difference logic android-client uses
// (DateTimeUtils.calculateAge). Everything else is literal.

import 'dart:convert';

class CanonicalSeed {
  CanonicalSeed._();

  static const String androidClientPinnedSha =
      '645e4518ff37a02700a7696de2f0b006b5c1c1ca';

  static String vaultProfileJson() {
    const birthDate = '1990-01-01';
    final age = _ageFromIso(birthDate);
    return jsonEncode({
      'athlete_id': 'smoketest-user',
      'name': 'Lab User',
      'birth_date': birthDate,
      'height_cm': 180,
      'weight_kg': 75.0,
      'subscription_tier': 'COACH',
      'fitness_goal': 'GENERAL_FITNESS',
      'activity_level': 'consistently_training',
      'available_minutes_per_day': 60,
      'age': age,
      'sex': 'male',
      'level': 'intermediate',
      'goal_type': 'general_fitness',
      'goal_class': 'stay_fit',
      'sport': 'cycling',
      'training_years': 1,
      'weekly_hours': 7.0,
      'meso_length': 21,
      'meso_train_days': List<int>.generate(21, (i) => i),
      'meso_off_days': <int>[],
      'meso_minutes': 1260,
      'availability': {for (var d = 0; d < 21; d++) '$d': 60},
      'mood_zone_preferences': {
        'energized': ['Z3', 'Z4', 'Z5'],
        'normal': ['Z2', 'Z3', 'Z4'],
        'tired': ['Z1', 'Z2'],
        'stressed': ['Z1', 'Z2'],
        'recovering': ['Z1'],
      },
    });
  }

  static int _ageFromIso(String iso) {
    final birth = DateTime.parse(iso);
    final now = DateTime.now();
    var age = now.year - birth.year;
    if (now.month < birth.month ||
        (now.month == birth.month && now.day < birth.day)) {
      age -= 1;
    }
    return age;
  }
}

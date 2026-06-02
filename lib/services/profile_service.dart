// PR-F: Profile persistence service.
//
// Saves and loads the user's AthleteProfile JSON to persistent storage.
// The profile is stored as a JSON file in the app's support directory.
//
// ZERO-FABRICATION: If the user doesn't know their FTP/threshold, we persist
// null — not a fabricated number. The engine already handles absent anchors
// (falls back to HR/RPE); a fabricated FTP would poison every power target.

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Service for persisting and loading the user's athlete profile.
class ProfileService {
  ProfileService._();

  static const _profileFileName = 'athlete_profile.json';

  /// Check if a persisted profile exists.
  static Future<bool> hasPersistedProfile() async {
    final file = await _profileFile();
    return file.exists();
  }

  /// Load the persisted profile JSON.
  /// Returns null if no profile exists.
  static Future<String?> loadProfile() async {
    final file = await _profileFile();
    if (!await file.exists()) return null;
    return file.readAsString();
  }

  /// Save the profile JSON to persistent storage.
  static Future<void> saveProfile(String profileJson) async {
    final file = await _profileFile();
    await file.writeAsString(profileJson);
  }

  /// Delete the persisted profile (for testing or reset flows).
  static Future<void> deleteProfile() async {
    final file = await _profileFile();
    if (await file.exists()) {
      await file.delete();
    }
  }

  static Future<File> _profileFile() async {
    final support = await getApplicationSupportDirectory();
    return File('${support.path}/$_profileFileName');
  }
}

/// Builder for creating an AthleteProfile JSON from onboarding wizard inputs.
///
/// Maps the user's selections to the AthleteProfile schema expected by
/// gatc-ffi's construct_engines_fresh().
class ProfileBuilder {
  ProfileBuilder();

  // Required fields
  int? age;
  String? sex;           // 'male' | 'female'
  String? level;         // 'beginner' | 'intermediate' | 'advanced' | 'elite'
  String? sport;         // 'cycling' | 'running' | 'walking' | 'hiking'
  String? goalType;      // goal_type string
  double? weeklyHours;
  int? trainingYears;
  int? thresholdHr;      // threshold_hr (can be null if unknown)

  // Sport-specific anchors — null if unknown (zero-fabrication)
  int? ftpWatts;                 // cycling only
  int? thresholdPaceSecKm;       // running only

  /// Validate that all required fields are set.
  bool get isValid =>
      age != null &&
      sex != null &&
      level != null &&
      sport != null &&
      goalType != null &&
      weeklyHours != null &&
      trainingYears != null;

  /// Build the AthleteProfile JSON for the engine.
  ///
  /// ZERO-FABRICATION: Unknown anchors (FTP, threshold pace) are set to null,
  /// not fabricated. The engine handles absent anchors correctly.
  String build() {
    if (!isValid) {
      throw StateError('ProfileBuilder: required fields missing');
    }

    // Generate a stable athlete_id using UUID v4
    final athleteId = const Uuid().v4();

    // Derive goal_class from goal_type (simplified mapping)
    final goalClass = _goalClassFrom(goalType!);

    // Default meso parameters (21-day mesocycle, 5 training days)
    const mesoLength = 21;
    final mesoTrainDays = List<int>.generate(5, (i) => i); // [0,1,2,3,4]
    const mesoOffDays = [5, 6];
    final mesoMinutes = (weeklyHours! * 60).round();

    final profile = <String, dynamic>{
      'athlete_id': athleteId,
      'age': age,
      'sex': sex,
      'level': level,
      'goal_type': goalType,
      'goal_class': goalClass,
      'sport': sport,
      'weekly_hours': weeklyHours,
      'training_years': trainingYears,
      'recent_activity': 'trained', // default assumption
      'threshold_hr': thresholdHr,
      // Sport-specific anchors — null if unknown
      'ftp_watts': sport == 'cycling' ? ftpWatts : null,
      'threshold_pace_sec_km': sport == 'running' ? thresholdPaceSecKm : null,
      'power_profile': null, // Not collected in onboarding
      // Meso parameters
      'meso_length': mesoLength,
      'meso_train_days': mesoTrainDays,
      'meso_off_days': mesoOffDays,
      'meso_minutes': mesoMinutes,
      'availability': <String, int>{},
    };

    return jsonEncode(profile);
  }

  /// Map goal_type to goal_class.
  String _goalClassFrom(String goalType) {
    switch (goalType) {
      case 'general_fitness':
      case 'stay_fit':
        return 'stay_fit';
      case 'weight_loss':
        return 'weight_loss';
      case 'endurance':
      case 'base_building':
        return 'endurance';
      case 'performance':
      case 'race_preparation':
        return 'performance';
      default:
        return 'endurance';
    }
  }
}

/// Supported sports per v1.3 (strength deferred).
enum Sport {
  cycling('cycling', 'Cycling'),
  running('running', 'Running'),
  walking('walking', 'Walking'),
  hiking('hiking', 'Hiking');

  const Sport(this.value, this.label);
  final String value;
  final String label;
}

/// Experience levels.
enum Level {
  beginner('beginner', 'Beginner', '< 1 year'),
  intermediate('intermediate', 'Intermediate', '1-3 years'),
  advanced('advanced', 'Advanced', '3-7 years'),
  elite('elite', 'Elite', '7+ years');

  const Level(this.value, this.label, this.description);
  final String value;
  final String label;
  final String description;
}

/// Goal types.
enum GoalType {
  generalFitness('general_fitness', 'General Fitness', 'Stay healthy and active'),
  endurance('endurance', 'Build Endurance', 'Improve aerobic capacity'),
  performance('performance', 'Performance', 'Train for events/races'),
  weightLoss('weight_loss', 'Weight Loss', 'Lose weight through exercise');

  const GoalType(this.value, this.label, this.description);
  final String value;
  final String label;
  final String description;
}

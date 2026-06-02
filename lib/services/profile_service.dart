// PR-F: Profile persistence service.
// PR-H: Moved profile into encrypted vault.
//
// Bootstrap approach: persist only the athlete_id (a random UUID — not personal
// data) in a tiny plaintext pointer file; store the full profile (age/sex/FTP/
// anchors) in the encrypted vault (SQLCipher).
//
// MIGRATION: Pre-PR-H installations have the full profile in plaintext
// `athlete_profile.json`. On first load, we migrate to vault-based storage:
// 1. Read the old plaintext profile
// 2. Write it to the encrypted vault
// 3. Create the pointer file with just athlete_id
// 4. Delete the old plaintext file
//
// ZERO-FABRICATION: If the user doesn't know their FTP/threshold, we persist
// null — not a fabricated number. The engine already handles absent anchors
// (falls back to HR/RPE); a fabricated FTP would poison every power target.

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../src/rust/api.dart' as rust_api;
import '../src/rust/frb_generated.dart';

/// Service for persisting and loading the user's athlete profile.
///
/// PR-H: Profile storage is now split:
/// - Pointer file (`athlete_pointer.json`): contains only athlete_id (plaintext, ~40 bytes)
/// - Vault DB: contains full profile (encrypted with SQLCipher)
class ProfileService {
  ProfileService._();

  static const _pointerFileName = 'athlete_pointer.json';
  static const _legacyProfileFileName = 'athlete_profile.json';

  /// Check if a persisted profile exists (either pointer or legacy file).
  static Future<bool> hasPersistedProfile() async {
    final pointer = await _pointerFile();
    if (await pointer.exists()) return true;
    // Check for legacy pre-PR-H plaintext profile
    final legacy = await _legacyProfileFile();
    return legacy.exists();
  }

  /// Load the profile JSON using the appropriate method.
  ///
  /// Handles both:
  /// - New pointer+vault approach (PR-H): reads athlete_id from pointer,
  ///   then full profile from encrypted vault
  /// - Legacy plaintext approach (pre-PR-H): reads directly from file,
  ///   then migrates to vault on next save
  ///
  /// Requires RustLib to be initialized for vault reads.
  /// Returns null if no profile exists.
  static Future<String?> loadProfile() async {
    final support = await getApplicationSupportDirectory();
    final vaultPath = support.path;

    // First check for pointer file (PR-H approach)
    final pointer = await _pointerFile();
    if (await pointer.exists()) {
      final pointerJson = await pointer.readAsString();
      final athleteId = _extractAthleteId(pointerJson);
      if (athleteId != null) {
        // Ensure RustLib is initialized
        await RustLib.init();
        // Read from vault
        final profile = await rust_api.readProfileFromVault(
          athleteId: athleteId,
          vaultPath: vaultPath,
        );
        return profile;
      }
    }

    // Check for legacy plaintext profile (pre-PR-H)
    final legacy = await _legacyProfileFile();
    if (await legacy.exists()) {
      return legacy.readAsString();
    }

    return null;
  }

  /// Save the profile JSON to the encrypted vault.
  ///
  /// Creates/updates the pointer file and writes the full profile to vault.
  /// If a legacy plaintext file exists, deletes it after successful vault write.
  ///
  /// Requires RustLib to be initialized.
  static Future<void> saveProfile(String profileJson) async {
    final support = await getApplicationSupportDirectory();
    final vaultPath = support.path;

    // Ensure RustLib is initialized
    await RustLib.init();

    // Write to vault
    await rust_api.writeProfileToVault(
      athleteProfileJson: profileJson,
      vaultPath: vaultPath,
    );

    // Extract athlete_id and write pointer file
    final athleteId = _extractAthleteId(profileJson);
    if (athleteId != null) {
      final pointer = await _pointerFile();
      await pointer.writeAsString(jsonEncode({'athlete_id': athleteId}));
    }

    // Remove legacy plaintext file if it exists (migration cleanup)
    final legacy = await _legacyProfileFile();
    if (await legacy.exists()) {
      await legacy.delete();
    }
  }

  /// Delete all profile data (for testing or full reset).
  ///
  /// Removes both pointer file and any legacy plaintext file.
  /// Note: This does NOT erase the vault — use `clearAllUserData` for that.
  static Future<void> deleteProfile() async {
    final pointer = await _pointerFile();
    if (await pointer.exists()) {
      await pointer.delete();
    }
    final legacy = await _legacyProfileFile();
    if (await legacy.exists()) {
      await legacy.delete();
    }
  }

  /// Get the vault path for engine construction.
  static Future<String> getVaultPath() async {
    final support = await getApplicationSupportDirectory();
    return support.path;
  }

  /// Read the athlete_id from the pointer file (if exists).
  /// Returns null if no pointer file exists.
  static Future<String?> getAthleteId() async {
    final pointer = await _pointerFile();
    if (!await pointer.exists()) {
      // Check legacy file for athlete_id
      final legacy = await _legacyProfileFile();
      if (await legacy.exists()) {
        final profileJson = await legacy.readAsString();
        return _extractAthleteId(profileJson);
      }
      return null;
    }
    final pointerJson = await pointer.readAsString();
    return _extractAthleteId(pointerJson);
  }

  static String? _extractAthleteId(String json) {
    try {
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      return decoded['athlete_id'] as String?;
    } catch (_) {
      return null;
    }
  }

  static Future<File> _pointerFile() async {
    final support = await getApplicationSupportDirectory();
    return File('${support.path}/$_pointerFileName');
  }

  static Future<File> _legacyProfileFile() async {
    final support = await getApplicationSupportDirectory();
    return File('${support.path}/$_legacyProfileFileName');
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

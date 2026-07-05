// Morning read gate — BS-012
//
// The salience gate that decides whether the morning notification fires.
// Pure Dart; fully unit-tested decision table. Zero new FFI.
//
// Three reasons to speak (if presence allows):
// (a) State level CHANGED vs last delivered read
// (b) Pending advisories non-empty
// (c) Calibration milestone crossed (sufficiency bucket changed)
//
// Otherwise: NOTHING is sent. Silence is a finished state.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Coach presence level — governs notification frequency.
/// Imported from you_screen.dart where the user sets it.
enum CoachPresence { off, quiet, moderate }

/// The result of evaluating the morning read gate.
class MorningReadResult {
  const MorningReadResult({
    required this.shouldFire,
    this.stateWord,
    this.stateColor,
    this.advisoryText,
    this.reason,
  });

  /// Whether the notification should fire.
  final bool shouldFire;

  /// State word from readiness_indicator (e.g. "Productive", "Accumulated").
  final String? stateWord;

  /// State color hex for the dot (e.g. "#2BD974").
  final String? stateColor;

  /// Advisory text for line 2 (from state_advisory or realized line).
  final String? advisoryText;

  /// Debug: why it fired or was silent.
  final String? reason;

  /// Silent result.
  static const silent = MorningReadResult(shouldFire: false);
}

/// The morning read gate service.
///
/// Evaluates whether to fire the morning notification based on:
/// - Coach presence setting
/// - State change since last read
/// - Pending advisories
/// - Calibration milestone changes
class MorningReadGate {
  MorningReadGate({
    required this.prefs,
  });

  final SharedPreferences prefs;

  // Preference keys.
  static const _keyLastDeliveredLevel = 'morning_read_last_level';
  static const _keyLastDeliveredDate = 'morning_read_last_date';
  static const _keyLastCalibrationBucket = 'morning_read_last_calibration';
  static const _keyCoachPresence = 'coach_presence';

  /// Evaluate the gate and return the result.
  ///
  /// Parameters are parsed JSON from the engine FFI calls:
  /// - [readinessIndicatorJson]: from readiness_indicator()
  /// - [pendingAdvisoriesJson]: from pending_advisories()
  /// - [stateAdvisoryJson]: from state_advisory()
  /// - [validationReportJson]: from validation_report()
  MorningReadResult evaluate({
    required String? readinessIndicatorJson,
    required String? pendingAdvisoriesJson,
    required String? stateAdvisoryJson,
    required String? validationReportJson,
  }) {
    // 1. Read coach presence.
    final presence = _readPresence();
    if (presence == CoachPresence.off) {
      return const MorningReadResult(
        shouldFire: false,
        reason: 'presence=off',
      );
    }

    // 2. Parse engine outputs.
    final indicator = _parseJson(readinessIndicatorJson);
    final advisories = _parseJsonList(pendingAdvisoriesJson);
    final stateAdvisory = _parseJson(stateAdvisoryJson);
    final validation = _parseJson(validationReportJson);

    // Extract state level.
    final currentLevel = indicator?['level'] as String?;
    final stateWord = _levelToWord(currentLevel);
    final stateColor = _levelToColor(currentLevel);

    // Extract advisory text.
    final advisoryText = stateAdvisory?['advisory'] as String? ??
        stateAdvisory?['text'] as String? ??
        '';

    // 3. Check the three reasons.
    final lastLevel = prefs.getString(_keyLastDeliveredLevel);
    final lastDate = prefs.getString(_keyLastDeliveredDate);
    final lastCalibration = prefs.getString(_keyLastCalibrationBucket);

    final today = _todayDateString();
    final currentCalibration = validation?['sufficiency_bucket'] as String?;

    // (a) State level changed?
    final stateChanged = currentLevel != null &&
        lastLevel != null &&
        currentLevel != lastLevel &&
        lastDate != today;

    // (b) Pending advisories non-empty?
    final hasAdvisories = advisories.isNotEmpty;

    // (c) Calibration milestone crossed?
    final calibrationChanged = currentCalibration != null &&
        lastCalibration != null &&
        currentCalibration != lastCalibration &&
        lastDate != today;

    // 4. Apply presence rules.
    bool shouldFire = false;
    String? reason;

    switch (presence) {
      case CoachPresence.quiet:
        // Quiet: only fire for advisories.
        if (hasAdvisories) {
          shouldFire = true;
          reason = 'quiet+advisory';
        } else {
          reason = 'quiet,no_advisory';
        }
        break;

      case CoachPresence.moderate:
        // Moderate: fire for any of the three reasons.
        if (stateChanged) {
          shouldFire = true;
          reason = 'moderate+state_changed';
        } else if (hasAdvisories) {
          shouldFire = true;
          reason = 'moderate+advisory';
        } else if (calibrationChanged) {
          shouldFire = true;
          reason = 'moderate+calibration';
        } else {
          reason = 'moderate,no_change';
        }
        break;

      case CoachPresence.off:
        // Already handled above.
        break;
    }

    // 5. Don't fire if there's no content.
    if (shouldFire && (stateWord == null || stateWord.isEmpty)) {
      shouldFire = false;
      reason = 'no_state_word';
    }
    if (shouldFire && advisoryText.isEmpty && !stateChanged && !calibrationChanged) {
      // Advisory-only fire but no text → don't fire.
      if (hasAdvisories) {
        shouldFire = false;
        reason = 'advisory_empty';
      }
    }

    return MorningReadResult(
      shouldFire: shouldFire,
      stateWord: stateWord,
      stateColor: stateColor,
      advisoryText: advisoryText.isNotEmpty ? advisoryText : null,
      reason: reason,
    );
  }

  /// Mark that a notification was delivered. Call after successful fire.
  void markDelivered({
    required String? level,
    required String? calibrationBucket,
  }) {
    final today = _todayDateString();
    if (level != null) {
      prefs.setString(_keyLastDeliveredLevel, level);
    }
    prefs.setString(_keyLastDeliveredDate, today);
    if (calibrationBucket != null) {
      prefs.setString(_keyLastCalibrationBucket, calibrationBucket);
    }
  }

  /// Read coach presence from prefs.
  CoachPresence _readPresence() {
    final value = prefs.getString(_keyCoachPresence);
    switch (value) {
      case 'off':
        return CoachPresence.off;
      case 'quiet':
        return CoachPresence.quiet;
      case 'moderate':
      default:
        return CoachPresence.moderate;
    }
  }

  /// Parse JSON string to map, null-safe.
  Map<String, dynamic>? _parseJson(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      final decoded = jsonDecode(json);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Parse JSON string to list, null-safe.
  List<dynamic> _parseJsonList(String? json) {
    if (json == null || json.isEmpty) return const [];
    try {
      final decoded = jsonDecode(json);
      if (decoded is List) return decoded;
      return const [];
    } catch (_) {
      return const [];
    }
  }

  /// Map level to display word.
  String? _levelToWord(String? level) {
    switch (level?.toLowerCase()) {
      case 'green':
        return 'Productive';
      case 'yellow':
        return 'Accumulated';
      case 'orange':
        return 'Fatigued';
      case 'red':
        return 'Overreached';
      default:
        return level; // Pass through if already a word.
    }
  }

  /// Map level to color hex.
  String? _levelToColor(String? level) {
    switch (level?.toLowerCase()) {
      case 'green':
      case 'productive':
        return '#2BD974';
      case 'yellow':
      case 'accumulated':
        return '#E6872F';
      case 'orange':
      case 'fatigued':
        return '#E65C2F';
      case 'red':
      case 'overreached':
        return '#E63946';
      default:
        return null;
    }
  }

  /// Get today's date as string (YYYY-MM-DD).
  String _todayDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

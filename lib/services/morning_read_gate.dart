// Morning read gate — BS-012
//
// The salience gate that decides whether the morning notification fires.
// Pure Dart; fully unit-tested decision table. Zero new FFI.
//
// Three reasons to speak (if presence allows):
// (a) Fatigue state CHANGED vs last delivered read
// (b) Pending advisories non-empty
// (c) Calibration milestone crossed (sufficiency bucket changed)
//
// Otherwise: NOTHING is sent. Silence is a finished state.
//
// DR-021 fixes:
// - N1: Use locked vocabulary only (Recovered/Productive/Accumulated/
//       Overreached/IllnessRisk — engine words verbatim)
// - N2: Use fatigueState from viterbiFatigueState(), not level→word mapping
// - N3: State color hex from tokens.dart state palette (not level palette)

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../theme/tokens.dart';

/// Coach presence level — governs notification frequency.
/// Defined HERE (single source); the You screen reads/writes the same
/// `coach_presence` SharedPreferences key and must import this enum rather
/// than declaring its own.
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

  /// State word from viterbiFatigueState — engine verbatim
  /// (Recovered/Productive/Accumulated/Overreached/IllnessRisk).
  final String? stateWord;

  /// State color hex from tokens.dart state palette (e.g. "#00C6A7").
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
  static const _keyLastDeliveredState = 'morning_read_last_state';
  static const _keyLastDeliveredDate = 'morning_read_last_date';
  static const _keyLastCalibrationBucket = 'morning_read_last_calibration';
  static const _keyCoachPresence = 'coach_presence';

  /// Evaluate the gate and return the result.
  ///
  /// Parameters are parsed JSON from the engine FFI calls:
  /// - [fatigueStateJson]: from viterbiFatigueState() — the engine's state word
  /// - [pendingAdvisoriesJson]: from pending_advisories()
  /// - [stateAdvisoryJson]: from state_advisory()
  /// - [validationReportJson]: from validation_report()
  MorningReadResult evaluate({
    required String? fatigueStateJson,
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
    final fatigueState = _parseJson(fatigueStateJson);
    final advisories = _parseJsonList(pendingAdvisoriesJson);
    final stateAdvisory = _parseJson(stateAdvisoryJson);
    final validation = _parseJson(validationReportJson);

    // Extract fatigue state — engine word verbatim (N1/N2).
    // viterbiFatigueState returns {"state": "Productive", ...}
    final currentState = fatigueState?['state'] as String?;
    final stateWord = currentState; // Engine word verbatim, no mapping
    final stateColor = _stateToColor(currentState);

    // Extract advisory text.
    final advisoryText = stateAdvisory?['advisory'] as String? ??
        stateAdvisory?['text'] as String? ??
        '';

    // 3. Check the three reasons.
    final lastState = prefs.getString(_keyLastDeliveredState);
    final lastDate = prefs.getString(_keyLastDeliveredDate);
    final lastCalibration = prefs.getString(_keyLastCalibrationBucket);

    final today = _todayDateString();
    final currentCalibration = validation?['sufficiency_bucket'] as String?;

    // (a) Fatigue state changed?
    // First-ever observation (lastState == null) is deliberately SILENT:
    // there is no baseline to have changed from, and the first read is not
    // news the athlete asked to be woken for (adversarial review 2026-07-06).
    final stateChanged = currentState != null &&
        lastState != null &&
        currentState != lastState &&
        lastDate != today;

    // (b) Pending advisories non-empty?
    final hasAdvisories = advisories.isNotEmpty;

    // (c) Calibration milestone crossed?
    // Same first-observation dead-zone as (a), same reason: no baseline.
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
    required String? state,
    required String? calibrationBucket,
  }) {
    final today = _todayDateString();
    if (state != null) {
      prefs.setString(_keyLastDeliveredState, state);
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

  /// Map fatigue state to color hex — the LOCKED state palette, read from
  /// the design tokens (never hardcoded hex; adversarial review 2026-07-06).
  /// Engine word verbatim; only the 5 locked states are recognized.
  String? _stateToColor(String? state) {
    final color = switch (state?.toLowerCase()) {
      'recovered' => MivaltaColors.stateRecovered,
      'productive' => MivaltaColors.stateProductive,
      'accumulated' => MivaltaColors.stateAccumulated,
      'overreached' => MivaltaColors.stateOverreached,
      'illnessrisk' => MivaltaColors.stateIllnessRisk,
      _ => null,
    };
    if (color == null) return null;
    final argb = color.toARGB32().toRadixString(16).padLeft(8, '0');
    return '#${argb.substring(2).toUpperCase()}';
  }

  /// Get today's date as string (YYYY-MM-DD).
  String _todayDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

// Morning read courier — BS-012 (engine-side verdict since rust-engine #388).
//
// The salience DECISION lives in the engine (`morning_read_verdict`): whether
// the coach speaks is a coaching decision, so Viterbi's seam decides it. This
// file is the client's COURIER half only:
// - carries the delivery context IN (coach presence preference, last-delivered
//   markers, the same-day flag — all from SharedPreferences, because the
//   client owns the calendar and the athlete's device-local preferences);
// - parses the engine's verdict JSON OUT into `MorningReadResult` for the
//   delivery layer (title/body verbatim — engine words, never assembled here);
// - records `markDelivered` after a successful fire.
//
// No thresholds, no decision table, no fallback copy in Dart. The engine's
// `title` is the card-worded state display (e.g. "Carrying some fatigue"),
// never the raw enum token — the lock-screen enum leak is closed engine-side.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../theme/tokens.dart';

/// Coach presence level — governs notification frequency.
/// Defined HERE (single source); the You screen reads/writes the same
/// `coach_presence` SharedPreferences key and must import this enum rather
/// than declaring its own. `name` values (`off`/`quiet`/`moderate`) are the
/// engine's presence vocabulary verbatim.
enum CoachPresence { off, quiet, moderate }

/// The engine's morning-read verdict, parsed for the delivery layer.
/// Every field is couriered verbatim from the verdict JSON except
/// [stateColor], which is a display-token lookup (design tokens, not logic).
class MorningReadResult {
  const MorningReadResult({
    required this.shouldFire,
    this.title,
    this.body,
    this.state,
    this.sufficiencyBucket,
    this.stateColor,
    this.reason,
  });

  /// Whether the engine says the notification fires.
  final bool shouldFire;

  /// Card-worded notification title from the engine (capitalized state
  /// display wording) — rendered verbatim, never the raw state token.
  final String? title;

  /// Notification body from the engine (state advisory verbatim). May be
  /// empty — a title-only notification is honest absence, never filled in.
  final String? body;

  /// Raw engine state token (Recovered/…/IllnessRisk) — used ONLY as the
  /// last-delivered marker for the next verdict call, never displayed.
  final String? state;

  /// Sufficiency bucket token — last-delivered marker only.
  final String? sufficiencyBucket;

  /// State color hex from the LOCKED design-token state palette.
  final String? stateColor;

  /// Engine reason token (debug/telemetry only).
  final String? reason;

  /// Silent result.
  static const silent = MorningReadResult(shouldFire: false);
}

/// The morning-read courier service (see file header).
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

  /// The presence token to courier to the engine (`off`/`quiet`/`moderate`).
  /// Default mirrors the You screen's default selection.
  String get presenceToken =>
      prefs.getString(_keyCoachPresence) ?? CoachPresence.moderate.name;

  /// Last-delivered state token (engine word verbatim), or null before the
  /// first delivered read.
  String? get lastDeliveredState => prefs.getString(_keyLastDeliveredState);

  /// Last-delivered sufficiency bucket, or null before the first read.
  String? get lastDeliveredBucket =>
      prefs.getString(_keyLastCalibrationBucket);

  /// Whether a read was already delivered today (client owns the calendar —
  /// same contract as the realize seams' caller-supplied date).
  bool get alreadyNotifiedToday =>
      prefs.getString(_keyLastDeliveredDate) == _todayDateString();

  /// Parse the engine's verdict JSON into a [MorningReadResult].
  /// Mechanical courier parse — no defaults masquerading as decisions: a
  /// malformed payload throws (fail loud), it is never coerced to a fire.
  MorningReadResult parseVerdict(String verdictJson) {
    final v = jsonDecode(verdictJson) as Map<String, dynamic>;
    final state = v['state'] as String?;
    return MorningReadResult(
      shouldFire: v['fire'] as bool,
      title: v['title'] as String?,
      body: v['body'] as String?,
      state: state,
      sufficiencyBucket: v['sufficiency_bucket'] as String?,
      stateColor: _stateToColor(state),
      reason: v['reason'] as String?,
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

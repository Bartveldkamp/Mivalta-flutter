// HomeData — display-only snapshot of engine output for the home.
//
// Extracted from readiness_screen.dart. This is a plumbing model that maps
// engine output to UI state; the screen that used it is deleted.

import 'activity_summary.dart';
import 'realized_line.dart';
import '../theme/source_tier.dart';

/// The insufficient-data gate. Maps the engine's own no-data verdict to the
/// home's "we need more data" presentation — it is NOT a Dart threshold.
///
/// `ViterbiMonitor::readiness_indicator()` (gatc-viterbi) returns an explicit
/// no-data result — score 0, **confidence 0**, empty contributions — when it
/// has neither HMM posteriors nor any z-score history to stand on, rather than
/// reading absent z-scores as "exactly at baseline" and fabricating a healthy
/// number. Its doc-comment contract is explicit: *"Consumers gate their 'need
/// more data' copy on the zero confidence."* We honour that here.
///
/// This verdict is PERSISTED: `zscore_history` and the HMM posteriors are saved
/// on every state-changing op and restored on launch, so once the model has
/// learned an athlete's baseline it keeps surfacing readiness across app
/// restarts.
bool insufficientDataFromConfidence(double? confidence) =>
    confidence == null || confidence == 0.0;

/// Display-only snapshot of engine output for the home. Public (not
/// underscore-private) so widget tests can pump the home directly.
class HomeData {
  // Zone 1 — State (hero)
  int? readinessScore;           // HEADLINE: indicator['score'] (4-axis blend)
  double? confidence;            // indicator['confidence'] — no-data/learning gate
  String? level;                 // HEADLINE band: indicator['level'] (Green/Yellow/Orange/Red) → colour + word
  // Item 4: indicator['contributions'] — 4-axis reasons for Josi's why-reveal
  List<Map<String, dynamic>> contributions = const [];
  String? stateRecommendation;   // stateWidget['state_recommendation']
  String? confidenceAdvisory;    // stateWidget['confidence_advisory']
  String? fatigueState;          // viterbiFatigueState().state
  RealizedLine? realizedLine;    // gatc_ffi::realize_advisor_line — deterministic Josi line (text + safety)

  // Zone 2 — Today (from SessionWidget)
  String? workoutTitle;          // sessionWidget['workout_title']
  int? durationMin;              // sessionWidget['duration_min']
  String? sessionZone;           // sessionWidget['zone']
  int? targetWatts;              // sessionWidget['target_watts']
  String? targetPaceMss;         // sessionWidget['target_pace_mss']
  String? focusCue;              // sessionWidget['focus_cue']
  String? rationaleProse;        // sessionWidget['rationale_prose']
  String? zoneCap;               // zoneCapWithAdvisories().zone

  // Today-facts tiles — labelled via the fixed dictionaries in
  // lib/copy/today_facts_labels.dart, never shown raw.
  String? acwrZone;              // contextWidget['acwr_zone']
  String? acwrRecommendation;    // contextWidget['acwr_recommendation']
  String? dataStatus;            // contextWidget['data_status']
  double? lastNightSleepHours;   // readBiometricHistory sleep_hours, last night

  // BS-005: MetricBar bindings for Load/Sleep cards
  double? loadCeiling;           // getAcwr().chronic_load (the 28-day baseline for bar)
  double? acwrValue;             // getAcwr().acwr — the ratio, not the bar fill
  String? loadBandLine;          // getAcwr().recommendation — "Within today's target band"
  double? sleepNeedHours;        // profile sleep_need (target) — may be null (phone-only)
  String? sourceTierLabel;       // lastObservationSourceTier() → "device-sourced"

  // Zone 3 — Context (from ContextWidget)
  String? lastWorkout;           // contextWidget['last_workout']
  List<String> reactiveAlerts = const [];    // contextWidget['reactive_alerts']
  List<String> patternAdvisories = const []; // contextWidget['pattern_advisories']
  List<double> historyScores = const [];     // readReadinessHistory['readiness_score']
  SourceTier? sourceTier;        // lastObservationSourceTier()
  double? todayLoad;             // readDailyLoads()[today] — cumulative load today

  // Latest completed workout (for home workout row)
  ActivitySummary? latestActivity; // readRecentActivities(limit: 1)[0]

  // Days with observations the engine has returned — drives the learning ring's
  // "day X" why line.
  int observationDays = 0;     // readBiometricHistory distinct-date row count

  // State
  bool insufficientData = false;
  String? error;
  // FL-3: set when a corrupt/incompatible persisted blob forced a fresh
  // start. Surfaced once (non-silent), never swallowed.
  bool historyReset = false;
}

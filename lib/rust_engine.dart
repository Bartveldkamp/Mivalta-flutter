// MVP-1 facade. Wraps the auto-generated flutter_rust_bridge surface
// in lib/src/rust/ so the rest of the app only sees idiomatic Dart —
// no FRB types in signatures here, and the only FRB type that leaks
// is `EnginesHandle` (opaque to Dart by design; the Dart side just
// holds it and hands it back).
//
// **Continuity contract**: the app MUST persist ViterbiEngine state across
// launches. On first run, call `constructEnginesFresh` and immediately
// `saveState` + `writeViterbiState` to persist. On subsequent launches,
// call `constructEnginesFromState` with the previously persisted state JSON.
// See MVP1_BUILD_BRIEF.md STEP 3.
//
// Bridge errors flow through unchanged: every method here re-throws
// the `BridgeError` sealed class from `lib/src/rust/api.dart`, which
// is itself a freezed sealed class with one Dart subclass per
// upstream variant (LibraryNotLoaded / EngineConstructionFailed /
// VaultError / InputError / StateError / RoundTripFailed). Callers
// catch `BridgeError` and switch on variant.

import 'dart:io' show Platform;
import 'dart:typed_data' show Uint8List;

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart'
    show ExternalLibrary;

import 'src/rust/api.dart' as rust_api;
import 'src/rust/api.dart' show BridgeError, EnginesHandle;
import 'src/rust/frb_generated.dart';

export 'src/rust/api.dart' show BridgeError, EnginesHandle;

/// Thin Dart facade over the rust-engine bridge.
class RustEngineBinding {
  RustEngineBinding._();

  /// FRB init is one-shot (calling `RustLib.init()` twice throws). Guard it so
  /// the two sequential entry points work regardless of order: main.dart's
  /// onboarding completion (which may run before any engine is built) and
  /// [bootstrap]. They are not concurrent, so the plain bool guard is safe here.
  static bool _rustInited = false;
  static Future<void> ensureRustInit() async {
    if (_rustInited) return;
    if (Platform.isAndroid) {
      // Android: dynamic library loaded via dlopen (default FRB behavior)
      await RustLib.init();
    } else if (Platform.isIOS) {
      // iOS: static linking via CocoaPods — symbols are in the executable.
      // The xcframework is embedded via MivaltaRustBridge.podspec.
      // ExternalLibrary.process uses DynamicLibrary.process() which looks up
      // symbols linked into the running process (static linking), not dlopen.
      await RustLib.init(
        externalLibrary: ExternalLibrary.process(iKnowHowToUseIt: true),
      );
    } else {
      throw UnsupportedError(
        'Mivalta-flutter requires Android or iOS; '
        'host/desktop not supported (no native library)',
      );
    }
    _rustInited = true;
  }

  /// Initialise the FRB runtime and return a ready-to-use binding.
  /// Host runs (desktop/test) throw a clear error — no native library.
  static Future<RustEngineBinding> bootstrap() async {
    await ensureRustInit();
    return RustEngineBinding._();
  }

  /// FL-16: complete an onboarding profile from RAW inputs. Stateless — no
  /// engine handle needed — so onboarding can call it before any engine exists.
  /// The ENGINE derives goal_class, the mesocycle, meso_minutes, and per-sport
  /// anchor gating; the client computed none of it.
  static Future<String> buildOnboardingProfile(String inputsJson) async {
    await ensureRustInit();
    return rust_api.buildOnboardingProfile(inputsJson: inputsJson);
  }

  /// Day-2 smoke test — `gatc_ffi::hello_uniffi()`.
  Future<String> hello() => rust_api.engineHello();

  // ===========================================================================
  // CONSTRUCTION — two paths: fresh (first run) vs restore (subsequent launches)
  // ===========================================================================

  /// Construct all engines for a FIRST RUN (no persisted state exists).
  ///
  /// After calling this, immediately call [saveState] and persist the result
  /// via [writeViterbiState] so subsequent launches can restore via
  /// [constructEnginesFromState].
  Future<EnginesHandle> constructEnginesFresh({
    required String athleteProfileJson,
    required String tablesJson,
    required String vaultPath,
  }) {
    return rust_api.constructEnginesFresh(
      athleteProfileJson: athleteProfileJson,
      tablesJson: tablesJson,
      vaultPath: vaultPath,
    );
  }

  /// Construct all engines from PERSISTED STATE (subsequent launches).
  ///
  /// [viterbiStateJson] is the JSON returned by a prior [saveState] call.
  /// The ViterbiEngine is restored via `from_persisted_state()`, preserving the
  /// learned HMM, ceiling intelligence, OutcomeTracker, etc. across app restarts.
  ///
  /// If the state JSON is invalid or corrupted, throws [BridgeError]. Handle
  /// this by falling back to [constructEnginesFresh] and accepting the state
  /// reset.
  Future<EnginesHandle> constructEnginesFromState({
    required String athleteProfileJson,
    required String tablesJson,
    required String vaultPath,
    required String viterbiStateJson,
  }) {
    return rust_api.constructEnginesFromState(
      athleteProfileJson: athleteProfileJson,
      tablesJson: tablesJson,
      vaultPath: vaultPath,
      viterbiStateJson: viterbiStateJson,
    );
  }

  /// Legacy constructor for backward compatibility with existing screens.
  /// Delegates to [constructEnginesFresh]. New code should use the explicit
  /// [constructEnginesFresh] / [constructEnginesFromState] pair.
  Future<EnginesHandle> constructEngines({
    required String athleteProfileJson,
    required String tablesJson,
    required String vaultPath,
  }) {
    return rust_api.constructEngines(
      athleteProfileJson: athleteProfileJson,
      tablesJson: tablesJson,
      vaultPath: vaultPath,
    );
  }

  // ===========================================================================
  // VITERBI ENGINE — fatigue monitoring, readiness
  // ===========================================================================

  /// `ViterbiEngine::readiness_score()` — returns raw JSON
  /// `{"score": int, "advisories": {...}}`.
  Future<String> readinessScore(EnginesHandle handle) =>
      rust_api.readinessScore(handle: handle);

  /// `ViterbiEngine::readiness_indicator()` — the 4-axis readiness blend
  /// (HMM posteriors + Banister + physio + psychological), with per-axis
  /// breakdown, level, and confidence. This is the headline number for the
  /// three-zone PULL home.
  Future<String> readinessIndicator(EnginesHandle handle) =>
      rust_api.readinessIndicator(handle: handle);

  /// `ViterbiEngine::state_advisory()` — `{state_recommendation,
  /// confidence_advisory}`, card-sourced. Dashboard removal Phase 2: the home +
  /// detail read state prose from here (replaces the dashboard StateWidget).
  Future<String> stateAdvisory(EnginesHandle handle) =>
      rust_api.stateAdvisory(handle: handle);

  /// `gatc_ffi::realize_advisor_line(...)` — the deterministic, firewall-validated
  /// Josi ADVISOR line. Returns a raw `RealizedLine` JSON (`text`, `safety[]`,
  /// `degraded`); the caller parses it with `RealizedLine.parse`. [date] is the
  /// ISO `YYYY-MM-DD` the engine should realize for (engine has no clock). Pure
  /// pass-through. Throws (BridgeError) when the engine can't supply a faithful
  /// line — the caller treats that as honest absence.
  Future<String> realizeAdvisorLine(EnginesHandle handle,
          {required String date}) =>
      rust_api.realizeAdvisorLine(handle: handle, date: date);

  /// `gatc_ffi::realize_workout_reflection(...)` — the S1 post-workout coach
  /// reaction (voice wiring train, engine #388). Raw `RealizedLine` JSON;
  /// ungraded sessions get the honest "logged, not judged" line, never a
  /// fabricated grade. Throws when the activity is unknown — the caller
  /// treats that as honest absence.
  Future<String> realizeWorkoutReflection(EnginesHandle handle,
          {required String activityId, required String date}) =>
      rust_api.realizeWorkoutReflection(
          handle: handle, activityId: activityId, date: date);

  /// `gatc_ffi::realize_advisory_offer(...)` — the S3 Josi offer line for an
  /// advisor option (voice wiring train, engine #388). [optionJson] is the
  /// engine's own WorkoutOption JSON couriered back verbatim; [readinessLevel]
  /// is the engine's readiness band token. The returned `RealizedLine`
  /// carries `why`/`purpose` for the disclosure tap.
  Future<String> realizeAdvisoryOffer(EnginesHandle handle,
          {required String optionJson,
          required String readinessLevel,
          required String date}) =>
      rust_api.realizeAdvisoryOffer(
          handle: handle,
          optionJson: optionJson,
          readinessLevel: readinessLevel,
          date: date);

  /// `gatc_ffi::realize_day_summary(...)` — the S4 end-of-day coach summary
  /// (voice wiring train, engine #388). The engine derives the day shape
  /// (rest/single/multi) from the vault's real activity count for [date].
  /// Raw `RealizedLine` JSON.
  Future<String> realizeDaySummary(EnginesHandle handle,
          {required String date}) =>
      rust_api.realizeDaySummary(handle: handle, date: date);

  /// `gatc_ffi::morning_read_verdict(...)` — BS-012 moved ENGINE-side
  /// (founder decision 2026-07-06): the engine decides fire/silent and
  /// assembles the card-worded title (never the raw state token) + body
  /// (state advisory verbatim, or honestly empty). Dart couriers only the
  /// delivery context in. Returns JSON `{fire, reason, state,
  /// sufficiency_bucket, title, body}`.
  Future<String> morningReadVerdict(EnginesHandle handle,
          {required String presence,
          String? lastDeliveredState,
          String? lastDeliveredBucket,
          required bool alreadyNotifiedToday}) =>
      rust_api.morningReadVerdict(
          handle: handle,
          presence: presence,
          lastDeliveredState: lastDeliveredState,
          lastDeliveredBucket: lastDeliveredBucket,
          alreadyNotifiedToday: alreadyNotifiedToday);

  /// `ViterbiEngine::get_acwr()` — AcwrResult JSON (acwr, zone, recommendation,
  /// …). Dashboard removal Phase 2: home today-facts + Explore load context.
  Future<String> getAcwr(EnginesHandle handle) =>
      rust_api.getAcwr(handle: handle);

  /// `ViterbiEngine::get_monotony_strain()` — MonotonyStrainResult JSON
  /// (monotony, strain, zone, recommendation, …). Explore load context.
  Future<String> getMonotonyStrain(EnginesHandle handle) =>
      rust_api.getMonotonyStrain(handle: handle);

  /// `ViterbiEngine::pending_advisories()` — PendingAdvisories JSON
  /// (reactive_alerts[].message, pattern_advisories[].description). Home context.
  Future<String> pendingAdvisories(EnginesHandle handle) =>
      rust_api.pendingAdvisories(handle: handle);

  /// `VaultEngine::last_workout_summary()` — one-line narrative summary of the
  /// most recent activity (empty when none). Home "last workout" line.
  Future<String> lastWorkoutSummary(EnginesHandle handle) =>
      rust_api.lastWorkoutSummary(handle: handle);

  /// `ViterbiEngine::get_readiness()` — full snapshot JSON, contains
  /// `fatigue_state` alongside the rest of the readiness state.
  Future<String> viterbiFatigueState(EnginesHandle handle) =>
      rust_api.viterbiFatigueState(handle: handle);

  /// `ViterbiEngine::validation_report()` — on-device prediction-vs-reality
  /// validation (`data_sufficiency`, `paired_observations`, `period_days`,
  /// `overall_model_score`, nested accuracy). The "is the model validated for
  /// you yet" read.
  Future<String> validationReport(EnginesHandle handle) =>
      rust_api.validationReport(handle: handle);

  /// `ViterbiEngine::personalization_diagnostics()` — learning-progress
  /// diagnostics (`observation_count`, `confidence` bucket, optional HRV
  /// windows/episode). JSON `null` until the first observation.
  Future<String> personalizationDiagnostics(EnginesHandle handle) =>
      rust_api.personalizationDiagnostics(handle: handle);

  /// `ViterbiEngine::zone_cap_with_advisories()` — raw JSON
  /// `{"zone": "Z8|Z5|Z2|REST", "advisories": {...}}`.
  Future<String> zoneCapWithAdvisories(EnginesHandle handle) =>
      rust_api.zoneCapWithAdvisories(handle: handle);

  /// `ViterbiEngine::save_state()` — serialize the current HMM state to JSON.
  /// Call this after any state-changing operation and persist the result to
  /// the vault via [writeViterbiState]. On next launch, pass this JSON
  /// to [constructEnginesFromState] to restore continuity.
  Future<String> saveState(EnginesHandle handle) =>
      rust_api.saveState(handle: handle);
  /// `ViterbiEngine::pause_learning()` — V4 global privacy setting: stop ALL
  /// personal adaptation (HMM, ceiling intelligence, OutcomeTracker) until
  /// [resumeLearning] is called. The engine still processes observations but
  /// does not update learned parameters.
  Future<void> pauseLearning(EnginesHandle handle) =>
      rust_api.pauseLearning(handle: handle);

  /// `ViterbiEngine::resume_learning()` — lift the V4 privacy pause.
  Future<void> resumeLearning(EnginesHandle handle) =>
      rust_api.resumeLearning(handle: handle);

  /// `ViterbiEngine::is_learning_paused()` — read the V4 pause flag for the
  /// Settings toggle state.
  Future<bool> isLearningPaused(EnginesHandle handle) =>
      rust_api.isLearningPaused(handle: handle);


  /// `ViterbiEngine::process_observation(observation_json)` — feed a
  /// UniversalObservation (JSON) to the HMM. Returns the updated assessment
  /// JSON including fatigue_state, readiness_level, confidence, etc.
  ///
  /// Use this for vendor-normalized observations (from [normalizeObservation]).
  /// For manual entry, prefer [processManualObservation] which builds the
  /// typed observation in Rust with proper defaults.
  Future<String> processObservation(
    EnginesHandle handle, {
    required String observationJson,
  }) =>
      rust_api.processObservation(handle: handle, observationJson: observationJson);

  /// Build and process a manual observation entry in Rust.
  ///
  /// This helper constructs a typed UniversalObservation with `source="manual"`
  /// and `tier=Minimal`, then processes it through the HMM. Keeps JSON hand-building
  /// out of Dart and ensures honest provenance.
  ///
  /// [isoDate] must parse as `YYYY-MM-DD`; throws [BridgeError.invalidDate] if not.
  /// All biometric fields are optional; pass `null` for fields the user didn't enter.
  Future<String> processManualObservation(
    EnginesHandle handle, {
    required String isoDate,
    double? restingHr,
    double? hrvRmssd,
    double? sleepHours,
    int? rpe,
  }) =>
      rust_api.processManualObservation(
        handle: handle,
        isoDate: isoDate,
        restingHr: restingHr,
        hrvRmssd: hrvRmssd,
        sleepHours: sleepHours,
        rpe: rpe,
      );

  // ===========================================================================
  // ADVISOR ENGINE — workout suggestions (A/B/C options)
  // ===========================================================================

  // The stateless `recommendWorkout` facade was removed in the 2.1 advisor
  // history wire: both production surfaces (Today, Advisor) now call
  // `recommendWorkoutWithHistory`, which subsumes it (the engine falls back to
  // baseline behaviour on an empty/balanced history). The engine-side
  // `recommend_workout` FFI method and the generated binding remain — only the
  // caller-less hand-written facade is gone (no-dead-code rule 7).
  /// `AdvisorEngine::recommend_workout_with_history(...)` — Phase-2 unified
  /// selector using the activity history window. The shim reads recent
  /// activities from the vault internally, so no history JSON is passed from
  /// Dart. This is the path that enables system rotation, dose progression,
  /// and B5 calibration.
  Future<String> recommendWorkoutWithHistory(
    EnginesHandle handle, {
    String? mood,
    String? equipment,
    String? terrain,
  }) =>
      rust_api.recommendWorkoutWithHistory(
        handle: handle,
        mood: mood,
        equipment: equipment,
        terrain: terrain,
      );

  /// `VaultEngine::write_assessment(...)` — the #3 readiness write-back. Persists
  /// the engine's CURRENT 4-axis readiness indicator (+ Viterbi fatigue state) to
  /// `date`'s biometrics readiness columns, so the Journey charts read it back.
  /// The shim owns the honest-absence skip (no readiness yet → nothing written);
  /// Dart only couriers the date. Returns `true` if a row was written, `false`
  /// if skipped on honest absence.
  Future<bool> writeReadinessAssessment(
    EnginesHandle handle, {
    required String date,
  }) =>
      rust_api.writeReadinessAssessment(handle: handle, date: date);


  // ===========================================================================
  // VAULT ENGINE — on-device encrypted storage
  // ===========================================================================

  /// `VaultEngine::read_default_profile()` — round-trips the profile
  /// through the on-device encrypted vault.
  Future<String> vaultSnapshot(EnginesHandle handle) =>
      rust_api.vaultSnapshot(handle: handle);

  /// `VaultEngine::last_observation_source_tier()` — JSON `"Medical"`,
  /// `"Device"`, `"Partial"`, or `"Manual"` for the most recent
  /// biometric observation; JSON `null` if the vault has no
  /// biometric rows yet. Callers parse with `jsonDecode`.
  Future<String> lastObservationSourceTier(EnginesHandle handle) =>
      rust_api.lastObservationSourceTier(handle: handle);

  /// `VaultEngine::read_readiness_history(days)` — series of readiness
  /// snapshots for the past N days, driving the home/detail trend chart.
  Future<String> readReadinessHistory(EnginesHandle handle, {required int days}) =>
      rust_api.readReadinessHistory(handle: handle, days: days);

  /// `VaultEngine::read_daily_loads` — daily training load (`load_uls` per day)
  /// for the past N days, JSON `[[date, load], ...]`. Monitor load surface.
  Future<String> readDailyLoads(EnginesHandle handle, {required int days}) =>
      rust_api.readDailyLoads(handle: handle, days: days);

  /// `VaultEngine::list_data_sources` — distinct vault data sources with
  /// per-source metric capabilities/counts. Feeds the You provenance panel
  /// and is the designed input for [buildSourceOverview] (PR-C3).
  Future<String> listDataSources(EnginesHandle handle) =>
      rust_api.listDataSources(handle: handle);

  /// `VaultEngine::read_activities_in_range` — every stored activity in the
  /// closed `yyyy-MM-dd` window, pageable arbitrarily far back. Journey
  /// history list ("open ANY past workout" — PR-B; screen lands in PR-C).
  Future<String> readActivitiesInRange(
    EnginesHandle handle, {
    required String start,
    required String end,
  }) =>
      rust_api.readActivitiesInRange(handle: handle, start: start, end: end);

  /// `VaultEngine::metabolic_time_in_zone_rollup` — engine-summed
  /// time-in-metabolic-level over the window (week/meso recall). The sum is
  /// the ENGINE's; Dart displays (PR-B; screen lands in PR-C).
  Future<String> metabolicTimeInZoneRollup(
    EnginesHandle handle, {
    required String start,
    required String end,
  }) =>
      rust_api.metabolicTimeInZoneRollup(
          handle: handle, start: start, end: end);

  /// `VaultEngine::import_encrypted_vault` — restore a `.mvbackup` blob (the
  /// V5 export's inverse). Engine owns decryption/validation/overwrite; wrong
  /// passphrase fails loud, never a partial import (PR-B; restore UI in PR-C).
  Future<String> importEncryptedVault(
    EnginesHandle handle, {
    required String athleteId,
    required String passphrase,
    required List<int> blob,
    required bool overwrite,
  }) =>
      rust_api.importEncryptedVault(
        handle: handle,
        athleteId: athleteId,
        passphrase: passphrase,
        blob: blob,
        overwrite: overwrite,
      );

  /// `ViterbiEngine::hrv_trend` — HRV trend over short/mid/long windows
  /// (descriptive, honest-absent; engine bands DRAFT). Journey trend surface
  /// (PR-B; screen lands in PR-C).
  Future<String> hrvTrend(EnginesHandle handle) =>
      rust_api.hrvTrend(handle: handle);

  /// `ViterbiEngine::rhr_trend` — Resting-HR trend over short/mid/long windows
  /// (descriptive, honest-absent; engine bands DRAFT). Journey trend surface
  /// (PR-B; screen lands in PR-C).
  Future<String> rhrTrend(EnginesHandle handle) =>
      rust_api.rhrTrend(handle: handle);

  /// `VaultEngine::read_mmp_history` — rolling mean-maximal power curve JSON
  /// (`{"points":[...]}` or `null`). Monitor power-profile surface.
  Future<String> readMmpHistory(EnginesHandle handle) =>
      rust_api.readMmpHistory(handle: handle);

  // ──────────────────────────────────────────────────────────────────────────
  // Activity ingestion (Recipe 4) — write completed workouts to vault
  // ──────────────────────────────────────────────────────────────────────────

  /// `VaultEngine::write_activity` — persist a completed activity to the vault.
  /// The [activityJson] is VaultActivity JSON (completed_at, activity_type,
  /// duration_minutes, load_uls, load_method). Activity ingestion flow (Recipe 4).
  Future<void> writeActivity(EnginesHandle handle,
          {required String activityJson}) =>
      rust_api.writeActivity(handle: handle, activityJson: activityJson);

  /// `PostProcessEngine::process_activity` — run the post-activity producer
  /// pipeline. Takes the activity wire + prior MMP + prior CP fit + policy.
  /// Returns PostProcessResult JSON with updated MMP, power_profile_update,
  /// wbal_series, decoupling, events. Activity ingestion flow (Recipe 4).
  Future<String> processActivity(
    EnginesHandle handle, {
    required String activityJson,
    required String historyJson,
    required String currentFitJson,
    required String policyJson,
  }) =>
      rust_api.processActivity(
        handle: handle,
        activityJson: activityJson,
        historyJson: historyJson,
        currentFitJson: currentFitJson,
        policyJson: policyJson,
      );

  /// `VaultEngine::read_power_profile` — read the persisted PowerProfile
  /// (CP, W', fit metadata). Returns `null` JSON if no profile saved.
  Future<String> readPowerProfile(EnginesHandle handle) =>
      rust_api.readPowerProfile(handle: handle);

  /// `VaultEngine::write_power_profile` — persist the athlete's PowerProfile
  /// after a CP refit. Activity ingestion flow (Recipe 4).
  Future<void> writePowerProfile(EnginesHandle handle,
          {required String profileJson}) =>
      rust_api.writePowerProfile(handle: handle, profileJson: profileJson);

  /// `VaultEngine::write_mmp_history` — persist the rolling MMP curve history
  /// after process_activity. Activity ingestion flow (Recipe 4).
  Future<void> writeMmpHistory(EnginesHandle handle,
          {required String historyJson}) =>
      rust_api.writeMmpHistory(handle: handle, historyJson: historyJson);

  /// `ViterbiEngine::record_activity` — tell the HMM that a training load
  /// happened. [loadJson] is UniversalLoadScore JSON. Call save_state() after.
  /// Activity ingestion flow (Recipe 4).
  Future<void> recordActivity(EnginesHandle handle,
          {required String loadJson}) =>
      rust_api.recordActivity(handle: handle, loadJson: loadJson);

  /// `CpEngine::fit_cp_default(mmpCurveJson)` — Critical Power + W′ fit over the
  /// MMP curve (Monod-Scherrer / Hill). Feed the JSON [readMmpHistory] returns;
  /// yields `{cp_watts, w_prime_joules, r_squared, n_points}`. Monitor
  /// power-profile depth.
  Future<String> fitCp(EnginesHandle handle, {required String mmpCurveJson}) =>
      rust_api.fitCp(handle: handle, mmpCurveJson: mmpCurveJson);

  /// `PostProcessEngine::compute_time_in_zone` — per-zone dwell for one
  /// completed activity, binned through MiValta's own `zone_anchors` scale
  /// (R, Z1..Z8). [activityJson] is the producer activity wire
  /// (`{"completed_at","power_samples":[..],"hr_samples":[..]?,"sample_rate_hz"}`).
  /// Returns `TimeInZone {anchor, seconds:[{zone,seconds}×9], total_seconds}`
  /// JSON. The engine picks the anchor (cycling+FTP+power → power, else HR) and
  /// throws when neither anchor is usable — Monitor time-in-zone surface.
  Future<String> computeTimeInZone(EnginesHandle handle,
          {required String activityJson}) =>
      rust_api.computeTimeInZone(handle: handle, activityJson: activityJson);

  /// `VaultEngine::read_recent_activities(limit)` — recent completed activities
  /// (newest first), JSON array of stored activities. Used to find the latest
  /// workout's date for the workout-detail surface.
  Future<String> readRecentActivities(EnginesHandle handle, {required int limit}) =>
      rust_api.readRecentActivities(handle: handle, limit: limit);

  /// `VaultEngine::get_workout_detail(date)` — completed-workout detail composite
  /// (actuals + engine-graded quality) for a date; JSON matches the Flutter
  /// `WorkoutDetail` contract, or `null` when no activity that date.
  Future<String> getWorkoutDetail(EnginesHandle handle, {required String date}) =>
      rust_api.getWorkoutDetail(handle: handle, date: date);

  /// `VaultEngine::realize_benchmark_change(event_json)` — compose the Phase 3
  /// notify card ("your threshold improved") from a `benchmark_change` event.
  /// Returns `{kind, headline, benchmark_line, disclosure:[…]}` (engine
  /// composes every word, unit-correct) or the string `"null"` when the event
  /// is absent/unknown — honest absence.
  Future<String> realizeBenchmarkChange(EnginesHandle handle, {required String eventJson}) =>
      rust_api.realizeBenchmarkChange(handle: handle, eventJson: eventJson);

  /// `VaultEngine::read_audit_trail(event_type, limit)` — the athlete's audit
  /// ledger newest-first, filtered by `eventType` (empty = all). Used to read
  /// the latest `benchmark_change` row for the notify card. JSON array.
  Future<String> readAuditTrail(EnginesHandle handle,
          {required String eventType, required int limit}) =>
      rust_api.readAuditTrail(handle: handle, eventType: eventType, limit: limit);

  /// `VaultEngine::completed_workout_facts(date)` — the post-workout report's
  /// INPUT facts (engine-classified zone + actuals + quality) for a date; JSON
  /// `CompletedWorkoutFacts`, or `null` when no activity. Pair with
  /// [buildPostWorkoutReport].
  Future<String> completedWorkoutFacts(EnginesHandle handle, {required String date}) =>
      rust_api.completedWorkoutFacts(handle: handle, date: date);

  /// `AdvisorEngine::build_post_workout_report(factsJson)` — the card-grounded
  /// post-workout report (energy system, zone purpose, stimulus/cost note,
  /// quality summary, autocue). Feed the JSON [completedWorkoutFacts] returns.
  Future<String> buildPostWorkoutReport(EnginesHandle handle, {required String factsJson}) =>
      rust_api.buildPostWorkoutReport(handle: handle, factsJson: factsJson);

  /// `VaultEngine::read_biometric_history(days)` — daily biometric snapshots for
  /// the past N days, JSON array incl. `sleep_hours`/`sleep_quality`. Drives the
  /// Monitor sleep-trend surface.
  Future<String> readBiometricHistory(EnginesHandle handle, {required int days}) =>
      rust_api.readBiometricHistory(handle: handle, days: days);

  /// `VaultEngine::recent_decoupling_pct` — trailing-window mean of
  /// `hr_decoupling_pct`, JSON `{"mean_decoupling_pct": <double|null>}`.
  /// Monitor aerobic-decoupling surface.
  Future<String> recentDecouplingPct(EnginesHandle handle, {required int windowDays}) =>
      rust_api.recentDecouplingPct(handle: handle, windowDays: windowDays);

  /// `ViterbiEngine::fitness_series` — long-term Banister fitness *trend*
  /// (the slow shape), JSON `[{date, fitness, fatigue, form}]` ascending.
  /// Distinct from the Viterbi *state*. Monitor fitness-trend surface.
  Future<String> fitnessSeries(EnginesHandle handle, {required int days}) =>
      rust_api.fitnessSeries(handle: handle, days: days);

  /// `VaultEngine::read_metric_across_activities` — dated per-activity metric
  /// series (`normalized_power`, `pace_sec_per_km`, …) for the fitness-trend
  /// actuals overlay. JSON array of `{date, activity_id, value, activity_type}`.
  Future<String> readMetricAcrossActivities(
    EnginesHandle handle, {
    required String metric,
    required String activityType,
    required int limit,
  }) =>
      rust_api.readMetricAcrossActivities(
        handle: handle,
        metric: metric,
        activityType: activityType,
        limit: limit,
      );

  /// `VaultEngine::write_viterbi_state(athlete_id, state_json)` — persist
  /// the ViterbiEngine state to the vault. Call this after [saveState]
  /// to ensure continuity across app restarts.
  Future<void> writeViterbiState(EnginesHandle handle, {required String stateJson}) =>
      rust_api.writeViterbiState(handle: handle, stateJson: stateJson);

  /// `VaultEngine::read_viterbi_state(athlete_id)` — read the persisted
  /// ViterbiEngine state from the vault. Returns JSON `null` if no state
  /// exists (first run).
  Future<String> readViterbiState(EnginesHandle handle) =>
      rust_api.readViterbiState(handle: handle);

  /// `PostProcessEngine::sync_benchmark_from_activities` — the CLOSED
  /// benchmark loop: raw activity streams → sport-native fit (CP watts for
  /// cyclists, Critical Speed distance:time for runners — never crossed) →
  /// confirm/promote gate over the remembered evidence window → the decision
  /// APPLIED to the engine's bound profile. Returns `{decision, applied,
  /// event|null, candidate_history, athlete_profile}`. Dart's duties are all
  /// courier — `BenchmarkSyncService` is the canonical chain.
  Future<String> syncBenchmarkFromActivities(
    EnginesHandle handle, {
    required String activitiesJson,
    required String candidateHistoryJson,
  }) =>
      rust_api.syncBenchmarkFromActivities(
        handle: handle,
        activitiesJson: activitiesJson,
        candidateHistoryJson: candidateHistoryJson,
      );

  /// `VaultEngine::write_benchmark_event` — file a benchmark promotion or
  /// demotion in the encrypted audit ledger (`benchmark_change`). Pass the
  /// sync's `event` object VERBATIM. Returns `{"audit_id": "…"}`.
  Future<String> writeBenchmarkEvent(EnginesHandle handle, {required String eventJson}) =>
      rust_api.writeBenchmarkEvent(handle: handle, eventJson: eventJson);

  /// `VaultEngine::write_benchmark_history` — persist the sync's returned
  /// `candidate_history` VERBATIM (the pattern memory behind "the level
  /// never rises on one workout").
  Future<void> writeBenchmarkHistory(EnginesHandle handle, {required String historyJson}) =>
      rust_api.writeBenchmarkHistory(handle: handle, historyJson: historyJson);

  /// `VaultEngine::read_benchmark_history` — the persisted pattern memory,
  /// or the string `"null"` on first run (honest absence the sync accepts
  /// as an empty evidence window).
  Future<String> readBenchmarkHistory(EnginesHandle handle) =>
      rust_api.readBenchmarkHistory(handle: handle);

  /// `PostProcessEngine::profile()` — the athlete profile as the LIVE engine
  /// holds it. After a benchmark promotion this is the byte-exact source to
  /// persist ([writeProfile]) and re-bind ([updateProfile]) from.
  Future<String> postprocessProfile(EnginesHandle handle) =>
      rust_api.postprocessProfile(handle: handle);

  /// Minimal biometric write for the hardware-verification debug swatch
  /// exerciser. Writes `source` + ISO date + placeholder `restingHr`, so
  /// the next [lastObservationSourceTier] call returns the matching tier.
  /// Throws `BridgeError.invalidDate` if [isoDate] doesn't parse.
  Future<void> writeMinimalBiometric({
    required EnginesHandle handle,
    required String source,
    required String isoDate,
    int restingHr = 60,
  }) =>
      rust_api.writeMinimalBiometric(
        handle: handle,
        source: source,
        isoDate: isoDate,
        restingHr: restingHr,
      );

  // ===========================================================================
  // VAULT-FIRST INGEST (NEXT_BUILD_BRIEF §B)
  // ===========================================================================
  //
  // Write raw observations to the vault BEFORE processing:
  //   1. writeRawObservation(json) → persist raw vendor payload
  //   2. normalizeObservation → writeBiometric (normalized biometrics)
  //   3. processObservation (HMM) → markRawObservationProcessed
  //
  // This preserves the original vendor payload for audit + replay.

  /// `VaultEngine::write_raw_observation(json)` — persist raw vendor observation
  /// BEFORE processing. Returns the row ID for later [markRawObservationProcessed].
  /// JSON must include `date`, `source`, `data_type`, and `payload` fields.
  Future<int> writeRawObservation(EnginesHandle handle, {required String json}) =>
      rust_api.writeRawObservation(handle: handle, json: json);

  /// `VaultEngine::write_biometric(json)` — persist a normalized biometric
  /// observation (VaultBiometric JSON: date, source, resting_hr, hrv_rmssd,
  /// sleep_hours, sleep_quality, etc.). Call after normalizeObservation to
  /// persist biometrics for the Journey biometric pillars.
  Future<void> writeBiometric(EnginesHandle handle, {required String json}) =>
      rust_api.writeBiometric(handle: handle, json: json);

  /// Persist a biometric row from a normalized observation
  /// (`UniversalObservation` JSON from [normalizeObservation]). The engine
  /// converts the observation shape (`resting_hr` f64) to the vault row shape
  /// (`resting_hr` i32). Use this on the ingest path instead of
  /// [writeBiometric], which rejects the observation's float `resting_hr`.
  Future<void> writeBiometricFromObservation(EnginesHandle handle,
          {required String json}) =>
      rust_api.writeBiometricFromObservation(handle: handle, json: json);

  /// `VaultEngine::mark_raw_observation_processed(id, observation_json)` — flag
  /// a raw observation as processed. Pass empty string for observationJson to
  /// skip storing the normalized form alongside the raw.
  Future<void> markRawObservationProcessed(
    EnginesHandle handle, {
    required int id,
    required String observationJson,
  }) =>
      rust_api.markRawObservationProcessed(
        handle: handle,
        id: id,
        observationJson: observationJson,
      );

  /// `VaultEngine::read_raw_observations_by_type(data_type, days)` — fetch raw
  /// observations for a data type (e.g. "biometric", "activity") over the last N
  /// days. Returns JSON array of raw observation records.
  Future<String> readRawObservationsByType(
    EnginesHandle handle, {
    required String dataType,
    required int days,
  }) =>
      rust_api.readRawObservationsByType(
        handle: handle,
        dataType: dataType,
        days: days,
      );

  /// `VaultEngine::read_raw_observations_by_activity(activity_id)` — fetch raw
  /// observations linked to a specific activity ID. Returns JSON array.
  Future<String> readRawObservationsByActivity(
    EnginesHandle handle, {
    required String activityId,
  }) =>
      rust_api.readRawObservationsByActivity(handle: handle, activityId: activityId);

  /// `VaultEngine::read_activity_by_id(activity_id)` — fetch a single stored
  /// activity by its ID. Returns JSON of the VaultActivity or error if not found.
  Future<String> readActivityById(EnginesHandle handle, {required String activityId}) =>
      rust_api.readActivityById(handle: handle, activityId: activityId);

  // ===========================================================================
  // DASHBOARD ENGINE — REMOVED (dashboard removal Phase 2)
  // ===========================================================================
  // The home/detail/explore now read the canonical engines directly
  // (state_advisory, get_acwr, get_monotony_strain, pending_advisories,
  // recommend_workout_with_history, last_workout_summary). The dashboard FFI
  // engine + shim fns were deleted in Phase 3 (rust-engine #356; shim re-pin
  // to the dashboard-less engine in this PR).

  // ===========================================================================
  // NORMALIZER ENGINE — vendor data normalization
  // ===========================================================================

  /// `NormalizerEngine::normalize_observation(vendor, json)` — normalize
  /// vendor-specific observation JSON to a UniversalObservation.
  ///
  /// Supported vendors: garmin, oura, whoop, polar, apple/healthkit,
  /// wahoo, coros, ble. The engine bounds-validates the result before
  /// returning. The Dart side receives a normalized JSON ready to pass
  /// to `ViterbiEngine::process_observation()` (bound in PR-E).
  Future<String> normalizeObservation(
    EnginesHandle handle, {
    required String vendor,
    required String json,
  }) =>
      rust_api.normalizeObservation(handle: handle, vendor: vendor, json: json);

  /// `NormalizerEngine::classify_source(source)` — classify a data source
  /// into a quality tier. Returns JSON with tier, tier_code, and
  /// confidence_acceleration.
  Future<String> classifySource(EnginesHandle handle, {required String source}) =>
      rust_api.classifySource(handle: handle, source: source);

  /// `NormalizerEngine::build_source_overview(sources_json)` — build a
  /// complete "data sources overview" for the mobile UI. Returns which
  /// source is primary for each metric (HRV, sleep, RHR, activity).
  Future<String> buildSourceOverview(EnginesHandle handle, {required String sourcesJson}) =>
      rust_api.buildSourceOverview(handle: handle, sourcesJson: sourcesJson);

  // ===========================================================================
  // CONVENIENCE — check for persisted state before construction
  // ===========================================================================

  /// Check if a persisted ViterbiEngine state exists for the given athlete.
  /// Uses a temporary VaultEngine to query without constructing all engines.
  ///
  /// Returns `true` if state exists and should be restored via
  /// [constructEnginesFromState], `false` if this is a first run and
  /// should use [constructEnginesFresh].
  Future<bool> hasPersistedState({
    required String athleteProfileJson,
    required String vaultPath,
  }) =>
      rust_api.hasPersistedState(
        athleteProfileJson: athleteProfileJson,
        vaultPath: vaultPath,
      );

  /// Read the persisted ViterbiEngine state JSON directly from the vault.
  /// Returns `null` if no state exists (first run), the state JSON otherwise.
  /// Use this to get the state JSON to pass to [constructEnginesFromState].
  Future<String?> readPersistedState({
    required String athleteProfileJson,
    required String vaultPath,
  }) =>
      rust_api.readPersistedState(
        athleteProfileJson: athleteProfileJson,
        vaultPath: vaultPath,
      );

  // ===========================================================================
  // PR-H: VAULT-BASED PROFILE STORAGE — profile now lives in encrypted vault
  // ===========================================================================
  //
  // Bootstrap approach: persist only athlete_id (a random UUID — not personal
  // data) in a tiny plaintext pointer; store the full profile (age/sex/FTP/
  // anchors) in the encrypted vault.

  /// Read the athlete profile from the encrypted vault using just the athlete_id.
  ///
  /// Returns `null` if no profile exists in the vault (first run scenario).
  /// Use this on app launch to retrieve the profile without needing the full
  /// profile JSON first.
  Future<String?> readProfileFromVault({
    required String athleteId,
    required String vaultPath,
  }) =>
      rust_api.readProfileFromVault(
        athleteId: athleteId,
        vaultPath: vaultPath,
      );

  /// Write the athlete profile to the encrypted vault.
  ///
  /// Use this after onboarding to persist the full profile before engines
  /// are constructed. After engines are available, use [writeProfile] instead.
  Future<void> writeProfileToVault({
    required String athleteProfileJson,
    required String vaultPath,
  }) =>
      rust_api.writeProfileToVault(
        athleteProfileJson: athleteProfileJson,
        vaultPath: vaultPath,
      );

  // ===========================================================================
  // PR-G: SETTINGS & DATA CONTROL — profile updates, export, erasure
  // ===========================================================================
  //
  // Zero-fabrication / no-harvesting invariants:
  // - No network calls anywhere
  // - Export writes local file only
  // - Delete is real crypto-erase, not a soft flag

  /// Update the athlete profile across all engines.
  ///
  /// Re-binds ViterbiEngine, AdvisorEngine, and NormalizerEngine.
  /// Call this when the user edits their profile in Settings.
  Future<void> updateProfile(EnginesHandle handle, {required String athleteProfileJson}) =>
      rust_api.updateProfile(handle: handle, athleteProfileJson: athleteProfileJson);

  /// Persist the profile to the encrypted vault.
  ///
  /// Writes a VaultProfile record to vault.db (SQLCipher-encrypted).
  Future<void> writeProfile(EnginesHandle handle, {required String json}) =>
      rust_api.writeProfile(handle: handle, json: json);

  /// Persist a benchmark promotion into the athlete's stored profile.
  ///
  /// The engine merges only the coaching anchors (FTP / threshold pace /
  /// threshold HR / cycling power profile) into the existing VaultProfile,
  /// keeping athlete_id + personal data. This is the correct persistence path
  /// for a promotion — [writeProfile] with a [postprocessProfile] payload
  /// silently failed (a bare AthleteProfile has no athlete_id, so the
  /// VaultProfile writer serde-rejected it and the improvement was lost).
  Future<void> mergeProfileBenchmarks(
    EnginesHandle handle, {
    required String athleteProfileJson,
  }) =>
      rust_api.mergeProfileBenchmarks(
        handle: handle,
        athleteProfileJson: athleteProfileJson,
      );

  /// Read the default profile from the vault.
  ///
  /// Returns the JSON-serialized VaultProfile.
  Future<String> readDefaultProfile(EnginesHandle handle) =>
      rust_api.readDefaultProfile(handle: handle);

  /// Export the entire vault as an encrypted backup blob.
  ///
  /// The blob is passphrase-encrypted (AES-256-GCM). Without the passphrase,
  /// the data is unrecoverable. By design.
  ///
  /// Returns the raw encrypted bytes — save to file via share sheet.
  Future<Uint8List> exportEncryptedVault(
    EnginesHandle handle, {
    required String athleteId,
    required String passphrase,
  }) =>
      rust_api.exportEncryptedVault(
        handle: handle,
        athleteId: athleteId,
        passphrase: passphrase,
      );

  /// Export biometric history as CSV.
  ///
  /// Returns CSV content as a string. `days` controls how many days of
  /// history (0 = all). Save to file via share sheet.
  Future<String> exportBiometricsCsv(EnginesHandle handle, {required int days}) =>
      rust_api.exportBiometricsCsv(handle: handle, days: days);

  /// Permanently erase all user data.
  ///
  /// Destroys the vault key → all encrypted data becomes unrecoverable noise.
  /// Returns a JSON report of what was destroyed.
  ///
  /// **IRREVERSIBLE.** Show confirm dialog before calling.
  Future<String> clearAllUserData(EnginesHandle handle, {required String athleteId}) =>
      rust_api.clearAllUserData(handle: handle, athleteId: athleteId);

  /// Cryptographically erase only the sealed cache key.
  ///
  /// The main vault is unaffected. Use [clearAllUserData] to wipe everything.
  Future<void> cryptoEraseCache(EnginesHandle handle) =>
      rust_api.cryptoEraseCache(handle: handle);
}

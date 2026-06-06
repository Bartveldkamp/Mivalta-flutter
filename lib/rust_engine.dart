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

import 'src/rust/api.dart' as rust_api;
import 'src/rust/api.dart' show BridgeError, EnginesHandle;
import 'src/rust/frb_generated.dart';

export 'src/rust/api.dart' show BridgeError, EnginesHandle;

/// Thin Dart facade over the rust-engine bridge.
class RustEngineBinding {
  RustEngineBinding._();

  /// Initialise the FRB runtime and return a ready-to-use binding.
  /// Day-2 review WARNING 3: gated on Platform.isAndroid — host runs
  /// throw a clear error instead of segfaulting on a missing
  /// `libmivalta_rust_bridge.so`.
  static Future<RustEngineBinding> bootstrap() async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('Mivalta-flutter spike is Android-only');
    }
    await RustLib.init();
    return RustEngineBinding._();
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

  /// `ViterbiEngine::get_readiness()` — full snapshot JSON, contains
  /// `fatigue_state` alongside the rest of the readiness state.
  Future<String> viterbiFatigueState(EnginesHandle handle) =>
      rust_api.viterbiFatigueState(handle: handle);

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

  /// `AdvisorEngine::suggest_workouts(...)` — shim composes the
  /// `SuggesterContext` from live engine state + profile fields.
  ///
  /// Optional [mood], [equipment], and [terrain] parameters allow the UI
  /// to pass user preferences. Defaults: mood="normal", equipment=null,
  /// terrain=null (engine interprets as "any").
  Future<String> recommendWorkout(
    EnginesHandle handle, {
    String? mood,
    String? equipment,
    String? terrain,
  }) =>
      rust_api.recommendWorkout(
        handle: handle,
        mood: mood,
        equipment: equipment,
        terrain: terrain,
      );

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

  /// `VaultEngine::read_mmp_history` — rolling mean-maximal power curve JSON
  /// (`{"points":[...]}` or `null`). Monitor power-profile surface.
  Future<String> readMmpHistory(EnginesHandle handle) =>
      rust_api.readMmpHistory(handle: handle);

  /// `CpEngine::fit_cp_default(mmpCurveJson)` — Critical Power + W′ fit over the
  /// MMP curve (Monod-Scherrer / Hill). Feed the JSON [readMmpHistory] returns;
  /// yields `{cp_watts, w_prime_joules, r_squared, n_points}`. Monitor
  /// power-profile depth.
  Future<String> fitCp(EnginesHandle handle, {required String mmpCurveJson}) =>
      rust_api.fitCp(handle: handle, mmpCurveJson: mmpCurveJson);

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
  // DASHBOARD ENGINE — three-zone PULL home widgets
  // ===========================================================================

  /// `DashboardEngine::get_dashboard()` — composite payload (state + session
  /// + context) as JSON. Drives the three-zone PULL home layout.
  Future<String> getDashboard(EnginesHandle handle) =>
      rust_api.getDashboard(handle: handle);

  /// `DashboardEngine::get_state_widget()` — Tier 1 state widget JSON.
  Future<String> getStateWidget(EnginesHandle handle) =>
      rust_api.getStateWidget(handle: handle);

  /// `DashboardEngine::get_session_widget()` — Tier 2 session widget JSON.
  Future<String> getSessionWidget(EnginesHandle handle) =>
      rust_api.getSessionWidget(handle: handle);

  /// `DashboardEngine::get_context_widget()` — history/load context widget JSON.
  Future<String> getContextWidget(EnginesHandle handle) =>
      rust_api.getContextWidget(handle: handle);

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
  /// Re-binds ViterbiEngine, AdvisorEngine, NormalizerEngine, DashboardEngine.
  /// Call this when the user edits their profile in Settings.
  Future<void> updateProfile(EnginesHandle handle, {required String athleteProfileJson}) =>
      rust_api.updateProfile(handle: handle, athleteProfileJson: athleteProfileJson);

  /// Persist the profile to the encrypted vault.
  ///
  /// Writes a VaultProfile record to vault.db (SQLCipher-encrypted).
  Future<void> writeProfile(EnginesHandle handle, {required String json}) =>
      rust_api.writeProfile(handle: handle, json: json);

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

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

  // ===========================================================================
  // ADVISOR ENGINE — workout suggestions (A/B/C options)
  // ===========================================================================

  /// `AdvisorEngine::suggest_workouts(...)` — shim composes the
  /// `SuggesterContext` from live engine state + profile fields, with
  /// documented defaults for mood / equipment / terrain / phase /
  /// meso_day (no user-input form yet). Raw JSON array of options.
  Future<String> recommendWorkout(EnginesHandle handle) =>
      rust_api.recommendWorkout(handle: handle);

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
}

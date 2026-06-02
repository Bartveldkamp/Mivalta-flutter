//! MVP-1 API surface. Bridges flutter_rust_bridge ↔ gatc-ffi for real-data
//! round trips. Every public function here delegates to an existing
//! `gatc_ffi::*` pub fn; no engine logic is added in this crate. Returns
//! are raw JSON strings (rendered as-is on the Dart side) so no UniFFI
//! record type ever crosses the FRB boundary — Day-2 review WARNING 4.
//!
//! **Continuity contract**: the app MUST persist ViterbiEngine state across
//! launches. On first run, call `construct_engines_fresh` and immediately
//! `save_state` to persist. On subsequent launches, call
//! `construct_engines_from_state` with the previously persisted state JSON.
//! See MVP1_BUILD_BRIEF.md STEP 3.

use flutter_rust_bridge::frb;
use std::sync::Arc;

/// Typed bridge error; FRB emits one Dart subclass per variant.
/// Maps gatc-ffi's six variants (Vault/Input/State/Policy/
/// Consistency/General per rust-engine CLAUDE.md) onto this set —
/// Policy and Consistency fold into `StateError` because the prose
/// distinction is lost on a display-only consumer.
#[derive(Debug, Clone)]
pub enum BridgeError {
    LibraryNotLoaded,
    EngineConstructionFailed(String),
    VaultError(String),
    InputError(String),
    StateError(String),
    RoundTripFailed(String),
    /// ISO-8601 date string couldn't be parsed at the shim before
    /// reaching the engine. Distinct from `InputError` so the debug
    /// exerciser (and future writes) can surface a precise "your date
    /// is malformed" toast instead of the generic JSON schema rejection text.
    InvalidDate(String),
}

impl std::fmt::Display for BridgeError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            BridgeError::LibraryNotLoaded => write!(f, "library not loaded"),
            BridgeError::EngineConstructionFailed(m) => write!(f, "engine construction failed: {m}"),
            BridgeError::VaultError(m) => write!(f, "vault error: {m}"),
            BridgeError::InputError(m) => write!(f, "input error: {m}"),
            BridgeError::StateError(m) => write!(f, "state error: {m}"),
            BridgeError::RoundTripFailed(m) => write!(f, "round-trip failed: {m}"),
            BridgeError::InvalidDate(m) => write!(f, "invalid date: {m}"),
        }
    }
}
impl std::error::Error for BridgeError {}

impl From<gatc_ffi::BridgeError> for BridgeError {
    fn from(e: gatc_ffi::BridgeError) -> Self {
        match e {
            gatc_ffi::BridgeError::Vault(m) => BridgeError::VaultError(m),
            gatc_ffi::BridgeError::Input(m) => BridgeError::InputError(m),
            gatc_ffi::BridgeError::State(m) => BridgeError::StateError(m),
            gatc_ffi::BridgeError::Policy(m) => BridgeError::StateError(format!("policy: {m}")),
            gatc_ffi::BridgeError::Consistency(m) => BridgeError::StateError(format!("consistency: {m}")),
            gatc_ffi::BridgeError::General(m) => BridgeError::RoundTripFailed(m),
        }
    }
}

/// Bundle of all gatc-ffi engines MVP-1 exercises. Opaque to Dart by
/// `#[frb(opaque)]`; Dart only holds an `Arc<EnginesHandle>` proxy and
/// hands it back to method calls.
///
/// Engines included:
/// - ViterbiEngine — fatigue monitoring, readiness, zone cap
/// - AdvisorEngine — workout suggestions (A/B/C options)
/// - VaultEngine — on-device encrypted storage
/// - DashboardEngine — three-zone PULL home widgets
/// - NormalizerEngine — vendor data normalizer (Garmin/Oura/Whoop/Polar/Apple/Wahoo/COROS/BLE)
#[frb(opaque)]
pub struct EnginesHandle {
    viterbi: Arc<gatc_ffi::ViterbiEngine>,
    advisor: Arc<gatc_ffi::AdvisorEngine>,
    vault: Arc<gatc_ffi::VaultEngine>,
    dashboard: Arc<gatc_ffi::DashboardEngine>,
    normalizer: Arc<gatc_ffi::NormalizerEngine>,
    profile_json: String,
    athlete_id: String,
}

/// Day-2 smoke test — kept so the existing engine-hello status line
/// in main.dart stays green.
pub fn engine_hello() -> String {
    gatc_ffi::hello_uniffi()
}

// =============================================================================
// CONSTRUCTION — two paths: fresh (first run) vs restore (subsequent launches)
// =============================================================================

/// Construct all engines for a FIRST RUN (no persisted state exists).
///
/// After calling this, the Dart side MUST immediately call `save_state()`
/// and persist the returned JSON so subsequent launches can restore via
/// `construct_engines_from_state()`. The plain `new()` seed constructor is
/// only reachable here — the restore path uses `from_persisted_state()`.
pub fn construct_engines_fresh(
    athlete_profile_json: String,
    tables_json: String,
    vault_path: String,
) -> Result<EnginesHandle, BridgeError> {
    let athlete_id = extract_athlete_id(&athlete_profile_json)?;

    let viterbi = gatc_ffi::ViterbiEngine::new(athlete_profile_json.clone())
        .map_err(|e| BridgeError::EngineConstructionFailed(format!("viterbi: {e}")))?;
    let advisor = gatc_ffi::AdvisorEngine::new(athlete_profile_json.clone(), tables_json.clone())
        .map_err(|e| BridgeError::EngineConstructionFailed(format!("advisor: {e}")))?;
    let vault = gatc_ffi::VaultEngine::new(athlete_profile_json.clone(), vault_path.clone())
        .map_err(|e| BridgeError::EngineConstructionFailed(format!("vault: {e}")))?;
    let dashboard = gatc_ffi::DashboardEngine::new(
        athlete_profile_json.clone(),
        vault_path.clone(),
        tables_json.clone(),
    )
    .map_err(|e| BridgeError::EngineConstructionFailed(format!("dashboard: {e}")))?;
    let normalizer = gatc_ffi::NormalizerEngine::new(athlete_profile_json.clone())
        .map_err(|e| BridgeError::EngineConstructionFailed(format!("normalizer: {e}")))?;

    Ok(EnginesHandle {
        viterbi,
        advisor,
        vault,
        dashboard,
        normalizer,
        profile_json: athlete_profile_json,
        athlete_id,
    })
}

/// Construct all engines from PERSISTED STATE (subsequent launches).
///
/// `viterbi_state_json` is the JSON returned by a prior `save_state()` call.
/// The ViterbiEngine is restored via `from_persisted_state()`, preserving the
/// learned HMM, ceiling intelligence, OutcomeTracker, etc. across app restarts.
///
/// If the state JSON is invalid or corrupted, returns an error. The Dart side
/// should handle this by falling back to `construct_engines_fresh()` and
/// accepting the state reset.
pub fn construct_engines_from_state(
    athlete_profile_json: String,
    tables_json: String,
    vault_path: String,
    viterbi_state_json: String,
) -> Result<EnginesHandle, BridgeError> {
    let athlete_id = extract_athlete_id(&athlete_profile_json)?;

    let viterbi = gatc_ffi::ViterbiEngine::from_persisted_state(
        athlete_profile_json.clone(),
        viterbi_state_json,
    )
    .map_err(|e| BridgeError::EngineConstructionFailed(format!("viterbi restore: {e}")))?;

    let advisor = gatc_ffi::AdvisorEngine::new(athlete_profile_json.clone(), tables_json.clone())
        .map_err(|e| BridgeError::EngineConstructionFailed(format!("advisor: {e}")))?;
    let vault = gatc_ffi::VaultEngine::new(athlete_profile_json.clone(), vault_path.clone())
        .map_err(|e| BridgeError::EngineConstructionFailed(format!("vault: {e}")))?;
    let dashboard = gatc_ffi::DashboardEngine::new(
        athlete_profile_json.clone(),
        vault_path.clone(),
        tables_json.clone(),
    )
    .map_err(|e| BridgeError::EngineConstructionFailed(format!("dashboard: {e}")))?;
    let normalizer = gatc_ffi::NormalizerEngine::new(athlete_profile_json.clone())
        .map_err(|e| BridgeError::EngineConstructionFailed(format!("normalizer: {e}")))?;

    Ok(EnginesHandle {
        viterbi,
        advisor,
        vault,
        dashboard,
        normalizer,
        profile_json: athlete_profile_json,
        athlete_id,
    })
}

/// Legacy constructor for backward compatibility with existing screens.
/// Delegates to `construct_engines_fresh`. New code should use the explicit
/// `construct_engines_fresh` / `construct_engines_from_state` pair.
pub fn construct_engines(
    athlete_profile_json: String,
    tables_json: String,
    vault_path: String,
) -> Result<EnginesHandle, BridgeError> {
    construct_engines_fresh(athlete_profile_json, tables_json, vault_path)
}

fn extract_athlete_id(profile_json: &str) -> Result<String, BridgeError> {
    let profile: serde_json::Value = serde_json::from_str(profile_json)
        .map_err(|e| BridgeError::InputError(format!("profile parse: {e}")))?;
    profile
        .get("athlete_id")
        .and_then(|v| v.as_str())
        .map(|s| s.to_string())
        .ok_or_else(|| BridgeError::InputError("missing athlete_id in profile".to_string()))
}

// =============================================================================
// VITERBI ENGINE — fatigue monitoring, readiness
// =============================================================================

/// `ViterbiEngine::readiness_score()` — JSON `{"score":i32, "advisories":...}`.
pub fn readiness_score(handle: &EnginesHandle) -> Result<String, BridgeError> {
    handle.viterbi.readiness_score().map_err(Into::into)
}

/// `ViterbiEngine::readiness_indicator()` — the 4-axis readiness blend
/// (HMM posteriors + Banister + physio + psychological), with per-axis
/// breakdown, level, and confidence. This is the headline number for the
/// three-zone PULL home.
pub fn readiness_indicator(handle: &EnginesHandle) -> Result<String, BridgeError> {
    handle.viterbi.readiness_indicator().map_err(Into::into)
}

/// `ViterbiEngine::get_readiness()` — full snapshot JSON including
/// `fatigue_state`. gatc-ffi exposes the state through the snapshot,
/// not as a standalone scalar; Dart parses/renders as-is.
pub fn viterbi_fatigue_state(handle: &EnginesHandle) -> Result<String, BridgeError> {
    handle.viterbi.get_readiness().map_err(Into::into)
}

/// `ViterbiEngine::zone_cap_with_advisories()`.
pub fn zone_cap_with_advisories(handle: &EnginesHandle) -> Result<String, BridgeError> {
    handle.viterbi.zone_cap_with_advisories().map_err(Into::into)
}

/// `ViterbiEngine::save_state()` — serialize the current HMM state to JSON.
/// Call this after any state-changing operation and persist the result to
/// the vault via `write_viterbi_state()`. On next launch, pass this JSON
/// to `construct_engines_from_state()` to restore continuity.
pub fn save_state(handle: &EnginesHandle) -> Result<String, BridgeError> {
    handle.viterbi.save_state().map_err(Into::into)
}

// =============================================================================
// ADVISOR ENGINE — workout suggestions (A/B/C options)
// =============================================================================

/// `AdvisorEngine::suggest_workouts(...)`. SuggesterContext is composed
/// from (a) the engine-bound profile and (b) live `readiness_score` —
/// no per-call user input (no mood/equipment/terrain form in the
/// MVP-1 UI), so those fields use defaults — see PR body.
pub fn recommend_workout(handle: &EnginesHandle) -> Result<String, BridgeError> {
    let profile: serde_json::Value = serde_json::from_str(&handle.profile_json)
        .map_err(|e| BridgeError::InputError(format!("profile re-parse: {e}")))?;
    let readiness_str = handle.viterbi.readiness_score().map_err(BridgeError::from)?;
    let readiness: serde_json::Value = serde_json::from_str(&readiness_str)
        .map_err(|e| BridgeError::RoundTripFailed(format!("readiness_score JSON: {e}")))?;
    let score = readiness.get("score").and_then(|v| v.as_i64()).unwrap_or(50) as i32;
    let readiness_level = if score >= 75 { "high" } else if score >= 40 { "medium" } else { "low" };
    let s = |k: &str, d: &str| profile.get(k).and_then(|v| v.as_str()).unwrap_or(d).to_string();
    let i = |k: &str, d: i64| profile.get(k).and_then(|v| v.as_i64()).unwrap_or(d) as i32;
    let ctx = serde_json::json!({
        "athlete_id": s("athlete_id", "smoketest-user"),
        "date": chrono::Local::now().naive_local().date().format("%Y-%m-%d").to_string(),
        "duration_minutes": i("available_minutes_per_day", 60),
        "sport": s("sport", "cycling"),
        "mood": "normal", "goal": s("goal_type", "general_fitness"),
        "equipment": serde_json::Value::Null, "terrain": serde_json::Value::Null,
        "readiness_level": readiness_level, "readiness_score": score,
        "state": "Recovered", "confidence": "medium", "warm_up_period": false,
        "level": s("level", "intermediate"), "age": i("age", 30),
        "phase": "general_prep", "meso_day": 0, "meso_days": 21,
        "variant_seed": 0, "session_class": "standard",
    });
    handle.advisor.suggest_workouts(ctx.to_string()).map_err(Into::into)
}

// =============================================================================
// VAULT ENGINE — on-device encrypted storage
// =============================================================================

/// `VaultEngine::read_default_profile()` — round-trips the profile
/// through the on-device vault. With a fresh vault this is the seed
/// profile read back, proving write→read is live.
pub fn vault_snapshot(handle: &EnginesHandle) -> Result<String, BridgeError> {
    handle.vault.read_default_profile().map_err(Into::into)
}

/// `VaultEngine::last_observation_source_tier()` — JSON `"Medical"` /
/// `"Device"` / `"Partial"` / `"Manual"` for the most recent biometric
/// observation on disk, or JSON `null` if the vault has no biometric
/// rows yet. Dart parses with `jsonDecode`; a `null` decoded value is
/// the engine's "insufficient data" signal for the SourceTier swatch.
pub fn last_observation_source_tier(handle: &EnginesHandle) -> Result<String, BridgeError> {
    handle
        .vault
        .last_observation_source_tier()
        .map_err(Into::into)
}

/// `VaultEngine::read_readiness_history(days)` — series of readiness
/// snapshots for the past N days, driving the home/detail trend chart.
pub fn read_readiness_history(handle: &EnginesHandle, days: i32) -> Result<String, BridgeError> {
    handle.vault.read_readiness_history(days).map_err(Into::into)
}

/// `VaultEngine::write_viterbi_state(athlete_id, json)` — persist the
/// ViterbiEngine state to the vault. Call this after `save_state()` to
/// ensure continuity across app restarts.
pub fn write_viterbi_state(handle: &EnginesHandle, state_json: String) -> Result<(), BridgeError> {
    handle
        .vault
        .write_viterbi_state(handle.athlete_id.clone(), state_json)
        .map_err(Into::into)
}

/// `VaultEngine::read_viterbi_state(athlete_id)` — read the persisted
/// ViterbiEngine state from the vault. Returns JSON `null` if no state
/// exists (first run). Use this at launch to check whether to call
/// `construct_engines_from_state()` or `construct_engines_fresh()`.
pub fn read_viterbi_state(handle: &EnginesHandle) -> Result<String, BridgeError> {
    handle
        .vault
        .read_viterbi_state(handle.athlete_id.clone())
        .map_err(Into::into)
}

/// Minimal biometric write for the hardware-verification debug swatch
/// exerciser. Composes a minimal VaultBiometric JSON with `date`,
/// `source`, and a placeholder `resting_hr` so the next
/// `last_observation_source_tier` call returns the matching tier and
/// the readiness screen's section (e) picks up the LOCKED swatch.
///
/// `iso_date` must parse as `YYYY-MM-DD`; on failure the shim emits
/// `BridgeError::InvalidDate` *before* touching the vault.
pub fn write_minimal_biometric(
    handle: &EnginesHandle,
    source: String,
    iso_date: String,
    resting_hr: i32,
) -> Result<(), BridgeError> {
    chrono::NaiveDate::parse_from_str(&iso_date, "%Y-%m-%d")
        .map_err(|e| BridgeError::InvalidDate(format!("{iso_date}: {e}")))?;
    let payload = serde_json::json!({
        "date": iso_date,
        "source": source,
        "resting_hr": resting_hr,
    });
    handle
        .vault
        .write_biometric(payload.to_string())
        .map_err(Into::into)
}

// =============================================================================
// DASHBOARD ENGINE — three-zone PULL home widgets
// =============================================================================

/// `DashboardEngine::get_dashboard()` — composite payload (state + session
/// + context) as JSON. Drives the three-zone PULL home layout.
pub fn get_dashboard(handle: &EnginesHandle) -> Result<String, BridgeError> {
    handle.dashboard.get_dashboard().map_err(Into::into)
}

/// `DashboardEngine::get_state_widget()` — Tier 1 state widget JSON.
pub fn get_state_widget(handle: &EnginesHandle) -> Result<String, BridgeError> {
    handle.dashboard.get_state_widget().map_err(Into::into)
}

/// `DashboardEngine::get_session_widget()` — Tier 2 session widget JSON.
pub fn get_session_widget(handle: &EnginesHandle) -> Result<String, BridgeError> {
    handle.dashboard.get_session_widget().map_err(Into::into)
}

/// `DashboardEngine::get_context_widget()` — history/load context widget JSON.
pub fn get_context_widget(handle: &EnginesHandle) -> Result<String, BridgeError> {
    handle.dashboard.get_context_widget().map_err(Into::into)
}

// =============================================================================
// NORMALIZER ENGINE — vendor data normalization
// =============================================================================

/// `NormalizerEngine::normalize_observation(vendor, json)` — normalize
/// vendor-specific observation JSON to a UniversalObservation.
///
/// Supported vendors: garmin, oura, whoop, polar, apple/healthkit,
/// wahoo, coros, ble. The engine bounds-validates the result before
/// returning. The Dart side receives a normalized JSON ready to pass
/// to `ViterbiEngine::process_observation()`.
pub fn normalize_observation(
    handle: &EnginesHandle,
    vendor: String,
    json: String,
) -> Result<String, BridgeError> {
    handle
        .normalizer
        .normalize_observation(vendor, json)
        .map_err(Into::into)
}

/// `NormalizerEngine::classify_source(source)` — classify a data source
/// into a quality tier. Returns JSON with tier, tier_code, and
/// confidence_acceleration.
pub fn classify_source(handle: &EnginesHandle, source: String) -> Result<String, BridgeError> {
    handle.normalizer.classify_source(source).map_err(Into::into)
}

/// `NormalizerEngine::build_source_overview(sources_json)` — build a
/// complete "data sources overview" for the mobile UI. Returns which
/// source is primary for each metric (HRV, sleep, RHR, activity).
pub fn build_source_overview(
    handle: &EnginesHandle,
    sources_json: String,
) -> Result<String, BridgeError> {
    handle
        .normalizer
        .build_source_overview(sources_json)
        .map_err(Into::into)
}

// =============================================================================
// CONVENIENCE — check for persisted state before construction
// =============================================================================

/// Check if a persisted ViterbiEngine state exists for the given athlete.
/// Uses a temporary VaultEngine to query without constructing all engines.
///
/// Returns `true` if state exists and should be restored via
/// `construct_engines_from_state()`, `false` if this is a first run and
/// should use `construct_engines_fresh()`.
pub fn has_persisted_state(
    athlete_profile_json: String,
    vault_path: String,
) -> Result<bool, BridgeError> {
    let athlete_id = extract_athlete_id(&athlete_profile_json)?;
    let vault = gatc_ffi::VaultEngine::new(athlete_profile_json, vault_path)
        .map_err(|e| BridgeError::EngineConstructionFailed(format!("vault: {e}")))?;
    let state_json = vault.read_viterbi_state(athlete_id).map_err(BridgeError::from)?;
    // Engine returns JSON "null" if no state exists
    Ok(state_json != "null" && !state_json.is_empty())
}

/// Read the persisted ViterbiEngine state JSON directly from the vault.
/// Returns `None` if no state exists (first run), `Some(json)` otherwise.
/// Use this to get the state JSON to pass to `construct_engines_from_state()`.
pub fn read_persisted_state(
    athlete_profile_json: String,
    vault_path: String,
) -> Result<Option<String>, BridgeError> {
    let athlete_id = extract_athlete_id(&athlete_profile_json)?;
    let vault = gatc_ffi::VaultEngine::new(athlete_profile_json, vault_path)
        .map_err(|e| BridgeError::EngineConstructionFailed(format!("vault: {e}")))?;
    let state_json = vault.read_viterbi_state(athlete_id).map_err(BridgeError::from)?;
    if state_json == "null" || state_json.is_empty() {
        Ok(None)
    } else {
        Ok(Some(state_json))
    }
}

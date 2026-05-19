//! Day-3 API surface. Bridges flutter_rust_bridge ↔ gatc-ffi for a
//! real-data round trip. Every public function here delegates to an
//! existing `gatc_ffi::*` pub fn; no engine logic is added in this
//! crate. Returns are raw JSON strings (rendered as-is on the Dart
//! side) so no UniFFI record type ever crosses the FRB boundary —
//! Day-2 review WARNING 4.

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
    /// Day-7: ISO-8601 date string couldn't be parsed at the shim
    /// before reaching the engine. Distinct from `InputError` so the
    /// debug exerciser (and future writes) can surface a precise
    /// "your date is malformed" toast instead of the generic JSON
    /// schema rejection text.
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

/// Bundle of the three gatc-ffi engines Day 3 exercises. Opaque to
/// Dart by `#[frb(opaque)]`; Dart only holds an `Arc<EnginesHandle>`
/// proxy and hands it back to method calls.
#[frb(opaque)]
pub struct EnginesHandle {
    viterbi: Arc<gatc_ffi::ViterbiEngine>,
    advisor: Arc<gatc_ffi::AdvisorEngine>,
    vault: Arc<gatc_ffi::VaultEngine>,
    profile_json: String,
}

/// Day-2 smoke test — kept so the existing engine-hello status line
/// in main.dart stays green.
pub fn engine_hello() -> String {
    gatc_ffi::hello_uniffi()
}

/// Construct the three engines from the canonical seed JSON +
/// compiled tables + a writable vault path (created at first use).
pub fn construct_engines(
    athlete_profile_json: String,
    tables_json: String,
    vault_path: String,
) -> Result<EnginesHandle, BridgeError> {
    let viterbi = gatc_ffi::ViterbiEngine::new(athlete_profile_json.clone())
        .map_err(|e| BridgeError::EngineConstructionFailed(format!("viterbi: {e}")))?;
    let advisor = gatc_ffi::AdvisorEngine::new(athlete_profile_json.clone(), tables_json)
        .map_err(|e| BridgeError::EngineConstructionFailed(format!("advisor: {e}")))?;
    let vault = gatc_ffi::VaultEngine::new(athlete_profile_json.clone(), vault_path)
        .map_err(|e| BridgeError::EngineConstructionFailed(format!("vault: {e}")))?;
    Ok(EnginesHandle { viterbi, advisor, vault, profile_json: athlete_profile_json })
}

/// `ViterbiEngine::readiness_score()` — JSON `{"score":i32, "advisories":...}`.
pub fn readiness_score(handle: &EnginesHandle) -> Result<String, BridgeError> {
    handle.viterbi.readiness_score().map_err(Into::into)
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

/// `AdvisorEngine::suggest_workouts(...)`. SuggesterContext is composed
/// from (a) the engine-bound profile and (b) live `readiness_score` —
/// no per-call user input (no mood/equipment/terrain form in the
/// Day-3 UI), so those fields use defaults — see PR body.
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

/// Day-7: minimal biometric write for the hardware-verification debug
/// swatch exerciser. Composes a minimal VaultBiometric JSON with
/// `date`, `source`, and a placeholder `resting_hr` so the next
/// `last_observation_source_tier` call returns the matching tier and
/// the readiness screen's section (e) picks up the LOCKED swatch.
///
/// `iso_date` must parse as `YYYY-MM-DD`; on failure the shim emits
/// `BridgeError::InvalidDate` *before* touching the vault. The
/// physiological value is a placeholder — production writes will
/// carry real metrics.
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

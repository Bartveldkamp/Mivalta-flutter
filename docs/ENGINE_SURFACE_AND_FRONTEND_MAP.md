# Engine Surface ↔ Frontend Map

Status: living inventory, v1 (2026-06-15). Purpose: one clear picture of what
the Rust engine OFFERS, what the Flutter shim EXPOSES, what the UI CONSUMES, and
therefore what is left to build to make the product fully connected and
functional. Authoritative sources, verified this pass:

- Engine surface: `mivalta-rust-engine/engine_registry.json` **v2.24** — 16
  engines, **194 methods + 14 standalone functions** (~208 callable).
- Flutter shim: `rust/src/api.rs` — **65 `pub fn`** (one `gatc_ffi::*` call each,
  pure transport; verified zero compute).
- Facade: `lib/rust_engine.dart` — 67 methods (65 + 2 convenience wrappers).
- Consumption: the 8 screens in `lib/screens/` (audit 2026-06-15).

> The shim is intentionally a SUBSET: MVP scope is **MONITOR + ADVISOR**; COACH
> (multi-day plans, plan negotiation, open Josi chat) is post-MVP. Most
> "untapped" engine methods are deferred by design, not bugs. The list below
> separates *deferred-by-design* from *real MVP gaps*.

---

## A. Wired and live (engine → shim → screen)

| Area | Engine method(s) | Shim fn | Screen(s) |
|---|---|---|---|
| Readiness headline | `readiness_indicator` | `readiness_indicator` | Readiness, Detail |
| Readiness + advisories | `readiness_score`, `pending_advisories` | `readiness_score` | Readiness, Detail |
| Fatigue state | `get_readiness` | `viterbi_fatigue_state` | Readiness |
| Zone cap | `zone_cap_with_advisories` | `zone_cap_with_advisories` | Readiness |
| Dashboard widgets | `get_state/session/context_widget` | same | Readiness |
| Fitness trend | `fitness_series` | `fitness_series` | Journey |
| Advisor options | `recommend_workout_with_history` | same | Advisor |
| Post-workout report | `completed_workout_facts`, `build_post_workout_report` | same | Advisor |
| Workout detail | `get_workout_detail` | same | Workout detail |
| History / loads / readiness | `read_biometric_history`, `read_daily_loads`, `read_readiness_history`, `read_recent_activities` | same | Readiness, Detail, Journey, Explore |
| Power/CP/MMP/decoupling | `read_mmp_history`, `fit_cp_default`, `recent_decoupling_pct`, `read_metric_across_activities` | `read_mmp_history`, `fit_cp`, … | Detail, Journey |
| Post-activity pipeline | `process_activity`, `compute_time_in_zone` | same | (via ingest) |
| Manual entry | `process_observation` | `process_manual_observation` | Manual entry |
| Continuity | `save_state`, `from_persisted_state`, `read/write_viterbi_state` | same | all (bootstrap) |
| Learning toggle | `pause/resume/is_learning_paused` | same | Settings |
| Profile rebind | `update_profile` (×4 engines) | `update_profile` | Settings, Onboarding |
| Normalizer | `normalize_observation`, `classify_source`, `build_source_overview` | same | Settings, ingest |
| Data control | `export_encrypted_vault`, `export_biometrics_csv`, `clear_all_user_data`, `crypto_erase_cache` | same | Settings |
| Vault-first ingest | `write_raw_observation`, `mark_raw_observation_processed`, `read_raw_observations_by_*`, `read_activity_by_id` | same | ingest |

**Engine pin:** `rust/Cargo.toml` → `71b848b` (vault-first ingest). NOTE: the
Flutter `CLAUDE.md` "Engine pin" section still narrates `b603b5e` — stale; the
`rev=` line is authoritative. (Doc drift to fix.)

---

## B. Real MVP gaps (capability the engine HAS, the UI does NOT yet use)

1. **Optional NFOR inputs are not collected, so their emissions run silent.**
   Manual entry covers only RHR / HRV / sleep / RPE. The engine supports
   `set_mental_emission` (mood VAS), `set_chronotropic_emission`,
   `set_rpe_hr_drift_emission`, plus sick flag / cycle day / wellness / body
   temp via the observation. **Build:** extend manual entry + the observation
   wire; the M1/M2 leading-overtraining signals stay dark until then.
2. **Model-trust surface missing.** `validation_report` (DataSufficiency:
   "model not yet validated for you") and `personalization_diagnostics`
   (multi-scale learning progress) are not exposed in the shim. These are the
   honest "how well do I know you yet" story — strong fit for the learning ring
   / a "how MiValta is learning you" surface. **Build:** add shim fns + a UI.
3. **Recovery forecast unused.** `forecast_states` + `estimate_recovery` are not
   exposed. A "when will you be fresh again" read is a high-value calm feature.
   **Build:** shim fn + a small forecast surface.
4. **Workout WRITE path → confirm.** `write_activity` IS in the shim, but no
   screen was found calling it; if nothing writes a completed workout, the
   post-workout report / history-aware advisor read from an empty table. **Verify
   first** whether `health_ingest` or a workout-finish flow calls it; if not,
   this is the highest-impact functional gap (see `MAC_BRIEF_WORKOUT_INGEST.md`).
5. **Privacy/transparency depth.** `list_memories` / `forget_memory` (V4
   transparency, V3 granular revocation), `delete_by_source` / `delete_by_date_range`,
   and `import_encrypted_vault` (export is wired, import is not) are unexposed —
   Settings-tier features promised by the privacy story.
6. **Guardrails gating not surfaced.** `get_gating_policy` /
   `get_threshold_multiplier` run inside the engine; the UI shows no explicit
   "confidence-gated" state. Likely fine for MVP — confirm intent.

## C. Deferred by design (NOT gaps — COACH / post-MVP)

- **PlanEngine** (9) — `create_plan`, `advance_meso`, `audit_plan`, … : 0 exposed.
- **NarrativeEngine** (14) — plan overview, session detail, compliance, schedule.
- **ReplanEngine** (5) — `detect_scope`, `execute_replan`.
- **ChatEngine** (7) — `chat`, conversational Josi (PR-F).
- Vault plan/assessment/audit methods that back the above.

These are the COACH tier; leave unexposed until that phase.

---

## D. Hygiene (low priority)

- 8 dead facade methods (audit/precursor: `getDashboard`, `hasPersistedState`,
  `readActivityById`, `readRawObservationsBy*`, `cryptoEraseCache`,
  `readDefaultProfile`, `readViterbiState`) — superseded by other paths; prune
  or document.
- `observation_count()` exists on the FFI engine but is **not** in the shim
  (confirms why the no-data gate uses `readiness_indicator` confidence, the
  exposed + persisted signal).

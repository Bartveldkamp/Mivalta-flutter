# JOURNEY (2nd anchor) — spec, code-audited 2026-06-13

Built from a 3-agent source audit of mivalta-rust-engine (not from memory).
Every tier states what the CODE actually provides. Engine pin: b603b5e (v2.24).
Hard rule unchanged: engine decides, app displays; no raw enums user-visible;
verdict → reasons → data, stretched across time.

Cross-cutting truth: nearly all per-session depth is STARVED until workout
ingestion fills the vault. Journey ships honest-empty first.

## TIER 1 — buildable NOW, no engine change (reachable from the pinned shim)
- **Calibration arc** ("learning you — day X of ~28"): observation-day count
  via `readBiometricHistory` row count (display-only). [observation_days field
  = clean fix, flagged but not blocking.]
- **Load-vs-recovery divergence over weeks** — THE spine:
  `readDailyLoads` (per-day load series) + `readReadinessHistory` (state/score
  series) + `fitnessSeries` (Banister fitness/fatigue/form, a real SERIES,
  athlete-learned τ/k). Render the two-line shape, not ACWR. ✅ all three in
  shim+facade today.
- **Per-session detail card** from STORED `VaultActivity` (21 fields, audited):
  duration, distance, avg/max HR, `load_uls`, `post_workout_hrv`,
  `hr_recovery`, `hr_decoupling_pct`, `zone_compliance_pct`, `normalized_power`,
  `intensity_factor`, `variability_index`, `efficiency_factor`, `rpe`,
  `planned_zone`/`planned_ntiz`. Via `readRecentActivities`/`getWorkoutDetail`.
  ✅ stored data, not recompute.
- **Adaptation proof = Efficiency-Factor trend** (same output, fewer beats over
  weeks) via `readMetricAcrossActivities('efficiency_factor')`. Also HR-recovery
  trend (`hr_recovery` is a stored column). ✅ THE "is it working" answer, now.
- **Reported-RPE trend** + **decoupling % per session** (stored). ✅
- Today's monotony/strain as a QUIET flag from the context widget (point-in-time
  only — NOT a trend). ✅ value yes, trend no.

## TIER 2 — small engine additions (data EXISTS, needs exposure/persistence)
- **sRPE-vs-engine-EXPECTATION pattern**: engine computes `rpe_hr_drift_pct`
  but does NOT persist it per session (HMM-input only). Fix: store it on
  VaultActivity (one column). Then the *disagreement* (not just reported RPE)
  trends. Small, high-value.
- **Monotony/strain TREND series**: today point-in-time only
  (`get_monotony_strain`). Needs a per-day series API.
- **Fatigue-state history series**: `state_history` Vec EXISTS (42-day,
  persisted) but NO FFI export. Add `get_state_history(days)`. (Vault
  readiness-history already covers most of this need.)
- **Workout grade** (Excellent…Poor): computed in `workout_quality.rs`, but
  neither FFI-exposed nor stored. Expose + optionally persist.
- **Historical time-in-zone**: computed on-demand (`computeTimeInZone`), not
  stored; depends on raw-sample/FIT retention for past sessions.

## TIER 3 — real engine architecture (the moat; NOT possible today)
- **"What the engine learned" markers** ("your fatigue clears a day faster
  than when you started") AND **baseline-band narrowing adaptation proof**:
  BLOCKED. The engine stores ONLY current baselines — `PersonalBaseline`
  (HRV/RHR bands), `BanisterParameters` (τ₂ = clearance), `CeilingIntelligence`.
  There are NO timestamped historical snapshots. This is an ARCHITECTURE
  addition (persist weekly baseline snapshots), not an exposure gap. Single
  highest-value engine investment; unlocks both features at once.
- **Annotate-the-anomaly that IMPROVES predictions**: tags alcohol / work-stress
  / illness-type / nutrition do NOT exist as observation fields, and there's NO
  per-day annotation vault table (only activity-scoped `user_note`). Capture-
  only tagging could ship as honest INERT notes earlier; making tags feed the
  HMM = new input fields + new emissions = real engine work.

## Keep OFF Journey (design discipline, no code): GPS map as hero, social
## comparison, raw splits-as-default, achievements/streaks.

## Engine briefs this spec generates (for rust-engine, sequenced):
1. Persist `rpe_hr_drift_pct` on VaultActivity (Tier 2, smallest, high value).
2. `get_state_history(days)` FFI export (Tier 2).
3. Weekly baseline-snapshot persistence + read API (Tier 3, the moat).
4. Anomaly-tag inputs + emissions (Tier 3, only if validated worth it).

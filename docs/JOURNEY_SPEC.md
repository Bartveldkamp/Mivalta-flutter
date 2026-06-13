# JOURNEY (2nd anchor) — spec, code-audited 2026-06-13

## ★ LOCKED SCOPE (founder 2026-06-13) — THREE PILLARS, nothing more
Trimmed down. Annotate-the-anomaly (alcohol/stress/nutrition tags) is CUT —
too complex (new inputs + new emissions). Journey = exactly these three,
all Tier-1 buildable on stored data:
  1. **Load-vs-recovery divergence over weeks** (the spine):
     readDailyLoads + readReadinessHistory + fitnessSeries (Banister).
  2. **Per-session detail** from the stored 21-field VaultActivity
     (decoupling, EF, NP/IF/VI, zone-compliance, HR-recovery, RPE, planned-vs-actual).
  3. **Adaptation proof = Efficiency-Factor trend** (+ HR-recovery trend) via
     readMetricAcrossActivities — the "is it working" answer.
Plus the calibration arc ("learning you — day X") already decided.
DEFERRED (not beta): the baseline-evolution "what the engine learned" markers
(Tier 3 — needs engine to persist baseline-history; revisit post-beta).
DROPPED: anomaly tagging entirely.

---


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

---

## Journey = the PERSONALIZED DEPTH PAGE (founder 2026-06-13)

Journey is the user's own stats page — all training depth, **on demand, never
forced**. Its defining quality: **customizable**, with the AI feel present.
The user CHOOSES which overviews to show/hide (same configurable-tiles pattern
as Today, item 12, but a full library here). Calm by default; depth the user
opts into. Verdict→reasons→data still holds.

Candidate overviews the user can add/hide (AVAILABILITY = PENDING CODE AUDIT —
each will be marked EXISTS / NEEDS-EXPOSURE / NOT-STORED before any is built;
do NOT implement an overview until its row is confirmed EXISTS):
- Sleep overview (hours; STAGES if the engine stores them — to verify)
- HRV overview (series)
- Resting-HR overview (series)
- Steps overview
- Watts × heart-rate comparison (needs raw per-activity series — to verify)
- Heart-rate × km/time (pace trace — to verify)
- Workouts overview (list) + workout-TYPE breakdown
- Best results (power bests via MMP/CP; pace bests — to verify)
- Per day / week / month views
- Load overview — day / week / meso
- "The new models" (M1/M2/RPE-HR-drift/decoupling — likely internal-only, to verify)
- **Ask Josi to find a value / overview** — the cards+chips retrieval pattern
  (item 26): bounded "show me X" chips that surface an existing engine series,
  NOT free chat. Only over confirmed-EXISTS data.

This is the AI-feel surface: the user composes their own dashboard, and Josi
can fetch any of it on request — but every overview is real engine data,
nothing fabricated, and anything NOT-STORED is simply not offered (honest
absence), never faked.

---

## OVERVIEW AVAILABILITY MATRIX (code-audited 2026-06-13, pin b603b5e)

### ✅ BUILD NOW — EXISTS + reachable from the Flutter shim
- **HRV over time** — `read_biometric_history` (hrv_rmssd/sdnn), daily series.
- **Resting-HR over time** — `read_biometric_history` (resting_hr), daily series.
- **Sleep — HOURS + quality only** (NOT stages) — `read_biometric_history`
  (sleep_hours, sleep_quality). Stages are parsed by the health normalizer then
  DROPPED before vault — so hours/quality build now; stages are NOT-STORED.
- **Workouts list** — `read_recent_activities` / `read_activities_in_range`
  (full VaultActivity rows: HR, load, decoupling, EF, VI, NP, IF, zone-compliance…).
- **Workout-TYPE breakdown** — client-side grouping of the activity list by
  `activity_type` (counting/grouping = presentation; allowed). Build now.
- **Load — day / week / month / meso** — `daily_strain_series`, `acute_load`
  (7d), `chronic_load(weeks)`, `monthly_strain`, `load_summary(meso_days)` — all
  REAL APIs in the shim, not client math.
- **Fitness/fatigue/form trend** — `fitness_series` (Banister), series.
- **Per-session quality detail** — stored on VaultActivity (decoupling, EF, NP,
  IF, VI, zone-compliance, HR-recovery, post-workout HRV, plan-vs-actual).

### 🟡 NEEDS-EXPOSURE — computed but not reachable (small engine/shim brief)
- **Power bests (MMP) + Critical Power** — engine computes (`MmpEngine`,
  `CpEngine`) but there is **no MmpEngine binding in the Flutter shim** → add
  shim bindings (data exists, just unexposed to Dart).
- **"The new models" per-day values** (M1 chronotropic, M2 mental, RPE↔HR drift,
  decoupling emissions) — FFI exposes the CONFIG (get/set_*_emission), NOT the
  per-day z-score OUTPUT. Reading the daily contribution needs a new read API.
- **Watts × HR / HR × pace WITHIN-workout traces** — only `raw_fit_path` is
  stored; raw samples need client-side FIT parsing OR an engine sample-export.

### 🔴 NOT-STORED — real engine work (defer / decide)
- **Steps** — read by the health layer, accepted by the normalizer, but NEVER
  persisted to the vault. New VaultBiometric column to store it.
- **Sleep STAGES** (deep/REM/light/awake) — aggregated away in normalization;
  needs persistence (new column/table) to ever show a stage breakdown.
- **Running PACE best-efforts** — no velocity-curve engine exists (power-only).
  New engine work for a running-bests overview.

### Consequence for the personalized library
- The configurable overview catalogue ships with the ✅ set first (each a
  hide/show tile). 🟡 items light up as their shim/read briefs land. 🔴 items
  are simply NOT offered until the engine stores them — honest absence.
- "Ask Josi to find X" (chips retrieval) is wired ONLY to ✅ overviews initially.

### Engine/shim briefs this generates (sequenced, smallest first)
1. Add MmpEngine/CpEngine bindings to the Flutter shim (unlocks power bests — pure exposure).
2. FFI read for per-day M1/M2/decoupling/RPE-drift contributions (the "new models" overview).
3. Persist steps (one VaultBiometric column).
4. Persist sleep stages (column/table) — only if the stage breakdown is wanted.
5. Pace best-efforts engine (running bests) — larger; post-beta.

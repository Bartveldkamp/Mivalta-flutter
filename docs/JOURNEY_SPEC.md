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
  - **TIZ-from-vault (Option A — the activity-capture follow-up).** Verified
    2026-06-30: TIZ paints ONLY from a live device HR stream. The display reads
    it via `latestWorkoutTimeInZone()` → `_health.getHealthDataFromTypes(...)`
    (the live health plugin) → `computeTimeInZone`
    (`lib/services/health_ingest.dart:1162`,
    `lib/screens/readiness_detail_screen.dart:228`). `compute_time_in_zone` is
    **stateless** (`gatc-ffi/src/lib.rs:4194` — bins the series passed at call
    time, persists nothing) and the vault stores **no HR series**
    (`buildWorkoutActivityJson` writes scalars only; `get_workout_detail` returns
    `zone_compliance_pct`, not the per-zone dwell). **Consequence:** a vault-only
    workout (e.g. the DEBUG demo seed, PR #120) **cannot** paint TIZ — feeding
    `computeTimeInZone` at ingest would be dead compute nothing reads. **The fix
    (compute-once → store → display-reads-vault):** capture + persist the
    intra-workout HR series (or the computed TIZ distribution) at ingest, add a
    vault-backed accessor (fold TIZ into `get_workout_detail` or a new getter),
    and point the detail screen at the vault (keeping the live-plugin path as the
    on-device-real source). Cross-repo: rust-engine vault schema + FFI, then the
    Flutter display. This is the **P0/P2 activity-capture** work (P0 captures +
    persists the series; TIZ reads the vault) — TIZ-from-seed arrives for real
    with it. Until then, TIZ is witnessed via a real/injected workout, NOT the
    seed (Option B, founder 2026-06-30).

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

---

## ALSO PRESENTABLE — capabilities the engine has that weren't requested
(From the 2026-06-13 audits. Same honesty tags. Offer these in the library too.)

### ✅ Build now — reachable in the shim, real data
- **Readiness/recovery line over time** — `read_readiness_history` (the
  "recovery" half of the load-vs-recovery spine, as its own overview).
- **Confidence / "how sure am I" over time** — `viterbi_confidence` in
  `read_biometric_history`; visualizes the model earning trust.
- **The 4-axis breakdown** (fatigue model · fitness & freshness · body signals ·
  how you feel) — `readiness_indicator.contributions`; the same reasons Josi
  shows, as a standalone panel.
- **FORM / freshness** (race-readiness, TSB-like) — `fitness_series` returns
  fitness, fatigue AND **form**; you only named "load," but freshness is the
  taper/peak signal and it's free here.
- **Time-in-zone per workout** — `compute_time_in_zone` (R,Z1–Z8 dwell).
- **Plan vs actual adherence** — `planned_zone`/`planned_ntiz` on VaultActivity
  vs the actuals; "did I hit the session as prescribed."
- **Reactive alerts / pattern advisories** — context widget; engine-flagged
  "watch this" notes over time.
- **Data-source & quality overview** — `build_source_overview` (which device fed
  each signal + its tier); doubles as the privacy-insights surface (item 25).
- **Zone cap / max-safe-zone today** — `zone_cap_with_advisories`.
- **Critical Power + power-curve (stored)** — `fit_cp` + `read_power_profile` +
  `read_mmp_history` appear shim-reachable (CONFIRM: distinct from live MMP
  compute, which is not bound).

### 🟡 Needs-exposure — computed + FFI, but no shim binding (high "wow", small brief)
- **Forward fatigue FORECAST** — `forecast_states(days)`: "where your state is
  heading." The engine predicts; nobody asked, but it's a differentiator.
- **Recovery estimate** — `estimate_recovery`: "when you'll be fresh again."
- **Discrete fatigue-STATE history** — `state_history` (42-day, persisted) via a
  new `get_state_history`; the Recovered→IllnessRisk ribbon over time.
- **W′-balance trace + time-to-failure** — `WbalEngine`; per-session anaerobic
  depletion (cycling depth).
- **HMM posteriors** — `get_posteriors`: probability across the 5 states (a
  power-user / "nerd mode" panel).

### 🔴 Not-stored (as before): steps, sleep stages, pace bests, per-day new-model z-scores.

**Standouts you didn't ask for but should consider:** the **forecast** + **recovery
estimate** (the engine looks FORWARD, not just back) and **form/freshness** (peak
readiness) — all three are real engine outputs, only the first two need a shim
binding. These are the most "next-gen coach" surfaces available.

---

## SLEEP overview — DECISION (founder 2026-06-13): show the vendor's own
Sleep is **display passthrough of what the device/app already provides** (Oura,
Apple Health, Garmin…), NOT engine-derived. Verified path:
- `lib/services/health_ingest.dart` ALREADY reads full stages (deep/light/REM/
  awake) from Apple Health + Health Connect (lines ~277-295, ~657-694), then
  forwards to the Rust normalizer which aggregates to `sleep_hours` and drops
  the breakdown.
- **So:** the Sleep overview reads the vendor sleep (stages + durations + the
  in-sleep HR/HRV the source syncs) **directly from the platform health store
  for DISPLAY** — no engine change, no vault persistence needed for live view.
- The engine KEEPS using its aggregated `sleep_hours` for readiness (unchanged,
  HMM undisturbed). Two clean lanes: engine uses hours for the decision; Journey
  shows the vendor's rich view as-is.
- Architecture note: this is the ONE Journey overview sourced from the health
  store rather than the engine vault — label it honestly ("from Apple Health /
  Oura"), display-only, never a coaching input.
- HONEST LIMIT: only what the vendor SYNCS to the health store is readable. A
  proprietary score the app keeps internally (e.g. Oura's own Sleep Score
  number) may NOT be in HealthKit/Health Connect → show stages/durations/HR we
  can actually read; don't promise a vendor score that isn't exposed.
- Status: ✅ build-now (DISPLAY read), one Dart change — retain the stage data
  health_ingest already fetches instead of discarding it after the engine call.
  Persisting stages to MiValta's own vault (offline/after-revoke) stays 🔴/later.

---

## VAULT AS SINGLE SOURCE OF TRUTH — principle (founder 2026-06-13) vs wiring
Founder architecture: ALL data (devices, platforms, Oura) lands in the VAULT —
user ownership lives there; GATC/Viterbi work FROM the vault; the vault is
served via FFI to the frontend for display. CORRECT, and the engine/vault
IMPLEMENT it. But the live Flutter ingest does NOT yet wire it. Code-verified:

WHAT EXISTS (engine + vault — the design is right):
- `raw_observations` table (gatc-vault models.rs:316) with `vendor_json` =
  "the complete, unmodified vendor JSON payload as received from the device/API",
  plus `observation_json` (normalized) + `processed` flag, keyed by
  source/vendor/data_type, linkable to activity_id.
- FFI exposes it (gatc-ffi lib.rs:1397+): `write_raw_observation` (persist raw
  BEFORE processing), `mark_raw_observation_processed`,
  `read_raw_observations_by_type`, `read_raw_observations_by_activity`.

THE GAP (verified, honest):
1. The Flutter SHIM (`rust/src/api.rs`) does NOT bind any raw_observation
   method — grep returns none.
2. The ingest (`health_ingest.dart:386-409`) does: map→`normalizeObservation`
   →`processObservation`, then **DISCARDS `vendorJson`**. The raw payload is
   never persisted; only the reduced normalized biometric (sleep_hours, hrv,
   rhr) reaches the vault.
CONSEQUENCE: today the vault is NOT the complete record the principle intends —
Oura/device richness (sleep STAGES, steps, everything beyond the reduced fields)
passes through and is dropped. This also matters for the ownership/export promise
(privacy), not just Journey.

CORRECTION to the earlier "Sleep = health-store passthrough" note: that was a
side-channel and is SUPERSEDED. The right path is the founder's: persist the raw
vendor payload to the vault on ingest, then serve it out via FFI for display.
Sleep stages / steps / Oura richness are therefore NOT "engine can't" — they are
"ingest+shim wiring missing"; the storage already exists.

WIRING BRIEF (cross-repo, elevates the 🔴 items to 🟡 "wire it"):
1. Flutter shim: bind `write_raw_observation`, `mark_raw_observation_processed`,
   `read_raw_observations_by_type/_by_activity`.
2. `health_ingest.dart`: write_raw_observation(vendorJson) BEFORE normalize;
   mark_raw_observation_processed(normalizedJson) after — per the engine's
   documented 4-step flow (gatc-ffi lib.rs:1388). Manual entry: same.
3. Journey vendor-rich overviews (sleep stages, steps, full Oura view) READ from
   `read_raw_observations_by_type` — vault-sourced, FFI-served, honest.
4. This makes the vault the true complete record (ownership/export honored).

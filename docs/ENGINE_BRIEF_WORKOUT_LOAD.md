# ENGINE COMPANION BRIEF — workout load from raw HR samples

**For:** the `mivalta-rust-engine` session. **From:** the Flutter session.
**Status:** contract proposal (Quality Charter Law 8 — cross-repo via brief, not a quiet edit).
**Severity:** RED. Kills the Charter's canonical fabrication.

## Why (the defect)
Flutter's auto-ingest currently fabricates a workout's training load and feeds it
to the fatigue HMM. Verified, file:line:

- `Mivalta-flutter/lib/services/health_ingest.dart:598-605` — builds
  `{ "value": durationMinutes }` ("1 ULS per minute") and calls `record_activity`.
  A fabricated load → corrupts ACWR / monotony / strain / fitness. (Prime Directive.)
- `:559-567` — Dart computes avg/max HR from raw samples. Math in the edge. (Law 2.)
- `:540`, `:596` — TODOs admitting the placeholder.

## Why it can't be fixed in Flutter alone (verified)
- The `health` plugin v11.1.1 `WorkoutHealthValue` exposes only
  `workoutActivityType / totalEnergyBurned / totalDistance / totalSteps`
  (`health_value_types.dart:115-150`). **No native avg/max HR.** The only HR
  available is the raw per-sample stream.
- Engine load surface (registry v2.24 @ pin `71b848b`):
  - `ViterbiEngine.process_observation` computes Banister-TRIMP load **only when the
    observation carries a pre-aggregated `activity_avg_hr` + `activity_minutes`**
    (`gatc-viterbi/src/lib.rs:1644`; `load.rs:254-266`).
  - `ViterbiEngine.record_activity` just stores a caller-supplied value
    (`lib.rs:2360`).
  - `PostProcessEngine.process_activity` / `compute_time_in_zone` take raw samples
    but produce MMP/CP/W′bal/decoupling / zone dwell — **never a load**.
- ⇒ No FFI turns raw HR samples into a recorded load. A pre-aggregated avg HR can
  only be produced by averaging samples — which, per Law 2, the engine must do, not Dart.

## The ask (engine)
Add an FFI that owns the whole computation. Proposed shape (engine session decides
the exact name/home — ViterbiEngine or PostProcess):

`record_activity_from_samples(activity_wire_json: String) -> String  // LoadScore JSON, or null`

Input wire = the format Flutter already builds for time-in-zone
(`health_ingest.dart:898-920 buildHrActivityJson`):
`{ "completed_at", "hr_samples":[..], "hr_timestamps":[..], "power_samples":[..], "sample_rate_hz" }`

Behaviour:
1. Average HR from `hr_samples` (engine-side, deterministic), and max.
2. Run `UniversalLoadCalculator` against the **bound profile** (`resting_hr`,
   `max_hr`, `sex`, `hr_threshold`): Exponential TRIMP when HR + RHR + maxHR present
   (Banister 1991), else the existing cited cascade (Quadratic HR / RPE / Calories).
   Every branch is a REAL computation — **no DurationOnly placeholder masquerading
   as measured**; if only duration exists, prefer honest absence (see 4).
3. Record the load (`record_activity` / `push_training_load`).
4. **Honest absence:** if `hr_samples` < 2 (or window ≤ 0) AND no calories/RPE →
   return JSON `null` (or a loud error). NEVER a duration stand-in. Caller renders
   honest absence.
5. Return the real `LoadScore` (`value, method, confidence, intensity, avg_hr,
   max_hr`) so the activity row can carry the REAL `load_uls` + avg/max HR.

Also: ensure `VaultActivity.load_uls` + `avg_heart_rate` + `max_heart_rate` get the
real engine values (engine-filled on write, or via the returned score).

Required: `engine_registry.json` bump; a unit test with a concrete numeric
assertion citing Banister 1991 (e.g. known HR/RHR/maxHR/duration → expected TRIMP).

## Flutter pairing (this repo — PAUSED until the FFI exists at a new pin)
1. Delete `health_ingest.dart:559-567` (HR averaging) and `:598-605` (fabricated load
   + direct `record_activity`).
2. `_ingestWorkout`: fetch the workout's raw HR samples in-window (as
   `latestWorkoutTimeInZone:953-1003` already does), build the wire via
   `buildHrActivityJson`, call the new FFI.
3. Write `VaultActivity` with the engine-returned real `load_uls` / avg / max HR — or
   rely on the engine write. No Dart-computed fields.
4. Too few samples → honest absence (no load recorded), never a guess.
5. Widget/unit test with a concrete assertion; re-pin `rust/Cargo.toml` to the rev
   that ships the FFI and note it.

## Definition of done (this fix)
- [ ] No averaging or load math anywhere in Dart (Law 2).
- [ ] Engine computes load from raw samples; Banister cited + tested (Law 7).
- [ ] Missing HR → honest absence, never a duration stand-in (Prime Directive, Law 3).
- [ ] `load_uls` / avg / max HR on the vault row are real engine values (Law 1).
- [ ] Red-flag grep clean in `_ingestWorkout`; both TODOs resolved (Law 4).

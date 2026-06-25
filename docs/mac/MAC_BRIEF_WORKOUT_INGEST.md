# Mac Brief — Workout ingestion: the missing trunk wire

**Executor:** Mac Claude Code (Alta). **Scope:** this repo (shim + facade +
ingest service + test). **FFI scope discipline:** this brief IS the surfaced
proposal — it adds shim bindings (`write_activity`, `process_activity`); review
the diff against this brief.
**Origin:** the 2026-06-11 bidirectional wiring audit. The OUTPUT direction is
fully wired; the INGEST direction is wired for daily biometrics but **no
completed workout is ever written to the vault** (`write_activity` absent from
`rust/src/api.rs`; zero production `VaultActivity` writers). Deferred in
`health_ingest.dart:83` ("exerciseType impedance mismatch") — correctly
sequenced then, now the #1 gap.

## Why this is the highest-leverage wire in the app

The workout *display* side is already fully wired and reads from a vault table
nothing fills. This single missing wire currently starves FIVE wired features:
1. **Post-workout report** (`advisor_screen.dart` chain: `readRecentActivities`
   → `completedWorkoutFacts` → `buildPostWorkoutReport`) — never fires.
2. **Advisor energy-system rotation** (`recommend_workout_with_history` reads
   vault history in the shim) — permanently cold-start; never rotates.
3. **Power analytics** (MMP curve, CP/W′, charts on Explore) — empty.
4. **Aerobic-decoupling pipeline** → the decoupling HMM emission — silent.
5. **RPE-first feedback** (founder-core advisor behavior) — no workout RPE ever
   reaches the engine.

## Tasks

1. **Shim bindings (FFI boundary — per this brief):** add pure-transport fns for
   `gatc_ffi` `VaultEngine::write_activity(activity_json)` and
   `PostProcessEngine::process_activity(activity_json)` (and persist whatever
   process_activity's producer outputs need persisting per the FFI contract —
   read `docs/frontend/FFI_API_CONTRACT.md` Recipe 4 "Activity completion" in
   the rust-engine repo and follow it exactly; the engine repo is the source of
   truth for the call order). One `gatc_ffi::*` call per fn, raw JSON, no logic.
   FRB regen (`flutter_rust_bridge_codegen`) + facade methods.
2. **Resolve the exerciseType impedance mismatch** (the original deferral
   reason): the Flutter `health` plugin exposes its own workout-type enum; map
   it in the *ingest service* (display-side mapping table, not physiology) to
   the activity JSON the engine accepts (`VaultActivity.activity_type` strings —
   verify accepted values against the engine's normalizer/contract; do NOT
   invent). If a plugin type has no clean mapping, pass it as-is and let the
   engine's fail-loud validation decide — never silently drop a workout.
3. **Wire the flow in `health_ingest.dart`:** on sync, for each WORKOUT session
   not yet ingested: build the activity JSON (the `buildHrActivityJson` HR-window
   plumbing already exists for time-in-zone) → `write_activity` →
   `process_activity` → persist per Recipe 4 → then the existing observation
   flow (so derived signals like `aerobic_decoupling_pct` ride the next
   observation). Idempotency: don't re-write the same session on every sync
   (key by start-time/id).
4. **Workout RPE capture (founder-core):** after a workout is ingested, the
   athlete can attach an RPE (1–10) — simplest honest surface: a prompt/row on
   the advisor or readiness-detail screen for the latest unrated activity,
   writing RPE into the activity (per the FFI contract's note/update path —
   check what the contract provides; if the engine has no post-hoc RPE update
   method, STOP and surface that as an engine gap rather than hacking it
   client-side).
5. **Tests (rule 8):** ingest-service unit test (plugin workout → activity JSON
   mapping, idempotency), and a round-trip test: write_activity →
   readRecentActivities returns it → completedWorkoutFacts non-null.

## Definition of done

- A Health Connect workout lands in the vault, post-processes, and the
  post-workout report renders on next advisor open.
- The advisor's options change after ingesting hard workouts on consecutive
  days (rotation alive — the spacing gate has history to read).
- `flutter analyze --fatal-infos` + `flutter test` green; `cargo check` clean in
  `rust/`.
- No engine logic in Dart: the type-mapping table is transport, every number
  comes from the engine.
- Branch `mac/workout-ingest`; one PR; no merge without green CI.

## Out of scope

Vendor OAuth (Garmin/Polar/… direct APIs), BLE live streams, the dead-input
manual-entry fields (mental VAS / sick / cycle_day — separate small brief),
iOS bring-up specifics beyond keeping the mapping platform-aware.

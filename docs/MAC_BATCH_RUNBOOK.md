# Mac-Executor Batch — bring Flutter onto the validated engine

Web Claude built and validated the engine but cannot run the Flutter / Android
/ FRB toolchain (no `flutter`, `dart`, `cargo-ndk`, or `flutter_rust_bridge_codegen`
in the cloud container; the `gatc-ffi` git deps are ssh-pinned). These steps
run on Bart's Mac (Alta). Each step is independently verifiable; do them in
order.

## Why now

Engine `main` (rust-engine, post-PR #246) carries, on top of the v2.24 pin the
app currently uses:
- the unified advisor→GATC system selector (the Z2-forever fix) + B5
  calibration probes + the `expression` option field;
- the Viterbi safety chain (multi-scale suppression floor, acute HRV crash
  gate, sustained-FOR freeze, recovery release) — matrix 1152/1152 PASS.

All of it is FFI-**additive** (new JSON fields on existing payloads, no bound
method signature changed), EXCEPT the Dart facade does not yet expose
`recommend_workout_with_history` — that needs an FRB regen + a facade method.

## Step 1 — Re-pin the engine

In `rust/Cargo.toml`, both deps:

```toml
gatc-ffi    = { git = "ssh://git@github.com/Bartveldkamp/mivalta-rust-engine", rev = "<POST_#246_MAIN_SHA>" }
gatc-viterbi = { git = "ssh://git@github.com/Bartveldkamp/mivalta-rust-engine", rev = "<POST_#246_MAIN_SHA>" }
```

(Use the squash-merge commit SHA of #246 on rust-engine `main`.)

```bash
cd rust && cargo update -p gatc-ffi -p gatc-viterbi && cd ..
```

Verify: `git diff Cargo.lock` shows only the rev-SHA replacement.

## Step 2 — Regenerate FRB bindings

```bash
flutter_rust_bridge_codegen generate     # reads rust/src/api.rs → lib/src/rust/*
```

Verify: `grep recommendWorkoutWithHistory lib/src/rust/api.dart` now matches
(the shim fn at `rust/src/api.rs:498` surfaces). The generated files are
do-not-edit; commit them as-is.

## Step 3 — Facade method (lib/rust_engine.dart)

⚠️ Boundary change — this file is load-bearing (Flutter CLAUDE.md scope rule).
Add ONE method mirroring the existing `recommendWorkout`, plus the history
payload the shim already accepts (the `recent_activities_json` string the
engine parses into its window):

```dart
/// `AdvisorEngine::recommend_workout_with_history(...)` — the Phase-2 tail.
/// Identical to [recommendWorkout] plus the recent-activity JSON the engine
/// turns into the selector's history window (recency, dose progression,
/// calibration-gate count). Pure transport.
Future<String> recommendWorkoutWithHistory(
  EnginesHandle handle, {
  String? mood,
  String? equipment,
  String? terrain,
  required String recentActivitiesJson,
}) =>
    rust_api.recommendWorkoutWithHistory(
      handle: handle,
      mood: mood,
      equipment: equipment,
      terrain: terrain,
      recentActivitiesJson: recentActivitiesJson,
    );
```

(Match the exact generated parameter names from Step 2 — FRB may camel-case
`recent_activities_json` differently; read the generated signature.)

## Step 4 — Wire the readiness/advisor screen to the history path

The home/advisor screen currently calls `recommendWorkout` (no history → the
engine runs its no-history baseline, calibration ineligible). Switch it to
`recommendWorkoutWithHistory`, sourcing the recent activities the same way the
continuity path already reads the vault:

- read recent completed activities from the vault (the `VaultActivity` list —
  the same rows `readReadinessHistory` / continuity already touch);
- `jsonEncode` them into `recentActivitiesJson`;
- pass through. No thresholds or math in Dart (architecture rule 3) — the
  string is opaque transport.

This is what makes the unified brain actually drive the app: system rotation,
dose progression, and the B5 calibration sequence only engage on the history
path.

## Step 4b — Two FFI-coverage gaps found in the 2026-06-10 audit

A full `gatc-ffi → shim → facade` diff (Web Claude, 2026-06-10) found the
shim↔facade layer essentially complete (49/50 functions wired) EXCEPT the
history method in Step 3 — plus two engine capabilities that exist in
`gatc-ffi` but the shim never exposes, so they are **dark on the phone today**.
These need a SHIM addition first (the shim has no binding for them), then the
FRB regen in Step 2 surfaces them, then a facade method. Both are in MVP scope.

### 4b-i — Activate the HMM emission signals (HIGH — built but dormant)

`construct_engines*` calls `ViterbiEngine::new(...)` and nothing else, so the
four advanced emission signals you built are never switched on in the app:
`set_decoupling_emission`, `set_mental_emission` (M2), `set_chronotropic_emission`
(M1), `set_rpe_hr_drift_emission`. Until these are called, the phone runs the
basic HRV/RHR/sleep HMM only — the mental-disturbance, chronotropic, RPE↔HR
drift, and decoupling axes contribute nothing.

Fix: in `rust/src/api.rs`, right after `ViterbiEngine::new` in BOTH
`construct_engines_fresh` and `construct_engines_from_state`, call the four
`set_*_emission` methods with the card-driven configs (the engine exposes the
DRAFT defaults; pass them straight through — no Dart-side config). This is
still pure transport: the shim turns the signals on, it computes nothing.
No new facade method needed (it happens at construction). Verify with
`viterbi.personalization_diagnostics()` showing the emission metrics populated
after a few observations.

### 4b-ii — Privacy "pause learning" control (MEDIUM — spec'd, unwired)

`pause_learning` / `resume_learning` / `is_learning_paused` (V4 global privacy
setting, MIVALTA_FINAL_SPEC) have no shim binding and no facade method, so the
Settings screen has nothing to call. Add three one-line shim fns + three facade
methods (mirror the `save_state` pattern), then wire the Settings toggle.

## Step 5 — Build + smoke test

```bash
flutter pub get
flutter analyze                                   # zero issues
flutter test                                      # green (add a round-trip
                                                  # widget test for the new path)
flutter build apk --debug --target-platform android-arm64
```

Smoke on a device: a fresh profile shows the calibration framing
("Calibration 1 of 5 …") for the first sessions; after ~5 logged workouts the
selector takes over and the offered zones rotate (not Z2 every day); a stated
hilly terrain surfaces the `expression` field ("Climb Repeats"); and
`personalization_diagnostics` shows the M1/M2/decoupling/RPE-drift emission
metrics populated (Step 4b-i) rather than absent.

## Step 6 — Commit + (optionally) PR

```
feat(flutter): re-pin engine post-#246 + recommend_workout_with_history facade & wiring
```

Update `CLAUDE.md`'s "Engine pin" block to the new SHA + registry note.

---

### What stays Web Claude's vs Mac's
- Web Claude: all engine logic, cards, validation, the SHA to pin.
- Mac: FRB codegen, the `.so`/APK build, on-device smoke, release signing —
  none of which the cloud container can do.

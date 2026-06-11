# Mac-Executor Batch — bring Flutter onto the validated engine

> **Line-up checklist (verified 2026-06-11 against rust-engine `b603b5e` +
> Flutter `main` `2f41d95`).** The shipped app pins an OLD engine (`90dd3a4`)
> and runs a thinner slice than what's validated on rust `main`:
>
> - [ ] **1. Re-pin** `rust/Cargo.toml` `90dd3a4` -> **`b603b5e`** (both deps) — §1
> - [ ] **2. FRB codegen regen** — §2 (surfaces the new shim methods)
> - [ ] **3. `recommendWorkoutWithHistory` facade + screen wiring** — §3/§4
>       (unlocks system rotation, dose progression, B5 calibration, `expression`)
> - [ ] **4. Arm the 3 card-backed emissions** — §4b-i: ONE call,
>       `enable_card_emissions(tables)` after each construct (validated ON
>       2026-06-11: matrix 1152/1152 + sim PASS; rust PR #250)
> - [ ] **5. `pauseLearning` facade** (V4 privacy) — §4b-ii
> - [ ] **6. Render new payload fields** — `expression`, calibration framing in `why`
> - [ ] **7. Build `.so`/APK + smoke** — §5
>
> Items 1–2 + the build are Mac-only (no toolchain in the cloud container);
> 3–6 are Dart/shim edits spelled out below.

Web Claude built and validated the engine but cannot run the Flutter / Android
/ FRB toolchain (no `flutter`, `dart`, `cargo-ndk`, or `flutter_rust_bridge_codegen`
in the cloud container; the `gatc-ffi` git deps are ssh-pinned). These steps
run on Bart's Mac (Alta). Each step is independently verifiable; do them in
order.

## Why now

Engine `main` (rust-engine `b603b5e`, post-PR #245–#248) carries, on top of the
older `90dd3a4` pin the app currently uses:
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
gatc-ffi    = { git = "ssh://git@github.com/Bartveldkamp/mivalta-rust-engine", rev = "b603b5e" }
gatc-viterbi = { git = "ssh://git@github.com/Bartveldkamp/mivalta-rust-engine", rev = "b603b5e" }
```

(`b603b5e` = rust-engine `main` after #245–#248: unification + B5 + expression
+ the Viterbi safety chain + APIM-B fatigue typing + risk-factors. Verified the
current app pin is the older `90dd3a4`, which predates all of it.)

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

### 4b-i — HMM emission signals — ✅ UNBLOCKED 2026-06-11: ONE call, validated

**History:** this step was briefly blocked (2026-06-11 AM) because the
emissions were `enabled:false` everywhere and no harness had ever validated
them ON. That engine-side work is now DONE and merged (rust-engine PR #250,
`b603b5e`): both harnesses feed coherent `aerobic_decoupling_pct` /
`chronotropic_suppression_pct` signals and run with the emissions ARMED —
**matrix 1152/1152 PASS, double-blind sim PASS (safety 12/12, responsive 89 %,
no regression)**. The validated configuration now INCLUDES the three
card-backed emissions.

**What Mac does (replaces the old four-setter instruction):** in
`rust/src/api.rs`, in BOTH `construct_engines_fresh` and
`construct_engines_from_state`, right after `ViterbiEngine::new(...)`, add
exactly one call:

```rust
viterbi.enable_card_emissions(compiled_tables_json.clone())?;
```

That single engine-side method resolves the emission cards and arms
decoupling + mental (M2) + chronotropic (M1) with the card-faithful configs —
the same call both validation harnesses use, so the phone runs the exact
validated configuration. Notes:

- `rpe_hr_drift` is intentionally NOT armed: it has no card SoT yet
  (rust NEXT_WORK P1.0). The method skips it; nothing to do client-side.
- Idempotent; an absent/incomplete card leaves that emission off (fail-safe).
- Still pure transport: the shim adds one pass-through call, computes nothing.
- Requires the Step-1 re-pin (the method exists from rust-engine `b603b5e`).
- Smoke check: after a few observations with decoupling/mental inputs,
  `personalization_diagnostics()` shows the emission metrics populated.

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
hilly terrain surfaces the `expression` field ("Climb Repeats"). (The
decoupling/mental/chronotropic emission metrics are **populated** once their
inputs flow — §4b-i smoke check; RPE↔HR drift stays absent (no card yet, P1.0).)

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

# Mac Brief — Privacy "Pause learning" toggle (+ shim hygiene)

**Executor:** Mac Claude Code (Alta). **Scope:** this repo only.
**Origin:** founder-approved beta-gap #1 (2026-06-11) — the engine's learning-pause
privacy controls are fully bound through the FRB facade but have **no UI**. This is
a spec-level privacy promise (pause the model adapting) with no surface.

## Task 1 — Privacy section in Settings

`lib/screens/settings_screen.dart` has four `_SectionCard` sections (Profile,
Data Sources, Export My Data, Delete Everything). Add a **Privacy** section
between Export and Delete:

1. **Toggle: "Pause learning".** Wire to the existing facade methods (already
   bound, verified):
   - `RustEngine.isLearningPaused(handle)` → initial toggle state (read at
     section build; handle the engine-not-ready case the same way the other
     sections do).
   - On switch ON → `pauseLearning(handle)`; on switch OFF → `resumeLearning(handle)`.
   - **Persistence:** after every toggle, persist engine state the same way the
     rest of the app does on state-changing operations (`saveState` +
     `writeViterbiState`) so the pause survives an app restart. Then verify on
     a fresh `constructEnginesFromState()` that `isLearningPaused` returns the
     persisted value — if it does NOT survive the engine save/restore
     round-trip, STOP and report (that would be an engine seam, not a UI bug;
     do not work around it in Dart).
2. **Explanation copy under the toggle** (display-only, no thresholds):
   "Readiness scores still update, but the engine stops refining its model of
   you." (This matches the engine-docs banner language; put the string in
   `lib/copy/` per the locked-copy pattern if other settings copy lives there,
   else inline like the section's siblings.)
3. **Persistent banner while paused:** when `isLearningPaused == true`, the
   ReadinessScreen shows a calm, non-blocking banner ("Learning paused").
   Match the existing banner/notice idiom on that screen — calm presence, not
   an alarm; no modal.
4. **Test (rule 8):** widget test asserting (a) the toggle reflects
   `isLearningPaused`, (b) toggling calls pause/resume + persists, (c) the
   banner renders iff paused. Concrete-value assertions.

## Task 2 — Shim hygiene (surfaced + founder-approved FFI touch)

`rust/src/api.rs:529` still carries `#[allow(dead_code)]` + a "until FRB regen"
comment on `recommend_workout_with_history`. The regen has happened and
`advisor_screen.dart` is the live caller via the generated bindings. Remove the
attribute + stale comment, run `cargo check` in `rust/` (real ssh pin resolves on
Mac), and confirm zero warnings. **No signature change, no behaviour change** —
if removing the attribute produces a dead-code warning, the call chain is not
what we think: stop and report instead of re-adding the allow.

## Definition of done

- `flutter analyze --fatal-infos` clean (CI runs this — local `flutter test`
  green is NOT sufficient).
- `flutter test` green incl. the new widget test.
- `cargo check` clean in `rust/` after the attribute removal.
- Pause state survives app restart (manual check on device/emulator if attached).
- One PR, branch `mac/privacy-toggle`, descriptive commit; do not merge without
  green CI.

## Out of scope

Vendor OAuth/BLE transports, advisory ledger (blocked on rust Phase 1),
time-in-zone promotion, any other shim/facade change. One section, one toggle,
one banner, one hygiene fix.

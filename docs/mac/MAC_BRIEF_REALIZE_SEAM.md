# MAC BRIEF — wire the realize-advisor-line seam (Item 2, the Mac round-trip)

**Branch:** `claude/wire-realize-advisor-seam` (cloud-authored, held).
**Your job (Mac only):** the toolchain steps the cloud session cannot run —
`cargo update`, FRB codegen, iOS xcframework, and the execution-verification
(`flutter analyze` / `flutter test`). The cloud session already authored the
re-pin, the shim, the model, the facade, the presenter wiring, the home caller,
and the tests. **Do not redesign or add features** — execute and report (repo
Rule 1).

> ⚠️ **CI on this branch is RED until you regen.** This PR adds a new FFI method
> (`realizeAdvisorLine`). The generated `lib/src/rust/*` bindings do **not** yet
> contain it, so `flutter analyze` fails on `rust_api.realizeAdvisorLine` and the
> frb-drift-guard fails until you run codegen and commit the result. That is the
> drift-guard working as designed, not a defect.

## What the cloud already authored (verify, don't redo)
- `rust/Cargo.toml` — `gatc-ffi` + `gatc-viterbi` re-pinned `8b3b95a → b7264cb`
  (engine `main` after #367; `realize_advisor_line` confirmed at
  `gatc-ffi/src/lib.rs:4344`).
- `rust/src/api.rs` — `EnginesHandle` gains `narrative: Arc<NarrativeEngine>`,
  constructed in BOTH `construct_engines_fresh` and `construct_engines_from_state`
  with the SAME `vault_path` as `vault` (one vault of record). New pass-through
  `realize_advisor_line(handle, date)` → raw `RealizedLine` JSON.
- `lib/models/realized_line.dart` — parse model `{text, safety[], degraded}`.
- `lib/rust_engine.dart` — facade `realizeAdvisorLine(handle, date:)`.
- `lib/widgets/josi_presenter.dart` — optional `RealizedLine`; `text` → headline,
  `safety` rendered verbatim + always (never branched on). Extended, not replaced.
- `lib/screens/readiness_screen.dart` — home calls the seam with today's date
  (Flutter supplies the clock), parses, passes to `JosiPresenter`; fail-loud from
  the engine is caught as honest absence (falls back to the state line).
- Tests: `test/realized_line_test.dart` (parse) + new group in
  `test/josi_presenter_test.dart` (text headline + safety verbatim + no-data wins).

## Steps (in order)
1. `git fetch && git checkout claude/wire-realize-advisor-seam`
2. `cd rust && cargo update -p gatc-ffi -p gatc-viterbi`
   - The lock should move to `b7264cb`. **This is a LARGE bump** (carries #358
     ChatEngine removal, #359 trend layer, #363–365 voice pipeline, #367). If
     `cargo build` surfaces a shim mismatch from an intervening FFI change,
     **stop and report the exact error** — the cloud session will author the
     reconciliation (do not patch it yourself).
3. **FRB codegen:** `flutter_rust_bridge_codegen generate` (or the repo's wrapper
   script). Confirm the generated `lib/src/rust/api.dart` now exposes
   `realizeAdvisorLine`. **Commit the regenerated `lib/src/rust/*`** in sync.
4. **iOS xcframework rebuild** (`scripts/build_ios.sh` or the documented path) so
   the iOS app links the new symbol. Android is proven by the `smoke` CI job.
5. **Verify by execution** (report the actual output, not "green"):
   - `flutter analyze`
   - `flutter test`
   - confirm `frb-drift-guard` is satisfied (regen committed in sync).
6. Build to a device/simulator (`flutter run`) far enough to confirm it launches.

## What this brief does NOT do
- **No witness.** Wiring + build only. The device witness — open the app against
  the real seeded athlete (#115) and confirm `readinessIndicator`,
  `viterbiFatigueState`, the session widget, and the RealizedLine (text + safety)
  render real data — is **Bart's**, not the Mac session's and not the cloud's.
- No designed ADVISOR surface (Claude Design's chapter). Minimal display only.
- No engine changes — the seam is merged and frozen at `b7264cb`.

## Report back
The build reaches a runnable app on a device, with `flutter analyze`/`flutter
test` green and drift-guard satisfied — explicitly: **wired and build-proven,
awaiting Bart's device witness, NOT witnessed.** Hold the PR for Bart's merge.

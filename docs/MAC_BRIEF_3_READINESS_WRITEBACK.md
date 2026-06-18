# Mac-Executor Brief — #3 readiness write-back (engine pin bump + wiring)

> **Two phases, deliberately split** (founder decision 2026-06-18). Phase 1 is
> the engine pin bump ALONE — no Dart/shim edits — so the engine-behaviour swap
> is verified in isolation before any wiring lands on top of it. Phase 2 (the
> `write_assessment` shim + facade + call-site) lands as a follow-up commit only
> AFTER Phase 1 is confirmed clean on the simulator.
>
> Items needing the Mac (no toolchain in the cloud container; `gatc-ffi` git
> deps are ssh-pinned, `flutter_rust_bridge_codegen` + iOS build are macOS-only):
>
> **Phase 1 (this commit — pin bump):**
> - [ ] **1. Refresh `Cargo.lock`** to the new rev — §1.1
> - [ ] **2. Rebuild the `.so`/xcframework** (NO FRB regen — surface unchanged) — §1.2
> - [ ] **3. `flutter pub get && flutter analyze && flutter test`** — §1.3
> - [ ] **4. On-sim sanity + single-writer proof** — §1.4
> - [ ] **5. Report clean → unblocks Phase 2**
>
> **Phase 2 (follow-up commit — wiring; spelled out in §2 for the contract):**
> - [ ] **6. FRB codegen regen** (surfaces the new `write_assessment` shim fn)
> - [ ] **7. Build `.so` + `flutter test` (incl. the new write-back test) + on-sim**

Web/coding Claude authored the pin bump (`rust/Cargo.toml`) and this brief but
cannot run the Flutter/cargo-ssh/FRB toolchain in the cloud container. These
steps run on Bart's Mac (Alta). Do them in order; each is independently
verifiable.

## Why now — the #3 single-writer precondition

`readiness_indicator()` is the home headline (the 4-axis blend). The Journey
charts read it back from the `biometrics` table's readiness columns
(`readiness_score`/`readiness_level`/`fatigue_state`/`viterbi_confidence`) via
`read_readiness_history` (filtered `WHERE readiness_score IS NOT NULL` — the
honest-absence boundary). For the Flutter call-site to write that headline back
per day, ONE writer must own those columns. Before #298 BOTH `write_biometric`
**and** `write_assessment` wrote them, so a write-back would race/clobber the
biometric write. **#298 (`44b0566`) makes `write_assessment` the single writer**
— `write_biometric` no longer touches the readiness columns. That is the
precondition this bump delivers.

Verified against rust-engine code this session:
- Pin was `79b7c93`; `write_biometric` there writes the readiness columns
  (`crates/gatc-vault/src/sync.rs:495–515` at that rev).
- `#298` (`44b0566`) is **33 commits ahead** of `79b7c93` — NOT in the old pin.
- `engine_registry.json` is **byte-identical** across `79b7c93..2d51fea`
  (v2.24, zero method delta) → **no FFI surface change, no FRB regen for the
  bump itself.**

## Step 1 — Phase 1: the engine pin bump (this commit)

`rust/Cargo.toml` is already edited: both `gatc-ffi` and `gatc-viterbi` now pin
`rev = "2d51fea"` (was `79b7c93`). Full SHA:
`2d51fea0abdd7947bf4b44bed5c264b3e81ed08f`.

The range `79b7c93..2d51fea` is behaviour/test/docs only:
- **#298** `feat(rust): #3 readiness write-back — single-writer` (the reason).
- **#291** `#4a` re-ingest-reproducible normalizer timestamps (behaviour-only,
  gatc-normalizer).
- **#295** `#4b` gated fail-safe load dedup in `record_activity` (behaviour-only,
  gatc-viterbi).
- The rest: `WIRING_COVERAGE_MAP` + a batch of FFI seam tests + docs (no runtime).

### 1.1 — Refresh `Cargo.lock`
The cloud container can't reach the ssh-pinned private repo, so `Cargo.lock`
still references `79b7c93`. On the Mac:
```bash
cd rust
cargo update -p gatc-ffi -p gatc-viterbi   # or: cargo build (auto-refreshes lock)
```
Expect the three `git+ssh://…?rev=79b7c93#…` source lines for every `gatc-*`
member to flip to `?rev=2d51fea#2d51fea0abdd7947bf4b44bed5c264b3e81ed08f`.
Commit the refreshed `Cargo.lock`.

### 1.2 — Rebuild the artifact (NO FRB regen)
The FFI surface is unchanged, so **do not** run `flutter_rust_bridge_codegen`
here. Just rebuild the native lib via the normal path:
```bash
scripts/build_ios.sh          # or the Android .so build, per target
```
`frb-drift-guard` must stay green: the shim (`rust/src/api.rs`) and the
generated `lib/src/rust/` are untouched in Phase 1, so there is no drift.

### 1.3 — Flutter gate
```bash
flutter pub get
flutter analyze      # expect: no issues
flutter test         # expect: all green (no new tests in Phase 1)
```

### 1.4 — On-sim sanity + single-writer proof
- Launch on the simulator; confirm the readiness home renders as before (the
  bump is behaviour-only — the headline should be stable, NOT changed by Phase 1).
- **Single-writer proof (the point of the bump):** sync a day with biometrics,
  then confirm that day's `biometrics` readiness columns are written by the
  assessment path only — i.e. a subsequent `write_biometric` for the same date
  does NOT null/overwrite the readiness columns. (Until Phase 2 wires the
  write-back, the readiness columns may simply be absent for synced days — that
  is honest-absence, not a regression.)
- `#4a`/`#4b` sanity: re-running a sync of the same days does not double-count
  load (dedup) and produces identical normalizer timestamps (reproducible).

### 1.5 — Report
Report Phase 1 clean (lock refreshed, build green, analyze/test green, sim OK).
**That unblocks Phase 2.**

## Step 2 — Phase 2: the wiring (follow-up commit — CONTRACT, not yet written)

Authored by the coding seat after Phase 1 confirms clean. Recorded here so the
contract is fixed and the Mac knows the regen is coming. The 4 edits:

1. **Shim** `rust/src/api.rs` — add one pass-through:
   `write_assessment(handle, date, score: i32, level, state, confidence: f64)`
   → `gatc_ffi::VaultEngine::write_assessment(date, score, level, state, confidence)`.
   No logic; returns `()`/error like its siblings.
2. **FRB regen** — `flutter_rust_bridge_codegen` regenerates `lib/src/rust/`
   (this IS the regen trigger; `frb-drift-guard` will be red until it runs).
3. **Facade** `lib/rust_engine.dart` — `writeAssessment(...)` calling the binding.
4. **Call-site** `lib/services/health_ingest.dart` — inside the existing
   `if (mutated > 0)` block (right after `saveState`/`writeViterbiState`, ~:470–473),
   ONCE for the latest processed date: read `readinessIndicator(handle)` (+ the
   HMM `fatigue_state` from `getReadiness`), and write it back via
   `writeAssessment`. **Value map:** `score` = `readiness_indicator.score` (i32,
   the 4-axis blend), `level` = `readiness_indicator.level`, `confidence` =
   `readiness_indicator.confidence`, `state` = HMM `fatigue_state` from the
   `getReadiness` snapshot, `date` = the latest processed observation date.
   **MANDATORY honest-absence guard:** if `readiness_indicator` is no-data
   (`score == 0` AND empty `contributions`), SKIP the `writeAssessment` call
   entirely — never write a fabricated 0/neutral readiness row. (Engine is the
   single writer; Dart only couriers the engine's own value.)

**Phase 2 test (required):** a `flutter test` proving (a) a synced day with a
real readiness_indicator → a `biometrics` row whose readiness columns carry that
exact score/level/state/confidence; (b) a no-data day → NO readiness row written
(the guard). Plus the rust-engine seam tests #276/#278/#280 + the #3 single-writer
test stay green (they're in the bumped engine).

## Blast radius
- Phase 1: `rust/Cargo.toml` (done) + `Cargo.lock` (Mac) + `.so` rebuild. No Dart.
- Phase 2: `rust/src/api.rs`, `lib/src/rust/` (regen), `lib/rust_engine.dart`,
  `lib/services/health_ingest.dart`, one test. Crosses the Dart↔Rust boundary —
  already surfaced and authorized (founder go, 2026-06-18).

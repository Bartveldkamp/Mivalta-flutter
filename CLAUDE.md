# CLAUDE.md — MiValta Flutter frontend

Guidance for Claude Code when working with this repository.

## Repo scope

- WRITE scope for this Claude session: this repo only.
- READ-ONLY sibling repos on Hetzner box: mivalta-rust-engine,
  mivalta-science-engine, mivalta-android-client. Reference patterns only.

## Working Rules

**Rule 1 — Mac Claude Code executes by default.** Anything that touches the filesystem (creating files, editing code, running tests, building) goes through Claude Code on Bart's Mac (M4, Alta). Mac is the primary executor for all day-to-day work across the 4 active MiValta repos.

**Rule 2 — Hetzner Claude is the GPU specialist on standby.** Hetzner (144.76.62.249) is activated only when work requires GPU (model fine-tuning, large oracle eval runs) or sustained heavy compute exceeding Mac capacity. When activated, Hetzner Claude operates on a brief-driven contract — receives sealed briefs, executes within scope, coordinates back via GitHub PRs. Hetzner does not maintain a parallel autonomous chat session.

**Rule 3 — Web Claude orchestrates via GitHub MCP.** The web/app Claude (this seat) coordinates strategy, drafts briefs, reads architectural state via GitHub MCP, and reviews bot outputs adversarially. Web Claude does not have filesystem access. All cross-session continuity happens via versioned documents in repos (DECISIONS.md, ARCHITECTURE_OVERVIEW.md, W1_ORACLE_PLAN.md, CLAUDE.md, REVIEWER.md), not via chat memory.

**Rule 4 — Zero guessing.** If any Claude session does not know something with certainty, READ the source-of-truth before acting. GitHub UI for repo state. Source files for code state. Branch protection settings via API for gate state. Claude Code summary reports are useful but not authoritative — verify before acting on "all clean" claims.

---

## What This Is

MiValta's production Flutter frontend. Replaces `mivalta-android-client` over
~2-4 months.

**Core principle**: on-device first. The Rust engine DECIDES. Flutter DISPLAYS.
The LLM (V10.1) is the messenger, not the coach — deferred to grounded-Josi phase (PR-F).

## Current milestone

**MVP-1** — see `docs/MVP1_BUILD_BRIEF.md` for the full scope.

- Engine DECIDES, Flutter DISPLAYS. No thresholds/math/fallback in Dart.
- Default home: `ReadinessScreen` (three-zone PULL layout, dark-first).
- Headline: `readiness_indicator()` — the 4-axis readiness blend.
- Continuity: persisted ViterbiEngine state survives app restarts.
- V10.1 LLM spike: retained as kDebugMode-only route for grounded-Josi phase.
- No cloud round-trips; on-device only.

### Engine pin

`rust/Cargo.toml` pins `gatc-ffi` to revision `47af641` (engine_registry v2.20) — carries the MONITOR/ADVISOR audit fixes (restart-continuity, worst-state REST, decoupling block + signal, real-availability duration, sport-guard).

## Repository Structure

```
Mivalta-flutter/
├── lib/                # Dart source
│   ├── main.dart       # Entry point — routes to ReadinessScreen
│   ├── rust_engine.dart # Dart facade over FRB bindings
│   ├── screens/        # UI screens (readiness, debug exerciser)
│   ├── theme/          # LOCKED design tokens (SourceTier swatches)
│   └── src/rust/       # Auto-generated FRB bindings (do not edit)
├── rust/               # Rust shim bridging flutter_rust_bridge ↔ gatc-ffi
│   ├── Cargo.toml      # gatc-ffi git-rev pin
│   └── src/api.rs      # Shim bindings — one gatc_ffi::* call per fn
├── android/            # Android target
├── test/               # flutter_test
├── docs/               # MVP build briefs
├── .github/            # CI workflows (adversarial review)
├── .claude/            # REVIEWER.md system prompt
├── pubspec.yaml        # Dart package manifest
└── pubspec.lock
```

## Build and Test

```bash
flutter pub get                                          # Resolve deps
flutter analyze                                          # Static analysis
flutter test                                             # Run unit/widget tests
flutter build apk --debug --target-platform android-arm64  # Debug build
flutter run                                              # Launch on attached device
```

## How Flutter consumes the engine

- **Rust engine binding via `flutter_rust_bridge`** (MVP-1). UniFFI bindings
  in `mivalta-rust-engine` are compiled into `libmivalta_rust_bridge.so` via
  the `rust/` shim crate. Every shim function is one `gatc_ffi::*` call →
  raw JSON string. No UniFFI record types cross the FRB boundary.
- **V10.1 LLM via `llama_cpp_dart`** — deferred to grounded-Josi phase (PR-F).
  The llama_cpp_dart dep is retained but the V10SpikeScreen is kDebugMode-only.
- **Continuity**: ViterbiEngine state is persisted to the vault on every
  state-changing operation and restored on subsequent launches. The app
  MUST call `constructEnginesFromState()` when persisted state exists, or
  `constructEnginesFresh()` + `saveState()` + `writeViterbiState()` on first run.

## Architecture Rules (STRICTLY ENFORCED)

1. **No engine logic in Dart.** Computation stays in Rust.
2. **FFI is pure transport.** `rust/src/api.rs` binds one `gatc_ffi::*` method
   per function; it adds no engine logic. Returns raw JSON strings.
3. **Dart is display only.** Widgets map engine output to UI state.
   No thresholds, math, or fallback logic.
4. **Source tier color tokens are locked**: Medical `#2BD974`, Device
   `#00C6A7`, Partial `#E6872F`, Manual `#878C8C`. Use the design
   token; never hardcode hex.
5. **F1 no-data copy is locked verbatim**: "We need more data to
   predict recovery." Do not paraphrase, do not soften.
6. **No cloud round-trips in the LLM path.** On-device only.
   Model download from `http://144.76.62.249/models/*` is the only
   HTTP exception, and only on first launch.
7. **No dead code.** Every new public Dart symbol has a call site
   reachable from production within one PR.
8. **New behaviour needs a test.** `flutter test` / widget test /
   integration test, with a concrete-value assertion.

## Key Entry Points

- `lib/main.dart` — production entry point → ReadinessScreen.
- `lib/screens/readiness_screen.dart` — three-zone PULL home, driven by engine.
- `lib/rust_engine.dart` — Dart facade over FRB bindings.
- `rust/src/api.rs` — shim bindings (one gatc_ffi::* call per fn).
- `lib/screens/debug_swatch_exerciser.dart` — kDebugMode-only SourceTier tester.
- `V10SpikeScreen` (main.dart) — kDebugMode-only V10.1 LLM screen.

## Commit Convention

```
feat(flutter): Add readiness_indicator binding
fix(flutter): Guard against null advisories in readiness screen
test(flutter): Add continuity round-trip test
docs: Update MVP1_BUILD_BRIEF.md with PR-A scope
```

### Scope discipline

Changes to `rust/src/api.rs` (shim), `lib/rust_engine.dart` (facade), or any
code that crosses the Dart↔Rust boundary require pausing and surfacing the
proposed change before editing — the FFI layer is load-bearing for the whole
product.

---

## Related Repos

Cross-repo decisions and context: see [`docs/DECISIONS.md`](https://github.com/Bartveldkamp/mivalta-rust-engine/blob/main/docs/DECISIONS.md) in mivalta-rust-engine.

| Repo | Role | Language | Link |
|------|------|----------|------|
| mivalta-rust-engine | Privacy-first AI fitness coaching engine, ships to mobile via FFI | Rust | [GitHub](https://github.com/Bartveldkamp/mivalta-rust-engine) |
| mivalta-science-engine | Training pipeline, Josi LoRA fine-tuning, V10/V11 messenger | Python | [GitHub](https://github.com/Bartveldkamp/mivalta-science-engine) |
| mivalta-android-client | Native Android app, consumes UniFFI Kotlin bindings + jniLibs | Kotlin/Compose | [GitHub](https://github.com/Bartveldkamp/mivalta-android-client) |
| mivalta-flutter-test-ui | Flutter test/scratch harness | Flutter | [GitHub](https://github.com/Bartveldkamp/mivalta-flutter-test-ui) |

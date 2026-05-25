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

MiValta's forward-direction Flutter frontend. Replaces
`mivalta-android-client` over ~2-4 months. The Day 1-3 spike validates
V10.1 (`llama_cpp_dart`) and the rust-engine binding path
(`flutter_rust_bridge`) before any UI work begins.

**Core principle**: on-device first. The Rust engine DECIDES. Flutter
DISPLAYS. The LLM (V10.1) is the messenger, not the coach.

## Repository Structure

```
Mivalta-flutter/
├── lib/                # Dart source (spike: single-screen main.dart)
├── android/            # Android-only target for the spike
├── test/               # flutter_test
├── docs/               # Investigation + design notes
├── .github/            # CI workflows (adversarial review)
├── .claude/            # REVIEWER.md system prompt
├── pubspec.yaml        # Dart package manifest
└── pubspec.lock
```

Single-module for the spike; multi-module (Compose-equivalent
`feature/` + `core/` split) deferred until after V10.1 sign-off.

## Build and Test

```bash
flutter pub get                                          # Resolve deps
flutter analyze                                          # Static analysis
flutter test                                             # Run unit/widget tests
flutter build apk --debug --target-platform android-arm64  # Spike build
flutter run                                              # Launch on attached device
```

## How Flutter consumes the engine

- **V10.1 LLM via `llama_cpp_dart`** (Day 1 spike). Model:
  `http://144.76.62.249/models/josi-v10-1-q4_k_m.gguf` (sha256
  `8bb9f19deb49990fb6e5a22028624786c850f4ae0eefde8f30d99463c40adfdb`).
  Off-thread `LlamaEngine` worker isolate, streaming
  `GenerationEvent` for TTFT + total-time measurement.
- **Rust engine binding via `flutter_rust_bridge`** (Day 2+). UniFFI
  bindings in `mivalta-rust-engine` are Kotlin/Swift today; Dart
  binding via `flutter_rust_bridge` is the next spike target after
  V10.1 signs off.
- **F-VA1 PendingAdvisories** surface at the FFI boundary — Flutter
  consumes the JSON variants of the 5 state-gating scalars; it does
  not compute them.

## Architecture Rules (STRICTLY ENFORCED)

1. **No engine logic in Dart.** Computation stays in Rust.
2. **FFI is pure transport.** `flutter_rust_bridge` serializes typed
   data only; llama.cpp pointers stay within their binding scope.
3. **Dart is display only.** Widgets map engine output to UI state.
   No thresholds, math, or fallback logic.
4. **Source tier color tokens are locked**: Medical `#2BD974`, Device
   `#00C6A7`, Partial `#E6872F`, Manual `#878C8C`. Use the design
   token; never hardcode hex.
5. **F1 no-data copy is locked verbatim**: "We need more data to
   predict recovery." Do not paraphrase, do not soften.
6. **No cloud round-trips in the V10.1 LLM path.** On-device only.
   Model download from `http://144.76.62.249/models/*` is the only
   HTTP exception, and only on first launch.
7. **No dead code.** Every new public Dart symbol has a call site
   reachable from production within one PR.
8. **New behaviour needs a test.** `flutter test` / widget test /
   integration test, with a concrete-value assertion.

## Key Entry Points

- `lib/main.dart` — spike screen entry point (single-screen V10.1
  perf measurement).
- `LlamaEngine` worker isolate — future home of llama_cpp_dart
  binding behind a thin Dart-side facade.
- `flutter_rust_bridge` generated FFI module — future home of
  rust-engine binding (Day 2+).

## Commit Convention

```
feat(flutter): Add LlamaEngine isolate wrapper
fix(flutter): Guard against null Generation event on stream close
test(flutter): Add widget test for spike-screen latency labels
docs: Update V10_1_FLUTTER_PERF_SPIKE.md with device run results
```

### Scope discipline

Changes to `lib/main.dart` entry, FFI binding layers, or any code that crosses the Dart↔Rust boundary require pausing and surfacing the proposed change before editing — the V10.1 LLM path and the rust-engine binding are load-bearing for the whole product.

---

## Related Repos

Cross-repo decisions and context: see [`docs/DECISIONS.md`](https://github.com/Bartveldkamp/mivalta-rust-engine/blob/main/docs/DECISIONS.md) in mivalta-rust-engine.

| Repo | Role | Language | Link |
|------|------|----------|------|
| mivalta-rust-engine | Privacy-first AI fitness coaching engine, ships to mobile via FFI | Rust | [GitHub](https://github.com/Bartveldkamp/mivalta-rust-engine) |
| mivalta-science-engine | Training pipeline, Josi LoRA fine-tuning, V10/V11 messenger | Python | [GitHub](https://github.com/Bartveldkamp/mivalta-science-engine) |
| mivalta-android-client | Native Android app, consumes UniFFI Kotlin bindings + jniLibs | Kotlin/Compose | [GitHub](https://github.com/Bartveldkamp/mivalta-android-client) |
| mivalta-flutter-test-ui | Flutter test/scratch harness | Flutter | [GitHub](https://github.com/Bartveldkamp/mivalta-flutter-test-ui) |

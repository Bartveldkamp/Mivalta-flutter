# CLAUDE.md — MiValta Flutter frontend

Guidance for Claude Code when working with this repository.

## Repo scope

- WRITE scope for this Claude session: this repo only.
- READ-ONLY sibling repos on Hetzner box: mivalta-rust-engine,
  mivalta-science-engine, mivalta-android-client. Reference patterns only.

## Working with Claude — Three Rules

Codified after the 2026-05-17 cross-repo-sync session. Apply to every Claude session working on any MiValta repo.

### Rule 1 — Hetzner Claude executes

Anything that touches a filesystem (cargo, git, file edits, tests, builds, conflict resolution, training runs, GGUF exports, Android cross-compile) goes through Hetzner Claude over SSH. Web Claude does NOT write long shell scripts for the founder to copy-paste into a terminal. If a task needs hands, it needs Hetzner.

Hetzner is at `144.76.62.249`. Use tmux for resilience to SSH drops:

```
ssh root@144.76.62.249
tmux attach -t mivalta || tmux new -s mivalta
cd ~/mivalta-rust-engine
claude --resume     # or just `claude`
```

Hetzner has the full Rust toolchain (1.95.0 + Android targets), Android NDK r26d, V10/V11 training environment (Qwen3, llama.cpp), and 32+ GB RAM.

### Rule 2 — Web Claude orchestrates via GitHub MCP

Anything that touches GitHub (opening PRs, reading PR/commit/run state, monitoring workflows, cross-repo coordination, posting review replies) goes through web Claude via the GitHub MCP server. Hetzner Claude does NOT ask the founder to "check the Actions tab" — web Claude checks it directly.

Web Claude has full MCP access to:
- `Bartveldkamp/mivalta-rust-engine`
- `Bartveldkamp/mivalta-science-engine`
- `Bartveldkamp/mivalta-android-client`
- `Bartveldkamp/Mivalta-flutter`

### Rule 3 — Zero guessing

If either Claude does not know something, READ it before acting:

- Don't assume a SHA → query commits via MCP or `git rev-parse`
- Don't assume a table count → `cargo run -p gatc-export` and read the actual number
- Don't assume a line number → grep or Read the file
- Don't assume what `main` contains → fetch first, then check
- Don't write "should be around line N" → find the exact line first

### Division of labor

| Layer | Owns |
|---|---|
| **Hetzner Claude** | Shell, cargo, git, file edits, conflict resolution, test/lint runs, building bindings, training runs |
| **Web Claude** (GitHub MCP) | Reading repo/PR/run state, opening PRs with strategic context, monitoring workflows, cross-repo coordination, drafting briefs for Hetzner |
| **Founder** | Merge decisions, strategic direction, sport-science judgment, branding, commercial decisions |

### Anti-patterns banned

- "Paste this script into your terminal" → use Hetzner Claude instead
- "Should be around line N" → grep first, then act
- "Expected X, got Y" without verifying → read the real number
- "Try this, if it fails paste the error" → only when no other diagnostic path

### Why this exists

The 2026-05-17 cross-repo-sync session burned ~4 hours of founder time in a copy-paste loop because web Claude was guessing what the shell would output instead of reading what it actually output. The breakthrough was Hetzner Claude doing 3 cherry-picks autonomously in 21 minutes with senior-level judgment (caught Batch A contamination in PR #134's base, surgically removed it without prompting). 10x faster AND higher quality than the copy-paste loop.

Codifying so neither future Claude nor future founder drifts back.

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

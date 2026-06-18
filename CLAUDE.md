# CLAUDE.md — MiValta Flutter frontend

Guidance for Claude Code when working with this repository.

## Viterbi terminology — NON-NEGOTIABLE (READ FIRST)

**Viterbi is the engine that RUNS / ACTS / COMPUTES / DECIDES. The HMM is a
FORMULA inside Viterbi (π/A/B + decode/forward) — it never "runs" or "decides".**
There is no standalone "HMM state" or "HMM readiness": readiness is Viterbi's
4-axis indicator, of which the HMM posterior is one axis. In Dart, code
comments, and chat, the subject of run/compute/decide is **Viterbi**, never the
HMM. Canonical rule + banned/correct phrasings:
`mivalta-rust-engine/docs/VITERBI_TERMINOLOGY.md`. Read it before describing or
touching any readiness/Viterbi/HMM code or display.

## Architecture — carved-in-stone facts (READ FIRST before architectural design)

The canonical data-architecture facts live in the **Immovable Facts** at the top
of `mivalta-rust-engine/docs/ARCHITECTURE.md` (data flow, vault-first/sovereignty,
encryption boundary, layer responsibilities) — each verified against real code
with a `path:line` citation, including the Flutter side (e.g. the vault-first
auto-sync in `lib/services/health_ingest.dart`, Dart-is-display-only). **Read it
before any design touching the data flow / vault / FFI boundary, and verify your
premise against it / the code first** — a design built on a wrong architectural
premise has no other mechanical catch. Engine DECIDES, Flutter DISPLAYS; the
edges courier, the engine computes.

Its granular companion is `mivalta-rust-engine/docs/VERIFIED_FINDINGS.md` —
durable code-traced facts (each `file:line` + verification date) so sessions
don't re-derive what's known. **Check it before tracing a code fact; spot-re-
confirm a cited line before relying on it for high-stakes work.**

## Working Protocol — Quality Charter (READ FIRST · NON-NEGOTIABLE)

Full text: [`docs/QUALITY_CHARTER.md`](docs/QUALITY_CHARTER.md). The bar is
**gold-Olympic-medal**: every value real, every claim verified, every gap
honest. This **outranks speed and "looks done."**

**PRIME DIRECTIVE — NO FABRICATION.** Never present to the user, or feed the
engine, a value that isn't the real result of the real computation on real
input — no placeholders, defaults-as-data, guessed constants, or "conservative
estimates" that ship. Missing input → **honest absence** (null / "no data") or
**fail loud**. Never a stand-in. *(Canonical violation: a workout load recorded
as `value: durationMinutes` and fed to the HMM — a fabrication that passed CI.
CI green ≠ true.)*

**THE LAWS**
1. Trace every number to its real source, on demand.
2. The engine computes; the edges (Dart / FFI / transport) only courier — no
   math (not even a mean) outside the engine.
3. No silent fallbacks or defaults masquerading as measurement.
4. Placeholders / TODOs in a value-producing path are tracked defects, not a
   resting state — finish or make honest-absent before merge.
5. CI green is necessary, not sufficient — every data path needs a semantic audit.
6. Fail loud over fail quiet.
7. Cite the science; use the physiologically correct form, not the convenient one.
8. Cross-boundary / cross-repo changes are surfaced before editing and travel via
   contract docs, never a quiet edit.

**THE PRACTICE** — read the real code before any claim (never a summary or a
prior chat's word); verify by **execution** (run the test / `flutter test` /
read the CI log), not assertion; falsify your own claims; report the diff + test
output with gaps named, not essays. Never say "done / clean" unless traced
**this session**.

**OPERATING MODEL** — one coding seat works across all three repos (reads all;
writes the repo in scope). The **Mac** terminal builds/runs (iOS / simulator)
only; **Hetzner** does GPU only. **Flat git:** small change → PR → merge on
green → delete branch.

## Working Discipline — the session method (READ FIRST · companion to the Charter)

The Charter says *what must be true*; the **Working Discipline** says *how a
session proves it and works without doing damage* — the rules that actually held
in practice, each pointing to the **mechanical thing that catches you breaking
it** (seam-test template + machine-closed loop, verify-your-own-output before
reporting, commit-local-hold-push with ambiguity = hold-not-permission,
design-surface-and-hold before any engine-path edit, branch-off-`main`,
untested≠broken / don't inflate scope, the logic→tests / build→drift-guard /
integration→one-sync layer split). Judgment-only rules are marked **[JUDGMENT]**;
everything else names its backstop. Canonical doc:
`mivalta-rust-engine/docs/WORKING_DISCIPLINE.md`. Read it before any code or
verify work. (In this repo the build→drift-guard layer is live as
`.github/workflows/frb-drift-guard.yml` + `scripts/build_ios.sh`.)

## Repo scope

- WRITE scope for this Claude session: this repo only.
- READ-ONLY sibling repos on Hetzner box: mivalta-rust-engine,
  mivalta-science-engine, mivalta-android-client. Reference patterns only.

## Working Rules

**Rule 1 — The remote/cloud Claude session CODES; Mac Claude Code BUILDS and RUNS only (founder, 2026-06-12).** All implementation (Dart, docs, tests) is authored by the coding session and pushed to the working branch. The Mac session's job is the macOS-only physical layer and nothing more: `git pull`, build the iOS/Android artifacts (xcframework, pods, `flutter run`), the FRB codegen step when asked, and showing the app on the simulator/device. The Mac session does NOT design, refactor, or implement features on its own initiative — it executes explicit build/run instructions and reports results. (This supersedes the older "Mac executes by default" rule: parallel coding caused rebase collisions and stale-doc reasoning on 2026-06-12.)

**Rule 2 — Hetzner Claude is the GPU specialist on standby.** Hetzner (144.76.62.249) is activated only when work requires GPU (model fine-tuning, large oracle eval runs) or sustained heavy compute exceeding Mac capacity. When activated, Hetzner Claude operates on a brief-driven contract — receives sealed briefs, executes within scope, coordinates back via GitHub PRs. Hetzner does not maintain a parallel autonomous chat session.

**Rule 3 — Web Claude orchestrates via GitHub MCP.** The web/app Claude (this seat) coordinates strategy, drafts briefs, reads architectural state via GitHub MCP, and reviews bot outputs adversarially. Web Claude does not have filesystem access. All cross-session continuity happens via versioned documents in repos (DECISIONS.md, ARCHITECTURE_OVERVIEW.md, W1_ORACLE_PLAN.md, CLAUDE.md, REVIEWER.md), not via chat memory.

**Rule 4 — Zero guessing.** If any Claude session does not know something with certainty, READ the source-of-truth before acting. GitHub UI for repo state. Source files for code state. Branch protection settings via API for gate state. Claude Code summary reports are useful but not authoritative — verify before acting on "all clean" claims.

---

## What This Is

MiValta's production Flutter frontend. Replaces `mivalta-android-client` over
~2-4 months.

**Core principle**: on-device first. The Rust engine DECIDES. Flutter DISPLAYS.
The LLM is the messenger, not the coach — fully deferred to the grounded-Josi
phase (PR-F). The V10.1 spike was purged (PR-J, enforced by
`.github/workflows/lineage-guard.yml`); its replacement (model W) ships via
Play Asset Delivery with a clean-slate architecture.

## Current milestone

**MVP-1** — see `docs/MVP1_BUILD_BRIEF.md` for the full scope.

- Engine DECIDES, Flutter DISPLAYS. No thresholds/math/fallback in Dart.
- Default home: `ReadinessScreen` (three-zone PULL layout, dark-first).
- Headline: `readiness_indicator()` — the 4-axis readiness blend.
- Continuity: persisted ViterbiEngine state survives app restarts.
- LLM layer: fully deferred (V10.1 spike purged in PR-J). The only
  kDebugMode-only screen is `debug_swatch_exerciser.dart`.
- No cloud round-trips; on-device only.

### Engine pin

`rust/Cargo.toml` pins `gatc-ffi` and `gatc-viterbi` to revision `2d51fea` (rust-engine `main` HEAD after #307, engine_registry **v2.24** per `engine_registry.json` at that rev). The `79b7c93 → 2d51fea` bump carries the **#3 readiness write-back single-writer** (#298): `write_biometric` no longer writes the biometrics readiness columns — only `write_assessment` does — which is the precondition for the Flutter call-site to write the 4-axis `readiness_indicator` back without a dual-writer clobber. It also sweeps #4a re-ingest-reproducible normalizer timestamps (#291) and #4b gated fail-safe load dedup (#295), both behaviour-only. `engine_registry.json` is **unchanged** across the range (v2.24, zero method delta), so the bump adds NO FFI surface and needs NO FRB regen on its own (a pure rev-SHA replacement + `.so` rebuild). The earlier pin also provided the unified advisor→GATC system selector (Z2-forever fix), `AdvisorEngine::recommend_workout_with_history` (vault history → energy-system rotation), B5 calibration probes, the `expression` option field, and the Viterbi safety chain; `advisor_screen.dart` is the live caller. The `rev = "2d51fea"` line in `rust/Cargo.toml` is authoritative; the comment block above it narrates the full re-pin history. **The `write_assessment` shim binding (the #3 wiring) lands in a follow-up commit — THAT is the FRB-regen trigger, not this bump.**

## Repository Structure

```
Mivalta-flutter/
├── lib/                # Dart source
│   ├── main.dart       # Entry point — first-launch detection → OnboardingScreen or ReadinessScreen
│   ├── rust_engine.dart # Dart facade over FRB bindings
│   ├── screens/        # 8 UI screens (readiness, readiness detail, advisor, explore,
│   │                   # manual entry, onboarding, settings, debug swatch exerciser)
│   ├── models/         # Display-side parse models (activity, power curve, trends, …)
│   ├── widgets/        # readiness_ring + analytics/ chart cards
│   ├── services/       # health_ingest, profile_service
│   ├── copy/           # Locked copy strings (F1)
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
- **LLM layer: none in the current build.** The V10.1 spike (and its
  llama_cpp_dart dep) was purged in PR-J; the on-device messenger is deferred
  to the grounded-Josi phase (PR-F) and will ship as model W via Play Asset
  Delivery.
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
6. **No cloud round-trips.** On-device only. (The V10-era first-launch
   model-download HTTP exception was removed with the PR-J purge; the
   replacement messenger ships via Play Asset Delivery.)
   **OS-level weather exception (founder-approved 2026-06-12,
   FOUNDER_FEEDBACK_2026-06-12 item 18):** local weather on the home
   comes from Apple WeatherKit via the `mivalta/weather` platform
   channel — the fetch is performed by Apple's OS frame (CoreLocation
   one-shot + WeatherKit), never by MiValta servers and never as
   MiValta-originated HTTP. Any failure renders honest absence (no
   icon, no forecast), never fabricated conditions. Android
   equivalent t.b.d.; until decided the channel is iOS-only and
   Android shows nothing.
7. **No dead code.** Every new public Dart symbol has a call site
   reachable from production within one PR.
8. **New behaviour needs a test.** `flutter test` / widget test /
   integration test, with a concrete-value assertion.
9. **Josi is a PRESENTER, locked (founder 2026-06-12).** She renders as
   on-screen TEXT — no chat box, no text input, no open Q&A, and **no
   TTS/audio layer** in the beta. "Voice" is a tone, not audio. The user's
   only interactions: the "why?" disclosure tap and choosing among engine
   suggestions on the Advisor screen. Open conversation is Coach tier
   (post-beta). See `docs/DESIGN_BUILD_SPEC.md` → "Josi's role".

## Key Entry Points

- `lib/main.dart` — production entry point → ReadinessScreen.
- `lib/screens/readiness_screen.dart` — three-zone PULL home, driven by engine.
- `lib/rust_engine.dart` — Dart facade over FRB bindings.
- `rust/src/api.rs` — shim bindings (one gatc_ffi::* call per fn).
- `lib/screens/debug_swatch_exerciser.dart` — kDebugMode-only SourceTier tester.

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

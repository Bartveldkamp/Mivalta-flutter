# V10.1 spike — closed

> Marker doc. Day 7 is the final spike milestone. Day 8+ is **MVP
> build week 1, Figma rebuild** — tracked separately, opened from a
> fresh session, not "spike Day 8."

## What the spike proved

| Question | Answer |
|---|---|
| Can a Flutter shell load Qwen3-1.7B Q4_K_M GGUF on arm64-v8a? | Yes — `llama_cpp_dart` 0.9.0-dev.6 prebuilt CPU AAR, Day-1 PR #1. |
| Can Flutter consume the rust-engine FFI on Android? | Yes — `flutter_rust_bridge` 2.12.0 over a thin shim crate (`rust/` in this repo), Day-2 PR #2. |
| Real-data round trip (profile → engine → V10.1)? | Yes — Day-3 PR #5, six FRB methods (`construct_engines`, `readiness_score`, `viterbi_fatigue_state`, `zone_cap_with_advisories`, `recommend_workout`, `vault_snapshot`) bound to existing gatc-ffi `pub fn`s; no new pub fns in rust-engine. |
| Can the F1 readiness UI render real engine output? | Yes — Day-4 PR #8, five display-only sections, LOCKED SourceTier color tokens, LOCKED F1 no-data copy. |
| Per-observation SourceTier reachable from Flutter? | Yes — Day-5 added `VaultEngine.last_observation_source_tier()` upstream (rust-engine PR #147 → main) and wired it through to a single LOCKED swatch in the readiness screen (Mivalta-flutter PR #7). |
| TTFT < 10 s on the Motorola Edge 60? | **See `HARDWARE_VERIFICATION_RESULTS.md` for the empirical answer.** Day-7 PR ships the telemetry overlay; the results commit on that doc is the spike close. |
| Build reproducible from a fresh clone with CI? | Yes — `rust/Cargo.toml` git-rev pin against rust-engine SHA, `.github/workflows/smoke-build.yml` runs on PR + main, no-ops cleanly without `RUST_ENGINE_DEPLOY_KEY` and runs end-to-end with it. |

## What's deferred to MVP build (Figma rebuild)

Anything below was flagged in a spike PR's review or PR body and
left for the post-spike build. Not a blocker for the spike close —
the spike proves the wiring; the MVP rebuilds the product on top.

- **F1 deepening.** Today section (a) gates on `advisories.last_observation_at == null`; sections (b)–(d) render their own engine defaults. MVP will replace this with the founder-authored F1 deck (multiple frames, conditional copy, designer-supplied tokens).
- **iOS target.** Spike was Android-only. Adding iOS requires an `xcframework` slot in `rust/Cargo.toml` and a `MainViewController.swift` mirror of the platform channel. Mechanical.
- **`SuggesterContext` user inputs.** `recommend_workout` defaults `mood = "normal"`, `equipment = null`, `terrain = null`, `phase = "general_prep"`, `meso_day = 0`, `variant_seed = 0`, `session_class = "standard"`. MVP needs a mood/equipment picker before any of these defaults are honest.
- **`ChatEngine` binding for native V10.1 grounding.** Spike uses a raw single-prompt path against the LlamaEngine isolate; the productive path packages engine state into the prompt via `gatc_ffi::ChatEngine::generate_response_*`. Deferred.
- **`compiled_tables.json` provenance refresh.** Currently committed as a ~335 KB asset; needs a per-rust-engine-bump regeneration step.
- **P3 cleanups noted across PRs #5–#7:**
  - Vault dir provisioning move to a `RustEngineBinding.bootstrapWithSupportDir()` helper.
  - TOCTOU on `Directory.create(recursive: true)` precheck (cosmetic).
  - Positive assertion in smoke-build CI that no `libgatc*.so` survives the rm-glob.
  - Test-side imports of `package:mivalta_flutter/src/rust/api.dart` for `BridgeError_*` variants (re-export through facade or wait for FRB to expose them).

## Empirical record

`docs/spike/HARDWARE_VERIFICATION_RESULTS.md` is the authoritative
record. The numbers in that doc are the answer to "did the spike
hit its acceptance bar?" — not anything in this file.

## Next milestone

MVP build week 1 opens from a fresh session against a Figma-driven
brief. **Web Claude will not queue a Day 8 from the spike session.**

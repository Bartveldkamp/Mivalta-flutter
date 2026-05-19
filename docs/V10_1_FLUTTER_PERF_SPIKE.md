# V10.1 Flutter perf spike — investigation

> **Status:** investigation phase complete; **PAUSED for sign-off** on package choice before implementation.
>
> Branch: `claude/v10-1-perf-spike`. Flutter SDK: 3.44.0 stable (Dart 3.12).
> Target device: Motorola Edge 60 (Android, arm64-v8a).
> Model: Josi V10.1 — `josi-v10-1-q4_k_m.gguf`, Qwen3-1.7B Q4_K_M, 1.03 GB
> (sha256 `8bb9f19d…`), served from `http://144.76.62.249/models/`.
>
> Goal: prove (or disprove) <10 s response latency for one typical chat
> turn from a Flutter shell, on real hardware, today.

---

## What the existing native Android client already proves

The `mivalta-android-client` repo vendors `llama.cpp` directly under
`core/ai/src/main/cpp/llama.cpp/` (pinned to upstream commit
`537eadb1b`, 2026-02-06). Qwen3 architecture is supported by that
build — V10 / V10.1 both already run on-device through `JosiV10Inference`.
So the question is **not** "can Qwen3-1.7B Q4_K_M run on this hardware?"
(known yes) — it is **"can a Flutter wrapper match it without re-doing
the C++ build by hand?"**

That framing lets us favour a package that ships **prebuilt Android
arm64-v8a binaries** over one that needs custom CMake/NDK plumbing on
Day 1.

---

## Package landscape (read-only inventory, May 2026)

| Package | Latest | Last published | Active? | Android arm64 | GGUF from disk | Qwen3 evidence | Notes |
|---|---|---|---|---|---|---|---|
| **`llama_cpp_dart`** (netdur) | `0.9.0-dev.6` | 2026-04-30 | **yes** — 262 commits, ongoing pre-1.0 rewrite | **yes**, ships prebuilt CPU + Hexagon AAR from CI | yes (`Llama("path.gguf")`) | **explicit** — README discusses "Qwen3 SWA" cache behaviour | Off-thread inference via `LlamaEngine` worker isolate; streaming `Stream<GenerationEvent>`; "scope shifted to Flutter mobile only"; API may break before 1.0. |
| **`lib_llama_cpp`** (gsmlg-app) | `0.6.2` | **2026-05-19 (~1h ago)** | **yes** | yes, federated `lib_llama_cpp_android`, CPU prebuilt .so | yes (`modelPath`) | not called out, but is a thin llama.cpp passthrough | Brand-new OpenAI-shaped facade (`client.chat.completions.create`). Promising but ~zero in-the-wild track record. |
| **`flutter_gemma`** (DenisovAV) | `0.15.3` | 2026-05-17 | **yes** | yes | **no — `.task` / `.litertlm` / `.bin` / `.tflite`** | yes ("Qwen3 0.6B") | **Hard veto.** Engine is MediaPipe GenAI / LiteRT, not llama.cpp. Our shipped artifact is a GGUF — converting Qwen3-1.7B → MediaPipe `.task` is a separate (multi-day) workstream and not guaranteed to exist for our LoRA-fine-tuned V10.1. |
| **`llama_cpp`** (lindeer) | `1.2.0` | 15 months ago | stale | yes | yes | none | Pinned to llama.cpp commit `8854044` — pre-`libllama.so`/`libggml.so` split. Qwen3 support unlikely / untested. |
| **`fllama`** (Telosnex) | `0.0.1` on pub | 18 months ago | stale | yes (CI build) | yes | none | Author README last touched Feb 2024. |
| **`llamafu`** (neul-labs) | `0.1.0` | 3 months ago | unclear | yes | yes | **Qwen2 only** (no Qwen3 mention) | Newer entrant, smaller surface area; risky for Day 1. |

Direct alternative considered:

- **`flutter_rust_bridge` over a Rust llama wrapper** — would mean
  pulling in `llama-cpp-rs` or building our own crate, then codegen'ing
  Dart FFI, then cross-compiling for `aarch64-linux-android`. The Mivalta
  rust-engine itself does not currently bind llama.cpp (it owns the
  coaching/planning surface, not the LLM). So this path is **net-new
  Rust + NDK + codegen** before a single token is generated. Out of
  budget for a Day 1 spike.
- **Platform-channel reuse of the native client's vendored
  llama.cpp** — defensible Day 2+ fallback (the C++ already builds and
  runs Qwen3-1.7B on this exact device family), but requires lifting
  the Android module out of `mivalta-android-client` and wiring a
  Kotlin shim. Not Day 1.

---

## Recommendation

**Use `llama_cpp_dart` 0.9.0-dev.6** for the spike, with a single-prompt
streaming inference call that measures wall-clock to first token and
total generation time.

Reasons (ranked by Day-1 risk reduction):

1. **Qwen3-specific awareness.** netdur's README explicitly references
   Qwen3 SWA cache behaviour. The author knows the architecture exists
   and tracks its quirks — strong signal that a Q4_K_M Qwen3-1.7B GGUF
   will at least load and tokenize correctly.
2. **Prebuilt Android AAR shipped from the package's own CI** — no NDK
   toolchain dance on Day 1. (`lib_llama_cpp` also ships prebuilts, but
   it is one hour old; we'd rather not be the first user.)
3. **Off-thread isolate + streaming `GenerationEvent` stream.** Perfect
   match for the spike's two acceptance metrics: time-to-first-token and
   total response time, both measurable without UI thread contortions.
4. **Scope statement matches ours.** netdur explicitly narrowed
   `llama_cpp_dart` to "Flutter mobile only" — exactly our target.
5. **Active.** Pre-release versions are landing weeks apart through
   2026. We can pin to the prerelease and expect responsiveness if we
   hit a bug.

Accepted risks:
- It's a **`-dev.6` prerelease**; API is documented to break before
  1.0. For a one-screen spike that's a non-issue.
- AAR is CPU-only. That matches the existing native client (no GPU on
  this Motorola path), so the latency floor should be comparable.

If `llama_cpp_dart` fails to load V10.1 or crashes on inference, the
**Plan B** (Day 2 work, not Day 1) is platform-channel reuse of the
native client's already-compiled `llama.cpp` module. Plan C would be
`flutter_rust_bridge` + a fresh Rust llama crate — not recommended.

---

## Proposed implementation (after sign-off)

Single screen, no theming, no DI, no persistence:

1. App startup: ensure V10.1 GGUF is at
   `getApplicationSupportDirectory()/josi-v10-1-q4_k_m.gguf`. If
   missing, download once from
   `http://144.76.62.249/models/josi-v10-1-q4_k_m.gguf`, verify SHA-256
   matches `8bb9f19deb49990fb6e5a22028624786c850f4ae0eefde8f30d99463c40adfdb`.
2. UI: `TextField` (default value: "Should I train today?"), `Run`
   button, output `Text`, two latency labels: **TTFT** (ms from tap to
   first token) and **Total** (ms from tap to completion).
3. On Run: spin up `LlamaEngine` worker isolate (one-time), submit
   prompt, capture timestamps off the `GenerationEvent` stream, render.
4. Network security: cleartext-permit
   `144.76.62.249` only via Android Network Security Config (the model
   host is HTTP, not HTTPS — same as native client).
5. `flutter build apk --debug` → arm64-v8a APK → report path, size,
   sha256.

---

## Verdict (to be filled after device run)

> _Pending hardware measurement. Founder will install the APK on the
> Motorola Edge 60 and read TTFT + Total off-screen._

- [ ] **PASS** — < 10 s total → proceed to Day 2 (Compose-equivalent
      UI port).
- [ ] **FAIL** — ≥ 10 s, or crash, or load failure → escalate; activate
      Plan B (platform-channel reuse of native client llama.cpp).

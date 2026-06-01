# MVP-1 BUILD BRIEF — MiValta Flutter (post-spike Figma rebuild)

> **Status:** sealed brief, ready to execute. Authored by Web Claude
> (orchestration seat) per Working Rule 3. The Mac Claude Code executor
> builds from this PR-by-PR; the founder runs each APK on-device.
>
> **Supersedes:** `docs/spike/SPIKE_CLOSED.md` "Next milestone" line.
> The V10.1 spike is closed; this is "MVP build week 1."
>
> **Develop on branch:** `claude/clever-noether-1hhfw` (this branch).

---

## 0. One-paragraph framing

The spike *proved the wiring*: a Flutter shell binds the Rust engine over
`flutter_rust_bridge` (raw JSON strings only across the boundary), reads
real engine output, and renders it display-only. MVP-1 *rebuilds the
product* on top of that proven binding, to the UI/UX Direction v1.1
(three-zone PULL home, calm/honest/agency, dark-first) and the canonical
spec v1.4 ("a coach they can trust — honest about what it does not yet
know"; **not** an all-knowing coach). Scope is **MONITOR + ADVISOR +
grounded Josi**, built in that order, **with the on-device LLM added
last**. Everything before the LLM phase is pure engine→display: zero
fabrication surface, which is exactly the constraint we locked
("must come from engine to eliminate hallucination / wandering of LLM").

---

## 1. The non-negotiable contract (carried from the spike, do not relax)

1. **The engine DECIDES. Flutter DISPLAYS.** No thresholds, math, or
   fallback logic in Dart. Every displayed value is verbatim from an
   engine FFI method.
2. **FFI is pure transport.** The `rust/` shim crate adds no engine
   logic; it delegates to one `gatc_ffi::*` method and returns the raw
   JSON string. No UniFFI record type crosses the FRB boundary (Day-2
   review WARNING 4 — keep it).
3. **Zero fabrication.** If the engine has no value, the UI shows the
   engine's own "honest empty" signal (e.g. `last_observation_at == null`
   → the LOCKED F1 no-data copy "We need more data to predict
   recovery."). The UI never invents, interpolates, or softens.
4. **LOCKED design tokens.** SourceTier hex (Medical `#2BD974`, Device
   `#00C6A7`, Partial `#E6872F`, Manual `#878C8C`) and F1 no-data copy
   are locked. Change only on a founder-authorised token bump in the same
   PR.
5. **On-device only.** No cloud round-trips. (When the LLM phase lands,
   the only HTTP exception is the first-launch model download.)
6. **No dead Dart.** Every new public Dart symbol has a production call
   site within its PR. New behaviour ships with a `flutter test`
   concrete-value assertion. `smoke-build.yml` stays green.

---

## 2. Engine reconciliation — the shim is months stale

`rust/Cargo.toml` pins `gatc-ffi` at **`281d831`** (Day-7 spike SHA).
That predates the entire recent engine evolution. **First build step is
to re-pin and reconcile.**

| | Spike (`281d831`) | Current `main` (`94b2bd4`, registry **v2.18**) |
|---|---|---|
| Live readiness indicator | `readiness_score()` (0–100 scalar) | **`readiness_indicator()`** — the 4-axis readiness blend (HMM posteriors + Banister performance + physio z + psychological), calibration-aware, card-pinned `monitoring_v5:readiness_blend`. **This is the headline number for the home.** |
| V10 / "all-knowing coach" | present in engine + spike LLM path | **removed** from engine; spec → v1.4 honest posture |
| Engine count | pre-consolidation | **16 engines**, ChatEngine = 6 methods |
| New fields | — | `UniversalObservation.altitude_m`, `utc_offset_minutes` (§8.5 altitude/travel safety) |

**Action (PR-A):** bump the `rev =` pin to current `main`
(`94b2bd4...`, or latest `main` at build time — verify it contains
`pub fn readiness_indicator` and `engine_registry.json` `"version":
"2.18"` before pinning), regenerate the FRB bindings, and reconcile the
bound-method list below. Drop every V10/`josi-v10-1` reference from the
default code path (the GGUF model path stays dead-coded behind a debug
flag until the LLM phase — see §6 PR-F).

---

## 3. The binding map — every surface → exact engine method

All methods verified present on `main` in
`mivalta-rust-engine/crates/gatc-ffi/src/lib.rs`. ✅ = already bound in
the spike shim; ➕ = new shim binding to add. Engines are constructed
once from the canonical seed profile + `compiled_tables.json` + a
writable vault dir.

### Construction
| Shim fn | Engine ctor |
|---|---|
| `construct_engines` ✅ (extend) | `ViterbiEngine::new(profile)`, `AdvisorEngine::new(profile, tables)`, `VaultEngine::new(profile, vault_path)`, ➕ `DashboardEngine::new(...)`, and (LLM phase) `ChatEngine::new_with_vault(profile, vault_path)` |

### MONITOR surface (three-zone home + readiness detail)
| Displayed item | Shim fn | Engine method | Notes |
|---|---|---|---|
| **Readiness blend** (headline) | ➕ `readiness_indicator` | `ViterbiEngine::readiness_indicator()` | The live 4-axis blend. Replaces the spike's raw `readiness_score` as the headline. |
| Score 0–100 + advisories | `readiness_score` ✅ | `readiness_score()` | `advisories.last_observation_at == null` ⇒ insufficient-data path. |
| Fatigue state | `viterbi_fatigue_state` ✅ | `get_readiness()` | `state` field. |
| Zone cap + advisories | `zone_cap_with_advisories` ✅ | `zone_cap_with_advisories()` | |
| Readiness trend (sparkline) | ➕ `read_readiness_history` | `VaultEngine::read_readiness_history(days)` | Series for the home/detail trend. |
| Three-zone home payloads | ➕ `get_dashboard` / `get_state_widget` / `get_session_widget` / `get_context_widget` | `DashboardEngine::*` | Purpose-built display-only Tier-2.5 assembler (W1.1 W3/W4). All prose from knowledge cards, no LLM. **Use these to drive the three zones rather than re-assembling client-side.** |
| Data source tier swatch | `last_observation_source_tier` ✅ | `VaultEngine::last_observation_source_tier()` | LOCKED tokens. `null` ⇒ no-data copy. |
| Altitude/travel banner (§8.5) | (within readiness payloads) | — | Surface the engine's dampening signal; do not compute. |

### ADVISOR surface
| Displayed item | Shim fn | Engine method | Notes |
|---|---|---|---|
| Session options A/B/C | `recommend_workout` ✅ (rework) | `AdvisorEngine::suggest_workouts(context_json)` | **Spike stubbed the `SuggesterContext`** (mood=normal, equipment/terrain=null, phase=general_prep, meso_day=0…). MVP adds a real mood/equipment/terrain picker so these fields are honest. |
| Plan modification | ➕ `detect_scope` / `execute_replan` | `ReplanEngine::detect_scope(...)` + `execute_replan(...)` | Coach-mode gated (Micro/Meso structured edits + Macro rebuild). Optional for MVP-1; include only if the ADVISOR cut needs replan. |

### Data ingest (feeds MONITOR/ADVISOR honestly)
| Path | Shim fn | Engine method | Notes |
|---|---|---|---|
| Manual biometric | `write_minimal_biometric` ✅ (promote) | `VaultEngine::write_biometric(json)` | Spike version writes a placeholder `resting_hr`; production carries real metrics. |
| Vendor normalize | ➕ `normalize_observation` | `NormalizerEngine::*` (Garmin/Oura/Whoop/Polar/Apple/Wahoo/COROS/BLE) | One real vendor in MVP-1; rest follow. |
| Profile read-back | `vault_snapshot` ✅ | `VaultEngine::read_default_profile()` | |

### Josi surface — **LAST** (grounded conversational, then LLM)
| Item | Shim fn | Engine method | Notes |
|---|---|---|---|
| Conversational turn | ➕ `chat` | `ChatEngine::chat(message, context_json, athlete_id)` | §8 retrieval: **Josi only queries; the engine computes every value.** Returns structured JSON. The I6 constitutional guardrails live here (read-only on physics). |
| History | ➕ `get_conversation_for_llm` / `clear_history` | `ChatEngine::*` | |
| Profile retest mid-session | ➕ `update_profile` | `ChatEngine::update_profile(json)` | |
| On-device LLM messenger | (Dart, `llama_cpp_dart`) | — | The actual GGUF generation, fed *only* engine-computed state. **Added dead-last** (PR-F). |

---

## 4. Screen inventory (UI/UX Direction v1.1)

- **Home — three-zone PULL layout.** Dark-first, calm/honest/agency.
  Driven by `DashboardEngine` widgets + `readiness_indicator`. Zone 1
  state, zone 2 today's session, zone 3 context. No coaching imperative
  voice — present, don't push.
- **Readiness detail.** The 4 blend axes, the score, fatigue state, zone
  cap + advisories, trend sparkline, source-tier swatch, altitude/travel
  banner when active.
- **Advisor.** A/B/C session options with the mood/equipment/terrain
  picker that makes `SuggesterContext` honest.
- **Josi bottom sheet (glass).** Conversational retrieval surface.
  Engine-grounded. **Built last.**
- **Debug exerciser** (kDebugMode only) — keep from the spike for tier
  swatch / vault exercising.

The spike's `main.dart` perf-measurement screen (prompt box + TTFT/PSS
telemetry) is **retired from the default route** in PR-A; its telemetry
harness may be preserved behind the debug flag for the LLM phase.

---

## 5. Stale docs to fix (cheap, do alongside PR-A)

- `CLAUDE.md` / `README.md` in this repo: V10.1-centric, "spike Day N"
  framing, old "Three Rules". Update to: production app, spec v1.4,
  UI/UX v1.1, readiness_blend headline, engine-decides/Flutter-displays.
- `flutter-test-ui` repo reference: confirm whether MVP-1 work belongs
  here (production) vs the scratch harness.

---

## 6. Build sequencing (PRs — each green on `flutter analyze` + `flutter test` + `smoke-build.yml`)

| PR | Scope | Gates |
|---|---|---|
| **PR-A** | Re-pin shim to current `main`; regenerate FRB; add `readiness_indicator`, `read_readiness_history`, the 4 `DashboardEngine` widget bindings; drop V10/GGUF from default route; refresh `CLAUDE.md`/`README`. | Binding round-trips; CI green; no V10 symbols in default path. |
| **PR-B** | Theme + three-zone home scaffold (dark-first tokens, PULL layout) wired to `DashboardEngine` widgets + `readiness_indicator`. | Home renders real engine state; insufficient-data path shows honest empty. |
| **PR-C** | Readiness detail (4 axes, trend, source tier, altitude/travel banner). | Every value verbatim from engine; widget test per section. |
| **PR-D** | Advisor surface + `SuggesterContext` mood/equipment/terrain picker → `suggest_workouts`. | A/B/C options reflect real picker input, not defaults. |
| **PR-E** | Data ingest: manual `write_biometric` + one real vendor via `NormalizerEngine`. | Round-trip write→readiness reflects new observation. |
| **PR-F** *(LAST)* | Grounded Josi bottom sheet via `ChatEngine::chat` (§8, engine-fed) **then** the on-device LLM messenger (`llama_cpp_dart`, sha256-gated download). | Josi surfaces only engine-computed values; LLM is messenger, never source of physics. |

---

## 7. Hard constraints on this seat (so expectations are honest)

- **Web Claude (this seat) cannot build or run Flutter.** No Flutter SDK,
  Android NDK, or device here; only `mivalta-rust-engine` is cloned. Per
  Working Rule 1, the Mac Claude Code executor builds; the founder runs
  the APK on-device. This brief + authored code on the branch is the
  hand-off artifact.
- **Engine repo is private; the shim clones it over SSH.** The Mac
  executor / CI needs the `RUST_ENGINE_DEPLOY_KEY` for the pinned rev to
  resolve (see README CI section).
- **FFI binding changes require surfacing before editing** (scope
  discipline, both repos' CLAUDE.md). PR-A's shim changes are pre-agreed
  by this brief; anything beyond it pauses for founder sign-off.

---

## 8. Open decisions for the founder

1. **ADVISOR cut for MVP-1:** suggestions only, or include `ReplanEngine`
   (coach-mode replan)? Brief assumes suggestions-only unless told
   otherwise.
2. **First real vendor** for PR-E (Garmin / Oura / Whoop / Polar / Apple
   / Wahoo / COROS / BLE)?
3. **LLM messenger model** for PR-F: reuse the spike's Qwen3-1.7B
   Q4_K_M GGUF path, or a different/updated checkpoint now that V10 is
   retired and Josi is strictly engine-grounded?

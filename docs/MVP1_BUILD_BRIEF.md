# MVP-1 BUILD BRIEF — MiValta Flutter (post-spike Figma rebuild)

> **Status:** sealed brief, executing. Authored by Web Claude (orchestration
> seat) per Working Rule 3. The Mac Claude Code executor builds from this
> PR-by-PR; the founder runs each APK on-device.
>
> **Supersedes:** `docs/spike/SPIKE_CLOSED.md` "Next milestone" line. The
> V10.1 spike is closed; this is "MVP build week 1."
>
> **Develop on branch:** `claude/clever-noether-1hhfw` (this branch).
>
> **Founder decisions locked (2026-06-01):** ADVISOR = **suggestions only**
> (no `ReplanEngine` in MVP-1). Data ingest connects **Garmin + Polar + BLE +
> other supported platforms** (multi-vendor, not one). The **entire LLM/Josi
> layer is deferred to a later step** — MVP-1 is purely about connecting the
> Rust engine to the Flutter frontend over FFI with real, working app
> functionality.

---

## 0. One-paragraph framing

The spike *proved the wiring*: a Flutter shell binds the Rust engine over
`flutter_rust_bridge` (raw JSON strings only across the boundary), reads real
engine output, and renders it display-only. MVP-1 *rebuilds the product* on top
of that proven binding, to UI/UX Direction v1.1 (three-zone PULL home,
calm/honest/agency, dark-first) and canonical spec v1.4 ("a coach they can
trust — honest about what it does not yet know"; **not** an all-knowing coach).
Scope is **MONITOR + ADVISOR (suggestions) + multi-vendor data ingest**, with
the **on-device LLM / grounded Josi added dead-last**. Everything in MVP-1 is
pure engine→display: zero fabrication surface, which is exactly the constraint
we locked ("must come from engine to eliminate hallucination / wandering of
LLM").

---

## 1. The non-negotiable contract (carried from the spike, do not relax)

1. **The engine DECIDES. Flutter DISPLAYS.** No thresholds, math, or fallback
   logic in Dart. Every displayed value is verbatim from an engine FFI method.
2. **FFI is pure transport.** The `rust/` shim crate adds no engine logic; it
   delegates to one `gatc_ffi::*` method and returns the raw JSON string. No
   UniFFI record type crosses the FRB boundary (Day-2 review WARNING 4 — keep).
3. **Zero fabrication.** If the engine has no value, the UI shows the engine's
   own "honest empty" signal (e.g. `last_observation_at == null` → the LOCKED
   F1 no-data copy "We need more data to predict recovery."). The UI never
   invents, interpolates, or softens.
4. **LOCKED design tokens.** SourceTier hex (Medical `#2BD974`, Device
   `#00C6A7`, Partial `#E6872F`, Manual `#878C8C`) and F1 no-data copy are
   locked. Change only on a founder-authorised token bump in the same PR.
5. **On-device compute only.** No cloud inference. The only network I/O is
   (a) pulling the user's *own* wearable data from authorised vendor accounts /
   BLE devices in the connectivity layer, and (b) — in the deferred LLM phase —
   the first-launch model download. Neither sends engine state off-device.
6. **No dead Dart.** Every new public Dart symbol has a production call site
   within its PR. New behaviour ships with a `flutter test` concrete-value
   assertion. `smoke-build.yml` stays green.

---

## 2. Engine reconciliation — the shim is months stale

`rust/Cargo.toml` pins `gatc-ffi` at **`281d831`** (Day-7 spike SHA), predating
the entire recent engine evolution. **First build step is to re-pin and
reconcile.**

| | Spike (`281d831`) | Current `main` (`94b2bd4`, registry **v2.18**) |
|---|---|---|
| Live readiness indicator | `readiness_score()` (0–100 scalar) | **`readiness_indicator()`** — 4-axis readiness blend (HMM posteriors + Banister performance + physio z + psychological), calibration-aware, card-pinned `monitoring_v5:readiness_blend`. **The headline number for the home.** |
| V10 / "all-knowing coach" | present in engine + spike LLM path | **removed** from engine; spec → v1.4 honest posture |
| Engine count | pre-consolidation | **16 engines**; ChatEngine = 6 methods |
| New fields | — | `UniversalObservation.altitude_m`, `utc_offset_minutes` (§8.5 altitude/travel safety) |

**Action (PR-A):** bump the `rev =` pin to current `main` (verify it contains
`pub fn readiness_indicator` and `engine_registry.json` `"version": "2.18"`
first), regenerate the FRB bindings, reconcile the bound-method list (§3), and
drop every V10/`josi-v10-1` reference from the default code path (the GGUF path
stays dead-coded behind a debug flag until the LLM phase).

---

## 3. The binding map — every surface → exact engine method

All methods verified present on `main` in
`mivalta-rust-engine/crates/gatc-ffi/src/lib.rs`. ✅ = already bound in the spike
shim; ➕ = new shim binding to add. Engines are constructed once from the
canonical seed profile + `compiled_tables.json` + a writable vault dir.

### Construction
| Shim fn | Engine ctors |
|---|---|
| `construct_engines` ✅ (extend) | `ViterbiEngine::new`, `AdvisorEngine::new`, `VaultEngine::new`, ➕ `DashboardEngine::new`, ➕ `NormalizerEngine::new`, and (LLM phase) `ChatEngine::new_with_vault` |

### MONITOR surface (three-zone home + readiness detail)
| Displayed item | Shim fn | Engine method | Notes |
|---|---|---|---|
| **Readiness blend** (headline) | ➕ `readiness_indicator` | `ViterbiEngine::readiness_indicator()` | Live 4-axis blend. Replaces the spike's raw `readiness_score` as the headline. |
| Score 0–100 + advisories | `readiness_score` ✅ | `readiness_score()` | `advisories.last_observation_at == null` ⇒ insufficient-data path. |
| Fatigue state | `viterbi_fatigue_state` ✅ | `get_readiness()` | `state` field. |
| Zone cap + advisories | `zone_cap_with_advisories` ✅ | `zone_cap_with_advisories()` | |
| Readiness trend | ➕ `read_readiness_history` | `VaultEngine::read_readiness_history(days)` | Series for home/detail trend. |
| Three-zone home payloads | ➕ `get_dashboard` / `get_state_widget` / `get_session_widget` / `get_context_widget` | `DashboardEngine::*` | Purpose-built display-only Tier-2.5 assembler. All prose from knowledge cards, no LLM. Drive the three zones from these. |
| Data source tier swatch | `last_observation_source_tier` ✅ | `VaultEngine::last_observation_source_tier()` | LOCKED tokens. `null` ⇒ no-data copy. |

### ADVISOR surface — **suggestions only (locked)**
| Displayed item | Shim fn | Engine method | Notes |
|---|---|---|---|
| Session options A/B/C | `recommend_workout` ✅ (rework) | `AdvisorEngine::suggest_workouts(context_json)` | Spike stubbed the `SuggesterContext`; MVP-D adds a real mood/equipment/terrain picker so the fields are honest. **`ReplanEngine` is OUT of MVP-1.** |

### Data ingest — engine NORMALIZES; the app does the transport
**Architectural split (important):** the Rust engine never connects to a device
or a vendor cloud. It only *normalizes* the JSON the app hands it. Real
transport (BLE, vendor OAuth) is the Flutter platform layer — see §4a and PR-E.

| Path | Shim fn | Engine method | Notes |
|---|---|---|---|
| Normalize vendor obs | ➕ `normalize_observation` | `NormalizerEngine::normalize_observation(vendor, json)` | vendor ∈ garmin / oura / whoop / polar / apple\|healthkit / wahoo / coros / ble. Bounds-validated before vault/HMM. |
| Classify a source | ➕ `classify_source` | `NormalizerEngine::classify_source(source)` | → tier + confidence acceleration. |
| Multi-source overview | ➕ `build_source_overview` | `NormalizerEngine::build_source_overview(sources_json)` | Which source is primary per metric (HRV/sleep/RHR/activity) — drives the "your data sources" UI. |
| Manual / write | `write_minimal_biometric` ✅ (promote) | `VaultEngine::write_biometric(json)` | Production carries real metrics, not the placeholder RHR. |
| Profile read-back | `vault_snapshot` ✅ | `VaultEngine::read_default_profile()` | |

### Josi surface — **deferred entirely to a later step**
`ChatEngine::chat / get_conversation_for_llm / clear_history / update_profile`
+ the on-device LLM messenger (`llama_cpp_dart`, engine-grounded, §8 retrieval:
Josi queries, the engine computes). **Not in MVP-1.**

---

## 4. Screen inventory (UI/UX Direction v1.1)

- **Home — three-zone PULL layout.** Dark-first, calm/honest/agency. Driven by
  `DashboardEngine` widgets + `readiness_indicator`. Present, don't push.
- **Readiness detail.** The 4 blend axes, score, fatigue state, zone cap +
  advisories, trend, source-tier swatch, altitude/travel banner when active.
- **Advisor.** A/B/C session options + mood/equipment/terrain picker that makes
  `SuggesterContext` honest. (Suggestions only — no replan.)
- **Data sources.** "Your connected devices/platforms" view driven by
  `build_source_overview` + per-source tier swatches.
- **Debug exerciser** (kDebugMode only) — kept from the spike.

### 4a. Connectivity (the real device/platform dots)
The actual connections the founder asked for live in the **Flutter platform
layer**, not the engine:
- **BLE** (chest straps / HR / power, e.g. Polar H10, BLE HRM) via a Flutter
  Bluetooth plugin → raw sample → `normalize_observation("ble", json)`.
- **Garmin** (Garmin Connect / Health API, OAuth) → raw JSON →
  `normalize_observation("garmin", json)`.
- **Polar** (Polar AccessLink, OAuth) → `normalize_observation("polar", json)`.
- **Others** (Oura / Whoop / Apple HealthKit / Wahoo / COROS) as the same
  pattern, enabled incrementally.
Each pulls the user's *own* data into the on-device vault; engine state never
leaves the device. This is its own PR (PR-E) because OAuth + BLE pairing +
background sync is substantial.

The spike's `main.dart` perf-measurement screen (prompt box + TTFT/PSS) is
**retired from the default route** in PR-A; its telemetry harness may be kept
behind the debug flag for the eventual LLM phase.

---

## 5. Stale docs to fix (cheap, do alongside PR-A)

- `CLAUDE.md` / `README.md` (this repo): V10.1-centric, "spike Day N", old
  "Three Rules". Update to: production app, spec v1.4, UI/UX v1.1,
  readiness_blend headline, engine-decides/Flutter-displays.

---

## 6. Build sequencing (PRs — each green on `flutter analyze` + `flutter test` + `smoke-build.yml`)

| PR | Scope | Gates |
|---|---|---|
| **PR-A** | Re-pin shim to current `main`; regenerate FRB; bind the full no-LLM surface (`readiness_indicator`, `read_readiness_history`, 4 Dashboard widgets, 3 Normalizer fns); keep advisor suggestions-only; retire V10/GGUF from default route; refresh `CLAUDE.md`/`README`. | Bindings round-trip on-device; CI green; no V10 symbol in default path. |
| **PR-B** | Theme + three-zone home (dark-first tokens, PULL layout) wired to `DashboardEngine` widgets + `readiness_indicator`. | Home renders real engine state; insufficient-data shows honest empty. |
| **PR-C** | Readiness detail (4 axes, trend, source tier, altitude/travel banner). | Every value verbatim from engine; widget test per section. |
| **PR-D** | Advisor surface + `SuggesterContext` mood/equipment/terrain picker → `suggest_workouts` (suggestions only). | A/B/C options reflect real picker input, not defaults. |
| **PR-E** | **Connectivity:** BLE + Garmin + Polar transport (then Oura/Whoop/Apple/Wahoo/COROS) → `normalize_observation` → vault; "data sources" UI via `build_source_overview`. | Real data from a paired device/account lands in the vault and moves readiness. |
| **PR-F** *(later step, not MVP-1)* | Grounded Josi bottom sheet via `ChatEngine::chat` (§8, engine-fed) **then** the on-device LLM messenger. | Josi surfaces only engine-computed values; LLM is messenger, never source of physics. |

---

## 7. Hard constraints on the orchestration seat (honest expectations)

- **Web Claude cannot build or run Flutter.** No Flutter SDK / Android NDK /
  device here; only `mivalta-rust-engine` is cloned. Per Working Rule 1 the Mac
  Claude Code executor builds; the founder runs the APK. This brief + authored
  code on the branch is the hand-off artifact.
- **Engine repo is private; the shim clones it over SSH.** The executor / CI
  needs `RUST_ENGINE_DEPLOY_KEY` for the pinned rev to resolve.
- **FFI binding changes require surfacing before editing** (scope discipline,
  both repos' CLAUDE.md). PR-A's shim changes are pre-agreed by this brief;
  anything beyond it pauses for founder sign-off.

---

## 8. Decisions — resolved

1. **ADVISOR cut:** suggestions only. `ReplanEngine` is **out** of MVP-1. ✅
2. **Connectivity:** Garmin + Polar + BLE first, then the other supported
   platforms, via the engine's existing normalizer vendors. ✅
3. **LLM:** entire LLM / grounded-Josi layer **deferred to a later step**
   (PR-F), after the engine↔frontend dots are fully connected. ✅

# WU3 — "No data" panel evidence matrix (Line-1, Phase 1)

Read-only trace. Diagnosis only — **no code edits in this work unit.** Each row
follows the data from its engine producer → FFI/FRB shim → Flutter consumer →
the exact threshold that gates the empty state, and is classified
**VERIFIED** (path intact, populates on real data) / **HONEST-ABSENCE**
(empty-by-design, engine-gated, copy is honest) / **BROKEN** (value is produced
but dropped, or the path can never populate).

Traced this session (2026-06-16) against the working tree on
`claude/modest-turing-bn7qoo`. Engine repo at `b313a0c`, flutter at `cf76557`.

> **Frame:** The prior `docs/archive/SIMULATOR_AUDIT_REPORT.md` (dated 2025-06-15, now archived) was
> captured while the engine **restore was failing** (`Missing 'current_state'`,
> the double-encode bug). That bug is fixed (rust-engine #267/#268; PROOF 1
> continuity is certified, `current_state=Recovered`, `obs=150`). So every
> "engine unavailable" verdict in that report is **stale** and must be
> re-derived under a *working* engine — which is what this matrix does.

---

## The two root causes (read this first)

Most of the "No data" surface collapses to **two independent root causes**.
Keeping them un-entangled is the whole point (per the brief's "trace, don't
conclude"):

### RC-1 — `write_assessment` is never called (GENUINE production break)
`biometrics.readiness_score` is written by exactly one method:
`VaultManager::write_assessment` (`mivalta-rust-engine/crates/gatc-vault/src/sync.rs:532`),
exposed at the FFI bridge (`gatc-ffi/src/lib.rs:1158`). It is the documented
**step 5** of the canonical ingest flow and, per `docs/DECISIONS.md:1273-1275`
(Q3 Atomicity), is meant to commit **as one unit** with `write_viterbi_state`.

**The entire Flutter repo has zero references to it** — not in the FRB shim
(`rust/src/api.rs`), not in `lib/rust_engine.dart`, not in the generated
bindings, not in `health_ingest.dart`, not in the seeder. `health_ingest.dart`
calls `writeViterbiState` (`:463`) but never the assessment half, so the
DECISIONS Q3 "one unit" intent is violated **at the edge**. Worse:
`processObservation` returns the freshly-computed `DailyAssessment` (which
carries the readiness score) and the call site **discards the return value**
(`health_ingest.dart:428`).

⇒ The per-day readiness score is **computed on every observation and thrown
away.** `read_readiness_history` filters `WHERE readiness_score IS NOT NULL`
(`sync.rs:2598`), so it is **permanently empty in production** — independent of
how much real data flows in. This is a Law-3/Law-4 defect (a value-producing
path drops the value; the UI then says "no data" while the data is being
generated). It is **not** a seeder artifact.

### RC-2 — the demo seeder is not the real ingest path (test-signal pollution)
`lib/debug/demo_seeder.dart` header (`:5-11`) claims it replays through "the
EXACT SAME ingest path a real watch/Oura sync uses." It does **not**. Real
ingest (`health_ingest.dart:404-439`) is:
`writeRawObservation → normalizeObservation → writeBiometric → processObservation → markRawObservationProcessed`.
The seeder (`demo_seeder.dart:134-150`) does only
`normalizeObservation → processObservation → saveState/writeViterbiState`,
**omitting `writeRawObservation`, `writeBiometric`, and
`markRawObservationProcessed`.**

⇒ Seeded data has **HMM observations but zero biometric rows.** So on seeded
data the source-tier swatch, the Journey HRV/RHR/Sleep cards, and the
`today_facts` sleep tile all show empty — **as artifacts of the seeder, not
production breaks.** This is debug-only (`kDebugMode`), so it is not a shipping
defect, but it systematically *understates* the production data surface and
risks mis-diagnosing seeder artifacts as engine breaks. The header's "EXACT
SAME ingest path" claim is itself inaccurate (a fidelity/doc defect).

These two are separable: fixing RC-2 (seeder calls `writeBiometric`) makes the
source tier populate **but the trend stays empty** until RC-1 is fixed
(`write_assessment` wired). That clean split is the Phase-2 confirmation lever.

---

## Matrix

| # | Panel (copy) | Consumer file:line | FFI / shim | Producer file:line | Gating threshold | Verdict |
|---|---|---|---|---|---|---|
| 1 | **"No history data available."** (readiness trend) | `lib/screens/readiness_detail_screen.dart:151` read → `:156` `readiness_score` → `:315`/`:599` empty → `:601`. Also home `lib/screens/readiness_screen.dart:545`, journey recovery sparkline `lib/screens/journey_screen.dart:192` | `lib/rust_engine.dart:300` → `lib/src/rust/api.dart:244` `readReadinessHistory` | `gatc-vault/src/sync.rs:2588` `read_readiness_history` — `SELECT … FROM biometrics WHERE readiness_score IS NOT NULL`. Writer = `sync.rs:532` `write_assessment` (FFI `lib.rs:1158`) | `readiness_score IS NOT NULL` (`sync.rs:2598`) — but **nothing ever writes that column** (RC-1) | **BROKEN** |
| 2 | **"Still learning your load"** (training-load tile) | `lib/widgets/today_facts.dart:88` `loadContextAvailable(dataStatus) ? trainingLoadLabel(acwrZone) : null` → null → `:115` (`kTrainingLoadLearningCopy`, `lib/copy/today_facts_labels.dart:45`) | engine `context_widget.data_status` / `acwr_zone` via `getContextWidget` (DashboardEngine) | underlying loads `gatc-vault/src/sync.rs:2708` `read_daily_loads` — `SELECT … SUM(load_uls) FROM activities`. Activities from `writeActivity` (`health_ingest.dart:588`) | engine-owned `data_status` (ACWR needs chronic load history, Lolli 2019). Seeder seeds no activities → genuinely insufficient | **HONEST-ABSENCE** (engine-gated; copy honest) |
| 3 | **"No data yet"** (source-tier swatch) | `lib/screens/readiness_detail_screen.dart:251`→`:252` `sourceTierFromEngine` → null → `:762`. Also home `readiness_screen.dart:585`→`:1455` | `lib/src/rust/api.dart:239` `lastObservationSourceTier` | `gatc-ffi/src/lib.rs:1283` → `read_latest_biometric` → `gatc_normalizer::data_quality::classify_source(bio.source)`; `None`→JSON `null` (`lib.rs:1292`). `source` written by `write_biometric` (`sync.rs:479`) | `latest.is_none()` → `null`. Production writes the row (`health_ingest.dart:423`); **seeder does not** (RC-2) | **VERIFIED** path; "No data yet" on seeded data is an **RC-2 seeder artifact** |
| 4 | **"Couldn't load your journey."** | `lib/screens/journey_screen.dart:160-272` `_fetch` wraps 6 engine reads in one try/catch → `:268` `d.error` → `:411`/`:418` (`kJourneyErrorCopy`) | `readBiometricHistory`, `readDailyLoads`, `readReadinessHistory`, `fitnessSeries`, `readRecentActivities`, `readMetricAcrossActivities` | n/a (catch-all) | `d.error != null` — any one read throwing. Each card already has its own honest empty copy, so a top-level error ≠ honest-absence — a read **threw** | **NEEDS LIVE DIAGNOSIS** — prior "engine unavailable" cause is gone (restore fixed); capture actual `e.toString()` in Phase 2 (item vi) |
| 5 | **Feel/psych axis provenance** (seeder) | `lib/debug/demo_seeder.dart:91-115` `_toHealthKitJson` emits only `resting_heart_rate`, `hrv_sdnn`, `oxygen_saturation`, `sleep_samples` | `normalizeObservation` → `processObservation` | fixture `assets/debug/demo_season.json` — **zero** subjective fields (grep for `mental_state`/`wellness`/`rpe`/`cycle_day`/`sick`/`mood` → none) | seeded obs carry **no** subjective input → Feel axis takes the observed/physiological path, never fabricated subjective | **VERIFIED** (honest provenance) |

---

## What this means for Phase 2 (Mac live run)

- **Trend (#1) will be empty even on real, non-seeded data.** This is the one
  row that a "fix the seeder" change will NOT cure — it isolates RC-1. The
  Phase-2 dump of `readReadinessHistory()` should come back `[]` regardless of
  observation count; that confirms BROKEN.
- **Source tier (#3) "No data yet" is the seeder, not the engine.** If Phase 2
  runs the *real* ingest (or a seeder fixed to call `writeBiometric`), the tier
  populates. Do not log this as an engine/FFI break.
- **Training load (#2) is correct as-is.** Leave the copy. Only revisit if
  Phase 2 shows `data_status` arriving `null`-by-omission rather than as an
  engine-decided "insufficient".
- **Journey (#4): capture the literal error string.** With restore fixed it may
  now load; if it still errors, the `e.toString()` names which of the 6 reads
  throws.

## Phase-3 shapes (HELD — surface to Bart before any edit)

These are **not** done here. They are the BROKEN-row remediation shapes, listed
so the matrix is the decision point:

1. **RC-1 (Trend):** bind `write_assessment` in the FRB shim (`rust/src/api.rs`)
   → FRB regen → call it from `health_ingest.dart` right after
   `processObservation` (using that call's returned `DailyAssessment`), ideally
   committed atomically with `writeViterbiState` per DECISIONS Q3. **This
   crosses the Dart↔Rust boundary** (shim change) → surface to Bart first per
   flutter CLAUDE.md scope discipline. No engine *math* changes — the value is
   already computed; it is purely persistence wiring.
2. **RC-2 (seeder fidelity):** make `demo_seeder.dart` mirror the real ingest
   (`writeRawObservation` + `writeBiometric` + `markRawObservationProcessed`),
   or correct its header claim. Debug-only; no production surface.
3. Held items **(b)** archetype-resolution `panic!` → typed catchable error and
   **(c)** FFI rejection of unknown `goal_type` remain unchanged and engine-side;
   surface before editing.

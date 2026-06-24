# AUDIT REPORT — MiValta Flutter, pre-update (2026-06-14)

**Target:** `main` ≡ `claude/flutter-frontend-049nbp` · engine pin `71b848b` · CI green on `11c5686`.
**Method:** falsification — each claim met an attempt to break it; every verdict carries `file:line` / log evidence.
**Status:** STATIC HALF COMPLETE (this seat). RUNTIME HALF PENDING (Mac seat — the runtime brief is folded in below under "RUNTIME HALF — brief + findings").

Verdict key: **HOLDS** (survived falsification) · **BROKEN** · **UNVERIFIED** (needs runtime/deeper read).
Severity: **BLOCKER** · **MAJOR** · **MINOR** · **INFO** · **OPEN** (decision pending).

---

## Findings

### [MAJOR] Engine logic in Dart — workout load is computed client-side
- **Claim audited:** "Dart is display-only; no math/thresholds (Rule 1)."
- **Break attempt:** traced the workout-ingest write path.
- **Evidence:** `lib/services/health_ingest.dart:598-603` — `loadJson = {'value': durationMinutes}`, comment: *"Conservative estimate: 1 ULS per minute … the engine should compute the real ULS."* A load estimate authored in Dart and passed to `recordActivity`.
- **Verdict:** BROKEN (Rule 1). The duration→ULS estimate is a coaching computation.
- **Action:** Move ULS derivation into the engine (engine computes load from duration + avg/max HR + profile, à la hrTSS). **Crosses the FFI boundary → surface to founder before editing `api.rs`/facade.** Until then it understates/!misstates training load for HR-only (non-power) workouts. Companion engine brief candidate.

### [MAJOR] Manual entry is missing illness / mental-VAS / cycle-day inputs
- **Claim audited:** manual entry covers the engine's subjective Bio1 inputs.
- **Break attempt:** grepped `manual_entry_screen.dart` for illness/sick/mental/vas/cycle.
- **Evidence:** zero matches. Present controllers: RHR, HRV(rmssd), sleep-hours, RPE only (`manual_entry_screen.dart:39-42`). The engine *supports* `cycle_day`, `sick`, `wellness`, `mental_state` (rust CLAUDE.md — Bio1 + M2 mental-disturbance emission), and these feed real HMM signals (Meeusen 2013 mood-disturbance as leading NFOR marker).
- **Verdict:** BROKEN as a surface gap (not a defect; honest absence today).
- **Action:** Add the optional inputs to manual entry, vault-first via `write_biometric` (no engine change — fields already exist). Pure-Dart, in-scope. Recommend as the next build item.

### [MINOR] Continuity wiring is in readiness_screen, not main.dart (doc drift)
- **Claim audited:** CLAUDE.md — "the app MUST call constructEnginesFromState … in main.dart."
- **Evidence:** continuity branch lives in `lib/screens/readiness_screen.dart:300-339` (persisted → `constructEnginesFromState`; else `constructEnginesFresh` + `writeViterbiState`). `main.dart` has none.
- **Verdict:** HOLDS functionally; doc is stale.
- **Action:** correct CLAUDE.md wording. (Runtime round-trip still to be confirmed on device — see brief §3.)

### [MINOR] Engine-pin doc drift
- **Evidence:** `rust/Cargo.toml:59,62` = `71b848b`; CLAUDE.md "Engine pin" + `NEXT_BUILD_BRIEF.md:11` say `b603b5e`. Cargo.toml is authoritative.
- **Action:** `docs:` sync both to `71b848b`.

### [MINOR] Branch hygiene — Mac built from a stale branch
- **Evidence:** Mac seat reported building `claude/coach-phase3plus-session-itfxxs` (the merged PR #76 branch). Canonical coding branch is `claude/flutter-frontend-049nbp` ≡ `main`.
- **Action:** Mac builds should `git pull` `main`.

### [INFO] FFI purity — spot-checked, not exhaustively read
- **Evidence:** `rust/src/api.rs` has 66 `pub fn` vs 48 literal `gatc_ffi::` occurrences. The delta is constructors (`construct_engines*`) and method-on-handle dispatch (e.g. engine objects held in the handle), not added logic — sampled fns are pure pass-through returning raw JSON.
- **Verdict:** HOLDS on sample; full per-fn read recommended.
- **Action:** one-pass per-fn purity read (cheap; can be done this seat).

### [OPEN] F.5 daily local notification
- **Evidence:** no `flutter_local_notifications` in `pubspec.yaml`. Brief says flag the dep before adding.
- **Action:** founder dep-approval decision.

### Workout-ingest residual TODOs (tied to MAJOR-1)
- `health_ingest.dart:540` idempotency is start-time-keyed (no local-storage de-dupe). `:596` hrTSS load pending. Track with the load-math fix.

---

## Claims that HELD (falsified, survived) — with evidence
| Rule / claim | Evidence | Verdict |
|---|---|---|
| No cloud egress (only weather channel) | grep `lib/`: no `http`/Dio/Socket clients; sole match is a doc-string in generated `api.freezed.dart` | HOLDS |
| Locked SourceTier tokens, no hardcoded hex | grep hex outside `lib/theme/` + generated → 0 matches | HOLDS |
| F1 copy verbatim, single-sourced | only definition `lib/copy/f1.dart:8` = "We need more data to predict recovery." | HOLDS |
| Josi presenter — no chat box / Q&A / TTS | all `TextField`/controllers are profile/biometric/settings forms (onboarding, manual entry, settings); none feed Josi; no TTS/audio dep | HOLDS |
| No engine-logic thresholds on engine values in Dart | grep readiness/zone/hrv/load `[<>]=? N` outside generated/tests → 0 matches (the load-math finding above is the lone exception) | HOLDS (1 exception) |
| `flutter analyze --fatal-infos` is a real CI gate | `.github/workflows/ci.yml:26` + `:29` `flutter test` | HOLDS |
| Vault-first biometric ingest order | `health_ingest.dart:410-435` raw→normalize→`writeBiometric`→`processObservation`→`markRawObservationProcessed` | HOLDS |
| Workout ingest wired end-to-end | `_ingestWorkout` `health_ingest.dart:524-607`: fetch→`mapWorkoutType`→VaultActivity→`writeActivity`→record; sync reports `workoutsProcessed` | HOLDS (load math = MAJOR above) |
| "Engine not connected" (Mac claim) | FALSE — `readiness_screen.dart:368` `readinessIndicator` + `:388` no-data from `last_observation_at==null`; engine bound, no data seeded | Mac claim REJECTED |
| ~355 tests | 355 test/testWidgets calls across 37 files | HOLDS (count only — quality pending §5 runtime sampling) |

---

## Static ship/don't-ship call
**No BLOCKERs.** One **MAJOR** that affects correctness (Dart-side load math → wrong training load for HR-only workouts) — this is the gate item and needs an engine-side fix decision. The manual-entry MAJOR is a missing surface, not a defect (honest absence holds). Everything else is minor/doc/open.

**Recommendation:** not ship-blocking *visually*, but **do not finalize the update until the load-math finding is dispositioned** (either fixed engine-side or explicitly accepted as placeholder for beta) AND the Mac runtime half confirms 4-state rendering + continuity round-trip on device.

---

## RUNTIME HALF — brief + findings (Mac seat)

> *Folded in 2026-06-20 from the former `AUDIT_BRIEF_UPDATE.md` (archived) so both
> halves of the one audit live in a single doc. This is the part that needs the iOS
> simulator: the Mac seat BUILDS, RUNS, OBSERVES, and APPENDS findings under
> "RUNTIME FINDINGS" below. Do not design, refactor, or edit feature code — if
> something looks broken, record it, don't fix.*

**Target (as briefed):** branch `claude/flutter-frontend-049nbp` (≡ `main`), engine
pin `71b848b`.

### Setup (run in order)
```bash
git checkout claude/flutter-frontend-049nbp && git pull origin claude/flutter-frontend-049nbp
scripts/build_ios_xcframework.sh        # REQUIRED — native engine; hot restart won't swap it
cd ios && pod install && cd ..
flutter pub get
flutter devices                         # find the booted simulator
flutter run -d "<booted iPhone simulator>"
```

### Posture
Falsification, not confirmation. A screen that looks right is a hypothesis until
you've reached its edge states. Capture a **screenshot per state** and drop the
file path into the report. Expected non-bugs to state up front so they aren't
mis-logged: WeatherKit fails on the sim (JWT) → honest absence (works on device);
HealthKit empty on sim → that's why the seeder exists.

### Runtime tasks (append results to "RUNTIME FINDINGS" below)

**R1. Engine-is-live proof** (falsify "no readiness without bindings")
1. Fresh launch (or after Delete Everything): Today should show the locked F1 copy
   "We need more data to predict recovery." Screenshot. ← honest no-data, engine bound.
2. Settings → Developer · Demo data → **Seed ~10 days**. Return to Today, pull-to-refresh.
3. Confirm a **real readiness number** renders (ring + value). Screenshot.
   - HOLDS if a number appears; BROKEN if it stays on F1 copy after a successful seed.

**R2. Continuity round-trip** (wiring lives in `readiness_screen.dart`, not main.dart)
1. With data seeded, note the readiness value.
2. Fully kill the app (not background) and relaunch.
3. Confirm: same readiness value, NO re-onboarding, no recompute-from-zero. Screenshot both.
   - BROKEN if state is lost or onboarding reappears.

**R3. Four-state coverage** (seed the full season to reach the hard states)
Settings → Developer · Demo data → **Seed full season (~30 days)**. For each screen —
**Today, Journey, You, Advisor, Readiness-detail** — capture whichever of these
states it can reach and screenshot each: **no-data** · **low-confidence** ·
**normal** · **red** (Overreached / IllnessRisk — the season drives toward this).
For each: honest absence where there's no data (never a fake number, never a crash)?
Source-tier badges using the right color token? Log any state you could NOT reach + why.

**R4. Test quality sample** (confirm concrete assertions, not smoke)
Run `flutter test`. Then open 3 of: `advisor_chips_test.dart`, `journey_screen_test.dart`,
`workout_ingest_test.dart`, `readiness_screen_test.dart`. For each, note whether it
asserts a **concrete value** or just "pumps without throwing." Flag smoke-only as MINOR.

**R5. Re-check the static MAJORs in the live app**
- **Workout load (MAJOR):** if you can seed/sync a workout, does the load shown look
  plausible or flat (the Dart placeholder = 1 ULS/min)? Screenshot the workout detail.
- **Manual entry (MAJOR):** open Manual entry — confirm illness/mental/cycle inputs are
  absent (expected) and the present inputs (RHR/HRV/sleep/RPE) write + persist.

### Output
Append to "RUNTIME FINDINGS" below: one block per task (R1–R5) with verdict +
screenshot path + any finding (severity). Commit with `docs: runtime audit findings
(Mac)`. Then hand back — the coding seat does the adversarial merge + final
ship/don't-ship call.

---

## RUNTIME FINDINGS (Mac seat appends below)
_(empty — pending the runtime-half tasks above)_

# AUDIT BRIEF (RUNTIME HALF) — Mac seat

**For the Mac Claude Code seat only.** The static/code half is done — see
`docs/AUDIT_REPORT_2026-06-14.md`. This brief is the part that needs the iOS
simulator. You BUILD, RUN, OBSERVE, and APPEND findings. Do **not** design,
refactor, or edit feature code. If something looks broken, record it — don't fix.

**Target:** branch `claude/flutter-frontend-049nbp` (≡ `main`), engine pin `71b848b`.

## Setup (run in order)
```bash
git checkout claude/flutter-frontend-049nbp && git pull origin claude/flutter-frontend-049nbp
scripts/build_ios_xcframework.sh        # REQUIRED — native engine; hot restart won't swap it
cd ios && pod install && cd ..
flutter pub get
flutter devices                         # find the booted simulator
flutter run -d "<booted iPhone simulator>"
```

## Posture
Falsification, not confirmation. A screen that looks right is a hypothesis until
you've reached its edge states. Capture a **screenshot per state** and drop the
file path into the report. Expected non-bugs to state up front so they aren't
mis-logged: WeatherKit fails on the sim (JWT) → honest absence (works on device);
HealthKit empty on sim → that's why the seeder exists.

## Tasks — append results to the "RUNTIME FINDINGS" section of `docs/AUDIT_REPORT_2026-06-14.md`

### R1. Engine-is-live proof (falsify "no readiness without bindings")
1. Fresh launch (or after Delete Everything): Today should show the locked F1 copy
   "We need more data to predict recovery." Screenshot. ← honest no-data, engine bound.
2. Settings → Developer · Demo data → **Seed ~10 days**. Return to Today, pull-to-refresh.
3. Confirm a **real readiness number** renders (ring + value). Screenshot.
   - HOLDS if a number appears; BROKEN if it stays on F1 copy after a successful seed.

### R2. Continuity round-trip (the wiring lives in `readiness_screen.dart`, not main.dart)
1. With data seeded, note the readiness value.
2. Fully kill the app (not background) and relaunch.
3. Confirm: same readiness value, NO re-onboarding, no recompute-from-zero. Screenshot both.
   - BROKEN if state is lost or onboarding reappears.

### R3. Four-state coverage (seed the full season to reach the hard states)
Settings → Developer · Demo data → **Seed full season (~30 days)**. For each screen —
**Today, Journey, You, Advisor, Readiness-detail** — capture whichever of these
states it can reach and screenshot each:
- **no-data** (before seeding) · **low-confidence** (early in season) ·
  **normal** · **red** (Overreached / IllnessRisk — the season drives toward this).
For each: honest absence where there's no data (never a fake number, never a crash)?
Source-tier badges using the right color token? Log any state you could NOT reach + why.

### R4. Test quality sample (confirm concrete assertions, not smoke)
Run `flutter test`. Then open 3 of: `advisor_chips_test.dart`, `journey_screen_test.dart`,
`workout_ingest_test.dart`, `readiness_screen_test.dart`. For each, note whether it
asserts a **concrete value** or just "pumps without throwing." Flag smoke-only as MINOR.

### R5. Re-check the static MAJORs in the live app
- **Workout load (MAJOR):** if you can seed/sync a workout, does the load shown look
  plausible or flat (the Dart placeholder = 1 ULS/min)? Screenshot the workout detail.
- **Manual entry (MAJOR):** open Manual entry — confirm illness/mental/cycle inputs are
  absent (expected) and the present inputs (RHR/HRV/sleep/RPE) write + persist.

## Output
Append to `docs/AUDIT_REPORT_2026-06-14.md` under "RUNTIME FINDINGS": one block per
task (R1–R5) with verdict + screenshot path + any finding (severity). Commit with
`docs: runtime audit findings (Mac)`. Then hand back — the coding seat does the
adversarial merge + final ship/don't-ship call.

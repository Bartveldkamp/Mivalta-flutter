# BUILD-REPORT — BS-016 Voice Surfaces V2

**Date:** 2026-07-06
**Branch:** `feature/bs016-voice-build`
**Spec:** `review/voice/BS-016-voice.md`

---

## Summary

Wired four Josi coach-voice FFI seams to their respective UI screens. The FFI
seams were already available in `rust_engine.dart` from the `3b5ec7c` engine pin.
This build completed the UI-side wiring.

| Surface | FFI Seam | Screen | Implementation |
|---------|----------|--------|----------------|
| S1 | `realizeWorkoutReflection` | Today | Post-workout reflection |
| S2 | `realizeAdvisorLine` | Today | Already wired (headline) |
| S3 | `realizeAdvisoryOffer` | Advisor | Offer line per option |
| S4 | `realizeDaySummary` | Journey | Day summary card |

---

## Build Log

### S1 — Post-Workout Reflection (Today)

**Files modified:**
- `lib/models/home_data.dart` — added `workoutReflection` field
- `lib/screens/today_screen.dart` — wired reflection loading + UI

**Implementation:**
1. Load recent activities via `readRecentActivities(limit: 5)`
2. Check if latest activity is from today
3. Call `realizeWorkoutReflection(activityId, date)` for today's activity
4. Parse `RealizedLine` and store in `HomeData.workoutReflection`
5. Render in "Recent workout" module card with coach quote styling

**RealizedLine fields used:**
- `text` — coach's one-line reaction (italic, quoted)
- `safety[]` — not rendered here (workout context, not advisory)

**Honest absence:** If no activity synced today, the module shows the activity
without a coach line. If activity lacks quality metrics, engine returns a
"logged, not judged" line — rendered verbatim.

---

### S3 — Advisory Offer Line (Advisor)

**Files modified:**
- `lib/screens/advisor_screen.dart` — wired offer lines + updated disclosure
- `lib/models/workout_option.dart` — added `toJson()` for serialization
- `lib/screens/today_screen.dart` — pass `readinessLevel` to Advisor

**Implementation:**
1. AdvisorScreen receives `readinessLevel` from Today
2. After options load, call `realizeAdvisoryOffer(optionJson, readinessLevel, date)` for each
3. Store `RealizedLine` per option ID in `_offerLines` map
4. Render offer line text below option title (italic, secondary color)
5. Use `why`/`purpose` from RealizedLine for disclosure tap content

**RealizedLine fields used:**
- `text` — Josi's offer framing in readiness-band register
- `why` — disclosure "why this workout" (feeds existing tap)
- `purpose` — disclosure "what it does" (feeds existing tap)

**Honest absence:** If `realizeAdvisoryOffer` fails for an option, that option
renders without an offer line. Disclosure falls back to `option.why`/`zonePurpose`.

---

### S4 — End-of-Day Summary (Journey)

**Files modified:**
- `lib/screens/journey_screen.dart` — wired day summary + UI card

**Implementation:**
1. In `_loadJourneyData`, call `realizeDaySummary(date)` for today
2. Parse `RealizedLine` and store in `_todaySummary`
3. Render "TODAY" section at top of Journey with day summary card
4. Coach line renders in card body (italic, secondary color)

**RealizedLine fields used:**
- `text` — Josi closes the day (rest/single/multi-session variants)
- `safety[]` — rendered if present

**Honest absence:** If `realizeDaySummary` fails, the TODAY section still renders
the observation day count but without a coach line.

---

## Contract Verification

### RealizedLine Model

```dart
class RealizedLine {
  final String text;
  final List<String> safety;
  final bool degraded;
  final String? degradeReason;
  final String? why;
  final String? purpose;
}
```

- `text` rendered **verbatim** — no paraphrase, no math in Dart
- `safety[]` items **always render** when present (firewall-validated)
- `degraded` lines render normally — degradation IS the truth
- `degradeReason` is telemetry, **never shown**

### Engine-Display Contract

All computation stays in Rust. Dart only:
- Parses JSON
- Maps to UI state
- Renders text verbatim

No thresholds, no fallbacks, no fabrication.

---

## Verification

```
flutter analyze → No issues found!
flutter test → 263 tests passed
```

---

## Files Changed

| File | Change |
|------|--------|
| `lib/models/home_data.dart` | +3 lines (workoutReflection field) |
| `lib/models/workout_option.dart` | +14 lines (toJson method) |
| `lib/screens/today_screen.dart` | +60 lines (S1 wiring + UI) |
| `lib/screens/advisor_screen.dart` | +55 lines (S3 wiring + UI) |
| `lib/screens/journey_screen.dart` | +35 lines (S4 wiring + UI) |

---

*Authored: 2026-07-06*

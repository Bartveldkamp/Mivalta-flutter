STATUS: DONE

# BS-016 — Josi Voice Surfaces (V6)

**Surface:** Voice (Today, Advisor, Journey)
**Spec-ID:** BS-016
**Date:** 2026-07-06
**Completed:** 2026-07-06
**Design ref:** `docs/briefs/DESIGN_BRIEF_2026-07-06_VOICE_AND_BACKUP.md` Part 1
**FFI ref:** `docs/mac/MAC_BRIEF_VOICE_WIRING_TRAIN.md` (pin `3b5ec7c`, FRB-regen done)

---

## Context

Four Josi coach-voice surfaces. Each returns a `RealizedLine` JSON:
`{ "text": "...", "safety": ["..."], "degraded": false, "degrade_reason": null, "why": "...", "purpose": "..." }`

The contract: **engine DECIDES, Flutter DISPLAYS** — `text` renders verbatim, no
paraphrase, no math, no thresholds in Dart.

---

## Surface Status

| Surface | FFI Seam | Status |
|---------|----------|--------|
| S1 | `realizeWorkoutReflection` | **DONE** — Today post-workout |
| S2 | `realizeAdvisorLine` | **DONE** — Today headline |
| S3 | `realizeAdvisoryOffer` | **DONE** — Advisor options |
| S4 | `realizeDaySummary` | **DONE** — Journey day view |

---

## Build Steps (ordered)

### Step 1 — S1 Post-Workout Reflection on Today

**Seam:** `realizeWorkoutReflection(handle, activityId, date)`

After any workout syncs to the vault, Josi has a one-line coach reaction. Display
in the "recent activity" module on Today for any activity synced TODAY.

**Implementation:**
- In Today's data-load path, after activities load, check for today's activities
- For each today activity, call `realizeWorkoutReflection(activityId, date)`
- Store the `RealizedLine` on the activity model (or in a parallel map)
- Render the `text` below the activity summary in the Today module
- Safety items render above/inline as per existing pattern

**Honest absence:** If activity has no quality metrics (HR decoupling etc), the
engine returns a "logged, not judged" line — render it, never fabricate a grade.

### Step 2 — S3 Advisory Offer Line on Advisor

**Seam:** `realizeAdvisoryOffer(handle, optionJson, readinessLevel, date)`

The Advisor screen's recommended workout gets a Josi offer line in the readiness
band's register. Plus the why/purpose disclosure fields ride on this line.

**Implementation:**
- In AdvisorScreen, after options load, call `realizeAdvisoryOffer` for EACH option
- Pass the option JSON verbatim (engine expects its own output back)
- Pass the readiness level from the indicator call
- Store the returned `RealizedLine` per option
- Render the `text` as the offer line above/below the option card
- `why`/`purpose` from the RealizedLine feed the disclosure tap (replace current
  `option.why`/`option.zonePurpose` with the engine's richer content)

**Red days:** If advisor returns no options, keep existing honest-absent state.

### Step 3 — S4 End-of-Day Summary on Journey

**Seam:** `realizeDaySummary(handle, date)`

Josi closes the day. Three shapes — rest / single-session / multi-session —
derived from the vault's real activity count.

**Implementation:**
- In JourneyScreen, when rendering a past day, call `realizeDaySummary(date)`
- Store the `RealizedLine` for that day
- Render the `text` as the day summary line in the day card
- Safety items render if present
- Rest day is content, not empty — "rest is training too" line is engine-owned

**Placement decision:** Day card footer in Journey. Optional: evening state of
Today (deferred — needs time-of-day logic).

---

## Locked Constraints (design-brief §Locked constraints)

- `text` renders verbatim. `safety[]` strings must ALWAYS render.
- `degraded: true` lines still render normally — the degrade IS the truth.
- `degrade_reason` is telemetry, NEVER shown.
- Josi is a PRESENTER: no chat box, no text input, no TTS.
- Lines rotate by calendar day, bit-identical within a day.
- F1 no-data copy unchanged.

---

## DoD Checklist

- [x] S1 Post-workout reflection on Today
- [x] S3 Advisory offer line + why/purpose disclosure
- [x] S4 Day summary on Journey
- [x] `flutter analyze` clean
- [x] `flutter test` green (263 tests)
- [x] BUILD-REPORT-voice-v2.md with seam outputs

---

*Authored: 2026-07-06*

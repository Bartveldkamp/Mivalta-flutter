STATUS: READY TO BUILD (2026-07-06) — seams LIVE on main (rust-engine #388, Flutter #153). Decisions D1–D9 final; build layout in §Build below.
Source brief: `docs/briefs/DESIGN_BRIEF_2026-07-06_VOICE_AND_BACKUP.md` Part 1 (removed in the 2026-07-15 docs cleanup; the decisions shipped — this file is kept only as the locked-copy record).
Seams verified against rust-engine `docs/frontend/FFI_API_CONTRACT.md` §7.1 / §4.2.

# BS-016-josi-voice — the four voice surfaces: design decisions + copy rules

All four surfaces render one `RealizedLine` {text, safety[], degraded, why,
purpose}. LOCKED (from the brief, restated as build law): `text` verbatim ·
`safety[]` always rendered, never restyled into invisibility · `degraded:true`
renders NORMALLY (no badge, no error styling; `degrade_reason` never shown) ·
Josi is a PRESENTER (no chat, no input, no TTS) · same-day lines are
bit-identical — cache per day, never across days.

## S1 — Post-workout reaction (`realize_workout_reflection`)

**D1 · Placement: BOTH, one source.** The line IS the Reveal's verdict (BS-011
§1 — the reveal's Josi line now comes from `realize_workout_reflection`, not a
separate composition), AND it persists on the workout detail view. A coach's
reaction isn't a toast that expires; the athlete re-reads it. Treatment:
JosiCard, top position, both places.

**D2 · No grade chip. Ruled now, early, as the brief asked.** The grade
(excellent…poor) stays voiced-only. A visual grade badge is a report card —
gamified judgment, the tone we've refused everywhere. No engine seam
requested. If a future need appears it goes through Bart as a new ruling.

**D3 · Honest absence is the same card.** The "logged, not judged" line
renders in the identical JosiCard treatment — no muted variant, no apology
styling. To Josi, "I can't judge this one" is a full sentence, not a
degraded state.

## S2 — State headline: already live, no change. (Noted for completeness.)

## S3 — Advisory offer + why/purpose disclosure (`realize_advisory_offer`)

**D4 · Offer line sits ABOVE the A/B/C options** as a JosiCard — Josi offers,
the options answer. It replaces any static "here are your options" header.
One line, readiness-band register, verbatim.

**D5 · Disclosure layout (the why-tap):** expands INLINE under the tapped
option (no modal — a disclosure is a lean-in, not an interruption). Two
short labeled blocks, engine text verbatim:
- eyebrow `WHY THIS` → `why`
- eyebrow `WHAT IT TRAINS` → `purpose`
`safety[]` lines render below both, always, MivaltaType.small, textSecondary
— present but never decorative. Collapse on second tap. One disclosure open
at a time.

**D6 · Red days: the offer line carries the day alone.** When the advisor
returns no options, render the Josi line + designed rest state — NO invented
fallback card, no grayed fake options. This is a THIRD advisor state,
distinct from day-zero absent (no data yet) — don't reuse that copy; the
engine's line is the content.

## S4 — End-of-day summary (`realize_day_summary`)

**D7 · Where it lives: Today's evening state + Journey day detail. NOT a
notification.** The morning read is MiValta's one notification — that promise
(BS-012, vision ruling) outranks a new moment. Josi closes the day on screen:
- Today, after the client-defined evening threshold (D8): a "closing the day"
  JosiCard replaces the advisor slot (the day's decision is over).
- Journey day view: the summary line persists as that day's record, all
  three shapes (rest / single / multi).

**D8 · "End of day" definition (client-owned, engine has no clock):**
evening = from 19:00 local, OR 30+ min after the day's last session ingest,
whichever comes first. Constant in one place, named, stated in the build
report. No user setting this pass.

**D9 · Rest day renders full-voice.** The rest line is content — same card,
same weight, deliberately zero numbers. Never an empty-state illustration.

## Build layout (added when the seams went live — branch `feature/bs016-voice-build`)

**B0 · One renderer, one presenter lock.** Build a single shared widget
`lib/widgets/josi_voice_card.dart` — `JosiVoiceCard(line: RealizedLine)`:
- Card: `surface1` bg · `cardBorder` hairline · `MivaltaRadii.lg` ·
  `MivaltaSpace.x4` padding · Josi avatar dot (26px, the existing gradient
  treatment) left, text right.
- Text: `line.text` VERBATIM — `MivaltaType.body`, `textSecondary`, height 1.55.
  No interpolation, no truncation, no case changes.
- Safety: every `line.safety[]` entry below the text, `MivaltaSpace.x2` gap,
  `MivaltaType.small`, `textSecondary` (NOT muted — always legible), no icon,
  no collapse, no "show more".
- `line.degraded == true` renders IDENTICALLY (assert in widget test: no
  branch on `degraded` reaches styling). `degradeReason` never rendered.
- Empty/null `text` ⇒ the card does not mount — callers show their existing
  absent state; never an empty shell.
All three surfaces use THIS widget — the presenter lock lives in one file.

**B1 · S1 reflection placement (per D1/D3):**
- Reveal screen: `JosiVoiceCard(realize_workout_reflection)` is position 2 —
  directly under the session header (duration/distance/source line), ABOVE
  time-in-zone. It REPLACES the reveal's current composed Josi line (one
  source; delete the old composition path).
- Workout detail view: same card, same position-2 slot. Same day = identical
  bits (the engine guarantees it; don't cache separately — call the seam).
- "Logged, not judged" absence line: same JosiVoiceCard, unchanged treatment.

**B2 · S3 offer + disclosure (per D4/D5/D6):**
- `JosiVoiceCard(realize_advisory_offer)` ABOVE the A/B/C option cards,
  `MivaltaSpace.x3` below the masthead; DELETE any static header text above
  the options.
- Disclosure: tapping "why?" on an option expands INLINE under that option
  (AnimatedSize, `MivaltaMotion.standard`): eyebrow `WHY THIS`
  (`MivaltaType.label`, tealSolid) → `line.why` · eyebrow `WHAT IT TRAINS` →
  `line.purpose`, both `MivaltaType.small`/`textSecondary`; `safety[]` below,
  same rule as B0. One open at a time; second tap collapses.
- Red day (engine returns no options): offer JosiVoiceCard + the designed
  rest state — distinct from day-zero absent; no fake/grayed options.

**B3 · S4 day summary (per D7/D8/D9):**
- Today: when `now >= 19:00 local || lastIngest + 30min` (whichever first —
  ONE named constant `kEveningThreshold`, stated in the build report), the
  advisor slot swaps to `JosiVoiceCard(realize_day_summary)` with eyebrow
  `CLOSING THE DAY` (`MivaltaType.label`, textMuted).
- Journey day view: the same summary line persists as that day's record —
  all three shapes (rest / single / multi) render through the same card.
- Rest-day line: full-voice, same card, zero numbers added by Dart.

**DoD:** shots s1-reveal / s1-detail / s3-offer / s3-disclosure / s3-red-day /
s4-today-evening / s4-journey-day + one seeded degraded line rendering
normally · widget test asserting degraded==normal styling · analyze/test
green · report line 1 = this spec + SHA.

## Voice-health note (engine V1.7): each surface records its line outcome via
`record_voice_event` — plumbing, not UI; no visible counter this pass.

## Build note
Flutter wiring is plain FRB-helper plumbing per the brief (no FRB regen).
Touchpoints: Today (S2 live, S4 evening state), Reveal + workout detail (S1),
Advisor (S3). Build AFTER the merge window closes; one branch
`feature/bs016-josi-voice`. DoD: shots of all four surfaces + the S3 red-day
state + one degraded line rendering normally (seed it), analyze/test green.

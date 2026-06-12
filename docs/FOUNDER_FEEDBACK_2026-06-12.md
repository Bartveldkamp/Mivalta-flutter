# Founder UI feedback — 2026-06-12 (first designed-home session, iOS sim)

Seven items, each routed to its layer. Display items are buildable now;
two need a founder decision (flagged). Engine items route to rust-engine.

## 1. No data → Viterbi status says NOTHING (display, small)
With insufficient data the home must not show a fatigue-state badge/status at
all — no "Recovered" from priors. Honest silence: F1 copy + ring placeholder
only. Fix: gate the state badge (and Josi's state line) on the same
`insufficientData` flag the ring uses. `readiness_screen.dart` + presenter.

## 2. Latest training: time/distance/load, tap → depth (display; DEPENDS ON INGEST)
Workout row shows duration · distance · load; tapping opens detail: averages,
max speed, power range, time per energy system, etc. Display side largely
exists (workout detail screen) but is STARVED — completed workouts never reach
the vault. `MAC_BRIEF_WORKOUT_INGEST.md` is the prerequisite; this item is the
design pass on top once data flows.

## 3. Weather on home, smooth/stylish (NEW — ⚠ FOUNDER DECISION NEEDED)
Tension with the locked "no cloud round-trips" rule: any weather API is a
network call. Privacy-compatible option: OS-level weather (Apple WeatherKit
on iOS; Android equivalent) — data fetched by the OS frame, not our servers.
Decide: (a) OS weather allowed as an explicit exception, (b) defer post-beta,
(c) drop. Do NOT build until decided.

## 4. "Why" must be a real explainer (engine prose quality)
The why-reveal should genuinely explain (which signals moved, what the session
targets) — not a generic line. Routes to rust-engine: card prose for
`rationale_prose` / `why` + the 4-axis contributions already exposed by
`readiness_indicator` (detail screen renders them; the why-tap should too).

## 5. Speak ENERGY SYSTEMS, not Z1/Z2 (⚠ CROSS-REPO — vocabulary decision)
User-facing language = the 6-system model (the advisor→GATC selector's energy
systems), with a tap-to-explain for each; zones stay in the depth layer for
power users. Touches: engine display strings/cards (zone → system labels),
session/advisor widgets, AND Josi's slot vocabulary (`{zone}` slot → system
label rendering — engine renders the display form into the slot value, same
pattern as `{state}` labels). Needs a small naming card (the 6 user-facing
system names + one-line explainers) as SoT in rust-engine knowledge cards —
founder should approve the 6 names before the regen.

## 6. Home: quick "start workout" link (display, small)
Short link/button on home → manual workout start / log-workout flow. Lands
with item 2's ingest wiring (starting a workout only matters once finishing
one persists).

## 7. Home: today's load next to the state (display, small-medium)
A cumulative today-load element beside the Viterbi state (the day's strain so
far, engine-computed — `daily_loads` already exposes the series; render
today's value). Zone-3 information promoted to a glanceable chip; no Dart math.

## 8. Advisor "click menu" — LOVED; load it with options (founder, same day)
The lead-with-A / offer-C layout is approved enthusiastically. Ask: richer
variety behind it — more alternatives under "More options", more expression
variety (terrain/indoor/intervals variants). Engine-side: the expression
catalog + history-aware rotation already exist; raise the offered-option
count/variants in the advisor response (rust-engine), UI scales as-is.
Keep the lead-with-A hierarchy LOCKED — variety lives behind the reveal,
never as a flat menu.

## Suggested order
1 (honest silence) → 7 (today-load chip) → 4 (why prose, engine) →
2+6 (after ingest lands) → 8 (engine option variety) →
5 (after naming card approved) → 3 (after decision).

## Round 2 — evening, on the redesigned 3-anchor home ("much better!!!!!")
9. Big green "+" FAB: remove/redesign — not nice, not useful (manual entry needs a calmer home).
10. Start workout: smaller/stylish, top-LEFT corner beside the centered MiValta title (title stays centered — liked).
11. Weather (next-gen form): one local-condition icon top-RIGHT (sun/cloud/rain); tap → 7-day forecast drops down. Wiring still pending the no-cloud decision (WeatherKit = the privacy-true path).
12. The 4 today-facts tiles become USER-CONFIGURABLE (user chooses which tiles show).
13. The "why" under the F1 line must EXPLAIN: what data is needed, how the model works, how it earns trust over the first weeks (calibration story, plain language, card-sourced).
14. Plan tab: rethink for beta — only MONITOR+ADVISORY exist, so "planning" is thin. Propose alternative content (e.g., week-in-review / recovery timeline) — founder decides naming/content.
15. Founder design doc to review: uploads/63315832-MiValta_UIUX_Design_North_Star_v1.0.docx — assess against canon next session.

## Founder decisions — evening close
16. **DARK STAYS — RESOLVED.** Dark-first remains locked canon, "like the logo."
    The North Star docx's "warm off-white surfaces" line is OVERRIDDEN; when
    converting the docx to docs/DESIGN_NORTH_STAR.md, replace it with the
    dark-first material language (editorial typography & calm authority KEEP).
17. Founder Figma reference (next session: review against canon — note prior
    finding: Okapion file predates no-chat beta scope):
    https://www.figma.com/design/mAiucTGUjP8bP1T2cAute0/MIV---Design
18. **WEATHERKIT — YES (founder).** Weather wiring approved via Apple
    WeatherKit (included in the Developer Program, 500k calls/mo): the
    privacy-compatible OS-level exception to the no-cloud rule — fetched by
    the OS frame, never MiValta servers; document the exception explicitly
    in CLAUDE.md rule 6 when wiring. Form per item 11: one condition icon
    top-right, tap → 7-day forecast. Android equivalent t.b.d. at wiring.
19. **Item 14 RESOLVED — Plan tab becomes "Journey" (founder).** Since beta is
    MONITOR+ADVISORY (no real planning), the 2nd anchor renders the athlete's
    JOURNEY per the North Star docx idea: the calibration/learning arc
    ("model learning you — day X of ~28"), baseline evolution, milestones,
    week-in-review — past+becoming, not future planning. Engine-grounded
    only; honest empty states; rename tab label accordingly.

## UPDATE ROUND 3 — scope (one clear round, founder 2026-06-12 evening)
Implement together, each with widget tests + 4-state screenshot notes:
items 9 (kill FAB) · 10 (Start workout top-left, title centered) ·
11+18 (WeatherKit icon top-right, tap=7-day) · 12 (user-configurable tiles) ·
13 (extended trust-story "why") · 19 (Plan→Journey). Dark-first (16) locked.

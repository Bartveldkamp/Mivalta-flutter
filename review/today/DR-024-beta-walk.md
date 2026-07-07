STATUS: OPEN — rolling beta-walk review (2026-07-06, walk started at Today).
# DR-024-beta-walk — findings from Bart's device walk

## WALK ROUND 2 (2026-07-07, fresh corridor) — open finds
- **W10 · Auth positioning + sizes** → ruling: `review/auth/BS-001b-auth-splash-sovereignty.md`
  ("One quiet account" is a positioning ERROR — sovereignty-first locked copy;
  logo 64 / wordmark 28; verify the logo asset is the MiValta mark, not a
  fingerprint glyph).
- **W14 · Sport step → "Your profile" (12:07)** → ruling
  `review/onboarding/BS-002c-profile-disclosure.md`: disclosure pattern
  (🔒 "How your private profile works" ▾), multi-select sports (engine
  contract check — no silent data drop), question lead "Let's start with
  your sports." Long framing sentence dropped; depth is opt-in.
- **W13 · Promise step (11:59)** → BS-002a updated with Bart's final copy:
  title duo'd with the logo (x5 gap, block moves up), "Private by design." +
  "Let's personalize MiValta to you." — architecture claim stays on Auth.
  Logo asset swap applies here too.
- **W12 · Auth flow sub-screens (email + code)** → BS-001b §flow-scale:
  64px mark on every auth screen, body ≥14, footer ≥12, code boxes 52px —
  and the fingerprint-style glyph confirms the wrong logo asset flow-wide.
- **W11 · Splash** → same file: logo 96, wordmark 32, x3 gap before
  "Your body. Your data.", hold ≥1.2s (currently flashes past).

Build witnessed: post-DR-023 (chip gone ✓, tokens applied ✓). New finds:

## W1 · Masthead is undersized relative to the layout (locked sizes)
Logo 22px + wordmark 19px reads as an afterthought next to a 74px hero.
**Locked:** logo **30px**, wordmark Zen Dots **24px**, gap 10px, row-2 spacing
unchanged. "Start workout" stays 13px/semibold (it's an action, not brand).
This ruling supersedes BS-002 variant-1b's sizes — record in the masthead
widget comment so it stops regressing. THIS IS THE 3RD SIZE REGRESSION —
add a golden/widget test asserting masthead logo ≥30 and wordmark style,
same tripwire pattern as the chip test.

## W2 · Weather — AMENDED 2: opt-in module, user's choice (final)
**Location source is the user's choice too (the research-validated pattern:
privacy by architecture — a forecast needs A place, not YOUR GPS):**
- **Default entry mode: manual place.** Turning the module on asks the user
  to type/search a town — NO location permission requested at all. This is
  the Yr/Hello-Weather pattern: nothing identifying leaves the phone, just
  a place name in a keyless forecast request.
- **Optional convenience: "Use my approximate location"** — only then the
  one-time coarse-location ask fires, in that context.
Weather is a **user-choosable module**, not a default fixture (this also
makes it the first concrete Make-It-Yours precedent — W3). Rules:
- **Default OFF.** The masthead slot ships empty; nothing asks for anything
  unless the user turns weather on (You → Display → "Show weather").
- The toggle's subtitle carries the honest line ("A forecast needs a place
  — type one, or use approximate location. Keyless request, never a
  commercial API; nothing else leaves the phone").
- Channel policy unchanged: WeatherKit through the OS first; Open-Meteo
  keyless fallback; commercial weather APIs banned.
- Pref: `show_weather` in SharedPreferences beside coach_presence — the
  first entry of the UserPreferences module registry.
- Denied/off ⇒ slot renders nothing (existing honest-absence behavior).

## W3 · Standing principle (not a defect): Today & Journey are user-composable
Module cards on Today/Journey are the user's choice (show/hide/reorder —
Make-It-Yours). Beta ships the default set; the module system lands
post-beta (BETA-001 cut line). Meanwhile: every new card MUST be built as a
ModuleCard (they all are today) so the composability layer bolts on without
rework. Don't hardcode order-dependent logic between cards.

## Night batch verification (Design, in source @ PR #165 / c85a314)
- **W5 round 2 ✓ CLOSED** — all three fixed exactly: `?? false` default OFF;
  toggle-on opens the place picker as the consent moment (dismiss keeps
  weather off — right); locked subtitle verbatim.
- **BS-016 B1 ✓ CLOSED (code)** — JosiCard position 2 on the reveal via
  `realize_workout_reflection`, honest fallback to the report line, D3
  respected. Note: reveal is its own screen, not a workout-detail view —
  "same card on detail" applies when a detail view exists (Journey day
  record, B3). Not a deviation.
- **REPO-SYNC ✓** — 5 files mirrored; future bridge outages non-blocking.
- **Deferred honestly, accepted:** B3 evening swap + Journey day record and
  the corridor You leg — both stay OPEN on this file, next batch.
- Reveal polish LOG (not blocking): zone-row labels render all-teal
  regardless of zone color (name uses stateRecovered, bar uses zone color —
  mismatch); "WHAT IT MEANS" renders the raw ACWR recommendation string —
  same V-ASK voice-register dependency as W7.

**Bart's morning sequence:** merge PR #165 → rebuild sim → witness: masthead
30/24 · vessel (calm/amber states) · model score ~53% · You bottom nav · You
restyle · tune sheet (weather OFF by default, picker on toggle-on) · reveal
Josi card. Then the walk continues: Advisor → Session → Journey.

## Merge policy (Bart, 2026-07-06): ONE batch PR per walk round
Merges cost ~45 min each — no more loose single-fix PRs. Collect all open
DR-024 work (W8 · W9 · W4 · W5, plus anything already sitting unmerged on
the dr-024 branch) onto ONE branch, one PR, one merge. Design verifies the
whole batch in source before Bart merges. Exception: a trust-critical
regression (like the Z2 leak) may still ship alone.

## Round 3 verification (Design, in source @ PR #162)
- **W1 ✓ CLOSED** — logo 30×30, wordmark Zen Dots 24, gap 10, size-assertion
  tests in. Verified in masthead.dart this time, not the report.
- **W6 ✓ CLOSED (code)** — LoadVessel is the ruling faithfully: capsule fill,
  meniscus, over-band never teal, quiet amber overspill bead, reduced-motion
  static, load-in-only animation. Witness on device for feel.
- **W7 Dart ✓** — `_stateFromZone` follows acwrZone. Engine ask logged as
  code TODO — ALSO log as V-ASK row in REVIEW-LOG next pass (per ruling).
- Still open: **W4** (You minimal restyle) · **W5** (tune button + sheet) ·
  W2 device witness · walk continues after merge.

## W8 · You screen has NO bottom nav — user is trapped
Witnessed (20:54): You renders without the Today/Journey/You tab bar; only
iOS home-swipe escapes. The tab bar is app chrome — it appears on ALL three
tabs, always. Fix: give YouScreen (and verify JourneyScreen) the same
bottom-nav the Today screen has — and extract ONE shared `MivaltaBottomNav`
widget so the three copies can't drift (same tripwire logic: a widget test
asserting all three tabs mount it).

## W9 · "Model score 5320%" — display math bug (trust-killer)
Witnessed on the Learning-you card. A percentage over 100 on a
calibration surface is instant credibility death. Cause (likely):
`overallModelScore` is already a percent (53.2) and you_screen multiplies
by 100 again. Fix: verify the unit against validation_report's contract,
display raw if already %, and CLAMP display to 0–100 with a debug assert if
the source exceeds 1.0/100. Also: Observations/Confidence show "—" while
sufficiency shows Medium — check those two reads while in there (same
diagnostics seam; — next to a real value smells like a parse miss, not
honest absence).

## W4 · You page — next-gen minimalistic restyle
The stacked icon+title card pile reads as settings-app, not MiValta. Ruling:
- Kill the per-card leading icons (the glyph noise is the clutter).
- Card titles → section EYEBROWS (MivaltaType.label, textMuted, uppercase)
  above flat row groups; hairline separators between rows, one surface —
  not a border-box per card.
- Rows: label left, value/chevron right, 44px min height, no subtitles
  unless consent-critical (weather line stays).
- The sovereignty banner stays the ONE colored moment on the page.
- Erase keeps its red treatment but drops the box-in-box look.

## W5 · Per-screen customize affordance (the Make-It-Yours entry)
Every composable screen (Today, Journey) carries its OWN customize button:
- Icon: `Icons.tune` (the sliders glyph — the known adjust symbol), 20px,
  textSecondary, far right of the masthead action row (weather sits left
  of it when on).
- Tap → bottom sheet "Make it yours · <screen>": beta contents = Show
  weather toggle (W2) + Words/Numbers first + the screen's module list
  with show/hide switches (reorder lands post-beta; build the sheet on the
  module registry from W2's `show_weather` pattern).
- You page gets NO tune button (it isn't composable; it IS the settings).

## W6 · Load card — the vessel (replace the flat bar)
Bart's ruling: load is a bucket that can spill — the flat MetricBar says
nothing. New treatment, same ModuleCard slot:
- A rounded **vessel** (capsule, ~56px tall, full card width) that FILLS
  with the day's load; the brim = the ACWR ceiling. Fill is a vertical
  gradient of the state teal; a subtle liquid meniscus curve at the top
  edge (CustomPainter, no package).
- **Within band:** calm teal fill, level well below brim.
- **Near brim (≥90%):** fill turns amber at the meniscus only.
- **Over (like today's 59/58):** the vessel shows a quiet overspill — fill
  reaches the brim, amber, with a small spill bead outside the rim. Calm,
  legible, never a red alarm; the picture says "full and spilling", the
  words stay the engine's.
- Number stays: "59 / 58" beside the vessel; caption unchanged.
- Reduced-motion: static levels, no animation. Animate fill on load-in
  only (600ms, decelerate) otherwise.

## W7 · Load caption: state/visual mismatch + out-of-register engine line
Witnessed: bar renders FULL TEAL (serene) while the caption reads "Load
spike detected - high injury risk, reduce immediately" — the visual says
calm, the words scream. Two fixes:
1. **Dart:** the vessel state (W6) must follow the ACWR zone — over-band
   can never render serene green. (Verbatim words law unchanged.)
2. **Engine ask (route to engine seat):** that recommendation string is out
   of the voice register ("high injury risk, reduce immediately" =
   alarm-speak; our vocabulary is steady: "Well above your usual — an easy
   day protects the week"). The words are engine-owned — they need the
   same card-voice pass the advisor lines got. Log as V-ASK in REVIEW-LOG.
- **W1 ✗ NOT DONE (round 2, verified in source @ branch):** masthead.dart was
  extracted but still carries logo 22 / wordmark 19 — the LOCKED 30/24 was
  never applied, and the widget tests apparently assert the old values.
  Apply the sizes; the test must assert logo width ≥ 30 and wordmark
  fontSize ≥ 24 (the tripwire is worthless if it pins the defect).
- **W2 ✓ model verified** — default none/honest-absence ✓, manual place ✓,
  GPS opt-in ✓, on-device city list (no-cloud geocoding — right call).
  Accepted for beta with two logs: (a) the 50-city list misses athlete
  towns — expand or ship an offline geocode DB post-beta; (b) Design still
  owes verification of the You toggle default-OFF + consent subtitle and
  the iOS getWeatherAt — next read.

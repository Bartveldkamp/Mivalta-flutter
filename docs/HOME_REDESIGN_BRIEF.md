# HOME REDESIGN BRIEF — founder directive 2026-06-12

Status: ACTIVE — supersedes the current single-screen three-zone home.
Implementation is stepwise; each step lands with widget tests and is pushed
before the next begins. This document is the contract for every step.

---

## 1. Founder directive (verbatim)

> Navigation: three anchors — Today / Plan / You. Plan = honest placeholder
> this round; You = settings+trends+privacy regrouped.
>
> Today screen, top to bottom: Josi's one-line verdict (small card). State
> element sized by data sufficiency — small ring while learning ("why"
> explains: "I'm still learning you — day X"), full hero only when confident.
> Then today-facts tiles: sleep last night, training load, today's load — in
> plain human words/numbers ONLY (read the engine's actual dashboard/context
> payloads and map every field to user language; raw enums like
> insufficient_data, ACWR ratios, monotony values are FORBIDDEN on this
> screen — depth lives in Explore). Then today's session card OR small
> "learning you" line. Then Start workout button = sensor check → optional
> GPS map → minimal live screen (stage live screen as follow-up if needed).
>
> Hard rules: no raw engine identifier ever user-visible; verdict→reasons→data
> on every surface; screenshot-describe all 4 states
> (no-data/low-confidence/normal/red) before each commit.
>
> Weather tile: stub a slot, don't wire (decision pending).

---

## 2. Architecture constraints (unchanged, CLAUDE.md)

- The engine DECIDES, Dart DISPLAYS. No thresholds, math, or fallback logic
  in Dart. Human-language mapping is a **label layer** (same pattern as
  `humanizeAxisName` / `readinessLevelColor`): engine value in → fixed copy
  out. Counting rows the engine returned and formatting numbers/dates is
  presentation; deriving meaning from values is not.
- Tokens-only styling. F1 copy locked verbatim. New behaviour needs a widget
  test with concrete-value assertions. Every public symbol has a production
  call site within the PR.

---

## 3. Navigation — Today / Plan / You

Material 3 `NavigationBar`, three destinations, state preserved per tab
(`IndexedStack`). Existing detail screens keep their push routes.

| Anchor | Content | Notes |
|---|---|---|
| **Today** | The redesigned home (this brief §4) | Default tab |
| **Plan** | Honest placeholder this round | No fake roadmap, no fabricated calendar. Calm copy: what Plan will become + what the engine needs first. No raw enums. |
| **You** | Settings + trends + privacy, regrouped | Entry hub: Profile & settings (→ SettingsScreen), Trends & history (→ ExploreScreen), Privacy & data (→ export vault / delete everything, surfaced from settings). |

The app bar's settings/trends/debug actions migrate into **You**; Today's app
bar slims down.

## 4. Today screen — top to bottom

1. **Josi's one-line verdict** — small card, one spoken line (engine
   `state_recommendation` verbatim, or locked F1 copy on no-data). "Why?"
   reveal keeps verdict→reasons→data ordering. Josi remains the ONE home
   surface for the F1 copy and the confidence advisory.
2. **State element, sized by data sufficiency**:
   - *Learning* (engine still calibrating): **small ring** (~120dp), muted
     presentation; its "why" explains: **"I'm still learning you — day X."**
   - *Confident*: **full hero ring** (220dp) with score/level/confidence.
   - Sizing gate = engine signals only: `insufficientData`
     (`advisories.last_observation_at == null`) OR a non-empty
     `confidence_advisory` from the state widget ⇒ learning. No Dart
     threshold on the confidence scalar.
   - **Day X** = count of days with observations the engine returns
     (`readBiometricHistory` rows). Counting rows is presentation. ENGINE
     GAP flagged (§7): an explicit `observation_days` field is the clean fix.
3. **Today-facts tiles** — plain human words/numbers ONLY (§5):
   - Sleep last night
   - Training load (week context)
   - Today's load
   - **Weather: stub slot only** — reserved tile, "coming soon" muted, no
     wiring (decision pending).
4. **Today's session card** (engine session widget, verbatim values) OR the
   small **"learning you"** line when insufficient data (no prescriptions
   from priors — 2026-06-12 no-data rules stay in force).
5. **Start workout button** → sensor check → optional GPS map → minimal live
   screen. Staged (§6, step 4): sensor-check entry lands first; live screen
   is a follow-up. No fabricated sensor states — honest "not connected".

## 5. Human-language mapping (today-facts layer)

Source payloads (verified against `lib/src/rust/api.dart` consumers,
2026-06-12): `readBiometricHistory` (`sleep_hours`, `resting_hr`,
`hrv_rmssd`), `readDailyLoads` (`[date, load]` rows), `getContextWidget`
(`acwr`, `acwr_zone`, `acwr_recommendation`, `monotony`, `monotony_zone`,
`monotony_recommendation`, `strain`, `last_workout`, `reactive_alerts`,
`pattern_advisories`, `data_status`), `getStateWidget`
(`state_recommendation`, `confidence_advisory`), `getSessionWidget`
(`workout_title`, `duration_min`, `zone`, `target_watts`, `target_pace_mss`,
`focus_cue`, `rationale_prose`), `readinessIndicator` (`score`, `level`,
`confidence`, `contributions`).

**FORBIDDEN user-visible on Today** (depth lives in Explore): raw enum/zone
strings (`insufficient_data`, `ok`, `optimal`, snake_case anything), ACWR
ratios, monotony/strain scalars, ULS units, field names, tier strings.

| Tile | Engine source | Human rendering | Empty/learning rendering |
|---|---|---|---|
| Sleep last night | latest `sleep_hours` for last night's date | "7.5 h sleep" + label "Last night" | "No sleep data yet" |
| Training load | `acwr_zone` → fixed label map (e.g. building / steady / high / easy week); engine's `acwr_recommendation` prose available in tap-through | "Training load: steady" | "Still learning your load" (when engine `data_status` ≠ ok / zone is the insufficient marker) |
| Today's load | today's `readDailyLoads` row | "Today: 156 load" → phrased "Trained today" / "Nothing logged yet" + number when present | "Nothing logged yet" |
| Weather (stub) | — none — | reserved slot, muted "Weather — soon" | same |

Every mapping is a fixed dictionary keyed on engine-provided strings; unknown
engine values fall back to silence (omit tile), never to the raw string.
The full zone-string → label dictionaries live in `lib/copy/` next to
`axis_labels.dart` so reviews can diff copy without touching widgets.

## 6. Implementation steps (each: widget tests → analyze/test → 4-state notes → commit → push)

| Step | Scope | Key files |
|---|---|---|
| 0 | This brief | `docs/HOME_REDESIGN_BRIEF.md` |
| 1 | Nav shell: Today/Plan/You `NavigationBar`; Plan placeholder screen; You hub regrouping settings/trends/privacy entries; app-bar slimdown | `lib/main.dart`, `lib/screens/app_shell.dart`, `lib/screens/plan_screen.dart`, `lib/screens/you_screen.dart` |
| 2 | Today: Josi one-line verdict card + adaptive state element (small learning ring w/ "day X" why, full hero when confident) | `lib/widgets/josi_presenter.dart`, `lib/widgets/readiness_ring.dart`, `lib/screens/readiness_screen.dart` |
| 3 | Today-facts tiles + human-language dictionaries + weather stub slot | `lib/copy/today_facts_labels.dart`, `lib/widgets/today_facts.dart`, `lib/screens/readiness_screen.dart` |
| 4 | Start workout entry: sensor-check screen (honest states), optional GPS map + minimal live screen staged as follow-up | `lib/screens/sensor_check_screen.dart` (+ follow-up) |

## 7. Open items / flags

- **ENGINE GAP — observation day count**: no `observation_days` field today;
  Day X is derived by counting engine-returned observation rows
  (display-only). Brief Hetzner/engine to expose it explicitly.
- **ENGINE BUG (item 8 scope)**: viterbi persisted-state restore fails every
  launch (`Missing 'current_state'`) — saveState→restore round-trip broken
  engine-side. Tracked separately.
- **Weather**: slot stubbed, provider/wiring decision pending (founder).
- **Live workout screen**: staged follow-up after sensor-check entry lands.
- **Plan tab**: placeholder copy flagged for founder review before lock.
- "I'm still learning you — day X." copy flagged for founder review.

## 8. Four-state matrix (screenshot-describe before each commit)

States: **no-data** (zero observations) / **low-confidence** (data present,
engine still calibrating) / **normal** (confident, green-ish) / **red**
(confident, red level). Each step's commit message links or describes all
four. Simulator screenshots capture whichever states are reachable with
on-device data; the rest are described from the widget-test seeds (the test
file pumps all four with engine-shaped values).

## 9. Sport-science display rules (founder-adopted 2026-06-12)

- **Deviation-first, always**: every signal renders as deviation from the
  athlete's own band ("sleep 1.2h under your norm"), never a raw absolute
  first — raw numbers are the third tap. The engine already provides
  baselines; display maps to them.
- **Every screen = glance / decision / capture zones** (top: <1s read ·
  middle: what to do · bottom thumb-zone: give data back).
- **Morning capture BEFORE verdict reveal**: the 4-slider wellness swipe
  (fatigue/soreness/sleep/mood, 5 seconds) comes first; the state reveals
  after — never bias the self-report. This is the morning flow's sequencing
  law.
- **Why-panel ordered by evidence weight**: wellness deviation → HRV trend
  inside the personal band (line-in-band, not a score) → resting HR → 72h
  load residue; honest band-width note while calibrating.
- **Post-session sRPE prompt within ~30 minutes**, not at bedtime.
- **You-screen risk = two slow diverging lines** (load trend vs
  recovery-capacity trend), no red badges.

---

## 8. Sport-science display rules (founder-adopted 2026-06-12)

1. **Deviation-first, always**: every signal renders vs the athlete's OWN
   band ("sleep 1.2h under your norm"); raw absolutes are the third tap.
2. **Every screen = glance / decision / capture zones** (top <1s read ·
   middle: what to do · bottom thumb-zone: give data back).
3. **Morning capture BEFORE verdict reveal**: the 4-slider wellness swipe
   (fatigue/soreness/sleep/mood, ~5s) comes first; state reveals after —
   never bias the self-report.
4. **Why-panel ordered by evidence weight**: wellness deviation → HRV trend
   inside the personal band (line-in-band, not a score) → resting HR → 72h
   load residue; honest band-width note while calibrating.
5. **Post-session sRPE prompt within ~30 minutes**, not at bedtime.
6. **You-screen risk = two slow diverging lines** (load vs recovery-capacity
   trend); no red badges.
7. **No naked numbers — visual + number, one-second meaning (founder).**
   Every number ships with an instant-read visual (band position, gauge,
   spark, fill) so meaning lands in <1s without reading. Less is more:
   fewer elements, each carrying more meaning. A value the user must
   interpret unaided is a design bug.

# Design Build Spec — MiValta MVP (the screens to design)

**Purpose.** The bridge from `UI_UX_DIRECTION.md` (the *direction* — philosophy,
tone, material language, locked tokens) to **"design exactly this screen, showing
exactly this real data."** For **Okapion** (visual design) and **Apadmi** (build).
This is what makes a designer fast and on-direction instead of guessing at content.

> **Read alongside:** `UI_UX_DIRECTION.md` (parent direction, in mivalta-rust-engine)
> · `docs/frontend/DATA_CATALOG.md` + `FFI_API_CONTRACT.md` (the real engine output
> each element renders) · `READING_ORDER.md` (this repo). **The engine DECIDES,
> the app DISPLAYS** — every number/label/zone on every screen is engine output,
> rendered verbatim. The designer designs the *frame*; the engine fills it.

**Scope: MONITOR + ADVISOR.** No conversational/chat surface in the MVP (Josi is a
later phase). COACH (multi-day plans) is deferred.

---

## ★ Design north star — a next-generation "training buddy," not a dashboard

This is the single principle that should override the look of every typical
training app, and it's the differentiator:

> **MiValta feels like an intuitive health/training *buddy* — calm by default,
> with all the depth there but revealed only when the user chooses to go deeper.**

- **Lead with what matters *now*.** The home is the buddy's read: one clear
  readiness (today), one clear suggestion (today's session), one calm line of
  context. Not a wall of graphs. The athlete should *glance* and know.
- **Progressive disclosure — every number is available, none is in your face.**
  The engine can produce a huge amount (full analytics, the 4-axis "why",
  biometric history, power curves, trends, load math). **All of it is reachable —
  one tap deeper, never on the front.** The home is the buddy; the depth is a
  drawer (the *Explore* / *detail* screens) the user *opens on purpose*. This is
  the opposite of the screen-and-graph overload of typical training apps, and it's
  the point of difference.
- **Honest, never alarming.** The quiet state is the product working; confidence
  is always visible ("still learning you" early on); the athlete can always go
  deeper or override. Color carries urgency; the numbers stay calm.

Every layout decision below should be tested against one question: *does this feel
like a buddy telling me what I need, or like a dashboard dumping data at me?* If
it's the latter, push the data one layer deeper.

---

## ★ Josi's role — PRESENTER, not a chat box (LOCKED, founder 2026-06-12)

The single most-repeated and most-misread point. Build to this exactly:

- **Josi is a PRESENTER (autocue).** She *reads out and emphasises what's
  happening* — today's readiness, today's session, one line of context — in a
  warm coach voice. "Voice" is a tone, not audio: **Josi renders as on-screen
  text; there is NO TTS/audio layer in the beta.** She is the face/voice of
  the home.
- **There is NO chat box. No text input. No open Q&A. No conversation.** This is
  non-negotiable for beta. (Open conversation was the entire trap the model work
  fell into.) The user does not "talk to" Josi.
- **The user's only interactions are:** progressive disclosure — a "why?" tap
  that *reveals more of the engine's own prose* — and, on the **Advisor** screen,
  **choosing among the engine's suggested workouts** (lead-with-A, offer-C).
  Choosing, never chatting.
- **Open/coaching conversation is COACH tier (Tier 3) — out of beta scope.**
- **The engine + vault are the brains and the memory.** They learn the athlete
  over time; Josi only presents what they know. She computes nothing, remembers
  nothing herself, and therefore cannot fabricate. Every word she speaks is
  engine output rendered verbatim or an engine value she sequences.

Implemented in beta as `lib/widgets/josi_presenter.dart` (home-screen autocue
over the existing grounded widgets — no model, no new engine plumbing).

---

## 0. The three "scores" — resolve the headline question first

The app surfaces **three distinct numbers**, each with a different job and home.
Designing them as one blob is the #1 way to get this wrong:

| Score | Question it answers | Range | Home | Treatment |
|---|---|---|---|---|
| **Readiness** | "How ready am I to train *today*?" | 0–100 + level (green/yellow/orange/red) | **Home screen HERO** | The big number in the ring. **Number-as-hero** (founder decision). |
| **Training load / ACWR / strain** | "Am I ramping safely / training too samey?" | ACWR ratio + monotony + strain | Home Zone 3 (context) + Explore | Gauges/stat tiles, secondary to readiness. |
| **Fitness trend** (Banister) | "Is my fitness rising over the season?" | fitness/fatigue/form trend | Explore (chart) | A longitudinal line chart, not a headline number. |

There is **no single "training score."** Readiness is *today*; load/ACWR is
*this week's stress*; fitness trend is *the season arc*. Keep them visually and
spatially distinct.

---

## 1. Locked constraints (non-negotiable — design within these)

- **Dark-first.** The default and primary theme.
- **Source-tier color tokens (exact hex):** Medical `#2BD974` · Device `#00C6A7`
  · Partial `#E6872F` · Manual `#878C8C`. These encode *data quality* — never
  repurpose them for other meaning.
- **F1 no-data copy, verbatim:** "We need more data to predict recovery."
- **Calm · Honest · Agency** (UI_UX §1): the quiet state is the product working,
  not emptiness; confidence is always visible; the athlete can always override.
- **Readiness = number-as-hero.** The 0–100 is the largest element on the home.
- **Advisor = lead-with-A.** Emphasize option A (the recommended session); offer C
  as the easy fallback; de-emphasize B. Not a flat equal-weight menu.
- **Verdict → reasons → data (A4, locked).** Every explanatory surface orders:
  the engine's verdict prose first, then the *reasons* (the 4-axis
  `contributions[]`, card-sourced meaning), then raw data (trends, stats) — raw
  data last and usually behind a tap, **never first**. Applied today: Josi's
  why-reveal (rationale → axis bars → confidence note), the readiness detail
  screen (hero → axis breakdown → biometric trends), and the post-workout
  report (quality verdict → what it built → collapsible stats).
- **Rest is content, not absence (A2).** A rest/recovery prescription renders as
  a full styled card with the same prominence as a workout — rest-specific
  presentation (recovery icon, recovered-state accent), never an empty state.
- **Every screen handles four "off-happy-path" states** (§4) — designers forget
  these; the engine produces them constantly early on.

---

## 2. Screen inventory (7 product screens)

Verified against the live app (`lib/screens/`). The functional versions exist and
are engine-wired; **this spec is the *design* pass on top.**

| # | Screen | Purpose | Hero element | Primary engine source |
|---|---|---|---|---|
| 1 | **Onboarding** | Capture the athlete profile; set expectations honestly | "Let's learn your physiology" | `get_vocabularies` (dropdowns), `build_onboarding_profile` |
| 2 | **Readiness (home)** | The daily glance: state · today's session · context | **Readiness ring (0–100)** | `readiness_indicator`, `get_state/session/context_widget` |
| 3 | **Readiness detail** | The "why" behind the score | The 4-axis breakdown | `readiness_indicator.contributions[]`, biometric history |
| 4 | **Advisor** | Today's workout options + post-workout feedback | **Option A card (lead)** | `recommend_workout_with_history`, `build_post_workout_report` |
| 5 | **Explore** | Analytics: load, power, fitness trend | The chart in view | `get_acwr`, `read_mmp_history`, `fit_cp`, `fitness_series`, decoupling |
| 6 | **Manual entry** | Supply data when no wearable synced | The input being entered | `process_manual_observation` |
| 7 | **Settings** | Profile · data sources · privacy · export/delete | — | `update_profile`, `build_source_overview`, pause-learning, export/erase |

---

## 3. Per-screen design briefs

### 2 · Readiness (home) — the three-zone PULL  ⭐ the screen that defines the product

The signature screen. Three vertical zones, scrolled/pulled, calm and dark.

```
┌─────────────────────────────────────┐
│  Tue 12 Jun            ● Device      │  ← date + source-tier dot (locked color)
│                                      │
│            ╭───────────╮             │
│            │           │             │  ZONE 1 — STATE (hero)
│            │    78      │  GREEN      │  • readiness ring: number-as-hero (0–100)
│            │  ───────   │             │  • ring color = level (green/yellow/orange/red)
│            │ Productive │             │  • state label below the number
│            ╰───────────╯             │  • thin confidence sub-arc / chip
│      "Adapting well to the week."    │  • one-line card-sourced prose (verbatim)
│                                      │
├─────────────────────────────────────┤
│  TODAY                               │  ZONE 2 — SESSION
│  Sweet-spot intervals · 50 min · Z4  │  • workout_title / duration / zone / target
│  3×12 min @ 215–235 W                │  • focus cue + rationale (verbatim)
│  "Up to Z5"   [ See options › ]      │  • zone-cap chip (engine permission)
│                                      │
├─────────────────────────────────────┤
│  CONTEXT                             │  ZONE 3 — LOAD/CONTEXT
│  ACWR 1.32  ▮▮▮▯ caution             │  • ACWR gauge w/ 4 bands + recommendation
│  Monotony 1.8 · Strain 4200          │  • monotony / strain tiles
│  ⚠ Watch for: HRV below baseline     │  • reactive_alerts / pattern_advisories (list)
│  Readiness ╱╲╱‾╲ (14d)               │  • 14-day readiness sparkline
└─────────────────────────────────────┘
```

Design intent (UI_UX §1): the hero ring should feel *calm*, not alarming — the
number is information, not a verdict. Color carries the urgency; the number stays
quiet. Zone 3 is "glanceable context," never a wall of stats.

### 3 · Readiness detail — the "why"

Reached by tapping the ring. The honesty layer.

- **The 4 axes** (`contributions[]`): *Fatigue model · Fitness & freshness · Body
  signals · How you feel* — four small bars showing how each pulled the score up/
  down (rename the raw keys per the data catalog; never show `hmm_posteriors`).
- **Biometric trends:** HRV / RHR / sleep over time, each against its personal
  baseline band (`read_biometric_history`).
- **"Still learning you"** progress when data is thin (`validation_report`).
- **Confidence** explained in plain words, not a decimal.

### 4 · Advisor — lead-with-A + post-workout

Two stacked sections:

```
┌─────────────────────────────────────┐
│  POST-WORKOUT (if a recent activity) │  • RPE-first: "You called it a 7 —
│  "Tempo ride · what it built…"       │    your HR says controlled. Fitness
│  (card-grounded report, verbatim)    │    is climbing." (build_post_workout_report)
├─────────────────────────────────────┤
│  TODAY'S SESSION                     │
│  ╔═════════════════════════════════╗ │  ← OPTION A — emphasized (lead)
│  ║ A · Sweet-spot intervals  ★    ║ │  • largest card; "recommended"
│  ║ 50 min · Z4 · 3×12 @ 215–235W   ║ │  • title/zone/duration/targets/why/expression
│  ║ "A clean stimulus while fresh." ║ │
│  ╚═════════════════════════════════╝ │
│  ─ or take it easy ─                 │
│  C · Easy aerobic spin · 45 min · Z2 │  ← OPTION C — the easy fallback (smaller)
│  (B available behind "more options") │  ← OPTION B — de-emphasized/hidden
└─────────────────────────────────────┘
```

At **red readiness** the engine caps options to easy/rest — present honestly
("today's the body's call"), never upsell. Mood/equipment/terrain pickers feed
the engine; they don't compute anything client-side.

### 5 · Explore — analytics

Tabbed or scrolled chart cards (all data engine-computed):
- **Load:** acute/chronic load + daily strain series.
- **Power (cycling):** MMP power-duration curve (log-x); CP + W′ headline numbers.
- **Fitness trend:** Banister fitness/fatigue/form season line (`fitness_series`).
- **Decoupling / EF:** per-workout aerobic drift trend.
- Running shows pace/decoupling; **no power curve** (honest — it doesn't exist for
  running yet).

### 1 · Onboarding, 6 · Manual entry, 7 · Settings

- **Onboarding:** profile capture (age/sex/level/sport/goal/hours + optional
  threshold HR/FTP/pace). Honest tone: "we're learning your physiology — the first
  ~28 days lean on population averages." Dropdowns from `get_vocabularies`.
- **Manual entry:** today's inputs when no wearable. Currently 4 fields (RHR/HRV/
  sleep/RPE). **Design should add** the engine-supported optional inputs that have
  no surface yet: **illness flag** (safety gate!), mental-state VAS, cycle day,
  wellness — small, optional, honest.
- **Settings:** profile edit · **data sources** (each with its locked tier badge)
  · **privacy** (the pause-learning toggle — to be built) · encrypted export ·
  delete-everything (with the receipt).

---

## 4. The four states EVERY screen must design for

The engine produces these constantly, especially in the first weeks. Designing
only the happy path is the classic miss:

1. **No data** — show the locked F1 copy; no fabricated score; a "log a few days"
   placeholder, calm not error-y.
2. **Low confidence / "still learning you"** — show the score but muted, with the
   honest "day 12 of ~28, learning your baselines" banner.
3. **Illness / red readiness** — render the state honestly; the session collapses
   to rest; no upsell.
4. **Error / paused learning** — a calm notice, never a blank or a crash.

---

## 5. What's already wired vs. what design unlocks

The functional app already renders all of the above from real engine output (the
wiring audit confirmed it). Design is **styling + hierarchy + graphics + states**,
not new plumbing — with three known build gaps the design should account for:
**workout ingestion** (so charts/post-workout fill — Mac brief), the **advisor
lead-A** restyle, and the **manual-entry optional inputs** (sick flag etc.).

## 7. Platform surfaces — iOS & Android (ambient / post-MVP)

> *Folded in 2026-06-20 from the former `UI_UX_DESIGN_IOS_ANDROID.md` (archived).
> This is the **platform** layer — how the calm-PULL, ambient-first design is built
> on each OS, and which parts are one shared Flutter codebase vs. a small native
> surface. Reconciles to `UI_UX_DIRECTION.md` §17 (rust-engine, v1.5 — "Material &
> Ambient Direction"); where direction and this disagree, the direction wins. The
> ambient surfaces below are **post-MVP** (the §17 north star), captured here so the
> in-app MVP spec above and the platform plan live in one place.*

Principle (every surface obeys it): **the Rust engine DECIDES/COMPUTES, the FFI
PASSES THROUGH, Flutter DISPLAYS.** No thresholds, math, or fabrication in Dart.
Ambient surfaces (widgets, Live Activities, tiles) render the engine's *persisted*
state — they never recompute it.

Marker convention: `[LOCKED]` fixed by an existing rule · `[DECISION NEEDED]` open
choice (UX rule given, value flagged for Okapion) · `[iOS]` / `[Android]`
platform-specific; everything else is shared.

### 7.1 Shared foundations (one design system, two platforms)

**Design tokens.** Source-tier tokens `[LOCKED]` (per Flutter `CLAUDE.md` rule 4 /
`lib/theme/source_tier.dart`): Medical `#2BD974` · Device `#00C6A7` · Partial
`#E6872F` · Manual `#878C8C`. Okapion anchors `[LOCKED]` (direction §5.1): primary
green `#1DBF60`, tertiary teal `rgba(32,183,186,0.38)`, yellow `#FFCE2E`, glass
focus teal `#007166`. Never hardcode hex in widgets — use the token; if a needed
semantic colour is missing, surface it to Okapion, don't invent one.

**Dark surface levels** (direction §5.3): four luminance-based levels on a dark
canvas (L0 true background → L3 overlay/sheet); depth from luminance + 1px borders,
**never drop shadows** (they don't read on dark). Exact hex are Okapion's to set
`[DECISION NEEDED]`.

**Adaptive material** (direction §17.1) `[DECISION NEEDED — evolves §5.5]`:
direction proposes ONE material whose opacity adapts to content behind it. Until
§5.5 is rewritten the **build rule remains §15.5** — glass/blur is **one surface
region only** (the Josi bottom sheet) `[LOCKED §15.5]`, never nested/animated-blur,
bound with `ClipRRect`, Impeller on, with a **mandatory solid fallback** for
mid/low Android + reduce-transparency; data surfaces stay opaque. Flutter today:
model a single `MivaltaMaterial` widget with an adaptive backdrop + baked-in solid
fallback, positioning for the §17.1 future without a rewrite.

**Readiness-as-light state machine** (direction §17.2 / §5.2): state is read
pre-cognitively from how the top surface *behaves*, then confirmed by the named
state + number beneath (never colour/light alone — accessibility §5.2 / 14.13):
Recovered = calm/cool/slow pooling light; Productive = confident steady glow
(`#00C6A7` family); Accumulated = warmer/thicker (`#FFCE2E` family, restrained);
Overreached = dimmed/settling (muted terracotta); IllnessRisk = light recedes and
stills (quieted grey-red). Confidence is expressed in the *certainty of the light*
plus the worded band — **no confidence decimals** `[LOCKED §3/§11]`. The number
stays smaller, as confirmation. Flutter: a custom-painted surface keyed off the
engine's persisted state + confidence band; no per-pixel Liquid Glass required.

**Muted-alarm rule** (direction §17.3): a safety state (`IllnessRisk`, ACWR danger)
is communicated by **changing the surface physics** — stillness, receding light,
one slow low-frequency haptic on first appearance — not bright red or motion. The
safety floor is **exempt from the presence dial** `[LOCKED §16.3]`. Always
accompanied by the named state + text; reduce-motion/-transparency renders the same
seriousness as a solid treatment.

**Typography** (direction §5.4 / §17.4): two-role system — a display face for the
state word + readiness number (the glance), a refined body face for prose and Josi.
**Tabular figures only where numbers are compared.** Respect Dynamic Type (iOS) /
font scale (Android); layouts reflow `[LOCKED 14.13]`.

**Motion & haptics** (direction §6 / §17.5): state transitions **re-settle**
(~500–600ms, interruptible), they don't fade/pop. Haptics carry meaning (soft
"settle" tap on state confirm; heavier/slower report for a safety state). **No
celebratory / streak / confetti motion** `[LOCKED §6/§11]`. The spinner is dead
(§15.4) — Josi's "Why this session?" reasoning **resolves step-by-step** in the
material; the wait is trust-building, never theatrical fake thinking.

### 7.2 Surface map (iOS ↔ Android equivalence) — the ambient-first strategy (§17.6)

Build priority is left-to-right within each row.

| Surface intent | `[iOS]` | `[Android]` | Flutter delivery |
|---|---|---|---|
| **Daily glance** | Home/Lock widget (WidgetKit) + Dynamic Island morning read | Home/Lock widget (Glance / App Widget) + "At a Glance" line | Native widget UI; reads persisted engine state via shared storage |
| **The session** | Live Activity (lock screen + Dynamic Island) | Live Updates (Android 16 API where available; ongoing notification fallback) | Native activity/notification; data pushed from Dart while app runs |
| **Bedside / recovery** | StandBy (charging, landscape) | AOD-friendly / charging surface where OEM allows | Native; iOS-led |
| **Wrist** | Watch complication + Smart Stack | Wear OS Tile + complication | Separate watch target; reads same state |
| **Voice / system** | App Intents / Siri / Spotlight | App Actions / Assistant + Quick Settings tile | Intent layer → on-device engine getter (read-only) |
| **Spatial (horizon)** | Vision Pro spatial review | — | Static-Generative catalogue ports (direction §15.3/§15.6) |

**Honesty about parity:** Dynamic Island, StandBy, and Vision Pro are iOS-only —
that's why Apple is the north star even while Flutter is the build. The widget +
session Live-Update + Wear tile are the cross-platform core and ship **first**:
they carry the thesis on the ~340 days a year nothing is wrong (presence without
demand is the retention answer, not gamification).

### 7.3 iOS surfaces (detail) `[iOS]`

- **Widgets (WidgetKit)** — the quiet default: readiness-as-light field + state word
  + small number + source-tier dot; lock-screen complication-style for at-a-glance.
  Timeline updated on engine state change, not a poll. Tap → deep-links to the
  three-zone home.
- **Live Activity + Dynamic Island** — the session: holds the prescription (target
  W/pace + the *why*) for the session's duration; Island shows compact state +
  target; resolves into the post-workout read on end. Values verbatim from the
  engine; never computes.
- **StandBy** — bedside: charging + landscape → a calm readiness face (light field +
  state word), zero interaction. The most on-brand surface for a recovery product.
- **Apple Watch** — complication (state-as-light dial/tint + one word) + Smart Stack
  ("today's read" in the morning). Co-equal with the phone, not a port afterthought.
- **App Intents / Siri / Spotlight** — "What's my readiness?" answered from the
  on-device engine. Uniquely safe: the assistant reads a *computed* value, never
  generates one.
- **Vision Pro** — horizon (not v1): spatial post-ride review; catalogue ports.

### 7.4 Android surfaces (detail) `[Android]`

- **App Widgets (Jetpack Glance)** — the quiet default mirroring the iOS daily
  glance; must render with the solid (no-blur) fallback + meet contrast minimums on
  mid/low-end Health-Connect devices.
- **Live Updates / ongoing notification** — the session: Android 16 Live Updates API
  where available, ongoing notification as universal fallback; carries target
  W/pace + the *why*; resolves to the post-workout read.
- **AOD / at-a-glance** — bedside-equivalent where the OEM permits; otherwise the
  widget on a charging screen (no exact StandBy twin — degrade gracefully).
- **Wear OS** — Tile for the state read + watch-face complication; same persisted
  state source as the phone.
- **App Actions / Assistant + Quick Settings** — readiness query (read-only engine
  getter) + an optional one-tap glance tile.

### 7.5 Flutter build notes (ambient)

- **Native vs. Dart:** widgets, Live Activity/Live Updates, StandBy, Wear tiles, and
  the intent layer are small **native** surfaces (Swift/WidgetKit, Kotlin/Glance)
  wired via platform channels; they read engine state from shared storage written by
  the Dart app. The in-app UI is Dart. FFI shim rule unchanged: one `gatc_ffi::*`
  call per fn, no compute (`CLAUDE.md` rule 2; `rust/src/api.rs`).
- **State for ambient surfaces:** they render a *persisted* engine read (the
  continuity state saved on every state-changing op). They never construct an engine
  or recompute — they display the last good computed state, with source tier +
  confidence.
- **Glass:** exactly one blur region (Josi), `ClipRRect`-bounded, solid fallback, no
  animated blur, Impeller on, profiled on real mid/low Android (§15.5).
- **Tests / dead code** `[LOCKED]`: each new surface gets a widget/integration test
  with a concrete-value assertion (rule 8); every new public Dart symbol has a
  production call site within one PR (rule 7).

### 7.6 Accessibility (both platforms, non-negotiable — direction 14.13)

State never by colour/light alone (always named state + text); Dynamic Type / font
scale respected, layouts reflow; screen-reader labels on every data point including
**provenance and confidence**; contrast minimums met on the dark canvas; `Reduce
Transparency` / `Reduce Motion` honoured (solid material, static light, no re-settle
— the safety seriousness still reads); haptics supplement, never replace,
visual/textual confirmation.

### 7.7 Platform open decisions (carried from direction §17 — for Okapion + spec)

- Adopt the single adaptive material and formally rewrite §5.5? (§17.1)
- Readiness-as-light demoting the number — confirm against spec (§17.2).
- Collapse the tab spine toward two glance-surfaces (Today / History)? (§17.8 / 14.1)
- iOS-first vs Android-first **sequencing** (14.7 / §15.6) — design supports either
  order; the build focus is the open call.
- Exact dark surface-level hex values — Okapion to set.

**Ambient build priority** (where to spend first): (1) readiness-as-light home +
daily-glance widget reading persisted state; (2) the session surface (Live Activity
/ Live Updates); (3) the wrist (complication / Wear Tile); (4) voice (App Intents /
App Actions); (5) polish (StandBy, motion/haptic refinement, "Why this session?"
resolve-in-material).

---

## 8. References

- `UI_UX_DIRECTION.md` (rust-engine) — the parent direction + the §17 "north star"
  (ambient surfaces) that is **post-MVP**, not the in-app MVP spec.
- `docs/frontend/DATA_CATALOG.md` + `FFI_API_CONTRACT.md` (rust-engine) — the exact
  payload behind every element here.
- `MAC_BRIEF_*` (this repo) — the build tasks that fill the gaps above.

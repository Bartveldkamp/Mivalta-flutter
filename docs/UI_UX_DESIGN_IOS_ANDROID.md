# MiValta — UI/UX Design: iOS & Android

Status: platform design spec, v1.0
Date: 2026-06-07
Build: Flutter (single codebase) targeting iOS + Health-Connect Android.
Source of truth: this document RECONCILES to `UI_UX_DIRECTION.md` §17 (rust-engine, v1.5 —
"Material & Ambient Direction"). Where the canonical direction and this spec disagree, the
direction wins; this file is the platform translation of it, not a new mandate.

Principle (unchanged, every surface obeys it): **the Rust engine DECIDES/COMPUTES, the FFI
PASSES THROUGH, Flutter DISPLAYS.** No thresholds, math, or fabrication in Dart. Ambient
surfaces (widgets, Live Activities, tiles, voice) render the engine's persisted state — they
never recompute it.

---

## 0. How to read this

This is the **platform** layer: how the calm-PULL, ambient-first, honest design (Section 1 of
the direction) is built on each OS, and which parts are one shared Flutter codebase vs. a small
native surface. It is deliberately split into:
- **§1 Shared foundations** — one design system, identical on both platforms.
- **§2 Surface map** — the iOS↔Android equivalence table.
- **§3 / §4** — the platform-specific surfaces in detail (iOS, then Android).
- **§5–§9** — in-app screens, Flutter build notes, accessibility, locked rules + open decisions.

Marker convention (matching the direction doc):
- `[LOCKED]` — fixed by an existing locked rule (tokens, F1 copy, glass limits). Do not change.
- `[DECISION NEEDED]` — an open choice; the UX rule is given, the value is flagged for Okapion.
- `[iOS]` / `[Android]` — platform-specific; everything else is shared.

---

## 1. Shared foundations (one design system, two platforms)

### 1.1 Design tokens

**Source-tier tokens** `[LOCKED]` (per Flutter `CLAUDE.md` rule 4 and `lib/theme/source_tier.dart`):

| Tier | Token | Hex |
|------|-------|-----|
| Medical | `sourceTierMedical` | `#2BD974` |
| Device | `sourceTierDevice` | `#00C6A7` |
| Partial | `sourceTierPartial` | `#E6872F` |
| Manual | `sourceTierManual` | `#878C8C` |

**Okapion anchors** `[LOCKED]` (direction §5.1):

| Role | Hex |
|------|-----|
| Primary green (positive / safe / go) | `#1DBF60` |
| Tertiary teal | `rgba(32,183,186,0.38)` |
| Yellow (caution / attention) | `#FFCE2E` |
| Glass focus teal | `#007166` |

Never hardcode hex in widgets — use the token (Flutter rule 4). If a needed semantic colour is
missing from the set, surface it to Okapion; do not invent one (direction §5.1).

### 1.2 Dark surface levels (direction §5.3)

Four luminance-based levels on a dark canvas; depth from luminance + 1px borders, **never drop
shadows** (they do not read on dark). Exact values are Okapion's to set — placeholders below are
illustrative and `[DECISION NEEDED]`, not canonical tokens:

| Level | Role | Illustrative |
|-------|------|--------------|
| L0 | True background | very near-black |
| L1 | Elevated surface (cards) | +luminance |
| L2 | Secondary elevated (nested) | +luminance |
| L3 | Overlay / sheet | +luminance |

### 1.3 The adaptive material (direction §17.1) `[DECISION NEEDED — evolves §5.5]`

Direction §17.1 proposes retiring the "glass vs. opaque" split for ONE material whose opacity
adapts to content behind it. Until §5.5 is formally rewritten, the **build rule remains §15.5**:
- Glass/blur is **one surface region only** (the Josi bottom sheet), `[LOCKED §15.5]`.
- Never nested, never animated-blur; bound with `ClipRRect`; Impeller on.
- **Mandatory solid fallback** for mid/low Android and for reduce-transparency: a semi-opaque
  solid that looks *intentional*, never broken.
- Data surfaces stay **opaque** (charts, tiles, history). If frame rate and aesthetics conflict,
  frame rate wins.

Flutter today: model a single `MivaltaMaterial` widget with `(a)` an adaptive backdrop that goes
near-opaque over data and `(b)` the solid fallback baked in. This positions the codebase for the
§17.1 adaptive-material future without a rewrite, while shipping inside §15.5 limits now.

### 1.4 Readiness-as-light state machine (direction §17.2 / §5.2)

State is read pre-cognitively from how the top surface **behaves**, then confirmed by the named
state + number beneath (never colour/light alone — accessibility, direction §5.2 / 14.13).

| Viterbi state | Light behaviour | Semantic colour (through tokens) |
|---|---|---|
| Recovered | calm, cool, slow pooling luminance | open / light |
| Productive | confident, steady glow | confident teal `#00C6A7` family |
| Accumulated | warmer, thicker, less air | warm amber (`#FFCE2E` family, restrained) |
| Overreached | dimmed, settling | muted terracotta |
| IllnessRisk | light **recedes and stills** | quieted grey-red |

- Confidence is expressed in the **certainty of the light** (a `calibrating` state shimmers
  faintly — unresolved light for unresolved knowledge) plus the worded band ("stable",
  "calibrating", "low confidence"). **No confidence decimals** `[LOCKED §3/§11]`.
- The number stays smaller, as confirmation (resolves the hero-number paradox, §17.2).
- Flutter: a custom-painted surface (gradient / low-cost luminance animation) keyed off the
  engine's persisted state + confidence band. No per-pixel Liquid Glass required.

### 1.5 The muted-alarm rule (direction §17.3)

A safety state (`IllnessRisk`, ACWR danger) is communicated by **changing the surface physics**
— stillness, receding light, one slow low-frequency haptic on first appearance — not by bright
red or motion. It is impossible to miss because the whole interface starts behaving differently.
The safety floor is **exempt from the presence dial** `[LOCKED §16.3]` and fires regardless of
coaching-style setting. Always accompanied by the named state + text; a reduce-motion /
reduce-transparency fallback renders the same seriousness as a solid treatment.

### 1.6 Typography (direction §5.4 / §17.4)

Two-role system: a display face for the state word + readiness number (the glance), a refined
body face for prose and Josi. **Tabular figures only where numbers are compared** (charts,
splits). Prefer a variable font with an optical-size axis (or two cuts) so glance type is a
different drawing at display size, never system-default-sporty. Respect Dynamic Type (iOS) and
font scale (Android); layouts reflow `[LOCKED 14.13]`.

### 1.7 Motion & haptics (direction §6 / §17.5)

- State transitions **re-settle** (~500–600ms, interruptible), they do not fade/pop.
- Pull-up sheets use standard physical, interruptible motion.
- Haptics carry meaning, not noise: soft "settle" tap on state confirm; heavier/slower report
  for a safety state. iOS: `UIImpactFeedbackGenerator` / Core Haptics. Android: `VibrationEffect`
  / `HapticFeedbackConstants`. Flutter: `HapticFeedback` for the common path, platform channel
  for the safety report where richer haptics are wanted.
- **No celebratory / streak / confetti motion** `[LOCKED §6/§11]`. Race-day and rest are
  intentionally still.
- The spinner is dead (§15.4): Josi's "Why this session?" reasoning **resolves step-by-step**
  in the material; the wait is the trust-building, never theatrical fake thinking.

---

## 2. Surface map (iOS ↔ Android equivalence)

The ambient-first strategy (direction §17.6). Build priority is left-to-right within each row.

| Surface intent | `[iOS]` | `[Android]` | Flutter delivery |
|---|---|---|---|
| **Daily glance** | Home/Lock Screen widget (WidgetKit) + Dynamic Island morning read | Home/Lock widget (Glance / App Widget) + "At a Glance" line | Native widget UI; reads persisted engine state via shared storage |
| **The session** | Live Activity (lock screen + Dynamic Island) | Live Updates / ongoing notification (Android 16 Live Updates API where available; ongoing notification fallback) | Native activity/notification; data pushed from Dart while app runs |
| **Bedside / recovery** | StandBy (charging, landscape) | AOD-friendly / charging surface where OEM allows | Native; iOS-led |
| **Wrist** | Watch complication + Smart Stack | Wear OS Tile + complication | Separate watch target; reads same state |
| **Voice / system** | App Intents / Siri / Spotlight | App Actions / Assistant + Quick Settings tile | Intent layer → on-device engine getter (read-only) |
| **Spatial (horizon)** | Vision Pro spatial review | — | Static-Generative catalogue ports (direction §15.3/§15.6) |

**Honesty about parity:** Dynamic Island, StandBy, and Vision Pro are iOS-only — that is the
reason Apple is named the north star even while Flutter is the build. The widget + session
Live-Update + Wear tile are the cross-platform core and ship **first**: they carry the thesis on
the ~340 days a year nothing is wrong (direction §17.6/§17.7 — presence without demand is the
retention answer, not gamification).

---

## 3. iOS surfaces (detail) `[iOS]`

### 3.1 Widgets (WidgetKit) — the quiet default
- Small/medium widget: the readiness-as-light field, the state word, a small number, a source-
  tier dot. Lock Screen circular/inline complication-style widget for the at-a-glance read.
- Timeline updated on engine state change (watch-sync / nightly γ-confirmation), not on a poll.
- Tap → deep-links to the three-zone home (§5).

### 3.2 Live Activity + Dynamic Island — the session
- On session start, a Live Activity holds the prescription (target W / pace + the *why*) for the
  session's duration; the Island shows the compact state + target.
- Resolves into the post-workout read (card-grounded, engine-computed) when the session ends.
- All values verbatim from the engine; the Live Activity never computes.

### 3.3 StandBy — bedside
- Charging + landscape → a calm readiness face: the light field + state word, zero interaction.
- The single most on-brand surface for a recovery product; overnight + on-waking.

### 3.4 Apple Watch — complication + Smart Stack
- Complication: the state-as-light reduced to a dial/tint + one word.
- Smart Stack surfaces "today's read" contextually in the morning.
- Co-equal with the phone for athletes who live on the watch — not a port afterthought.

### 3.5 App Intents / Siri / Spotlight — voice
- "What's my readiness?" answered from the on-device engine. **Uniquely safe**: the assistant
  reads a *computed* value, never generates one — the zero-fabrication architecture (direction
  §8.1) is what makes voice retrieval trustworthy.

### 3.6 Vision Pro — horizon (not v1)
- Spatial post-ride review (power curve, fitness arc as objects). Catalogue ports without rethink.

---

## 4. Android surfaces (detail) `[Android]`

### 4.1 App Widgets (Glance / Jetpack Glance) — the quiet default
- Home + lock-screen widget mirroring the iOS daily glance: light field, state word, number,
  source-tier dot. Updated on engine state change.
- Health-Connect Android spans many mid/low-end devices — the widget must render with the solid
  (no-blur) material fallback and meet contrast minimums (§15.5 / 14.13).

### 4.2 Live Updates / ongoing notification — the session
- Android 16 **Live Updates** API for the session strip where available; ongoing notification as
  the universal fallback. Carries target W/pace + the *why*; resolves to the post-workout read.

### 4.3 AOD / at-a-glance — bedside-equivalent
- Where the OEM permits an always-on / ambient surface, the calm readiness read; otherwise the
  widget on a charging screen. iOS StandBy has no exact Android twin — degrade gracefully.

### 4.4 Wear OS — Tile + complication
- A Tile for the state read; a watch-face complication for the light + word. Same persisted
  state source as the phone.

### 4.5 App Actions / Assistant + Quick Settings
- Assistant App Actions for the readiness query (read-only engine getter). A Quick Settings tile
  as an optional one-tap glance.

---

## 5. In-app screens (shared)

The in-app surface is one Flutter codebase, identical layout on both platforms (use-mode changes
content, not the spine — direction 14.1). Canonical wiring lives in `docs/UI_FLOW.md`; this spec
only adds the material/ambient treatment on top of it.

- **Three-zone home** (`ReadinessScreen`): Zone 1 STATE as the light field (§1.4) over an opaque
  detail stack; Zone 2 TODAY (session + "Why this session?" collapsed); Zone 3 CONTEXT (three
  opaque tiles). The home stops being the *primary* surface — the widget/Island is (§2).
- **Josi** is a pull-up glass bottom sheet (the one glass surface), reachable from anywhere; not
  a tab (direction §4 / 14.1).
- **F1 no-data copy is locked verbatim**: "We need more data to predict recovery." `[LOCKED]`
- **Spine** `[DECISION NEEDED]`: direction §17.8 suggests collapsing toward two glance-surfaces
  (Today / History) with Profile+Settings behind the avatar — revisits 14.1; do not change the
  tab spine without surfacing it.

---

## 6. Flutter build notes

- **What's native vs. Dart:** widgets, Live Activity/Live Updates, StandBy, Wear tiles, and the
  intent layer are small **native** surfaces (Swift/WidgetKit, Kotlin/Glance) wired via platform
  channels; they read engine state from shared storage written by the Dart app. The in-app UI is
  Dart. The FFI shim rule is unchanged: one `gatc_ffi::*` call per fn, no compute (Flutter
  `CLAUDE.md` rule 2; `rust/src/api.rs`).
- **State for ambient surfaces:** ambient surfaces must render a *persisted* engine read (the
  continuity state already saved on every state-changing op). They never construct an engine or
  recompute — they display the last good computed state, with its source tier and confidence.
- **Glass:** exactly one blur region (Josi), `ClipRRect`-bounded, solid fallback, no animated
  blur, Impeller on, profiled on real mid/low Android (§15.5).
- **New behaviour needs a test** `[LOCKED]` (Flutter `CLAUDE.md` rule 8): each new surface gets a
  widget/integration test with a concrete-value assertion (e.g. the widget renders the persisted
  state word + source-tier token for a known fixture).
- **No dead code** `[LOCKED]`: every new public Dart symbol has a production call site within one
  PR.

---

## 7. Accessibility (both platforms, non-negotiable — direction 14.13)

- State never by colour/light alone — always the named state + text.
- Dynamic Type / font scale respected; layouts reflow.
- Screen-reader labels on every data point, including **provenance and confidence** (they are
  meaning, not decoration).
- Contrast minimums met on the dark canvas; luminance-based depth must still pass contrast.
- `Reduce Transparency` / `Reduce Motion` honoured: solid material, static light, no re-settle
  animation — the safety seriousness still reads.
- Haptics supplement, never replace, visual/textual confirmation.

---

## 8. Locked rules + open decisions (the guardrails)

**Locked (do not change without changing the source rule):**
- Source-tier tokens + Okapion anchors (§1.1).
- One glass region, solid fallback, no animated blur (§15.5).
- F1 no-data copy verbatim (§5).
- No gamification / streaks / engagement notifications (direction §11).
- Notification budget = three types only (direction §10.4); safety floor exempt from presence
  dial (§16.3).
- Engine decides, Flutter displays; FFI is pure transport.

**Open `[DECISION NEEDED]` (carried from direction §17 — for Okapion + spec):**
- Adopt the single adaptive material and formally rewrite §5.5? (§1.3 / §17.1)
- Readiness-as-light demoting the number — confirm against spec (§1.4 / §17.2).
- Collapse the tab spine toward two glance-surfaces? (§5 / §17.8 / 14.1)
- iOS-first vs Android-first **sequencing** (direction 14.7 / §15.6) — the design supports either
  order without redesign; the build focus is the open call.
- Exact dark surface-level hex values (§1.2) — Okapion to set.

---

## 9. Build priority (where to spend first)

1. **The shared core that carries the thesis:** readiness-as-light home (§1.4) + daily-glance
   **widget** (iOS WidgetKit + Android Glance) reading persisted state. This alone delivers the
   "presence without demand" retention answer.
2. **The session surface:** Live Activity (iOS) / Live Updates (Android) holding the prescription
   and resolving to the post-workout read.
3. **The wrist:** Watch complication / Wear Tile.
4. **Voice:** App Intents / App Actions over the read-only engine getter.
5. Polish: StandBy (iOS), motion/haptic refinement, the "Why this session?" resolve-in-material.

The best version is the one that executes calm, honest, and presence-without-demand with
precision across both platforms — and knows when to show nothing at all.

---

End of MiValta UI/UX Design: iOS & Android v1.0.
Reconciles to `UI_UX_DIRECTION.md` §17 (rust-engine, v1.5). Drift detection is unchanged: does
the surface serve the Section 1 intent (calm, honest, agency)? If yes, proceed. If no, surface it.

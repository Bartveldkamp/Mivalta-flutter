# MiValta — Project Handoff to Apadmi

**This is the hand-in document.** MiValta engages Apadmi to build the production
**Flutter** app (iOS **and** Android) for the **beta**. This one page is the front
door, the scope statement, and the "read these, in this order" map. Everything it
references is in the repos; nothing here is verbal-only.

> **One-line:** MiValta is a privacy-first, **100% on-device** AI training coach. A
> deterministic Rust engine DECIDES; the Flutter app DISPLAYS. See
> [`MIVALTA_OVERVIEW.md`](https://github.com/Bartveldkamp/mivalta-rust-engine/blob/main/docs/MIVALTA_OVERVIEW.md)
> (1 page) for the whole model and all repos.

---

## 1. The beta is **MONITOR + ADVISOR** — build this, nothing more

- **MONITOR** (free tier) — the readiness dashboard. **No LLM.** Pure
  card-rendered display of the engine's state / readiness / load.
- **ADVISOR** (paid tier) — adds today's workout suggestion (lead-with-A, offer-C)
  and a post-workout report. Still **no conversational surface.**
- **NOT in the beta:** COACH (multi-day plans, plan negotiation) **and — important —
  no free Josi chat / Q&A.** ⚠️ **If you receive an older Okapion Figma that has a
  Josi free-chat screen, that file is SUPERSEDED.** The beta has no chatbot, no
  open Q&A. The on-device conversational layer is a *later* phase.
- **Platforms: iOS + Android** (that's why it's Flutter). iOS bring-up needs
  finishing — see `docs/IOS_BRINGUP_BRIEF.md`.

## 2. The design north star — a next-generation **"training buddy," not a dashboard**

This is the differentiator, and it overrides the look of every typical training
app:

- **Calm and intuitive by default** — it feels like a knowledgeable *buddy* who
  tells you what matters *now*: one clear read (today's readiness), one clear
  suggestion (today's session), one calm line of context. Not a wall of graphs.
- **Progressive disclosure — all the depth is there, revealed only on demand.**
  Every number, chart, trend, and "why" the engine can produce **is available** —
  but it lives **one tap deeper**, never on the front. The home is the buddy's
  read; the depth (full analytics, the 4-axis why, history, power curves) is a
  drawer the user *chooses* to open. The opposite of screen-and-graph overload.
- **Honest, never alarming** — the quiet state is the product working; confidence
  is always visible ("still learning you" early on); the athlete can always go
  deeper or override.

The **canonical design direction is the next-generation concept in
[`UI_UX_DIRECTION.md`](https://github.com/Bartveldkamp/mivalta-rust-engine/blob/main/docs/UI_UX_DIRECTION.md)
+ [`DESIGN_BUILD_SPEC.md`](DESIGN_BUILD_SPEC.md)** in this repo — NOT the older
Okapion Figma. `DESIGN_BUILD_SPEC.md` is the screen-by-screen execution brief
(what each screen shows, from which real engine data, all states).

## 3. Read in this order

| # | Doc | Why |
|---|---|---|
| 1 | [`docs/READING_ORDER.md`](READING_ORDER.md) (this repo) | The dev front door: scope, repo tour, Dart↔Rust path, build/test, known gaps |
| 2 | [`docs/FRONTEND_HANDOVER.md`](FRONTEND_HANDOVER.md) (this repo) | Repo structure + the **wired-vs-not-built** map |
| 3 | [`docs/DESIGN_BUILD_SPEC.md`](DESIGN_BUILD_SPEC.md) (this repo) | The screens to design/build + the buddy/progressive-disclosure north star |
| 4 | `docs/frontend/FFI_API_CONTRACT.md` + `docs/frontend/DATA_CATALOG.md` (rust-engine) | Every engine method, JSON shape, and the full catalogue of signals available |
| 5 | `docs/UI_UX_DIRECTION.md` (rust-engine) | The design language + locked tokens (read §0–§16 as MVP; §17 is post-MVP "north star") |

## 4. The non-negotiables (the engine + spec enforce these)

- **Engine DECIDES, Flutter DISPLAYS.** No coaching logic, math, thresholds, or
  fallback in Dart — every number/zone/state comes out of the engine computed.
- **Locked source-tier colors:** Medical `#2BD974` · Device `#00C6A7` · Partial
  `#E6872F` · Manual `#878C8C`. **Locked no-data copy, verbatim:** "We need more
  data to predict recovery."
- **On-device only.** No cloud round-trips.
- **No chat surface in the beta.**

## 5. What's wired vs. what to build

The engine is complete; the app already renders real engine output on every core
screen (verified by a bidirectional wiring audit). The build work — each with a
brief in this repo's `docs/`:

- **`MAC_BRIEF_WORKOUT_INGEST.md`** — *the #1 task.* Completed workouts aren't yet
  written to the vault, which starves five wired features (post-workout report,
  advisor rotation, power charts, the decoupling signal, workout RPE).
- **`MAC_BRIEF_ADVISOR_LEAD_A.md`** — restyle the advisor to lead-with-A / offer-C.
- Privacy "pause learning" toggle (bound, no UI); manual-entry optional inputs
  (illness flag etc.); finish iOS bring-up.

## 6. Repos & access

| Repo | Role | Apadmi needs |
|---|---|---|
| **Mivalta-flutter** (this) | The app | write |
| **mivalta-rust-engine** | The engine + the FFI contract + the design direction | **read** (the git-pinned `gatc-ffi` is fetched from here on build) |
| mivalta-science-engine | The Josi model (later phase) | not for beta |

**Build prerequisites** (the day-1 cliff): the APK/IPA needs the Rust engine
compiled into the native lib first — Flutter + Rust toolchain + NDK (Android) /
Xcode (iOS) + read access to `mivalta-rust-engine`. See `README.md` → Quick start.

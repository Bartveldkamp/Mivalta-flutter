# START HERE — Reading Order for External Frontend Developers

You're building (or designing) the MiValta Flutter app. This is the **one page to
read first**, then the ordered list of what to read next and why. The product is
**on-device, privacy-first**, and built on one hard principle:

> **The Rust engine DECIDES. Flutter DISPLAYS.** No coaching logic, math,
> thresholds, or fallback in Dart. Every number, zone, state, and recommendation
> comes out of the engine already computed; the UI renders it verbatim.

## What you're building — the MVP scope (do not exceed it)

**MVP = MONITOR + ADVISOR.** COACH is deferred to a later phase.

- **MONITOR** (free tier) — the readiness dashboard. **No LLM.** Pure
  card-rendered display of the engine's state/readiness/load. The home screen.
- **ADVISOR** (paid tier) — adds today's workout suggestion and post-workout
  feedback. The conversational AI (Josi) is a *later* phase; do **not** build a
  chat/Q&A surface for the MVP.
- **COACH** (multi-day plans, plan negotiation, open conversation) — **out of
  MVP scope.** If a design doc describes conversational/negotiation surfaces,
  they are post-MVP unless explicitly marked MVP.

Two design decisions you must build to (founder, 2026-06-11):
1. **Advisor workout options: lead with A, offer C as the easy fallback.** Option
   A is the engine's recommended session (lead it); option C is the easy
   alternative; option B is de-emphasized. *Not* an equal-weight menu.
2. **Readiness home: the number (0–100) is the hero** — the largest element.

## Read in this order

| # | Read | Why | Where |
|---|---|---|---|
| 1 | **`FRONTEND_HANDOVER.md`** (this repo) | The repo tour: structure, the Dart↔Rust path, what's wired vs. not-built, build/test. Your map. | `docs/` here |
| 2 | **`MVP1_BUILD_BRIEF.md`** (this repo) | The exact MVP scope + screens to build. | `docs/` here |
| 3 | **Engine FFI contract** | Every engine method, its JSON shape, and errors — the authoritative API surface. **If any doc disagrees with this, this wins.** | rust-engine `docs/frontend/FFI_API_CONTRACT.md` |
| 4 | **The client builder's guide** | Plain-English meaning of every value the athlete sees + how to render it; the UI rules. | rust-engine `docs/frontend/FRONTEND.md` |
| 5 | **UI/UX direction** | The design language, tone, three-zone home, locked tokens. Read §0–§16 as MVP; **Section 17 is a forward-looking "north star," not the MVP build.** | rust-engine `docs/UI_UX_DIRECTION.md` (v1.6) |
| 6 | *(context, optional)* | The product mental model + the two engines. | rust-engine `docs/REPO_GUIDE.md`, `docs/ARCHITECTURE.md` |

> The rust-engine docs (3–6) live in the **`mivalta-rust-engine`** repo
> (https://github.com/Bartveldkamp/mivalta-rust-engine), which you clone
> separately. Its `docs/index.md` is the role-based entry point on that side.

## Non-negotiables (the engine + spec enforce these)

- **Render prose verbatim.** Advisory sentences and dashboard strings are final —
  don't reword, summarize, or append.
- **Never compute physiology in Dart.** If you need a value, there's a call for it.
- **Locked source-tier color tokens:** Medical `#2BD974`, Device `#00C6A7`,
  Partial `#E6872F`, Manual `#878C8C`. Use the design token; never hardcode hex.
- **Locked F1 no-data copy, verbatim:** "We need more data to predict recovery."
- **Surface confidence honestly.** Low data → say so ("still learning you").
- **On-device only.** No cloud round-trips.
- **The Dart↔Rust boundary is load-bearing** — changes to `rust/src/api.rs` or
  `lib/rust_engine.dart` must be surfaced before editing (see `CLAUDE.md`).

## Known gap to be aware of

The current advisor screen in this repo (`lib/screens/advisor_screen.dart`) still
treats A/B/C as **equal-weight** — that predates the lead-with-A decision above
and is flagged for alignment. Build new advisor UI to **lead-with-A / offer-C**.

## Build & test (quickstart)

`flutter pub get`, `analyze`, and `test` work immediately. **Building the APK
does NOT** — it needs the Rust engine compiled into
`libmivalta_rust_bridge.so` first. That step requires: a Rust toolchain +
`cargo-ndk`, **Android NDK 28**, and **SSH access to the private
`mivalta-rust-engine` repo** (Cargo resolves the git-pinned `gatc-ffi` over
SSH — it fails without the key). See **`README.md` → "Quick start"** for the
exact `cargo ndk … build` recipe (and the stray-`.so` cleanup). Don't expect
`flutter build apk` to work until you've done that.

```bash
flutter pub get
flutter analyze          # CI gate: `flutter analyze --fatal-infos` — stricter than tests
flutter test
# APK build — only AFTER the Rust .so is built (see README.md Quick start):
flutter build apk --debug --target-platform android-arm64
```
CI gate is `flutter analyze --fatal-infos`: **local `flutter test` passing is not
sufficient** — analyze must be clean too.

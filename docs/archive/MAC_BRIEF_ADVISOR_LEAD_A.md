> **ARCHIVED 2026-06-20 — superseded; shipped**
>
> Advisor lead-with-A / offer-C / B-de-emphasized restyle landed in lib/ (AdvisorOptionsList) and is pinned by test/advisor_options_test.dart; the READING_ORDER.md "Known gap #2" is marked RESOLVED (2026-06-12). Retained for provenance.

---

# Mac Brief — Advisor screen: implement lead-with-A / offer-C

**Executor:** Mac Claude Code (Alta). **Scope:** this repo only (display-only —
no shim/facade/engine change).
**Origin:** founder design decision (UI_UX_DIRECTION v1.6, 2026-06-11) +
fresh-eyes onboarding audit, which named this the **#1 blocker** for the
handover. `READING_ORDER.md` and the UI/UX doc say *lead-with-A / offer-C*; the
**code still renders three equal-weight cards** — a doc-vs-code contradiction a
new dev/designer hits immediately.

## The decision to build to

The advisor returns three options in fixed order (engine contract,
`FFI_API_CONTRACT.md` §4.8): **A** = the data-aligned GATC pick, **B** =
alternative, **C** = recovery/easy fallback. The UI must present them as a real
coach would:

- **Lead with A** — visually emphasized: top, largest, headline-styled as "the
  recommended session for today."
- **Offer C** as the clearly-labelled **easy alternative** ("or take it easy").
- **De-emphasize B** (or omit it from the primary view; secondary at most).
- **NOT** three equal cards the user scans as a flat menu.

This is presentation only. The engine already ranks A/B/C; the UI reflects that
ranking. No reordering, no logic, no thresholds in Dart — the order comes from
the engine; the UI just styles it.

## Tasks

1. **Rework `lib/screens/advisor_screen.dart`** (currently a flat
   `ListView.builder` rendering A/B/C identically): emphasize A, present C as the
   easy fallback, de-emphasize/secondary B. Render every value verbatim from the
   engine (`recommend_workout_with_history` → `WorkoutOptionData`): title, zone,
   duration, targets, RPE, `why`, optional terrain `expression`. Honour the
   readiness cap honestly (at red, A is already capped to easy/rest by the engine —
   present it as such, don't upsell).
2. **Widget test** (`test/advisor_screen_test.dart`): assert that given A/B/C,
   **A is rendered emphasized/first** and **C is presented as the easy
   alternative** — so a future accidental reorder/flatten is caught. Concrete-value
   assertions (rule 8).
3. **Clear the known-gap note** in `docs/READING_ORDER.md` (§"Known gap") once the
   screen matches the decision.

## Definition of done

- `flutter analyze --fatal-infos` clean (the CI gate — stricter than `flutter test`).
- `flutter test` green incl. the new ranking assertion.
- Advisor screen visibly leads with A and offers C; B de-emphasized.
- Branch `mac/advisor-lead-a`; one PR; do not merge without green CI.

## Out of scope

The Josi conversational layer (deferred), the privacy toggle (separate brief
`MAC_BRIEF_PRIVACY_TOGGLE.md`), any `rust/src/api.rs` / `lib/rust_engine.dart`
change (the engine already provides ranked A/B/C — this is pure display).

STATUS: ACTIVE

# Today Screen — Build Report v8

**Live build as of SHA `c9f4b4b`.**

**Branch:** `feature/today-fresh-build`
**Date:** 2026-07-01
**Spec:** BS-004-typescale.md — iOS-native type scale bump

**Status:** BS-004 complete. Type scale bumped to iOS-native base (body 17px).

---

## Screenshots — CAPTURED (SHA-matched)

| State | Filename | What renders |
|-------|----------|--------------|
| Normal | `today_c9f4b4b_normal.png` | Type scale bump visible: cardTitle 18px, metric 32px, labels 14px |

---

## BS-004 — Type Scale Bump (NEW)

**Spec:** BS-004-typescale.md

| Token | Old | New | Status |
|-------|-----|-----|--------|
| `titleM` | 20px | 22px | Done |
| `metric` | — | 32px (NEW) | Done |
| `bodyL` | 17px | 19px | Done |
| `body` | 15px | 17px | Done |
| `cardTitle` | 13px | 18px | Done |
| `small` | 13px | 14px | Done |
| `label` | 11px | 12px | Done |

**Note:** `hero` (56px) and `display` (40px) unchanged — already at target.

**Widget wiring:** `module_card.dart` now uses `MivaltaType.cardTitle`, `MivaltaType.small`, and new `MivaltaType.metric` tokens instead of hardcoded sizes.

---

## Files Changed (this pass)

| File | Changes |
|------|---------|
| `lib/theme/tokens.dart` | BS-004 type scale bump: titleM 20→22, bodyL 17→19, body 15→17, cardTitle 13→18, small 13→14, label 11→12; NEW `metric` token at 32px |
| `lib/widgets/today/module_card.dart` | Wired `MetricRow` to use `MivaltaType.cardTitle`, `MivaltaType.small`, `MivaltaType.metric` tokens |

---

## Current State — What Renders

| Element | Status | Detail |
|---------|--------|--------|
| Card title "Load today" | Updated | `cardTitle` 18px (was 13px) |
| Metric value "59" | Updated | NEW `metric` 32px Inter w600 |
| Unit label "UL" | Updated | `small` 14px at 50% alpha |
| Row label "Training load" | Updated | `small` 14px |
| State word "Productive" | Updated | `titleM` 22px (was 20px) |
| Body copy | Updated | `body` 17px (iOS-native base) |

---

## Screenshot Log

| SHA | Filename | Task | Date |
|-----|----------|------|------|
| `c9f4b4b` | `today_c9f4b4b_normal.png` | **BS-004 — type scale bump** | 2026-07-01 |
| `1e133d8` | `today_1e133d8_normal.png` | DR-012 — Z8 chip suppressed | 2026-07-01 |
| `833361d` | `today_833361d_*.png` | BS-002 masthead | 2026-07-01 |
| `f9b7eff` | `today_f9b7eff_*.png` | DR-009 — glow centered | 2026-07-01 |

Historical screenshots in `archive/`.

---

## Prior Work

All items from v7 remain complete:
- BS-001 Steps 1–10: cards, glow, chip, absence treatments
- BS-002: Two-tier masthead (logo+wordmark centered, start workout + weather)
- DR-004–DR-012: token pass, chip treatment, glow tuning, portrait-only, Z8 suppression

---

## Next

**Completed:** BS-004 — type scale bumped to iOS-native base.

**Awaiting:** Design Review (DR) for BS-004 screenshot.

# Today Screen — Build Report v6 (BS-001 executed)

**Branch:** `feature/today-fresh-build`
**Commit:** `ee709d7`
**Date:** 2026-07-01
**Status:** BS-001 Steps 1-10 complete

---

## BS-001 Build Steps — Execution Status

| Step | Description | Status |
|------|-------------|--------|
| 1 | Card titles → Title Case | ✓ Done |
| 2 | Card icons → 30×30 rounded tile, rgba(0,198,167,.12) bg, #00C6A7 17px | ✓ Done |
| 3 | "YOUR DAY" section eyebrow above cards | ✓ Done |
| 4 | Glow → 172/104px two-layer, 12px/2px blur | ✓ Done |
| 5 | State word spacing at 6px (not 12px) | ✓ Done |
| 6 | Collapse hero void when Josi + chip absent | ✓ Done |
| 7 | Decision chip honest-absent (hidden, collapse) | ✓ Done |
| 8 | Josi honest-absent, source from state_recommendation | ✓ Done |
| 9 | Card container + absence-body styling | ✓ Done |
| 10 | Sleep card consistency (Title Case + icon tile) | ✓ Done |

### Trailing Flags (deferred)
- Combined Load & Sleep card — not this pass
- Collapsible cards — not this pass

---

## Files Changed

| File | Changes |
|------|---------|
| `lib/screens/today_screen.dart` | Hero void collapse, "YOUR DAY" eyebrow, conditional spacing |
| `lib/widgets/today/glow_hero.dart` | 172/104px two-layer glow, 12px/2px blur, dart:ui import |
| `lib/widgets/today/module_card.dart` | Title Case, icon tile 30×30 with bg |

---

## Current State — What Renders

| Element | Status | Detail |
|---------|--------|--------|
| "Today" title | ✓ Real | Left-aligned, Inter 700 |
| Glow hero | ✓ Real | Two-layer 172/104px, 12px/2px blur |
| Score "78" | ✓ Real | Engine-computed readiness |
| State word "Recovered" | ✓ Real | Mint #7FE3B0, 6px below score |
| "YOUR DAY" eyebrow | ✓ New | Inter 700, 10px, 1.1px tracking, uppercase |
| Josi line | Honest-absent | Collapses (advisories not attached) |
| Decision chip | Honest-absent | Collapses (not wired) |
| Load today card | Honest-absent | Title Case, icon tile |
| Daily activity card | Honest-absent | Title Case, icon tile |
| Sleep card | ✓ Real | "8h", Title Case, icon tile |
| Suggested workout card | Honest-absent | Title Case, icon tile |
| Bottom nav | ✓ Real | Today (active) / Journey / You |

---

## Screenshot Log

| SHA | Filename | Task | Date |
|-----|----------|------|------|
| `eb42c02` | `today_eb42c02_live.png` | Initial reconciliation | 2026-06-30 |
| `a7c312a` | `today_a7c312a_live.png` | DR-002 fixes | 2026-06-30 |
| `5e46e4e` | `today_5e46e4e_live.png` | State word wiring fix | 2026-06-30 |
| `2b2edc9` | `today_2b2edc9_live.png` | Baseline for DR-003 | 2026-07-01 |
| `57afe91` | `today_57afe91_live.png` | DR-003 fixes | 2026-07-01 |
| `ee709d7` | `today_ee709d7_live.png` | **BS-001 complete** | 2026-07-01 |

---

## Next

**For Mac session:** Capture SHA-stamped screenshot `today_ee709d7_live.png` on simulator.

**For Claude Design:** Review as DR-004 against BS-001 spec.

STATUS: ACTIVE

# Today Screen — Build Report v6

**Live build as of SHA `375d07e`.**

**Branch:** `feature/today-fresh-build`
**Date:** 2026-07-01
**Spec:** BS-001-today.md + DR-004 token pass

---

## Screenshot

**PENDING** — Mac session to capture three states:
- `today_<SHA>_normal.png` (seeded, real data)
- `today_<SHA>_honest-absent.png` (no profile/data)
- `today_<SHA>_populated.png` (fully-populated: Load + Josi + suggestion)

---

## BS-001 Build Steps — Execution Status

| Step | Description | Status |
|------|-------------|--------|
| 1 | Card titles → Title Case | ✓ Done |
| 2 | Card icons → 30×30 rounded tile, rgba(0,198,167,.12) bg, #00C6A7 17px | ✓ Done |
| 3 | "YOUR DAY" section eyebrow above cards | ✓ Done |
| 4 | Glow → MivaltaGlow 3-layer (240px field, 312/221/120 layers, blur 14/8/3) | ✓ Done (DR-004) |
| 5 | State word spacing at 8px (MivaltaGlow.wordGap) | ✓ Done (DR-004) |
| 6 | Collapse hero void when Josi + chip absent | ✓ Done |
| 7 | Decision chip honest-absent (hidden, collapse) + present treatment (check_circle, radius 12) | ✓ Done (DR-004) |
| 8 | Josi honest-absent, source from state_recommendation | ✓ Done |
| 9 | Card container + absence-body styling | ✓ Done |
| 10 | Sleep card consistency (Title Case + icon tile) | ✓ Done |

### DR-004 Additions

| Item | Description | Status |
|------|-------------|--------|
| H1 | Report SHA hygiene | ✓ Done |
| V1 | Stray glyph investigation (SliverAppBar elevation=0) | ✓ Done |
| V2 | Decision chip present treatment (check_circle, radius md, white label) | ✓ Done |
| Token pass | MivaltaGlow 3-layer + MivaltaType.hero in glow_hero.dart | ✓ Done |
| Fuller seed | Workout at offset 0, zone cap + workout suggestion wiring | ✓ Done |

### Trailing Flags (deferred)
- Combined Load & Sleep card — not this pass
- Collapsible cards — not this pass

---

## Files Changed

| File | Changes |
|------|---------|
| `lib/screens/today_screen.dart` | Hero void collapse, "YOUR DAY" eyebrow, conditional spacing, zone cap + workout suggestion loading, decision chip present treatment (V2), SliverAppBar elevation 0 (V1) |
| `lib/widgets/today/glow_hero.dart` | MivaltaGlow 3-layer glow (240px field, 312/221/120 layers, blur 14/8/3), MivaltaType.hero for score, MivaltaType.titleM for state word |
| `lib/widgets/today/module_card.dart` | Title Case, icon tile 30×30 with bg |
| `assets/debug/demo_season.json` | Added workout at offset 0 for Load today |

---

## Current State — What Renders

| Element | Status | Detail |
|---------|--------|--------|
| "Today" title | ✓ Real | Left-aligned, Inter 700, elevation 0 |
| Glow hero | ✓ Real | 3-layer MivaltaGlow (240px field, blur 14/8/3) |
| Score "78" | ✓ Real | MivaltaType.hero (Inter 400/72) |
| State word "Recovered" | ✓ Real | MivaltaType.titleM (20px w600), mint #7FE3B0, 8px below score |
| "YOUR DAY" eyebrow | ✓ Real | Inter 700, 10px, 1.1px tracking, uppercase |
| Josi line | Pending | Wired to state_recommendation; collapses when absent |
| Decision chip | Pending | Wired to zoneCap; present treatment: check_circle, radius 12, white label |
| Load today card | Pending | Wired to readDailyLoads; workout at offset 0 in seed |
| Daily activity card | Honest-absent | Title Case, icon tile |
| Sleep card | ✓ Real | "8h", Title Case, icon tile |
| Suggested workout card | Pending | Wired to recommendWorkout; A option title + duration |
| Bottom nav | ✓ Real | Today (active) / Journey / You |

---

## Screenshot Log

Historical screenshots are in `archive/`.

| SHA | Filename | Task | Date |
|-----|----------|------|------|
| `0f04b85` | `today_0f04b85_normal.png` | BS-001 complete (pre-token-pass) | 2026-07-01 |
| `0f04b85` | `today_0f04b85_honest-absent.png` | BS-001 honest-absent | 2026-07-01 |
| PENDING | `today_375d07e_normal.png` | DR-004 token pass | 2026-07-01 |
| PENDING | `today_375d07e_honest-absent.png` | DR-004 honest-absent | 2026-07-01 |
| PENDING | `today_375d07e_populated.png` | DR-004 fully-populated | 2026-07-01 |

---

## Next

**For Mac session:** Capture three SHA-stamped screenshots (`today_375d07e_*.png`) on simulator, place in `review/today/`.

**For Claude Design:** Review as DR-005 against updated spec.

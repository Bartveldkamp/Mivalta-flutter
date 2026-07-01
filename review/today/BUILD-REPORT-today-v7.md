STATUS: ACTIVE

# Today Screen — Build Report v7

**Live build as of SHA `1e133d8`.**

**Branch:** `feature/today-fresh-build`
**Date:** 2026-07-01
**Spec:** BS-001 + DR-004–DR-009 (prior passes) + BS-002-today.md (masthead) + **DR-012-today.md** (chip false-positive fix)

**Status:** DR-012 complete. Z8 ceiling no longer renders as decision chip.

---

## Screenshots — CAPTURED (SHA-matched)

| State | Filename | What renders |
|-------|----------|--------------|
| Normal | `today_1e133d8_normal.png` | BS-002 masthead, Score 84/Productive, glow, **no chip** (Z8 suppressed), cards |

DR-012: chip is now absent for Z8 ceiling. No system dialogs, full UI visible.

---

## BS-002 — Two-tier Masthead (NEW)

**Spec:** BS-002-today.md (Bart-approved variant 1b)

| Item | Description | Status |
|------|-------------|--------|
| Row 1 | Logo 22×22 + "MiValta" Zen Dots 19px, **centered** | ✓ Done |
| Row 2 | "Start workout" (primaryGreen #1DBF60) left · weather right | ✓ Done |
| Logo↔wordmark gap | 9px | ✓ Done |
| Brand↔micro-row gap | 12px (MivaltaSpace.x3) | ✓ Done |
| Masthead↔glow gap | 24px (MivaltaSpace.x5) | ✓ Done |
| Start workout | play_arrow 18px + "Start workout" Inter 600 13px, primaryGreen | ✓ Done |
| Weather | Live data or "Sunny 18°" placeholder | ✓ Done |
| Font | GoogleFonts.zenDots() | ✓ Done |

**Replaces:** DR-010 single-row top bar (logo left, workout button right).

**Note:** `_startWorkout()` is a TODO stub — acceptable per BS-002; wire when workout flow exists.

---

## DR-012 — Decision Chip False-Positive Fix (NEW)

**Spec:** DR-012-today.md

| Item | Description | Status |
|------|-------------|--------|
| Problem | "Max power · Z8" renders as a decision — false positive | ✓ Fixed |
| Root cause | Z8 is the ceiling (no restriction), not a cap | ✓ Identified |
| Fix | `_isRestrictiveCap` helper: only Z1–Z7 + REST are restrictive | ✓ Implemented |
| Render gate | `showChip = !insufficientData && (restrictiveCap \|\| hasSession)` | ✓ Updated |
| Spacer logic | Uses same `showChip` condition for void-collapse | ✓ Fixed |

**Result:** Decision chip no longer renders when zoneCap is Z8 (ceiling).

---

## Prior Work (BS-001 + DR-004–DR-009)

All items from v6 remain complete:

- BS-001 Steps 1–10: cards, glow, chip, absence treatments
- DR-004: token pass, chip present treatment
- DR-005: glow 280px, responsive, chip level-name
- DR-008: portrait-only, hero 56px, glow 340px
- DR-009: D1 (glow centered), D2 (halo alpha), D3 ("Learning" label)

---

## Files Changed (this pass)

| File | Changes |
|------|---------|
| `lib/screens/today_screen.dart` | BS-002 `_buildMasthead()` replaces `_buildTopBar()`; removed `_LogoWordmark`, `_WorkoutButton`, `_WeatherChip`; added `_buildWeatherSlot()`, `_iconForWeatherSymbol()`, `_conditionForSymbol()`. **DR-012:** added `_isRestrictiveCap()` helper; rewrote chip render gate + spacer to suppress Z8 ceiling. |

---

## Current State — What Renders

| Element | Status | Detail |
|---------|--------|--------|
| Masthead Row 1 | ✓ Real | Logo + "MiValta" centered, Zen Dots 19px |
| Masthead Row 2 | ✓ Real | "Start workout" green left, "Sunny 18°" right |
| Glow hero | ✓ Real | 3-layer MivaltaGlow (340px field), centered on number |
| Score "84" | ✓ Real | MivaltaType.hero (Inter 400/56px) |
| State word "Productive" | ✓ Real | MivaltaType.titleM, teal #00C6A7 |
| Decision chip | ✓ Absent | DR-012: Z8 is ceiling, not restriction — chip suppressed |
| "YOUR DAY" eyebrow | ✓ Real | Inter 700, 10px, uppercase |
| Load today card | ✓ Real | "Training load 59 UL" |
| Daily activity card | Honest-absent | Title Case, icon tile |
| Sleep card | ✓ Real | "8h", Title Case, icon tile |
| Suggested workout card | Honest-absent | Wired but engine returns null |
| Bottom nav | ✓ Real | Today (active) / Journey / You |

---

## Screenshot Log

| SHA | Filename | Task | Date |
|-----|----------|------|------|
| `1e133d8` | `today_1e133d8_normal.png` | **DR-012 — Z8 chip suppressed** | 2026-07-01 |
| `833361d` | `today_833361d_normal.png` | BS-002 masthead — DR-011 pixel confirmation | 2026-07-01 |
| `833361d` | `today_833361d_honest-absent.png` | BS-002 honest-absent | 2026-07-01 |
| `f9b7eff` | `today_f9b7eff_*.png` | DR-009 — glow centered (D1/D2/D3) | 2026-07-01 |
| `66addc5` | `today_66addc5_*.png` | DR-008 — hero 56, glow 340 | 2026-07-01 |
| `0433243` | `today_dr005_*.png` | DR-005 — glow 280, chip level-name | 2026-07-01 |

Historical screenshots in `archive/`.

---

## Next

**Completed:** DR-012 — Z8 ceiling no longer renders as decision chip.

**Remaining gaps (engine domain, not UI):**
- Josi line: engine doesn't return stateRecommendation for this athlete state
- Suggested workout: engine returns null for this athlete state
- Weather: WeatherKit not configured (placeholder renders correctly)

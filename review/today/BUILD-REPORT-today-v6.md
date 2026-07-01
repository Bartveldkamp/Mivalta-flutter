STATUS: ACTIVE

# Today Screen — Build Report v6

**Live build as of SHA `d73aee1`.**

**Branch:** `feature/today-fresh-build`
**Date:** 2026-07-01
**Spec:** BS-001-today.md + DR-004 token pass + DR-005 handoff

---

## Screenshots — CAPTURED

Two states captured for DR-005/DR-006:

| State | Filename | What renders |
|-------|----------|--------------|
| Normal | `today_dr005_normal.png` | Score 84/Productive, "Max power · Z8" chip, Load 59 UL, Sleep 8h, 280px glow |
| Honest-absent | `today_dr005_honest-absent.png` | Glow only (no score), all cards show absence treatments |

### Key changes from DR-005 handoff

**Glow:** 280px field (was 240px) — fuller breathing field
**Chip:** "Max power · Z8" (was bare "Z8") — zone-to-level-name mapping
**Responsive:** glow scales 70% landscape, 85% small screens (<390px)

### What renders (populated)
- Score 84 / Productive (populated ✓)
- Decision chip "Max power · Z8" with check_circle icon (populated ✓)
- Load today: 59 UL (populated ✓)
- Sleep: 8h (populated ✓)

**Still absent (engine returns null for this state):**
- Josi line (stateRecommendation empty)
- Suggested workout (recommendWorkout returns null/empty suggestions)

---

## BS-001 Build Steps — Execution Status

| Step | Description | Status |
|------|-------------|--------|
| 1 | Card titles → Title Case | ✓ Done |
| 2 | Card icons → 30×30 rounded tile, rgba(0,198,167,.12) bg, #00C6A7 17px | ✓ Done |
| 3 | "YOUR DAY" section eyebrow above cards | ✓ Done |
| 4 | Glow → MivaltaGlow 3-layer (280px field, 364/258/140 layers, blur 14/8/3) | ✓ Done (DR-005) |
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
| Screenshots | Three states captured | ✓ Done |

### DR-005 Handoff Items

| Item | Description | Status |
|------|-------------|--------|
| Glow-280 | Increase fieldSize 240 → 280 (tokens.dart) | ✓ Done |
| Responsive | Landscape 70%, small screens 85% (glow_hero.dart) | ✓ Done |
| Chip level-name | Zone codes → human text (Z8 → "Max power · Z8") | ✓ Done |
| Screenshots | Two states captured | ✓ Done |

### Trailing Flags (deferred)
- Combined Load & Sleep card — not this pass
- Collapsible cards — not this pass

---

## Files Changed

| File | Changes |
|------|---------|
| `lib/screens/today_screen.dart` | Hero void collapse, "YOUR DAY" eyebrow, conditional spacing, zone cap + workout suggestion loading, decision chip present treatment (V2), SliverAppBar elevation 0 (V1), **DR-005: zone-to-level-name mapping (_formatZoneDecision)** |
| `lib/widgets/today/glow_hero.dart` | MivaltaGlow 3-layer glow, MivaltaType.hero for score, MivaltaType.titleM for state word, **DR-005: responsive sizing (landscape 70%, SE 85%)** |
| `lib/theme/tokens.dart` | **DR-005: MivaltaGlow.fieldSize 240 → 280** |
| `lib/widgets/today/module_card.dart` | Title Case, icon tile 30×30 with bg |
| `assets/debug/demo_season.json` | Added workout at offset 0 for Load today |

---

## Current State — What Renders

| Element | Status | Detail |
|---------|--------|--------|
| "Today" title | ✓ Real | Left-aligned, Inter 700, elevation 0 |
| Glow hero | ✓ Real | 3-layer MivaltaGlow (280px field, blur 14/8/3), responsive |
| Score "84" | ✓ Real | MivaltaType.hero (Inter 400/88) |
| State word "Productive" | ✓ Real | MivaltaType.titleM (20px w600), teal #00C6A7, 8px below score |
| "YOUR DAY" eyebrow | ✓ Real | Inter 700, 10px, 1.1px tracking, uppercase |
| Josi line | Honest-absent | Wired to state_recommendation; engine returns null |
| Decision chip | ✓ Real | "Max power · Z8" — check_circle, radius 12, white label |
| Load today card | ✓ Real | "Training load 59 UL" |
| Daily activity card | Honest-absent | Title Case, icon tile |
| Sleep card | ✓ Real | "8h", Title Case, icon tile |
| Suggested workout card | Honest-absent | Wired but engine returns null |
| Bottom nav | ✓ Real | Today (active) / Journey / You |

---

## Screenshot Log

Historical screenshots are in `archive/`.

| SHA | Filename | Task | Date |
|-----|----------|------|------|
| `0f04b85` | `today_0f04b85_normal.png` | BS-001 complete (pre-token-pass) | 2026-07-01 |
| `0f04b85` | `today_0f04b85_honest-absent.png` | BS-001 honest-absent | 2026-07-01 |
| `3376e69` | `today_3376e69_normal.png` | DR-004 token pass — populated | 2026-07-01 |
| `3376e69` | `today_3376e69_honest-absent.png` | DR-004 honest-absent | 2026-07-01 |
| `3376e69` | `today_3376e69_populated.png` | DR-004 populated (same as normal) | 2026-07-01 |
| `d73aee1` | `today_dr005_normal.png` | DR-005 handoff — glow 280, chip level-name | 2026-07-01 |
| `d73aee1` | `today_dr005_honest-absent.png` | DR-005 honest-absent | 2026-07-01 |

---

## Next

**For Claude Design:** Review as DR-006 against this build.

**Remaining gaps (engine domain, not UI):**
- Josi line: engine doesn't return stateRecommendation for this athlete state
- Suggested workout: engine doesn't return suggestions for this athlete state

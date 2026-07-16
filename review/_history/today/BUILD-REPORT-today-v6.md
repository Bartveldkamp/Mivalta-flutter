STATUS: ACTIVE

# Today Screen — Build Report v6

**Live build as of SHA `f9b7eff`.**

**Branch:** `feature/today-fresh-build`
**Date:** 2026-07-01
**Spec:** BS-001-today.md + DR-004 token pass + DR-005 handoff + DR-008/DR-009 glow fixes

**Status:** Design-matched for beta (portrait). All DR-008 deltas closed.

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

### DR-008 / DR-009 Final Pass

| Item | Description | Status |
|------|-------------|--------|
| Portrait-only | Lock iOS + Android to portrait (beta); landscape deferred | ✓ Done (66addc5) |
| Hero-56 | Hero font 60px → 56px | ✓ Done |
| Glow-340 | fieldSize 300 → 340 | ✓ Done |
| D1 | Center glow core on number (offset -16px when state word present) | ✓ Done (f9b7eff) |
| D2 | Raise inner/mid halo scale/alpha (inner 0.60/0.70, mid 1.0/0.48) | ✓ Done |
| D3 | Honest "Learning" label for absent-hero | ✓ Done |
| Screenshots | Three states captured at f9b7eff | ✓ Done |

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
| `0433243` | `today_dr005_normal.png` | DR-005 handoff — glow 280, chip level-name | 2026-07-01 |
| `0433243` | `today_dr005_honest-absent.png` | DR-005 honest-absent | 2026-07-01 |
| `66addc5` | `today_66addc5_normal.png` | DR-008 — hero 56, glow 340, portrait-only | 2026-07-01 |
| `66addc5` | `today_66addc5_populated.png` | DR-008 populated | 2026-07-01 |
| `66addc5` | `today_66addc5_honest-absent.png` | DR-008 honest-absent | 2026-07-01 |
| `f9b7eff` | `today_f9b7eff_normal.png` | DR-009 — glow centered on number (D1/D2/D3) | 2026-07-01 |
| `f9b7eff` | `today_f9b7eff_populated.png` | DR-009 populated | 2026-07-01 |
| `f9b7eff` | `today_f9b7eff_honest-absent.png` | DR-009 — "Learning" label (D3) | 2026-07-01 |

---

## Next

**Today is design-matched for beta (portrait).** DR-008/DR-009 deltas closed.

**Hold for:** Bart's merge gate, then start Advisor (BS-002).

**Remaining gaps (engine domain, not UI):**
- Josi line: engine doesn't return stateRecommendation for this athlete state
- Suggested workout: engine doesn't return suggestions for this athlete state

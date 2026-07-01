STATUS: ACTIVE

# Today Screen — Build Report v10

**Live build as of SHA `622ad55`.**

**Branch:** `feature/bs004-typescale` (contains BS-004, BS-005, BS-006)
**Date:** 2026-07-01
**Spec:** BS-006-sleep-ring.md — SleepStageRing for Sleep card

**Status:** BS-006 widget complete. Shows honest-absent variant (engine lacks stage data). `placeholder ⚠`

---

## Screenshots — PENDING

| State | Filename | What renders |
|-------|----------|--------------|
| Scrolled | _pending_ | Load MetricBar + Sleep honest-absent ring |
| Honest-absent | _pending_ | Sleep ring outline + "No sleep data" + "Connect a sleep tracker" |

**Note:** Screenshots required after hot-reload on simulator.

---

## BS-006 — SleepStageRing (NEW)

**Spec:** BS-006-sleep-ring.md

### New Widget: `SleepStageRing`
Located at `lib/widgets/today/sleep_stage_ring.dart`

| Component | Description |
|-----------|-------------|
| `SleepStages` model | deepMinutes, remMinutes, lightMinutes, awakeMinutes |
| `SleepStageRing` widget | Full 360° ring + center total + legend |
| `_SleepRingPainter` | CustomPainter for stage arcs |
| `_EmptyRingPainter` | Full outline for honest-absent |
| `_LegendRow` | Colored dot + label + minutes |

### Color Tokens Added (tokens.dart)

| Token | Hex | Usage |
|-------|-----|-------|
| `sleepDeep` | #2C6C8F | Deep sleep arc |
| `sleepRem` | #00C6A7 | REM sleep arc |
| `sleepLight` | #7FE3B0 | Light sleep arc |
| `sleepAwake` | #3A4048 | Awake arc |

### Draw Order
Per spec: Deep → REM → Light → Awake (clockwise from top, -90°)

### Sleep Card States

| State | Renders |
|-------|---------|
| With stages | Full ring + center time + legend |
| Without stages | Outline ring + "No sleep data" + "Connect a sleep tracker" |

**Current state: Honest-absent** (engine lacks per-stage data)

---

## Files Changed (this pass)

| File | Changes |
|------|---------|
| `lib/theme/tokens.dart` | Added sleepDeep, sleepRem, sleepLight, sleepAwake color tokens |
| `lib/widgets/today/sleep_stage_ring.dart` | NEW: SleepStageRing widget + CustomPainter |
| `lib/screens/today_screen.dart` | Replace Sleep MetricBar with SleepStageRing; remove unused methods |

---

## Honesty Bindings (per spec §3)

| Field | Source | Status |
|-------|--------|--------|
| Sleep stages | Engine per-stage minutes | **Missing** — placeholder ⚠ |
| Total sleep | `readBiometricHistory(days: 1).sleep_hours` | Real (but unused in ring) |
| Sleep need | Profile sleep_need | Partial |
| Source tier | `lastObservationSourceTier()` | Real |

---

## Current State — What Renders

| Element | Status | Detail |
|---------|--------|--------|
| Load card | Unchanged | MetricBar from BS-005 |
| Daily activity | Unchanged | Honest-absence card |
| Sleep card | **Updated** | SleepStageRing honest-absent variant |
| Suggested workout | Unchanged | Honest-absence (engine returns null) |

---

## Screenshot Log

| SHA | Filename | Task | Date |
|-----|----------|------|------|
| `622ad55` | _pending_ | BS-006 — SleepStageRing | 2026-07-01 |
| `29d4b5c` | `today_29d4b5c_scrolled.png` | DR-013 — Sleep card witness | 2026-07-01 |
| `b6001e6` | `today_b6001e6_normal.png` | BS-005 — MetricBar | 2026-07-01 |
| `c9f4b4b` | `today_c9f4b4b_normal.png` | BS-004 — type scale bump | 2026-07-01 |

---

## Prior Work

All items from v9 remain complete:
- BS-005: MetricBar for Load card
- BS-004: Type scale bump to iOS-native base
- BS-002: Two-tier masthead
- BS-001: Cards, glow, chip, absence treatments
- DR-004–DR-013: Token pass, chip treatment, glow tuning

---

## Next

**Completed:** BS-006 — SleepStageRing widget implemented.

**Awaiting:**
1. Hot-reload app and capture scrolled screenshot
2. Design Review (DR) for BS-006 screenshot

**Gaps flagged:**
- `placeholder ⚠` — Engine lacks per-stage sleep minutes; honest-absent renders
- Once engine provides stage data, wire to SleepStageRing

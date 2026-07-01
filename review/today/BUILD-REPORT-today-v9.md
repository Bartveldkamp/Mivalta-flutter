STATUS: ACTIVE

# Today Screen — Build Report v9

**Live build as of SHA `b6001e6`.**

**Branch:** `feature/bs004-typescale` (contains BS-004 + BS-005)
**Date:** 2026-07-01
**Spec:** BS-005-biometric-cards.md — MetricBar for Load/Sleep cards

**Status:** BS-005 complete. Load and Sleep cards now use DS-compliant MetricBar widget.

---

## Screenshots — CAPTURED (SHA-matched)

| State | Filename | What renders |
|-------|----------|--------------|
| Normal | `today_b6001e6_normal.png` | Load card: "59 / 58" + teal bar + "Training load · Partial data" |
| Scrolled | `today_29d4b5c_scrolled.png` | **All 4 cards visible:** Load MetricBar, Daily activity (absence), Sleep MetricBar "8h" + "100% of target", Suggested workout (absence) |

**Note:** Honest-absent screenshot deferred — requires engine state without Load/Sleep data.

### DR-013 witness gap closed
- **Sleep card visible:** "8h" bold + muted unit, recovered-green bar at 100%, scale "0h" to "need · 8h", caption "100% of your target · Partial data"

---

## BS-005 — MetricBar for Biometric Cards (NEW)

**Spec:** BS-005-biometric-cards.md

### New Widget: `MetricBar`
Located at `lib/widgets/today/metric_bar.dart`

| Prop | Description |
|------|-------------|
| `value` | The counted value (numeric) |
| `max` | Denominator for bar fill |
| `valueWidget` | Rich markup (e.g., SleepDuration "7h 42m") |
| `ceiling` | Shown as "/ ceiling" beside value |
| `color` | Bar fill color |
| `scaleStart` / `scaleEnd` | Scale markers at bar ends |
| `caption` | Context text below bar |

### Load today card
| Item | Value | Status |
|------|-------|--------|
| Number | Bold, MivaltaType.metric (32px) | Done |
| Ceiling | ACWR chronic_load from engine | Done |
| Bar | Teal (#00C6A7), fill = value/ceiling | Done |
| Scale | "0" to "<ceiling>" | Done |
| Caption | Band line + source tier | Done |

### Sleep card
| Item | Value | Status |
|------|-------|--------|
| Number | Rich "7h 42m" via SleepDuration widget | Done |
| Bar | Recovered-green (#7FE3B0), fill = slept/need | Done |
| Scale | "0h" to "need · 8h" | Done |
| Caption | "N% of your target" + source tier | Done |

### Daily activity card
| Item | Status |
|------|--------|
| Honest-absence | Unchanged ("No activity data / Connect a health source…") |

---

## Files Changed (this pass)

| File | Changes |
|------|---------|
| `lib/widgets/today/metric_bar.dart` | NEW: MetricBar + SleepDuration widgets |
| `lib/models/home_data.dart` | Added loadCeiling, loadBandLine, sleepNeedHours, sourceTierLabel fields |
| `lib/screens/today_screen.dart` | Load/Sleep cards use MetricBar; fetch ACWR + source tier; removed _formatSleep |

---

## Honesty Bindings (per spec §3)

| Field | Source | Status |
|-------|--------|--------|
| Load value | `readDailyLoads(days: 1)` | Real |
| Load ceiling | `getAcwr().chronic_load` | Real |
| Load band line | `getAcwr().recommendation` | Real |
| Sleep hours | `readBiometricHistory(days: 1).sleep_hours` | Real |
| Sleep need | Profile (default 8h if not set) | Partial |
| Source tier | `lastObservationSourceTier()` | Real |

---

## Current State — What Renders

| Element | Status | Detail |
|---------|--------|--------|
| Load card | Updated | MetricBar: "59 / 58" + full teal bar + "Training load · Partial data" |
| Sleep card | Updated | MetricBar: rich duration + recovered-green bar + need scale |
| Daily activity | Unchanged | Honest-absence card |
| Suggested workout | Unchanged | Honest-absence (engine returns null) |

---

## Screenshot Log

| SHA | Filename | Task | Date |
|-----|----------|------|------|
| `29d4b5c` | `today_29d4b5c_scrolled.png` | **DR-013 — Sleep card witness** | 2026-07-01 |
| `b6001e6` | `today_b6001e6_normal.png` | BS-005 — MetricBar | 2026-07-01 |
| `c9f4b4b` | `today_c9f4b4b_normal.png` | BS-004 — type scale bump | 2026-07-01 |
| `1e133d8` | `today_1e133d8_normal.png` | DR-012 — Z8 chip suppressed | 2026-07-01 |

---

## Prior Work

All items from v8 remain complete:
- BS-004: Type scale bump to iOS-native base
- BS-002: Two-tier masthead
- BS-001: Cards, glow, chip, absence treatments
- DR-004–DR-012: Token pass, chip treatment, glow tuning

---

## Next

**Completed:** BS-005 — Load/Sleep cards use DS MetricBar widget.

**Awaiting:** Design Review (DR) for BS-005 screenshot.

**Gaps flagged:**
- Honest-absent screenshot not captured (needs fresh engine state)
- Sleep need from profile not wired (using 8h default)

STATUS: ACTIVE
**Spec:** BS-006-sleep-ring.md · **SHA:** `b4e6d45` · **placeholder ⚠**

# Today Screen — Build Report v10

**Live build as of SHA `b4e6d45`.**

**Branch:** `feature/dr014-d6-stamp` (D6 dart-define stamp fix)
**Date:** 2026-07-02
**Spec:** BS-006-sleep-ring.md — SleepStageRing for Sleep card

**Status:** BS-006 widget complete. Shows honest-absent variant. `placeholder ⚠`

**D6 build stamp:** Uses `--dart-define=BUILD_SHA=$(git rev-parse --short HEAD)` at runtime.

---

## Engine Stage Accessor — GAP-001 §G1

**Accessor attempted:** `readBiometricHistory(days: 1)` returns `sleep_hours` only.

**What exists:** Engine normalizer aggregates `sleep_stages[]` / `sleep_samples[]` → single `sleep_hours`. Raw stage arrays stored via `write_raw_observation` but no FFI returns per-stage minutes.

**What's needed:** `read_sleep_stages(date)` FFI to aggregate per-stage minutes from stored raw payloads, OR persist per-stage minutes on `VaultBiometric` at normalize time.

**Result:** Without per-stage data, `SleepStageRing` renders honest-absent variant. **No fabrication from `sleep_hours`** — genuineness gate honoured.

---

## Screenshots — PENDING

| State | Filename | What renders |
|-------|----------|--------------|
| Scrolled | `today_f2ac5ed_scrolled.png` | Load MetricBar + Sleep honest-absent ring + build stamp |

**Captured:** 2026-07-02 — Load + Sleep ring + `build f2ac5ed` stamp visible.

---

## BS-006 — SleepStageRing

**Spec:** BS-006-sleep-ring.md

### Widget: `SleepStageRing`
Located at `lib/widgets/today/sleep_stage_ring.dart`

| Component | Description |
|-----------|-------------|
| `SleepStages` model | deepMinutes, remMinutes, lightMinutes, awakeMinutes |
| `SleepStageRing` widget | Full 360° ring + center total + legend |
| `_SleepRingPainter` | CustomPainter for stage arcs |
| `_EmptyRingPainter` | Full outline for honest-absent |
| `_LegendRow` | Colored dot + label + minutes |

### Color Tokens (tokens.dart)

| Token | Hex | Usage |
|-------|-----|-------|
| `sleepDeep` | #2C6C8F | Deep sleep arc |
| `sleepRem` | #00C6A7 | REM sleep arc |
| `sleepLight` | #7FE3B0 | Light sleep arc |
| `sleepAwake` | #3A4048 | Awake arc |

### Draw Order vs Legend Order (DR-014 D1)
- **Draw order:** Deep → REM → Light → Awake (clockwise from top, -90°)
- **Legend order:** Light / REM / Deep / Awake (per spec + DR-014)

### Sleep Card States

| State | Renders |
|-------|---------|
| With stages | Full ring + center time + legend (Light/REM/Deep/Awake) |
| Without stages | Outline ring + "No sleep data" + "Connect a sleep tracker" |

**Current state: Honest-absent** (engine lacks per-stage data — GAP-001 §G1)

---

## Files Changed

| File | Changes |
|------|---------|
| `lib/theme/tokens.dart` | Added sleepDeep, sleepRem, sleepLight, sleepAwake color tokens |
| `lib/widgets/today/sleep_stage_ring.dart` | SleepStageRing widget + CustomPainter; DR-014 D1 legend order fix |
| `lib/screens/today_screen.dart` | Replace Sleep MetricBar with SleepStageRing; remove unused methods |

---

## Honesty Bindings

| Field | Source | Status |
|-------|--------|--------|
| Sleep stages | Engine per-stage minutes | **Missing** — placeholder ⚠ (GAP-001 §G1) |
| Total sleep | `readBiometricHistory(days: 1).sleep_hours` | Real (unused — no fabrication) |
| Sleep need | Profile sleep_need | Partial |
| Source tier | `lastObservationSourceTier()` | Real |

---

## DR-014 Fixes Applied

| ID | Fix | Status |
|----|-----|--------|
| D1 | Legend order Light/REM/Deep/Awake | Done @ `b4e6d45` |
| D2 | Ring proportion (verify in render) | Not blocking |
| D3 | BUILD-REPORT with accessor + placeholder ⚠ | This file |
| D4 | SHA handshake (report ↔ screenshot) | Fixed — both use `b4e6d45` |
| D6 | kDebugMode build stamp on Today | Done @ `b4e6d45` |

---

## Screenshot Log

| SHA | Filename | Task | Date |
|-----|----------|------|------|
| `f2ac5ed` | `today_f2ac5ed_scrolled.png` | BS-006 + DR-014 D1–D6 | 2026-07-02 |
| `29d4b5c` | `today_29d4b5c_scrolled.png` | DR-013 — Sleep card witness | 2026-07-01 |
| `b6001e6` | `today_b6001e6_normal.png` | BS-005 — MetricBar | 2026-07-01 |
| `c9f4b4b` | `today_c9f4b4b_normal.png` | BS-004 — type scale bump | 2026-07-01 |

---

## Next

**Completed:** BS-006 + DR-014 D1/D3/D4.

**Awaiting:**
1. Scrolled screenshot `today_b4e6d45_scrolled.png` (Load MetricBar + Sleep honest-absent ring)
2. DR-014 close

**Merge intent:** After DR-014 closes, merge `feature/bs004-typescale` → `main`.

**Then:** `review/auth/BS-001-auth.md` — Auth account screen

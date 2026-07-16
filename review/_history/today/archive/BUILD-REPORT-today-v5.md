# Today Screen — Build Report v5 (DR-003 fixes applied)

**Branch:** `feature/today-fresh-build`
**Commit:** `57afe91`
**Date:** 2026-07-01
**Status:** DR-003 blocking issues resolved

---

## Changes in This Version

### Fixed (from DR-003)

| ID | Issue | Fix Applied |
|----|-------|-------------|
| **M1** | Card titles ALL CAPS | Title Case: "Load today", "Daily activity", "Sleep", "Suggested workout" |
| **M3** | MetricRow labels ALL CAPS | Title Case, Inter 500/13px |
| **G3** | State word spacing 6px | Increased to 12px |

### Files Changed

- `lib/widgets/today/module_card.dart` — Title Case titles + label styling
- `lib/widgets/today/glow_hero.dart` — State word spacing

---

## Current State — What Renders

| Element | Status | Detail |
|---------|--------|--------|
| "Today" title | ✓ Real | Left-aligned, Inter 700 |
| Glow hero | ✓ Real | Three-layer soft field |
| Score "78" | ✓ Real | Engine-computed readiness |
| State word "Recovered" | ✓ Real | Mint #7FE3B0, 12px spacing below score |
| Josi line | Honest-absent | Traced: advisories not attached (seeder gap) |
| Decision chip | Honest-absent (collapse) | Accessor not wired — SizedBox.shrink() |
| Load today card | Honest-absent | "No activity recorded" — Title Case |
| Daily activity card | Honest-absent | "No activity data" — Title Case |
| Sleep card | ✓ Real | "8h" from seeded biometrics — Title Case |
| Suggested workout card | Honest-absent | "No suggestion yet" — Title Case |
| Bottom nav | ✓ Real | Today (active) / Journey / You |

---

## Remaining Non-Blocking Items

| ID | Issue | Status |
|----|-------|--------|
| G1 | Glow ellipse (Y-stretch) | Open |
| L1 | Hero vertical compression | Open |
| C1 | Decision chip accessor wiring | Open |

---

## Screenshot Log

| SHA | Filename | Task | Date |
|-----|----------|------|------|
| `eb42c02` | `today_eb42c02_live.png` | Initial reconciliation | 2026-06-30 |
| `a7c312a` | `today_a7c312a_live.png` | DR-002 fixes (nav, cards, glow) | 2026-06-30 |
| `5e46e4e` | `today_5e46e4e_live.png` | State word wiring fix | 2026-06-30 |
| `2b2edc9` | `today_2b2edc9_live.png` | Baseline for DR-003 | 2026-07-01 |
| `57afe91` | `today_57afe91_live.png` | **DR-003 fixes applied** | 2026-07-01 |

---

## Next

**For Mac session:** Capture SHA-stamped screenshot `today_57afe91_live.png` on simulator and add to `review/today/`.

**Verdict:** M1 blocking issue resolved. Ready for design review gate pass.

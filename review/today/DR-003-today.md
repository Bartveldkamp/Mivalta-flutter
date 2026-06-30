# DR-003 — Today Screen Design Review

**SHA:** `e8e44f2`
**Screenshot:** `today_5e46e4e_live.png`
**Date:** 2026-06-30
**Status:** Review complete

---

## Summary

The state-word wiring bug is fixed. The screen now correctly displays engine state. Several design refinements needed before "matches."

---

## Hero Zone

### Score + State Word ✓ PASS

| Element | Expected | Actual | Verdict |
|---------|----------|--------|---------|
| Score | 78 | 78 | ✓ |
| State word | "Recovered" | "Recovered" | ✓ |
| State color | #7FE3B0 (mint) | #7FE3B0 | ✓ |
| Font | Inter | Inter | ✓ |
| Score size | ~42px | 42px | ✓ |

### Glow Field — NEEDS REFINEMENT

| Issue | Detail | Priority |
|-------|--------|----------|
| **G1** | Glow field is circular but design spec shows elliptical/oval stretch on Y-axis | Medium |
| **G2** | Inner core too bright — reduce alpha on innermost gradient stop | Low |
| **G3** | State word should have more vertical separation from score (currently 6px, spec shows ~12px) | Low |

---

## Josi Line — DESIGNED ABSENCE ✓

**Status:** Not rendered (engine returns empty `state_recommendation`)

**Verdict:** This is **correct behavior**. The JosiCard collapses to `SizedBox.shrink()` when line is null/empty. This is the designed honest-absence pattern — no card, no placeholder, no "Josi is thinking..." fabrication.

**Note:** When the engine provides a recommendation, the card will render. No code change needed.

---

## Decision Chip — BUILD GAP (not designed absence)

**Status:** Not rendered (engine accessors not wired)

**Issue:** The decision chip widget exists but requires `zoneCap` or `sessionZone` from additional engine calls (`zoneCapWithAdvisories()`, `sessionWidget()`). These are not yet wired.

| Action | Owner | Priority |
|--------|-------|----------|
| **C1** | Wire `zoneCapWithAdvisories()` to populate `zoneCap` | Code — Medium |
| **C2** | Design fallback: if no zone cap, show nothing (collapse) or show "Ready to train" | Design — decide |

---

## Module Cards

### Honest-Absence Pattern ✓ PASS

All four cards correctly implement the **named + actionable unlock** pattern:

| Card | State Label | Unlock CTA | Verdict |
|------|-------------|------------|---------|
| Load Today | "No activity recorded" | "Log a workout to see your load" | ✓ |
| Daily Activity | "No activity data" | "Connect a health source for steps & movement" | ✓ |
| Sleep | "Last night" / "8h" | (has data — correct) | ✓ |
| Suggested Workout | "No suggestion yet" | "Complete more workouts to unlock AI suggestions" | ✓ |

### Card Styling — REFINEMENTS

| Issue | Detail | Priority |
|-------|--------|----------|
| **M1** | Card titles are ALL CAPS — spec shows Title Case ("Load today" not "LOAD TODAY") | Medium |
| **M2** | Icon tint: all icons are `stateProductive` teal — Sleep icon should be a calmer color when showing data | Low |
| **M3** | Sleep card metric alignment: "8h" right-aligned is correct, but label "LAST NIGHT" should not be all-caps | Low |

---

## Bottom Nav ✓ PASS

| Element | Expected | Actual | Verdict |
|---------|----------|--------|---------|
| Tabs | Today / Journey / You | ✓ | ✓ |
| Active state | Today highlighted | Today in teal | ✓ |
| Inactive state | Muted | Gray | ✓ |
| Icons | Sun / Route / Person | ✓ | ✓ |

**Minor:** Icon style is outlined for inactive, filled for active — this is correct.

---

## Layout & Spacing

| Issue | Detail | Priority |
|-------|--------|----------|
| **L1** | Hero zone takes too much vertical space — large gap between glow and first card | Medium |
| **L2** | Card gap is `x3` (12px) — spec shows `x4` (16px) between cards | Low |
| **L3** | Bottom padding before nav feels tight — add `x4` after last card | Low |

---

## Color Fidelity ✓ PASS

| Token | Expected | Actual | Verdict |
|-------|----------|--------|---------|
| `--surface-background` | #0B0B0D | ✓ | ✓ |
| `--state-recovered` | #7FE3B0 | ✓ | ✓ |
| `--state-productive` | #00C6A7 | ✓ | ✓ |
| `--text-primary` | #FFFFFF | ✓ | ✓ |
| `--text-secondary` | #878C8C | ✓ | ✓ |

---

## Action Items

### Blocking (fix before merge)

| ID | Issue | Owner |
|----|-------|-------|
| **M1** | Card titles: change to Title Case | Code |

### Non-blocking (can iterate post-merge)

| ID | Issue | Owner |
|----|-------|-------|
| G1 | Glow ellipse stretch | Code |
| G3 | State word spacing | Code |
| L1 | Hero vertical compression | Code |
| C1 | Wire decision chip accessors | Code |
| C2 | Decision chip fallback design | Design |

---

## Verdict

**CONDITIONAL PASS** — Fix M1 (card title casing), then ready for next gate.

The honest-absence patterns are correct. The Josi collapse is designed behavior. The chip absence is a known build gap, not a bug.

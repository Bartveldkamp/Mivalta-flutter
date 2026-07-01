STATUS: ACTIVE

# BS-001 — Today Screen Build Steps

**Surface:** Today
**Spec-ID:** BS-001
**Date:** 2026-07-01
**Executed at:** SHA `ee709d7`

---

## Build Steps (ordered)

### Step 1 — Card Titles to Title Case
Card titles: "Load today", "Daily activity", "Sleep", "Suggested workout"
Font: Inter 600, 13px

### Step 2 — Card Icon Tiles
Icons: 30×30 rounded tile
Background: rgba(0,198,167,.12)
Icon: #00C6A7, 17px

### Step 3 — "Your Day" Section Eyebrow
Above module cards
Font: Inter 700, 10px, 1.1px tracking, uppercase
Color: rgba(244,245,244,.45)

### Step 4 — Glow Field
Two-layer soft field:
- Outer: 172px, 12px blur
- Inner: 104px, 2px blur
Color: from state→tone map (Recovered=#7FE3B0, Productive=#00C6A7, etc.)
Shape: Circular (scaleY ≤1.06 only if needed)

### Step 5 — State Word Spacing
Keep at 6px below score.
Do NOT push to 12px — that separates the pair.

### Step 6 — Collapse Hero Void
When Josi + chip are absent, their space collapses.
Cards move up ~20px under the state word.

### Step 7 — Decision Chip Honest-Absent
Hide the chip, collapse its space.
Do NOT wire `zoneCapWithAdvisories` — advisories not attached, wiring now would fabricate.

### Step 8 — Josi Honest-Absent
Josi stays honest-absent.
When it renders, source from `state_recommendation` (not `realize_advisor_line`).

### Step 9 — Card Container Styling
Card container + absence-body styling per exact tokens.

### Step 10 — Sleep Card Consistency
Title Case + icon tile (same pattern as other cards).

---

## Trailing Flags (deferred — not this pass)

- Combined Load & Sleep card
- Collapsible cards

---

## Execution

Executed by Claude Code at SHA `ee709d7` on 2026-07-01.
See BUILD-REPORT-today-v6.md for results.

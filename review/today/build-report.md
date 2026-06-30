# Today Screen — Build Report

**PR**: #122 (draft, held for design review)
**Branch**: `feature/today-design-ui`
**Build date**: 2026-06-30
**Engine pin**: `b7264cb` (v2.29)
**Seeded athlete**: 10 observations, Recovered state

---

## Screenshots

| Screenshot | Description |
|------------|-------------|
| [today-main-2026-06-30.png](today-main-2026-06-30.png) | Today screen — initial build |
| [today_dr001_fixed.png](today_dr001_fixed.png) | Today screen — after DR-001 fixes |

---

## Element → Real Value → Source

| Element | Rendered Value | Engine Source |
|---------|----------------|---------------|
| **GlowHero score** | 78 | `readiness_indicator()` → `indicator['score']` (4-axis blend) |
| **GlowHero state word** | Recovered | `viterbiFatigueState()` → `state` field |
| **Glow color** | #7FE3B0 (stateRecovered) | Mapped from fatigue state via `fatigueStateColor()` |
| **DecisionChip** | "Train as planned" | Engine has workout suggestion (not rest day, not insufficient data) |
| **Workout title** | Endurance Ride | `recommendWorkoutWithHistory()` → `workout_title` |
| **Workout duration** | 90 min | `recommendWorkoutWithHistory()` → `duration_min` |
| **Zone badge** | Endurance | `recommendWorkoutWithHistory()` → `zone` |
| **Zone badge color** | Green tint | `zoneColor()` lookup from zone label |
| **Focus cue** | "Settle into your pace" | `recommendWorkoutWithHistory()` → `focus_cue` |

---

## Honest Absences

| Element | Reason |
|---------|--------|
| **JosiLine** | `realize_advisor_line` returned error: "advisories not attached to state" — engine refused to fabricate |
| **Weather control** | WeatherKit unavailable on simulator (expected) |
| **Load & Sleep metrics** | Card header visible; metrics may be absent or collapsed |

---

## Layout Fixes Applied

- GlowHero container height: increased from `size + 24` to `size + 28` to accommodate state word line height (fixed 1px overflow)

---

## DR-001 Fixes Applied (2026-06-30)

| ID | Fix | Status |
|----|-----|--------|
| **T1** | Hero number → Inter 500, -0.03em, tabular figures (removed Zen Dots) | ✅ Fixed |
| **T2** | State→colour map verified: Recovered = #7FE3B0, Productive = #00C6A7 | ✅ Correct |
| **L1** | App bar → "Today" left-aligned, removed centered "MiValta" wordmark | ✅ Fixed |
| **S1** | Josi line source from `state_recommendation` (not `realize_advisor_line`) | ✅ Fixed |
| **T3** | Chip label near-white (`textPrimary`), icon teal (`tertiaryTealSolid`) | ✅ Fixed |
| **L2** | Daily-activity card first, collapsed by default (honest absence if no data) | ✅ Fixed |
| **L3** | Close empty Josi gap when no recommendation present | ✅ Fixed |
| **G1/G2** | Zone badge gap (engine-side §8.2) | ⏭️ Skipped |

### App Bar Changes (L1)
- Title: "MiValta" → "Today"
- Alignment: `centerTitle: true` → `centerTitle: false`
- Added tune/customize affordance icon (right side)
- Start workout control remains in leading position (left side)

### Typography Changes (T1)
- Hero number font: `GoogleFonts.zenDots` → `GoogleFonts.inter`
- Weight: 500 (medium)
- Letter spacing: -0.03em
- Features: `tabularFigures()`, `liningFigures()`

### Decision Chip Changes (T3)
- Icon color: state-based → teal (`tertiaryTealSolid`) for train states
- Label color: state-based → near-white (`textPrimary`) always

---

## Files Changed

```
lib/widgets/today/
├── decision_chip.dart    # Training decision indicator
├── glow_hero.dart        # Radial gradient hero + score + state
├── josi_line.dart        # Avatar + prose (honest absence when no line)
├── module_card.dart      # Collapsible metric cards
├── today_body.dart       # Main visual layer
└── today_widgets.dart    # Barrel export

lib/theme/tokens.dart     # Extended with Zen Dots, Inter, MivaltaTextStyles
lib/screens/readiness_screen.dart  # Integrated TodayBody
pubspec.yaml              # Added google_fonts: ^6.2.1
```

---

## Design Reference

- `mivalta-design/vision/Today-Modular.html`
- `mivalta-design/vision/Today-Composition.html`
- `mivalta-design/tokens/colors.css`
- `mivalta-design/tokens/typography.css`

---

## Review Checklist (for Claude Design)

### Round 1 (Initial Review)
- [ ] GlowHero: radial gradient matches design (two-layer glow, blur radius)
- [x] GlowHero: score typography — **DR-001 T1: Inter 500, -0.03em, tabular**
- [x] GlowHero: state word position and color — **DR-001 T2: verified correct**
- [x] DecisionChip: border, icon, text styling — **DR-001 T3: teal icon, white label**
- [ ] ModuleCard: header typography, collapse animation
- [x] Spacing: vertical rhythm between elements — **DR-001 L3: no empty Josi gap**
- [x] Colors: exact hex values match design tokens — **DR-001 T2: verified**
- [ ] Font weights: match Inter weight scale

### Round 2 (DR-001 Fixes)
- [x] App bar: "Today" left-aligned, not centered "MiValta" — **DR-001 L1**
- [x] Josi line: source from state_recommendation — **DR-001 S1**
- [x] Daily activity card: first position, collapsed default — **DR-001 L2**
- [ ] G1/G2: Zone badge gap — **engine-side, skipped**

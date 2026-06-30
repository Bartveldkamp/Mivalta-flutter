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
| [today-main-2026-06-30.png](today-main-2026-06-30.png) | Today screen with real engine data |

---

## Element → Real Value → Source

| Element | Rendered Value | Engine Source |
|---------|----------------|---------------|
| **GlowHero score** | 78 | `readiness_indicator()` → `indicator['score']` (4-axis blend) |
| **GlowHero state word** | Recovered | `viterbiFatigueState()` → `state` field |
| **Glow color** | #00C6A7 (stateProductive) | Mapped from fatigue state via `_stateColor()` |
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

- [ ] GlowHero: radial gradient matches design (two-layer glow, blur radius)
- [ ] GlowHero: score typography (Zen Dots, sizing, weight)
- [ ] GlowHero: state word position and color
- [ ] DecisionChip: border, icon, text styling
- [ ] ModuleCard: header typography, collapse animation
- [ ] Spacing: vertical rhythm between elements
- [ ] Colors: exact hex values match design tokens
- [ ] Font weights: match Inter weight scale

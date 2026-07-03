# BUILD-REPORT: Verdict Layer (DR-016)

**Branch:** `feature/bs007-verdict`
**Commit:** `7a51ede`
**Date:** 2026-07-03

## Summary

BS-007 verdict layer implementation: the readiness state verdict (GlowHero),
decision chip (zone cap), and evidence layer (WhyUnfold).

## Screenshots

| State | File | Description |
|-------|------|-------------|
| Hero | `verdict_7a51ede_hero.png` | GlowHero with "84 Productive" + animated glow |
| Glow | `verdict_7a51ede_glow.png` | Alternate hero capture |
| Scrolled | `verdict_7a51ede_scrolled.png` | Decision chip + YOUR DAY cards |

## Implementation

### GlowHero (`widgets/today/glow_hero.dart`)
- 3-ring animated glow (counter-phased halo, 6s loop)
- Readiness score (large number, crossfade animation)
- State label below (Productive/Recovered/Accumulated/Unknown)
- Respects `disableAnimations` for reduced motion

### JosiCard (`widgets/today/josi_card.dart`)
- Primary Josi advice from `realizeAdvisorLine` FFI
- Fallback to `stateRecommendation` from indicator
- **Current state:** Not rendering — `realizeAdvisorLine` returns error
  (advisories not attached in demo seeder)

### WhyUnfold (`widgets/today/why_unfold.dart`)
- "Why?" affordance below JosiCard
- Expands to show readiness contributions
- Each row: label · value · direction glyph (▲/▼/—)
- Staggered row entrance animation (90ms per row)
- **Current state:** Collapses when contributions[] is empty

### Decision Chip
- Shows zone cap (Easy · Z2, Steady · Z3, etc.)
- Only renders for restrictive caps (Z1–Z7, REST)
- Z8 (no restriction) hides the chip
- Checkmark icon indicates session zone

## Engine Dependencies

| Feature | Accessor | Status |
|---------|----------|--------|
| Readiness score | `readiness_indicator()` | Working |
| State label | `readiness_indicator().state` | Working |
| Zone cap | `readiness_indicator().zone_cap` | Working |
| Josi line | `realizeAdvisorLine()` | Stub (advisories missing) |
| Contributions | `readiness_indicator().contributions` | Empty in demo |

## Verification

- [x] GlowHero renders with animated glow
- [x] Readiness score displays correctly (84)
- [x] State label shows "Productive"
- [x] Decision chip renders "Easy · Z2"
- [x] Reduced motion respected
- [ ] JosiCard renders with advice (blocked on engine)
- [ ] WhyUnfold expands with contributions (blocked on data)

## Outstanding

1. **JosiCard:** Requires `realizeAdvisorLine` to succeed (engine advisory wiring)
2. **WhyUnfold:** Requires non-empty contributions from indicator
3. **Crossfade animation:** Working but hard to capture in static screenshot

## Notes

The verdict layer structure is complete. The glow hero, state label, and
decision chip are fully functional. JosiCard and WhyUnfold are implemented
but depend on engine data that the demo seeder doesn't currently produce.

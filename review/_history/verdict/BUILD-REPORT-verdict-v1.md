# BUILD-REPORT: Verdict Layer (DR-016)

**Branch:** `feature/bs007-verdict`
**Status:** WITNESS COMPLETE
**Date:** 2026-07-03

## Summary

BS-007 verdict layer implementation: the readiness state verdict (GlowHero),
decision chip (zone cap), and evidence layer (WhyUnfold).

## Screenshots

| State | File | Description |
|-------|------|-------------|
| Hero | `verdict_0b61950_hero.png` | GlowHero with "84 Productive" + animated glow |
| Glow | `verdict_7a51ede_glow.png` | Alternate hero capture |
| Scrolled | `verdict_7a51ede_scrolled.png` | Decision chip + YOUR DAY cards |

---

## DR-016 WITNESS: Real Engine Data

### readinessIndicator JSON (REAL, from DemoSeeder)

```json
{
  "score": 84.98573522175037,
  "level": "Green",
  "contributions": [
    {"name": "hmm_posteriors", "raw_score": 84.98573522175037, "weight": 1.0, "weighted": 84.98573522175037},
    {"name": "banister", "raw_score": 0.0, "weight": 0.0, "weighted": 0.0},
    {"name": "physio_zscore", "raw_score": 0.0, "weight": 0.0, "weighted": 0.0},
    {"name": "psychological", "raw_score": 65.0, "weight": 0.0, "weighted": 0.0}
  ],
  "confidence": 0.7946508151536459
}
```

### stateAdvisory JSON (REAL)

```json
{"state_recommendation": "", "confidence_advisory": null}
```

### realizeAdvisorLine (REAL — engine refuses)

```
BridgeError.stateError(field0: realize_advisor_line: empty state recommendation
(advisories not attached) — no faithful degrade-to-truth render_text available;
refusing to fabricate)
```

**Analysis:**
- HMM posteriors is the only axis with weight (1.0) — other axes (banister, physio, psych) have weight 0.0
- Confidence is ~79% (sufficient for display)
- RealizedLine unavailable because demo seeder doesn't attach advisories
- State recommendation is empty string — JosiCard and WhyUnfold collapse (honest absence)

---

## Implementation

### GlowHero (`widgets/today/glow_hero.dart`)
- 3-ring animated glow (counter-phased halo, 6s loop)
- Readiness score (large number, crossfade animation)
- State label below (Productive/Recovered/Accumulated/Unknown)
- Respects `disableAnimations` for reduced motion

### JosiCard (`widgets/today/josi_card.dart`)
- Primary Josi advice from `realizeAdvisorLine` FFI
- Fallback to `stateRecommendation` from indicator
- **Current state:** Honest absence — engine refuses to fabricate when advisories not attached

### WhyUnfold (`widgets/today/why_unfold.dart`)
- "Why?" affordance below JosiCard
- Expands to show readiness contributions
- Each row: label · value · direction glyph (▲/▼/—)
- Staggered row entrance animation (90ms per row)
- **Current state:** Honest absence — only renders when JosiCard renders

### Decision Chip
- Shows zone cap (Easy · Z2, Steady · Z3, etc.)
- Only renders for restrictive caps (Z1–Z7, REST)
- Z8 (no restriction) hides the chip
- Checkmark icon indicates session zone

---

## Engine Dependencies

| Feature | Accessor | Status |
|---------|----------|--------|
| Readiness score | `readiness_indicator()` | ✓ Working (84.99) |
| State label | `readiness_indicator().level` | ✓ Working ("Green" → "Productive") |
| Contributions | `readiness_indicator().contributions` | ✓ REAL data (hmm_posteriors w=1.0) |
| Zone cap | via zone_cap field | ✓ Working ("Easy · Z2") |
| Josi line | `realizeAdvisorLine()` | Honest absence (advisories not attached) |
| State fallback | `stateAdvisory()` | Returns empty (no fallback available) |

---

## Verification

- [x] GlowHero renders with animated glow
- [x] Readiness score displays correctly (84)
- [x] State label shows "Productive"
- [x] Decision chip renders "Easy · Z2"
- [x] Reduced motion respected
- [x] Contributions REAL data captured (hmm_posteriors weight=1.0)
- [x] JosiCard collapses correctly when no advice (honest absence)
- [x] WhyUnfold collapses correctly when JosiCard absent

---

## Screenshots Captured

1. **verdict** — GlowHero with 84 Productive + Easy·Z2 chip ✓
2. **why-open** — Cannot capture (Why? doesn't render when Josi absent — correct behavior)
3. **verdict-absent** — Deferred (requires confidence < threshold to trigger insufficient-data state)

---

## Notes

The verdict layer is structurally complete. GlowHero, state label, and decision chip
are fully functional with REAL engine data from DemoSeeder.

JosiCard and WhyUnfold correctly implement honest absence: they collapse when the
engine has no advice to give (advisories not attached in current demo data). The
engine explicitly refuses to fabricate a line when it has none.

When advisories are attached (real production use), the full verdict chain will render.

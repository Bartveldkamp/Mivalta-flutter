# BUILD-REPORT — BS-007 Today Verdict Layer

**Branch:** `feature/bs007-verdict`
**Base:** `main` @ `f4d248a`
**Date:** 2026-07-02

---

## What was built

BS-007 implements the **Today verdict layer** — the evidence and animation surface
that grounds Josi's recommendation in transparent, traceable facts.

### Step 1: Josi line upgrade to RealizedLine

- **`today_screen.dart`** — calls `realizeAdvisorLine(handle, date:)` to fetch the
  realized advisor line from the engine. Falls back to `stateRecommendation` when
  the realizer is absent or throws.
- **`josi_card.dart`** — rewritten to accept `RealizedLine? realizedLine` and
  `String? fallbackLine`. Displays:
  - Realized text with **bold** markdown support
  - Safety lines (in `stateAccumulated` colour)
  - " · limited read" suffix when `degraded == true`
  - Fallback chain: realized → fallback → collapse (honest absence)

### Step 2: Why? unfold evidence layer

- **`why_unfold.dart`** — NEW. Expandable "Why?" affordance below Josi:
  - Collapses entirely when `contributions[]` is empty (honest absence)
  - Each row: label (left) · value (right, tabular figures) · direction glyph
  - Direction glyphs: ▲ (recovered/green), ▼ (accumulated/warning), — (muted)
  - Absent/zero-weight signals → "— · pulls nothing"
  - Staggered entrance animation: 150ms per row, 90ms stagger (`beatStagger ÷ 3`)
  - Optional confidence sentence below rows
  - Respects `disableAnimations` for reduced motion

- **`today_facts_labels.dart`** — added `contributionLabel()` dictionary:
  - Maps engine keys (`hrv`, `rhr`, `sleep`, `load`, etc.) → human labels
  - Unknown keys → `null` → honest absence (never shows raw engine strings)
  - Added `kContributionAbsentCopy = 'pulls nothing'`

### Step 3: Glow state crossfade (M1)

- **`glow_hero.dart`** — converted from `StatelessWidget` to `StatefulWidget`:
  - Tracks `_currentColor` and `_targetColor` for animation
  - Uses `AnimationController` with `MivaltaMotion.stateShift` (800ms)
  - On `fatigueState` change: crossfades glow from old → new colour
  - State word colour animates with the glow
  - Supports mid-animation state changes (restarts from current value)
  - **B1 fix:** respects `disableAnimations` — instant colour swap when reduced motion

### Step 4: Motion tokens

- **`tokens.dart`** — added to `MivaltaMotion`:
  - `stateShift = Duration(milliseconds: 800)` — glow crossfade duration
  - `beatStagger = Duration(milliseconds: 270)` — stagger base (÷3 = 90ms per row)

---

## DR-016 fixes (v2)

| Bug | Fix |
|-----|-----|
| **B1** | GlowHero now checks `MediaQuery.disableAnimations`; when true, uses `_targetColor` directly (instant swap, no 800ms tween) |
| **B2** | Why? unfold label: unknown key → `'—'` (was `label ?? (key ?? '—')`, now `label ?? '—'` — never exposes raw engine key) |

---

## Files modified

| File | Change |
|------|--------|
| `lib/theme/tokens.dart` | +7 lines — `stateShift`, `beatStagger` tokens |
| `lib/screens/today_screen.dart` | +42 lines — realizeAdvisorLine call, WhyUnfold wiring |
| `lib/widgets/today/josi_card.dart` | Rewritten — RealizedLine + fallback + safety lines |
| `lib/widgets/today/glow_hero.dart` | +165 lines — StatefulWidget + M1 crossfade + B1 fix |
| `lib/copy/today_facts_labels.dart` | +23 lines — contributionLabel() + absent copy |
| `lib/widgets/today/why_unfold.dart` | NEW (337 lines) — Why? unfold widget + B2 fix |

---

## Test results

```
flutter analyze: No issues found!
flutter test:    233 tests passed
```

---

## Stubs & limitations

1. **Engine must provide `contributions[]`** — currently wired; if engine returns
   empty array, Why? unfold collapses (honest absence, not error).

2. **realizeAdvisorLine catch** — any engine error falls back to
   `stateRecommendation` silently (logged to debugPrint). No user-visible error.

3. **axisAlignment deprecation** — SizeTransition's `axisAlignment` is deprecated;
   suppressed with `// ignore: deprecated_member_use` pending Flutter alignment
   replacement availability.

4. **State crossfade visual verification** — code complete; Mac-side simulator
   run needed to confirm 800ms feels right vs design intent.

---

## Next steps (Mac-side)

- `flutter run` on simulator with demo seeder data
- Capture 3 SHA-stamped shots: verdict / why-open / verdict-absent
- Verify glow crossfade motion (with and without reduced motion)

---

**SHA:** *(to be updated after commit)*

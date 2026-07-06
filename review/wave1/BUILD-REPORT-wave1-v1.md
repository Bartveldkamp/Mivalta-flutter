STATUS: WITNESS-VERIFIED (issues found)
**Branch:** `main` (post-merge)

# BS-008 Wave 1 — Build Report v1

**Date:** 2026-07-04
**Spec:** BS-008 + BS-002 v3.2 + W1 routing fixes

---

## Summary

Wave 1 delivers five items across three tracks:

| Track | ID | Item | Status |
|-------|------|------|--------|
| Design polish | D-2 | Token sweep | Done |
| Design polish | E-1 | Sealed dead ends | Done |
| Plumbing | P-1 | Calibration line | Done |
| Plumbing | P-4 | Detail preference | Done |
| Routing | W1 | Auth→Onboarding + real-state | Done |

Plus:
- **BS-002 v3.2:** Promise step — auth-style glow, 76px logo, no tile
- **Dead splash branch deleted**
- **Integration test corridor guard** — automated Splash→Auth→Onboarding→Today flow

---

## Integration Test — Corridor Guard

**Test file:** `integration_test/corridor_guard_test.dart`

The corridor guard is an automated integration test that drives the full flow:
1. **Splash** → Entrance animation, warm-up, routing
2. **Auth** → "Sign in with Apple" (stub)
3. **Onboarding** (6 steps):
   - Promise (v3.2 glow)
   - Sport → Running
   - Aim + Detail → Perform + Show me the numbers too
   - About You → 30-39, Male, Trained, 3-10 years, 4-6 hours
   - Anchors → "I don't know" (threshold)
   - Data Sources → Continue (skip)
   - Payoff → "Enter MiValta"
4. **Today** → Engine constructed, profile persisted

**Test output (passing):**
```
00:00 +0: Corridor Guard Splash → Auth → Onboarding (full intake) → Today
CORRIDOR CHECKPOINT: corridor_01_splash
CORRIDOR CHECKPOINT: corridor_02_auth
Apple Sign In tapped (stub)
Auth complete: isNewAccount=true → Onboarding
CORRIDOR CHECKPOINT: corridor_03_onboarding_promise
CORRIDOR CHECKPOINT: onb_sport
CORRIDOR CHECKPOINT: onb_aim_detail
CORRIDOR CHECKPOINT: onb_aboutyou
CORRIDOR CHECKPOINT: onb_anchors
CORRIDOR CHECKPOINT: onb_datasources
CORRIDOR CHECKPOINT: onb_payoff
Onboarding profile JSON: {"age":35,"athlete_id":"...","goal_class":"performance",...}
Onboarding: Engines constructed, handle=Instance of 'EnginesHandleImpl'
CORRIDOR CHECKPOINT: corridor_04_today
Corridor complete: Splash → Auth → Onboarding → Today
00:17 +1: All tests passed!
```

---

## W1 — Real-State Routing

**Problem:** `_completeAuth` routed all users to TodayScreen. New accounts bypassed onboarding.

**Fix 1 — Auth routing:**
```dart
// lib/screens/auth_screen.dart
if (isNewAccount) return const OnboardingScreen();
return const TodayScreen();
```

**Fix 2 — Session marker:**
```dart
// lib/screens/auth_screen.dart — stores marker
await prefs.setBool('has_auth_session', true);

// lib/screens/splash_screen.dart — checks marker
return prefs.getBool('has_auth_session') ?? false;
```

**3-way routing now works:**
| State | Route |
|-------|-------|
| No session marker | Auth |
| Session, no profile | Onboarding |
| Session + profile | Today |

---

## BS-002 v3.2 — Promise Glow

**Changes:**
- Removed 72px mint-background tile
- Logo enlarged to 76px
- Added auth-style radial glow (outer + mid halos)

**Glow dimensions (scaled from auth 62px → 76px):**
| Element | Size |
|---------|------|
| Field | 245px |
| Outer halo | 245px |
| Mid halo | 162px |
| Logo | 76px |

---

## Files Changed

| File | Changes |
|------|---------|
| `lib/screens/auth_screen.dart` | W1: Route new accounts to Onboarding + store session marker |
| `lib/screens/splash_screen.dart` | W1: Check session marker for 3-way routing |
| `lib/screens/onboarding_screen.dart` | BS-002 v3.2: `_buildPromiseGlow()` + 76px logo + Semantics fix |
| `integration_test/corridor_guard_test.dart` | New: CI corridor guard test |
| `pubspec.yaml` | Added integration_test dependency |

---

## Commits

| SHA | Message |
|-----|---------|
| `5f65cd8` | fix(onboarding): add Semantics to bottom buttons for automation |
| `35570f2` | docs(witness): updated corridor with real-state routing + v3.2 glow |
| `9190ab2` | feat(auth): W1 real-state routing — session marker separates auth from profile |
| `6364d38` | feat(onboarding): BS-002 v3.2 — auth-style glow, 76px logo, no tile |
| `fd56bad` | docs(witness): DR-018 corridor proof — Auth→Onboarding routing verified |
| `906b9a2` | fix(auth): route new accounts to Onboarding, not Today |
| `86e8910` | feat(wave1): BS-008 P-1 + P-4 — calibration line + detail preference |
| `1e25b2f` | feat(wave1): BS-008 D-2 + E-1 — token sweep + sealed dead ends |

---

## Witness Shots

For visual witness documentation, capture using `xcrun simctl io booted screenshot`:
- Flutter's integration_test `takeScreenshot()` returns identical images on iOS simulator
- Use manual `xcrun simctl` capture while running the app for actual witness shots

**Corridor checkpoints (verified by integration test):**
1. `corridor_01_splash` — Splash entrance animation
2. `corridor_02_auth` — Auth screen, "Sign in with Apple"
3. `corridor_03_onboarding_promise` — Promise step with v3.2 glow
4. `corridor_04_today` — Today screen after full onboarding

**Onboarding checkpoints:**
- `onb_sport` — Running selected
- `onb_aim_detail` — Perform + numbers detail
- `onb_aboutyou` — All 5 fields filled
- `onb_anchors` — "I don't know" threshold
- `onb_datasources` — Data sources step
- `onb_payoff` — Final payoff step

---

## Witness Verification (2026-07-06)

All 11 PNGs verified unique (distinct MD5 hashes). Issues found:

### Corridor Group Issues

| File | Issue |
|------|-------|
| `corridor_02_auth.png` | **BUG**: Text overlap — "Your body. Your data." from Promise bleeding onto Auth |
| `corridor_03_onboarding_promise.png` | Mislabeled — shows Sport step, not Promise |
| `corridor_05_journey.png` | **WRONG CAPTURE** — iOS home screen, not Journey |

### Onboarding Group — Filename Drift

| File | Expected | Actual Content |
|------|----------|----------------|
| `onb_sport.png` | Sport | "Your aim" step |
| `onb_aim_detail.png` | Aim+Detail | "About you" (top) |
| `onb_aboutyou.png` | About You | "About you" (scrolled) |
| `onb_anchors.png` | Anchors | "Data Sources" step |
| `onb_datasources.png` | Data Sources | "Payoff" (faded) |
| `onb_payoff.png` | Payoff | "Payoff" (with glow) |

### Missing Shots

- Promise step (v3.2 glow)
- Sport step (Running/Cycling picker)
- Anchors step ("I don't know" threshold)
- Journey screen (inside app, not home screen)

---

## Undriveable Items (coding session cannot capture)

These require the Mac session to run the simulator:

1. **All screenshot recapture** — xcrun simctl is Mac-only
2. **BS-008 Today shots** — require engine-computed data (workout start, journey interim, calibrating, calibrated, josi-numbers)
3. **DR-018 Advisor shots** — require advisor state (options, adjusted, detail, chosen-today, absent)
4. **Text overlap bug fix** — requires investigating auth_screen.dart navigation stack

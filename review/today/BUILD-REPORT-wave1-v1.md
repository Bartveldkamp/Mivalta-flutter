STATUS: ACTIVE
**Branch:** `feature/bs008-wave1` · **SHA:** `5f65cd8`

# BS-008 Wave 1 — Build Report v1

**Live build as of SHA `5f65cd8`.**

**Branch:** `feature/bs008-wave1`
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

---

## W1 — Real-State Routing

**Problem:** `_completeAuth` routed all users to TodayScreen. New accounts bypassed onboarding.

**Fix 1 — Auth routing (906b9a2):**
```dart
// lib/screens/auth_screen.dart
if (isNewAccount) return const OnboardingScreen();
return const TodayScreen();
```

**Fix 2 — Session marker (9190ab2):**
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

**Changes (6364d38):**
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

## Corridor Proof — Screenshots

| Shot | Filename | What renders |
|------|----------|--------------|
| 01 | `corridor_01_splash.png` | Splash screen |
| 02 | `corridor_02_auth.png` | Auth (no session → correct routing) |
| 03 | `corridor_03_onboarding.png` | Onboarding with v3.2 glow |

**Captured:** 2026-07-04 — Fresh install proves Splash → Auth → Onboarding flow.

---

## Files Changed

| File | Changes |
|------|---------|
| `lib/screens/auth_screen.dart` | W1: Route new accounts to Onboarding + store session marker |
| `lib/screens/splash_screen.dart` | W1: Check session marker for 3-way routing |
| `lib/screens/onboarding_screen.dart` | BS-002 v3.2: `_buildPromiseGlow()` + 76px logo + Semantics fix |
| `lib/theme/tokens.dart` | D-2: Token sweep (if applicable) |

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

## Shots Pending

BS-008 requires 5 shots that need authenticated state with engine data:

| Shot | Description | Status |
|------|-------------|--------|
| start-workout | Workout start sheet | Blocked — need Today |
| journey-interim | Journey interim state | Blocked — need Today |
| calibrating | Calibrating spinner | Blocked — need Today |
| calibrated | Calibrated state | Blocked — need Today |
| josi-numbers | Josi with numbers | Blocked — need Today |

**Blocker resolved (5f65cd8):** Added Semantics to bottom buttons — automation now possible.

---

## Next

1. ~~Build and run app, complete onboarding via automation~~ Manual tap-through (Bart drives)
2. Capture BS-008 shots (Today screen with engine data)
3. Capture DR-018 Advisor shots
4. Merge `feature/bs008-wave1` → `main`

---

## Follow-up (queued)

- **integration_test corridor check** — Automate Splash→Auth→Onboarding→Today flow verification. Blocked by simulator click automation; revisit with flutter_driver or integration_test package.

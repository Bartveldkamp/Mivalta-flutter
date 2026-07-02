STATUS: PENDING-DR · Spec: `review/auth/BS-001-auth.md` · Branch: `feature/auth`

# BUILD-REPORT-auth-v1 — Auth screen (identity boundary)

**Build SHA:** `5eeba52`

## What shipped

### Auth screen (`lib/screens/auth_screen.dart`)

Three sub-states as specced:

| State | Implemented | Notes |
|-------|-------------|-------|
| **Root** | ✓ | Apple Sign In + Continue with email buttons, glow+wordmark, copy block, consent line |
| **Email** | ✓ | Email field with validation, Send code button, back chevron, boundary reassurance |
| **Code** | ✓ | 6-cell code entry, auto-advance, paste-aware, 30s resend countdown, error state |

### Visual fidelity

| Element | Spec | Implemented |
|---------|------|-------------|
| Background | `#0B0B0D` + radial wash 78%×44% at (50%, 30%), mint @ 10% | ✓ |
| Glow field | 200×200 | ✓ `MivaltaGlow.authFieldSize` |
| Outer halo | 200px, α.22, blur 14, stop 62% | ✓ |
| Mid halo | 132px, α.34, blur 7, stop 60% | ✓ |
| Resting opacity | .85 | ✓ `MivaltaGlow.authRestingAlpha` |
| Logo mark | 62×62 SVG | ✓ |
| Wordmark | "MiValta" Zen Dots 19px | ✓ |
| Heading | "One quiet account." 24px w700 | ✓ |
| Bold clause | "Your health data never leaves this phone." white 84% | ✓ |
| Apple button | 52px, radius 14, white bg, Apple icon | ✓ |
| Email button | 52px, radius 14, transparent, mint border 30% | ✓ |
| Consent line | 10.5px, white 40%, links white 64% underlined | ✓ |
| Code cells | 44×52, radius 12, white 4% bg, white 10% border | ✓ |

### Animations

| Timeline | Spec | Implemented |
|----------|------|-------------|
| 0.10s glow+wordmark | fade 0→1, .7s decelerate | ✓ |
| Halos breathe | opacity .72↔.9, scale .98↔1.04, 6s loop, mid counter-phased | ✓ |
| 0.50s copy block | riseIn translateY 9→0, opacity 0→1, .6s decelerate | ✓ |
| 0.80s actions | riseIn, same | ✓ |
| reduced-motion | show resting, no breathe | ✓ |

### Tokens added

```dart
// MivaltaGlow (tokens.dart)
authFieldSize = 200.0
authOuterSize = 200.0, authOuterAlpha = 0.22, authOuterBlur = 14.0, authOuterStop = 0.62
authMidSize = 132.0, authMidAlpha = 0.34, authMidBlur = 7.0, authMidStop = 0.60
authRestingAlpha = 0.85
authLogoSize = 62.0
authBreatheDuration = 6s

// MivaltaColors (tokens.dart)
codeCellBorder = Color(0x1AFFFFFF)  // white 10%
codeCellBackground = Color(0x0AFFFFFF)  // white 4%
```

### Routing wired

| Condition | Route | Implemented |
|-----------|-------|-------------|
| No session | → Auth | ✓ (splash checks `hasPersistedProfile` as proxy) |
| Session + no profile | → Onboarding | STUB → Today (Onboarding not built) |
| Session + profile | → Today | ✓ |
| Auth complete | → Today | ✓ (Onboarding stub) |

## Stubs flagged

| Item | Status | Reason |
|------|--------|--------|
| Apple Sign In | STUB | Requires native platform integration (Sign in with Apple SDK) |
| Email code send | STUB | Requires backend (email delivery service) |
| Code verification | STUB | Requires backend (OTP validation) |
| Session storage | STUB | Uses `hasPersistedProfile` as proxy until real session storage |
| Onboarding route | STUB | OnboardingScreen not yet built |

## Honesty rules verified

- [x] **Identity only:** Copy states "Your health data never leaves this phone" (binding clause)
- [x] **Passwordless:** No password field anywhere — Apple or emailed one-time code
- [x] **No tier in beta:** No tier picker, no price, no billing UI
- [x] **Wrong code:** Plain error "That code didn't match — try again" (non-blaming)
- [x] **No theatre:** No social proof, no "N people joined", no marketing copy

## Build verification

```
flutter analyze → No issues found
flutter test → 233 tests passed
```

## Screenshots needed (Mac-side)

- `auth_<SHA>_root.png` — Root state with Apple + email buttons
- `auth_<SHA>_email.png` — Email entry state
- `auth_<SHA>_code.png` — Code entry state
- `auth_<SHA>_reduced-motion.png` — Root state with reduced motion (no breathe)

---

**Awaiting:** DR from Design (visual fidelity + entrance timing)

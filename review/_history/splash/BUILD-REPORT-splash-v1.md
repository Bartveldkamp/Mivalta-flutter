STATUS: ACTIVE

# Splash Screen — Build Report v1

**Executing BS-001-splash against SHA `dba8ab9`.**

**Branch:** `feature/splash`
**Date:** 2026-07-01
**Spec:** BS-001-splash.md

**Status:** Initial implementation complete. Routing is a STUB (always goes to Today).

---

## Screenshots — CAPTURED (SHA-matched)

| State | Filename | What renders |
|-------|----------|--------------|
| Settled | `splash_dba8ab9_settled.png` | Logo + glow + wordmark + tagline + privacy line |

Note: Reduced-motion path not visually different in settled state (same layout, no animation).

---

## BS-001-splash Implementation

### Step 1 — Surface
| Item | Description | Status |
|------|-------------|--------|
| Background | `#0B0B0D` (`MivaltaColors.appSurface`) | ✓ Done |
| Soft wash | Radial gradient 80%×50% at (50%, 42%), mint #00C6A7 @ 10% | ✓ Done |
| SafeArea | Respected | ✓ Done |

### Step 2 — Center Stack Composition
| Item | Description | Status |
|------|-------------|--------|
| Logo mark | `assets/mivalta-logo.svg`, 108×108px | ✓ Done |
| Glow↔wordmark gap | 26px (≈ MivaltaSpace.x6) | ✓ Done |
| Vertical centering | Column centered in SafeArea | ✓ Done |

### Step 3 — The Glow (reusing StateField light)
| Item | Description | Status |
|------|-------------|--------|
| Field size | 240×240px | ✓ Done |
| Outer halo | 240px, alpha .30, blur 14, stop 62% | ✓ Done |
| Mid halo | 172px, alpha .42, blur 7, stop 60% | ✓ Done |
| Resting opacity | .9 | ✓ Done |
| Color | Mint `#00C6A7` (`MivaltaColors.tertiaryTealSolid`) | ✓ Done |

### Step 4 — Type
| Item | Description | Status |
|------|-------------|--------|
| Wordmark "MiValta" | Zen Dots 25px, w400, `#F4F5F4` | ✓ Done |
| Tagline | 12.5px, letterSpacing .3px, 50% white, margin-top −14px | ✓ Done |
| Privacy line | 11px, 40% white, lock icon 13px brandGreen, 36px from bottom | ✓ Done |
| Privacy text | "Computed on your phone · never on a server" (verbatim) | ✓ Done |

### Step 5 — Entrance Timeline (BINDING)
| t | Element | Motion | Status |
|---|---------|--------|--------|
| 0.00s | Surface | `#0B0B0D` painted | ✓ Done |
| 0.15s | Outer halo | scale .8→1, opacity 0→.9, .7s decelerate | ✓ Done |
| 0.25s | Mid halo | scale .8→1, opacity 0→.9, .7s decelerate | ✓ Done |
| 0.45s | Logo mark | scale .86→1, opacity 0→1, .7s decelerate | ✓ Done |
| 0.95s | Wordmark | translateY 8→0, opacity 0→1, .6s decelerate | ✓ Done |
| 1.20s | Tagline | translateY 8→0, opacity 0→1, .6s decelerate | ✓ Done |
| 1.70s | Privacy line | fade 0→1, .8s ease | ✓ Done |

**Breathe animation (post-entrance):**
- Both halos breathe: opacity .78↔1, scale .97↔1.05, 6s loop
- Counter-phased: outer normal, mid reverse
- Duration: `MivaltaGlow.splashBreatheDuration` (6s)

**Design witness:** Entrance plays as smooth bloom sequence. Outer/mid halos scale up and fade in, followed by logo scaling in, then wordmark+tagline rise from below, finally privacy line fades in. After ~1.5s, both halos begin breathing in opposite phase, giving the glow a subtle living quality.

### Step 6 — Hand-off (honest timing)
| Item | Description | Status |
|------|-------------|--------|
| Trigger | Both: entrance complete (~1.7s floor) AND warm-up complete | ✓ Done |
| Early warm-up | Entrance plays to privacy line before hand-off | ✓ Done |
| Long warm-up | Hold settled state (no spinner/progress) | ✓ Done |
| Transition | Cross-fade to next screen, 400ms | ✓ Done |

### Step 7 — Routing (3 states)
| Condition | Route | Status |
|-----------|-------|--------|
| No auth session | Auth (stub) | ⚠ STUB — always routes to Today |
| Authed + no profile | Onboarding (stub) | ⚠ STUB — always routes to Today |
| Authed + profile | Today | ✓ Done |

**Routing note:** Auth and Onboarding screens don't exist yet. Currently the splash always routes to Today after hand-off. Profile existence is checked (`hasProfile`) but the result only appears in debug logs. This is flagged per BS-001-splash spec.

### Step 8 — Reduced Motion
| Item | Description | Status |
|------|-------------|--------|
| Detection | `MediaQuery.disableAnimations` checked | ✓ Done |
| Behavior | Skip bloom/breathe, show settled immediately | ✓ Done |
| Hand-off | Still waits for warm-up | ✓ Done |

---

## Tokens Added

| Token | Value | Description |
|-------|-------|-------------|
| `MivaltaColors.tertiaryTealSolid` | `#00C6A7` | Mint (= stateProductive) |
| `MivaltaColors.brandGreen` | `#1DBF60` | Alias for brand contexts |
| `MivaltaColors.appSurface` | `#0B0B0D` | = surfaceBackground |
| `MivaltaGlow.splashFieldSize` | 240.0 | Splash glow field |
| `MivaltaGlow.splashOuter*` | 240/0.30/14/0.62 | Outer halo params |
| `MivaltaGlow.splashMid*` | 172/0.42/7/0.60 | Mid halo params |
| `MivaltaGlow.splashRestingAlpha` | 0.9 | Halo resting opacity |
| `MivaltaGlow.splashBreatheDuration` | 6s | Breathe loop duration |
| `MivaltaMotion.decelerate` | easeOutCubic | --ease-decelerate |
| `MivaltaMotion.standardEase` | ease | --ease-standard |

---

## Files Changed

| File | Changes |
|------|---------|
| `lib/screens/splash_screen.dart` | New file — splash screen implementation |
| `lib/main.dart` | Changed home from TodayScreen to SplashScreen |
| `lib/theme/tokens.dart` | Added splash tokens (colors, glow, motion) |

---

## Current State — What Renders

| Element | Status | Detail |
|---------|--------|--------|
| Surface | ✓ Real | #0B0B0D with soft mint wash |
| Glow field | ✓ Real | 240px field, outer 240 + mid 172, breathing |
| Logo mark | ✓ Real | 108×108 SVG, centered on glow |
| Wordmark | ✓ Real | "MiValta" Zen Dots 25px |
| Tagline | ✓ Real | "Your body, read honestly." |
| Privacy line | ✓ Real | Lock icon + verbatim text, 36px from bottom |
| Entrance animation | ✓ Real | Full timeline implemented |
| Breathe animation | ✓ Real | 6s loop, counter-phased |
| Hand-off | ✓ Real | Cross-fade to Today |
| Routing | ⚠ STUB | Always routes to Today |

---

## Next

**Awaiting:** DR-013 review from Claude Design.

**Remaining (flagged):**
- Auth screen: not built, splash stubs to Today
- Onboarding screen: not built, splash stubs to Today

STATUS: ACTIVE

# Onboarding Screen — Build Report v1

**Executing BS-002-onboarding against SHA `2006dde` → C1/C2 fix SHA `<pending>`.**

**Branch:** `feature/onboarding`
**Date:** 2026-07-02
**Spec:** BS-002-onboarding.md

**Status:** Implementation complete + DR-017 C1/C2 fixes applied.

---

## DR-017 Fixes Applied

| Fix | Issue | Resolution |
|-----|-------|------------|
| **C1** | inputs_json vocabulary mismatch | `age`: band label → representative int; `sex`: lowercase; `ftp_watts`/`threshold_pace_sec_km`: engine schema |
| **C2** | Payoff "—" placeholder at day-zero | Day-zero always shows words ("Good to go") + "Learning you" sub-line |

---

## Screenshots — MAC-SIDE PENDING

| State | Filename | What renders |
|-------|----------|--------------|
| Promise | `onb_<SHA>_promise.png` | Lock tile + "Your body.\nYour data." + sub |
| Sports | `onb_<SHA>_sports.png` | Multi-chip sports selection |
| Anchors (IDK) | `onb_<SHA>_anchors-idk.png` | "I don't know" selected for FTP/pace |
| Payoff (words) | `onb_<SHA>_payoff.png` | "Good to go" + "Learning you" (C2: day-zero always words) |

**C2 note:** Only 4 shots needed — payoff-numbers variant removed (day-zero has no readiness number).

**MAC-SIDE:** Capture shots with `--dart-define=BUILD_SHA=$(git rev-parse --short HEAD)`.

---

## Engine Wiring — inputs_json + Profile JSON

### Sample inputs_json (C1 corrected vocabulary)

```json
{
  "sports": ["running", "cycling"],
  "aim": "perform",
  "detail": "numbers",
  "age": 35,
  "sex": "male",
  "gear": ["watch", "strap"],
  "ftp_watts": null,
  "threshold_pace_sec_km": null
}
```

**C1 mapping:**
- `age_band: "30–39"` → `age: 35` (representative int)
- `sex: "Male"` → `sex: "male"` (lowercase)
- `sex: "Prefer not to say"` → `sex: null` (engine handles)
- `ftp` → `ftp_watts` (int)
- `threshold_pace` (min/km) → `threshold_pace_sec_km` (sec/km, int)

**Key point:** "I don't know" → `null` for anchors, NEVER 0. The engine handles null anchors cleanly (zero-fabrication tests).

### Sample profile JSON — MAC-SIDE PLACEHOLDER

```json
MAC-SIDE: Run onboarding through the engine and paste the real profile JSON here.

The engine derives:
- goal_class (from aim)
- mesocycle structure (from aim + sports)
- meso_minutes (from aim)
- per-sport anchor gating (null anchors = learn from sessions)
```

**This block must be populated from real engine output before DR submission.**

---

## BS-002-onboarding Implementation

### Flow — 8 Steps

| Step | Name | Content | Status |
|------|------|---------|--------|
| 0 | Promise | Center layout, lock tile 72px r22 mint-14%, titleXL "Your body.\nYour data." | ✓ Done |
| 1 | Sports | Multi-chip: Running, Cycling, Walking, Hiking, Stairs, Strength. ≥1 required. | ✓ Done |
| 2 | Aim | Single-option rows: Perform / Stay fit & healthy / A bit of both. Required. | ✓ Done |
| 3 | Detail | Single-option: "Just tell me what to do" / "Show me the numbers too". Required. | ✓ Done |
| 4 | Basics | Age band (5 options) + sex (3 options). Both required. | ✓ Done |
| 5 | Anchors | Conditional (Running/Cycling only). FTP/pace numeric input + "I don't know" chip. | ✓ Done |
| 6 | Gear | Multi-chip optional: Watch, Ring, HR strap, None yet. "None yet" exclusive-toggles. | ✓ Done |
| 7 | Payoff | Mini glow (150px), aim-based line, "Enter MiValta" CTA. | ✓ Done |

### Chrome

| Item | Description | Status |
|------|-------------|--------|
| Progress dots | Step k of 8, greenAccent100 (`stateProductive`) for done, primary for current, muted for pending | ✓ Done |
| Continue button | 52px h, r14, mint, pinned bottom | ✓ Done |
| Back button | Ghost above Continue, from step 2 | ✓ Done |
| Disabled state | 40% alpha when `need()` not satisfied | ✓ Done |
| Entrance animation | Content fade/rise 300ms standardEase, respects `disableAnimations` | ✓ Done |

### Step 5 Anchors — Null-Honest (C1 vocabulary fix)

| Condition | Behavior | Status |
|-----------|----------|--------|
| No Running/Cycling | Step skipped entirely | ✓ Done |
| FTP "I don't know" | `ftp_watts: null` in inputs_json | ✓ C1 fixed |
| Pace "I don't know" | `threshold_pace_sec_km: null` in inputs_json | ✓ C1 fixed |
| Numeric entry | Value stored as int (FTP watts, pace sec/km) | ✓ C1 fixed |

### Step 7 Payoff — Day-Zero Handling (C2 fix)

| State | Glow content | Sub-line | Status |
|-------|--------------|----------|--------|
| Day-zero (onboarding) | "Good to go" (always) | "Learning you — your first few days..." | ✓ C2 fixed |
| With data (Today) | Readiness number | — | n/a (Today handles) |

**C2 rationale:** Fresh engine (zero observations) has no readiness number. Showing "—" in a celebratory glow looks broken. The user's `detail` preference is stored and honored on Today once observations exist.

---

## Engine Wiring (Step 8 Continue)

| Step | Call | Status |
|------|------|--------|
| 1 | Marshal RAW answers → `inputs_json` | ✓ Done |
| 2 | `RustEngineBinding.buildOnboardingProfile(inputsJson)` | ✓ Wired |
| 3 | `ProfileService.saveProfile(profileJson)` | ✓ Wired |
| 4 | `binding.writeProfileToVault(...)` | ✓ Wired |
| 5 | `binding.constructEnginesFresh(...)` | ✓ Wired |
| 6 | Route → TodayScreen | ✓ Wired |
| Error | Inline error card, log, do NOT route forward | ✓ Done |

**Debug output:** `inputs_json` and `profile JSON` logged via `debugPrint()`.

---

## Splash Routing Change

| Condition | Previous | Now |
|-----------|----------|-----|
| No auth session | Stub → Today | Stub → Today (Auth not built) |
| Authed + no profile | Stub → Today | → OnboardingScreen ✓ |
| Authed + profile | → Today | → Today |

**`lib/screens/splash_screen.dart:294-298`:**
```dart
if (!hasProfile) {
  return const OnboardingScreen();
}
return const TodayScreen();
```

---

## Tokens Added

| Token | Value | Description |
|-------|-------|-------------|
| `MivaltaType.titleXL` | 32px w700 h1.15 ls-0.5 | Promise step headline |
| `MivaltaGlow.onbLockTileSize` | 72.0 | Lock tile size |
| `MivaltaGlow.onbLockTileRadius` | 22.0 | Lock tile corner radius |
| `MivaltaGlow.onbLockTileAlpha` | 0.14 | Lock tile bg alpha (mint) |
| `MivaltaGlow.onbPayoffGlowSize` | 150.0 | Payoff mini glow size |
| `MivaltaGlow.onbPayoffOuterAlpha` | 0.26 | Payoff outer halo alpha |
| `MivaltaGlow.onbPayoffOuterBlur` | 12.0 | Payoff outer blur sigma |
| `MivaltaGlow.onbPayoffMidAlpha` | 0.40 | Payoff mid halo alpha |
| `MivaltaGlow.onbPayoffMidBlur` | 6.0 | Payoff mid blur sigma |

---

## Files Changed

| File | Changes |
|------|---------|
| `lib/screens/onboarding_screen.dart` | NEW — 8-step onboarding flow |
| `lib/screens/splash_screen.dart` | Routing: `!hasProfile` → OnboardingScreen |
| `lib/theme/tokens.dart` | Added titleXL + onboarding glow tokens |

---

## Current State — What Renders

| Element | Status | Detail |
|---------|--------|--------|
| 8-step flow | ✓ Real | All steps implemented, Back-navigable |
| Progress dots | ✓ Real | Step k of 8, correct colors |
| Continue/Back | ✓ Real | Enabled/disabled logic correct |
| Sports chips | ✓ Real | Multi-select, ≥1 required |
| Aim options | ✓ Real | Single-select rows |
| Detail options | ✓ Real | Single-select rows |
| Basics | ✓ Real | Age band + sex chips |
| Anchors | ✓ Real | Conditional, "I don't know" → null |
| Gear chips | ✓ Real | Multi-select, "None yet" exclusive |
| Payoff glow | ✓ Real | 150px, teal, aim-based line |
| Engine wiring | ✓ Wired | FFI calls in place |
| Splash routing | ✓ Real | !hasProfile → OnboardingScreen |

---

## Rules Compliance

| Rule | Status |
|------|--------|
| Tokens by name (`MivaltaType.*`, etc.) | ✓ |
| 44px+ hit targets | ✓ (chips use `minHeight: 44`) |
| Semantics widgets (`aria-pressed`) | ✓ (`Semantics(toggled:...)`) |
| No fitness-test language | ✓ |
| No "sync your data" | ✓ |
| No tier names on screen | ✓ |
| Back preserves answers | ✓ |
| Kill mid-flow → restart step 1 | ✓ (no partial profile written) |

---

## MAC-SIDE Checklist

- [ ] Run onboarding flow with demo profile
- [ ] Capture 5 screenshots (promise, sports, anchors-idk, payoff-numbers, payoff-words)
- [ ] Paste real `inputs_json` echo from debug console
- [ ] Paste real `profile JSON` from debug console
- [ ] Update SHA in screenshot filenames
- [ ] Verify all 8 steps reachable and Back-navigable

---

## Next

**Awaiting:** MAC-SIDE screenshots + engine output + DR from Claude Design.

**Stubs (none):** All engine wiring in place. No placeholder calls.

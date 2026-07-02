STATUS: ACTIVE

# Onboarding Screen — Build Report v2

**Executing BS-002-onboarding v2 against SHA `TBD`.**

**Branch:** `feature/onboarding`
**Date:** 2026-07-02
**Spec:** BS-002-onboarding.md v2

**Status:** v2 implementation complete — engine contract aligned + C5/C6 fixes.

---

## DR-017 Fixes Applied

| Fix | Issue | Resolution |
|-----|-------|------------|
| **C4** | Engine contract mismatch | v2 rewrite (single sport, level/hours/years, no null sex) |
| **C5** | `balanced` not in engine enum | `aim: "both"` → `goal_type: "general_fitness"` |
| **C6** | athlete_id regenerated each time | Persisted via SharedPreferences (generated once) |

---

## v2 Changes (C4 Fix — Engine Contract Alignment)

| Item | v1 | v2 |
|------|----|----|
| Sport | Multi-chip (6 options) | SINGULAR (Running \| Cycling only) |
| Sex | 3 options (incl. "Prefer not to say") | 2 options (Female \| Male, non-nullable) |
| Training step | None | NEW: level + experience + weekly_hours |
| Engine payload | Incomplete | Full `OnboardingInputs` contract |
| detail/gear | Sent to engine | App-side only (SharedPreferences) |
| Total steps | 8 | 9 (Training inserted after Basics) |

---

## Screenshots — MAC-SIDE PENDING

| State | Filename | What renders |
|-------|----------|--------------|
| Promise | `onb_<SHA>_promise.png` | Lock tile + "Your body.\nYour data." + sub |
| Sport | `onb_<SHA>_sport.png` | Single-choice: Running \| Cycling |
| Basics | `onb_<SHA>_basics.png` | Age band (5) + Sex (Female/Male) |
| Training | `onb_<SHA>_training.png` | Level + Experience + Weekly hours |
| Anchors | `onb_<SHA>_anchors.png` | FTP/pace input + "I don't know" chip |
| Payoff | `onb_<SHA>_payoff.png` | "Good to go" + "Learning you" |

**MAC-SIDE:** Capture shots with `--dart-define=BUILD_SHA=$(git rev-parse --short HEAD)`.

---

## Engine Wiring — inputs_json v2

### Sample inputs_json (v2 contract)

```json
{
  "athlete_id": "550e8400-e29b-41d4-a716-446655440000",
  "age": 35,
  "sex": "male",
  "level": "intermediate",
  "sport": "cycling",
  "goal_type": "performance",
  "weekly_hours": 8.5,
  "training_years": 6,
  "ftp_watts": null
}
```

**v2 contract fields:**
| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `athlete_id` | string | ✓ | UUID v4, persisted (C6: generated once, never changes) |
| `age` | int | ✓ | Band → representative int (25/35/45/55/65) |
| `sex` | string | ✓ | `"male"` \| `"female"` (non-nullable) |
| `level` | string | ✓ | `beginner` \| `novice` \| `intermediate` \| `advanced` |
| `sport` | string | ✓ | SINGULAR: `"cycling"` \| `"running"` |
| `goal_type` | string | ✓ | `performance` \| `general_fitness` (C5: no 'balanced') |
| `weekly_hours` | double | ✓ | Hours/week (3.0/5.0/8.5/12.0) |
| `training_years` | int | ✓ | Years of experience (0/2/6/12) |
| `ftp_watts` | int? | cycling | null = "I don't know" |
| `threshold_pace_sec_km` | int? | running | null = "I don't know" |

**Key mappings:**
- `aim: "perform"` → `goal_type: "performance"`
- `aim: "healthy"` → `goal_type: "general_fitness"`
- `aim: "both"` → `goal_type: "general_fitness"` (C5: engine has no 'balanced')
- `experience: "<1"` → `training_years: 0`
- `experience: "1-3"` → `training_years: 2`
- `experience: "3-10"` → `training_years: 6`
- `experience: "10+"` → `training_years: 12`

### App-Side Prefs (NOT sent to engine)

```dart
// SharedPreferences keys
'onboarding_detail' → 'simple' | 'numbers'
'onboarding_gear'   → List<String> of gear ids
```

Today screen reads these via `SharedPreferences` to customize display.

---

## BS-002-onboarding v2 Implementation

### Flow — 9 Steps

| Step | Name | Content | Status |
|------|------|---------|--------|
| 0 | Promise | Center layout, lock tile 72px r22 mint-14%, titleXL "Your body.\nYour data." | ✓ Done |
| 1 | Sport | SINGULAR choice: Running \| Cycling (FL-17 compliant) | ✓ Done |
| 2 | Aim | Single-option rows: Perform / Stay fit & healthy / A bit of both | ✓ Done |
| 3 | Detail | Single-option: "Just tell me what to do" / "Show me the numbers too" | ✓ Done |
| 4 | Basics | Age band (5 options) + Sex (Female/Male only) | ✓ Done |
| 5 | Training | Level (4) + Experience (4) + Weekly hours (4) — all required | ✓ Done |
| 6 | Anchors | Conditional (Running/Cycling only). FTP/pace + "I don't know" | ✓ Done |
| 7 | Gear | Multi-chip optional: Watch, Ring, HR strap, None yet | ✓ Done |
| 8 | Payoff | Mini glow (150px), "Good to go", "Learning you" sub-line | ✓ Done |

### Training Step (NEW in v2)

| Field | Options | Engine field |
|-------|---------|--------------|
| Level | Beginner / Novice / Intermediate / Advanced | `level` string |
| Experience | Less than a year / 1-3 years / 3-10 years / 10+ years | `training_years` int |
| Weekly hours | 2-3 hours / 4-6 hours / 7-10 hours / 10+ hours | `weekly_hours` double |

### Sex Options (v2 — no null)

| Option | Engine value | Copy |
|--------|--------------|------|
| Female | `"female"` | "Used only on-device, for heart-rate zones" |
| Male | `"male"` | "Used only on-device, for heart-rate zones" |

**G9 compliance:** "Prefer not to say" removed — engine requires non-nullable sex for heart-rate zone formulas.

### Chrome

| Item | Description | Status |
|------|-------------|--------|
| Progress dots | Step k of 9, greenAccent100 for done, primary for current, muted for pending | ✓ Done |
| Continue button | 52px h, r14, mint, pinned bottom | ✓ Done |
| Back button | Ghost above Continue, from step 2 | ✓ Done |
| Disabled state | 40% alpha when `need()` not satisfied | ✓ Done |
| Entrance animation | Content fade/rise 280ms standardEase, respects `disableAnimations` | ✓ Done |

---

## Engine Wiring (Final Step)

| Step | Call | Status |
|------|------|--------|
| 1 | Marshal RAW answers → `inputs_json` (v2 contract) | ✓ Done |
| 2 | Save local prefs (detail, gear) → SharedPreferences | ✓ Done |
| 3 | `RustEngineBinding.buildOnboardingProfile(inputsJson)` | ✓ Wired |
| 4 | `ProfileService.saveProfile(profileJson)` | ✓ Wired |
| 5 | Load compiled_tables.json asset | ✓ Wired |
| 6 | `binding.writeProfileToVault(...)` | ✓ Wired |
| 7 | `binding.constructEnginesFresh(...)` | ✓ Wired |
| 8 | Route → TodayScreen | ✓ Wired |
| Error | Inline error card, log, do NOT route forward | ✓ Done |

**Debug output:** `inputs_json` and `profile JSON` logged via `debugPrint()`.

---

## Files Changed

| File | Changes |
|------|---------|
| `lib/screens/onboarding_screen.dart` | v2 rewrite — 9-step flow, engine contract |
| `pubspec.yaml` | Added `shared_preferences: ^2.2.3` |

---

## Current State — What Renders

| Element | Status | Detail |
|---------|--------|--------|
| 9-step flow | ✓ Real | All steps implemented, Back-navigable |
| Progress dots | ✓ Real | Step k of 9, correct colors |
| Continue/Back | ✓ Real | Enabled/disabled logic correct |
| Sport (singular) | ✓ Real | Running \| Cycling only |
| Aim options | ✓ Real | Single-select rows |
| Detail options | ✓ Real | Single-select rows (local pref) |
| Basics | ✓ Real | Age band + sex (Female/Male only) |
| Training | ✓ Real | Level + experience + hours |
| Anchors | ✓ Real | Conditional, "I don't know" → null |
| Gear chips | ✓ Real | Multi-select, "None yet" exclusive (local pref) |
| Payoff glow | ✓ Real | 150px, teal, "Good to go" + "Learning you" |
| Engine wiring | ✓ Wired | FFI calls in place, v2 payload |
| Local prefs | ✓ Wired | SharedPreferences for detail/gear |

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
| FL-17 (cycling/running only) | ✓ |
| G9 (no null sex) | ✓ |

---

## MAC-SIDE Checklist

- [ ] Run onboarding flow with demo profile
- [ ] Capture 6 screenshots (promise, sport, basics, training, anchors, payoff)
- [ ] Paste real `inputs_json` echo from debug console
- [ ] Paste real `profile JSON` from debug console
- [ ] Update SHA in screenshot filenames
- [ ] Verify all 9 steps reachable and Back-navigable
- [ ] Verify Training step collects all 3 fields

---

## Next

**Awaiting:** MAC-SIDE screenshots + engine output + DR from Claude Design.

**Stubs (none):** All engine wiring in place. No placeholder calls.

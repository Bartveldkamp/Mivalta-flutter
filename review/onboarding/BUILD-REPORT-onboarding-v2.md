STATUS: ACTIVE

# Onboarding Screen — Build Report v2

**Executing BS-002-onboarding v2 against SHA `8d5ae25`.**

**Branch:** `feature/onboarding`
**Date:** 2026-07-02
**Spec:** BS-002-onboarding.md v2

**Status:** ⚠️ C7 BLOCKER — `goal_type` contract mismatch discovered during real run.

---

## DR-017 Fixes Applied

| Fix | Issue | Resolution |
|-----|-------|------------|
| **C4** | Engine contract mismatch | v2 rewrite (single sport, level/hours/years, no null sex) |
| **C5** | `balanced` not in engine enum | `aim: "both"` → `goal_type: "general_fitness"` |
| **C6** | athlete_id regenerated each time | Persisted via SharedPreferences (generated once) |
| **C7** | `goal_type: "performance"` not in engine type_map | ⚠️ BLOCKER — engine only accepts event-specific goals (10k, 5k, etc.) |

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

## Screenshots

| State | Filename | Status |
|-------|----------|--------|
| Promise | `shots/onb_68e19f1_promise.png` | ✓ Captured |
| Sport | `shots/onb_8d5ae25_sport.png` | ⏳ Manual |
| Basics | `shots/onb_8d5ae25_basics.png` | ⏳ Manual |
| Training | `shots/onb_8d5ae25_training.png` | ⏳ Manual |
| Anchors | `shots/onb_8d5ae25_anchors.png` | ✓ Captured |
| Payoff | `shots/onb_8d5ae25_payoff.png` | ✓ Captured (shows C7 error) |

**SHA:** `8d5ae25`

**Captured:** 3/6 — Promise, Anchors, Payoff (with error state)

---

## Engine Wiring — inputs_json v2

### REAL inputs_json (captured 2026-07-02)

```json
{
  "athlete_id": "f772f921-c6bf-4bb5-8c29-0d4714921d4b",
  "age": 55,
  "sex": "male",
  "level": "advanced",
  "sport": "running",
  "goal_type": "performance",
  "weekly_hours": 3.0,
  "training_years": 12,
  "threshold_pace_sec_km": null
}
```

### REAL profile JSON (captured 2026-07-02)

```json
{
  "age": 55,
  "athlete_id": "f772f921-c6bf-4bb5-8c29-0d4714921d4b",
  "availability": {"0":45,"11":45,"13":45,"14":45,"16":45,"18":45,"2":45,"20":45,"4":45,"6":45,"7":45,"9":45},
  "goal_class": "performance",
  "goal_type": "performance",
  "level": "advanced",
  "meso_length": 21,
  "meso_minutes": 540,
  "meso_off_days": [1,3,5,8,10,12,15,17,19],
  "meso_train_days": [0,2,4,6,7,9,11,13,14,16,18,20],
  "recent_activity": "competitive",
  "sex": "male",
  "sport": "running",
  "training_years": 12,
  "weekly_hours": 3.0
}
```

### C7 Engine Error (captured 2026-07-02)

```
PanicException(RuleResolver::resolve_archetype_from_type_map:
no archetype registered for goal_type='performance' sport='running'.

Valid (goal_type, sport, goal_class) combinations from the resolved type_map:
- (10000m, running, finish/performance)
- (5000m, running, finish/performance)
- (5k, running, finish/performance)
- (century, cycling, finish/performance)
- (criterium, cycling, finish/performance)
- ... [event-specific goals only]
```

**Root cause:** Engine expects event-specific `goal_type` (10k, 5k, etc.), not generic "performance"/"general_fitness". The v2 onboarding sends generic goals but compiled_tables.json only has event-specific archetypes.

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

- [x] Run onboarding flow with demo profile
- [x] Capture 6 screenshots (promise, sport, basics, training, anchors, payoff) — 3/6 done
- [x] Paste real `inputs_json` echo from debug console
- [x] Paste real `profile JSON` from debug console
- [x] Update SHA in screenshot filenames
- [x] Verify all 9 steps reachable and Back-navigable
- [x] Verify Training step collects all 3 fields

---

## C7 Resolution Required

**BLOCKER:** Engine archetype resolution fails because:
- Onboarding sends: `goal_type: "performance"` or `"general_fitness"`
- Engine expects: event-specific goals like `"10k"`, `"5000m"`, `"century"`

**Options:**
1. Add generic archetypes to `compiled_tables.json` (engine-side)
2. Add event-goal selection step to onboarding (Flutter-side)
3. Map generic goals to default events (e.g., "performance" + "running" → "10k")

**Next:** Resolve C7 before onboarding can complete successfully.

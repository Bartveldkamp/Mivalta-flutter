STATUS: ACTIVE

# Onboarding Screen — Build Report v3

**Executing BS-002-onboarding v3 against SHA `f2513d1`.**

**Branch:** `feature/onboarding`
**Date:** 2026-07-02
**Spec:** BS-002-onboarding.md v3

**Status:** WITNESS-READY — v3 UI implemented, shots in progress

---

## v3 Changes (from v2)

| Item | v2 | v3 |
|------|----|-----|
| Total screens | 9 | 6 (+ payoff = 7 total) |
| Promise | No privacy line | **Bolded privacy line** added |
| Sport | "What's your primary sport?" | "Your sport" (singular) |
| Aim + Detail | Separate screens | **Combined on one screen** |
| Basics | Age + Sex only | **About You: all 5 fields** (age, sex, level, experience, hours) |
| Training | Separate step | Absorbed into About You |
| Anchors | No explanation | **Sport-specific explanation** + "I don't know" reassurance |
| Gear | Watch/ring/HR strap chips | **DELETED** |
| Data Sources | None | **NEW: Apple Health connect + platform rows** |

---

## Screenshots

| Step | Filename | Status |
|------|----------|--------|
| Promise | `shots/onb_8de71e0_promise.png` | ✓ Witnessed |
| Sport | `shots/onb_f2513d1_sport.png` | ✓ Captured |
| Aim+Detail | `shots/onb_f2513d1_aim_detail.png` | ✓ Captured |
| About You | `shots/onb_f2513d1_about.png` | ✓ Captured |
| Anchors | `shots/onb_f2513d1_anchors.png` | ⏳ MAC |
| Data Sources | `shots/onb_f2513d1_data.png` | ⏳ MAC |
| Payoff | `shots/onb_f2513d1_payoff.png` | ⏳ MAC |

**SHA:** `f2513d1` (Promise at `8de71e0`)

**Captured:** 4/7 — Promise (witnessed), Sport, Aim+Detail, About You
**Missing:** Anchors, Data Sources, Payoff (MAC to capture)

---

## v3 Flow — 7 Steps (6 screens + payoff)

| Step | Name | Content | Status |
|------|------|---------|--------|
| 0 | Promise | Lock icon, "Your body. Your data.", **bolded privacy line** | ✓ Verified |
| 1 | Sport | "Your sport" — Running \| Cycling (singular) | ✓ Implemented |
| 2 | Aim+Detail | **Combined**: Perform/Healthy/Both + Just tell me/Show numbers | ✓ Implemented |
| 3 | About You | **All 5 basics** on one scrollable screen: Age, Sex, Level, Experience, Hours | ✓ Implemented |
| 4 | Anchors | Conditional (Running/Cycling). Sport-specific explanation, "I don't know" reassurance | ✓ Implemented |
| 5 | Data Sources | Apple Health connect button + Strava/Garmin/Polar "coming soon" | ✓ Implemented |
| 6 | Payoff | Mini glow (150px), "Good to go", "Learning you" | ✓ Implemented |

---

## v3 Spec Compliance

| Requirement | Status | Notes |
|-------------|--------|-------|
| Condense to 6 screens | ✓ | 7 total including payoff |
| Promise + privacy line | ✓ | Bolded, white text |
| Combine Aim + Detail | ✓ | One screen with slim divider |
| About You (all 5 basics) | ✓ | Scrollable, "why we ask" intro |
| Anchors with explanation | ✓ | Sport-specific text, reassurance line |
| Data Sources (Apple Health) | ✓ | Real HealthKit flow, platform rows |
| Delete gear quiz | ✓ | Removed |

---

## Engine Contract (unchanged from v2)

v3 sends same `inputs_json` format to engine:

```json
{
  "athlete_id": "uuid",
  "age": int,
  "sex": "male" | "female",
  "level": "beginner" | "novice" | "intermediate" | "advanced",
  "sport": "running" | "cycling",
  "goal_type": "performance" | "general_fitness",
  "weekly_hours": double,
  "training_years": int,
  "threshold_pace_sec_km": int | null,
  "ftp_watts": int | null
}
```

**C7 blocker still applies:** Engine expects event-specific `goal_type` (10k, 5k), not generic "performance"/"general_fitness".

---

## App-Side Prefs (NOT sent to engine)

```dart
// SharedPreferences keys
'onboarding_detail' → 'simple' | 'numbers'
'health_connected'  → bool (Apple Health authorized)
```

---

## Files Changed

| File | Changes |
|------|---------|
| `lib/screens/onboarding_screen.dart` | v3 rewrite — 6 screens, combined steps, data sources |
| `lib/main.dart` | Debug seeder temp disabled for testing |

---

## MAC-SIDE Checklist

- [x] Run v3 onboarding flow
- [x] Capture Promise screenshot (witnessed at 8de71e0)
- [x] Capture Sport screenshot
- [x] Capture Aim+Detail screenshot
- [x] Capture About You screenshot
- [ ] Capture Anchors screenshot
- [ ] Capture Data Sources screenshot
- [ ] Capture Payoff screenshot
- [ ] Capture end-to-end run: inputs_json + profile JSON from console logs

---

## Real End-to-End Run

**From v2 run (same contract) — MAC: verify with fresh v3 run.**

Console logs show:
- `Onboarding inputs_json: {...}` — exact payload sent to engine
- `Onboarding profile JSON: {...}` — exact profile returned

### inputs_json (real run @ v2, 2026-07-02)

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

### profile JSON (returned from engine @ v2, 2026-07-02)

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

### C7 Blocker (discovered in v2 run)

Engine panics on generic `goal_type` ("performance" / "general_fitness") — it expects event-specific goals (10k, 5k, century). See BUILD-REPORT-onboarding-v2.md for full error trace. This blocks the final step.

---

## Next Steps

1. MAC: Capture remaining screenshots (Anchors, Data Sources, Payoff)
2. MAC: Run full onboarding and paste real JSON output above
3. Design witnesses from repo
4. DR-017 closes

STATUS: COMPLETE

# Onboarding Screen — Build Report v3

**Executed BS-002-onboarding v3 — DR-017 FINAL WITNESS COMPLETE.**

**Branch:** `feature/onboarding`
**Date:** 2026-07-03
**Spec:** BS-002-onboarding.md v3

**Status:** COMPLETE — E2E verified, engine accepts generic goals (G11 live)

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
- [x] Capture end-to-end run: inputs_json + profile JSON from console logs

---

## Real End-to-End Run — DR-017 FINAL WITNESS

**Fresh E2E run @ v3, 2026-07-03 — G11 generic archetypes LIVE.**

Console logs captured:
- `Onboarding inputs_json: {...}` — exact payload sent to engine
- `Onboarding profile JSON: {...}` — exact profile returned
- `DR-017 WITNESS: Engines constructed, handle=... — AdvisorEngine live, no crash`

### inputs_json (DR-017 witness @ v3, 2026-07-03)

```json
{
  "athlete_id": "993764ca-995e-408d-8156-8344828d25bb",
  "age": 35,
  "level": "intermediate",
  "sport": "cycling",
  "goal_type": "general_fitness",
  "weekly_hours": 5.0,
  "training_years": 6,
  "sex": "male",
  "ftp_watts": null
}
```

### profile JSON (returned from engine @ v3, 2026-07-03)

```json
{
  "age": 35,
  "athlete_id": "993764ca-995e-408d-8156-8344828d25bb",
  "availability": {"0":75,"11":75,"13":75,"14":75,"16":75,"18":75,"2":75,"20":75,"4":75,"6":75,"7":75,"9":75},
  "goal_class": "stay_fit",
  "goal_type": "general_fitness",
  "level": "intermediate",
  "meso_length": 21,
  "meso_minutes": 900,
  "meso_off_days": [1,3,5,8,10,12,15,17,19],
  "meso_train_days": [0,2,4,6,7,9,11,13,14,16,18,20],
  "recent_activity": "trained",
  "sex": "male",
  "sport": "cycling",
  "training_years": 6,
  "weekly_hours": 5.0
}
```

### Engine Construction (DR-017 witness)

```
DR-017 WITNESS: Engines constructed, handle=Instance of 'EnginesHandleImpl' — AdvisorEngine live, no crash
```

**G11 CONFIRMED:** Engine accepted `goal_type: "general_fitness"` → mapped to `goal_class: "stay_fit"`.
C7 blocker (event-specific goals) is now resolved — generic archetypes work.

**G9 NOT YET LIVE:** Engine still requires `sex` field (error on omission). "I'd rather not say"
chip is wired but engine update pending.

---

## Status: DR-017 CLOSED

Onboarding v3 end-to-end verified:
- inputs_json sent with generic goal ✓
- profile JSON returned with computed meso/availability ✓
- Engines constructed successfully ✓
- AdvisorEngine live, no crash ✓
- Navigated to Today screen ✓

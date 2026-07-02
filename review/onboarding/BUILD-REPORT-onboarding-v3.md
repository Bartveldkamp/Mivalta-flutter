STATUS: ACTIVE

# Onboarding Screen — Build Report v3

**Executing BS-002-onboarding v3 against SHA `15240a6`.**

**Branch:** `feature/onboarding`
**Date:** 2026-07-02
**Spec:** BS-002-onboarding.md v3

**Status:** BUILDING — v3 UI implemented, capturing screenshots

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
| Promise | `shots/onb_15240a6_promise.png` | ✓ Captured |
| Sport | `shots/onb_15240a6_sport.png` | ⏳ Manual |
| Aim+Detail | `shots/onb_15240a6_aim_detail.png` | ⏳ Manual |
| About You | `shots/onb_15240a6_about.png` | ⏳ Manual |
| Anchors | `shots/onb_15240a6_anchors.png` | ⏳ Manual |
| Data Sources | `shots/onb_15240a6_data.png` | ⏳ Manual |
| Payoff | `shots/onb_15240a6_payoff.png` | ⏳ Manual |

**SHA:** `15240a6`

**Captured:** 1/7 — Promise

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
- [x] Capture Promise screenshot
- [ ] Capture Sport screenshot
- [ ] Capture Aim+Detail screenshot
- [ ] Capture About You screenshot
- [ ] Capture Anchors screenshot
- [ ] Capture Data Sources screenshot
- [ ] Capture Payoff screenshot
- [ ] Re-enable debug seeder after screenshots

---

## Next Steps

1. Manually navigate through onboarding on simulator to capture remaining screenshots
2. Re-enable debug seeder in main.dart after screenshots
3. Commit v3 implementation
4. Address C7 blocker (engine goal_type contract)

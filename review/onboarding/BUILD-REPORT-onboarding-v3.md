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

**MAC: Run a full onboarding flow and paste the actual JSON below.**

The console log will show:
- `Onboarding inputs_json: {...}` — the exact payload sent to engine
- `Onboarding profile JSON: {...}` — the exact profile returned

### inputs_json (real run)

```json
// MAC: paste the actual inputs_json from `debugPrint` here
```

### profile JSON (returned from engine)

```json
// MAC: paste the actual profile JSON from `debugPrint` here
```

---

## Next Steps

1. MAC: Capture remaining screenshots (Anchors, Data Sources, Payoff)
2. MAC: Run full onboarding and paste real JSON output above
3. Design witnesses from repo
4. DR-017 closes

# Simulator Walkthrough Audit Report

**Date:** 2025-06-15
**Device:** iPhone 16 Pro Simulator
**Branch:** main (post git pull + xcframework rebuild)

---

## Critical Finding: Engine Restore Failure

**The demo data seeder ran successfully** ("Seeded 30 simulated days"), but the
**engine failed to restore** on app restart:

```
flutter: persisted-state restore failed — _$BridgeError_EngineConstructionFailedImpl:
BridgeError.engineConstructionFailed(field0: viterbi restore: Missing 'current_state'
in persisted Viterbi state)
```

This means the Rust engine could not reconstruct its state from the seeded data.
All screens show empty/error states as a result — **not a Flutter UI bug, but an
engine-layer state persistence issue**.

---

## Screen-by-Screen Audit

| Screen | Renders? | Real Data? | Warm Voice? | Issue | Screenshot |
|--------|----------|------------|-------------|-------|------------|
| **Today** | Yes | No — empty state | Yes ("We need more data to predict recovery.") | Engine restore failed; shows honest empty state | `01_today.png` |
| **Journey** | Yes | No — error state | N/A | "Couldn't load your journey." — engine unavailable | `02_journey.png` |
| **You** | Yes | N/A (menu) | N/A | Renders correctly; all 4 menu items visible | `03_you.png` |
| **Settings** | Yes | Profile shows | N/A | Units toggle, Profile, Privacy sections render | `04_settings.png` |
| **Settings (Export)** | Yes | N/A | N/A | Export Encrypted Backup, Export CSV, Delete All render | `05_settings_export.png` |
| **Settings (Developer)** | Yes | Seeder worked | N/A | Demo data section renders; seeder confirmed "30 days" | `06_settings_developer.png` |
| **Advisor** | Not tested | — | — | Requires engine; not reachable without readiness | — |
| **Manual entry** | Not tested | — | — | Would need to navigate from readiness | — |
| **Readiness detail** | Not tested | — | — | Requires engine data | — |

---

## What Works (UI Layer)

1. **Today screen structure** — JOSI card, readiness ring, tiles, tab bar all render
2. **Warm voice copy** — "We need more data to predict recovery." (locked copy, correct)
3. **Why? reveal** — Button present on JOSI card
4. **Configurable tiles** — Tune icon visible; Last night, Training load, Today tiles
5. **Journey screen structure** — Title, tab bar render; error state is honest
6. **You menu** — All 4 sections: Profile & settings, Trends & history, Privacy & data, SourceTier exerciser
7. **Settings sections** — Preferences (Units toggle), Your Profile, Privacy & On-Device, Data Sources, Export, Delete Everything, Developer · Demo data
8. **Units toggle** — Metric/Imperial segmented button (Imperial selected)
9. **Privacy proof section** — "100% on your device", "Encrypted vault" with SQLCipher explanation
10. **Demo data seeder** — Ran and reported "Seeded 30 simulated days"
11. **WeatherKit** — Expected failure on simulator (noted as "honest absence")

---

## What's Broken (Engine Layer)

1. **Engine state restore** — `viterbi restore: Missing 'current_state' in persisted Viterbi state`
   - The seeder writes data but the engine can't reconstruct from it
   - This is a Rust engine bug, not Flutter

2. **Journey data** — Shows error because engine handle is unavailable

3. **All engine-dependent screens** — Cannot show real computed readiness, trends, advisor suggestions

---

## Honest Empty States (Working as Designed)

These are correct UI behaviors when no data exists:

- "We need more data to predict recovery." — JOSI card (warm, locked copy)
- "No sleep data yet" — Last night tile
- "Still learning your load" — Training load tile
- "Nothing logged yet" — Today tile
- "Couldn't load your journey." — Journey screen (engine error)
- "No data sources connected yet." — Settings > Data Sources

---

## Weather Note

```
flutter: weather unavailable — weatherkit: The operation couldn't be completed.
(WeatherDaemon.WDSJWTAuthenticatorServiceListener.Errors error 2.)
```

This is expected on simulator — WeatherKit requires device entitlements. **Not a bug.**

---

## Screenshots

All screenshots saved to `docs/audit_screenshots/`:

1. `01_today.png` — Today screen empty state
2. `02_journey.png` — Journey error state
3. `03_you.png` — You menu
4. `04_settings.png` — Settings top (Preferences, Profile, Privacy)
5. `05_settings_export.png` — Settings middle (Export, Delete)
6. `06_settings_developer.png` — Settings bottom (Developer · Demo data)

---

## Root Cause for Follow-Up

**The demo data seeder successfully injects biometric history**, but **the engine's
Viterbi HMM restore expects a `current_state` field** that isn't present in the
persisted format.

This is a **mivalta-rust-engine** issue:
- File: likely `viterbi.rs` or engine state serialization
- The persisted JSON is missing a required field for restore

**Recommendation:** Fix engine state serialization/deserialization to include
`current_state`, or update the seeder to write a complete engine snapshot.

---

## Summary

| Category | Status |
|----------|--------|
| Flutter UI | **Works** — all screens render, honest empty states |
| Warm voice copy | **Works** — JOSI card shows locked copy |
| Settings | **Works** — all sections including Developer seeder |
| Engine integration | **Broken** — restore fails, no computed data |
| Demo data flow | **Blocked** — seeder runs but engine can't consume |

**Next step:** Fix engine state restore in mivalta-rust-engine before re-testing
data flow through the Flutter UI.

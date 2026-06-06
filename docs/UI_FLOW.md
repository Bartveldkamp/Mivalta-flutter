# MiValta Flutter — UI/UX Flow, Screens & Wiring

Status: living map. Date: 2026-06-06. Source: read from `lib/` (not from spec).
Reconciles to `UI_UX_DIRECTION.md` (rust-engine) and the engine pin in `rust/Cargo.toml`.

Principle (every arrow obeys it): **the Rust engine DECIDES/COMPUTES, the FFI PASSES
THROUGH, Flutter DISPLAYS.** No thresholds/math/fabrication in Dart.

---

## 1. Navigation flow (screens + subscreens)

```mermaid
flowchart TD
    A[main.dart · MivaltaApp] --> B[_AppEntryPoint]
    B -->|first run / no profile| ON[OnboardingScreen]
    B -->|profile + persisted state exist| RS[ReadinessScreen — HOME / hub]
    ON -->|pop OnboardingResult profileJson| RS

    RS -->|tap readiness| RD[ReadinessDetailScreen]
    RS -->|Add data| ME[ManualEntryScreen]
    RS -->|Workout options| AD[AdvisorScreen]
    RS -->|Settings| SE[SettingsScreen]
    RS -. kDebugMode .-> DBG[DebugSwatchExerciser]

    ME -->|pop true = data entered → refresh| RS
    SE -->|reset → popUntil first| RS
    DBG -. debug .-> RS

    classDef tier1 fill:#143,stroke:#2BD974,color:#fff;
    classDef tier2 fill:#134,stroke:#00C6A7,color:#fff;
    classDef entry fill:#222,stroke:#888,color:#fff;
    class RS,RD,ME,SE tier1;
    class AD tier2;
    class A,B,ON,DBG entry;
```

**Tiers** (per `UI_UX_DIRECTION` v1.4 + DECISIONS Entry X):
- 🟢 **MONITOR** (free, no Josi): `ReadinessScreen`, `ReadinessDetailScreen`, `ManualEntryScreen`, `SettingsScreen`, `OnboardingScreen`.
- 🔵 **ADVISOR** (Josi layer): `AdvisorScreen` (bounded A/B/C; humanized voice deferred to PR-F).
- ⚪ **COACH** (post-beta): planning / open conversation — not yet built.

---

## 2. ReadinessScreen — the hub (three-zone PULL home)

```mermaid
flowchart LR
    subgraph RS[ReadinessScreen]
      Z1[Zone 1 · STATE<br/>readiness + Viterbi state + confidence]
      Z2[Zone 2 · TODAY<br/>suggested session + source tier]
      Z3[Zone 3 · CONTEXT<br/>ACWR / monotony / strain]
    end
    Z1 --> RD2[→ ReadinessDetailScreen]
    Z2 --> AD2[→ AdvisorScreen]
```

Engine wiring (facade calls): `readinessIndicator`, `readinessScore`,
`viterbiFatigueState`, `zoneCapWithAdvisories`, `getStateWidget`,
`getSessionWidget`, `getContextWidget`, `readReadinessHistory`,
`lastObservationSourceTier`. Lifecycle: `readPersistedState` →
`constructEnginesFromState` | `constructEnginesFresh` → `saveState` →
`writeViterbiState`. Auto data sync via `HealthIngestService`.

---

## 3. Subscreen composition + engine wiring

```mermaid
flowchart TD
    RD[ReadinessDetailScreen]
    RD --> H[Hero · score/level]
    RD --> AX[Axis breakdown · 4-axis blend]
    RD --> TR[Trend · 30-day readiness]
    RD --> TL[Training Load ★ daily bars]
    RD --> PW[Power Profile ★ MMP curve]
    RD --> CN[Coach Note · advisories]
    RD --> SC[Source + Confidence]

    AD[AdvisorScreen]
    AD --> PP[Preferences · mood/equipment/terrain]
    AD --> OL[A/B/C option cards · equal weight]

    ME[ManualEntryScreen]
    SE[SettingsScreen]

    %% engine wiring (facade → shim → gatc-ffi)
    RD -. readinessIndicator / readinessScore / readReadinessHistory .-> E1[(ViterbiEngine)]
    RD -. getStateWidget .-> E2[(DashboardEngine)]
    TL -. readDailyLoads ★ .-> E3[(VaultEngine)]
    PW -. readMmpHistory ★ .-> E3
    AD -. recommendWorkout .-> E4[(AdvisorEngine)]
    ME -. processManualObservation / writeMinimalBiometric / writeViterbiState .-> E1
    SE -. updateProfile / buildSourceOverview / exportBiometricsCsv / exportEncryptedVault / clearAllUserData .-> E3
    ON2[OnboardingScreen] -. profileJson .-> E3

    %% ★ = wired via pure pass-through FFI (PR #44)
```

`★` = the analytics surfaces wired in PR #44 via **pure pass-through** FFI
(`read_daily_loads`, `read_mmp_history`).

---

## 4. The data wiring (engine → display), one layer at a time

```mermaid
flowchart LR
    UI[Flutter screen / widget] --> FAC[rust_engine.dart · facade]
    FAC --> FRB[lib/src/rust · FRB bindings]
    FRB --> SHIM[rust/src/api.rs · shim<br/>ONE gatc_ffi call per fn, no compute]
    SHIM --> ENG[gatc-ffi engines<br/>Viterbi · Advisor · Vault · Dashboard · Normalizer]
    ENG --> V[(SQLCipher vault)]
    ENG -->|knowledge cards| K[(compiled tables)]

    classDef pure fill:#102,stroke:#00C6A7,color:#fff;
    class SHIM pure;
```

- **Shim is pure transport** (rule: zero computation in the bridge).
- **Dart is display-only** (no thresholds/math/fallback).
- **External data in**: `HealthIngestService` (Health Connect / HealthKit) →
  `processObservation`; or `ManualEntryScreen` → `processManualObservation`.

---

## 5. Screen inventory (source of truth)

| Screen | File | Tier | Returns | Key engine calls |
|---|---|---|---|---|
| AppEntryPoint | `main.dart` | — | — | `readPersistedState`, `constructEngines*` |
| OnboardingScreen | `screens/onboarding_screen.dart` | Monitor | `OnboardingResult(profileJson)` | (ProfileService → vault) |
| **ReadinessScreen** (hub) | `screens/readiness_screen.dart` | Monitor | — | `readinessIndicator`, `getStateWidget`, `getSessionWidget`, `getContextWidget`, … |
| ReadinessDetailScreen | `screens/readiness_detail_screen.dart` | Monitor | — | `readinessIndicator`, `readReadinessHistory`, `readDailyLoads ★`, `readMmpHistory ★` |
| AdvisorScreen | `screens/advisor_screen.dart` | Advisor | — | `recommendWorkout` |
| ManualEntryScreen | `screens/manual_entry_screen.dart` | Monitor | `bool` (data entered) | `processManualObservation`, `writeMinimalBiometric` |
| SettingsScreen | `screens/settings_screen.dart` | Monitor | varies | `updateProfile`, `exportEncryptedVault`, `clearAllUserData` |
| DebugSwatchExerciser | `screens/debug_swatch_exerciser.dart` | debug | — | — |

★ wired in PR #44 (pure pass-through). Analytics surfaces still to wire
(roadmap): PMC fitness series, workout-detail composite (need new engine getters).

# UI/UX Clean-out Plan

**Status**: HELD FOR APPROVAL
**Date**: 2026-06-30
**Scope**: Strip entire UI/UX layer to blank shell, preserve all plumbing

---

## The Line

**REMOVE** — all UI/UX (presentation layer)
**KEEP** — all plumbing (engine wiring, models, services, bridge, vault, tokens)

---

## FILES TO DELETE (32 files)

### lib/screens/ — ALL 13 screens

| File | Type | Notes |
|------|------|-------|
| `advisor_screen.dart` | UI | Workout suggestions surface |
| `app_shell.dart` | UI | Navigation shell (Today/Journey/You) |
| `debug_swatch_exerciser.dart` | UI | Debug-only SourceTier tester |
| `explore_screen.dart` | UI | Analytics/trends surface |
| `journey_screen.dart` | UI | Activity history surface |
| `manual_entry_screen.dart` | UI | Manual biometric entry |
| `onboarding_screen.dart` | UI | First-launch wizard (see AMBIGUOUS) |
| `readiness_detail_screen.dart` | UI | Readiness breakdown |
| `readiness_screen.dart` | UI | Home screen (see AMBIGUOUS) |
| `sensor_check_screen.dart` | UI | BLE sensor pairing |
| `settings_screen.dart` | UI | Settings/privacy |
| `workout_detail_page.dart` | UI | Post-workout detail |
| `you_screen.dart` | UI | Profile hub |

### lib/widgets/ — ALL 19 widgets

| File | Type | Notes |
|------|------|-------|
| `analytics/biometric_chart.dart` | UI | Chart widget |
| `analytics/critical_power_card.dart` | UI | CP display card |
| `analytics/decoupling_card.dart` | UI | Decoupling display |
| `analytics/fitness_trend_chart.dart` | UI | Fitness trend chart |
| `analytics/load_strain_card.dart` | UI | Load/strain display |
| `analytics/post_workout_report_card.dart` | UI | Report card |
| `analytics/power_curve_chart.dart` | UI | MMP chart |
| `analytics/sleep_trend_card.dart` | UI | Sleep trend display |
| `analytics/time_in_zone_chart.dart` | UI | TiZ chart |
| `analytics/training_load_chart.dart` | UI | Load chart |
| `analytics/workout_detail_card.dart` | UI | Workout detail card |
| `josi_presenter.dart` | UI | Josi "why" reveal |
| `learning_status_card.dart` | UI | Learning progress |
| `readiness_light_field.dart` | UI | Light-field hero |
| `today/decision_chip.dart` | UI | Decision indicator |
| `today/glow_hero.dart` | UI | Glow hero (#122 new) |
| `today/josi_line.dart` | UI | Josi line (#122 new) |
| `today/module_card.dart` | UI | Module card (#122 new) |
| `today/today_body.dart` | UI | Today body (#122 new) |
| `today/today_widgets.dart` | UI | Barrel export |
| `today_facts.dart` | UI | Today facts tiles |
| `weather.dart` | UI | Weather overlay |

**Total UI deletions: 32 files**

---

## FILES TO KEEP (42 files)

### lib/models/ — ALL 16 models (plumbing)

| File | Notes |
|------|-------|
| `activity_summary.dart` | Engine output parse model |
| `biometric_series.dart` | Engine output parse model |
| `critical_power.dart` | Engine output parse model |
| `decoupling_trend.dart` | Engine output parse model |
| `fitness_trend.dart` | Engine output parse model |
| `learning_status.dart` | Engine output parse model |
| `load_context.dart` | Engine output parse model |
| `metric_series.dart` | Engine output parse model |
| `power_curve.dart` | Engine output parse model |
| `realized_line.dart` | Engine output parse model |
| `sleep_trend.dart` | Engine output parse model |
| `time_in_zone.dart` | Engine output parse model |
| `training_load.dart` | Engine output parse model |
| `workout_detail.dart` | Engine output parse model |
| `workout_option.dart` | Engine output parse model |
| `workout_report.dart` | Engine output parse model |

### lib/services/ — ALL 10 services (plumbing)

| File | Notes |
|------|-------|
| `ble/ble_hr_service.dart` | BLE heart rate plumbing |
| `ble/ble_transport.dart` | BLE transport interface |
| `ble/flutter_blue_transport.dart` | BLE impl |
| `ble/hr_measurement.dart` | BLE HR data model |
| `health_ingest.dart` | Health Connect / HealthKit ingest |
| `ingest_adapter.dart` | Shared ingest pipeline |
| `journey_tiles_prefs.dart` | SharedPreferences |
| `profile_service.dart` | Profile persistence |
| `today_tiles_prefs.dart` | SharedPreferences |
| `unit_prefs.dart` | Unit preferences |
| `weather_service.dart` | OS WeatherKit channel |

### lib/theme/ — BOTH (design foundation)

| File | Notes |
|------|-------|
| `source_tier.dart` | SourceTier colours (LOCKED) |
| `tokens.dart` | Design tokens (foundation for new UI) |

### lib/copy/ — ALL 6 (locked copy strings)

| File | Notes |
|------|-------|
| `axis_labels.dart` | Label mappings |
| `f1.dart` | LOCKED F1 copy |
| `journey_labels.dart` | Label mappings |
| `today_facts_labels.dart` | Label mappings |
| `trust_story.dart` | Trust prose |
| `zone_labels.dart` | Zone labels (energy system names) |

### lib/src/rust/ — ALL 5 (FRB bridge)

| File | Notes |
|------|-------|
| `api.dart` | FRB generated |
| `api.freezed.dart` | FRB generated |
| `frb_generated.dart` | FRB generated |
| `frb_generated.io.dart` | FRB generated |
| `frb_generated.web.dart` | FRB generated |

### lib/ root — 3 files

| File | Notes |
|------|-------|
| `main.dart` | Entry point (MODIFY for blank shell) |
| `rust_engine.dart` | Dart facade over FRB |
| `canonical_seed.dart` | Test fixture data |

### lib/debug/ — 1 file

| File | Notes |
|------|-------|
| `demo_seeder.dart` | Debug seeder (feeds engine) |

---

## AMBIGUOUS — BART'S CALL NEEDED

### 1. `readiness_screen.dart` — mixed UI + plumbing

Contains:
- `HomeData` class (lines 120-170) — engine output snapshot model
- `_humanizeFatigueState()` — label transform helper
- `insufficientDataFromConfidence()` — engine gate helper
- `_fallbackProfile()` — fallback profile JSON
- Heavy engine wiring in `_fetch()` methods
- All the UI widgets and layout

**Options**:
- **A) Delete entirely** — `HomeData` and helpers can be recreated when rebuilding, or extracted now to `models/home_data.dart`
- **B) Extract plumbing, delete UI** — pull `HomeData`, helpers, `_fallbackProfile` into separate files first

**Recommendation**: Option A (delete entirely). The new UI will define its own data shapes.

### 2. `onboarding_screen.dart` — mixed UI + plumbing

Contains:
- `OnboardingResult` class (lines 16-24) — result type for onboarding flow
- All the wizard UI pages and form state

**Impact**: `main.dart` imports `OnboardingResult` for the onboarding navigation flow.

**Options**:
- **A) Delete entirely** — but then main.dart onboarding flow breaks
- **B) Extract `OnboardingResult` to `models/onboarding_result.dart`** — delete UI, keep the type
- **C) Keep onboarding_screen.dart** — it's needed for first-launch; strip in rebuild phase

**Recommendation**: Option B or C. First-launch still needs onboarding. Bart's call.

### 3. `main.dart` — entry point needs modification

Current flow: `_AppEntryPoint` → checks profile → onboarding OR `AppShell`

**Blank shell options**:
- **A) Minimal Scaffold** — "MiValta" text centered, no navigation
- **B) Empty Container** — just `MaterialApp(home: Container())`
- **C) Preserve onboarding flow** — but replace `AppShell` with blank shell

**Recommendation**: Option A — a visible "blank shell" proves boot succeeded.

---

## TESTS TO DELETE (UI tests follow their subjects)

| Test file | Reason |
|-----------|--------|
| `advisor_chips_test.dart` | Tests deleted UI |
| `advisor_options_test.dart` | Tests deleted UI |
| `app_shell_test.dart` | Tests deleted UI |
| `debug_exerciser_gate_test.dart` | Tests deleted UI |
| `debug_swatch_exerciser_test.dart` | Tests deleted UI |
| `josi_presenter_test.dart` | Tests deleted UI |
| `journey_screen_test.dart` | Tests deleted UI |
| `onboarding_privacy_test.dart` | Tests deleted UI (depends on ambiguous) |
| `pause_learning_toggle_test.dart` | Tests deleted UI |
| `readiness_detail_screen_test.dart` | Tests deleted UI |
| `readiness_screen_test.dart` | Tests deleted UI |
| `sensor_check_ble_test.dart` | Tests deleted UI |
| `sensor_check_screen_test.dart` | Tests deleted UI |
| `today_facts_test.dart` | Tests deleted UI |
| `weather_test.dart` | Tests deleted UI |
| `widget_test.dart` | Generic widget test |
| `workout_detail_page_test.dart` | Tests deleted UI |

**Total test deletions: ~17 files**

## TESTS TO KEEP (model/service tests)

| Test file | Reason |
|-----------|--------|
| `activity_summary_test.dart` | Tests kept model |
| `biometric_series_test.dart` | Tests kept model |
| `ble_hr_measurement_test.dart` | Tests kept service |
| `ble_hr_service_test.dart` | Tests kept service |
| `canonical_seed_test.dart` | Tests kept fixture |
| `critical_power_test.dart` | Tests kept model |
| `decoupling_trend_test.dart` | Tests kept model |
| `demo_seeder_test.dart` | Tests kept debug plumbing |
| `fitness_trend_test.dart` | Tests kept model |
| `ingest_adapter_test.dart` | Tests kept service |
| `journey_tiles_prefs_test.dart` | Tests kept service |
| `learning_status_test.dart` | Tests kept model |
| `load_context_test.dart` | Tests kept model |
| `power_curve_test.dart` | Tests kept model |
| `profile_service_test.dart` | Tests kept service |
| `realized_line_test.dart` | Tests kept model |
| `rust_engine_binding_test.dart` | Tests kept plumbing |
| `sleep_trend_test.dart` | Tests kept model |
| `source_tier_test.dart` | Tests kept theme |
| `time_in_zone_test.dart` | Tests kept model |
| `tokens_test.dart` | Tests kept theme |
| `training_load_test.dart` | Tests kept model |
| `unit_prefs_test.dart` | Tests kept service |
| `workout_detail_test.dart` | Tests kept model |
| `workout_ingest_test.dart` | Tests kept service |
| `workout_option_test.dart` | Tests kept model |
| `workout_report_test.dart` | Tests kept model |
| `zone_labels_test.dart` | Tests kept copy |

---

## END STATE

After strip:
- App boots to **blank shell** (minimal Scaffold with "MiValta" text)
- All **engine wiring** intact (RustEngineBinding, FRB bridge, services)
- All **data models** intact (parse models for engine output)
- All **design tokens** intact (MivaltaColors, MivaltaTypography, etc.)
- All **locked copy** intact (F1, zone labels, etc.)
- **~32 UI files deleted**, **~17 UI tests deleted**
- **~42 plumbing files kept**, **~28 plumbing tests kept**
- `flutter test` passes on remaining tests
- `flutter run` boots to blank shell on device/simulator

---

## AWAITING BART'S APPROVAL

**Questions for Bart**:

1. **Onboarding**: Delete entirely, extract `OnboardingResult` first, or keep for now?

2. **`HomeData` in readiness_screen.dart**: Delete entirely (recreate later) or extract first?

3. **Blank shell look**: Minimal Scaffold with "MiValta" text, or just empty Container?

4. **Confirm the line**: Anything in the KEEP list that should actually go? Anything in DELETE that should stay?

---

**HOLDING — no deletions until Bart approves this plan.**

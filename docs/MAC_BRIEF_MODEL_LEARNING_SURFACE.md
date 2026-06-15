# Mac brief — wire up the model-learning surface (FRB regen + build + verify)

This branch adds two new FFI shim functions, so the **FRB bindings must be
regenerated** before the app compiles. Until you run codegen, `flutter analyze`
will fail on `rust_api.validationReport` / `rust_api.personalizationDiagnostics`
— that is expected (same pattern as `recommend_workout_with_history`).

## What landed (cloud session, authored — do not redesign)

- `rust/src/api.rs`: `validation_report()` + `personalization_diagnostics()`
  pass-throughs (one `gatc_ffi::*` call each).
- `lib/rust_engine.dart`: facade `validationReport()` + `personalizationDiagnostics()`.
- `lib/models/learning_status.dart`: parse model (pure, tested).
- `lib/widgets/learning_status_card.dart`: "How MiValta is learning you" card.
- `lib/screens/readiness_detail_screen.dart`: loads both reads + renders the card.
- `test/learning_status_test.dart`: parse-model concrete-value tests.

## Steps

```bash
git pull origin claude/coach-phase3plus-session-itfxxs

# 1. Regenerate FRB bindings (picks up the 2 new shim fns).
#    Use the project's pinned flutter_rust_bridge_codegen (2.12.0).
flutter_rust_bridge_codegen generate

# 2. Build the Rust .so (needs the engine pin + cargo-ndk / xcframework as usual).
#    (Same recipe as README "Quick start".)

# 3. Verify.
flutter pub get
flutter analyze --fatal-infos     # CI gate — must be clean
flutter test                      # all tests, incl. learning_status_test.dart

# 4. Show it: open the readiness DETAIL screen (tap the hero), scroll to
#    "How MiValta is learning you". On a fresh install it should say it hasn't
#    started learning; after seeding a season it should report the day count +
#    confidence bucket and the validation line.
```

## Also pending Mac verification on this branch (from earlier this session)

- **Readiness-as-light hero** (`ReadinessLightField` replaced `ReadinessRing`):
  build + show on the simulator; confirm the home fills after a seed (the
  no-data gate now keys off the engine's persisted confidence).
- Commit the regenerated `lib/src/rust/*` so CI goes green.

## Report back

`flutter analyze` + `flutter test` output, and a screenshot of the detail
screen's learning section (seeded + fresh).

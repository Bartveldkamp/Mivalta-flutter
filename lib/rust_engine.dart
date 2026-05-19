// Day-3 facade. Wraps the auto-generated flutter_rust_bridge surface
// in lib/src/rust/ so the rest of the app only sees idiomatic Dart —
// no FRB types in signatures here, and the only FRB type that leaks
// is `EnginesHandle` (opaque to Dart by design; the Dart side just
// holds it and hands it back).
//
// Bridge errors flow through unchanged: every method here re-throws
// the `BridgeError` sealed class from `lib/src/rust/api.dart`, which
// is itself a freezed sealed class with one Dart subclass per
// upstream variant (LibraryNotLoaded / EngineConstructionFailed /
// VaultError / InputError / StateError / RoundTripFailed). Callers
// catch `BridgeError` and switch on variant.

import 'dart:io' show Platform;

import 'src/rust/api.dart' as rust_api;
import 'src/rust/api.dart' show BridgeError, EnginesHandle;
import 'src/rust/frb_generated.dart';

export 'src/rust/api.dart' show BridgeError, EnginesHandle;

/// Thin Dart facade over the rust-engine bridge.
class RustEngineBinding {
  RustEngineBinding._();

  /// Initialise the FRB runtime and return a ready-to-use binding.
  /// Day-2 review WARNING 3: gated on Platform.isAndroid — host runs
  /// throw a clear error instead of segfaulting on a missing
  /// `libmivalta_rust_bridge.so`.
  static Future<RustEngineBinding> bootstrap() async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('Mivalta-flutter spike is Android-only');
    }
    await RustLib.init();
    return RustEngineBinding._();
  }

  /// Day-2 smoke test — `gatc_ffi::hello_uniffi()`.
  Future<String> hello() => rust_api.engineHello();

  /// Construct the bundled Viterbi / Advisor / Vault engines from the
  /// canonical seed and the compiled knowledge tables. [vaultPath] must
  /// be a writable directory on the device — typically
  /// `getApplicationSupportDirectory()/day3-vault`. Throws
  /// [BridgeError] on failure.
  Future<EnginesHandle> constructEngines({
    required String athleteProfileJson,
    required String tablesJson,
    required String vaultPath,
  }) {
    return rust_api.constructEngines(
      athleteProfileJson: athleteProfileJson,
      tablesJson: tablesJson,
      vaultPath: vaultPath,
    );
  }

  /// `ViterbiEngine::readiness_score()` — returns raw JSON
  /// `{"score": int, "advisories": {...}}`.
  Future<String> readinessScore(EnginesHandle handle) =>
      rust_api.readinessScore(handle: handle);

  /// `ViterbiEngine::get_readiness()` — full snapshot JSON, contains
  /// `fatigue_state` alongside the rest of the readiness state.
  Future<String> viterbiFatigueState(EnginesHandle handle) =>
      rust_api.viterbiFatigueState(handle: handle);

  /// `ViterbiEngine::zone_cap_with_advisories()` — raw JSON
  /// `{"zone": "Z8|Z5|Z2|REST", "advisories": {...}}`.
  Future<String> zoneCapWithAdvisories(EnginesHandle handle) =>
      rust_api.zoneCapWithAdvisories(handle: handle);

  /// `AdvisorEngine::suggest_workouts(...)` — shim composes the
  /// `SuggesterContext` from live engine state + profile fields, with
  /// documented defaults for mood / equipment / terrain / phase /
  /// meso_day (no user-input form yet). Raw JSON array of options.
  Future<String> recommendWorkout(EnginesHandle handle) =>
      rust_api.recommendWorkout(handle: handle);

  /// `VaultEngine::read_default_profile()` — round-trips the profile
  /// through the on-device encrypted vault.
  Future<String> vaultSnapshot(EnginesHandle handle) =>
      rust_api.vaultSnapshot(handle: handle);
}

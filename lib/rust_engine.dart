// Day-2 spike facade. Wraps the auto-generated flutter_rust_bridge
// surface in lib/src/rust/ so the rest of the app only sees idiomatic
// Dart — no FRB types, no native pointers, no init order leaking
// outward.

import 'src/rust/api.dart' as rust_api;
import 'src/rust/frb_generated.dart';

/// Thin Dart facade over the rust-engine bridge.
///
/// Construction is async because the flutter_rust_bridge runtime must
/// load `libmivalta_rust_bridge.so` (and its statically-linked
/// gatc-ffi code) before any call returns. Call [bootstrap] once at
/// app start; the same instance can be reused for the lifetime of the
/// process.
class RustEngineBinding {
  RustEngineBinding._();

  /// Initialise the FRB runtime and return a ready-to-use binding.
  /// Safe to call more than once — the underlying `RustLib.init` is
  /// idempotent within a single isolate.
  static Future<RustEngineBinding> bootstrap() async {
    await RustLib.init();
    return RustEngineBinding._();
  }

  /// Returns the engine's canonical UniFFI smoke-test value
  /// (`gatc_ffi::hello_uniffi()`).
  Future<String> hello() => rust_api.engineHello();
}

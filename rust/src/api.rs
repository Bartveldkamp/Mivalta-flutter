//! Day-2 spike API surface — exactly one function, by design.

/// Returns the string the engine produces for its canonical
/// UniFFI smoke-test, `gatc_ffi::hello_uniffi()`. Today this is the
/// literal `"hello"`. Used by the Day-2 Flutter spike to prove the
/// `flutter_rust_bridge` → shim → gatc-ffi call chain is live.
pub fn engine_hello() -> String {
    gatc_ffi::hello_uniffi()
}

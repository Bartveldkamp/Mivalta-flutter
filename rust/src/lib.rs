//! Day-2 spike shim. Bridges `flutter_rust_bridge`'s expected
//! plain-Rust ABI to gatc-ffi's UniFFI proc-macro exports.
//!
//! Only one entry today: `engine_hello`, which forwards to
//! `gatc_ffi::hello_uniffi`. Day 3+ will replace this with the
//! readiness path (PendingAdvisories), but the shim layer stays —
//! it's the seam where the Flutter app sees idiomatic Rust types
//! without touching UniFFI's wire format directly.

mod api;
mod frb_generated;

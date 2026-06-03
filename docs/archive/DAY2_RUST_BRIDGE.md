# Day 2 binding tool spike

> **Verdict (read-only investigation; nothing built yet):**
> use `flutter_rust_bridge` v2.x with a thin shim crate in this repo.
> Plan B (`uniffi-bindgen-dart`) is rejected today but is the right
> long-term option once two upstream blockers clear.

## What the two candidates claim

### flutter_rust_bridge (`fzyzcjy/flutter_rust_bridge`, pub.dev)

- Latest: **2.12.0**, published 2026-03-29; commit on default branch
  **2026-05-17** (≈48 h before this spike).
- 133 contributors; Flutter Favorite badge; active CI on master.
- README quickstart is a one-liner: `cargo install
  flutter_rust_bridge_codegen && flutter_rust_bridge_codegen create
  my_app`. Generates Dart bindings from Rust source; the Rust side
  cross-compiles to `lib*.so` and links into the app.
- v2 highlights call out **"Parsing third-party packages: scan and
  use existing Rust packages in Dart (experimental)"** — directly
  relevant to this repo's read-only-rust-engine constraint.

### uniffi-bindgen-dart (`Uniffi-Dart/uniffi-dart`)

- The most active fork is `Uniffi-Dart/uniffi-dart` (38⭐, last
  update 2026-05-13). The original `NiallBunting/uniffi-bindgen-dart`
  is gone (404). `nchapman/uniffi-bindgen-dart` exists but is a
  3⭐ personal fork, last touched 2026-04-24.
- Cargo manifest pins **`uniffi-rs v0.30.0`** as the target binding
  surface; gatc-ffi pins **`uniffi 0.28.3`** (see
  `/root/mivalta-rust-engine/crates/gatc-ffi/Cargo.toml`). Major
  internal-protocol skew across that gap.
- README badge: **"status: experimental"** (red). The README itself
  flags five critical blockers, including:
  > **Proc-macro support — Modern UniFFI development pattern**
- Not published on pub.dev as a Dart package; consumed only as a
  Rust crate that generates Dart source via `cargo run`.

## How that maps to our gatc-ffi reality

Every FFI entry in `crates/gatc-ffi/src/lib.rs` uses **proc-macro
UniFFI** (`#[uniffi::export]`, e.g. `hello_uniffi()` at line 2995, plus
the 19 other `#[uniffi::export]` items grep'd at the same time). The
crate has no `.udl` file in the same directory. `uniffi-dart`'s own
README marks proc-macro UniFFI as a critical blocker — i.e. it cannot
generate Dart bindings for gatc-ffi as it stands today.

Layered on top: the uniffi-rs version skew (0.30 vs 0.28) would
require either bumping rust-engine (forbidden — read-only) or pinning
uniffi-dart older (then losing the version where proc-macro work is
actually progressing).

## Chosen tool: `flutter_rust_bridge`

Rationale, ranked by Day-2 risk reduction:

1. **It actually works against this codebase.** uniffi-dart hits a
   hard upstream blocker; FRB doesn't.
2. **Permitted shim path.** Brief allows "a thin Rust shim ONLY IF
   unavoidable." We add `rust/` in this repo with a single pub fn
   that delegates to `gatc_ffi::hello_uniffi()`. No edits to
   rust-engine.
3. **Mature + active.** Pre-1.0 churn is past; commits land daily.
4. **Android arm64-v8a is documented.** FRB's codegen `create`
   command sets up `cargokit`-based cross-compile; pinning the ABI
   to `arm64-v8a` aligns with Day-1's gradle config.

## Plan B kept in the drawer: `uniffi-bindgen-dart` (Uniffi-Dart fork)

Two upstream things need to land before we revisit:

1. **Proc-macro UniFFI support** (called out as a critical blocker in
   uniffi-dart's own README).
2. **uniffi-rs version alignment** with `gatc-ffi`'s `0.28.3` pin —
   either uniffi-dart back-ports, or rust-engine bumps to ≥0.30.

When both clear, Plan B becomes the better long-term option: it
reuses gatc-ffi's existing UniFFI surface (matching the
Kotlin/Swift path already documented in rust-engine
`scripts/build_flutter.sh`) instead of forcing a Mivalta-flutter-side
shim.

# Mivalta-flutter

Forward-direction Flutter frontend for MiValta. Replaces the
`mivalta-android-client` Kotlin app. See `CLAUDE.md` for the
architecture rules.

## Quick start (Hetzner / founder laptop)

Prerequisites:
- Flutter 3.44.0 stable (Dart 3.12).
- Rust toolchain (1.95+) with the `aarch64-linux-android` target.
- `cargo-ndk` (`cargo install cargo-ndk`).
- Android NDK 28 (e.g. `/opt/android-sdk/ndk/28.2.13676358`).
- SSH access to `Bartveldkamp/mivalta-rust-engine` (private repo —
  the Day-5 git-rev pin in `rust/Cargo.toml` clones over SSH).

```bash
git clone git@github.com:Bartveldkamp/Mivalta-flutter.git
cd Mivalta-flutter
flutter pub get

# Build the rust shim's .so for arm64-v8a (resolves the gatc-ffi
# git-rev pin in rust/Cargo.toml).
cd rust
export ANDROID_NDK_HOME=/opt/android-sdk/ndk/28.2.13676358
cargo ndk --target arm64-v8a --platform 21 \
  --output-dir ../android/app/src/main/jniLibs -- build --release
cd ..

# Day-5: drop the side-effect libgatc_ffi-<hash>.so left behind by
# Cargo's git-dep layout. Only libmivalta_rust_bridge.so is loaded
# at runtime; gatc-ffi is statically linked into it via rlib.
rm -f android/app/src/main/jniLibs/arm64-v8a/libgatc_ffi*.so

# Build the debug APK.
flutter build apk --debug --target-platform android-arm64
```

## Local-dev override for `rust/Cargo.toml`'s gatc-ffi pin

`rust/Cargo.toml` pins `gatc-ffi` to a specific
`mivalta-rust-engine` revision over SSH. When hacking on the engine
locally you typically want Cargo to read from your sibling working
tree on disk instead. Drop this at the repo root in
`.cargo/config.local.toml` and `cp .cargo/config.local.toml .cargo/config.toml`
(it's git-ignored locally; do NOT commit machine-specific paths):

```toml
[patch."ssh://git@github.com/Bartveldkamp/mivalta-rust-engine"]
gatc-ffi = { path = "/absolute/path/to/mivalta-rust-engine/crates/gatc-ffi" }
```

This survives `cargo update` because `[patch]` overrides live
outside the lockfile. Remove the file (or comment out the
`[patch]` block) to fall back to the pinned revision.

A workspace-level `.cargo/config.toml` is committed at the repo root
setting `net.git-fetch-with-cli = true` — Cargo's libgit2 backend
can't read the credential helper / SSH agent reliably; using the
system `git` binary lets local dev and CI share one transport.

## CI

`.github/workflows/smoke-build.yml` runs on PRs and `main` pushes.
It needs an SSH read-only deploy key on `mivalta-rust-engine` paired
with a `RUST_ENGINE_DEPLOY_KEY` secret on this repo so Cargo can
fetch the pinned git rev. If the secret is unset the workflow no-ops
with a notice (same skip-on-missing-key pattern as
`claude-review.yml`).

Steps performed:
1. `flutter pub get`
2. `cargo ndk … check` (verifies the git-rev pin resolves)
3. `flutter analyze`
4. `flutter test`
5. `cargo ndk … build` and `flutter build apk --debug --target-platform android-arm64`
6. `unzip -l` asserts `libmivalta_rust_bridge.so` + the V10.1 native
   stack (`libllama.so` + `libggml*.so` + `libmtmd.so`) and
   `assets/flutter_assets/assets/compiled_tables.json` are packed.

## Day log

| Day | PR | Summary |
|---|---|---|
| 1 | #1 | Bootstrap + V10.1 LLM consumption path |
| 2 | #2 | rust-engine binding via `flutter_rust_bridge` |
| 3 | #5 | Real-data round-trip — profile + rust-engine + V10.1 |
| 4 | (pending) | F1 readiness UI + SourceTier tokens |
| 5 | (this) | Real SourceTier swatch + git-rev pin + smoke-build CI |

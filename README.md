# Mivalta-flutter

Production Flutter frontend for MiValta. Replaces the
`mivalta-android-client` Kotlin app. See `CLAUDE.md` for the
architecture rules.

## Current milestone

**MVP-1** — see `docs/MVP1_BUILD_BRIEF.md` for the full scope.

- Engine DECIDES, Flutter DISPLAYS. No thresholds/math/fallback in Dart.
- Default home: `ReadinessScreen` (three-zone PULL layout, dark-first).
- Headline: `readiness_indicator()` — the 4-axis readiness blend.
- Continuity: persisted ViterbiEngine state survives app restarts.
- LLM layer: fully deferred to the grounded-Josi phase (PR-F). The V10.1
  spike was purged (PR-J); the shipped build contains no native LLM stack.
- No cloud round-trips; on-device only.

### Engine pin

`rust/Cargo.toml` pins `gatc-ffi` and `gatc-viterbi` to revision `b603b5e`
(rust-engine `main`, engine_registry v2.24). The `rev = "..."` line in
`rust/Cargo.toml` is the source of truth; see `CLAUDE.md` for what the pin
provides.

## Quick start (Hetzner / founder laptop)

Prerequisites:
- Flutter 3.44.0 stable (Dart 3.12).
- Rust toolchain (1.95+) with the `aarch64-linux-android` target.
- `cargo-ndk` (`cargo install cargo-ndk`).
- Android NDK 28 (e.g. `/opt/android-sdk/ndk/28.2.13676358`).
- SSH access to `Bartveldkamp/mivalta-rust-engine` (private repo —
  the git-rev pin in `rust/Cargo.toml` clones over SSH).

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

# Drop the side-effect libgatc_ffi-<hash>.so left behind by
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
6. `unzip -l` asserts `libmivalta_rust_bridge.so` and
   `assets/flutter_assets/assets/compiled_tables.json` are packed.
   (Historical note: the workflow file still also asserts the V10.1-era
   native LLM stack — `libllama.so` + `libggml*.so` + `libmtmd.so` —
   which was purged in PR-J and is no longer part of the shipped build;
   those stale assertions in `smoke-build.yml` are pending removal.)

## MVP-1 build sequence

| PR | Scope |
|---|---|
| **PR-A** | Re-pin shim, regenerate FRB, bind no-LLM surface, wire continuity |
| **PR-B** | Theme + three-zone home |
| **PR-C** | Readiness detail (4 axes, trend, source tier, altitude/travel) |
| **PR-D** | Advisor surface + SuggesterContext picker |
| **PR-E** | Connectivity: BLE + Garmin + Polar transport |
| **PR-F** | Grounded Josi + on-device LLM messenger (later step) |

# Mivalta-flutter

Production Flutter frontend for MiValta — a privacy-first, **on-device** AI
fitness coach. The Rust engine DECIDES; Flutter DISPLAYS. Replaces the
`mivalta-android-client` Kotlin app.

## 👋 New here? Start with the right door

| You are a… | Start here |
|---|---|
| **Frontend developer** | [`docs/READING_ORDER.md`](docs/READING_ORDER.md) — ordered onboarding: MVP scope, repo tour, the Dart↔Rust path, what's wired vs not, build/test, known gaps |
| **Designer** | `docs/UI_UX_DIRECTION.md` in [mivalta-rust-engine](https://github.com/Bartveldkamp/mivalta-rust-engine) — the design language + locked tokens |
| **Anyone (1-page picture)** | [What MiValta is](#what-mivalta-is) (below) — what MiValta is, the model, and the repos |
| **Working in the code** | `CLAUDE.md` — the architecture rules + the engine pin |

## What MiValta is

> *Folded in 2026-06-20 from the former `docs/MIVALTA_OVERVIEW.md` (archived). A
> single-page picture of what MiValta is, how it's built, and what exists today.*

**A privacy-first AI fitness coach that runs entirely on the device.** It ingests
a user's biometrics (heart rate, HRV, sleep, etc.) and tells them how recovered
they are and what to train today — with no cloud, no account required, and no data
leaving the phone.

**The core principle:** *the engine DECIDES, the app DISPLAYS, and (later) the LLM
EXPLAINS.* All coaching logic lives in a deterministic on-device engine. The AI
layer never makes decisions — it only puts the engine's output into words. This is
what makes the coaching trustworthy and the privacy real.

**The promise, literally:** 100% on-device, 100% user data ownership, no
harvesting. Data is encrypted at rest (SQLCipher), and "delete" means the
encryption key is destroyed — the data becomes unrecoverable noise.

### The tiers

Three product tiers — **Monitor / Advisory / Coach**. See [`docs/TIERS.md`](docs/TIERS.md)
for the canonical definition. (These are *product/pricing* tiers, named — not to be
confused with the engine's "Tier 1/2/3" architecture axis in the rust-engine's
`W1_SPEC.md`, which is Viterbi / GATC / Josi.)

| Tier | Price | What the user gets | Josi (LLM) | Engine |
|------|-------|--------------------|-----------|--------|
| **Monitor** | **Free** | Biometric numbers, stats, readiness/state — display only. No account, no network. | ❌ | ViterbiEngine |
| **Advisory** | **Paid** | Monitor + Josi (explains, interactive) + a single-day training idea | ✅ | + AdvisorEngine + Josi |
| **Coach** | **Paid (higher)** | Advisory + full long-term periodized plan, adjusts on request | ✅ | + PlanEngine + ReplanEngine + Josi |

Josi (the on-device LLM) switches on at **Advisory** and stays through **Coach**;
the free **Monitor** has no LLM at all. Build status: the *engine* behind all three
tiers exists today; **Josi (model W) is in development** and is what gates the paid
tiers, and the **entitlement gating itself is future work** (today's build shows
all surfaces open).

### Architecture at a glance

```
   ┌─────────────────────────┐     FFI (typed JSON, pure pass-through)
   │   mivalta-rust-engine   │ ◄──────────────────────────────────────┐
   │   (core IP — Rust)      │                                         │
   │                         │   • Viterbi monitor (readiness/fatigue) │
   │   • 16 engines          │   • Advisor (A/B/C workouts)            │
   │   • SQLCipher vault     │   • SQLCipher-encrypted on-device vault │
   │   • Health normalizers  │                                         │
   └─────────────────────────┘                                         │
                                                                       │
   ┌─────────────────────────┐                                         │
   │     Mivalta-flutter     │ ── flutter_rust_bridge ─────────────────┘
   │   (the app — Dart)      │
   │                         │   • Android + iOS, one codebase
   │   • Display only        │   • Health Connect / Apple Health ingest
   │   • No business logic   │   • Onboarding, Settings, data control
   └─────────────────────────┘
```

- **The engine is the IP.** It does all readiness, classification, statistics, and
  rule resolution. Deterministic, on-device, ~no external dependencies at runtime.
- **The app is display + transport.** Flutter maps engine output to UI; it contains
  zero coaching logic. The FFI layer serialises typed data only.
- **One client, two platforms.** Flutter targets Android and iOS from a single
  codebase. (A legacy native-Android app exists but is being *replaced* by Flutter.)

### What's built today (honest status)

✅ **Functionally complete and connected:**
- The **Monitor** and **Advisory** *engine* (readiness/state + A/B/C workout
  suggestions), running on real biometrics.
- Android end-to-end: Health Connect + Apple Health + manual ingest → engine →
  readiness/advice.
- On-device **SQLCipher** encryption; data export (encrypted backup + CSV) and
  **crypto-erase** delete.
- First-launch onboarding capturing real anchors (honest "I don't know" → no
  fabricated values).
- iOS data layer + native bridge **foundation** (xcframework, HealthKit mapping,
  encryption proven).
- **Zero network** — the app holds no INTERNET permission.

🔲 **Not yet done (the next phase):**
- **Josi (the LLM, model W)** — in development on a separate model-training track;
  it's what unlocks the paid **Advisory** and **Coach** tiers.
- **Tier gating / accounts / website upgrade** — the paywall mechanics; today's
  build shows all surfaces open.
- **Visual design pass** — the app currently renders through a neutral
  design-token layer (functional, not yet the final look); the architecture is set
  up so the real design is largely a token-layer swap.
- **iOS built end-to-end** — foundation is in; needs a real `flutter build ios` on
  a Mac with simulator runtime + signing.
- **Release/store steps** — keystore, Play Console, store listing, privacy policy
  (drafts in `docs/RELEASE_CHECKLIST.md`).

⚠️ **Honest caveat for technical reviewers:** the engine's coaching *constants*
(thresholds, recovery curves) are **DRAFT** — grounded in sport-science literature
(Meeusen, Banister, Seiler, Foster, Lolli…) and reviewed, but **not yet validated
against real-athlete data**. The architecture is sound; field validation is
outstanding work.

### The non-negotiables (preserve in any work)

1. **Computation stays in Rust.** No coaching logic, thresholds, or math in Dart —
   the app is display only.
2. **On-device only.** No cloud round-trips for user data. The app holds no
   INTERNET permission today; when the paid tiers ship, the Josi model (W) is
   delivered via Play Asset Delivery (download-only — nothing about the user is
   uploaded).
3. **No fabrication.** If a value is unknown, the app says so — it never invents
   numbers (e.g. an unknown FTP is stored as null, not guessed).
4. **Encryption + erasure are load-bearing.** SQLCipher vault; delete = destroy
   the key. This is the product's core promise, not a feature.

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

`rust/Cargo.toml` pins `gatc-ffi` and `gatc-viterbi` to revision `79b7c93`
(rust-engine `main`, engine_registry v2.24). The `rev = "..."` line in
`rust/Cargo.toml` is the source of truth; see `CLAUDE.md` → "Engine pin" for what
the pin provides and the pending Mac-gated bump to current `main` (`73e17b1`).

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

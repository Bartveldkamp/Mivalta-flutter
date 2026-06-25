# Sealed brief — iOS bring-up (Mivalta-flutter)

**For:** Mac Claude Code on Bart's Mac (Alta) — the Rule 1 executor — or Bart directly.
**Drafted:** 2026-06-08 by the remote/web session.
**Why this is a Mac job (and the part the remote session cannot do):** the iOS
SDK + Xcode toolchain are **macOS-only**. The Rust→iOS cross-compile and the
Flutter iOS build/run cannot happen on Linux or the ubuntu CI. This is the one
piece that physically requires a Mac.

---

## Where iOS stands (verified 2026-06-08) — plumbing DONE, only the build/run is missing
The integration is real and current; do **not** rebuild it from scratch:
- `scripts/build_ios_xcframework.sh` — builds the Rust shim for device
  (`aarch64-apple-ios`) + simulator (`aarch64-apple-ios-sim`, `x86_64-apple-ios`),
  `lipo`s the simulator slices, and creates
  `ios/Frameworks/MivaltaRustBridge/MivaltaRustBridge.xcframework` via
  `xcodebuild -create-xcframework`. Sets `SDKROOT` per target.
- `ios/Frameworks/MivaltaRustBridge/MivaltaRustBridge.podspec` — vendored
  xcframework, links `Security` + `CoreFoundation` (SQLCipher's CommonCrypto
  backend), `c++`, `static_framework = true`, iOS 13 min, excludes `i386`.
- `ios/Podfile` — links it (`pod 'MivaltaRustBridge'`, `use_frameworks!`).
- `rust/Cargo.toml` pins engine `gatc-ffi` / `gatc-viterbi` @ **`47af641`** (current,
  post-#54 — carries the MONITOR/ADVISOR audit fixes).

**Missing = only the built `.xcframework` artifact (Mac-produced) + first run/verify.**

## Objective
Produce the iOS xcframework against engine `47af641`, run the app on the **iOS
Simulator first** (no signing), then a **device**, and confirm the
**MONITOR + ADVISORY** surfaces work end-to-end (engine FFI live on iOS).

## Prerequisites (Mac)
- **Xcode** (App Store) with the iOS platform + Simulator installed;
  `sudo xcode-select -s /Applications/Xcode.app` (NOT CommandLineTools).
- **Rust targets:** `rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios`.
- **Flutter** (matching `pubspec.yaml`, `flutter_rust_bridge` 2.12.0) + **CocoaPods**.
- **Network/SSH** to fetch the engine git-rev `47af641` (`rust/Cargo.toml` pins via
  ssh to `rust-engine`; needs the deploy key / your SSH agent). The
  `.cargo/config.toml` already sets `git-fetch-with-cli = true`.

## Steps
```bash
flutter pub get

# 1) Build the Rust → iOS xcframework against engine 47af641.
#    First run fetches the engine rev + compiles SQLCipher for iOS — slow.
./scripts/build_ios_xcframework.sh

# 2) Pods
cd ios && pod install && cd ..

# 3) SIMULATOR FIRST (no signing required) — the cleanest first proof.
flutter run -d "<simulator-id>"        # e.g. an iPhone 15 simulator
#   or compile-only:  flutter build ios --simulator

# 4) DEVICE (after simulator works): set a Development Team in
#    Runner ▸ Signing & Capabilities, then:
flutter run -d "<device-id>"
#   build-only without signing to isolate compile vs sign:
#   flutter build ios --no-codesign
```

## Likely failure points (and the fix)
1. **SQLCipher / `libsqlite3-sys` cross-compile.** The bundled C build needs the
   deployment target. If `cc` errors on an iOS target, export
   `IPHONEOS_DEPLOYMENT_TARGET=13.0` before running the script (matches the
   podspec's `:ios, '13.0'`). `SDKROOT` is already set per target by the script.
2. **FRB external-library loading on iOS.** `flutter_rust_bridge` loads the Rust
   lib **differently on iOS** — statically linked via the framework, not `dlopen`.
   If the app launches but **every engine call throws "symbol not found" / "lib
   not loaded"**, this is it: confirm `lib/src/rust/frb_generated.dart`'s
   `RustLib.init()` / the iOS `external_library` config resolves the
   `MivaltaRustBridge` framework (name must match the podspec). This is the most
   likely real bring-up bug — it's the load-bearing FFI boundary.
3. **Signing (device only).** Simulator needs none. Device needs a Development
   Team + provisioning. Use `flutter build ios --no-codesign` to confirm the
   build compiles before fighting signing.
4. **sqlite3 symbol shadowing.** The podspec deliberately links `c++` and does
   NOT link system `sqlite3`, to protect SQLCipher's `PRAGMA key`. If the vault
   won't open / `PRAGMA key` fails at runtime, verify nothing added
   `s.libraries = 'sqlite3'`.
5. **Bitcode.** None needed (Xcode 14+ removed it); don't re-enable.

## Verify (the actual goal)
On the **Simulator**:
- App launches to **ReadinessScreen**; the readiness ring renders from
  `readiness_indicator()` → **engine FFI is alive on iOS**.
- Explore / Monitor surfaces load (fitness-trend, time-in-zone, etc.).
- "See workout options" returns A/B/C from `recommend_workout`.
If those render with **real engine output (not errors/null)**, iOS FFI bring-up
is proven. (The new safety behavior is also testable here: a profile with real
`availability` → non-60 durations; a `fail`-decoupling state → no Z4+ options.)

## Report back (PR / comment on Mivalta-flutter)
1. Did the xcframework build? Any `cargo`/`cc` errors hit + the fix.
2. Simulator run result + a screenshot of ReadinessScreen.
3. Device run result, or the signing blocker if no team is set up.
4. Any FRB-iOS loader config change needed (commit it — it's the boundary).
5. Verdict: does the MONITOR + ADVISORY path work on iOS, yes/no?

## 2026-06-12 addendum — Apple Developer account exists (founder confirmed)

The paid account removes the last administrative blockers. Three things it
unlocks, in execution order:

1. **Device signing (step 4 above).** Xcode ▸ Runner ▸ Signing & Capabilities ▸
   select the MiValta Team. Year-long provisioning instead of 7-day free-account
   profiles. Simulator still needs none — do simulator first regardless.
2. **HealthKit — capability + privacy strings (VERIFIED MISSING).**
   `lib/services/health_ingest.dart` + the engine's `healthkit.rs` normalizer
   are already written, but `ios/Runner/Info.plist` has **no**
   `NSHealthShareUsageDescription` and the Runner has no HealthKit capability —
   iOS will hard-deny health reads without them. Add:
   - Xcode ▸ Runner ▸ Signing & Capabilities ▸ **+ HealthKit** (read-only;
     no Clinical Health Records).
   - Info.plist: `NSHealthShareUsageDescription` — honest copy, e.g. "MiValta
     reads your resting heart rate, HRV, sleep and workouts on-device to
     estimate recovery. Nothing leaves your phone."
   (We only READ; `NSHealthUpdateUsageDescription` not needed.)
3. **TestFlight — the real n=1 beta channel** (after the device run proves FFI):
   - App Store Connect ▸ register the app record with the Runner's bundle id.
   - `flutter build ipa` ▸ upload (Xcode Organizer or `xcrun altool`/Transporter).
   - Internal Testing group with Bart's Apple ID → the beta installs from the
     TestFlight app, 90-day builds, updates push over the air — no cable, no
     re-provisioning. This is how the founder carries the beta day-to-day.
   - Later: add Apadmi to the App Store Connect team (Developer role) for
     production CI uploads.

**What the account does NOT change:** the xcframework build, the FRB-iOS
loader risk (#2 above), and the simulator-first sequence. Toolchain before
paperwork.

## Out of scope / guardrails
- Do **not** change the engine, the shim's Dart-facing API, or the locked design
  tokens to "make it build."
- If the FRB-iOS loader needs a config change, make the **minimal** change and
  **surface it in the PR** — it's the load-bearing FFI boundary, not a free edit.
- Do **not** disable SQLCipher / vault encryption to get it running.

---
*Sealed brief. Execute within scope; surface anything that requires going
outside it rather than improvising. This is the macOS-only half of iOS bring-up —
the plumbing is already in the repo and current.*

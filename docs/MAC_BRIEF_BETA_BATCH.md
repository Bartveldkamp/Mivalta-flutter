# MAC BATCH BRIEF — one coordinated pass to close the beta build gap

> **Purpose.** Everything that needs the **Mac/NDK toolchain** to take the engine
> from *engine-ready* (verified, on `main`) to *product-build-ready*, in **one
> coordinated session** instead of three trips. Authored by the coding seat
> (cannot run the Mac/cargo-ssh/NDK toolchain in the cloud); **execute on the Mac
> in order.** Each step has a command, the expected output, and a verification —
> the session is meant to be **mechanical, not exploratory**.
>
> **Accurate-to-main when written:** flutter pin = `79b7c93`; rust-engine `main` =
> `73e17b1` (A3 + Task C); `gatc-vault` `rusqlite` feature = `bundled-sqlcipher`
> (NOT yet vendored-openssl). Re-confirm these before starting.

## Preconditions (do first)
- [ ] **Merge flutter PR #103** (`ci(flutter): fix smoke NDK — local-cache:false`). Without it the smoke NDK step fails before reaching SQLCipher. (Founder merge.)
- [ ] Mac has the `mivalta-rust-engine` SSH access (the git-rev pin resolves) + Android NDK r27 + `cargo-ndk` + Flutter `3.44.0` stable.

---

## Step 1 — rust-engine: confirm `bundled-sqlcipher-vendored-openssl` (the DECISIONS §1078/§1138 Mac/NDK item)

**Why:** `gatc-vault` uses `rusqlite` `bundled-sqlcipher`, which needs **system
OpenSSL**. The Android cross-compile has none → `sqlcipher/sqlite3.c: fatal error:
'openssl/crypto.h' file not found` (the real smoke blocker). The vendored variant
builds OpenSSL for the target. This is the change `DECISIONS.md` §1078/§1138
parked "to confirm on the Mac/NDK" — this is that confirmation.

1. In `mivalta-rust-engine`, on a branch off `main` (`73e17b1`):
   `crates/gatc-vault/Cargo.toml` →
   `rusqlite = { version = "0.31", features = ["bundled-sqlcipher-vendored-openssl"] }`
2. Cross-compile the vault for Android to prove OpenSSL now vendors:
   ```bash
   cd /path/to/mivalta-rust-engine
   cargo ndk --target arm64-v8a --platform 21 -- build -p gatc-vault --release
   ```
   - **Expected:** the `libsqlite3-sys` build compiles `sqlcipher/sqlite3.c`
     **without** the `openssl/crypto.h` error (OpenSSL is built from the vendored
     source). Build finishes clean.
   - **If it still errors** (e.g. needs `perl`/`make` for the OpenSSL build, or an
     `OPENSSL_*` env): that's the genuine iteration this step exists to find —
     install the OpenSSL build deps and retry. Do **not** revert to
     `bundled-sqlcipher`; the vendored route is the decided path.
   - **Verify:** `cargo test -p gatc-vault` still green on host (host build
     unaffected).
3. Run the host gate so the feature swap didn't regress anything:
   `cargo test --workspace --lib --tests` → **2051 passed** (same as `main` today).
4. Commit + open the rust-engine PR; merge on green. **Record the new rev** (call
   it `<RUST_REV>`) — it contains A3 + Task C **+** vendored-openssl.

> **Scope note:** this is a load-bearing crate-build change; it adds an OpenSSL
> build to every `gatc-vault` compile (slower, adds build deps). That tradeoff is
> the reason it was parked for Mac confirmation — confirm it builds on the real
> toolchain before relying on it.

---

## Step 2 — flutter: bump the engine pin to `<RUST_REV>`

1. `rust/Cargo.toml` — both deps to the new rev:
   ```
   gatc-ffi     = { git = "...mivalta-rust-engine", rev = "<RUST_REV>" }
   gatc-viterbi = { git = "...mivalta-rust-engine", rev = "<RUST_REV>" }
   ```
2. Refresh the lock (needs the SSH the cloud lacks):
   ```bash
   cd rust && cargo update -p gatc-ffi -p gatc-viterbi
   ```
   - **Expected:** every `gatc-*` source line in `rust/Cargo.lock` flips from
     `?rev=79b7c93#…` to `?rev=<RUST_REV>#…`. Commit the refreshed `Cargo.lock`.
3. Rebuild the native artifact (NO FRB regen — `engine_registry.json` is
   **v2.24 unchanged** across `79b7c93 → <RUST_REV>`, zero method delta, so the
   shim + `lib/src/rust/` are untouched):
   ```bash
   scripts/build_ios.sh        # and/or the Android .so build per target
   ```
   - **Verify:** `frb-drift-guard` logic stays satisfied (no shim/binding change);
     `lib/src/rust/` git-clean.

---

## Step 3 — flutter: local gate + on-sim sanity

```bash
flutter pub get
flutter analyze            # expect: No issues found
flutter test               # expect: all green (418+ as of main)
```
- **On-sim / device sanity:** readiness home renders as before (the pin bump is
  behaviour-preserving for display).
- **Cross-source dedup is now ACTIVE (the point of the bump):** sync a workout via
  the health store **and** capture the same session live via a BLE strap → confirm
  the engine folds the load **once** (no double-count). Before this bump the app
  forwarded `start` but the engine couldn't read it; now it can.

---

## Step 4 — push → smoke goes green

Push the flutter pin-bump branch. With **#103 merged** (NDK) **+ `<RUST_REV>`**
(vendored-openssl), the `smoke` job should now pass end-to-end: NDK resolves →
SQLCipher cross-compiles → APK packs `libmivalta_rust_bridge.so`.
- **Verify:** `Smoke build / smoke` = green on the PR.

> **FOUNDER / BRANCH-PROTECTION ACTION (not a Mac/Code step):** once `smoke` is
> green on `main`, **make `smoke` a required check** in branch protection.
> Until then it's the only end-to-end Android-build gate and it's non-required —
> a real cross-compile regression could slip in unseen. This is Bart's GitHub
> settings click, not part of this brief.

---

## Step 5 — BLE device-lab pairing sign-off (hardware)

Task A's BLE strap track is code-complete + unit-green (mock transport); live
radio pairing is hardware-only.
- Pair each standard HR-profile strap (Verity Sense, Polar H10, Garmin HRM,
  Wahoo TICKR) via `sensor_check_screen`: scan (0x180D) → connect → live HR/RR →
  stop & save.
- **Verify per strap:** live HR ticks during capture; on save the session
  couriers through the ingest adapter and lands a workout observation (engine
  computes load); no crash on connect/disconnect/abort.
- Record the device-lab sign-off (which straps verified) — that closes Task A's
  last gate.

---

## Done = beta build-ready
Pin reads Task C · SQLCipher vendored-openssl confirmed · smoke green (then made
required by Bart) · BLE straps signed off. Track the rest (procurement, pilot) in
`mivalta-rust-engine/docs/PRODUCT_READINESS.md`.

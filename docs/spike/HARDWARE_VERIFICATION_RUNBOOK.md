# Hardware verification — phone session runbook

> Target: 15-20 min on the Motorola Edge 60, end-to-end. Founder
> session; Hetzner Claude does NOT touch the phone. Master
> orchestrator sequences Android Lab T4/T5 alongside this Flutter
> Hardware Verification Kit.

## Prerequisites (one-time)

- Motorola Edge 60 connected via USB, USB debugging enabled.
- `adb devices` lists the phone.
- `scp` configured for `root@144.76.62.249` (Hetzner).
- `~/lab/` directory on founder laptop for the APK transfer.

## Steps

1. **Fetch the APK from Hetzner.**

   ```bash
   scp root@144.76.62.249:/root/Mivalta-flutter/build/app/outputs/flutter-apk/app-debug.apk \
       ~/lab/mivalta-flutter-day7.apk
   ```

2. **Install on device.**

   ```bash
   adb install -r ~/lab/mivalta-flutter-day7.apk
   ```

   `-r` = replace existing install; preserves `getApplicationSupport`
   so the V10.1 GGUF (if already downloaded by a previous session)
   stays cached. If the GGUF isn't on disk, step 4's first Run will
   download it (~1.03 GB over HTTP from the model host).

3. **Launch the app.**

   ```bash
   adb shell am start -n com.mivalta.mivalta_flutter/.MainActivity
   ```

   Or tap the icon from the launcher. SpikeHome should load.

4. **V10.1 acceptance bar — TTFT < 10s, three runs.**

   - On SpikeHome, leave the default prompt "Should I train today?".
   - Wait for the status line to read `Status: ready — Model verified
     at …` (downloads + sha256 verify; one-time on first launch).
   - Tap **Run**. Wait for `Total: <N> ms` to populate.
   - Read the telemetry block at the bottom of the screen. Tap it
     once → "Telemetry copied to clipboard". Paste into Run 1's row
     in `docs/spike/HARDWARE_VERIFICATION_RESULTS.md`.
   - Tap **Run** twice more, capturing Run 2 and Run 3 the same way.

5. **SourceTier swatch exercise (debug-build only).**

   - On SpikeHome, **long-press the title bar** ("MiValta V10.1
     Spike"). This opens **Debug — SourceTier exerciser** (the entry
     point is `kDebugMode`-gated; absent from release builds).
   - Tap **Medical (A) — write polar_h10**. The screen flashes
     `Wrote polar_h10 → expect medical swatch.` and routes to the
     Readiness screen. Verify section (e) shows the green `Medical (A)`
     swatch. Mark the row in `HARDWARE_VERIFICATION_RESULTS.md`.
   - Hit the system Back button to return to the exerciser. Tap
     **Clear vault (day7-vault dir)** to wipe state.
   - Repeat for **Device (B) — oura**, **Partial (C) — apple_health**,
     **Manual (D) — manual**.

6. **Commit the results doc.**

   ```bash
   cd ~/mivalta/Mivalta-flutter
   git checkout main
   git pull
   $EDITOR docs/spike/HARDWARE_VERIFICATION_RESULTS.md   # paste the numbers
   git add docs/spike/HARDWARE_VERIFICATION_RESULTS.md
   git commit -m "docs: hardware verification results — V10.1 spike closed"
   git push
   ```

   This commit **is the spike close**. After it lands, the V10.1
   spike acceptance bar is empirically settled and the next milestone
   is "MVP build week 1, Figma rebuild" — opened from a fresh session.

## Troubleshooting

- `Run` button stays disabled → model still downloading or verifying.
  The status line names the stage; wait it out (sha256 verify on a
  cached 1.03 GB file is ~5 s on the Edge 60).
- Telemetry shows `Peak: — KB PSS` → platform channel didn't return.
  Likely the `RUST_ENGINE_DEPLOY_KEY` secret was set up but the APK
  was built from a stale `.so`. Rebuild on Hetzner, scp again.
- Debug exerciser doesn't appear on long-press → the APK was built
  with `--release` instead of `--debug`. The brief specifies
  `flutter build apk --debug` for this milestone.
- `Wrote <source>` then no swatch on Readiness → check the smoketest
  vault wasn't sharing state. The exerciser uses `day7-vault`
  separately from `day4-vault` to avoid this; if it bleeds through,
  the Clear-vault button resolves it.

## Sequencing notes for the master orchestrator

- Android Lab T4 (rust-engine fixture suite) can run on the same
  device first; its tests touch a separate package and don't conflict
  with this APK's `day7-vault` directory.
- T5 (Compose-equivalent UI port) should NOT run on the same device
  in the same session — it shares the SmoketestApp.kt vault
  namespace.
- Total budget: 15 min for steps 1-5 if everything is warm; up to
  40 min on first run if the GGUF download is fresh.

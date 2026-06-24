# Mac Brief — n=1 beta: get the functional app on the founder's phone

**Executor:** Mac Claude Code (Alta). **Goal:** put a working debug build on
Bart's Android phone so he can **dogfood it (n=1)** — the fastest, cheapest way to
find real bugs and "does this feel right" signal before the formal P0 pilot.
**Why now:** the engine is built and the app is wired; the only thing between Bart
and using MiValta daily is a build + an install. This is the highest-leverage
"contact with reality" move.

> **It will be unstyled.** This is the *functional* app (placeholder theme), not
> the designed one (Okapion, per `DESIGN_BUILD_SPEC.md`). That's the point: dogfood
> the function, let real use steer the design. Don't wait for design to ship this.

## Phase 1 — ship what works *today* (do this first, fast)

The daily readiness loop is fully wired and needs no new code:

1. **Build the debug APK** per `README.md` → "Quick start": Flutter 3.44 + Rust +
   `cargo-ndk` + NDK 28 + SSH to the engine repo → `cargo ndk … build` the shim
   `.so` → drop the stray `libgatc_ffi*.so` → `flutter build apk --debug
   --target-platform android-arm64`.
2. **Install on Bart's phone** (`adb install` or transfer the APK). Android-first
   (iOS bring-up is separate).
3. **Connect Health Connect** on the phone (grant HRV/RHR/sleep/workout perms) so
   `health_ingest` has real data to pull.
4. **Verify the on-device loop** (this IS the on-device smoke test from the pilot
   runbook §5):
   - a) Fresh profile shows the honest calibration framing / F1 no-data copy.
   - b) After a morning sync, a real readiness number + state + the three-zone home
     render.
   - c) Continuity: kill and relaunch — state restores (not a fresh 0).
   - d) The source-tier dot matches the device tier; advisor returns A/B/C.
5. **Hand Bart a 60-second dogfood log** (a notes template): each morning, does the
   readiness number *feel* right? does today's suggested session make sense? did
   anything look broken/empty? This subjective log is real n=1 data.

**Phase 1 is shippable to the phone immediately** — biometric readiness works
end-to-end without workouts.

## Phase 2 — close the loop (the workout wire)

For the advisor's rotation, post-workout report, and the charts to come alive, the
workout-ingest wire must land — that's its own brief, **`MAC_BRIEF_WORKOUT_INGEST.md`**
(the #1 build task). Sequence: Phase 1 onto the phone *now* → Phase 2 next → then
Bart's dogfood covers the full loop.

## Definition of done

- A debug APK installed on Bart's Android phone, pulling his real Health Connect
  data, showing a real readiness home that survives a restart.
- The 4 on-device checks pass (or each failure is logged with the screen + payload).
- Bart has the dogfood notes template.
- Any build/runtime issue that blocks install is reported with the exact error
  (don't paper over a crash — a phone that won't run the app is the finding).

## Out of scope

Visual design (that's Okapion / `DESIGN_BUILD_SPEC.md`), iOS, the Play Store,
vendor OAuth. This is one phone, one founder, real data, today.

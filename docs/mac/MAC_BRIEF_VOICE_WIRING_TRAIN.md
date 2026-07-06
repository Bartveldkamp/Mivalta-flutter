# MAC BRIEF — Voice wiring train (S1/S3/S4 seams + engine morning-read verdict)

**Audience:** Mac build executor (build/run + FRB codegen only, per Rule 1).
**Supersedes:** the "To Unblock" list in `review/voice/BUILD-REPORT-voice-v1.md`
(that list names three seams; the train is FOUR — it was written before the
morning-read verdict moved engine-side).
**Written:** 2026-07-06 (coding seat).

## Why this train exists

rust-engine PR #388 lands four FFI seams this repo consumes:

| Seam | Unblocks |
|---|---|
| `realize_workout_reflection` | S1 post-workout coach reaction (BS-016) |
| `realize_advisory_offer` | S3 advisory offer line (BS-016) — returns `why`/`purpose` on the `RealizedLine` |
| `realize_day_summary` | S4 end-of-day summary (BS-016) |
| `morning_read_verdict` | BS-012 salience decision moves ENGINE-side; the Dart decision table in `lib/services/morning_read_gate.dart` is deleted |

Unlike the last two pin bumps, this one **REQUIRES FRB codegen** — four new
shim functions cross the Dart↔Rust boundary.

## Preconditions (do not start until BOTH are true)

1. **rust-engine PR #388 is MERGED.** The pin target is the **merge commit SHA
   on rust-engine `main`** (squash merge — never pin a branch SHA; it becomes
   unreachable when the branch is deleted). Read it from GitHub at execution
   time; zero guessing.
2. **The coding seat has pushed the code train** to
   `claude/mivalta-plan-model-eval-rtbsuq` in THIS repo: pin bump with the real
   merge SHA, the four shim fns in `rust/src/api.rs`, facade methods in
   `lib/rust_engine.dart`, the morning-read gate swap, and tests. The Mac does
   not author any of this (Rule 1); if the branch does not contain these
   commits yet, stop and report.

## What the code train changes (context, not your work)

- **Shim (`rust/src/api.rs`):** four new fns, each one `gatc_ffi::*` call →
  raw JSON string, pattern identical to `realize_advisor_line`.
- **Facade (`lib/rust_engine.dart`):** four matching methods.
- **Morning-read swap (`lib/services/morning_read_gate.dart`):** the Dart
  decision table (three-reasons logic, dead-zone, dedupe, no-state-word
  backstop) is DELETED — the engine decides via `morning_read_verdict`. The
  client keeps ONLY its courier duties: read `coach_presence` +
  last-delivered markers + same-day flag from SharedPreferences, pass them
  in, render the returned `title`/`body` verbatim, `markDelivered` on fire,
  schedule the OS notification. This also fixes the silent advisory bug by
  construction (the Dart gate parsed `pending_advisories` as a JSON array;
  the engine returns a struct — the advisory trigger never fired).
- **Notification title:** now the engine's card-worded state display
  (capitalized), never the raw enum token — the lock-screen enum leak is gone.
  Empty `body` is legitimate (title-only notification, honest absence).
- **Tests:** the Dart decision-table unit tests are replaced by courier/seam
  tests (prefs round-trip, verdict-JSON render, title-only path).

## Mac execution steps

> **UPDATE (2026-07-06, post-#388 merge):** the coding seat already executed
> the pin bump (`3b5ec7c`), `cargo update`, **FRB codegen** (bindings in
> `lib/src/rust/` are committed), the shim/facade/gate-swap code, and verified
> `flutter analyze` (0 issues) + `flutter test` (all green) on the branch.
> The Mac owes ONLY the physical layer:

```bash
git checkout claude/mivalta-plan-model-eval-rtbsuq && git pull
flutter pub get && flutter analyze && flutter test   # confirm locally
./scripts/build_ios.sh          # xcframework rebuild at pin 3b5ec7c
flutter run                     # simulator → verification list below
```

## What to verify on the simulator (report each with a screenshot)

1. **S1:** complete/seed a workout → Today shows the coach reflection line
   (graded session gets prose; ungraded gets the honest "logged, not judged"
   line — NEVER a fabricated grade).
2. **S3:** Advisor screen offer line reads as coach voice; "why?" disclosure
   still works (`why`/`purpose` now ride on the `RealizedLine`).
3. **S4:** end-of-day summary renders for rest / single / multi-session days.
4. **BS-012:** notification preview (You screen) shows the card-worded title
   (e.g. "Carrying some fatigue"), never `Accumulated` raw; presence=off is
   fully silent; Android 13 asks POST_NOTIFICATIONS at runtime.
5. `flutter analyze` + `flutter test` output pasted verbatim in the report.

## Known follow-ups (NOT this train)

- iOS xcframework was already owed at `a579584`; this bump folds that debt in.
- In-app human panel (founder + Toon + beta athletes) starts once this train
  is on a device — that panel is the product verdict on the voice.

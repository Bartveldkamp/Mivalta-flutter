# MAC BRIEF — Code-first finish line (pin 5849920, registry v2.44)

Scope: build/run only (Rule 1). All code is authored and pushed; this brief
closes the PR-A → PR-D2 train (Flutter #182–#186 + engine #402–#411). FRB
codegen for every new shim fn ALREADY RAN in PR-B (#183; host codegen,
frb 2.12.0 / Flutter 3.44.0 — the drift-guard pins), and PR-D2 (#186) adds
**no** FFI surface (verified: `engine_registry.json` + `crates/gatc-ffi`
byte-identical across `8f506da..5849920`). Do NOT re-run codegen unless the
drift guard says otherwise.

## What changed since the last executed brief (context, not instructions)

- Engine pin `a510184 → 8f506da → 5849920` (rust-engine `main` after #411).
- Six shim fns accumulated (all FRB-regenned in their PRs):
  `read_activities_in_range`, `metabolic_time_in_zone_rollup`,
  `import_encrypted_vault`, `hrv_trend`, `rhr_trend`, `list_data_sources`.
- Screens wired to them (PR-C1–C4): Journey history/recall/trends/sleep,
  You provenance + vault restore + live units toggle, Today pull-to-refresh.
- PR-D2: the advisor detail renders the ENGINE-COMPOSED `coach_sentence`
  verbatim; the decision chip is nested "Endurance · Z2" (LEVELS LAW
  communication shape); onboarding shows the platform-true health store.

## Steps

1. `git pull` `main` (after #186 merges).
2. `cd rust && cargo update` (lock already pins the gatc revs; refreshes
   host artifacts only).
3. Rebuild the xcframework via `scripts/build_ios.sh`.
4. `flutter run` (debug, iOS simulator) with `--dart-define=SEED_DEMO=true`
   on a FRESH install (or after Settings → Delete All My Data).

## Witnesses (what to report back)

Each witness is a REAL screen state fed by real engine values — no state may
be reported "OK" from memory; look at the running app.

1. **Today** — readiness headline renders from the seeded season; the
   decision chip (if a restrictive cap is active in the seed) reads
   "<Level> · <Zone>" (e.g. "Endurance · Z2") — level FIRST, never the code
   alone. Pull down: the refresh indicator runs a real sync pass.
2. **Advisor detail** — open an option: the "Your session" card shows the
   engine's coach sentence ("Today your workout is …, a Z_ workout in …").
   If an option has no main set, the card is ABSENT — no
   "Warmup → Main set → Cooldown" line anywhere (that placeholder is gone).
3. **Journey** — HISTORY lists the seeded workouts newest-first and a row
   opens the workout detail; trained-time-by-level shows real 7d/28d
   rollups; RECOVERY TRENDS + SLEEP cards fill (or state honest absence).
4. **You** — data sources list real tiers from `list_data_sources`;
   "Restore a backup" round-trips a `.mvbackup` export (wrong passphrase
   must FAIL LOUD with no partial import); units toggle flips rendered
   units live.
5. **Onboarding** (fresh install, before seeding) — the data-sources step
   names the platform store: "Apple Health" on the iOS sim. (Android
   equivalent shows "Health Connect" — witness only if an Android build is
   run.)
6. **Cold restart** — kill and relaunch: readiness and history survive
   (persisted Viterbi state restored, no re-onboarding).

## Screenshots (Design handoff material — the finish-line deliverable)

For EVERY screen above, capture one screenshot per named state
(filled / honest-absent where reachable), each stamped with the app's
commit SHA (visible in the debug build banner or noted in the filename:
`<screen>_<state>_<short-sha>.png`). These are the SHA-stamped witnesses
the handoff bar requires — report the set back with the exact SHA built.

Report the exact console line + stack trace if any witness fails; do not
patch code on the Mac (Rule 1 — report back instead).

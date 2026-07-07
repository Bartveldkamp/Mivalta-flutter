# MAC BRIEF — benchmark-loop unmute (pin 63d8744, registry v2.42)

Scope: build/run only (Rule 1). All code is authored and pushed on the
working branch; FRB codegen ALREADY RAN in the PR (host codegen, frb 2.12.0 /
Flutter 3.44.0 — the drift-guard pins), so `lib/src/rust/` and
`rust/src/frb_generated.rs` are current. Do NOT re-run codegen unless the
drift guard says otherwise.

## What changed (context, not instructions)

- Engine pin `3b5ec7c → 63d8744` (rust-engine `main` after #394). Additive
  FFI only — nothing the old shim called changed shape.
- Five new shim fns: `sync_benchmark_from_activities`,
  `write_benchmark_event`, `write_benchmark_history`,
  `read_benchmark_history`, `postprocess_profile`.
- New Dart courier: `lib/services/benchmark_sync.dart`, called from the
  ingest post-workout path and the kDebugMode seeder witness in `main.dart`.

## Steps

1. `git pull` the working branch (or `main` after merge).
2. `cd rust && cargo update` (the lock already pins the gatc revs +
   `openssl-src 300.6.1`; this just refreshes any host-platform artifacts).
3. Rebuild the xcframework via the usual `scripts/build_ios.sh` path.
4. `flutter run` (debug, iOS simulator) with
   `--dart-define=SEED_DEMO=true` on a FRESH install (or after
   Settings → Delete All My Data).

## Witness (what to report back)

On boot after seeding, the console must print:

    benchmark loop witness: decision=hold applied=false

`hold` is CORRECT here — the canonical debug athlete carries no FTP
benchmark yet, so the engine holds `no_current_benchmark`. The witness
proves the full courier chain executes on-device (vault history read →
engine gate → history write) without error. Report the exact printed line
plus any stack trace if the line is missing.

Also confirm the normal seeded boot still lands on Today with readiness
rendered (no regression in the existing seed path).

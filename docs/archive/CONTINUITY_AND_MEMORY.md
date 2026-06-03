# CONTINUITY & MEMORY — hard requirement, day one

> **Status:** MANDATORY. Founder directive 2026-06-01: *"we must have 100%
> continuity of course, from day one."* This is not a later-phase nicety —
> it is an acceptance criterion on every MVP-1 PR that touches engine
> construction, observation writes, or Josi.
>
> Companion to `docs/MVP1_BUILD_BRIEF.md`.

## Why this doc exists

The engine is fully built to learn from, remember, and grow with the user.
That capability only becomes a *continuous experience* if the Flutter app
**wires the persistence lifecycle**. The closed V10.1 spike did NOT — it
constructed a fresh engine from the seed profile and a throwaway vault dir on
every launch, so it had **zero** continuity. Shipping that pattern again is a
hard regression. This doc names exactly what must be wired so it cannot be
skipped.

## What "100% continuity" means concretely

Close the app, reboot the phone, come back three weeks later → the app resumes
the *same* learned trajectory: personalized baselines intact, readiness model
where it left off, and Josi remembering who the person is. Never a fresh start.

## The three lifecycle obligations (all engine-supported today)

1. **Restore on launch.** On every cold start, construct the engine from
   persisted state, not from the seed:
   - read persisted Viterbi state: `VaultEngine.read_viterbi_state(athlete_id)`
   - construct via `ViterbiEngine.from_persisted_state(profile, state_json)`
     (NOT the plain `new(...)` seed constructor) when state exists.
   - first-run only (no persisted state yet): fall back to `new(...)`, then
     immediately persist (obligation 2) so the next launch restores.

2. **Persist after every change.** After processing observations / state
   changes: `ViterbiEngine.save_state()` → `VaultEngine.write_viterbi_state(...)`.
   The learned model must be on disk before the process can die.

3. **Josi uses the vault, always.** Construct Josi via
   `ChatEngine.new_with_vault(profile, vault_path)` — **never** the in-memory
   `new(...)`. That is what persists `athlete_memory` + conversation turns so
   Josi remembers the person across sessions. (Josi lands in the later LLM PR,
   but the constructor choice is locked now so it is not retrofitted.)

## Consent coupling (do not break)

A single switch governs both learning and memory: `pause_learning` /
`resume_learning` / `is_learning_paused`. When paused, the engine stops
personalizing AND Josi stops writing new memories — by design. The continuity
wiring must respect this gate, not bypass it.

## Acceptance criteria (enforced per PR)

- **PR-B (home) / PR-E (ingest):** an integration/widget test proving the
  restore→use→persist round trip: seed a first run, write an observation,
  tear down the engine, reconstruct via `from_persisted_state`, and assert the
  learned value survived (not reset to seed). No throwaway-vault pattern.
- **No fresh-construct-on-launch** anywhere on the production path. The seed
  constructor is reachable only on genuine first run.
- **Josi (LLM PR):** constructed with `new_with_vault`; a test asserts a memory
  written in one session is recalled in a new `ChatEngine` instance.

## Relationship to the two-vault decision

Continuity lives in the **owner vault** (`viterbi_state`, `athlete_memory`,
conversation turns) — it is the authoritative store and is what guarantees the
continuous experience. The two-vault cache-as-read-path work (engine side) is
about *how* that state is stored/served/erased; it does not create continuity
and must not compromise it. Both are day-one requirements, tracked separately:
continuity = this doc (Flutter lifecycle); cache-read-path = the engine F-V1
write-through PR.

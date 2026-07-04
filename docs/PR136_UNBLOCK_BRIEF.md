# Unblock brief — PR #136 "Feature/bs007 verdict"

**For:** whoever owns #136 (the parallel design session) + the Mac build executor.
**Status as of 2026-07-04:** #136 is **`dirty` (merge conflict with `main`)**, **no CI has run** (0 checks), and it still carries two fabrications that must not ship. This brief is what needs to happen to land it. I did **not** edit #136 — it's another session's 10-commit feature (+1092/−173) and rebasing it is the owner's call.

## Root cause (why it's blocked)

#136 branched from `f4d248a` (**#131**) and was never updated. Four PRs merged to `main` after it: **#132, #133, #134, #135**. #133 in particular (the HR-courier / F-ING-A change) rewrote the same ingest files #136 touches, so the branch conflicts. CI won't evaluate it until the conflict is resolved.

## Exact conflict set — 8 files changed on BOTH #136 and `main`

| File | What changed on `main` since #131 | Care level / resolution |
|---|---|---|
| `lib/services/health_ingest.dart` | **#133** — couriers **raw HR samples** to the engine; the Dart avg/max mean was removed from the load path (Charter Law 2). | **HIGH — do not clobber.** Keep `main`'s raw-courier path; re-apply #136's changes on top. The Dart mean must NOT return to the load input. |
| `lib/services/ingest_adapter.dart` | **#133** — `buildWorkoutObservationJson` emits the raw HR stream; `ingestWorkout` threads `hrSamples`. | **HIGH.** Same — take `main`'s version, layer #136 on top. |
| `test/ingest_adapter_test.dart` | **#133** — asserts raw `hr_samples` are couriered. | **HIGH.** Keep `main`'s assertions; add #136's, don't replace. |
| `rust/Cargo.toml` | **#133** — engine pin narrative. **Pin rev is identical** on both sides (`a57958458ef8a0bdb74dc80b587070dc0d20a65e`). | **Trivial.** Only the comment-history block differs — keep `main`'s (more current). No re-pin, no FRB-regen. |
| `lib/screens/today_screen.dart` | #133/#134/#135 wiring. | **Medium.** #136's rework (hero/glow/verdict) is in different regions than the ingest/weather/load code — should merge with small manual fixups. See fabrication note below. |
| `lib/theme/zone_names.dart` | #134 (advisor) — the LOCKED zone→energy-name map (DR-018 A3). | **Medium.** Preserve the locked mapping; merge #136's additions. |
| `lib/theme/tokens.dart` | #134/#135 design tokens. | **Medium.** Merge; keep the locked source-tier + zone colors. |
| `CLAUDE.md` | #135/#134 pin + milestone updates. | **Low.** Doc merge — take the union, keep the current pin section. |

## Two fabrications #136 still contains (must be fixed before merge)

#136's `today_screen.dart` still has both (its rework didn't touch these lines):
- **`'Sunny 18°'`** placeholder (~line 366) → must be honest absence (`SizedBox.shrink()`), Rule 6.
- **`?? 600`** load ceiling (~lines 563/567) → must not invent a range; render honest absence until the engine provides a real ceiling. Rule 3.

**These are already fixed in PR #137**, in the same regions. Cleanest path: **let #137 land first**, then #136 rebases and picks up the honest-absence versions automatically; or #136 applies the same two changes itself. Either way, do not ship either fabrication.

## Recommended procedure

1. **#137 merges first** (it's clean, tiny, correctness-only, base `main`).
2. Owner updates #136: `git fetch origin main && git rebase origin/main` (or merge `main` into the branch). Resolve the 8 files above — **the three ingest files are the ones to get right** (keep the raw-HR-courier path from #133).
3. Verify on the Mac executor: `flutter pub get && flutter analyze && flutter test`. The ingest tests (`ingest_adapter_test.dart`, `workout_ingest_test.dart`) are the guard that the courier path survived the rebase.
4. Confirm the two fabrications are gone from the final `today_screen.dart`.
5. Push → CI (smoke + drift-guard) should now run and gate normally.

## What NOT to do

- Do **not** re-pin the engine — the pin is already correct and identical to `main`.
- Do **not** reintroduce the Dart HR mean into the load path (that's the exact Law-2 violation #133 fixed).
- Do **not** merge with either fabrication still on screen.

---

*Written by the engine/wiring session. Cross-references: PR #137 (fabrication fixes + `docs/DESIGN_DATA_CONTRACT.md`), rust-engine #386 (beta, merged), #133 (HR courier).*

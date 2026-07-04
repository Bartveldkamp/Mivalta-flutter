# Brief for Claude Code (Mac) — branch reconcile, merge order, and a direction

**From:** the engine/wiring session (GitHub-MCP only, no filesystem).
**To:** Claude Code on Mac (filesystem + build/run + the MERGE-001 queue owner).
**Date:** 2026-07-04.
**Why you own this:** you have the filesystem, the build toolchain (`flutter analyze/test`, xcframework), and the live MERGE-001 queue context. I don't. Two agents rebasing/deleting the same branches is the exact collision the "one coding seat" rule prevents — so **you drive the branch work; I stay on GitHub-side PRs and briefs.** This is the reconciliation + a suggested order, not instructions to follow blindly.

## 1. Two things in the MERGE-001 table disagree with live GitHub — reconcile before acting

I verified these against the real remote `main` this session:

- **`feature/dr014-d6-stamp` is marked ✅ MERGED, but its 7 commits are NOT on `origin/main`.** `git cherry origin/main origin/feature/dr014-d6-stamp` returns all `+` (none applied); there is no DR-014 / build-stamp / dart-define commit on `main`. Either it merged somewhere that isn't pushed `main`, or the queue marked it done prematurely. **Please confirm where it landed** — if it's genuinely not on `main`, it still needs to merge; if superseded, it needs deleting, not "merged".
- **`feature/bs007-verdict` (#136) is marked "ALL ✓ merge-ready", but GitHub says `dirty`.** It's 4 behind `main` (branched from #131; #132–#135 merged after), **0 CI checks have run**, and it still carries two fabrications. "Green on the review checklist" ≠ "mergeable on GitHub." It needs the rebase in `docs/PR136_UNBLOCK_BRIEF.md` first.

**General method note:** judge merged/unmerged with `git cherry origin/main <branch>` (or patch-id), **never ahead/behind counts** — squash-merges leave a branch showing "N ahead" while fully merged. That mismatch is how I caught the dr014 discrepancy.

## 2. Suggested merge order (the dependency that matters)

1. **#137 first** — clean (1 ahead / 0 behind), tiny, correctness-only: removes the two fabrications (`Sunny 18°`, `?? 600`) on `today_screen` + adds `docs/DESIGN_DATA_CONTRACT.md`. No conflicts.
2. **#136 rebased onto `main`** — resolve the 8-file conflict per `docs/PR136_UNBLOCK_BRIEF.md`. Landing #137 first means #136 **inherits the honest-absence fixes** on its rebase instead of re-introducing the fabrications. The three ingest files are the ones to get right: keep `main`'s raw-HR-courier path from #133, do NOT restore the Dart HR mean into the load path.
3. Then the rest of the MERGE-001 queue (`feature/auth` DR-015, `feature/onboarding` C3 routing, `bs003-advisor` shots).

## 3. Branch hygiene — the actual cleanup ask

The founder's goal is fewer stale branches. Safe deletion needs `git cherry`-verified full-merge, not the queue's status column. For each branch: if every commit is `=`/`-` vs `main` → delete; if any `+` and no active PR → decide keep-and-PR or abandon-and-delete. The old `claude/pr-*` set is very likely superseded by the `feature/*` rewrites — worth the check you proposed (yes, do it), but confirm with `git cherry` that no unique work is stranded before deleting any.

## 4. Open direction / advice (not orders — your call with the founder)

- **The engine is racing ahead of the display.** rust-engine #386 (beta hardening) is merged; #385 (the whole X1.1 metabolic-level model) is green and near-mergeable. The unified metabolic model, HR/watt anchoring, and warm-start seam all exist engine-side — but Flutter is one live screen deep and drops most engine truth at the JSON seam (`metabolic_level`, `hr_bpm`, readiness contributions, watts/pace-at-screen). **The highest-leverage work now is display, not more engine.** `docs/DESIGN_DATA_CONTRACT.md` (in #137) is the field-by-field map for that.
- **Re-pin timing:** once rust #385 merges, Flutter should re-pin to pick up `metabolic_level` on the JSON (additive field, no FRB-regen — just `cargo update` + xcframework rebuild). Until then `metabolic_level` parses empty, so don't wire a headline to it yet.
- **A suggestion worth weighing:** collapse the branch sprawl by adopting a strict "one feature → one PR → merge on green → delete branch same day" cadence (the flat-git rule the Charter already states). The current 5+ live `feature/*` branches with partial merges is the thing generating the reconcile cost — a tighter loop prevents recurrence more than any one-time sweep.
- **The one risk I'd watch:** the fabrication class (`?? 600`, `Sunny 18°`). It reappeared in #136 independently of #137 fixing it — which means the *pattern* is easy to reintroduce. Consider a tiny `flutter test` / lint guard that fails on a hardcoded placeholder in a data slot (a grep-level check for `?? <number>` in display denominators, or a "no literal weather" assertion). Cheaper than catching it in review each time.

## 5. What I'm NOT touching (so we don't collide)

I will not delete, rebase, or force-push any branch while you hold the queue. My surface is: PR #137 (open), the two briefs (`PR136_UNBLOCK_BRIEF.md`, this file), and the rust-engine side (#385). Ping me via a PR comment if you want me to take any GitHub-side action.

---

*Cross-refs: PR #137 (fabrication fixes + design data contract), `docs/PR136_UNBLOCK_BRIEF.md`, rust-engine #385 (X1.1 metabolic model, near-merge) / #386 (beta, merged).*

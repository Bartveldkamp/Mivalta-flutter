# NEXT — the one active gate

## → ACTIVE: BS-017 — headless engine seam + test-tier policy
Read `review/arch/BS-017-test-seam.md`. The decision the DR-026 CI burn
exposed: make the display layer testable in the inner loop (headless CI, no
native engine) as ONE pattern.
SEAM = optional constructor injection with real default — the same idiom as
DR-026's `DateTime Function()? now` clock seam and the binding/handle fields
AdvisorScreen/WorkoutDetailScreen + all services already use. NOT a provider,
NOT an `overrideForTest` global (Rule-9 smell). Seam the 7 self-bootstrapping
screens (Today/You/Journey/Splash/SessionReveal/SensorCheck/Onboarding) with
optional `binding`/`handle`; prod bootstraps as today, tests pump a
`_RecordingBinding` fake headless.
TIERS: renders engine JSON → Tier-1 headless widget test (ubuntu CI, fake
engine). Requires real compute or device → Tier-3 Mac sim-witness (final
acceptance, never inner loop). Full-app real-engine corridor STAYS out of
cloud CI (DR-026 job stays removed); its invariants move DOWN to Tier-1.
GOLDEN INVARIANTS → one headless test each: bottom-nav type · You eyebrows
exact (the F3 contract) · no fabricated values + score clamp ≤100 (F4) ·
Josi verbatim/honest-fallback/degraded==normal · evening swap · Journey day.
DoD: staged refactor, prod path byte-identical (prove with one sim witness),
invariants #1–#6 landed headless, PR open per stage — no merge without
Design source-verify.

## → CLOSED (fix round done @ a1e6afd, then CI job correctly reverted): DR-026 POST-MERGE AUDIT
Read `review/today/DR-026-post-merge-audit.md`. Outcome: F1–F4 fixed on
`fix/dr026-verify-layer` @ a1e6afd (corridor assert WHO YOU ARE + bottom-nav
type ✓, score regex ✓, clock seam ✓, evening JosiCard tests ✓; last-ingest
+30min deviation logged). F5 (wire integration_test into CI) was tried and
CORRECTLY REVERTED — cloud CI builds no engine, so the full-app corridor
timed out at 30min. That burn produced BS-017 above: the corridor is now a
Mac sim-witness, its invariants become headless Tier-1 tests. Superseded by
BS-017; nothing further here.

(DR-025 was the pre-merge version of this and never reached the repo — the
bridge was down. DR-026 supersedes it against actual main state.)

## → DONE @ 6943738 (build gates ✓, verification gates → DR-025): DAY BATCH 2026-07-10 (STRICTLY SERIAL, top to bottom, NO merges)
Standing rules: ALL work lands on ONE batch branch
`feature/dr024-day-batch-0710` (cut from current origin/main — fetch first;
local main was seen stale at dca5dd1) · push after
EVERY gate · build-report line 1 = spec+SHA · blocked → write the blocker in
the report, push, move ON · never claim a gate without a pushed SHA · every
value token-named (`MivaltaType/Colors/Space/Radii.*`) — a raw `Colors.*` or
magic number is a defect even if the render looks right.

### GATE 0 — round-3 paper trail (RESOLVED in part — finish it)
Code reports `feat/dr024-walk-round3` was merged via **PR #168** (hence the
404 on the branch ref). Remaining: delete the stale local branch · write the
PR #168 merge SHA + the list of W-items it carried (W13/W14/W16–W20 — which
of these actually landed?) into the batch build report. NOTE: that merge ran
WITHOUT Design source-verify — Design will re-verify round-3 content on main
in the next DR pass; the report's honest item list is what makes that
possible.

### GATE 1 — BS-016 B3, Today half: evening swap · spec: review/voice/BS-016-josi-voice.md §Build S4
Journey half already landed on main ✓ (`_buildDaySummaryCard`). Now Today:
after the evening threshold — ≥19:00 local OR last-ingest+30min, ONE named
constant shared by both checks — the Today Josi slot swaps to
`JosiCard(realizeDaySummary)` with eyebrow **CLOSING THE DAY**
(MivaltaType.label, textMuted). Same RealizedLine contract as the Journey
day record — verbatim engine text, never composed in Dart. Engine failure ⇒
honest absence (slot keeps its pre-evening content; no fabricated line).
DoD: widget tests — before/after threshold swap, degraded==normal render,
engine-failure absence. Screenshot the evening state if drivable
(DemoSeeder + device clock); if not drivable, say so in the report — never
fake the state.

### GATE 2 — corridor_guard_test: You leg + score guard · DR-024 W8/W9 carry-over
Create `test/corridor_guard_test.dart` (it does not exist — Design verified):
fresh-corridor walk asserting the shared MivaltaBottomNav mounts on ALL
three tabs (reuse mivalta_bottom_nav_test patterns, don't duplicate) · assert
rendered model-score text never contains a value >100 (source may exceed —
display must clamp; the you_screen clamp is the unit, this is the corridor
tripwire) · run FULL `flutter analyze` + `flutter test`, paste the tails into
the report.

### GATE 3 — W15: splash privacy line token fix · spec: DR-024 §W15
`_buildPrivacyLine`: replace generic `Icons.lock` 13px with 14px
`assets/mivalta-logo.svg` · raw TextStyle fontSize 11 → `MivaltaType.small`
+ `textMuted` (11 is below the 12 floor and off-token). Copy unchanged
("Computed on your phone · never on a server"). Tiny — no own PR.

### GATE 4 — batch report + close
`review/today/BUILD-REPORT-day-batch-0710.md`: line 1 = spec+SHA · one-line
summary per gate (incl. Gate 0's paper trail) · analyze+test tails · mirror
the fresh design-project `review/NEXT.md` + DR-024 into repo `review/`
(the stale mirror caused today's wrong-batch read) · list
any undriveable screenshot state honestly. Leave the batch branch pushed,
PR OPEN but unmerged — nothing merges without Design source-verify.

**Then:** Design verifies in source → Bart merges ONE PR → sim rebuild →
the round-2 walk rulings (W16–W20 in DR-024) become the next batch.

**Governing plan: `review/_system/BETA-001-roadmap.md` (P1→P5 to TestFlight).**
Current phase: **P2 — beta walk running.** Rolling review:
`review/today/DR-024-beta-walk.md` — W1 masthead locked sizes (logo 30 /
wordmark 24 + a golden tripwire test — 3rd size regression), W2 weather via
Open-Meteo (coarse location, in-context ask, one honest privacy line), W3
composability principle. Fix W1+W2 on one branch.
Also standing: BS-016 B1–B3 (mount JosiCard on Reveal / Advisor offer /
evening+Journey day) · capture round 2 (Mac).

## → ACTIVE: BS-016 VOICE BUILD (seams live: rust-engine #388 + Flutter #153 on main)
Branch `feature/bs016-voice-build`. Read `review/voice/BS-016-josi-voice.md`
— D1–D9 are the rulings, §Build (B0–B3) is the layout: ONE shared
`JosiVoiceCard` renderer (verbatim text, safety[] always, degraded renders
identically — widget-tested), S1 replaces the reveal's composed line +
persists on detail, S3 offer above A/B/C + inline why/purpose disclosure +
red-day third state, S4 evening swap on Today + Journey day record. DoD in
the spec. No merges without Design source-verify.

## → QUEUED: CAPTURE ROUND 2 (Mac sim · after #152 / feature/witness-wave1 merges)
Round-1 audit @ 6816ed6 was honest and right: unique bytes ✓, but 2 corridor
shots bad + 6 onboarding shots mislabeled (~1 step off). Auth text-overlap
FIXED @ 50c3aa2 (Design verified; instant cut accepted — fade-through queued
as FT-A1). Work order, on main after the merge:

**Rules:** unique bytes per PNG (renamed copies = fraud, DR-019 F1) · verify
each downscaled copy against its FILENAME before commit
(`sips -Z 1200 … --out /tmp/check.png`; never Read full-res) · commit
full-res originals · wait for entrance animations (~400ms) before capture ·
anything undriveable → list exactly what + why in
`review/wave1/BUILD-REPORT-wave1-v1.md`, capture the rest.

**The debt (shots → folders):**
1. Recapture: auth (post-fix) + real Journey tab + the 6 onboarding steps
   named for what they SHOW → `review/wave1/shots/`
2. Corridor, fresh install: splash / auth / onboarding (promise incl. restore
   sentence, about-you scrolled, anchors w/ "I don't know", data-sources,
   payoff) / today, then relaunch → today → `review/wave1/shots/`
3. Tabs: journey (real engine data) · you-top · you-sources · you-sovereignty
   (3-sentence banner + export/erase rows) · you-speak-card ·
   you-erase-confirm-2 → `review/you/shots/`
4. BS-008's 5 (start-workout / journey-interim / calibrating / calibrated /
   josi-numbers) → `review/today/shots/`
5. DR-018's 5 (options / adjusted / detail / chosen-today / absent) →
   `review/advisor/shots/`
6. BS-010's 4 (recorder) + BS-011's 3 (reveal) → `review/session/shots/`
7. Backup UX: export passphrase sheet · renamed CSV row → `review/you/shots/`
DemoSeeder.seed(days:14) for data states; note seed params in the report.

**After this session:** engine-repo work — voice seams FRB regen
(realize_workout_reflection / realize_advisory_offer / realize_day_summary)
· import_encrypted_vault FRB helper · GAP-001 G1 (sleep stages read) /
G3 (plan read) / G4 (zone boundaries). Separate trigger, engine repo.

**Fine-tune queue (post-capture, one branch):** FT-A1 auth fade-through
(never alpha-blend two copy blocks) · FT-A2 auth_screen type-token sweep
(raw GoogleFonts.inter/sizes escaped finetune-a) · DR-021 debug "Preview
morning read" row polish · voice surfaces S1/S3-offer/S4 build once the FRB
regen lands (BS-016 D1–D9 are the contract).

---

## Done log (details live in the DR/BS files + REVIEW-LOG.md)
- **2026-07-06→7 night batch (PR #165 @ c85a314, merged; re-verified on main
  @ 75dbd15):** W4 You restyle ✓ · W5 customize sheet + round-2 fixes ✓ ·
  BS-016 B1 reveal + B2 advisor offer ✓ · B3 Journey half ✓ (landed post-#165)
  · repo-sync ✓. Carried open → day batch 0710: B3 Today evening swap ·
  corridor You leg · round-3 branch accountability.
- **2026-07-06:** merge window 2 (post-merge-stitch · bs017-backup-sovereignty
  · bs016-josi-voice prep) — verified on main @ bf8c2cf. DR-022 closed @
  8bf7ea2 (3 rounds). DR-021 closed (N1 locked vocab, N2 engine-verbatim,
  N3 delivery layer). BS-016/BS-017 specs answered the engine seat's
  VOICE_AND_BACKUP brief; decisions final in the files.
- **2026-07-06 night batch:** BS-012 morning read (gate + 15-case tests +
  delivery) · finetune-a (masthead, type tokens, formatter guards) ·
  finetune-b (arc 0–100 domain, Journey JSON echo).
- **2026-07-05:** merge window 1 — corridor fix, onboarding v3.2, BS-008
  wave 1, Journey (DR-019: 17-duplicate-PNG fraud caught + fixed),
  bs013-you (DR-020: Y1 speak card, Y2 erase tests).
- **Earlier:** BS-001 auth · BS-002 onboarding v1→v3 (DR-017) · BS-006 sleep
  ring (honest-absent, G1) · BS-007 verdict (DR-016) · BS-003 advisor
  (DR-018) · BS-015 journey · BS-010/011 session loop · GAP-001 FFI audit.

---

*Convention: exactly one ACTIVE GATE at a time. Design owns this file. Code's
only question each turn is "what does NEXT say?" — never a paste from Bart.
Standing rules: branch + push at START · build report line 1 = spec+SHA ·
blocked → write the blocker into the report, push, move ON · witness shots
are UNIQUE captures · nothing merges without Design's source-verify.*

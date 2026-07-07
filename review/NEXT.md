# NEXT — the one active gate

## → ACTIVE: NIGHT BATCH 2026-07-06→7 (Bart asleep — STRICTLY SERIAL, top to
bottom, don't stop to ask, NO merges)
Standing rules: ALL work lands on ONE batch branch `feature/dr024-night-batch`
(continue from the W8/W9 branch — merge policy: one PR per round, merges cost
45 min) · push after EVERY gate · build-report line 1 = spec+SHA · blocked →
write the blocker in the report, push, move ON · never claim a gate without a
pushed SHA.

### GATE 1 — W4: You page minimal restyle · spec: review/today/DR-024-beta-walk.md §W4
Kill per-row leading icons · card titles → uppercase eyebrows
(MivaltaType.label, textMuted) over flat row groups · hairline separators, one
surface (no border-box per card) · rows 44px min, label left / value+chevron
right · sovereignty banner stays the ONE colored moment · erase keeps red but
drops box-in-box.

### GATE 2 — W5: per-screen customize · spec §W5
`Icons.tune` 20px textSecondary, far right of the masthead action row on
Today AND Journey (You gets none). Tap → bottom sheet "Make it yours ·
<screen>": Show-weather toggle (W2 module, default OFF, manual-place picker
first, honest subtitle) · Words/Numbers first · the screen's module list with
show/hide switches persisted in SharedPreferences (registry pattern from
`show_weather`). Reorder is post-beta — don't build it.

### GATE 3 — BS-016 B1–B3: mount JosiCard on the remaining voice surfaces
· spec: review/voice/BS-016-josi-voice.md §Build
B1: reflection = Reveal position 2 (under session header, above TIZ) via
`realize_workout_reflection`, replaces any composed line; same card on workout
detail. B2: offer line ABOVE advisor options via `realize_advisory_offer`
(delete static header); red-day = offer line + rest state (third state).
B3: Today evening swap (≥19:00 local or last-ingest+30min, ONE named
constant) with eyebrow CLOSING THE DAY; same line as Journey day record.
DoD: widget tests incl. degraded==normal on each mount.

### GATE 4 — W9 witness prep + corridor extension
Add You leg to corridor_guard_test (tab bar present — W8's shared
MivaltaBottomNav asserted on all three tabs) · assert model-score text never
contains a value >100 · run full analyze+test.

### GATE 5 — REPO-SYNC + housekeeping
Mirror current Design files into repo `review/` (DR-024, WIRE-001, BETA-001,
BS-001a/002a/002b, BS-016 — so specs are readable even when the bridge is
down) · one-line summary per gate atop the batch build report · delete stale
local branches · leave the batch branch pushed, PR OPEN but unmerged.

**Morning:** Design verifies the whole batch in source → Bart merges ONE PR →
sim rebuild → walk continues (Advisor → Session/Reveal → Journey) + W6 vessel
& W9 ~53% device witness.

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

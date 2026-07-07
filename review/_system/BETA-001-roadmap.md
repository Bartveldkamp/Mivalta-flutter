STATUS: ACTIVE ROADMAP (2026-07-06) — owns the path to TestFlight beta.
# BETA-001 — from "skeleton complete" to a real beta

Canonical scope: `BETA_SCOPE.md` (buckets) + `BETA_UI_SPEC.md` (element grain).
This file reconciles that scope against code-reality on main TODAY and orders
the remaining work. Rule unchanged: **green is earned on device, against a
real seeded athlete or connected wearable — never the demo fixture.**

## Where we actually are (verified on main @ 1ec4239)
Built & merged: corridor (splash→auth→onboarding→today) · onboarding v3
(privacy-first intake, Apple Health permission, restore link) · Today (verdict
layer, load, sleep honest-absent, whisper) · Advisor A/B/C · Journey · You
(profile, learning, sources, sovereignty, speak card) · session loop
(recorder + reveal) · morning read (gate + delivery) · backup UX (encrypted
export, erase finality) · voice seams live (engine #388 / flutter #153).
In flight: BS-016 voice build (UNPUSHED — 4 deviations flagged, see NEXT.md) ·
capture round 2 (Mac).

## The five phases (strictly ordered gates)

### P1 — Close the in-flight work (days)
1. BS-016 voice build: push → fix deviations → Design verify → merge.
2. Capture round 2: the full witness-shot debt (Mac).
Exit: main is the complete UI; every screen has honest captures.

### P2 — THE WITNESS PASS (the honesty gate — BETA_SCOPE step 1)
One Mac session, one real profile (NOT DemoSeeder): real onboarding on device
→ Apple Health connected → live for 3+ days OR seeded from a real export.
Witness every ⚠ surface rendering REAL data: readiness hero, Josi lines, load,
biometric tiles (re-point to vault path if the empty-render trap fires —
HANDOFF §8.3), Journey series, You learning status, reveal after a real
workout. Each witness = a dated shot + one line in
`review/_system/WITNESS-LOG.md`. ⚠→✓ happens here only.
Exit: zero unwitnessed surfaces in the beta set.

### P3 — Beta-blocking engine asks (engine repo, parallel with P2)
- **G1** sleep-stage read → the ring lights up (BS-006 populated state).
- **import_encrypted_vault FRB helper** → restore flow works (BS-017 F4).
- **G3** plan read → AHEAD section; **G4** zone boundaries → live display
  zone words. (G3/G4 are cuttable to post-beta if timeline demands — the
  surfaces have designed honest-absent states.)

### P4 — Beta hardening (app side)
- **Auth decision** (Bart rules, see Decisions below): ship stubbed
  (labeled dev-entry) vs. real email-code service. The boundary copy is done;
  only the verification is stubbed.
- Notification permission flow polish (in-context ask — BS-012 §Scope).
- App icon + launch screen from brand assets (logo on transparent, the
  splash defect already fixed).
- App Store privacy labels drafted FROM the sovereignty copy — "data not
  collected" claims must match the mechanism exactly (Design writes these
  as a BS; they are marketing-legal surface).
- Crash/error surfaces: every engine `Policy`/`Input` error renders the
  engine's words, calm — sweep for raw exception toasts.

### P5 — TestFlight
Build number stamping (already have BUILD_SHA discipline) · TestFlight
group (team + first external athletes) · feedback channel: a "Send
feedback" row in You (mailto or TestFlight native — decide in P4) ·
beta welcome note written from the promise copy.

## Cut line (explicitly OUT of beta — designed, waiting)
Density dial / Make-It-Yours full module system (partial exists:
words/numbers pref) · wrist + Live Activity (needs G4) · forward horizon
(needs G3, unless P3 lands it) · Strava/Garmin/Polar platform sync ·
real Apple Sign-In (unless P4 auth decision says otherwise) · marketing
landing deploy (separate track, not app-gated).

## Decisions Bart owes (everything else proceeds without him)
1. **Auth for beta:** stubbed-labeled or real email code? (Real = external
   service — the only piece that can't be built in-repo.)
2. **G3/G4 in or out** of the beta window?
3. **Target date** for TestFlight upload — sets how hard P3 gets cut.

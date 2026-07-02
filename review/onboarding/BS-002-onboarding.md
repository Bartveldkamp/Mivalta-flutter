STATUS: SPEC v3 (2026-07-03) — BART'S DEVICE REVIEW: fewer screens, explain-why
everywhere, richer devices step. v3 deltas below are binding; v2 engine-contract
rules all still hold.
# BS-002-onboarding — Build Spec: Onboarding intake (phase 1.3)

## ▸ v3 — Bart's witnessed-intake corrections (2026-07-03)

**1. Condense to 6 screens.** v2's 9 taps feel like an interrogation. New flow:
- **1 · Promise** (unchanged) + one added line at the end of the sub, bolded:
  "Nothing you enter here — or ever — leaves your phone. No server, no cloud.
  MiValta cannot read it."
- **2 · Your sport** (single: Running / Cycling; unchanged from v2).
- **3 · Your aim** — aim options AND the detail toggle on ONE screen: aim rows on
  top, then a slim divider, then "How should MiValta talk to you?" with the two
  detail options as compact rows.
- **4 · About you** — ONE scrollable screen: Age bands · Sex · Level · Years ·
  Weekly hours (all tap-bands, grouped with section labels). Screen intro (small,
  muted, under the title): "Five quick facts — they set your starting zones and
  how hard MiValta lets a day be. All of it stays on this phone."
  Sex sub-line (G9 unchanged): "Used only on-device, to set heart-rate zones."
- **5 · Your numbers, if you have them** (anchors, conditional per sport) — must
  EXPLAIN itself:
  - Running title: "Your running threshold" · intro: "If you know your threshold
    pace — the fastest pace you could hold for about an hour — MiValta sets your
    training zones from day one. From a recent race or test is perfect."
  - Cycling title: "Your FTP" · intro: "If you know your FTP from a test or a head
    unit, MiValta sets your power zones from day one."
  - Both: the "I don't know" chip stays prominent; picking it shows one reassure
    line: "MiValta will find it from your first sessions."
- **6 · Your data sources** (replaces "gear") — see §2 — then Payoff (unchanged).

**2. Devices step becomes actionable, not a quiz.** Title: "Where your data comes
from". Intro: "Connect a source and MiValta reads sleep, heart rate and workouts
automatically — on the phone, never through our servers."
- **Connect now · Apple Health** — primary row with a Connect button that fires the
  real HealthKit permission flow (the `health_ingest` service that Today's cards
  already read from). State after grant: "Connected ✓". Declining is fine — row
  shows "Not now".
- **Platforms · Strava / Garmin / Polar** — listed as rows with honest state
  chips: `coming soon` (muted, not tappable-dead: tapping shows one line "Platform
  sync is on the roadmap — your watch's data already arrives via Apple Health").
  DO NOT fake an OAuth flow. Logged as **GAP-001 §G10** — platform sync needs an
  ingest design that honours sovereignty (their cloud → phone; nothing of ours out).
- **No gear quiz.** The watch/ring/strap chips are DELETED — connected sources make
  the question redundant; source tiers already classify what arrives.
- Footer (every data screen, small, muted): "On this phone. Never on a server."

**3. Sex stays Female/Male in beta** — engine contract (G9). The explain-line above
is the mitigation; G9 remains routed to Bart for the engine-side fix
(`sex: null` → neutral zone defaults) if wanted.


**Sits between Auth (1.2, DR-015 open) and Today.** Branch: `feature/onboarding`.
**Design refs:** `vision/Onboarding.html` (canonical flow — click through it) ·
`vision/Calibration-LearningYou.html` (the honesty frame) · SR-001 §SR1-14 (the payoff
moment). **Engine:** `build_onboarding_profile(inputs_json)` — PURE TRANSPORT (FL-16):
Dart marshals RAW answers, the ENGINE derives goal_class/meso/anchor gating. The client
computes nothing. Then `write_profile_to_vault` + `construct_engines_fresh` (the
existing post-onboarding path — api.rs PR-F tests show the exact round-trip).

---

## ▸ v2 — THE ENGINE CONTRACT (verified in gatc-ffi/src/lib.rs `OnboardingInputs`)

Required fields — serde REJECTS the payload if any is missing:
`athlete_id` (client UUID) · `age` i32 · `sex` "male"|"female" (String, NOT nullable) ·
`level` ("beginner"|"novice"|"intermediate"|"advanced"|"elite") · `sport` — **SINGULAR**,
and FL-17 rejects anything but the advisor-supported set (**cycling, running**) at the
boundary · `goal_type` (knowledge-card vocab — fetch legal values at runtime via
`get_vocabularies(["goal_type"])`, map aim→goal_type, echo the mapping in the report) ·
`weekly_hours` f64 · `training_years` i32. Optional (`#[serde(default)]`): `threshold_hr`,
`ftp_watts`, `threshold_pace_sec_km`. Unknown extra keys are ignored — `detail`/`gear`
are app-side prefs, store them locally, never expect the engine to.

**Flow changes v1→v2:**
- ▸ Step 2 becomes **"Your main sport"** — SINGLE choice, beta set: Running / Cycling
  only. (The multi-sport "What moves you?" vision promise is engine-gapped — see
  GAP-001 §G8 — walking/hiking/stairs/strength would be REJECTED at Get Started by
  FL-17. Do not show chips the engine will refuse.) Copy: "More sports are coming —
  pick the one MiValta should coach first."
- ▸ Step 4 Basics gains two rows on a second screen (still tap-only): **level**
  (Beginner / Getting back / Trained / Advanced → beginner/novice/intermediate/
  advanced) and **experience** ("How long have you trained?" <1 / 1–3 / 3–10 / 10+ yrs
  → training_years 0/2/6/12) and **weekly hours** ("Time you can give it, most
  weeks" — 2–3 / 4–6 / 7–10 / 10+ → 3.0/5.0/8.5/12.0).
- ▸ Sex step: **Female / Male only** — the engine field is non-nullable and vocab'd
  male|female (sex drives HR-zone defaults + menstrual-cycle correction). "Prefer not
  to say" is DESIGN-DESIRED but engine-impossible today → logged GAP-001 §G9, routed
  to Bart. Until G9 closes, copy softens it: "Used only on-device, for heart-rate
  zones" — never ship a choice that errors.
- ▸ Anchors step condition keys off the SINGLE sport (cycling→FTP, running→pace).
- ▸ age band → representative int (25/35/45/55/65), sex lowercase — as C1 already fixed.
- ▸ `athlete_id`: reuse the auth session's UUID (or generate+persist one if pre-auth).

## Flow — 8 steps, tap-only, no free text

Screen chrome: progress dots top (step k of 8, `greenAccent100` for done), one
question per screen, Continue pinned bottom (52px, r14, mint), ghost Back above it
from step 2. Entrance per step: content fades/rises 300ms `standardEase` (respect
`disableAnimations`). No skipping forward; every step must satisfy `need()` before
Continue enables (disabled = 40% alpha, not hidden).

1. **Promise** (center layout): lock tile 72px r22 mint-14%, "Your body.\nYour data."
   `MivaltaType.titleXL`, sub "Everything is computed on your phone. We can't see
   it — and we built it that way. Let's set MiValta up for you." CTA "Get started".
2. **Sports** (multi-chip): "What moves you?" / sub "Pick everything you do — there's
   no wrong answer." Chips: Running, Cycling, Walking, Hiking, Stairs, Strength
   (icons per vision file). ≥1 required.
3. **Aim** (single-option rows): "What's your aim?" — Perform / Stay fit & healthy /
   A bit of both (exact copy + descriptors from vision file). Required.
4. **Detail** (single-option): "How much detail?" — "Just tell me what to do" /
   "Show me the numbers too". Sets coaching density. Required.
5. **Basics** (two single-choice rows on one screen): age band (18–29 / 30–39 /
   40–49 / 50–59 / 60+) and sex (Female / Male / Prefer not to say). Copy: "The
   engine needs two basics to read you correctly." Both required ("Prefer not to
   say" IS an answer).
6. **Anchors** (conditional — ONLY if sports include Running and/or Cycling):
   "If you know it" — optional FTP (cycling) / threshold pace (running) numeric
   entry, AND a prominent "I don't know" chip per anchor. Copy: "No idea? Perfect —
   most people don't. MiValta learns it from your sessions." **"I don't know" →
   null in inputs_json. NEVER 0, never a default.** (Engine zero-fabrication tests
   guarantee null anchors construct fine.)
7. **Gear** (multi-chip, optional): Watch / Ring / HR strap / None yet. "None yet"
   exclusive-toggles the others.
8. **Payoff** (center): the SR1-14 confirmation. Mini glow (150px, teal) with —
   detail=="numbers" → seeded readiness number 48px; else → "Good to go" 24px.
   Line per aim (exact strings in vision file source). Below: "This is your Today —
   tuned to your answers. Adjust it any time in You → Coaching style." CTA
   "Enter MiValta".

## Wiring (Step 8 Continue)
1. Marshal RAW answers → `inputs_json` (echo the exact JSON in the build report).
2. `build_onboarding_profile(inputs_json)` → profile JSON. On error: inline honest
   error card ("Something didn't take — try again"), log, do NOT route forward.
3. `write_profile_to_vault(profile, vaultPath)` → `construct_engines_fresh` (mirror
   the PR-F round-trip; athlete_id from the auth session).
4. Route → Today. Update splash routing: session+no-profile → THIS flow (replaces
   the Onboarding stub from BS-001-auth A2).

## Rules
- Tokens by name everywhere (`MivaltaType.*`, `MivaltaColors.*`, `MivaltaSpace.*`,
  `MivaltaRadii.*`) — no `GoogleFonts.inter(...)` inline (avoid DR-015 A4's slip).
- Chips/options: 44px+ hit targets, `aria-pressed` semantics via Semantics widgets.
- No fitness-test language anywhere. No "sync your data to get started". No tier
  names on screen (monitor/advisor/coach stays internal).
- Back preserves answers; killing the app mid-flow restarts at step 1 (no partial
  profile is ever written).

## Definition of done
1. `review/onboarding/BUILD-REPORT-onboarding-v1.md` — line 1 spec+SHA; echo one real
   `inputs_json` AND the returned profile JSON (redact nothing — it's synthetic);
   state splash-routing change; flag any stub.
2. Shots (SHA-stamped, `review/onboarding/`): `onb_<SHA>_promise.png` ·
   `_sports.png` · `_anchors-idk.png` (with "I don't know" selected) ·
   `_payoff-numbers.png` · `_payoff-words.png` (detail=words variant).
3. All 8 steps reachable and Back-navigable in one run.
4. Await DR — no merge.

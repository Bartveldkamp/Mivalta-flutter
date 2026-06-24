# MiValta — CONSOLIDATED BUILD BRIEF (2026-06-13)
**For the build session (Mac/terminal). Implement top-to-bottom; each item:
widget tests + `flutter analyze --fatal-infos` + screenshot all 4 states
(no-data / low-confidence / normal / red) → commit → push. Run on the iPhone
simulator after each section so the founder can see progress.**

Working rule (CLAUDE.md): the engine DECIDES, Flutter DISPLAYS. No thresholds/
math/fallback in Dart. No raw engine enums user-visible. Dark-first. Josi =
presenter, NO chat box / NO TTS. Tokens only. F1 copy locked.

Engine pin: `b603b5e`. Where a section needs FFI not yet in the shim, REGENERATE
FRB bindings (Mac), and CONFIRM the method exists at the pin — if not, re-pin and
say so before proceeding.

Detail specs (read alongside): `HOME_REDESIGN_BRIEF.md`, `JOURNEY_SPEC.md`,
`FOUNDER_FEEDBACK_2026-06-12.md` (the V2 adoptions formerly in
`NEXT_UPDATE_V2_ADOPTIONS.md` are now folded into §F below; original archived in
`docs/archive/`), `VAULT_DATAFLOW_AUDIT.md`.

---

## ORDER OF WORK

### A. Finish Today-screen polish (FOUNDER_FEEDBACK items 9–13, 20–24, 27–28)
Verify done / complete where missing:
- Kill the big green "+" FAB (9).
- Start-workout control: subtle/refined, **top-LEFT** beside the centered
  MiValta title (title stays centered) (10, 20).
- **Weather**: ONE condition icon **+ temperature** right of the title; tap →
  **glassy, swipeable 7-day overlay** over the home (home visible beneath; glass
  per UI_UX §15.5: one surface, no nested/animated blur, solid fallback). Remove
  any weather tile (11, 18, 21, 24). WeatherKit approved (OS-level exception —
  document in CLAUDE.md rule 6).
- F1 "why" = the plain ~28-day trust story (13, 22) — already via `trust_story.dart`; verify.
- Today-facts tiles user-configurable (12).
- Start-workout flow: **sport picker as a SCROLLER** (running/walking/cycling
  variants → activity_type; PROFILE sport stays cycling/running, FL-17) + show
  connected devices, honest states (23, 27).
Acceptance: matches the screenshots the founder approved; 4-state notes.

### B. ⭐ VAULT-FIRST INGEST FIX (priority plumbing — see VAULT_DATAFLOW_AUDIT.md)
The gap: auto health-sync normalizes → HMM → **discards** the biometrics; the
vault never stores them, so HRV/RHR/sleep panels are empty for synced users, and
the raw vendor payload (Oura) is lost. Engine is READY (`write_biometric`,
`write_raw_observation`, `mark_raw_observation_processed`,
`read_raw_observations_*` all exist + tested) — this is WIRING.
1. Flutter shim (`rust/src/api.rs`): bind `write_biometric`,
   `write_raw_observation`, `mark_raw_observation_processed`,
   `read_raw_observations_by_type`, `read_raw_observations_by_activity`. FRB regen.
   (Confirm each exists at pin b603b5e; else re-pin + note.)
2. `health_ingest.dart` per-day loop, VAULT-FIRST order:
   a. `write_raw_observation(vendorJson, date, source)` — raw, before processing
   b. `normalizeObservation` → `write_biometric(normalized RHR/HRV/sleep[/steps])`
   c. `processObservation` (HMM) → `mark_raw_observation_processed(normalizedJson)`
   Idempotent per (date, source). Manual entry: same vault-first path.
Acceptance: after a sim sync (or seeded Health data), `read_biometric_history`
returns rows AND `raw_observations` is populated; data survives restart; export
includes it. THIS UNBLOCKS the Journey biometric pillars.

### C. JOURNEY screen — the personalized depth page (JOURNEY_SPEC.md)
Build the ✅ BUILD-NOW pillars + the configurable (show/hide) overview library:
- Load-vs-recovery divergence (readDailyLoads + readReadinessHistory +
  fitnessSeries incl. **form/freshness**); per-session detail (stored
  VaultActivity); **EF + HR-recovery adaptation trend**
  (readMetricAcrossActivities); calibration arc ("learning you — day X").
- Biometric overviews (HRV / RHR / sleep-hours) — now FILL because of (B);
  honest-empty before any data.
- Configurable tiles (user chooses what shows); "Ask Josi to find X" = bounded
  cards+chips over CONFIRMED-EXISTS data only (no free chat).
- Do NOT build 🔴 items (sleep stages*, steps*, pace bests, baseline-evolution
  markers) — *stages/steps become available once (B) persists raw; otherwise
  honest absence. Mark them coming-soon, never faked.

### D. Settings (FOUNDER_FEEDBACK item 25)
- Metric/imperial toggle (display formatting only; engine stays SI).
- Privacy & Data INSIGHTS: source overview + tier badges (`buildSourceOverview`),
  on-device proof, export (encrypted), granular revoke, delete-everything (receipt).

### E. Advisor — cards + chips (FOUNDER_FEEDBACK item 26, 8)
Confirm lead-with-A / offer-C; add bounded reply CHIPS (Less time · Different
sport · Feeling worse · Feeling better → one follow-up level → recompute → card
updates). Chips map to existing `recommend_workout` optional params (no engine
change). NO input bar. "Load with options" variety = rust-side; UI scales.

### F. V2 adoptions (folded 2026-06-20 from the archived NEXT_UPDATE_V2_ADOPTIONS.md)
Airplane-mode onboarding moment (copy = founder review); rest-as-content;
post-workout verdict-first; verdict→reasons→data audit; ONE daily local
notification (needs a local-notifications dep — flag before adding).

These five (the A1–A5 set) come from the 2026-06-12 next-gen vision review
(founder-approved: *"take what we are able to use and makes us better, and
implement it now, for next update."*). **Locked beta invariants HOLD**: no chat
box, no TTS, number-as-hero, engine decides / app displays. Execution: A1–A4 are
Flutter display work (widget tests per rule 8); A5 needs the notifications
dependency (Mac). Sequence AFTER the feedback-doc items 1–2–6–7 and the ingest wire.

**Captured but NOT this update (post-beta / Coach tier):**
- Live session surface (full-screen zone color, one chosen number, cues).
- Plan as recovery canvas + drag-session → downstream state re-predicts (engine
  replan/predict already exist).
- Conversation layer everywhere = Coach tier, after the bounded voice ships.
- Ambient no-number state surface = §17 north star (post-MVP, already doc'd —
  see `DESIGN_BUILD_SPEC.md` §7).

**Explicitly REJECTED for beta (do not build):**
- Persistent chat input on every screen (violates the locked no-chat invariant).
- Removing the readiness number (violates the number-as-hero founder decision).
- The review's palette refs (#1DBF60 / #007166) — old Okapion token set; use ours.

---

## COMPANION ENGINE BRIEFS (rust-engine — NOT this session; queue separately)
1. `observation_days` field (clean "day X").  2. Persist `rpe_hr_drift_pct`
per session.  3. `get_state_history(days)`.  4. Shim/expose `forecast_states`
+ `estimate_recovery` (forward-looking surfaces).  5. Baseline-evolution
weekly snapshots (Tier-3 moat).  6. Persist steps + sleep stages columns.
7. OS-keystore provider for the vault key (pre-launch security hardening).
8. Re-eval the slot-filling Josi checkpoint (SLOT_EVAL/POLISH briefs).

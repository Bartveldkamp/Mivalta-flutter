# Next-update adoptions — from the 2026-06-12 next-gen vision review (founder-approved)

Founder: "take what we are able to use and makes us better, and implement it
now, for next update." Locked beta invariants HOLD: no chat box, no TTS,
number-as-hero, engine decides / app displays.

## A. Build in the NEXT UPDATE (display-only, no founder decision needed)

1. **Airplane-mode privacy moment** (onboarding, final step): one screen —
   "Turn on airplane mode. Watch: the engine still works. Your data never
   leaves this phone." Render a live readiness compute as proof. Copy goes
   through founder review before lock. (Best privacy UX in the review.)
2. **Rest with equal visual weight**: a rest/recovery option or rest day
   renders as a full styled card — same prominence as a workout. Rest is
   content, not absence. (Advisor cards + session widget rule.)
3. **Post-workout verdict-first**: report card reorders to verdict line on
   top ("Executed as intended — cost ~a day of recovery" — engine prose),
   stats collapsible beneath. Existing fields, new hierarchy.
4. **Verdict → reasons → data, enforced**: the why-panel always shows the
   4-axis contributions (reasons) BEFORE any raw trend link. Pin as a design
   rule in DESIGN_BUILD_SPEC; audit detail screen ordering.
5. **One daily coach's-text notification** (local only, no cloud): morning
   state line from the engine, written like a coach's text. Needs
   local-notifications dep — Mac task; default ON, single, never more.

## B. Post-beta / Coach tier (captured, NOT next update)

- Live session surface (full-screen zone color, one chosen number, cues).
- Plan as recovery canvas + drag-session → downstream state re-predicts
  (engine replan/predict already exist).
- Conversation layer everywhere = Coach tier, after the bounded voice ships.
- Ambient no-number state surface = §17 north star (post-MVP, already doc'd).

## C. Explicitly rejected for beta

- Persistent chat input on every screen (violates locked no-chat invariant).
- Removing the readiness number (violates number-as-hero founder decision).
- Their palette refs (#1DBF60/#007166) — old Okapion token set; use ours.

Execution: items A1–A4 are Flutter display work (Mac or remote session,
widget tests per rule 8); A5 needs the notifications dependency (Mac).
Sequence AFTER the current feedback-doc items 1–2–6–7 and the ingest wire.

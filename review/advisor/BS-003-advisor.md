STATUS: SPEC — ready to build (large gate; independent of BS-001-engine)
# BS-003-advisor — The session offer (Advisor A/B/C) + Today entry

**Phase 2.2 — the core loop's second screen.** Branch: `feature/bs003-advisor`.
**Design refs:** `vision/Screen-CoreLoop.html` §2.2 (canonical layout — read it over
the bridge) · `vision/Advisor-Voice.html` (tone) · DIRECTION-001 (no salience changes
here). **FFI (all live today, verified in api.rs):** `recommend_workout(handle, mood?,
equipment?, terrain?)` → WorkoutOptionData[] JSON · `realize_advisor_line` (already on
Today) · existing `lib/models/workout_option.dart` parser (reuse — it is the tested
seam; extend, don't fork).
**Scope boundary:** the OFFER only. Selecting an option shows its structure and marks
intent. NO live recording, NO session player — that's the next gate (needs engine G4).

---

## 1 · Today entry — the "Suggested workout" card becomes real
- With options available: card shows option A's `title`, zone (ENERGY NAME FIRST —
  "Tempo · Z3", never bare "Z3"), `durationMin`, and `focusCue` as the one-line
  preview. Tap → Advisor screen. Chevron affordance, whole card 44px+ tappable.
- Day-zero / engine returns no options: keep the existing honest-absent copy
  ("No suggestion yet"). REPLACE the current sub-line ("Complete more workouts to
  unlock AI suggestions" — gamified unlock framing, off-voice) with:
  "MiValta suggests sessions once it's read a few of your days." Muted, no CTA.
- Calibration window: if `personalization_diagnostics` says still-learning, the card
  may show options but carries the small "learning you" qualifier line.

## 2 · Advisor screen — bounded, recommended, led
App bar: back arrow + "Today's options" (`MivaltaType.titleM`).

**Quick-adjust chip row** (horizontal, under app bar):
- Chips map EXACTLY to the FFI params — mood / equipment / terrain. Selected chips
  re-call `recommend_workout` with the new values; options re-render. This is
  RE-RESOLVE, never client-side filtering or editing of options.
- Legal values: fetch via `get_vocabularies` if the tables carry them; otherwise
  echo the engine-accepted strings you verify in the build report (creed rule 2 —
  both contract ends; do NOT invent labels).
- Chip visual: existing small-chip pattern (44px, selected = stateProductive 15%
  fill + border, per onboarding chips).
- Re-resolve in flight: options dim to 60%, one small progress indicator; no skeleton
  theatre. Error: inline honest card "Couldn't re-plan — try again", options revert.

**Option cards (A / B / C — exactly what the engine returns, max 3):**
- Card anatomy (top→bottom):
  1. Zone chip: energy name + code ("Tempo · Z3") — colour from the state ramp
     token for that zone family; name first is a LOCKED voice rule.
  2. `title` (`MivaltaType.cardTitle`) + expression badge when present (engine's
     `expression.title`, e.g. "Hill Fartlek" — small outlined chip).
  3. `why` — the engine's one-liner, verbatim (`textSecondary`).
  4. Specs row (flex, gap): duration ("64 min") · target watts OR pace when present
     ("238 W" / pace mm:ss/km) · tags as muted words. Absent target → simply absent,
     never "—" here (a missing target is normal, not a data gap).
  5. `zonePurpose` — card-sourced prose, `MivaltaType.small` muted, collapsed to
     2 lines with expand.
- Option A leads with a "Recommended" tag (stateProductive). The easiest option
  (engine's lowest-intensity) closes the list framed as legitimate: section footer
  line "…or take it easy — that's a real option too." No option is ever styled as
  a downgrade.
- Tap an option → detail state: full `structure` rendered (warmup / main set with
  cues / cooldown, from the JSON structure object — echo its REAL shape in the
  report before building the renderer), plus a primary button "This one today".
- "This one today" → persist choice locally (`chosen_option_<date>`), return to
  Today; the Suggested-workout card now shows the chosen session with a "chosen"
  tick. NO recording starts. Re-entering Advisor shows the choice, changeable.

## 3 · States (all designed, all honest)
- **No options** (engine returns empty/error): full-screen honest state — "Nothing
  to suggest yet" + the learning line; never a fabricated default session.
- **Degraded** advisories from the engine (safety[] on the realized line): render
  above the options in `stateAccumulated` — steady, not alarm.
- **Reduced motion:** entrance/stagger instant; re-resolve dim still allowed
  (opacity is not motion).

## 4 · Voice + token rules (binding)
- Zones: energy name first, code second — EVERYWHERE (SR1-07 ruling).
- Effort noun is "Load" if any cost language appears — never "strain".
- Tokens by name only; new tokens (if any) added to tokens.dart name-exactly and
  echoed in the report. No raw Colors.*, no magic numbers (creed rule 7).
- Copy: no gamification ("unlock", "streak"), no exclamation marks.

## Definition of done
1. `review/advisor/BUILD-REPORT-advisor-v1.md`: line 1 spec+SHA; echo ONE real
   `recommend_workout` JSON (seeded via DemoSeeder — say so), the REAL `structure`
   shape, the chip→param vocabulary table you verified, any new tokens with values.
2. Shots (SHA-stamped filenames, from the seeded build): `adv_<SHA>_options.png` ·
   `adv_<SHA>_adjusted.png` (chip selected, re-resolved) · `adv_<SHA>_detail.png` ·
   `adv_<SHA>_chosen-today.png` (Today card with tick) · `adv_<SHA>_absent.png`.
3. Today card day-zero copy change included and shot if seedable.
4. Parser: extend `workout_option.dart` only additively (structure renderer parses
   what the echo proves exists); unit test for the chip→param mapping.
5. Mirror this spec into repo `review/advisor/` in the same push (repo-sync rule).
6. Await DR — no merge. This branch stacks BEHIND the MERGE-001 queue.

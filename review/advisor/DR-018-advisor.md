STATUS: ACTIVE — round 1 (source review @ 16ba8b4; engine truth @ main 61c0e8f)
# DR-018-advisor — BS-003 Advisor A/B/C · Round 1

Overall: strong build — screen anatomy, re-resolve flow, honest states, persistence,
recommended/chosen badges, footer line, no-gamification copy all match BS-003. But
the exact failure the spec's §2 warned about ("do NOT invent labels") happened, and
it's a crasher.

## A1 ● BLOCKER — mood chip values are ILLEGAL; engine PANICS on them
Shipped chips: `fresh` / `normal` / `tired`. Engine truth
(`gatc-advisor/src/workout_suggester.rs`): legal moods are **`fun` / `easy` /
`hard` / `mix`** — the coach_cues prefix lookup PANICS on any other value
("missing mood='…' — Known moods: fun / easy / hard / mix", and the
`mood_prefix_panics_on_unknown_mood` test proves it). Tapping ANY shipped mood chip
crashes the engine call. Fix:
- Values: `fun` / `easy` / `hard` / `mix`, exactly.
- Label: not "Feeling" — engine mood is a WANT, not an energy state. Use
  "In the mood for": Fun · Easy · Hard · Mix.
- Unit test asserts the four legal values verbatim.

## A2 ● BLOCKER — equipment value `indoor` does nothing (silent no-op)
Engine does substring matching on equipment: `contains("outdoor")` → outdoor tag;
`contains("trainer")` or `contains("treadmill")` → indoor tag. The string `indoor`
matches NEITHER — the chip silently no-ops (a lie in the UI). Fix:
- Cycling: `outdoor` / `trainer`. Running: `outdoor` / `treadmill`. Labels can read
  "Outdoor" / "Indoor" but the SENT VALUE must be trainer/treadmill per profile
  sport (profile is available via ProfileService).
- Terrain: `flat` / `hilly` are engine-real; `trail` also is (`trail-friendly`
  tag) — add Trail as a third chip.

## A3 ◐ — zone→name map now conflicts with Today's
Advisor's map (Z3 Tempo · Z4 Threshold · Z5 VO2max) MATCHES the engine's zone
vocabulary (workout_suggester ZONE tags). But `today_screen.dart`'s `_DecisionChip`
still says Z4 Tempo · Z5 Threshold · Z6 VO₂max — two contradictory vocabularies in
one app. Fix: extract ONE shared `zoneDisplayName()` (advisor's mapping is the
correct one), use it in both screens; `_DecisionChip`'s map is corrected by this.

## A4 ◐ — `zonePurpose` truncation
Spec: collapsed to 2 lines with expand affordance. Shipped: maxLines 4, ellipsis, no
expand. Make it 2 + tappable "more".

## A5 ○ — verify on Mac (blocked items, agreed)
Structure renderer placeholder, screenshots, real-binding run — per build report,
fine. When echoing the real structure JSON, ALSO echo one full option with
`option_id` so the persistence key is verified against reality.

## Witnessed good
Spec mirror ✓ · chips re-resolve not filter ✓ · error reverts options ✓ · dim 60%
overlay ✓ · honest-absent copy verbatim ✓ · "…or take it easy" footer ✓ · A-leads
Recommended ✓ · chosen tick ✓ · SharedPreferences key per spec ✓ · safety advisories
in stateAccumulated ✓ · scope boundary held (no recording) ✓.

## To close
A1 + A2 fixed (with tests) + A3 unified → push → Design re-reads source → Mac
captures per BS-003 DoD.

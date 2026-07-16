# Design ↔ Engine Data Contract

**Purpose.** This is the interface between the *data-truth* layer (what the Rust
engine actually emits across the FFI, owned by the engine/wiring session) and the
*visual* layer (screens/widgets, owned by the design session). Bind every surface
to the real engine fields listed here. The golden rule, from the Quality Charter:

> **Never render a value the engine didn't produce.** Missing input → honest
> absence (`--` / a named empty state / nothing), or the locked F1 copy. Never a
> placeholder, never a fabricated default.

If a field you want isn't in this doc, it either isn't emitted yet (say so, don't
invent it) or needs an engine change — raise it, don't fill the gap in Dart.

---

## 1. The suggested-workout surface (`WorkoutOptionData`, from `AdvisorEngine`)

Emitted as a **bare JSON array** of options; parse option A (first) via the shared
`WorkoutOption` model. Every field below is real engine truth:

| Engine JSON field | Meaning | Dart status |
|---|---|---|
| `metabolic_level` | Canonical level id: `aerobic_base` / `aerobic_endurance` / `tempo` / `threshold` / `vo2max` / `anaerobic_neuro` (X1.1, Entry AD). The level leads; zone is its detail. | The athlete headline now rides on **`coach_sentence`** (below), the ENGINE-COMPOSED sentence — the raw `metabolic_level` field is not parsed standalone. See §2 (RESOLVED). |
| `coach_sentence` | **The headline (engine #411).** Full LEVELS-LAW sentence: level leads → purpose → nested code → real targets → feel cue. Empty `""` when no main set. | Parsed (`WorkoutOption.coachSentence`, `""`→null = honest absence) + rendered **verbatim** in advisor detail. |
| `zone` | Derived fine dial-position: `R`/`Z1`..`Z8`. | Parsed (`workout_option.dart`). |
| `target_watts` | Derived power target (present when athlete has FTP). | Parsed + shown on `advisor_screen`. |
| `target_pace_mss` | Derived pace "M:SS" (present when athlete has threshold pace). | Parsed + shown on `advisor_screen`. |
| `structure.main_set.hr_pct_min/max` | HR as % of threshold — **always present**. | Nested; only `cue_start` read today. |
| `structure.main_set.hr_bpm_min/max` | Absolute HR bpm (present when threshold_hr known). | **NOT parsed yet** — add `hrBpm` when you build the HR anchor slot. |
| `structure.main_set.watts_min/max`, `pace_sec_km_min/max` | Per-rep target bands. | Nested; not surfaced. |
| `zone_purpose` | Card prose ("what this zone trains"). Empty ⇒ honest absence. | Parsed + shown. |
| `expression` | Alt presentation (e.g. "Hill Fartlek"). `None` ⇒ no badge. | Parsed + shown. |
| `why` | One-line rationale. | Parsed. |

**The unified headline you want** ("Threshold — Z4 — 250 W / 158 bpm") is
buildable from: `metabolic_level` (name) + `zone` (detail) + `target_watts` /
`hr_bpm`. Two of the four already flow; `metabolic_level` and `hr_bpm` need the
parse fields added *at the moment you build the slot* (so they aren't dead code).

## 2. Headline source — RESOLVED by the LEVELS LAW (Entry AP + #406/#411)

The athlete-facing headline is the **engine-composed `coach_sentence`**, rendered
verbatim — the engine owns the wording (Law 2), Dart renders, never re-derives.
For the compact **decision chip**, `zone_names.dart` (LOCKED) returns the level
name with the zone code **nested behind it** — e.g. `"Endurance · Z2"` — the
communication shape the founder ruled canonical (level leads; the code is a
secondary detail, never alone). So both surfaces are covered without a Dart-side
re-derivation of the headline: the sentence comes whole from the engine; the chip
is just the LEVELS-LAW label. No open decision remains here.

## 3. The readiness surface (`readiness_indicator`, `get_readiness`, `state_advisory`)

| Engine field | Meaning | Dart status |
|---|---|---|
| `indicator.level` | Readiness band (green/yellow/orange/red). | Parsed → `data.level`, **not displayed** (GlowHero colors off fatigueState instead). |
| `indicator.contributions` | **4-axis "why"** breakdown — the whole point of the indicator. | Parsed → `data.contributions`, **not displayed**. |
| `state_advisory.confidence_advisory` | Confidence caveat text. | Parsed → `data.confidenceAdvisory`, **not displayed**. |

These are engine truth already crossing the FFI and dropped at the screen. Surface
them — the contributions breakdown especially is the athlete-facing explanation.

## 4. Honest absence — the locked rules

- **F1 no-data copy (LOCKED, verbatim):** `"We need more data to predict recovery."`
  Lives in `lib/copy/f1.dart`. It is **not currently wired** to the live home —
  the no-data state shows a hardcoded `'Learning'` label instead. Wire F1 to the
  readiness headline's no-data state.
- **Module cards** already have a good `_HonestAbsence` widget (label + unlock
  action) — reuse that pattern for every empty state.
- **Source-tier colors (LOCKED):** Medical `#2BD974`, Device `#00C6A7`, Partial
  `#E6872F`, Manual `#878C8C` — use the token, never hardcode.

## 5. Fabrications just removed (for awareness)

The engine/wiring session fixed two on `today_screen`:
- **Load card** no longer invents a `600` ceiling when ACWR isn't ready — it shows
  "Load range still building" until the engine provides a real chronic-load
  baseline. If design wants to show the raw acute load number in that window,
  render it **without** a range bar (no fabricated proportion).
- **Weather** no longer renders a `"Sunny 18°"` placeholder — absent weather
  renders nothing (Rule 6).

Please don't reintroduce either pattern; bind to the real field or show absence.

## 6. Where nothing exists yet

There is no `MainSet` or `SessionIntent` Dart model — `workout_option.dart`
inlines a partial `structure` read. A proper unified workout view (level → zone →
HR/watt/pace anchors, plus per-rep interval structure) wants a real `MainSet`
model mirroring `gatc-types::MainSet`. Add it when the detailed workout view lands.

---

*Engine field names verified against `mivalta-rust-engine/crates/gatc-types/src/lib.rs`
(`SessionIntent` / `MainSet` / `WorkoutOptionData`). The current Flutter engine
pin (`rev 5849920`, registry v2.44) emits `metabolic_level` and the composed
`coach_sentence` (#411) — both flow today; no re-pin pending for these fields.*

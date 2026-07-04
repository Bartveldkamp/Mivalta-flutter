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
| `metabolic_level` | **The headline.** Canonical level id: `aerobic_base` / `aerobic_endurance` / `tempo` / `threshold` / `vo2max` / `anaerobic_neuro` (X1.1, Entry AD). The level leads; zone is its detail. | **NOT parsed yet** — add `metabolicLevel` to `WorkoutOption`/`HomeData` when you build the headline slot. See §2. |
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

## 2. Decision needed: headline source — engine `metabolic_level` vs `zone_names.dart`

Today `zone_names.dart` (LOCKED, DR-018 A3) derives the energy name from `zone` in
Dart: `Z4→Threshold`, `Z5→VO₂max`, `Z6→Anaerobic`, `Z7→Neuromuscular`, `Z8→Max power`.
The engine's authoritative `metabolic_level` **merges** Z6/Z7/Z8 into one
`anaerobic_neuro` level. So the two disagree on the anaerobic band (Dart shows 3
distinct names; the engine shows 1 merged level).

**Pick one source of truth for the headline** (founder/design call):
- **(a) Engine `metabolic_level`** — authoritative, matches the unified model
  everywhere, but coarser at the top end (one "Anaerobic/Neuro" name).
- **(b) Keep `zone_names.dart`** — finer zone names, but it's a Dart-side
  re-derivation of a value the engine owns (mild architecture drift).

Recommendation: bind the **name** to engine `metabolic_level` (single source of
truth), and if you want the finer Z6/Z7/Z8 distinction, show the *zone* label
alongside it (`Anaerobic · Z6`). That keeps the engine authoritative and still
gives the granularity.

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
(`SessionIntent` / `MainSet` / `WorkoutOptionData`). Note: `metabolic_level` is
emitted by the engine only from the X1.1 revision onward — the current Flutter
engine pin predates it, so it parses empty until the engine is re-pinned. Re-pin
is a `cargo update` + xcframework rebuild, no FRB regen (additive JSON field).*

# MiValta — Beta Build Pack (PR-B → PR-F)

> **What this is.** A sealed, schema-verified plan to take the current
> foundation (PR-A: re-pin + bindings + continuity, on branch
> `claude/clever-noether-1hhfw`) to a **working Beta** of the MVP-1 app, built
> to `MIVALTA_FINAL_SPEC.md` v1.4 + `UI_UX_DIRECTION.md` v1.1 +
> `MVP1_BUILD_BRIEF.md`. Scope: **MONITOR + ADVISOR (suggestions) + grounded
> Josi (LLM last)**, 100% continuity, encrypted-at-rest, zero fabrication.
>
> **Who executes.** The Mac Claude Code (it has the Flutter/Android toolchain).
> Authored by the orchestration seat, which **cannot compile, FRB-regen, or run
> Flutter** — so:
>
> ⚠️ **HONESTY FENCE.** Every *binding name* and *JSON field name* in this pack
> is **verified** against the live engine (`rust_engine.dart` facade +
> `gatc-viterbi`/`gatc-ffi` source + `FRONTEND_API_GUIDE.md`). Any **Dart code**
> here is **reference** — it was not compiled or run. The Mac MUST
> `flutter analyze` + `flutter test` + build the APK and fix nits before
> treating anything as done. Nothing here is "verified working UI."

---

## 0. FIRST: fix the PR-A readiness headline bug (verified)

`lib/screens/readiness_screen.dart` currently parses the hero wrong:

```dart
// WRONG (PR-A): field 'blend' does not exist; value is a float, not int
d.readinessBlend = indicator['blend'] as int?;
```

The engine serializes `ViterbiEngine::readiness_indicator()` from
`ReadinessBlendResult` (`crates/gatc-viterbi/src/readiness_blend.rs`):

```
{ "score": f64, "level": <ReadinessLevel>, "confidence": f64,
  "contributions": [ { "name": str, "raw_score": f64, "weight": f64, "weighted": f64 }, ... ] }
```

So the headline number is **`score`** (a float), not `blend`, and must be read
as a number:

```dart
// RIGHT
final num? score = indicator['score'] as num?;        // e.g. 72.4
d.readinessScore = score?.round();                    // display rounded
d.readinessLevel = indicator['level']?.toString();    // verbatim
d.confidence     = (indicator['confidence'] as num?)?.toDouble();
```

> `level` is the `ReadinessLevel` enum — render it **verbatim** (don't hardcode a
> mapping; confirm its serialized spelling on first run and only humanize at the
> label layer, never recompute). Per the guide: Green ≥70 / Yellow 55–69 /
> Orange 40–54 / Red <40 — but the **engine** decides the level; the UI never
> derives it from the score.

This bug carries into PR-B if not fixed, because PR-B reuses the same parse.

---

## 1. Verified binding surface (what you can call today — PR-A's `RustEngineBinding`)

All confirmed present in `lib/rust_engine.dart`:

| Purpose | Dart facade method | Returns (JSON unless noted) |
|---|---|---|
| Construct (first run) | `constructEnginesFresh(profile, tables, vaultPath)` | `EnginesHandle` |
| Construct (restore) | `constructEnginesFromState(profile, tables, vaultPath, viterbiStateJson)` | `EnginesHandle` |
| Has persisted state? | `hasPersistedState(profile, vaultPath)` | `bool` |
| Read persisted state | `readPersistedState(profile, vaultPath)` | `String?` |
| **Readiness hero** | `readinessIndicator(h)` | `{score:f64, level, confidence:f64, contributions:[{name,raw_score,weight,weighted}]}` |
| Readiness score+advisories | `readinessScore(h)` | `{score:int, advisories:{last_observation_at, recommendations:[]}}` |
| Fatigue state | `viterbiFatigueState(h)` | `{state:"Recovered|Productive|Accumulated|Overreached|IllnessRisk", ...}` |
| Zone cap | `zoneCapWithAdvisories(h)` | `{zone:"Z8|Z5|Z2|REST", advisories:{...}}` |
| Persist state | `saveState(h)` → `writeViterbiState(h, stateJson)` | — |
| Readiness trend | `readReadinessHistory(h, days)` | series JSON |
| Workout suggestions | `recommendWorkout(h)` | `[{title, zone, ...}]` |
| Source tier | `lastObservationSourceTier(h)` | `"Medical"|"Device"|"Partial"|"Manual"|null` |
| Dashboard (3-zone) | `getDashboard(h)` / `getStateWidget(h)` / `getSessionWidget(h)` / `getContextWidget(h)` | display payloads (render verbatim) |
| Normalize vendor obs | `normalizeObservation(h, vendor, json)` | UniversalObservation JSON |
| Classify source | `classifySource(h, source)` | `{tier, tier_code, confidence_acceleration}` |
| Sources overview | `buildSourceOverview(h, sourcesJson)` | `{sources:[...], primary_sources:{...}}` |
| Manual biometric (placeholder) | `writeMinimalBiometric(h, source, isoDate, restingHr)` | — |

**Not yet bound (needs a shim addition in PR-D):**
`ViterbiEngine::process_observation(json)` — it EXISTS in the engine
(`gatc-ffi/src/lib.rs:425`) but PR-A didn't bind it. This is the call that feeds
a real observation into the HMM so readiness/zone/advice move off the
no-data state. See PR-D.

---

## 2. The honest data-flow (why the app shows "We need more data" today)

```
device / manual → normalizeObservation (vendor JSON → UniversalObservation)
               → process_observation(obs)   [HMM updates readiness]   ← NOT bound yet (PR-D)
               → write_biometric / write_raw_observation (persist)
               → saveState → writeViterbiState (continuity)
               → readinessIndicator / dashboard widgets (DISPLAY)
```

With no `process_observation` path wired and no real observations, the engine
honestly returns the no-data state (F1 copy "We need more data to predict
recovery."). That is correct behaviour, not a bug. **PR-D is what makes advice
appear.** PR-B/PR-C make the display beautiful and correct on top of whatever
data exists.

---

## 3. PR-B — Three-zone PULL home (the headline screen)

**Goal.** Replace the current list-style `ReadinessScreen` default with the
three-zone PULL home from `UI_UX_DIRECTION.md` v1.1: dark-first, calm, honest,
agency. Present — don't push.

**Zone mapping (DashboardEngine was purpose-built for this):**
- **Zone 1 — State (hero):** `readinessIndicator` → a calm readiness ring
  (score in the center, `level` as the ring color/label, `confidence` as a thin
  sub-arc) + `getStateWidget` prose rendered verbatim + `viterbiFatigueState`
  badge ("Illness risk", never "IllnessRisk").
- **Zone 2 — Today:** `getSessionWidget` (verbatim) + `zoneCapWithAdvisories`
  chip ("Today: up to Z3") + the first `recommendWorkout` option title.
- **Zone 3 — Context:** `getContextWidget` (verbatim) + a small
  `readReadinessHistory(days: 14)` sparkline + the `lastObservationSourceTier`
  swatch (LOCKED tokens from `theme/source_tier.dart`).

**Honest empty state.** When `readinessScore().advisories.last_observation_at`
is null, Zone 1 shows the LOCKED F1 copy instead of a fabricated ring. Zones 2/3
show their own engine-provided empty prose. Never invent numbers.

**Rules.** Display-only. Render all dashboard/advisory prose verbatim. No
client-side thresholds/zones/math. Keep the continuity construct/restore block
from the current `readiness_screen.dart` exactly (it's correct).

**Reference Dart — the readiness ring hero (schema-verified, compile + verify):**

```dart
// lib/widgets/readiness_ring.dart  (reference — Mac to compile/verify)
import 'package:flutter/material.dart';

/// Calm readiness hero. All inputs come verbatim from
/// ViterbiEngine.readiness_indicator(); this widget renders, never computes.
class ReadinessRing extends StatelessWidget {
  const ReadinessRing({
    super.key,
    required this.score,        // indicator['score'] as num, rounded; null = no data
    required this.level,        // indicator['level'] verbatim; drives color
    required this.confidence,   // indicator['confidence'] 0..1; thin sub-arc
    required this.noData,
  });

  final int? score;
  final String? level;
  final double? confidence;
  final bool noData;

  // Color is chosen by the engine's LEVEL, not by the UI re-deriving from score.
  Color _levelColor(BuildContext ctx) {
    switch ((level ?? '').toLowerCase()) {
      case 'green':  return const Color(0xFF2BD974);
      case 'yellow': return const Color(0xFFE8C547);
      case 'orange': return const Color(0xFFE6872F);
      case 'red':    return const Color(0xFFE5484D);
      default:       return Theme.of(ctx).colorScheme.outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (noData) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'We need more data to predict recovery.', // LOCKED F1 copy
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
      );
    }
    final color = _levelColor(context);
    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 220, height: 220,
            child: CircularProgressIndicator(
              value: (score ?? 0) / 100.0,
              strokeWidth: 14,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${score ?? '—'}',
                  style: theme.textTheme.displayLarge?.copyWith(color: color)),
              Text(level ?? '—', style: theme.textTheme.titleMedium),
              if (confidence != null)
                Text('confidence ${(confidence! * 100).round()}%',
                    style: theme.textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}
```

> Note: `Color.withValues` is Flutter 3.27+. If the Mac's SDK is older, use
> `color.withOpacity(0.15)`. (Flutter version is unverified from this seat.)

**Acceptance (Mac verifies):** with seeded/real observations the ring shows a
real number + level; with none it shows the F1 copy; all three zones render
verbatim engine prose; `flutter analyze`/`test` green; APK builds; default home
is the three-zone screen (V10 spike stays the kDebugMode-only `/v10-spike`
route).

---

## 4. PR-C — Readiness detail (tap the ring)

**Goal.** The "why" behind the score, honestly.

- **Axis breakdown:** `readinessIndicator().contributions[]` — 4 small bars,
  one per axis, using `weighted` for bar length and `raw_score`/`weight` in a
  caption. Humanize names at the label layer only:
  `hmm_posteriors`→"Fatigue model", `banister`→"Fitness & freshness",
  `physio_zscore`→"Body signals", `psychological`→"How you feel".
- **Trend:** `readReadinessHistory(days: 30)` → line/heatmap.
- **Coach note:** the `advisories.recommendations[]` from `readinessScore`,
  rendered verbatim, paired with the number (never the number alone).
- **Source + confidence:** `lastObservationSourceTier` swatch + the
  `confidence` value + a "still learning you" banner when confidence/data is low
  (honest posture — spec v1.4).

**Acceptance:** every value verbatim from engine; a widget test asserts the four
contribution bars render from a sample `contributions[]` payload.

---

## 5. PR-D — Advisor + manual data entry (this is what makes advice appear)

Two parts:

**(a) Bind `process_observation` in the shim** (`rust/src/api.rs`) — one
delegating fn, raw JSON in/out, matching the existing pattern. Then add to the
facade + regenerate FRB:

```rust
// rust/src/api.rs  (reference)
pub fn process_observation(handle: &EnginesHandle, observation_json: String)
    -> Result<String, BridgeError> {
    handle.viterbi.process_observation(observation_json).map_err(Into::into)
}
```

**(b) "Log today" manual-entry form** — minimal, honest: date, resting_hr,
hrv_rmssd, sleep_hours (+ optional mood). On submit:
1. build a UniversalObservation JSON (or `normalizeObservation(h, "manual", …)`),
2. `processObservation(h, obs)` → HMM updates,
3. persist: `saveState` → `writeViterbiState` (continuity) + `write_biometric`,
4. pop back to the home; the ring now shows real readiness.

**(c) Advisor surface** — `recommendWorkout` A/B/C option cards (suggestions
only; **no `ReplanEngine`** in MVP-1, per locked decision). The
`SuggesterContext` mood/equipment/terrain picker replaces PR-A's hardcoded
defaults so the suggestions are honest.

**Acceptance:** enter a few days of metrics → readiness ring, fatigue state,
zone cap, and a recommended workout all move off "We need more data" and show
real engine output. Continuity round-trip test (per `CONTINUITY_AND_MEMORY.md`)
green.

---

## 6. PR-E — Connectivity (real devices/platforms)

The engine NORMALIZES; the app does the TRANSPORT (the one place real I/O lives).

- **BLE** (chest straps / HR, e.g. Polar H10): a Flutter BLE plugin (e.g.
  `flutter_blue_plus`) → raw sample → `normalizeObservation(h, "ble", json)` →
  `processObservation` → persist.
- **Garmin** (Garmin Connect / Health API, OAuth) → `normalizeObservation(h,
  "garmin", json)`.
- **Polar** (Polar AccessLink, OAuth) → `normalizeObservation(h, "polar", …)`.
- **Others** (Oura/Whoop/Apple HealthKit/Wahoo/COROS) — same pattern, enabled
  incrementally.
- **"Your data sources" screen** ← `buildSourceOverview` + `classifySource`
  (which source is primary per metric; per-source tier swatch).

Each pulls the user's *own* data into the on-device encrypted vault; engine
state never leaves the device. This is the largest PR (OAuth + BLE pairing +
background sync) — scope it on its own. **Privacy note:** vendor *cloud* pulls
fetch the user's own data; on-device compute + encryption are unchanged.

**Acceptance:** real data from one paired device/account lands in the vault and
moves readiness.

---

## 7. PR-F — Grounded Josi + on-device LLM (LAST, by founder decision)

- Bind `ChatEngine::new_with_vault` (continuity-correct from day one) + `chat`,
  `get_conversation_for_llm`, `clear_history`, `update_profile`.
- Josi bottom sheet (glass) — §8 conversational retrieval: **Josi queries; the
  engine computes every value.** The on-device LLM (reuse the spike's
  `llama_cpp_dart` path, already retained behind `/v10-spike`) is the *messenger*
  fed engine state — never a source of physics.
- Acceptance: a memory written in one session is recalled in a new `ChatEngine`
  instance; Josi surfaces only engine-computed values.

---

## 8. Build order, branches, gates

1. Fix the §0 readiness bug (fold into PR-B).
2. PR-B home → PR-C detail → PR-D advisor+entry → PR-E connectivity → PR-F Josi.
3. One branch per PR off the current foundation; open a PR each; I review the
   diff against this pack before merge.
4. Every PR: `flutter analyze` clean, `flutter test` green (with a
   concrete-value assertion for new behaviour), `smoke-build.yml` green,
   APK builds.
5. **Re-pin reminder:** the engine pin is `4dab6cb` (pre-encryption). Bump to
   current `main` (`868a95d`, vault + ledger encryption) so the Beta stores data
   **encrypted-at-rest**; no Dart change needed, dev vaults auto-migrate.

## 9. Status — what's verified vs needs-Mac

| Item | Verified by orchestration seat | Needs Mac (compile/run) |
|---|---|---|
| Binding names + JSON field names | ✅ (engine source + guide) | — |
| §0 readiness bug diagnosis + fix | ✅ (schema-confirmed) | apply + compile |
| Reference Dart (ring) | ⚠️ schema-correct, NOT compiled | analyze/test/build/fix |
| PR-B…F specs + acceptance | ✅ | implement + verify |
| Anything "works" / renders | ❌ cannot claim | ✅ only after Mac builds |

**Bottom line:** the plan and the data contracts are verified and the one real
PR-A bug is caught and fixed here. Turning this into running screens is the
Mac's compile-and-verify pass — nothing in this pack should be merged as "done"
without it.

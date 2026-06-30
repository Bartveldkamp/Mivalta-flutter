#!/usr/bin/env python3
"""Generate the DEBUG demo-athlete season fixture.

SYNTHETIC INPUT ONLY. This emits a coherent ~30-day arc of raw, HealthKit-shaped
biometrics (resting HR, HRV SDNN, SpOâ‚‚, sleep hours) that the app's DEBUG
"demo athlete" seeder replays through the REAL ingest path
(normalizeObservation â†’ processObservation). The engine computes every readiness
state from this input â€” nothing on the display side is fabricated. This is the
on-device analog of the rust `dev_sim` / python `realworld_sim` season: synthetic
INPUT, real PIPELINE.

The arc mirrors dev_sim: base â†’ overload â†’ illness dip â†’ recovery.

Dates are NOT baked in: each day carries an `offset` (days before "today", 0 =
today) because the Viterbi monitor uses calendar-day windowing (42-day window,
stale data excluded) â€” the seeder assigns real dates ending today at replay time
so the season is never stale.

Run:  python3 scripts/gen_demo_season.py
Out:  assets/debug/demo_season.json   (committed; regenerate if the arc changes)
"""
from __future__ import annotations

import json
from pathlib import Path

# Coherent base â†’ overload â†’ illness â†’ recovery arc. Each tuple is one day:
# (resting_hr bpm, hrv_sdnn ms (None = no HRV reading that day), spo2 fraction,
# sleep hours). Hand-authored to a
# physiologically plausible shape (RHR rises / HRV falls under accumulating load,
# both worsen sharply in the illness dip, then converge back to baseline).
PHASES: list[tuple[str, list[tuple[float, float | None, float, float]]]] = [
    ("base", [
        (53, 64, 0.98, 7.8), (52, 66, 0.98, 8.0), (54, 63, 0.98, 7.6),
        (53, 65, 0.98, 7.9), (52, 67, 0.98, 8.1), (53, 64, 0.98, 7.7),
        (54, 62, 0.98, 7.5), (52, 66, 0.98, 8.0), (53, 65, 0.98, 7.8),
        (53, 64, 0.98, 7.9),
    ]),
    ("overload", [
        (54, 61, 0.97, 7.3), (55, 58, 0.97, 7.1), (56, 55, 0.97, 7.0),
        (57, 52, 0.97, 6.8), (57, 50, 0.97, 6.9), (58, 49, 0.97, 6.7),
        (59, 47, 0.97, 6.6), (59, 46, 0.97, 6.7),
    ]),
    ("illness", [
        (62, 38, 0.95, 6.2), (65, 33, 0.94, 5.9),
        (66, 31, 0.95, 6.1), (64, 35, 0.96, 6.4),
    ]),
    ("recovery", [
        (60, 42, 0.96, 6.8), (58, 47, 0.97, 7.2), (56, 52, 0.97, 7.5),
        (55, 56, 0.98, 7.8), (54, 59, 0.98, 7.9),
        (53, None, 0.98, 8.0),  # offset -2: deliberately no HRV — witness honest-absence (§8.0)
        (52, 64, 0.98, 8.1), (52, 65, 0.98, 8.0),
    ]),
]

# ---------------------------------------------------------------------------
# Activity seed (§8.0 witness pre-req, Option B): a few completed workouts the
# DEBUG seeder replays through the REAL workout-ingest core
# (IngestAdapter.ingestWorkout) so the engine computes the load and the vault-
# backed surfaces — Journey row, workout-detail, post-workout report — paint
# from real engine output on synthetic input.
#
# METABOLIC LEVELS LEAD, ZONES DERIVE UNDERNEATH. Each workout is authored as a
# sequence of (metabolic level, minutes) segments; LEVEL_HR maps each level to a
# target HR for this synthetic athlete (HRmax ~182, hand-authored — NOT a runtime
# constant). This generator (a build-time synthetic-INPUT authoring tool, like
# dev_sim — never the product runtime) expands the segments into a per-minute HR
# series and emits the session's avg/max HR. The runtime seeder couriers those
# scalars to the engine, which computes the HR-based load (Law 2: no mean in the
# Dart runtime — the averaging is fixture authoring here, exactly as the RHR/HRV
# arc above is authored).
#
# Time-in-zone is NOT seeded (Option B, founder 2026-06-30): TIZ is a live-
# capture surface that recomputes from the device HR stream at display, so it is
# witnessed via a real/injected workout, not the seed. The per-minute series is
# therefore the basis for avg/max only and is intentionally NOT emitted to the
# fixture (nothing reads it yet); it returns — persisted, with TIZ reading the
# vault — when Option A (the P0/P2 activity-capture build) lands.
#
# Target HR (bpm) per metabolic level — synthetic masters athlete, fixture
# authoring (R/recovery..L5/VO2). Hand-authored, physiologically ordered.
LEVEL_HR: dict[int, int] = {1: 115, 2: 132, 3: 150, 4: 165, 5: 174}

# offset -> (activity_type, [(level, minutes), ...]). One representative session
# per training phase so the Journey list + post-workout report show variety.
WORKOUTS: dict[int, tuple[str, list[tuple[int, int]]]] = {
    -24: ("ride", [(2, 20), (2, 30), (3, 15), (2, 10)]),                 # base: endurance + tempo finish (75 min)
    -15: ("ride", [(2, 12), (4, 8), (2, 4), (4, 8), (2, 4), (4, 8), (2, 16)]),  # overload: 3×8 threshold (60 min)
    -4:  ("ride", [(1, 15), (2, 25), (1, 5)]),                           # recovery: easy spin (45 min)
}


def _workout_for(offset: int) -> dict | None:
    """Author the completed-workout object for an offset, or None.

    Expands the (level, minutes) segments into a per-minute HR series via
    LEVEL_HR, then emits the session scalars the runtime reads. The series
    itself is NOT emitted (Option B — see the comment above)."""
    spec = WORKOUTS.get(offset)
    if spec is None:
        return None
    activity_type, segments = spec
    series = [LEVEL_HR[level] for level, minutes in segments for _ in range(minutes)]
    duration_min = len(series)
    return {
        "activity_type": activity_type,
        "duration_min": duration_min,
        "avg_hr": round(sum(series) / duration_min),
        "max_hr": max(series),
    }


def build() -> dict:
    rows = [row for _, days in PHASES for row in days]
    total = len(rows)
    days = []
    for i, (rhr, hrv, spo2, sleep) in enumerate(rows):
        # offset 0 == the most recent day (today); first row is the oldest.
        offset = -(total - 1 - i)
        day = {
            "offset": offset,
            "resting_heart_rate": {"value": float(rhr), "unit": "count/min"},
        }
        # `hrv` may be None for a deliberately-missing-HRV day: emit honest
        # absence (omit the field entirely), never a null, so the no-HRV path is
        # exercised in the witness pass (HANDOFF §8.0). Field order is preserved
        # (rhr, hrv?, spo2, sleep) so only the null-HRV day differs in the JSON.
        if hrv is not None:
            day["hrv_sdnn"] = {"value": float(hrv), "unit": "ms"}
        day["oxygen_saturation"] = {"value": float(spo2), "unit": "%"}
        day["sleep_hours"] = float(sleep)
        # Completed workout for this day (§8.0 activity seed), when authored.
        workout = _workout_for(offset)
        if workout is not None:
            day["workout"] = workout
        days.append(day)
    return {
        "_provenance": (
            "SYNTHETIC. Generated by scripts/gen_demo_season.py. Coherent "
            "base->overload->illness->recovery arc (mirrors dev_sim). Raw "
            "HealthKit-shaped INPUT only -- the engine computes all output. "
            "DEBUG ingest fixture; never shipped in release."
        ),
        "schema": "healthkit",
        "days": days,
    }


def main() -> None:
    out = Path(__file__).resolve().parent.parent / "assets" / "debug" / "demo_season.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(build(), indent=2) + "\n")
    print(f"wrote {out} ({len(build()['days'])} days)")


if __name__ == "__main__":
    main()

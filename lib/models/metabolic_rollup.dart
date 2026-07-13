// Metabolic time-in-zone ROLLUP — Journey recall (week / meso / any window).
//
// Display-only parse of `VaultEngine::metabolic_time_in_zone_rollup(start,end)`:
// the engine sums each stored workout's time-in-zone atom over the window
// (engine math, Law 2 — this model only reads the result). Wire shape is the
// engine's `MetabolicTimeInZone`: seconds per level id
// `{"aerobic_base":..,"aerobic_endurance":..,"tempo":..,"threshold":..,
//   "vo2max":..,"anaerobic_neuro":..,"unclassified":..}`.
// A window with no stream-bearing workouts returns ALL ZEROS — the engine's
// honest absence, surfaced here as `isEmpty` so the section renders "no
// recorded training in this window", never a fabricated bar.

import '../copy/level_labels.dart';

class MetabolicRollup {
  /// Seconds per engine level id, exactly as the engine summed them.
  final Map<String, double> secondsByLevel;

  /// Seconds the engine could not classify (kept visible, never re-binned).
  final double unclassifiedSeconds;

  const MetabolicRollup({
    required this.secondsByLevel,
    required this.unclassifiedSeconds,
  });

  factory MetabolicRollup.fromJson(dynamic json) {
    if (json is! Map) {
      return const MetabolicRollup(secondsByLevel: {}, unclassifiedSeconds: 0);
    }
    final byLevel = <String, double>{
      for (final (id, _) in kMetabolicLevelLabels)
        id: (json[id] as num?)?.toDouble() ?? 0,
    };
    return MetabolicRollup(
      secondsByLevel: byLevel,
      unclassifiedSeconds: (json['unclassified'] as num?)?.toDouble() ?? 0,
    );
  }

  /// True when the engine reported zero everywhere — the honest-absence
  /// signal for "no stream-bearing training in this window".
  bool get isEmpty =>
      unclassifiedSeconds == 0 &&
      secondsByLevel.values.every((s) => s == 0);

  /// (label, whole minutes) rows in fixed engine order, non-zero levels only.
  /// Rounding is display formatting; the engine owns the seconds.
  List<(String, int)> get nonZeroMinuteRows => [
        for (final (id, label) in kMetabolicLevelLabels)
          if ((secondsByLevel[id] ?? 0) > 0)
            (label, ((secondsByLevel[id]!) / 60).round()),
      ];
}

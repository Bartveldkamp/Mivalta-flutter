// Power Curve (Mean-Maximal Power) model — Monitor analytics.
//
// Display-only. Maps the engine's `gatc-mmp` output
// (mivalta-rust-engine `MmpCurve{points:[{duration_seconds, max_power_watts}]}`,
// from `MmpEngine::compute_mmp`). The curve IS the best power held for each
// duration — the standard cycling power-profile surface. Flutter only renders.
//
// FFI bridge needed (Mac step, roadmap §5): facade `computeMmp` / mmp_history
// returning the MmpCurve JSON. `compute_mmp` is already FFI-exposed in gatc-ffi.

class PowerPoint {
  final int durationSeconds;
  final double maxPowerWatts;

  const PowerPoint({required this.durationSeconds, required this.maxPowerWatts});

  factory PowerPoint.fromJson(Map json) => PowerPoint(
        durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
        maxPowerWatts: (json['max_power_watts'] as num?)?.toDouble() ?? 0,
      );
}

class PowerCurve {
  final List<PowerPoint> points;

  const PowerCurve({required this.points});

  bool get isEmpty => points.isEmpty;

  /// Peak power nearest a target duration (seconds), for labelling key points
  /// (5 s, 1 min, 5 min, 20 min, 60 min). Returns null when no points.
  /// Selection only — the engine computed every value.
  PowerPoint? nearest(int targetSeconds) {
    if (points.isEmpty) return null;
    PowerPoint best = points.first;
    int bestDelta = (best.durationSeconds - targetSeconds).abs();
    for (final p in points) {
      final d = (p.durationSeconds - targetSeconds).abs();
      if (d < bestDelta) {
        best = p;
        bestDelta = d;
      }
    }
    return best;
  }

  factory PowerCurve.fromJson(dynamic json) {
    List? raw;
    if (json is List) {
      raw = json;
    } else if (json is Map && json['points'] is List) {
      raw = json['points'] as List;
    }
    if (raw == null) return const PowerCurve(points: []);
    final pts = raw.whereType<Map>().map(PowerPoint.fromJson).toList(growable: false);
    return PowerCurve(points: pts);
  }
}

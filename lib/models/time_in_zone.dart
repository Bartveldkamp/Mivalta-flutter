// Time-in-Zone model — Monitor analytics (per-activity intensity distribution).
//
// Display-only. Maps the engine's `gatc-knowledge::zone_definitions::TimeInZone`
// (from `PostProcessEngine::compute_time_in_zone`): the seconds an activity's
// raw sample stream spent in each canonical zone, binned through MiValta's OWN
// `zone_anchors` scale (R, Z1..Z8) — never a vendor zone table. The engine
// classifies every sample by the athlete's threshold (FTP / threshold pace /
// LTHR); Flutter only renders. No thresholds or math in Dart.
//
// Wire shape:
//   {"anchor":"power"|"pace"|"hr",
//    "seconds":[{"zone":"R","seconds":0.0}, ... 9 buckets ...],
//    "total_seconds":1234.0}

/// Seconds spent in one canonical zone.
class ZoneSeconds {
  final String zone;
  final double seconds;

  const ZoneSeconds({required this.zone, required this.seconds});

  factory ZoneSeconds.fromJson(Map json) => ZoneSeconds(
        zone: json['zone']?.toString() ?? '',
        seconds: (json['seconds'] as num?)?.toDouble() ?? 0,
      );

  /// Whole minutes for compact labelling. Selection only — the engine
  /// computed the seconds.
  int get minutes => (seconds / 60).round();
}

/// Per-activity time-in-zone distribution over MiValta's canonical 9-bucket
/// scale (R recovery + the eight training zones Z1..Z8).
class TimeInZone {
  /// Anchor the engine classified through: `power` | `pace` | `hr`.
  final String anchor;

  /// One entry per canonical zone, in fixed engine order R, Z1..Z8.
  final List<ZoneSeconds> zones;

  /// Total classified seconds (engine sum; excludes skipped samples).
  final double totalSeconds;

  /// Engine rollup of the nine zones into the six metabolic levels
  /// (`aerobic_base` … `anaerobic_neuro`, plus `unclassified`) — which
  /// energy system was trained, for how long. Empty when the wire predates
  /// the rollup or the engine omitted it (honest absence; render nothing).
  final Map<String, double> metabolicSeconds;

  const TimeInZone({
    required this.anchor,
    required this.zones,
    required this.totalSeconds,
    this.metabolicSeconds = const {},
  });

  /// No samples classified yet (engine returned an empty/zero distribution).
  bool get isEmpty => zones.isEmpty || totalSeconds <= 0;

  /// Largest dwell, for highlighting the activity's dominant zone. Returns
  /// null when empty. Selection only.
  ZoneSeconds? get dominant {
    if (zones.isEmpty) return null;
    ZoneSeconds best = zones.first;
    for (final z in zones) {
      if (z.seconds > best.seconds) best = z;
    }
    return best.seconds > 0 ? best : null;
  }

  /// Fraction of total time in [z] (0.0–1.0), for bar sizing. The engine owns
  /// the totals; this is pure ratio for layout. Zero when total is zero.
  double fraction(ZoneSeconds z) =>
      totalSeconds > 0 ? z.seconds / totalSeconds : 0;

  factory TimeInZone.fromJson(dynamic json) {
    if (json is! Map) {
      return const TimeInZone(anchor: '', zones: [], totalSeconds: 0);
    }
    final raw = json['seconds'];
    final zs = raw is List
        ? raw.whereType<Map>().map(ZoneSeconds.fromJson).toList(growable: false)
        : const <ZoneSeconds>[];
    final metabolic = <String, double>{};
    final rawMet = json['metabolic_seconds'];
    if (rawMet is Map) {
      rawMet.forEach((k, v) {
        if (v is num) metabolic[k.toString()] = v.toDouble();
      });
    }
    return TimeInZone(
      anchor: json['anchor']?.toString() ?? '',
      zones: zs,
      totalSeconds: (json['total_seconds'] as num?)?.toDouble() ?? 0,
      metabolicSeconds: metabolic,
    );
  }
}

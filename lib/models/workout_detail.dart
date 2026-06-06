// Workout Detail model — Monitor analytics.
//
// Display-only. A completed workout's metrics + quality, composed from engine
// outputs: `session_actual` (duration_min, avg power/HR/pace), the
// `workout_quality` grading (hr_decoupling_pct, zone_compliance_pct,
// efficiency_factor, grade), and `gatc-decoupling` (decoupling_pct). All values
// are engine-computed; Flutter renders.
//
// FFI bridge needed (Mac step, roadmap §5): a per-activity getter returning this
// composite JSON. Producers exist (post-process pipeline + workout_quality).

class WorkoutDetail {
  final String date;
  final String sport;
  final int? durationMin;
  final int? avgWatts;
  final int? avgHr;
  final String? avgPaceMss;
  final double? decouplingPct;
  final double? efficiencyFactor;
  final double? zoneCompliancePct;

  /// Engine grade (e.g. "Excellent", "Good", "Fair", "Poor", "Ungraded").
  final String? grade;

  const WorkoutDetail({
    required this.date,
    required this.sport,
    this.durationMin,
    this.avgWatts,
    this.avgHr,
    this.avgPaceMss,
    this.decouplingPct,
    this.efficiencyFactor,
    this.zoneCompliancePct,
    this.grade,
  });

  factory WorkoutDetail.fromJson(dynamic json) {
    if (json is! Map) {
      return const WorkoutDetail(date: '', sport: '');
    }
    return WorkoutDetail(
      date: json['date']?.toString() ?? '',
      sport: json['sport']?.toString() ?? '',
      durationMin: (json['duration_min'] as num?)?.toInt(),
      avgWatts: (json['avg_watts'] as num?)?.toInt(),
      avgHr: (json['avg_hr'] as num?)?.toInt(),
      avgPaceMss: json['avg_pace_mss']?.toString(),
      decouplingPct: (json['decoupling_pct'] as num?)?.toDouble(),
      efficiencyFactor: (json['efficiency_factor'] as num?)?.toDouble(),
      zoneCompliancePct: (json['zone_compliance_pct'] as num?)?.toDouble(),
      grade: json['grade']?.toString(),
    );
  }
}

// Workout Detail model — Monitor analytics.
//
// Display-only. A completed workout's metrics + quality, composed by the
// engine (`NarrativeEngine::get_workout_detail(date)`): session actuals, the
// `workout_quality` grading, decoupling, the device-collected parameters
// stored verbatim from the athlete's device (founder 2026-07-07), and the
// per-workout time-in-metabolic-level atom. All values are engine-produced;
// Flutter renders. No thresholds or math in Dart — a `null` from the engine
// is honest absence and renders as nothing, never a stand-in.

import 'time_in_zone.dart';

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

  // ---- Session basics ----
  final double? distanceKm;
  final int? calories;
  final int? maxHr;

  /// Data source of this workout (e.g. `garmin`, `wahoo`, `manual`).
  final String? source;

  // ---- Device-collected parameters (verbatim from the device) ----
  final double? avgPowerWatts;
  final double? maxPowerWatts;

  /// Sport-native unit as the device reported it (rpm cycling / spm running).
  final double? avgCadence;
  final double? maxCadence;
  final double? avgSpeedMs;
  final double? maxSpeedMs;
  final double? elevationGainM;
  final double? elevationLossM;

  /// Polar Running Index (per-run VO2max proxy), as reported.
  final double? runningIndex;

  /// The per-workout time-in-zone + metabolic-level atom, or null when the
  /// workout carried no usable stream (honest absence).
  final TimeInZone? timeInZone;

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
    this.distanceKm,
    this.calories,
    this.maxHr,
    this.source,
    this.avgPowerWatts,
    this.maxPowerWatts,
    this.avgCadence,
    this.maxCadence,
    this.avgSpeedMs,
    this.maxSpeedMs,
    this.elevationGainM,
    this.elevationLossM,
    this.runningIndex,
    this.timeInZone,
  });

  factory WorkoutDetail.fromJson(dynamic json) {
    if (json is! Map) {
      return const WorkoutDetail(date: '', sport: '');
    }
    final rawTiz = json['time_in_zone'];
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
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      calories: (json['calories'] as num?)?.toInt(),
      maxHr: (json['max_hr'] as num?)?.toInt(),
      source: json['source']?.toString(),
      avgPowerWatts: (json['avg_power_watts'] as num?)?.toDouble(),
      maxPowerWatts: (json['max_power_watts'] as num?)?.toDouble(),
      avgCadence: (json['avg_cadence'] as num?)?.toDouble(),
      maxCadence: (json['max_cadence'] as num?)?.toDouble(),
      avgSpeedMs: (json['avg_speed_m_s'] as num?)?.toDouble(),
      maxSpeedMs: (json['max_speed_m_s'] as num?)?.toDouble(),
      elevationGainM: (json['elevation_gain_m'] as num?)?.toDouble(),
      elevationLossM: (json['elevation_loss_m'] as num?)?.toDouble(),
      runningIndex: (json['running_index'] as num?)?.toDouble(),
      timeInZone: rawTiz is Map ? TimeInZone.fromJson(rawTiz) : null,
    );
  }
}

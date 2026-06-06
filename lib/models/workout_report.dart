// Post-Workout Report model — Advisory (card-grounded, present-and-offer).
//
// Display-only. Maps the engine's `WorkoutReport`
// (mivalta-rust-engine `gatc_narrative::build_report`): the deterministic,
// card-grounded report for a completed session. Every string is either a
// verbatim engine number or a knowledge-card-sourced phrase — nothing authored
// in Dart. Absent fields stay empty and are simply not shown (no fabrication).

class WorkoutReport {
  final String date;
  final String sport;

  /// Canonical zone (R, Z1–Z8); empty when non-canonical.
  final String zone;
  final double durationMin;
  final int? avgHr;
  final int? rpe;

  /// Primary energy system trained — card `energy_systems:zone_map`. Empty when
  /// the zone is non-canonical.
  final String energySystem;

  /// What this zone builds — card `josi_explanations:zone_purpose_rules`.
  final String whatItBuilds;

  /// Stimulus/cost band interpretation — card `coach_cues:stimulus_cost_bands`.
  final String stimulusCostNote;

  /// The engine's own quality summary (verbatim), when present.
  final String qualitySummary;

  /// The deterministic plain-text report (the autocue) — every line a verbatim
  /// number or card phrase.
  final String autocue;

  const WorkoutReport({
    required this.date,
    required this.sport,
    required this.zone,
    required this.durationMin,
    required this.avgHr,
    required this.rpe,
    required this.energySystem,
    required this.whatItBuilds,
    required this.stimulusCostNote,
    required this.qualitySummary,
    required this.autocue,
  });

  /// Nothing to report (no completed session) — the card is hidden.
  bool get isEmpty => date.isEmpty && autocue.isEmpty;

  factory WorkoutReport.fromJson(dynamic json) {
    if (json is! Map) {
      return const WorkoutReport(
        date: '',
        sport: '',
        zone: '',
        durationMin: 0,
        avgHr: null,
        rpe: null,
        energySystem: '',
        whatItBuilds: '',
        stimulusCostNote: '',
        qualitySummary: '',
        autocue: '',
      );
    }
    return WorkoutReport(
      date: json['date']?.toString() ?? '',
      sport: json['sport']?.toString() ?? '',
      zone: json['zone']?.toString() ?? '',
      durationMin: (json['duration_min'] as num?)?.toDouble() ?? 0,
      avgHr: (json['avg_hr'] as num?)?.toInt(),
      rpe: (json['rpe'] as num?)?.toInt(),
      energySystem: json['energy_system']?.toString() ?? '',
      whatItBuilds: json['what_it_builds']?.toString() ?? '',
      stimulusCostNote: json['stimulus_cost_note']?.toString() ?? '',
      qualitySummary: json['quality_summary']?.toString() ?? '',
      autocue: json['autocue']?.toString() ?? '',
    );
  }
}

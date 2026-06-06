// Fitness Development (PMC) model — Monitor analytics.
//
// Display-only. Maps the engine's Banister model output
// (mivalta-rust-engine `gatc-planner/banister.rs` → `BanisterState{ctl, atl,
// tsb, form_zone}`, the TrainingPeaks Performance-Manager model: CTL=fitness
// τ=42d, ATL=fatigue τ=7d, TSB=form). The engine computes the series and the
// form classification; Flutter only renders — no thresholds or math in Dart.
//
// FFI bridge needed (Mac step, see MONITOR_ANALYTICS_ROADMAP §5): a getter that
// returns the CTL/ATL/TSB series over a date range as JSON
//   {"samples":[{"date","ctl","atl","tsb"}...], "form_zone":"..."}
// Today only the Banister *params* are FFI-exposed; the series getter is pending.

/// One day on the Performance-Manager curve.
class FitnessSample {
  final String date;
  final double ctl;
  final double atl;
  final double tsb;

  const FitnessSample({
    required this.date,
    required this.ctl,
    required this.atl,
    required this.tsb,
  });

  factory FitnessSample.fromJson(Map json) => FitnessSample(
        date: json['date']?.toString() ?? '',
        ctl: (json['ctl'] as num?)?.toDouble() ?? 0,
        atl: (json['atl'] as num?)?.toDouble() ?? 0,
        tsb: (json['tsb'] as num?)?.toDouble() ?? 0,
      );
}

/// The fitness-development series + the engine's current form classification.
class FitnessTrend {
  final List<FitnessSample> samples;

  /// Engine-decided form zone (e.g. "fresh", "productive", "grey", "fatigued").
  /// Verbatim from the engine — the UI does not classify form itself.
  final String? formZone;

  const FitnessTrend({required this.samples, this.formZone});

  /// True when there is no series to plot — the UI shows the honest empty state.
  bool get isEmpty => samples.isEmpty;

  /// Most recent sample (the "today" values), or null when empty.
  FitnessSample? get latest => samples.isEmpty ? null : samples.last;

  factory FitnessTrend.fromJson(dynamic json) {
    // Accept either {"samples":[...], "form_zone":...} or a bare list.
    if (json is List) {
      return FitnessTrend(
        samples: json
            .whereType<Map>()
            .map(FitnessSample.fromJson)
            .toList(growable: false),
      );
    }
    if (json is Map) {
      final raw = json['samples'];
      final samples = raw is List
          ? raw.whereType<Map>().map(FitnessSample.fromJson).toList(growable: false)
          : const <FitnessSample>[];
      return FitnessTrend(
        samples: samples,
        formZone: json['form_zone']?.toString(),
      );
    }
    return const FitnessTrend(samples: []);
  }
}

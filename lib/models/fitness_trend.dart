// Fitness trend model — Monitor analytics.
//
// Display-only. Maps `ViterbiEngine::fitness_series` — the long-term Banister
// fitness *trend* (the slow shape), JSON `[{date, fitness, fatigue, form}]`
// ascending by date:
//   - fitness — Banister fitness component g(t) (slow, τ₁≈42d)
//   - fatigue — Banister fatigue component h(t) (fast, τ₂≈15d)
//   - form    — modelled performance p★ + k₁·g − k₂·h
// The engine computes the Banister IRF; Flutter only renders. This is the
// long-term *trend*, distinct from the Viterbi *state* (today's fatigue state).

/// One day on the fitness trend.
class FitnessSample {
  final String date;
  final double fitness;
  final double fatigue;
  final double form;

  const FitnessSample({
    required this.date,
    required this.fitness,
    required this.fatigue,
    required this.form,
  });

  factory FitnessSample.fromJson(Map json) => FitnessSample(
        date: json['date']?.toString() ?? '',
        fitness: (json['fitness'] as num?)?.toDouble() ?? 0,
        fatigue: (json['fatigue'] as num?)?.toDouble() ?? 0,
        form: (json['form'] as num?)?.toDouble() ?? 0,
      );
}

/// The fitness-trend series.
class FitnessTrend {
  final List<FitnessSample> samples;

  const FitnessTrend({required this.samples});

  /// True when there is no series to plot — the UI shows the honest empty state.
  bool get isEmpty => samples.isEmpty;

  /// Most recent sample (the "today" values), or null when empty.
  FitnessSample? get latest => samples.isEmpty ? null : samples.last;

  factory FitnessTrend.fromJson(dynamic json) {
    // Engine returns a bare array; also tolerate a {"samples":[...]} envelope.
    if (json is List) {
      return FitnessTrend(
        samples:
            json.whereType<Map>().map(FitnessSample.fromJson).toList(growable: false),
      );
    }
    if (json is Map) {
      final raw = json['samples'];
      return FitnessTrend(
        samples: raw is List
            ? raw.whereType<Map>().map(FitnessSample.fromJson).toList(growable: false)
            : const <FitnessSample>[],
      );
    }
    return const FitnessTrend(samples: []);
  }
}

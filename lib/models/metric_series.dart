// Per-activity metric series — Monitor analytics (fitness-trend actuals overlay).
//
// Display-only. Maps `VaultEngine::read_metric_across_activities`, which returns
// a dated series `[{date, activity_id, value, activity_type}]` (value may be
// null when an activity lacks the metric). Used to overlay the athlete's ACTUAL
// watts (`normalized_power`) or pace (`pace_sec_per_km`) on the modelled fitness
// trend — the trend is the model, these are the measured values (no new claim).

class MetricSample {
  final String date;
  final double value;

  const MetricSample({required this.date, required this.value});
}

class MetricSeries {
  final List<MetricSample> samples;

  const MetricSeries({required this.samples});

  bool get isEmpty => samples.isEmpty;

  factory MetricSeries.fromJson(dynamic json) {
    if (json is! List) return const MetricSeries(samples: []);
    final out = <MetricSample>[];
    for (final e in json) {
      if (e is Map) {
        final v = (e['value'] as num?)?.toDouble(); // null → activity lacks metric
        if (v != null) {
          out.add(MetricSample(date: e['date']?.toString() ?? '', value: v));
        }
      }
    }
    return MetricSeries(samples: out);
  }
}

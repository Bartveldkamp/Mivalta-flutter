// Biometric Series model — for the Explore biometrics view.
//
// Display-only. Extracts one metric's series from the engine's biometric history
// (`VaultEngine::read_biometric_history(days)` → array of `VaultBiometric`).
// Keeps only days that recorded that metric (no fabrication/interpolation).
// Flutter renders verbatim values + a line; it derives no metric.

/// The biometrics a user can look into, mapped to their `VaultBiometric` field.
enum BiometricMetric {
  restingHr('resting_hr', 'Resting HR', 'bpm'),
  hrv('hrv_rmssd', 'HRV', 'ms'),
  sleep('sleep_hours', 'Sleep', 'h'),
  wellness('wellness', 'Wellness', ''),
  bodyTemp('body_temperature_deviation_c', 'Temp Δ', '°C');

  const BiometricMetric(this.field, this.label, this.unit);

  /// `VaultBiometric` JSON key.
  final String field;
  final String label;
  final String unit;
}

class BiometricPoint {
  final String date;
  final double value;
  const BiometricPoint({required this.date, required this.value});
}

class BiometricSeries {
  final BiometricMetric metric;

  /// Points with a recorded value for this metric, ascending by date.
  final List<BiometricPoint> points;

  const BiometricSeries({required this.metric, required this.points});

  bool get isEmpty => points.isEmpty;

  /// Most recent recorded value (verbatim); indexing, not math.
  double? get latest => points.isEmpty ? null : points.last.value;

  List<double> get values => points.map((p) => p.value).toList(growable: false);

  factory BiometricSeries.fromHistory(dynamic json, BiometricMetric metric) {
    if (json is! List) return BiometricSeries(metric: metric, points: const []);
    final pts = <BiometricPoint>[];
    for (final e in json) {
      if (e is Map) {
        final v = (e[metric.field] as num?)?.toDouble();
        final d = e['date']?.toString();
        if (v != null && d != null && d.isNotEmpty) {
          pts.add(BiometricPoint(date: d, value: v));
        }
      }
    }
    pts.sort((a, b) => a.date.compareTo(b.date));
    return BiometricSeries(metric: metric, points: pts);
  }
}

// Sleep Trend model — Monitor analytics.
//
// Display-only. Maps the engine's biometric history
// (mivalta-rust-engine `VaultBiometric{date, sleep_hours, ...}` via
// `VaultEngine::read_biometric_history`). Keeps only nights that have a recorded
// `sleep_hours` (no fabrication, no interpolation). Flutter renders verbatim —
// the latest value and a sparkline of the recent nights; it derives no metric.

class SleepNight {
  final String date;
  final double hours;
  const SleepNight({required this.date, required this.hours});
}

class SleepTrend {
  /// Nights with a recorded sleep duration, ascending by date.
  final List<SleepNight> nights;

  const SleepTrend({required this.nights});

  bool get isEmpty => nights.isEmpty;

  /// Most recent night's hours (verbatim) — `null` when empty. Indexing, not math.
  double? get latestHours => nights.isEmpty ? null : nights.last.hours;

  /// Series for the sparkline (rendering only).
  List<double> get series => nights.map((n) => n.hours).toList(growable: false);

  factory SleepTrend.fromJson(dynamic json) {
    if (json is! List) return const SleepTrend(nights: []);
    final nights = <SleepNight>[];
    for (final e in json) {
      if (e is Map) {
        final h = (e['sleep_hours'] as num?)?.toDouble();
        final d = e['date']?.toString();
        if (h != null && h > 0 && d != null && d.isNotEmpty) {
          nights.add(SleepNight(date: d, hours: h));
        }
      }
    }
    // ISO dates sort lexically; ascending so `latest` is the newest night.
    nights.sort((a, b) => a.date.compareTo(b.date));
    return SleepTrend(nights: nights);
  }
}

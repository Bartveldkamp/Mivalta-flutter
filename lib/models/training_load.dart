// Training Load model — Monitor analytics.
//
// Display-only. Maps `VaultEngine::read_daily_loads` output: daily training
// load (`load_uls` summed per day) as JSON `[[date, load], ...]` (serde tuple
// array). The engine computes the loads; Flutter renders.

class TrainingLoadDay {
  final String date;
  final double load;

  const TrainingLoadDay({required this.date, required this.load});
}

class TrainingLoad {
  final List<TrainingLoadDay> days;

  const TrainingLoad({required this.days});

  bool get isEmpty => days.isEmpty;

  /// Largest daily load in the window (for chart scaling / readout). Selection
  /// only — every value is engine-computed.
  double get peak =>
      days.isEmpty ? 0 : days.map((d) => d.load).reduce((a, b) => a > b ? a : b);

  factory TrainingLoad.fromJson(dynamic json) {
    if (json is! List) return const TrainingLoad(days: []);
    final out = <TrainingLoadDay>[];
    for (final row in json) {
      // serde (NaiveDate, f64) → ["2026-06-01", 123.4]
      if (row is List && row.length >= 2) {
        final load = (row[1] as num?)?.toDouble();
        if (load != null) {
          out.add(TrainingLoadDay(date: row[0]?.toString() ?? '', load: load));
        }
      } else if (row is Map) {
        final load = (row['load'] as num?)?.toDouble();
        if (load != null) {
          out.add(TrainingLoadDay(date: row['date']?.toString() ?? '', load: load));
        }
      }
    }
    return TrainingLoad(days: out);
  }
}

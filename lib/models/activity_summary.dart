// Activity Summary model — for the Explore/History workout list.
//
// Display-only. A compact row mapped from a stored `VaultActivity`
// (`VaultEngine::read_recent_activities`). The full per-workout detail (actuals
// + engine-graded quality) is fetched on tap via `get_workout_detail(date)`.

class ActivitySummary {
  final String id;
  final String date;
  final String sport;
  final int? durationMin;
  final int? avgHr;

  /// Universal Load Score for this workout, when the engine computed one.
  final double? loadUls;

  const ActivitySummary({
    required this.id,
    required this.date,
    required this.sport,
    this.durationMin,
    this.avgHr,
    this.loadUls,
  });

  factory ActivitySummary.fromJson(Map json) => ActivitySummary(
        id: json['id']?.toString() ?? '',
        date: json['date']?.toString() ?? '',
        sport: json['activity_type']?.toString() ?? '',
        durationMin: (json['duration_minutes'] as num?)?.round(),
        avgHr: (json['avg_heart_rate'] as num?)?.toInt(),
        loadUls: (json['load_uls'] as num?)?.toDouble(),
      );

  /// Parse the `read_recent_activities` JSON array (newest first). Only rows
  /// with a date survive — no fabricated entries.
  static List<ActivitySummary> listFromJson(dynamic json) {
    if (json is! List) return const [];
    return json
        .whereType<Map>()
        .map(ActivitySummary.fromJson)
        .where((a) => a.date.isNotEmpty)
        .toList(growable: false);
  }
}

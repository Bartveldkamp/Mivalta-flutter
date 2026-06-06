// Load Context model — for the Explore load/strain rollup.
//
// Display-only. Parses the engine's `DashboardEngine::get_context_widget()`
// payload (already bridged as `getContextWidget`): ACWR (acute:chronic, Lolli
// 2019) + Foster monotony/strain, each with an engine-assigned zone and
// card-sourced recommendation prose. The engine computes everything; Dart only
// renders. No buckets summed in Dart — these ARE the engine's load rollup.

class LoadContext {
  final double acwr;
  final String acwrZone;
  final String acwrRecommendation;
  final double monotony;
  final double strain;
  final String monotonyZone;
  final String monotonyRecommendation;

  /// `data_status == "ok"` — a real reading rather than a corrupt-state blank.
  final bool available;

  const LoadContext({
    required this.acwr,
    required this.acwrZone,
    required this.acwrRecommendation,
    required this.monotony,
    required this.strain,
    required this.monotonyZone,
    required this.monotonyRecommendation,
    required this.available,
  });

  /// True when the engine actually produced load readings (zones populated).
  /// On a cold start the engine returns `data_status: ok` with blank zones —
  /// that is "not enough history yet", not a reading.
  bool get hasReadings =>
      available && (acwrZone.isNotEmpty || monotonyZone.isNotEmpty);

  factory LoadContext.fromJson(Map json) => LoadContext(
        acwr: (json['acwr'] as num?)?.toDouble() ?? 0.0,
        acwrZone: json['acwr_zone']?.toString() ?? '',
        acwrRecommendation: json['acwr_recommendation']?.toString() ?? '',
        monotony: (json['monotony'] as num?)?.toDouble() ?? 0.0,
        strain: (json['strain'] as num?)?.toDouble() ?? 0.0,
        monotonyZone: json['monotony_zone']?.toString() ?? '',
        monotonyRecommendation: json['monotony_recommendation']?.toString() ?? '',
        available: (json['data_status']?.toString() ?? '') == 'ok',
      );
}

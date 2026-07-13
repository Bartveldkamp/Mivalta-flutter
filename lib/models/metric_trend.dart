// Metric trend — Journey HRV / RHR trend surfaces.
//
// Display-only parse of `ViterbiEngine::hrv_trend()` / `rhr_trend()`: the
// engine's `MetricTrend` — three OLS-sloped windows (short/mid/long), each a
// `WindowTrend` with an engine-decided `direction` bucket and honest absence
// (`available: false`, direction `"insufficient_data"`) when the window lacks
// coverage. Engine bands are DRAFT (pending ratification) and the engine says
// so per-window via `draft`. Dart renders the engine's words; it never
// re-slopes, re-buckets, or fills.

class WindowTrend {
  final int windowDays;
  final bool available;
  final int nPoints;

  /// Engine-decided bucket label (e.g. improving/stable/declining family), or
  /// `insufficient_data` when the window can't be sloped honestly.
  final String direction;

  /// Engine's change-per-week in the metric's own unit, when available.
  final double? changePerWeek;

  /// 0..1 descriptive window coverage (the engine's, not a Dart judgment).
  final double confidence;

  /// True when the engine's classification bands are DRAFT.
  final bool draft;

  const WindowTrend({
    required this.windowDays,
    required this.available,
    required this.nPoints,
    required this.direction,
    required this.changePerWeek,
    required this.confidence,
    required this.draft,
  });

  factory WindowTrend.fromJson(dynamic json) {
    if (json is! Map) {
      return const WindowTrend(
        windowDays: 0,
        available: false,
        nPoints: 0,
        direction: 'insufficient_data',
        changePerWeek: null,
        confidence: 0,
        draft: false,
      );
    }
    return WindowTrend(
      windowDays: (json['window_days'] as num?)?.toInt() ?? 0,
      available: json['available'] == true,
      nPoints: (json['n_points'] as num?)?.toInt() ?? 0,
      direction: json['direction']?.toString() ?? 'insufficient_data',
      changePerWeek: (json['change_per_week'] as num?)?.toDouble(),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      draft: json['draft'] == true,
    );
  }
}

class MetricTrend {
  final String metric;
  final WindowTrend short;
  final WindowTrend mid;
  final WindowTrend long;

  const MetricTrend({
    required this.metric,
    required this.short,
    required this.mid,
    required this.long,
  });

  factory MetricTrend.fromJson(dynamic json) {
    if (json is! Map) {
      return MetricTrend(
        metric: '',
        short: WindowTrend.fromJson(null),
        mid: WindowTrend.fromJson(null),
        long: WindowTrend.fromJson(null),
      );
    }
    return MetricTrend(
      metric: json['metric']?.toString() ?? '',
      short: WindowTrend.fromJson(json['short']),
      mid: WindowTrend.fromJson(json['mid']),
      long: WindowTrend.fromJson(json['long']),
    );
  }

  /// True when no window can be sloped honestly — the whole trend row renders
  /// the honest-absence copy instead of three empty chips.
  bool get isInsufficient =>
      !short.available && !mid.available && !long.available;
}

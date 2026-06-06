// Aerobic decoupling model — Monitor analytics.
//
// Display-only. Maps `ViterbiEngine::recent_decoupling_pct(window_days)`, which
// returns `{"mean_decoupling_pct": <f64|null>}` — the trailing-window mean of
// HR decoupling (Pw:HR / Pa:HR drift). Lower = more aerobically durable.
// The engine computes each window mean; Flutter only displays the three windows
// side by side so the athlete can read short- vs long-term drift.

class DecouplingTrend {
  /// Trailing-window means, in percent. Null = no reading in that window.
  final double? short; // 7-day
  final double? mid; // 14-day
  final double? long; // 28-day

  const DecouplingTrend({this.short, this.mid, this.long});

  bool get hasData => short != null || mid != null || long != null;

  /// Parse one `{"mean_decoupling_pct": <f64|null>}` payload to a nullable
  /// double. Selection only — no computation.
  static double? parseMean(dynamic json) {
    if (json is Map) {
      final v = json['mean_decoupling_pct'];
      if (v is num) return v.toDouble();
    }
    return null;
  }
}

// Load Context model — for the Explore load/strain rollup.
//
// Display-only. Built from TWO canonical engine results (dashboard removal
// Phase 2 — replaces the DashboardEngine context widget): `ViterbiEngine::
// get_acwr()` (acute:chronic, Lolli 2019) + `get_monotony_strain()` (Foster
// monotony/strain), each with an engine-assigned zone and card-sourced
// recommendation prose. The engine computes everything; Dart only renders. No
// buckets summed in Dart — these ARE the engine's load rollup.

class LoadContext {
  final double acwr;
  final String acwrZone;
  final String acwrRecommendation;
  final double monotony;
  final double strain;
  final String monotonyZone;
  final String monotonyRecommendation;

  /// Whether the engine returned a result to render. The engines always return
  /// a result (the corrupt-vault case is handled upstream at engine construction
  /// via FL-3, not here) — a fetch error leaves `_loadContext` null, which the
  /// screen renders as its empty path. Kept for the card's display gate.
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

  /// True when the engine actually produced load readings. On a cold start the
  /// engine returns the honest-absence zone `"insufficient_data"` — that is "not
  /// enough history yet", not a reading (FLAG 2: gate on the engine's zone, not a
  /// dashboard data_status).
  bool get hasReadings {
    bool real(String z) => z.isNotEmpty && z != 'insufficient_data';
    return real(acwrZone) || real(monotonyZone);
  }

  /// Build from the two canonical engine payloads: `get_acwr()` (AcwrResult) and
  /// `get_monotony_strain()` (MonotonyStrainResult).
  factory LoadContext.fromEngine({
    required Map acwr,
    required Map monotony,
  }) =>
      LoadContext(
        acwr: (acwr['acwr'] as num?)?.toDouble() ?? 0.0,
        acwrZone: acwr['zone']?.toString() ?? '',
        acwrRecommendation: acwr['recommendation']?.toString() ?? '',
        monotony: (monotony['monotony'] as num?)?.toDouble() ?? 0.0,
        strain: (monotony['strain'] as num?)?.toDouble() ?? 0.0,
        monotonyZone: monotony['zone']?.toString() ?? '',
        monotonyRecommendation:
            monotony['recommendation']?.toString() ?? '',
        available: true,
      );
}

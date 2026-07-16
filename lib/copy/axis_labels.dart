// Shared axis-name humanizer — engine `readiness_indicator.contributions[]`
// axis field names → user-facing labels. LABEL layer only; the engine owns
// the axes and their values. The four names are the engine's
// `AxisContribution.name` literals (gatc-viterbi/src/readiness_blend.rs).
//
// Used by the Today why-unfold (widgets/today/why_unfold.dart)
// (founder feedback 2026-06-12 item 4: the why-tap shows which signals moved).

/// Humanize axis names for display. Engine field → user-friendly label.
/// Unknown names → null (honest absence: the caller renders '—' — B2, never
/// the raw engine id).
String? humanizeAxisName(String? name) {
  return switch ((name ?? '').toLowerCase()) {
    'hmm_posteriors' => 'Fatigue model',
    'banister' => 'Fitness & freshness',
    'physio_zscore' => 'Body signals',
    'psychological' => 'How you feel',
    _ => null,
  };
}

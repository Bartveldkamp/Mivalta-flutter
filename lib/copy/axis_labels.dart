// Shared axis-name humanizer — engine `readiness_indicator.contributions[]`
// axis field names → user-facing labels. LABEL layer only; the engine owns
// the axes and their values.
//
// Used by the readiness detail screen's axis breakdown and Josi's why-reveal
// (founder feedback 2026-06-12 item 4: the why-tap shows which signals moved).

/// Humanize axis names for display. Engine field → user-friendly label.
String humanizeAxisName(String? name) {
  return switch ((name ?? '').toLowerCase()) {
    'hmm_posteriors' => 'Fatigue model',
    'banister' => 'Fitness & freshness',
    'physio_zscore' => 'Body signals',
    'psychological' => 'How you feel',
    _ => name ?? '—',
  };
}

// Metabolic-level display labels — the SINGLE Dart-side mapping from the
// engine's level ids to athlete-facing names (LEVELS LAW,
// mivalta-rust-engine/docs/LEVELS_LAW.md: one vocabulary, engine-owned;
// Dart renders it and never re-derives). Extracted from WorkoutDetailScreen
// so Journey's recall rollup and the workout detail speak identically.
//
// Fixed physiological order (X1.1, DECISIONS Entry AD): base → neuro.

/// (engine level id, athlete-facing label), in fixed engine order.
const List<(String, String)> kMetabolicLevelLabels = [
  ('aerobic_base', 'Aerobic base'),
  ('aerobic_endurance', 'Aerobic endurance'),
  ('tempo', 'Tempo'),
  ('threshold', 'Threshold'),
  ('vo2max', 'VO₂max'),
  ('anaerobic_neuro', 'Anaerobic / neuro'),
];

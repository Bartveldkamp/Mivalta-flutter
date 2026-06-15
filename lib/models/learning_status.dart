// Display-side parse model for the "how well MiValta knows you yet" surface.
// Pure transport-of-truth: every field is a verbatim engine read from
// ViterbiEngine.personalization_diagnostics() + .validation_report(). No
// thresholds, no math, no fabricated progress — the engine OWNS the buckets;
// Dart only renders them. Missing input → honest nulls, never a stand-in.
//
// Sources (verified against gatc-viterbi):
//   personalization_diagnostics (JSON, or literal `null` before the first
//     observation): observation_count, confidence (low|medium|high),
//     hrv_windows? , hrv_episode?
//   validation_report (JSON ValidationReport): data_sufficiency
//     (insufficient|low|medium|high), paired_observations, period_days,
//     overall_model_score.

import 'dart:convert';

class LearningStatus {
  const LearningStatus({
    required this.observationCount,
    required this.confidenceBucket,
    required this.dataSufficiency,
    required this.pairedObservations,
    required this.periodDays,
    required this.overallModelScore,
    required this.hasHrvWindows,
  });

  /// personalization_diagnostics.observation_count — personal-baseline reading
  /// count (drives the population→personal handover). Null before the first
  /// observation (diagnostics JSON was `null`).
  final int? observationCount;

  /// personalization_diagnostics.confidence — engine's baseline-confidence
  /// bucket ("low" / "medium" / "high"). Null before the first observation.
  final String? confidenceBucket;

  /// validation_report.data_sufficiency — engine's verdict on whether the
  /// model is validated against THIS athlete's own outcomes:
  /// "insufficient" / "low" / "medium" / "high".
  final String dataSufficiency;

  /// validation_report.paired_observations — prediction↔outcome pairs behind
  /// the sufficiency bucket (the exact day count).
  final int pairedObservations;

  /// validation_report.period_days — the validation window length.
  final int periodDays;

  /// validation_report.overall_model_score (0..1). Only meaningful once
  /// validated — see [isValidated]; before that it is the engine's Default 0.
  final double overallModelScore;

  /// Whether the multi-scale HRV windows have begun (first HRV reading folded).
  final bool hasHrvWindows;

  /// The engine has begun building this athlete's personal baseline.
  bool get hasBegunLearning =>
      observationCount != null && observationCount! > 0;

  /// The model has earned enough paired outcomes to be validated for this
  /// athlete (engine's own bucket — not a Dart threshold).
  bool get isValidated => dataSufficiency != 'insufficient';

  /// Parse the two raw engine JSON strings. [diagnosticsJson] may be the
  /// literal `"null"` (no observations yet) → the personal fields are null,
  /// the honest "haven't started learning you" state.
  factory LearningStatus.parse({
    required String diagnosticsJson,
    required String validationJson,
  }) {
    final diag = jsonDecode(diagnosticsJson);
    final val = jsonDecode(validationJson);

    final diagMap = diag is Map<String, dynamic> ? diag : null;
    final valMap = val is Map<String, dynamic> ? val : const {};

    return LearningStatus(
      observationCount: (diagMap?['observation_count'] as num?)?.toInt(),
      confidenceBucket: diagMap?['confidence']?.toString(),
      hasHrvWindows: diagMap?['hrv_windows'] != null,
      dataSufficiency:
          (valMap['data_sufficiency']?.toString()) ?? 'insufficient',
      pairedObservations: (valMap['paired_observations'] as num?)?.toInt() ?? 0,
      periodDays: (valMap['period_days'] as num?)?.toInt() ?? 0,
      overallModelScore:
          (valMap['overall_model_score'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

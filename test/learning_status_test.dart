// Tests for the LearningStatus parse model — the "how well MiValta knows you
// yet" surface (engine gap #2). Pins the contract against the REAL engine JSON
// shapes (gatc-viterbi personalization_diagnostics + ValidationReport, snake_case,
// DataSufficiency lowercase) and the honest-absence behaviour when the engine
// has nothing yet (diagnostics == null).

import 'package:flutter_test/flutter_test.dart';
import 'package:mivalta_flutter/models/learning_status.dart';

void main() {
  group('LearningStatus.parse', () {
    test('diagnostics null + insufficient validation → honest "not started"',
        () {
      // personalization_diagnostics returns JSON `null` before the first
      // observation; validation_report defaults to insufficient.
      final s = LearningStatus.parse(
        diagnosticsJson: 'null',
        validationJson: '{"period_days":0,"paired_observations":0,'
            '"overall_model_score":0.0,"data_sufficiency":"insufficient"}',
      );
      expect(s.observationCount, isNull);
      expect(s.confidenceBucket, isNull);
      expect(s.hasBegunLearning, isFalse);
      expect(s.dataSufficiency, 'insufficient');
      expect(s.isValidated, isFalse);
      expect(s.pairedObservations, 0);
    });

    test('learning underway but not yet validated', () {
      final s = LearningStatus.parse(
        diagnosticsJson: '{"observation_count":9,"confidence":"low",'
            '"hrv_windows":null,"hrv_episode":null}',
        validationJson: '{"period_days":30,"paired_observations":9,'
            '"overall_model_score":0.0,"data_sufficiency":"insufficient"}',
      );
      expect(s.observationCount, 9);
      expect(s.confidenceBucket, 'low');
      expect(s.hasBegunLearning, isTrue);
      expect(s.hasHrvWindows, isFalse);
      expect(s.isValidated, isFalse);
      expect(s.pairedObservations, 9);
    });

    test('validated model surfaces the engine buckets verbatim', () {
      final s = LearningStatus.parse(
        diagnosticsJson: '{"observation_count":30,"confidence":"high",'
            '"hrv_windows":{"w7":1.0},"hrv_episode":null}',
        validationJson: '{"period_days":90,"paired_observations":42,'
            '"overall_model_score":0.78,"data_sufficiency":"medium"}',
      );
      expect(s.observationCount, 30);
      expect(s.confidenceBucket, 'high');
      expect(s.hasHrvWindows, isTrue);
      expect(s.dataSufficiency, 'medium');
      expect(s.isValidated, isTrue);
      expect(s.pairedObservations, 42);
      expect(s.periodDays, 90);
      expect(s.overallModelScore, closeTo(0.78, 1e-9));
    });

    test('missing validation fields fall back to honest zeros, not guesses',
        () {
      final s = LearningStatus.parse(
        diagnosticsJson: 'null',
        validationJson: '{}',
      );
      expect(s.dataSufficiency, 'insufficient');
      expect(s.pairedObservations, 0);
      expect(s.periodDays, 0);
      expect(s.overallModelScore, 0.0);
      expect(s.isValidated, isFalse);
    });
  });
}

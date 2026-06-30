// Tests for the fitness-trend model (UI tests stripped in clean-out).
//
// Contract guard: maps ViterbiEngine::fitness_series — `[{date, fitness,
// fatigue, form}]` — and the actuals overlay (read_metric_across_activities).

import 'package:flutter_test/flutter_test.dart';
import 'package:mivalta_flutter/models/fitness_trend.dart';
import 'package:mivalta_flutter/models/metric_series.dart';

void main() {
  group('FitnessTrend.fromJson', () {
    test('parses the engine bare array [{date,fitness,fatigue,form}]', () {
      final t = FitnessTrend.fromJson([
        {'date': '2026-06-01', 'fitness': 50.0, 'fatigue': 60.0, 'form': -10.0},
        {'date': '2026-06-02', 'fitness': 51.2, 'fatigue': 55.0, 'form': -3.8},
      ]);
      expect(t.samples.length, 2);
      expect(t.latest!.fitness, 51.2);
      expect(t.latest!.form, -3.8);
      expect(t.isEmpty, isFalse);
    });

    test('tolerates a {samples:[...]} envelope', () {
      final t = FitnessTrend.fromJson({
        'samples': [
          {'date': 'd1', 'fitness': 10, 'fatigue': 12, 'form': -2},
        ],
      });
      expect(t.samples.length, 1);
      expect(t.latest!.fitness, 10);
    });

    test('empty / malformed → safe empty', () {
      expect(FitnessTrend.fromJson(null).isEmpty, isTrue);
      expect(FitnessTrend.fromJson('nope').isEmpty, isTrue);
      expect(FitnessTrend.fromJson({'samples': 'bad'}).isEmpty, isTrue);
    });
  });

  group('MetricSeries.fromJson (actuals overlay)', () {
    test('parses dated values, skips null-value activities', () {
      final m = MetricSeries.fromJson([
        {'date': 'd1', 'value': 240.0, 'activity_id': 'a', 'activity_type': 'cycling'},
        {'date': 'd2', 'value': null, 'activity_id': 'b', 'activity_type': 'cycling'},
        {'date': 'd3', 'value': 255.0, 'activity_id': 'c', 'activity_type': 'cycling'},
      ]);
      expect(m.samples.length, 2); // null skipped
      expect(m.samples.first.value, 240.0);
      expect(m.isEmpty, isFalse);
    });

    test('non-list → empty', () {
      expect(MetricSeries.fromJson(null).isEmpty, isTrue);
    });
  });
}

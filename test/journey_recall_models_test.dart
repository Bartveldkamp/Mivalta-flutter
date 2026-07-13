// PR-C1 — Journey recall models, pinned against the engine wire shapes
// (traced 2026-07-13: MetabolicTimeInZone from metabolic_time_in_zone_rollup;
// MetricTrend/WindowTrend from hrv_trend/rhr_trend).

import 'package:flutter_test/flutter_test.dart';
import 'package:mivalta_flutter/models/metabolic_rollup.dart';
import 'package:mivalta_flutter/models/metric_trend.dart';

void main() {
  group('MetabolicRollup', () {
    test('parses engine seconds verbatim and orders rows physiologically', () {
      final r = MetabolicRollup.fromJson({
        'aerobic_base': 600.0,
        'aerobic_endurance': 3600.0,
        'tempo': 0.0,
        'threshold': 899.0, // 14.98 min → display rounds to 15
        'vo2max': 0.0,
        'anaerobic_neuro': 36.0,
        'unclassified': 12.0,
      });

      expect(r.isEmpty, isFalse);
      expect(r.nonZeroMinuteRows, [
        ('Aerobic base', 10),
        ('Aerobic endurance', 60),
        ('Threshold', 15),
        ('Anaerobic / neuro', 1),
      ]);
      expect(r.unclassifiedSeconds, 12.0);
    });

    test('all-zeros window is the engine honest absence, not a render', () {
      final r = MetabolicRollup.fromJson({
        'aerobic_base': 0,
        'aerobic_endurance': 0,
        'tempo': 0,
        'threshold': 0,
        'vo2max': 0,
        'anaerobic_neuro': 0,
        'unclassified': 0,
      });
      expect(r.isEmpty, isTrue);
      expect(r.nonZeroMinuteRows, isEmpty);
    });

    test('malformed payload degrades to empty, never throws', () {
      expect(MetabolicRollup.fromJson('nope').isEmpty, isTrue);
      expect(MetabolicRollup.fromJson(null).isEmpty, isTrue);
    });
  });

  group('MetricTrend', () {
    test('parses windows verbatim including the DRAFT flag', () {
      final t = MetricTrend.fromJson({
        'metric': 'hrv_rmssd',
        'short': {
          'window_days': 7,
          'available': true,
          'n_points': 6,
          'direction': 'declining',
          'change_per_week': -3.2,
          'confidence': 0.85,
          'draft': true,
        },
        'mid': {
          'window_days': 28,
          'available': false,
          'n_points': 4,
          'direction': 'insufficient_data',
          'confidence': 0.14,
        },
        'long': {
          'window_days': 90,
          'available': false,
          'n_points': 4,
          'direction': 'insufficient_data',
          'confidence': 0.04,
        },
      });

      expect(t.metric, 'hrv_rmssd');
      expect(t.short.available, isTrue);
      expect(t.short.direction, 'declining');
      expect(t.short.changePerWeek, -3.2);
      expect(t.short.draft, isTrue);
      expect(t.mid.available, isFalse);
      expect(t.mid.direction, 'insufficient_data');
      expect(t.isInsufficient, isFalse,
          reason: 'one honest window is enough to render the row');
    });

    test('all windows unavailable → isInsufficient (honest-absence copy)', () {
      final t = MetricTrend.fromJson({
        'metric': 'resting_hr',
        'short': {'available': false, 'direction': 'insufficient_data'},
        'mid': {'available': false, 'direction': 'insufficient_data'},
        'long': {'available': false, 'direction': 'insufficient_data'},
      });
      expect(t.isInsufficient, isTrue);
    });

    test('malformed payload degrades to insufficient, never throws', () {
      expect(MetricTrend.fromJson([]).isInsufficient, isTrue);
      expect(MetricTrend.fromJson(null).isInsufficient, isTrue);
    });
  });
}

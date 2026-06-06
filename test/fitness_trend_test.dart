// Tests for the fitness-trend model + chart.
//
// Contract guard: maps ViterbiEngine::fitness_series — `[{date, fitness,
// fatigue, form}]` — and the actuals overlay (read_metric_across_activities).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mivalta_flutter/models/fitness_trend.dart';
import 'package:mivalta_flutter/models/metric_series.dart';
import 'package:mivalta_flutter/widgets/analytics/fitness_trend_chart.dart';
import 'package:mivalta_flutter/theme/tokens.dart';

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

  group('FitnessTrendChart', () {
    testWidgets('renders title and latest fitness/fatigue/form', (tester) async {
      final trend = FitnessTrend.fromJson([
        {'date': 'd1', 'fitness': 48.0, 'fatigue': 40.0, 'form': 8.0},
        {'date': 'd2', 'fitness': 49.0, 'fatigue': 38.0, 'form': 11.0},
      ]);
      await tester.pumpWidget(MaterialApp(
        theme: mivaltaDarkTheme(),
        home: Scaffold(body: FitnessTrendChart(trend: trend)),
      ));
      expect(find.text('Fitness development'), findsOneWidget);
      expect(find.text('Fitness'), findsOneWidget);
      expect(find.text('49'), findsOneWidget); // latest fitness rounded
      expect(find.text('11'), findsOneWidget); // latest form rounded
    });

    testWidgets('with overlay shows the measured legend', (tester) async {
      final trend = FitnessTrend.fromJson([
        {'date': '2026-06-01', 'fitness': 48.0, 'fatigue': 40.0, 'form': 8.0},
        {'date': '2026-06-10', 'fitness': 49.0, 'fatigue': 38.0, 'form': 11.0},
      ]);
      final overlay = MetricSeries.fromJson([
        {'date': '2026-06-05', 'value': 250.0},
      ]);
      await tester.pumpWidget(MaterialApp(
        theme: mivaltaDarkTheme(),
        home: Scaffold(
          body: FitnessTrendChart(
            trend: trend,
            overlay: overlay,
            overlayLabel: 'Actual watts',
          ),
        ),
      ));
      expect(find.text('Actual watts (measured, secondary scale)'), findsOneWidget);
    });

    testWidgets('empty trend → honest empty state, no crash', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: mivaltaDarkTheme(),
        home: const Scaffold(body: FitnessTrendChart(trend: FitnessTrend(samples: []))),
      ));
      expect(find.text('Fitness development'), findsOneWidget);
      expect(find.text('Not enough training history yet.'), findsOneWidget);
    });
  });
}

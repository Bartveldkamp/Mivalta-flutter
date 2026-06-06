// Tests for the Fitness Development (PMC) model + chart.
//
// Contract guard: maps the engine Banister output (CTL/ATL/TSB + form_zone).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mivalta_flutter/models/fitness_trend.dart';
import 'package:mivalta_flutter/widgets/analytics/fitness_trend_chart.dart';
import 'package:mivalta_flutter/theme/tokens.dart';

void main() {
  group('FitnessTrend.fromJson', () {
    test('parses {samples, form_zone}', () {
      final t = FitnessTrend.fromJson({
        'form_zone': 'productive',
        'samples': [
          {'date': '2026-06-01', 'ctl': 50.0, 'atl': 60.0, 'tsb': -10.0},
          {'date': '2026-06-02', 'ctl': 51.2, 'atl': 55.0, 'tsb': -3.8},
        ],
      });
      expect(t.formZone, 'productive');
      expect(t.samples.length, 2);
      expect(t.latest!.ctl, 51.2);
      expect(t.latest!.tsb, -3.8);
      expect(t.isEmpty, isFalse);
    });

    test('parses a bare list', () {
      final t = FitnessTrend.fromJson([
        {'date': 'd1', 'ctl': 10, 'atl': 12, 'tsb': -2},
      ]);
      expect(t.samples.length, 1);
      expect(t.latest!.ctl, 10);
      expect(t.formZone, isNull);
    });

    test('empty / malformed → safe empty', () {
      expect(FitnessTrend.fromJson(null).isEmpty, isTrue);
      expect(FitnessTrend.fromJson('nope').isEmpty, isTrue);
      expect(FitnessTrend.fromJson({'samples': 'bad'}).isEmpty, isTrue);
    });
  });

  group('FitnessTrendChart', () {
    testWidgets('renders title, form zone, and latest CTL/ATL/TSB', (tester) async {
      final trend = FitnessTrend.fromJson({
        'form_zone': 'fresh',
        'samples': [
          {'date': 'd1', 'ctl': 48.0, 'atl': 40.0, 'tsb': 8.0},
          {'date': 'd2', 'ctl': 49.0, 'atl': 38.0, 'tsb': 11.0},
        ],
      });
      await tester.pumpWidget(MaterialApp(
        theme: mivaltaDarkTheme(),
        home: Scaffold(body: FitnessTrendChart(trend: trend)),
      ));
      expect(find.text('Fitness development'), findsOneWidget);
      expect(find.text('fresh'), findsOneWidget);
      expect(find.text('Fitness (CTL)'), findsOneWidget);
      expect(find.text('49'), findsOneWidget); // latest CTL rounded
      expect(find.text('11'), findsOneWidget); // latest TSB rounded
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

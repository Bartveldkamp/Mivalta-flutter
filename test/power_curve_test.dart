// Tests for the Power Curve (MMP) model + chart.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mivalta_flutter/models/power_curve.dart';
import 'package:mivalta_flutter/widgets/analytics/power_curve_chart.dart';
import 'package:mivalta_flutter/theme/tokens.dart';

void main() {
  group('PowerCurve.fromJson', () {
    test('parses MmpCurve {points:[{duration_seconds, max_power_watts}]}', () {
      final c = PowerCurve.fromJson({
        'points': [
          {'duration_seconds': 5, 'max_power_watts': 900.0},
          {'duration_seconds': 60, 'max_power_watts': 500.0},
          {'duration_seconds': 1200, 'max_power_watts': 300.0},
        ],
      });
      expect(c.points.length, 3);
      expect(c.isEmpty, isFalse);
      expect(c.nearest(60)!.maxPowerWatts, 500.0);
      // nearest snaps to the closest duration
      expect(c.nearest(1000)!.durationSeconds, 1200);
    });

    test('bare list + malformed', () {
      expect(PowerCurve.fromJson([{'duration_seconds': 1, 'max_power_watts': 10}]).points.length, 1);
      expect(PowerCurve.fromJson(null).isEmpty, isTrue);
      expect(PowerCurve.fromJson('x').isEmpty, isTrue);
      expect(PowerCurve.fromJson({'points': 'bad'}).isEmpty, isTrue);
    });
  });

  group('PowerCurveChart', () {
    testWidgets('renders title + peak readouts from engine values', (tester) async {
      final curve = PowerCurve.fromJson({
        'points': [
          {'duration_seconds': 5, 'max_power_watts': 950.0},
          {'duration_seconds': 60, 'max_power_watts': 480.0},
          {'duration_seconds': 300, 'max_power_watts': 360.0},
          {'duration_seconds': 1200, 'max_power_watts': 295.0},
          {'duration_seconds': 3600, 'max_power_watts': 255.0},
        ],
      });
      await tester.pumpWidget(MaterialApp(
        theme: mivaltaDarkTheme(),
        home: Scaffold(body: PowerCurveChart(curve: curve)),
      ));
      expect(find.text('Power profile'), findsOneWidget);
      expect(find.text('5s'), findsOneWidget);
      expect(find.text('950W'), findsOneWidget); // 5s peak
      expect(find.text('255W'), findsOneWidget); // 60min peak
    });

    testWidgets('empty → honest empty, no crash', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: mivaltaDarkTheme(),
        home: const Scaffold(body: PowerCurveChart(curve: PowerCurve(points: []))),
      ));
      expect(find.text('No power data yet.'), findsOneWidget);
    });
  });
}

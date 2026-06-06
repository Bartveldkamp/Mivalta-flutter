// Tests for the BiometricSeries model + BiometricChart (Explore biometrics).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mivalta_flutter/models/biometric_series.dart';
import 'package:mivalta_flutter/widgets/analytics/biometric_chart.dart';
import 'package:mivalta_flutter/theme/tokens.dart';

void main() {
  group('BiometricSeries.fromHistory', () {
    final history = [
      {'date': '2026-06-03', 'resting_hr': 52, 'hrv_rmssd': 45.0},
      {'date': '2026-06-01', 'resting_hr': 50},
      {'date': '2026-06-02', 'hrv_rmssd': 40.0}, // no resting_hr
    ];

    test('extracts the chosen metric, ascending, drops missing readings', () {
      final rhr = BiometricSeries.fromHistory(history, BiometricMetric.restingHr);
      expect(rhr.points.length, 2); // 06-01, 06-03 have resting_hr
      expect(rhr.values, [50.0, 52.0]);
      expect(rhr.latest, 52.0);
      expect(rhr.metric.label, 'Resting HR');
    });

    test('empty / malformed → isEmpty', () {
      expect(BiometricSeries.fromHistory(null, BiometricMetric.hrv).isEmpty, isTrue);
      expect(BiometricSeries.fromHistory('x', BiometricMetric.sleep).isEmpty, isTrue);
      expect(BiometricSeries.fromHistory(const [], BiometricMetric.restingHr).isEmpty,
          isTrue);
    });
  });

  group('BiometricChart', () {
    testWidgets('renders metric label + latest value with unit', (tester) async {
      final s = BiometricSeries.fromHistory([
        {'date': '2026-06-01', 'resting_hr': 50},
        {'date': '2026-06-02', 'resting_hr': 52},
      ], BiometricMetric.restingHr);
      await tester.pumpWidget(MaterialApp(
        theme: mivaltaDarkTheme(),
        home: Scaffold(body: BiometricChart(series: s)),
      ));
      expect(find.text('RESTING HR'), findsOneWidget);
      expect(find.text('52 bpm'), findsOneWidget); // latest, whole number + unit
    });

    testWidgets('empty range → honest empty', (tester) async {
      final s = BiometricSeries.fromHistory(const [], BiometricMetric.sleep);
      await tester.pumpWidget(MaterialApp(
        theme: mivaltaDarkTheme(),
        home: Scaffold(body: BiometricChart(series: s)),
      ));
      expect(find.text('No Sleep data in this range.'), findsOneWidget);
    });
  });
}

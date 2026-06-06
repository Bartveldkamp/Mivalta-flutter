// Tests for the Sleep Trend model + card.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mivalta_flutter/models/sleep_trend.dart';
import 'package:mivalta_flutter/widgets/analytics/sleep_trend_card.dart';
import 'package:mivalta_flutter/theme/tokens.dart';

void main() {
  group('SleepTrend.fromJson', () {
    test('keeps only nights with sleep_hours, ascending; latest is newest', () {
      final t = SleepTrend.fromJson([
        {'date': '2026-06-03', 'sleep_hours': 7.5},
        {'date': '2026-06-01', 'sleep_hours': 6.0},
        {'date': '2026-06-02', 'resting_hr': 55}, // no sleep_hours → dropped
        {'date': '2026-06-04', 'sleep_hours': 8.0},
      ]);
      expect(t.nights.length, 3);
      expect(t.isEmpty, isFalse);
      expect(t.latestHours, 8.0); // 2026-06-04
      expect(t.series, [6.0, 7.5, 8.0]); // ascending by date
    });

    test('empty / malformed → isEmpty, no fabrication', () {
      expect(SleepTrend.fromJson(null).isEmpty, isTrue);
      expect(SleepTrend.fromJson('x').isEmpty, isTrue);
      expect(SleepTrend.fromJson(const []).isEmpty, isTrue);
      expect(SleepTrend.fromJson([
        {'date': '2026-06-01'} // no hours
      ]).isEmpty, isTrue);
    });
  });

  group('SleepTrendCard', () {
    testWidgets('renders latest sleep + nights count', (tester) async {
      final t = SleepTrend.fromJson([
        {'date': '2026-06-01', 'sleep_hours': 6.0},
        {'date': '2026-06-02', 'sleep_hours': 7.2},
        {'date': '2026-06-03', 'sleep_hours': 7.5},
      ]);
      await tester.pumpWidget(MaterialApp(
        theme: mivaltaDarkTheme(),
        home: Scaffold(body: SleepTrendCard(trend: t)),
      ));
      expect(find.text('SLEEP'), findsOneWidget);
      expect(find.text('7.5'), findsOneWidget); // latest night, 1 decimal
      expect(find.text('3 nights'), findsOneWidget);
    });

    testWidgets('empty → honest empty, no crash', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: mivaltaDarkTheme(),
        home: const Scaffold(body: SleepTrendCard(trend: SleepTrend(nights: []))),
      ));
      expect(find.text('No sleep data yet.'), findsOneWidget);
    });
  });
}

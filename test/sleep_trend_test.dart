// Tests for the Sleep Trend model (UI tests stripped in clean-out).

import 'package:flutter_test/flutter_test.dart';
import 'package:mivalta_flutter/models/sleep_trend.dart';

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
}

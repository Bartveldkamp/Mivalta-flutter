// Tests for the ActivitySummary model (Explore workout list).

import 'package:flutter_test/flutter_test.dart';
import 'package:mivalta_flutter/models/activity_summary.dart';

void main() {
  group('ActivitySummary.listFromJson', () {
    test('maps VaultActivity rows; drops rows without a date', () {
      final list = ActivitySummary.listFromJson([
        {
          'id': 'a1',
          'date': '2026-06-04',
          'activity_type': 'cycling',
          'duration_minutes': 60.0,
          'avg_heart_rate': 142,
          'load_uls': 85.0,
        },
        {'id': 'a2', 'activity_type': 'running'}, // no date → dropped
      ]);
      expect(list.length, 1);
      expect(list.first.sport, 'cycling');
      expect(list.first.durationMin, 60);
      expect(list.first.avgHr, 142);
      expect(list.first.loadUls, 85.0);
    });

    test('non-list → empty', () {
      expect(ActivitySummary.listFromJson(null), isEmpty);
      expect(ActivitySummary.listFromJson('x'), isEmpty);
    });
  });
}

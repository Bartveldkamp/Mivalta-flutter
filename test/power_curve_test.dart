// Tests for the Power Curve (MMP) model (UI tests stripped in clean-out).

import 'package:flutter_test/flutter_test.dart';
import 'package:mivalta_flutter/models/power_curve.dart';

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
}

// Pins the consumer zone-label map (F-ZONE, founder check 2026-06-15) to the
// engine's energy-SYSTEM assignment, not the Coggan zone-number ladder. The
// engine numbering is shifted (VO2max at Z4/Z5, threshold at Z3), so these
// assertions guard against silently reintroducing number→Coggan-name mislabels.

import 'package:flutter_test/flutter_test.dart';
import 'package:mivalta_flutter/copy/zone_labels.dart';

void main() {
  group('zoneLabel — engine-system-true naming', () {
    test('maps each engine zone to its energy-system label', () {
      expect(zoneLabel('R'), 'Recovery');
      expect(zoneLabel('Z1'), 'Endurance');
      expect(zoneLabel('Z2'), 'Endurance');
      expect(zoneLabel('Z3'), 'Threshold');
      // The engine puts VO2max at Z4/Z5 (aerobic_power) — NOT "Threshold".
      expect(zoneLabel('Z4'), 'VO2 Max');
      expect(zoneLabel('Z5'), 'VO2 Max');
      expect(zoneLabel('Z6'), 'Anaerobic');
      expect(zoneLabel('Z7'), 'Sprint');
      expect(zoneLabel('Z8'), 'Sprint');
    });

    test('is case-insensitive and trims', () {
      expect(zoneLabel('z4'), 'VO2 Max');
      expect(zoneLabel(' Z2 '), 'Endurance');
    });

    test('unknown / empty / null → null (never a raw code on screen)', () {
      expect(zoneLabel(null), isNull);
      expect(zoneLabel(''), isNull);
      expect(zoneLabel('Z9'), isNull);
      expect(zoneLabel('insufficient_data'), isNull);
    });
  });

  group('zoneCapLabel — "what is available today" chip', () {
    test('phrases the cap by system, recovery as a floor', () {
      expect(zoneCapLabel('Z8'), 'Up to Sprint');
      expect(zoneCapLabel('Z4'), 'Up to VO2 Max');
      expect(zoneCapLabel('Z2'), 'Up to Endurance');
      expect(zoneCapLabel('R'), 'Recovery only');
    });

    test('unknown → null so the chip is omitted, not shown raw', () {
      expect(zoneCapLabel(null), isNull);
      expect(zoneCapLabel('Z9'), isNull);
    });
  });
}

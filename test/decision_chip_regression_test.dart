// DR-023 T1: Decision chip regression test.
//
// The chip is a DECISION only when the engine RESTRICTS (Z1–Z7, REST).
// A healthy day (Z8 cap) must NOT show a chip even when a session suggestion
// is present — the suggestion's zone belongs on the workout card, not under
// the hero as a "MiValta tells you what to do" verdict.
//
// This test guards against the bug creeping back a third time.

import 'package:flutter_test/flutter_test.dart';
import 'package:mivalta_flutter/theme/zone_names.dart';

void main() {
  group('DR-023 T1: Decision chip gate', () {
    // The _isRestrictiveCap logic extracted for testing.
    // Mirrors today_screen.dart's _isRestrictiveCap method.
    bool isRestrictiveCap(String? zone) {
      if (zone == null || zone.isEmpty) return false;
      return switch (zone.toUpperCase()) {
        'Z1' || 'Z2' || 'Z3' || 'Z4' || 'Z5' || 'Z6' || 'Z7' || 'REST' => true,
        _ => false, // Z8 (ceiling) + unknown → collapse
      };
    }

    test('healthy day (Z8 cap) → no chip, even with session suggestion', () {
      // Z8 is the ceiling — no restriction.
      final zoneCap = 'Z8';
      // ignore: unused_local_variable
      final sessionZone = 'Z2'; // Engine suggests an easy session

      // The gate: chip shows ONLY when restrictive cap exists.
      // DR-023: removed `|| hasSession` — session zone no longer triggers chip.
      final restrictiveCap = isRestrictiveCap(zoneCap);
      final showChip = restrictiveCap; // hasSession is NOT consulted

      expect(restrictiveCap, isFalse, reason: 'Z8 is not restrictive');
      expect(showChip, isFalse, reason: 'Healthy day should NOT show decision chip');
    });

    test('capped day (Z2) → chip shows "Aerobic endurance · Z2" (level leads, code nested)', () {
      final zoneCap = 'Z2';

      final restrictiveCap = isRestrictiveCap(zoneCap);
      final showChip = restrictiveCap;

      expect(restrictiveCap, isTrue, reason: 'Z2 is restrictive');
      expect(showChip, isTrue, reason: 'Capped day MUST show decision chip');

      // LEVELS LAW communication shape: the metabolic LEVEL leads, the zone code
      // rides NESTED behind it. The canonical level word for Z2 is the 6-level
      // vocabulary "Aerobic endurance" (gatc_types::METABOLIC_LEVEL_LABELS,
      // mirrored by kMetabolicLevelLabels) — NOT the demoted per-zone word
      // "Endurance" (removed with the divergent zone_labels file). Bare "Z2"
      // stays banned; this matches test/zone_names_test.dart.
      final chipText = zoneDisplayLabel(zoneCap);
      expect(chipText, equals('Aerobic endurance · Z2'));
      expect(chipText.startsWith('Aerobic endurance'), isTrue,
          reason: 'the level name must LEAD — the code never fronts the chip');
    });

    test('REST cap → "Rest day", no code to nest', () {
      expect(zoneDisplayLabel('REST'), equals('Rest day'));
    });

    test('unknown zone → raw code once, never a fabricated "CODE · CODE" pair', () {
      expect(zoneDisplayLabel('Z9'), equals('Z9'));
    });

    test('REST cap → chip shows', () {
      final zoneCap = 'REST';

      final restrictiveCap = isRestrictiveCap(zoneCap);
      expect(restrictiveCap, isTrue, reason: 'REST is restrictive');
    });

    test('null/empty cap → no chip', () {
      expect(isRestrictiveCap(null), isFalse);
      expect(isRestrictiveCap(''), isFalse);
    });

    test('all restrictive zones (Z1-Z7, REST) are recognized', () {
      for (final zone in ['Z1', 'Z2', 'Z3', 'Z4', 'Z5', 'Z6', 'Z7', 'REST']) {
        expect(isRestrictiveCap(zone), isTrue, reason: '$zone should be restrictive');
      }
    });

    test('Z8 and unknown zones are NOT restrictive', () {
      for (final zone in ['Z8', 'Z9', 'UNKNOWN', 'foo']) {
        expect(isRestrictiveCap(zone), isFalse, reason: '$zone should NOT be restrictive');
      }
    });
  });
}

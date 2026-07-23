// LEVELS LAW (founder 2026-07-18, Option 1): zone display renders the engine's
// SIX metabolic-level words ONLY, level leading + zone code nested. Z6/Z7/Z8 all
// read "Anaerobic / neuro". The former per-zone vocabulary (Recovery/Anaerobic/
// Neuromuscular/Max power) is gone.

import 'package:flutter_test/flutter_test.dart';
import 'package:mivalta_flutter/theme/zone_names.dart';

void main() {
  group('zoneDisplayLabel — 6-level vocabulary, level leads, code nested', () {
    test('every training zone leads with its metabolic level, code nested', () {
      expect(zoneDisplayLabel('Z1'), 'Aerobic base · Z1');
      expect(zoneDisplayLabel('Z2'), 'Aerobic endurance · Z2');
      expect(zoneDisplayLabel('Z3'), 'Tempo · Z3');
      expect(zoneDisplayLabel('Z4'), 'Threshold · Z4');
      expect(zoneDisplayLabel('Z5'), 'VO₂max · Z5');
      // Z6/Z7/Z8 collapse to the single engine level (Option 1).
      expect(zoneDisplayLabel('Z6'), 'Anaerobic / neuro · Z6');
      expect(zoneDisplayLabel('Z7'), 'Anaerobic / neuro · Z7');
      expect(zoneDisplayLabel('Z8'), 'Anaerobic / neuro · Z8');
      expect(zoneDisplayLabel('R'), 'Aerobic base · R');
    });

    test('lowercase input still leads with the level (case-insensitive)', () {
      expect(zoneDisplayLabel('z4'), 'Threshold · Z4');
    });

    test('rest markers render a plain day word, no code', () {
      expect(zoneDisplayLabel('REST'), 'Rest day');
      expect(zoneDisplayLabel('OFF'), 'Rest day');
    });

    test('unknown zone fails visible — raw code once, never CODE · CODE', () {
      expect(zoneDisplayLabel('Z9'), 'Z9');
    });

    test('the removed per-zone vocabulary never appears', () {
      for (final z in ['Z1', 'Z2', 'Z3', 'Z4', 'Z5', 'Z6', 'Z7', 'Z8', 'R']) {
        final out = zoneDisplayLabel(z);
        for (final demoted in [
          'Recovery',
          'Endurance',
          'Anaerobic ·', // the old bare "Anaerobic" word (not "Anaerobic / neuro")
          'Neuromuscular',
          'Max power',
        ]) {
          expect(out.contains(demoted), isFalse,
              reason: '$z → "$out" must not carry the removed word "$demoted"');
        }
      }
    });
  });
}

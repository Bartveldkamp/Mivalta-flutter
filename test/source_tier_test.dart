// Regression guard on the LOCKED SourceTier color tokens. CLAUDE.md
// flags any drift here as a finding; this test fails the build
// immediately if a hex value changes.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mivalta_flutter/theme/source_tier.dart';

void main() {
  group('SourceTier locked tokens', () {
    test('the const map exposes exactly the four tiers', () {
      expect(kSourceTierHex.keys.toSet(), SourceTier.values.toSet());
      expect(kSourceTierHex.length, 4);
    });

    test('hex values match CLAUDE.md exactly', () {
      // Each entry is asserted explicitly so a drift produces a
      // line-level diff in the failure output.
      expect(kSourceTierHex[SourceTier.medical], 0xFF2BD974);
      expect(kSourceTierHex[SourceTier.device], 0xFF00C6A7);
      expect(kSourceTierHex[SourceTier.partial], 0xFFE6872F);
      expect(kSourceTierHex[SourceTier.manual], 0xFF878C8C);
    });

    test('Flutter Color projection is identity over the hex token', () {
      for (final tier in SourceTier.values) {
        final hex = kSourceTierHex[tier]!;
        final color = kSourceTierColor[tier]!;
        expect(color, Color(hex), reason: '$tier');
      }
    });

    test('Display labels match the engine Display impl', () {
      expect(kSourceTierLabel[SourceTier.medical], 'Medical (A)');
      expect(kSourceTierLabel[SourceTier.device], 'Device (B)');
      expect(kSourceTierLabel[SourceTier.partial], 'Partial (C)');
      expect(kSourceTierLabel[SourceTier.manual], 'Manual (D)');
    });
  });

  group('sourceTierFromEngine', () {
    test('maps each PascalCase engine variant to the enum', () {
      expect(sourceTierFromEngine('Medical'), SourceTier.medical);
      expect(sourceTierFromEngine('Device'), SourceTier.device);
      expect(sourceTierFromEngine('Partial'), SourceTier.partial);
      expect(sourceTierFromEngine('Manual'), SourceTier.manual);
    });

    test('returns null for the engine null sentinel', () {
      // VaultEngine::last_observation_source_tier emits JSON null
      // when no biometric exists; jsonDecode produces Dart null.
      expect(sourceTierFromEngine(null), isNull);
    });

    test('returns null for unknown strings or wrong types', () {
      expect(sourceTierFromEngine(''), isNull);
      expect(sourceTierFromEngine('medical'), isNull); // wrong case
      expect(sourceTierFromEngine('Medical (A)'), isNull); // label, not variant
      expect(sourceTierFromEngine(0), isNull);
      expect(sourceTierFromEngine(<String, Object?>{}), isNull);
    });
  });
}

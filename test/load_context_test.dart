// Tests for the LoadContext model (UI tests stripped in clean-out).
// Dashboard removal Phase 2: LoadContext is built from the two canonical engine
// results (get_acwr + get_monotony_strain); honest-absence is the engine's
// "insufficient_data" zone (FLAG 2), not a dashboard data_status.

import 'package:flutter_test/flutter_test.dart';
import 'package:mivalta_flutter/models/load_context.dart';

void main() {
  group('LoadContext.fromEngine', () {
    test('parses get_acwr + get_monotony_strain; hasReadings on real zones', () {
      final c = LoadContext.fromEngine(
        acwr: {
          'acwr': 1.25,
          'zone': 'optimal',
          'recommendation': 'Load is balanced.',
        },
        monotony: {
          'monotony': 1.8,
          'strain': 420.0,
          'zone': 'caution',
          'recommendation': 'Vary your training.',
        },
      );
      expect(c.available, isTrue);
      expect(c.hasReadings, isTrue);
      expect(c.acwr, 1.25);
      expect(c.acwrZone, 'optimal');
      expect(c.strain, 420.0);
      expect(c.monotonyZone, 'caution');
    });

    test('insufficient_data zones → available, not hasReadings (cold start)', () {
      final c = LoadContext.fromEngine(
        acwr: {'zone': 'insufficient_data'},
        monotony: {'zone': 'insufficient_data'},
      );
      expect(c.available, isTrue);
      expect(c.hasReadings, isFalse);
    });
  });
}

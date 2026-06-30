// Tests for the aerobic-decoupling model (UI tests stripped in clean-out).
//
// Contract guard: maps ViterbiEngine::recent_decoupling_pct JSON
// `{"mean_decoupling_pct": <f64|null>}`.

import 'package:flutter_test/flutter_test.dart';
import 'package:mivalta_flutter/models/decoupling_trend.dart';

void main() {
  group('DecouplingTrend.parseMean', () {
    test('reads mean_decoupling_pct number', () {
      expect(DecouplingTrend.parseMean({'mean_decoupling_pct': 5.2}), 5.2);
      expect(DecouplingTrend.parseMean({'mean_decoupling_pct': 0}), 0.0);
    });

    test('null reading / malformed → null (no fabrication)', () {
      expect(DecouplingTrend.parseMean({'mean_decoupling_pct': null}), isNull);
      expect(DecouplingTrend.parseMean({}), isNull);
      expect(DecouplingTrend.parseMean(null), isNull);
      expect(DecouplingTrend.parseMean('x'), isNull);
    });

    test('hasData reflects any non-null window', () {
      expect(const DecouplingTrend().hasData, isFalse);
      expect(const DecouplingTrend(mid: 4.0).hasData, isTrue);
    });
  });
}

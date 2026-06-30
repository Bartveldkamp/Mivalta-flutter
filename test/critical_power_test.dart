// Tests for the Critical Power (CP + W′) model (UI tests stripped in clean-out).

import 'package:flutter_test/flutter_test.dart';
import 'package:mivalta_flutter/models/critical_power.dart';

void main() {
  group('CriticalPower.fromJson', () {
    test('parses CpFit {cp_watts, w_prime_joules, r_squared, n_points}', () {
      final cp = CriticalPower.fromJson({
        'cp_watts': 248.6,
        'w_prime_joules': 21400.0,
        'r_squared': 0.985,
        'n_points': 5,
      });
      expect(cp.cpWatts, closeTo(248.6, 1e-9));
      expect(cp.wPrimeKj, closeTo(21.4, 1e-9));
      expect(cp.nPoints, 5);
      expect(cp.isEmpty, isFalse);
    });

    test('empty / malformed → isEmpty, no fabrication', () {
      expect(CriticalPower.fromJson(null).isEmpty, isTrue);
      expect(CriticalPower.fromJson('x').isEmpty, isTrue);
      expect(CriticalPower.fromJson({'cp_watts': 0, 'n_points': 0}).isEmpty, isTrue);
      // a non-physical CP (<=0) with points is still treated as no usable fit
      expect(
        CriticalPower.fromJson({
          'cp_watts': 0,
          'w_prime_joules': 100,
          'r_squared': 0.5,
          'n_points': 4,
        }).isEmpty,
        isTrue,
      );
    });
  });
}

// Tests for the Critical Power (CP + W′) model + card.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mivalta_flutter/models/critical_power.dart';
import 'package:mivalta_flutter/widgets/analytics/critical_power_card.dart';
import 'package:mivalta_flutter/theme/tokens.dart';

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

  group('CriticalPowerCard', () {
    testWidgets('renders CP headline + reserve from engine values', (tester) async {
      final cp = CriticalPower.fromJson({
        'cp_watts': 249.0,
        'w_prime_joules': 21400.0,
        'r_squared': 0.98,
        'n_points': 5,
      });
      await tester.pumpWidget(MaterialApp(
        theme: mivaltaDarkTheme(),
        home: Scaffold(body: CriticalPowerCard(cp: cp)),
      ));
      expect(find.text('CRITICAL POWER'), findsOneWidget);
      expect(find.text('249'), findsOneWidget); // CP watts, rounded
      expect(find.text('21.4 kJ'), findsOneWidget); // W′ reserve
      expect(find.text('r² 0.98'), findsOneWidget); // fit quality
    });

    testWidgets('empty → honest empty, no crash', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: mivaltaDarkTheme(),
        home: const Scaffold(
          body: CriticalPowerCard(
            cp: CriticalPower(cpWatts: 0, wPrimeJoules: 0, rSquared: 0, nPoints: 0),
          ),
        ),
      ));
      expect(find.text('No power data yet.'), findsOneWidget);
    });
  });
}

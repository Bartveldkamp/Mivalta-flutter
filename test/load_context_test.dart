// Tests for the LoadContext model + LoadStrainCard (Explore load/strain rollup).
// Dashboard removal Phase 2: LoadContext is built from the two canonical engine
// results (get_acwr + get_monotony_strain); honest-absence is the engine's
// "insufficient_data" zone (FLAG 2), not a dashboard data_status.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mivalta_flutter/models/load_context.dart';
import 'package:mivalta_flutter/widgets/analytics/load_strain_card.dart';
import 'package:mivalta_flutter/theme/tokens.dart';

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

  group('LoadStrainCard', () {
    Future<void> pump(WidgetTester tester, LoadContext c) => tester.pumpWidget(
          MaterialApp(
            theme: mivaltaDarkTheme(),
            home: Scaffold(body: LoadStrainCard(context_: c)),
          ),
        );

    testWidgets('renders ACWR/monotony/strain + recommendation', (tester) async {
      await pump(
        tester,
        LoadContext.fromEngine(
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
        ),
      );
      expect(find.text('1.25'), findsOneWidget); // ACWR, 2 dp
      expect(find.text('1.80'), findsOneWidget); // monotony, 2 dp
      expect(find.text('420'), findsOneWidget); // strain, rounded
      expect(find.text('Vary your training.'), findsOneWidget);
    });

    testWidgets('cold start (insufficient_data) → not-enough-history copy',
        (tester) async {
      await pump(
        tester,
        LoadContext.fromEngine(
          acwr: {'zone': 'insufficient_data'},
          monotony: {'zone': 'insufficient_data'},
        ),
      );
      expect(find.text('Not enough training history yet.'), findsOneWidget);
    });
  });
}

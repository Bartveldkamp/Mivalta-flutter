// Tests for the LoadContext model + LoadStrainCard (Explore load/strain rollup).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mivalta_flutter/models/load_context.dart';
import 'package:mivalta_flutter/widgets/analytics/load_strain_card.dart';
import 'package:mivalta_flutter/theme/tokens.dart';

void main() {
  group('LoadContext.fromJson', () {
    test('parses the engine context widget; available + hasReadings', () {
      final c = LoadContext.fromJson({
        'acwr': 1.25,
        'acwr_zone': 'optimal',
        'acwr_recommendation': 'Load is balanced.',
        'monotony': 1.8,
        'strain': 420.0,
        'monotony_zone': 'caution',
        'monotony_recommendation': 'Vary your training.',
        'data_status': 'ok',
      });
      expect(c.available, isTrue);
      expect(c.hasReadings, isTrue);
      expect(c.acwr, 1.25);
      expect(c.acwrZone, 'optimal');
      expect(c.strain, 420.0);
      expect(c.monotonyZone, 'caution');
    });

    test('ok but blank zones → available, not hasReadings (cold start)', () {
      final c = LoadContext.fromJson({'data_status': 'ok'});
      expect(c.available, isTrue);
      expect(c.hasReadings, isFalse);
    });

    test('state_unavailable → not available', () {
      final c = LoadContext.fromJson({'data_status': 'state_unavailable'});
      expect(c.available, isFalse);
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
        LoadContext.fromJson({
          'acwr': 1.25,
          'acwr_zone': 'optimal',
          'acwr_recommendation': 'Load is balanced.',
          'monotony': 1.8,
          'strain': 420.0,
          'monotony_zone': 'caution',
          'monotony_recommendation': 'Vary your training.',
          'data_status': 'ok',
        }),
      );
      expect(find.text('1.25'), findsOneWidget); // ACWR, 2 dp
      expect(find.text('1.80'), findsOneWidget); // monotony, 2 dp
      expect(find.text('420'), findsOneWidget); // strain, rounded
      expect(find.text('Vary your training.'), findsOneWidget);
    });

    testWidgets('cold start → not-enough-history copy', (tester) async {
      await pump(tester, LoadContext.fromJson({'data_status': 'ok'}));
      expect(find.text('Not enough training history yet.'), findsOneWidget);
    });

    testWidgets('state_unavailable → unavailable copy', (tester) async {
      await pump(tester, LoadContext.fromJson({'data_status': 'state_unavailable'}));
      expect(find.text('Load context unavailable.'), findsOneWidget);
    });
  });
}

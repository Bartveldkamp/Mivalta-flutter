// Tests for the aerobic-decoupling model + card.
//
// Contract guard: maps ViterbiEngine::recent_decoupling_pct JSON
// `{"mean_decoupling_pct": <f64|null>}`.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mivalta_flutter/models/decoupling_trend.dart';
import 'package:mivalta_flutter/widgets/analytics/decoupling_card.dart';
import 'package:mivalta_flutter/theme/tokens.dart';

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

  group('DecouplingCard', () {
    testWidgets('renders three windows formatted as percent', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: mivaltaDarkTheme(),
        home: const Scaffold(
          body: DecouplingCard(
            trend: DecouplingTrend(short: 3.4, mid: 4.1, long: 5.0),
          ),
        ),
      ));
      expect(find.text('Aerobic decoupling'), findsOneWidget);
      expect(find.text('3.4%'), findsOneWidget);
      expect(find.text('4.1%'), findsOneWidget);
      expect(find.text('5.0%'), findsOneWidget);
    });

    testWidgets('missing window shows em-dash, not a fabricated value',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: mivaltaDarkTheme(),
        home: const Scaffold(
          body: DecouplingCard(trend: DecouplingTrend(mid: 4.1)),
        ),
      ));
      expect(find.text('4.1%'), findsOneWidget);
      expect(find.text('—'), findsNWidgets(2)); // 7-day + 28-day absent
    });

    testWidgets('no data → honest empty state', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: mivaltaDarkTheme(),
        home: const Scaffold(body: DecouplingCard(trend: DecouplingTrend())),
      ));
      expect(find.text('No aerobic decoupling readings yet.'), findsOneWidget);
    });
  });
}

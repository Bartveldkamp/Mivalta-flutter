// Tests for the Training Load model + chart.
//
// Contract guard: maps VaultEngine::read_daily_loads JSON `[[date, load], ...]`.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mivalta_flutter/models/training_load.dart';
import 'package:mivalta_flutter/widgets/analytics/training_load_chart.dart';
import 'package:mivalta_flutter/theme/tokens.dart';

void main() {
  group('TrainingLoad.fromJson', () {
    test('parses serde tuple array [[date, load], ...]', () {
      final t = TrainingLoad.fromJson([
        ['2026-06-01', 120.0],
        ['2026-06-02', 0.0],
        ['2026-06-03', 200.5],
      ]);
      expect(t.days.length, 3);
      expect(t.isEmpty, isFalse);
      expect(t.days.first.date, '2026-06-01');
      expect(t.days.first.load, 120.0);
      expect(t.peak, 200.5);
    });

    test('also tolerates [{date, load}] objects', () {
      final t = TrainingLoad.fromJson([
        {'date': 'd1', 'load': 50},
      ]);
      expect(t.days.length, 1);
      expect(t.days.first.load, 50.0);
    });

    test('non-list / malformed → safe empty', () {
      expect(TrainingLoad.fromJson(null).isEmpty, isTrue);
      expect(TrainingLoad.fromJson('x').isEmpty, isTrue);
      expect(TrainingLoad.fromJson([42, 'bad']).isEmpty, isTrue);
      expect(TrainingLoad.fromJson([]).peak, 0);
    });
  });

  group('TrainingLoadChart', () {
    testWidgets('renders title + peak + day count', (tester) async {
      final t = TrainingLoad.fromJson([
        ['d1', 100.0],
        ['d2', 250.0],
      ]);
      await tester.pumpWidget(MaterialApp(
        theme: mivaltaDarkTheme(),
        home: Scaffold(body: TrainingLoadChart(load: t)),
      ));
      expect(find.text('Training load'), findsOneWidget);
      expect(find.text('250'), findsOneWidget); // peak rounded
      expect(find.text('2'), findsOneWidget); // day count
    });

    testWidgets('empty → honest empty state, no crash', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: mivaltaDarkTheme(),
        home: const Scaffold(body: TrainingLoadChart(load: TrainingLoad(days: []))),
      ));
      expect(find.text('No training load recorded yet.'), findsOneWidget);
    });
  });
}

// Tests for the Workout Detail model + card.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mivalta_flutter/models/workout_detail.dart';
import 'package:mivalta_flutter/widgets/analytics/workout_detail_card.dart';
import 'package:mivalta_flutter/theme/tokens.dart';

void main() {
  group('WorkoutDetail.fromJson', () {
    test('parses a full cycling workout', () {
      final w = WorkoutDetail.fromJson({
        'date': '2026-06-05',
        'sport': 'cycling',
        'duration_min': 75,
        'avg_watts': 240,
        'avg_hr': 148,
        'decoupling_pct': 4.2,
        'efficiency_factor': 1.82,
        'zone_compliance_pct': 88.0,
        'grade': 'Good',
      });
      expect(w.sport, 'cycling');
      expect(w.durationMin, 75);
      expect(w.avgWatts, 240);
      expect(w.decouplingPct, 4.2);
      expect(w.grade, 'Good');
      expect(w.avgPaceMss, isNull);
    });

    test('non-map → safe empty', () {
      final w = WorkoutDetail.fromJson('nope');
      expect(w.date, '');
      expect(w.durationMin, isNull);
    });
  });

  group('WorkoutDetailCard', () {
    testWidgets('renders grade, sport, and present metrics only', (tester) async {
      final w = WorkoutDetail.fromJson({
        'date': '2026-06-05',
        'sport': 'running',
        'duration_min': 50,
        'avg_pace_mss': '4:30',
        'avg_hr': 156,
        'decoupling_pct': 6.1,
        'grade': 'Fair',
      });
      await tester.pumpWidget(MaterialApp(
        theme: mivaltaDarkTheme(),
        home: Scaffold(body: WorkoutDetailCard(detail: w)),
      ));
      expect(find.text('Running'), findsOneWidget);
      expect(find.text('Fair'), findsOneWidget);
      expect(find.text('50 min'), findsOneWidget);
      expect(find.text('4:30'), findsOneWidget);
      expect(find.text('156 bpm'), findsOneWidget);
      expect(find.text('6.1%'), findsOneWidget);
      // absent metric not shown
      expect(find.text('Avg power'), findsNothing);
    });

    testWidgets('no metrics → honest empty line', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: mivaltaDarkTheme(),
        home: const Scaffold(
          body: WorkoutDetailCard(detail: WorkoutDetail(date: '', sport: 'cycling')),
        ),
      ));
      expect(find.text('No metrics for this workout.'), findsOneWidget);
    });
  });
}

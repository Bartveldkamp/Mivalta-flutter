// Tests for the Post-Workout Report model + card (Advisory).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mivalta_flutter/models/workout_report.dart';
import 'package:mivalta_flutter/widgets/analytics/post_workout_report_card.dart';
import 'package:mivalta_flutter/theme/tokens.dart';

WorkoutReport _sample() => WorkoutReport.fromJson({
      'date': '2026-06-04',
      'sport': 'cycling',
      'zone': 'Z2',
      'duration_min': 60.0,
      'avg_hr': 142,
      'rpe': 5,
      'energy_system': 'aerobic endurance',
      'what_it_builds': 'Aerobic base and fat oxidation.',
      'stimulus_cost_note': 'Low cost, durable stimulus.',
      'quality_summary': 'Zone compliance 95% (on target).',
      'autocue': 'Z2 ride, 60 min.',
    });

void main() {
  group('WorkoutReport.fromJson', () {
    test('parses the engine report shape', () {
      final r = _sample();
      expect(r.zone, 'Z2');
      expect(r.durationMin, 60.0);
      expect(r.avgHr, 142);
      expect(r.rpe, 5);
      expect(r.whatItBuilds, 'Aerobic base and fat oxidation.');
      expect(r.qualitySummary, 'Zone compliance 95% (on target).');
      expect(r.isEmpty, isFalse);
    });

    test('empty / malformed → isEmpty, no fabrication', () {
      expect(WorkoutReport.fromJson(null).isEmpty, isTrue);
      expect(WorkoutReport.fromJson('x').isEmpty, isTrue);
      expect(WorkoutReport.fromJson(const {}).isEmpty, isTrue);
    });
  });

  group('PostWorkoutReportCard', () {
    testWidgets('renders purpose + quality + zone from engine values', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: mivaltaDarkTheme(),
        home: Scaffold(body: PostWorkoutReportCard(report: _sample())),
      ));
      expect(find.text('POST-WORKOUT REPORT'), findsOneWidget);
      expect(find.text('Z2'), findsOneWidget);
      expect(find.text('Aerobic base and fat oxidation.'), findsOneWidget);
      expect(find.text('Zone compliance 95% (on target).'), findsOneWidget);
    });

    testWidgets('non-canonical zone → no zone badge, no crash', (tester) async {
      final r = WorkoutReport.fromJson({
        'date': '2026-06-04',
        'sport': 'running',
        'zone': '',
        'duration_min': 40.0,
        'what_it_builds': 'General aerobic work.',
        'autocue': 'run',
      });
      await tester.pumpWidget(MaterialApp(
        theme: mivaltaDarkTheme(),
        home: Scaffold(body: PostWorkoutReportCard(report: r)),
      ));
      expect(find.text('POST-WORKOUT REPORT'), findsOneWidget);
      expect(find.text('General aerobic work.'), findsOneWidget);
    });
  });
}

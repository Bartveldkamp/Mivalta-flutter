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

    // A3 (NEXT_UPDATE_V2_ADOPTIONS): verdict-first. The engine's verdict prose
    // leads; raw stats are collapsible beneath — verdict → reasons → data.
    testWidgets('verdict-first: quality summary leads, stats collapsed until '
        '"Details" tap', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: mivaltaDarkTheme(),
        home: Scaffold(body: PostWorkoutReportCard(report: _sample())),
      ));

      // Verdict + reasons visible immediately.
      expect(find.text('Zone compliance 95% (on target).'), findsOneWidget);
      expect(find.text('Low cost, durable stimulus.'), findsOneWidget);
      expect(find.text('Aerobic base and fat oxidation.'), findsOneWidget);

      // Verdict ABOVE the reasons (verdict → reasons → data).
      final verdictY = tester
          .getTopLeft(find.text('Zone compliance 95% (on target).'))
          .dy;
      final reasonY = tester
          .getTopLeft(find.text('Aerobic base and fat oxidation.'))
          .dy;
      expect(verdictY, lessThan(reasonY));

      // Raw stats hidden until asked.
      expect(find.textContaining('142 bpm avg'), findsNothing);
      expect(find.text('Details'), findsOneWidget);

      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();

      // Stats line — engine values verbatim, revealed on request.
      expect(find.textContaining('142 bpm avg'), findsOneWidget);
      expect(find.textContaining('RPE 5'), findsOneWidget);
      expect(find.textContaining('60 min'), findsOneWidget);
      expect(find.text('Hide details'), findsOneWidget);
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

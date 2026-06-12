// Journey tab content contract (round 3 item 19,
// docs/FOUNDER_FEEDBACK_2026-06-12.md): the 2nd anchor renders the athlete's
// JOURNEY — learning arc ("day X of ~28"), week-in-review, baseline
// evolution. Engine-grounded only with honest empty states; nothing
// fabricated (milestones have no engine surface yet — not faked).
//
// JourneyView is the public display layer (same data/view split as the
// home), so these tests pump seeded engine-shaped JourneyData directly —
// the host harness can't bootstrap the FFI engine.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mivalta_flutter/copy/journey_labels.dart';
import 'package:mivalta_flutter/models/fitness_trend.dart';
import 'package:mivalta_flutter/screens/journey_screen.dart';
import 'package:mivalta_flutter/theme/tokens.dart';
import 'package:mivalta_flutter/widgets/analytics/fitness_trend_chart.dart';

Future<void> _pumpView(WidgetTester tester, JourneyData? data) =>
    tester.pumpWidget(MaterialApp(
      theme: mivaltaDarkTheme(),
      home: JourneyView(data: data),
    ));

/// Founder hard rule: no raw engine identifiers user-visible.
void _expectNoRawEngineIdentifiers(WidgetTester tester) {
  final snake = RegExp(r'\b[a-z0-9]+_[a-z0-9_]+\b');
  for (final w in tester.widgetList<Text>(find.byType(Text))) {
    final s = w.data;
    if (s == null) continue;
    expect(snake.hasMatch(s), isFalse,
        reason: 'raw engine identifier leaked to UI: "$s"');
  }
}

void main() {
  group('JourneyScreen (engine not ready)', () {
    testWidgets('null binding/handle → honest loading copy, no sections, '
        'no crash', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: mivaltaDarkTheme(),
        home: const JourneyScreen(binding: null, handle: null),
      ));
      await tester.pump();

      expect(find.text(kJourneyLoadingCopy), findsOneWidget);
      expect(find.text(kJourneyLearningHeading), findsNothing);
      expect(find.text(kJourneyWeekHeading), findsNothing);
      expect(find.text(kJourneyBaselineHeading), findsNothing);
    });
  });

  group('JourneyView with seeded engine-shaped data', () {
    testWidgets('full journey: learning line verbatim + progress bar, '
        'week rows verbatim, baseline chart', (tester) async {
      final data = JourneyData()
        ..observationDays = 12
        ..weekLoads = const [
          ('2026-06-08', 156.4), // a Monday
          ('2026-06-09', 0.0),
        ]
        ..trend = const FitnessTrend(samples: [
          FitnessSample(
              date: '2026-06-01', fitness: 42.0, fatigue: 30.0, form: 12.0),
          FitnessSample(
              date: '2026-06-02', fitness: 43.5, fatigue: 28.0, form: 15.5),
        ]);
      await _pumpView(tester, data);

      // Learning arc — founder phrasing, day count verbatim.
      expect(find.text('Learning you \u2014 day 12 of ~28.'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text(kJourneyCalibrationCopy), findsOneWidget);

      // Week in review — weekday formatting + load rounded for display.
      expect(find.text('Mon'), findsOneWidget);
      expect(find.text('156'), findsOneWidget);
      expect(find.text('Tue'), findsOneWidget);

      // Baseline — the existing fitness-trend chart renders.
      expect(find.byType(FitnessTrendChart), findsOneWidget);
      expect(find.text(kJourneyBaselineEmptyCopy), findsNothing);

      _expectNoRawEngineIdentifiers(tester);
    });

    testWidgets('past the calibration window the of-clause drops — '
        'no false "day 30 of ~28"', (tester) async {
      final data = JourneyData()..observationDays = 30;
      await _pumpView(tester, data);

      expect(find.text('Learning you \u2014 day 30.'), findsOneWidget);
      expect(find.textContaining('of ~28'), findsNothing);
    });

    testWidgets('empty engine → honest empty copy per section, no bar, '
        'no chart, nothing fabricated', (tester) async {
      await _pumpView(tester, JourneyData());

      expect(find.text(kJourneyLearningEmptyCopy), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text(kJourneyWeekEmptyCopy), findsOneWidget);
      expect(find.text(kJourneyBaselineEmptyCopy), findsOneWidget);
      expect(find.byType(FitnessTrendChart), findsNothing);

      _expectNoRawEngineIdentifiers(tester);
    });

    testWidgets('fetch error → honest failure copy, no sections',
        (tester) async {
      final data = JourneyData()
        ..observationDays = 12 // even with partial data, error wins honestly
        ..error = 'boom';
      await _pumpView(tester, data);

      expect(find.text(kJourneyErrorCopy), findsOneWidget);
      expect(find.text(kJourneyLearningHeading), findsNothing);
      expect(find.text(kJourneyWeekHeading), findsNothing);
      expect(find.text(kJourneyBaselineHeading), findsNothing);
      expect(find.text('boom'), findsNothing,
          reason: 'raw exception text never reaches the user');
    });

    testWidgets('unparseable date falls back to the raw date string '
        '(no crash)', (tester) async {
      final data = JourneyData()
        ..weekLoads = const [('not-a-date', 80.0)];
      await _pumpView(tester, data);

      expect(find.text('not-a-date'), findsOneWidget);
      expect(find.text('80'), findsOneWidget);
    });
  });
}

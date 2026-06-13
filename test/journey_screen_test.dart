// Journey tab content contract (NEXT_BUILD_BRIEF §C): the 2nd anchor renders
// the athlete's JOURNEY — learning arc, load vs recovery, fitness/form,
// biometric overviews, workouts list, adaptation trends. Engine-grounded only
// with honest empty states; nothing fabricated.
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

Future<void> _pumpView(
  WidgetTester tester,
  JourneyData? data, {
  Set<String>? enabledTiles,
}) =>
    tester.pumpWidget(MaterialApp(
      theme: mivaltaDarkTheme(),
      home: JourneyView(
        data: data,
        enabledTiles: enabledTiles ?? kDefaultJourneyTiles,
      ),
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
      expect(find.text(kJourneyLoadRecoveryHeading), findsNothing);
      expect(find.text(kJourneyFitnessHeading), findsNothing);
    });
  });

  group('JourneyView with seeded engine-shaped data', () {
    testWidgets('full journey: learning line verbatim + progress bar, '
        'load-recovery, fitness/form chart', (tester) async {
      final data = JourneyData()
        ..observationDays = 12
        ..monthLoads = const [
          ('2026-06-08', 156.4),
          ('2026-06-09', 80.0),
        ]
        ..readinessHistory = const [
          ('2026-06-08', 72.0),
          ('2026-06-09', 68.0),
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

      // Load vs Recovery card
      expect(find.text(kJourneyLoadRecoveryHeading), findsOneWidget);
      expect(find.text('Load'), findsOneWidget);
      expect(find.text('Recovery'), findsOneWidget);

      // Fitness/Form card with chart
      expect(find.text(kJourneyFitnessHeading), findsOneWidget);
      expect(find.byType(FitnessTrendChart), findsOneWidget);

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

      // Visible without scrolling
      expect(find.text(kJourneyLearningEmptyCopy), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text(kJourneyLoadRecoveryEmptyCopy), findsOneWidget);
      expect(find.text(kJourneyFitnessEmptyCopy), findsOneWidget);

      // Scroll to see more cards
      await tester.scrollUntilVisible(
        find.text(kJourneyWorkoutsEmptyCopy),
        100,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text(kJourneyWorkoutsEmptyCopy), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text(kJourneyAdaptationEmptyCopy),
        100,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text(kJourneyAdaptationEmptyCopy), findsOneWidget);

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
      expect(find.text(kJourneyLoadRecoveryHeading), findsNothing);
      expect(find.text(kJourneyFitnessHeading), findsNothing);
      expect(find.text('boom'), findsNothing,
          reason: 'raw exception text never reaches the user');
    });

    testWidgets('biometric card shows latest value + sparkline',
        (tester) async {
      final data = JourneyData()
        ..biometricHistory = const [
          BiometricSample(date: '2026-06-08', hrvRmssd: 42.0),
          BiometricSample(date: '2026-06-09', hrvRmssd: 45.0),
        ];
      await _pumpView(tester, data);

      // HRV card shows latest value
      expect(find.text(kJourneyHrvHeading), findsOneWidget);
      expect(find.text('45'), findsOneWidget); // Latest HRV rounded
      expect(find.text('ms'), findsOneWidget); // Unit
    });

    testWidgets('workouts list shows activity summaries', (tester) async {
      final data = JourneyData()
        ..recentActivities = const [
          ActivitySummary(
            activityId: 'a1',
            activityType: 'ride',
            completedAt: '2026-06-09T10:00:00Z',
            durationSecs: 3600,
            loadUls: 120.0,
          ),
        ];
      await _pumpView(tester, data);

      // Scroll to the workouts card
      await tester.scrollUntilVisible(
        find.text(kJourneyWorkoutsHeading),
        100,
        scrollable: find.byType(Scrollable),
      );

      expect(find.text(kJourneyWorkoutsHeading), findsOneWidget);
      expect(find.text('Ride'), findsOneWidget);
      expect(find.textContaining('1h'), findsOneWidget); // Duration in combined text
      expect(find.text('120'), findsOneWidget);
    });

    testWidgets('adaptation card shows EF + HR recovery trends',
        (tester) async {
      final data = JourneyData()
        ..efTrend = const [
          ('2026-06-08T10:00:00Z', 1.45),
          ('2026-06-09T10:00:00Z', 1.52),
        ]
        ..hrRecoveryTrend = const [
          ('2026-06-08T10:00:00Z', 28.0),
          ('2026-06-09T10:00:00Z', 32.0),
        ];
      await _pumpView(tester, data);

      // Scroll to the adaptation card
      await tester.scrollUntilVisible(
        find.text(kJourneyAdaptationHeading),
        100,
        scrollable: find.byType(Scrollable),
      );

      expect(find.text(kJourneyAdaptationHeading), findsOneWidget);
      expect(find.text(kJourneyEfTrendLabel), findsOneWidget);
      expect(find.text('1.52'), findsOneWidget); // Latest EF
      expect(find.text(kJourneyHrRecoveryLabel), findsOneWidget);
      expect(find.text('32'), findsOneWidget); // Latest HR recovery rounded
    });
  });

  group('Configurable tiles (§C.5)', () {
    testWidgets('only enabled tiles are shown', (tester) async {
      final data = JourneyData()
        ..observationDays = 12
        ..monthLoads = const [('2026-06-08', 100.0)]
        ..biometricHistory = const [
          BiometricSample(date: '2026-06-08', hrvRmssd: 42.0),
        ];

      // Only enable learning and HRV tiles
      await _pumpView(
        tester,
        data,
        enabledTiles: {'learning', 'hrv'},
      );

      // Learning arc should show
      expect(find.text(kJourneyLearningHeading), findsOneWidget);

      // HRV should show
      expect(find.text(kJourneyHrvHeading), findsOneWidget);

      // Load vs Recovery should NOT show (not in enabledTiles)
      expect(find.text(kJourneyLoadRecoveryHeading), findsNothing);

      // Other tiles should not show
      expect(find.text(kJourneyFitnessHeading), findsNothing);
      expect(find.text(kJourneyRhrHeading), findsNothing);
      expect(find.text(kJourneySleepHeading), findsNothing);
    });

    testWidgets('empty enabledTiles shows no cards', (tester) async {
      final data = JourneyData()..observationDays = 12;

      await _pumpView(tester, data, enabledTiles: {});

      // No cards should show
      expect(find.text(kJourneyLearningHeading), findsNothing);
      expect(find.text(kJourneyLoadRecoveryHeading), findsNothing);
      expect(find.text(kJourneyFitnessHeading), findsNothing);
      expect(find.text(kJourneyHrvHeading), findsNothing);
    });

    testWidgets('configure button shows tile picker', (tester) async {
      Set<String>? changedTiles;
      final data = JourneyData()..observationDays = 12;

      await tester.pumpWidget(MaterialApp(
        theme: mivaltaDarkTheme(),
        home: JourneyView(
          data: data,
          enabledTiles: kDefaultJourneyTiles,
          onTilesChanged: (tiles) => changedTiles = tiles,
        ),
      ));

      // Tap the configure button
      final configButton = find.byTooltip(kJourneyTilePickerTooltip);
      expect(configButton, findsOneWidget);
      await tester.tap(configButton);
      await tester.pumpAndSettle();

      // Picker sheet should appear
      expect(find.text(kJourneyTilePickerTitle), findsOneWidget);

      // All tile names should be visible as chips
      for (final id in kJourneyTileIds) {
        expect(find.text(journeyTileName(id)), findsOneWidget);
      }

      // Tap Done to close
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      // onTilesChanged should have been called
      expect(changedTiles, isNotNull);
    });

    testWidgets('toggling a tile in picker updates selection', (tester) async {
      Set<String>? changedTiles;
      final data = JourneyData()..observationDays = 12;

      await tester.pumpWidget(MaterialApp(
        theme: mivaltaDarkTheme(),
        home: JourneyView(
          data: data,
          enabledTiles: kDefaultJourneyTiles,
          onTilesChanged: (tiles) => changedTiles = tiles,
        ),
      ));

      // Open picker
      await tester.tap(find.byTooltip(kJourneyTilePickerTooltip));
      await tester.pumpAndSettle();

      // Tap HRV chip to toggle it off (it's on by default)
      await tester.tap(find.text('HRV Trend'));
      await tester.pumpAndSettle();

      // Tap Done
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      // HRV should not be in the changed tiles
      expect(changedTiles, isNotNull);
      expect(changedTiles!.contains('hrv'), isFalse);
      expect(changedTiles!.contains('learning'), isTrue);
    });
  });
}

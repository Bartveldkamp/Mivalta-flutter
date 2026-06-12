// Step 3 (HOME_REDESIGN_BRIEF §5): the today-facts tiles speak plain human
// language ONLY. These tests pin the contract: engine values pass through the
// fixed dictionaries; raw enums/zone strings NEVER render; unknown engine
// values fall back to honest learning/empty copy, not the raw string; the
// training-load tap-through reveals the engine's recommendation prose
// verbatim.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mivalta_flutter/copy/today_facts_labels.dart';
import 'package:mivalta_flutter/services/today_tiles_prefs.dart';
import 'package:mivalta_flutter/services/weather_service.dart';
import 'package:mivalta_flutter/theme/tokens.dart';
import 'package:mivalta_flutter/widgets/today_facts.dart';

Future<void> _pump(WidgetTester tester, Widget child) =>
    tester.pumpWidget(MaterialApp(
      theme: mivaltaDarkTheme(),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ));

void main() {
  group('today_facts_labels dictionaries', () {
    test('trainingLoadLabel maps the engine zone family to fixed copy', () {
      // Engine-observed values (load_context_test.dart seeds).
      expect(trainingLoadLabel('optimal'), 'Steady');
      expect(trainingLoadLabel('caution'), 'High');
      // Level-string family accepted.
      expect(trainingLoadLabel('green'), 'Steady');
      expect(trainingLoadLabel('yellow'), 'High');
      expect(trainingLoadLabel('danger'), 'Very high');
      expect(trainingLoadLabel('red'), 'Very high');
      expect(trainingLoadLabel('low'), 'Easy week');
    });

    test('unknown zones → null (silence, never the raw string)', () {
      expect(trainingLoadLabel('insufficient_data'), isNull);
      expect(trainingLoadLabel('some_future_zone'), isNull);
      expect(trainingLoadLabel(null), isNull);
      expect(trainingLoadLabel(''), isNull);
    });

    test('loadContextAvailable keys on the engine data_status verbatim', () {
      expect(loadContextAvailable('ok'), isTrue);
      expect(loadContextAvailable('state_unavailable'), isFalse);
      expect(loadContextAvailable(null), isFalse);
    });
  });

  group('TodayFacts — sleep tile', () {
    testWidgets('engine sleep_hours renders as human copy', (tester) async {
      await _pump(tester, const TodayFacts(sleepHours: 7.5));
      expect(find.text('7.5 h sleep'), findsOneWidget);
      expect(find.text(kSleepTileLabel), findsOneWidget); // 'Last night'
    });

    testWidgets('no sleep row → honest empty copy', (tester) async {
      await _pump(tester, const TodayFacts());
      expect(find.text(kSleepEmptyCopy), findsOneWidget);
      expect(find.textContaining('h sleep'), findsNothing);
    });
  });

  group('TodayFacts — training-load tile', () {
    testWidgets('zone + ok status → fixed label, raw zone never visible',
        (tester) async {
      await _pump(
        tester,
        const TodayFacts(acwrZone: 'optimal', dataStatus: 'ok'),
      );
      expect(find.text('Steady'), findsOneWidget);
      expect(find.text('optimal'), findsNothing);
      expect(find.text(kTrainingLoadLearningCopy), findsNothing);
    });

    testWidgets('unknown zone → learning copy, raw string suppressed',
        (tester) async {
      await _pump(
        tester,
        const TodayFacts(acwrZone: 'insufficient_data', dataStatus: 'ok'),
      );
      expect(find.text(kTrainingLoadLearningCopy), findsOneWidget);
      expect(find.textContaining('insufficient_data'), findsNothing);
    });

    testWidgets('data_status ≠ ok → learning copy even with a known zone, '
        'and no tap-through', (tester) async {
      await _pump(
        tester,
        const TodayFacts(
          acwrZone: 'caution',
          acwrRecommendation: 'Ramp down this week.',
          dataStatus: 'state_unavailable',
        ),
      );
      expect(find.text(kTrainingLoadLearningCopy), findsOneWidget);
      expect(find.text('High'), findsNothing);
      expect(find.text('state_unavailable'), findsNothing);
      // No recommendation reveal when the engine says the state is not ready.
      await tester.tap(find.text(kTrainingLoadLearningCopy));
      await tester.pumpAndSettle();
      expect(find.text('Ramp down this week.'), findsNothing);
    });

    testWidgets('tap reveals the engine recommendation prose verbatim',
        (tester) async {
      await _pump(
        tester,
        const TodayFacts(
          acwrZone: 'caution',
          acwrRecommendation: 'Load is climbing fast — keep tomorrow easy.',
          dataStatus: 'ok',
        ),
      );
      expect(find.text('High'), findsOneWidget);
      // Hidden until asked (verdict first, reasons on tap).
      expect(
        find.text('Load is climbing fast — keep tomorrow easy.'),
        findsNothing,
      );

      await tester.tap(find.text('High'));
      await tester.pumpAndSettle();

      expect(
        find.text('Load is climbing fast — keep tomorrow easy.'),
        findsOneWidget,
      );
    });
  });

  group('TodayFacts — today\'s load tile', () {
    testWidgets('engine load row → trained copy + verbatim rounded number',
        (tester) async {
      await _pump(tester, const TodayFacts(todayLoad: 156.4));
      expect(find.text(kTodayLoadTrainedCopy), findsOneWidget);
      expect(find.text('156'), findsOneWidget);
      expect(find.text(kTodayLoadEmptyCopy), findsNothing);
    });

    testWidgets('no load row → honest empty copy, no number', (tester) async {
      await _pump(tester, const TodayFacts());
      expect(find.text(kTodayLoadEmptyCopy), findsOneWidget);
      expect(find.text(kTodayLoadTrainedCopy), findsNothing);
    });
  });

  group('TodayFacts — weather tile (items 11+18)', () {
    testWidgets('no OS report → honest empty copy', (tester) async {
      await _pump(tester, const TodayFacts());
      expect(find.text(kWeatherEmptyCopy), findsOneWidget);
    });

    testWidgets('OS report → condition + rounded temperature, glyph icon',
        (tester) async {
      final report = WeatherReport(
        symbol: 'cloud.rain',
        condition: 'Rain',
        temperatureC: 11.6,
        daily: const [],
      );
      await _pump(tester, TodayFacts(weather: report));
      expect(find.text('Rain · 12°'), findsOneWidget); // 11.6 rounds to 12
      expect(find.byIcon(Icons.water_drop_outlined), findsOneWidget);
      expect(find.text(kWeatherEmptyCopy), findsNothing);
    });
  });

  group('TodayFacts — user-configurable grid (item 12)', () {
    testWidgets('default: all four tiles render', (tester) async {
      await _pump(tester, const TodayFacts());
      expect(find.text(kSleepTileLabel), findsOneWidget);
      expect(find.text(kTrainingLoadTileLabel), findsOneWidget);
      expect(find.text(kTodayLoadTileLabel), findsOneWidget);
      expect(find.text(kWeatherTileLabel), findsOneWidget);
    });

    testWidgets('subset: only the chosen tiles render, in fixed order',
        (tester) async {
      await _pump(
        tester,
        const TodayFacts(
          sleepHours: 7.5,
          visibleTiles: {'sleep', 'today'},
        ),
      );
      expect(find.text(kSleepTileLabel), findsOneWidget);
      expect(find.text(kTodayLoadTileLabel), findsOneWidget);
      expect(find.text(kTrainingLoadTileLabel), findsNothing);
      expect(find.text(kWeatherTileLabel), findsNothing);
      // Sleep (first in kTodayTileIds) renders left of Today.
      final sleepX = tester.getCenter(find.text(kSleepTileLabel)).dx;
      final todayX = tester.getCenter(find.text(kTodayLoadTileLabel)).dx;
      expect(sleepX, lessThan(todayX));
    });

    testWidgets('hidden load tile → no load-why reveal even with engine prose',
        (tester) async {
      await _pump(
        tester,
        const TodayFacts(
          acwrZone: 'caution',
          acwrRecommendation: 'Ramp down this week.',
          dataStatus: 'ok',
          visibleTiles: {'sleep', 'today', 'weather'},
        ),
      );
      expect(find.text('High'), findsNothing);
      expect(find.text('Ramp down this week.'), findsNothing);
    });

    testWidgets('edit affordance renders only when wired, and invokes the '
        'callback', (tester) async {
      await _pump(tester, const TodayFacts());
      expect(find.byTooltip(kTilePickerTooltip), findsNothing);

      var tapped = false;
      await _pump(tester, TodayFacts(onEditTiles: () => tapped = true));
      final affordance = find.byTooltip(kTilePickerTooltip);
      expect(affordance, findsOneWidget);
      await tester.tap(affordance);
      expect(tapped, isTrue);
    });

    test('todayTileName maps every id to its tile heading', () {
      expect(todayTileName('sleep'), kSleepTileLabel);
      expect(todayTileName('load'), kTrainingLoadTileLabel);
      expect(todayTileName('today'), kTodayLoadTileLabel);
      expect(todayTileName('weather'), kWeatherTileLabel);
    });
  });

  group('TodayTilePicker (item 12 sheet body)', () {
    testWidgets('lists all four tiles by their human names with current '
        'state; toggling fires onChanged with the full set', (tester) async {
      Set<String>? changed;
      await _pump(
        tester,
        TodayTilePicker(
          visibleTiles: const {'sleep', 'load', 'today'},
          onChanged: (next) => changed = next,
        ),
      );

      expect(find.text(kTilePickerTitle), findsOneWidget);
      for (final id in kTodayTileIds) {
        expect(find.text(todayTileName(id)), findsOneWidget);
      }
      // Weather starts off; flip it on.
      await tester.tap(find.text(kWeatherTileLabel));
      await tester.pump();
      expect(changed, {'sleep', 'load', 'today', 'weather'});

      // Flip sleep off — set shrinks.
      await tester.tap(find.text(kSleepTileLabel));
      await tester.pump();
      expect(changed, {'load', 'today', 'weather'});
    });
  });

  group('TodayTilesPrefs (item 12 persistence)', () {
    test('round-trips the enabled set through the JSON file', () async {
      final dir = await Directory.systemTemp.createTemp('today_tiles_test');
      addTearDown(() => dir.delete(recursive: true));

      final prefs = TodayTilesPrefs(dir: dir);
      await prefs.save({'sleep', 'weather'});

      final loaded = await TodayTilesPrefs(dir: dir).load();
      expect(loaded, {'sleep', 'weather'});
    });

    test('no file yet → the all-on defaults', () async {
      final dir = await Directory.systemTemp.createTemp('today_tiles_test');
      addTearDown(() => dir.delete(recursive: true));

      expect(await TodayTilesPrefs(dir: dir).load(), kDefaultTodayTiles);
    });

    test('malformed file → defaults, never a crash', () async {
      final dir = await Directory.systemTemp.createTemp('today_tiles_test');
      addTearDown(() => dir.delete(recursive: true));
      await File('${dir.path}/today_tiles.json').writeAsString('not json');

      expect(await TodayTilesPrefs(dir: dir).load(), kDefaultTodayTiles);
    });

    test('unknown ids in the file are filtered out', () async {
      final dir = await Directory.systemTemp.createTemp('today_tiles_test');
      addTearDown(() => dir.delete(recursive: true));
      await File('${dir.path}/today_tiles.json').writeAsString(
        '{"enabled": ["sleep", "hacked_tile", 42]}',
      );

      expect(await TodayTilesPrefs(dir: dir).load(), {'sleep'});
    });
  });
}

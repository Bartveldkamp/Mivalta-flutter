// HOST-ONLY REAL-ENGINE HARNESS (final integration audit, 2026-07-16).
// Runs ONLY where the host FRB shim exists (rust/target/debug/
// libmivalta_rust_bridge.so — `cargo build` in rust/ on this machine).
// In cloud CI the shim cannot be built (DR-026), so these tests SELF-SKIP
// with an honest message instead of failing. On a dev machine / the Mac,
// they drive the REAL engine end to end.
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart'
    show ExternalLibrary;
import 'package:flutter_test/flutter_test.dart';
import 'package:mivalta_flutter/models/workout_option.dart';
import 'package:mivalta_flutter/screens/advisor_screen.dart';
import 'package:mivalta_flutter/screens/journey_screen.dart';
import 'package:mivalta_flutter/screens/today_screen.dart';
import 'package:mivalta_flutter/src/rust/api.dart' as rust;
import 'package:mivalta_flutter/src/rust/frb_generated.dart';
import 'package:mivalta_flutter/widgets/today/glow_hero.dart';

import '../support/headless_env.dart';
import 'support/real_host_binding.dart';

const _soPath = 'rust/target/debug/libmivalta_rust_bridge.so';
const _athleteId = 'audit-screens-0716';

late rust.EnginesHandle _handle;
late String _profileJson;
final _binding = RealHostBinding();

/// Warm one real athlete life into a fresh vault (same chain as the app).
Future<void> _warmLife() async {
  final tablesJson =
      await File('assets/compiled_tables.json')
          .readAsString();
  final vaultPath = (await Directory.systemTemp.createTemp('audit_scr_')).path;
  _profileJson = await rust.buildOnboardingProfile(
      inputsJson: jsonEncode({
    'athlete_id': _athleteId,
    'age': 35,
    'level': 'intermediate',
    'sport': 'cycling',
    'goal_type': 'general_fitness',
    'weekly_hours': 7.0,
    'training_years': 4,
    'sex': 'male',
    'threshold_hr': 165,
    'ftp_watts': 250,
  }));
  await rust.writeProfileToVault(
      athleteProfileJson: _profileJson, vaultPath: vaultPath);
  _handle = await rust.constructEnginesFresh(
    athleteProfileJson: _profileJson,
    tablesJson: tablesJson,
    vaultPath: vaultPath,
  );
  for (var i = 0; i < 12; i++) {
    final day = DateTime.utc(2026, 7, 4).add(Duration(days: i));
    final date =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    final normalized = await rust.normalizeObservation(
        handle: _handle,
        vendor: 'apple',
        json: jsonEncode({
          'date': date,
          'resting_heart_rate': 52.0 + (i % 3),
          'hrv_sdnn': 62.0 + (i % 5) * 1.5,
          'sleep_samples': [
            {
              'value': 4,
              'startDate': '${date}T00:30:00.000Z',
              'endDate': '${date}T07:48:00.000Z',
            }
          ],
        }));
    await rust.processObservation(
        handle: _handle, observationJson: normalized);
    await rust.writeBiometricFromObservation(handle: _handle, json: normalized);
    await rust.writeReadinessAssessment(handle: _handle, date: date);
  }
  // one streamed workout (yesterday)
  const start = '2026-07-15T16:00:00.000Z';
  final startEpoch = DateTime.parse(start).millisecondsSinceEpoch / 1000.0;
  final hr = List<double>.generate(
      1800, (i) => 118.0 + 30.0 * (i / 1800.0) + 6.0 * ((i ~/ 90) % 2));
  final ts = List<double>.generate(1800, (i) => startEpoch + i * 2.0);
  final normalizedW = await rust.normalizeObservation(
      handle: _handle,
      vendor: 'apple',
      json: jsonEncode({
        'date': '2026-07-15',
        'workout': {
          'start': start,
          'duration': 3600.0,
          'totalEnergyBurned': 640,
          'associatedSamples': {
            'heartRate': {
              'samples': hr,
              'average': hr.reduce((a, b) => a + b) / hr.length
            }
          },
        },
      }));
  final assess = await rust.processObservation(
      handle: _handle, observationJson: normalizedW);
  final load = (jsonDecode(assess) as Map)['recorded_load'] as num;
  await rust.writeActivityWithStreams(
      handle: _handle,
      activityJson: jsonEncode({
        'id': 'audit_scr_wk1',
        'date': '2026-07-15',
        'activity_type': 'ride',
        'duration_minutes': 60.0,
        'avg_heart_rate': 133,
        'max_heart_rate': 155,
        'calories': 640,
        'source': 'apple',
        'load_uls': load.toDouble(),
      }),
      streamsJson: jsonEncode({
        'completed_at': '2026-07-15T17:00:00.000Z',
        'power_samples': <double>[],
        'hr_samples': hr,
        'hr_timestamps': ts,
      }));
  final state = await rust.saveState(handle: _handle);
  await rust.writeViterbiState(handle: _handle, stateJson: state);
}

void main() {
  if (!File(_soPath).existsSync()) {
    print('SKIP: host shim not built ($_soPath) — run `cargo build` in rust/ '
        'to enable the real-engine audit.');
    return;
  }
  setUpAll(() async {
    await RustLib.init(externalLibrary: ExternalLibrary.open(_soPath));
    await _warmLife();
  });

  testWidgets('TODAY renders the real readiness: score digits + state word',
      (tester) async {
    await installHeadlessEnv(tester, profileJson: _profileJson);
    useTallTestViewport(tester);

    // The engine's own truth, read first — the screen must show THIS.
    // (real FFI futures only complete inside runAsync under testWidgets)
    late int expectedScore;
    late String expectedState;
    await tester.runAsync(() async {
      final ind =
          jsonDecode(await rust.readinessIndicator(handle: _handle)) as Map;
      expectedScore = (ind['score'] as num).toInt();
      final fatigue =
          jsonDecode(await rust.viterbiFatigueState(handle: _handle)) as Map;
      expectedState = fatigue['state'] as String;
    });

    await tester.pumpWidget(MaterialApp(
      home: TodayScreen(binding: _binding, handle: _handle),
    ));
    await pumpUntilLoaded(tester);
    // give the post-spinner engine futures extra real-async rounds to land
    for (var i = 0; i < 60; i++) {
      final heroes = find.byType(GlowHero).evaluate();
      if (heroes.isNotEmpty &&
          (heroes.first.widget as GlowHero).score != null) {
        break;
      }
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    final heroes = find.byType(GlowHero).evaluate();
    if (heroes.isEmpty) {
      final texts = find
          .byType(Text)
          .evaluate()
          .map((e) => (e.widget as Text).data)
          .whereType<String>()
          .take(25)
          .toList();
      print('DIAG no GlowHero in tree. Visible texts: $texts');
    } else {
      final heroW = heroes.first.widget as GlowHero;
      print('DIAG GlowHero score=${heroW.score} state=${heroW.fatigueState} '
          'insufficient=${heroW.insufficientData}');
    }

    final heroScore = find.descendant(
        of: find.byType(GlowHero), matching: find.text('$expectedScore'));
    expect(heroScore, findsOneWidget,
        reason:
            'GlowHero must display the engine readiness score $expectedScore');
    expect(find.textContaining(expectedState), findsWidgets,
        reason: 'the fatigue state word must render');
    print('SCREEN-TODAY renders score=$expectedScore state=$expectedState ✓');
  });

  testWidgets('ADVISOR renders the engine-composed coach sentence verbatim',
      (tester) async {
    await installHeadlessEnv(tester, profileJson: _profileJson);
    useTallTestViewport(tester);

    late List<WorkoutOption> options;
    late String? level;
    await tester.runAsync(() async {
      final recJson = await rust.recommendWorkoutWithHistory(handle: _handle);
      options = (jsonDecode(recJson) as List)
          .map((e) => WorkoutOption.fromJson(e as Map<String, dynamic>))
          .toList();
      final ind =
          jsonDecode(await rust.readinessIndicator(handle: _handle)) as Map;
      level = ind['level'] as String?;
    });
    expect(options, isNotEmpty);
    final withSentence =
        options.where((o) => (o.coachSentence ?? '').isNotEmpty).toList();
    expect(withSentence, isNotEmpty,
        reason: 'at least one option must carry the engine coach sentence');
    final sentence = withSentence.first.coachSentence!;

    await tester.pumpWidget(MaterialApp(
      home: AdvisorScreen(
        options: options,
        binding: _binding,
        handle: _handle,
        readinessLevel: level,
      ),
    ));
    await pumpUntilLoaded(tester);

    // Open the option detail if the sentence isn't already on screen.
    if (find.textContaining('Today your workout is').evaluate().isEmpty) {
      await tester.tap(find.text(withSentence.first.title).first);
      await pumpUntilLoaded(tester);
    }
    expect(find.text(sentence), findsOneWidget,
        reason: 'the coach sentence must render VERBATIM');
    print('SCREEN-ADVISOR renders coach sentence verbatim ✓ "$sentence"');
  });

  testWidgets('JOURNEY loads real history + day record from the engine',
      (tester) async {
    await installHeadlessEnv(tester, profileJson: _profileJson);
    useTallTestViewport(tester);

    await tester.pumpWidget(MaterialApp(
      home: JourneyScreen(binding: _binding, handle: _handle),
    ));
    await pumpUntilLoaded(tester);

    // The stored workout must surface in the history list.
    final hasRide = find.textContaining('Ride').evaluate().isNotEmpty ||
        find.textContaining('ride').evaluate().isNotEmpty;
    expect(hasRide, isTrue,
        reason: 'the ingested ride must appear in Journey history');
    print('SCREEN-JOURNEY renders the real ride row ✓');
  });
}

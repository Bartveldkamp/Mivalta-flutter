// HOST-ONLY REAL-ENGINE HARNESS (final integration audit, 2026-07-16).
// Runs ONLY where the host FRB shim exists (rust/target/debug/
// libmivalta_rust_bridge.so — `cargo build` in rust/ on this machine).
// In cloud CI the shim cannot be built (DR-026), so these tests SELF-SKIP
// with an honest message instead of failing. On a dev machine / the Mac,
// they drive the REAL engine end to end.
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart'
    show ExternalLibrary;
import 'package:flutter_test/flutter_test.dart';
import 'package:mivalta_flutter/src/rust/api.dart' as rust;
import 'package:mivalta_flutter/src/rust/frb_generated.dart';

const _soPath = 'rust/target/debug/libmivalta_rust_bridge.so';
const _athleteId = 'audit-athlete-0716';
const _passphrase = 'audit-pass-Xk9!';

void main() {
  if (!File(_soPath).existsSync()) {
    print('SKIP: host shim not built ($_soPath) — run `cargo build` in rust/ '
        'to enable the real-engine audit.');
    return;
  }
  late String tablesJson;
  late String vaultPath;

  setUpAll(() async {
    await RustLib.init(externalLibrary: ExternalLibrary.open(_soPath));
    tablesJson =
        await File('assets/compiled_tables.json')
            .readAsString();
    vaultPath = (await Directory.systemTemp.createTemp('audit_vault_')).path;
  });

  test('WHOLE LIFE against the real engine: onboard → ingest → readiness → '
      'advisor → TIZ → restart continuity → export/restore', () async {
    // ── 1 · ONBOARDING: engine builds the profile from raw inputs ──────────
    final inputs = jsonEncode({
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
    });
    final profileJson = await rust.buildOnboardingProfile(inputsJson: inputs);
    final profile = jsonDecode(profileJson) as Map<String, dynamic>;
    expect(profile['athlete_id'], _athleteId);
    expect(profile['ftp_watts'], isNotNull);
    print('W1 ONBOARD profile keys: ${profile.keys.length} '
        '(goal_class=${profile['goal_class']}, meso_minutes=${profile['meso_minutes']})');

    await rust.writeProfileToVault(
        athleteProfileJson: profileJson, vaultPath: vaultPath);

    // ── 2 · FIRST LAUNCH: fresh construction (arming inside the shim) ──────
    final handle = await rust.constructEnginesFresh(
      athleteProfileJson: profileJson,
      tablesJson: tablesJson,
      vaultPath: vaultPath,
    );

    // ── 3 · 12 DAYS of device biometrics via the real ingest chain ─────────
    // (apple vendor shape from health_ingest.dart:1058, normalize → process)
    String lastAssessment = '';
    for (var i = 0; i < 12; i++) {
      final day = DateTime.utc(2026, 7, 4).add(Duration(days: i));
      final date =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      final obs = jsonEncode({
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
        'steps': 8000 + i * 100,
      });
      final normalized = await rust.normalizeObservation(
          handle: handle, vendor: 'apple', json: obs);
      lastAssessment = await rust.processObservation(
          handle: handle, observationJson: normalized);
      await rust.writeBiometricFromObservation(
          handle: handle, json: normalized);
      await rust.writeReadinessAssessment(handle: handle, date: date);
    }
    final warmState =
        (jsonDecode(lastAssessment) as Map<String, dynamic>);
    print('W3 INGEST 12 biometric days → assessment keys=${warmState.keys.toList()}');

    // ── 3b · MANUAL ENTRY path (manual_entry screen's 4 fields) ────────────
    final manual = await rust.processManualObservation(
        handle: handle,
        isoDate: '2026-07-15',
        restingHr: 53.0,
        hrvRmssd: 64.0,
        sleepHours: 7.4,
        rpe: 4);
    expect(jsonDecode(manual), isA<Map<String, dynamic>>());
    print('W3b MANUAL observation processed: '
        'keys=${(jsonDecode(manual) as Map).keys.take(8).toList()}');

    // ── 4 · A DEVICE WORKOUT with HR streams (the ingest_adapter chain) ────
    const workoutDate = '2026-07-15';
    const workoutStart = '2026-07-15T16:00:00.000Z';
    final startEpoch =
        DateTime.parse(workoutStart).millisecondsSinceEpoch / 1000.0;
    // 60 min ride, HR sampled every 2 s → 1800 aligned samples, Z2-ish→Z4.
    final hrSamples = List<double>.generate(
        1800, (i) => 118.0 + 30.0 * (i / 1800.0) + 6.0 * ((i ~/ 90) % 2));
    final hrTimestamps =
        List<double>.generate(1800, (i) => startEpoch + i * 2.0);
    final avgHr =
        hrSamples.reduce((a, b) => a + b) / hrSamples.length;

    // workout observation (apple shape, ingest_adapter.buildWorkoutObservationJson:91)
    final workoutObs = jsonEncode({
      'date': workoutDate,
      'workout': {
        'start': workoutStart,
        'duration': 3600.0,
        'totalEnergyBurned': 640,
        'associatedSamples': {
          'heartRate': {'samples': hrSamples, 'average': avgHr}
        },
      },
    });
    final normalizedW = await rust.normalizeObservation(
        handle: handle, vendor: 'apple', json: workoutObs);
    final assessW = await rust.processObservation(
        handle: handle, observationJson: normalizedW);
    final recordedLoad =
        (jsonDecode(assessW) as Map<String, dynamic>)['recorded_load'];
    print('W4 WORKOUT recorded_load=$recordedLoad');
    expect(recordedLoad, isA<num>(),
        reason: 'engine must record a real load for an HR workout');
    expect((recordedLoad as num).toDouble(), greaterThan(0.0));

    // activity row (ingest_adapter.buildWorkoutActivityJson:131)
    final rowJson = jsonEncode({
      'id': 'audit_wk_1',
      'date': workoutDate,
      'activity_type': 'ride',
      'duration_minutes': 60.0,
      'avg_heart_rate': avgHr.round(),
      'max_heart_rate': 155,
      'calories': 640,
      'source': 'apple',
      'load_uls': recordedLoad.toDouble(),
    });
    // streams (ingest_adapter.buildActivityStreamsJson:161; hr_timestamps epoch secs)
    final streamsJson = jsonEncode({
      'completed_at': '2026-07-15T17:00:00.000Z',
      'power_samples': <double>[],
      'hr_samples': hrSamples,
      'hr_timestamps': hrTimestamps,
    });
    final receipt = await rust.writeActivityWithStreams(
        handle: handle, activityJson: rowJson, streamsJson: streamsJson);
    print('W4 TIZ receipt: $receipt');
    expect(jsonDecode(receipt)['tiz'], 'stored',
        reason: 'TIZ atom must persist at write (T4 contract)');

    // persist state exactly as health_ingest.persistBatchState does
    final stateJson = await rust.saveState(handle: handle);
    await rust.writeViterbiState(handle: handle, stateJson: stateJson);

    // ── 5 · READINESS renders-worthy payload (TodayScreen's exact calls) ───
    final indicatorJson = await rust.readinessIndicator(handle: handle);
    final ind = jsonDecode(indicatorJson) as Map<String, dynamic>;
    print('W5 READINESS score=${ind['score']} level=${ind['level']} '
        'confidence=${ind['confidence']} axes=${(ind['contributions'] as List?)?.map((c) => c['name']).toList()}');
    expect(ind['score'], isA<num>());
    expect((ind['score'] as num).toDouble(), greaterThan(0));
    expect((ind['level'] as String).toLowerCase(),
        isIn(['green', 'yellow', 'orange', 'red']));
    final axes = (ind['contributions'] as List)
        .map((c) => (c as Map)['name'] as String)
        .toList();
    expect(axes, contains('hmm_posteriors'));
    expect(axes, contains('physio_zscore'));

    final fatigue = jsonDecode(await rust.viterbiFatigueState(handle: handle));
    print('W5 fatigue state=${fatigue['state']}');
    expect(fatigue['state'], isNotNull);

    final advisory = jsonDecode(await rust.stateAdvisory(handle: handle));
    expect(advisory, isA<Map<String, dynamic>>());

    final josi = await rust.realizeAdvisorLine(handle: handle, date: '2026-07-16');
    print('W5 Josi line: ${jsonDecode(josi)['text'] ?? josi}');

    // ── 6 · SUGGESTION with history + the engine-composed coach sentence ───
    final recJson = await rust.recommendWorkoutWithHistory(handle: handle);
    final decodedRec = jsonDecode(recJson);
    final options = decodedRec is List ? decodedRec : const [];
    expect(options, isNotEmpty,
        reason: 'advisor must return at least one option');
    final sentences = options
        .map((o) => (o as Map)['coach_sentence'])
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .toList();
    print('W6 ADVISOR options=${options.length}; '
        'first=${(options.first as Map)['title'] ?? (options.first as Map)['name']}; '
        'coach_sentence[0]=${sentences.isNotEmpty ? sentences.first : '(absent)'}');
    expect(sentences, isNotEmpty,
        reason: 'engine-composed coach sentence must ride the options payload');

    // ── 7 · JOURNEY history + metabolic rollup off zeros ───────────────────
    final acts = jsonDecode(await rust.readActivitiesInRange(
        handle: handle, start: '2026-07-01', end: '2026-07-16')) as List;
    expect(acts, isNotEmpty);
    final row = acts.firstWhere((a) => a['id'] == 'audit_wk_1') as Map;
    print('W7 HISTORY row load_uls=${row['load_uls']} type=${row['activity_type']}');
    expect((row['load_uls'] as num).toDouble(), greaterThan(0.0));

    final rollupJson = await rust.metabolicTimeInZoneRollup(
        handle: handle, start: '2026-07-01', end: '2026-07-16');
    num rollupSum = 0;
    void sumNums(dynamic v) {
      if (v is num) rollupSum += v;
      if (v is Map) v.values.forEach(sumNums);
      if (v is List) v.forEach(sumNums);
    }

    sumNums(jsonDecode(rollupJson));
    print('W7 ROLLUP: $rollupJson');
    expect(rollupSum, greaterThan(0),
        reason: 'metabolic rollup must be non-zero after a streamed workout');

    // ── 8 · RESTART CONTINUITY (splash decision path, exact) ───────────────
    final has = await rust.hasPersistedState(
        athleteProfileJson: profileJson, vaultPath: vaultPath);
    expect(has, isTrue);
    final persisted = await rust.readPersistedState(
        athleteProfileJson: profileJson, vaultPath: vaultPath);
    expect(persisted, isNotNull);
    final handle2 = await rust.constructEnginesFromState(
      athleteProfileJson: profileJson,
      tablesJson: tablesJson,
      vaultPath: vaultPath,
      viterbiStateJson: persisted!,
    );
    final ind2 =
        jsonDecode(await rust.readinessIndicator(handle: handle2)) as Map;
    print('W8 RESTART score ${ind['score']} → ${ind2['score']} '
        '(state ${fatigue['state']} → '
        '${jsonDecode(await rust.viterbiFatigueState(handle: handle2))['state']})');
    expect(ind2['score'], ind['score'],
        reason: 'readiness must survive a restart bit-identically');
    final acts2 = jsonDecode(await rust.readActivitiesInRange(
        handle: handle2, start: '2026-07-01', end: '2026-07-16')) as List;
    expect(acts2.length, acts.length,
        reason: 'history must survive a restart');

    // ── 9 · EXPORT / RESTORE round-trip; wrong passphrase fails loud ───────
    final blob = await rust.exportEncryptedVault(
        handle: handle2, athleteId: _athleteId, passphrase: _passphrase);
    expect(blob.length, greaterThan(0));
    print('W9 EXPORT blob ${blob.length} bytes');

    Object? wrongPassError;
    try {
      await rust.importEncryptedVault(
          handle: handle2,
          athleteId: _athleteId,
          passphrase: 'not-the-passphrase',
          blob: blob,
          overwrite: true);
    } catch (e) {
      wrongPassError = e;
    }
    expect(wrongPassError, isNotNull,
        reason: 'wrong passphrase must FAIL LOUD, never partial-import');
    print('W9 wrong-passphrase failed loud: ${wrongPassError.runtimeType}');

    final restored = await rust.importEncryptedVault(
        handle: handle2,
        athleteId: _athleteId,
        passphrase: _passphrase,
        blob: blob,
        overwrite: true);
    print('W9 IMPORT: $restored');
    final actsAfter = jsonDecode(await rust.readActivitiesInRange(
        handle: handle2, start: '2026-07-01', end: '2026-07-16')) as List;
    expect(actsAfter.length, acts.length,
        reason: 'restore must reproduce the history');
  }, timeout: const Timeout(Duration(minutes: 5)));
}

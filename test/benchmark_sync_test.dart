// BenchmarkSyncService — the app-side courier chain of the CLOSED benchmark
// loop (founder 2026-07-07: auto-apply + full ledger + pattern rule).
//
// What these tests pin (courier truths, no engine logic to test here):
//   1. The chain runs in the contract order and passes engine output VERBATIM
//      — the history handed to the sync is exactly what the vault returned,
//      the event filed is exactly what the engine emitted.
//   2. The persisted profile is THE LIVE ENGINE'S OWN JSON (fetched back via
//      postprocessProfile), never a Dart re-assembly of the sync payload —
//      the byte-exactness rule that keeps Law 2 true after a promotion.
//   3. A hold writes NO profile and files NO event (honest absence), but
//      still stores the pruned evidence window.
//   4. An engine failure writes NOTHING and surfaces as a null outcome —
//      the vault is only ever touched with engine-produced values.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mivalta_flutter/rust_engine.dart';
import 'package:mivalta_flutter/services/benchmark_sync.dart';

class _FakeHandle implements EnginesHandle {
  @override
  Object? noSuchMethod(Invocation invocation) => null;
}

class _RecordingBinding implements RustEngineBinding {
  _RecordingBinding({required this.syncReturn});

  final List<String> calls = [];
  String historyReturn = 'null';
  String syncReturn;
  bool failSync = false;

  String? syncActivitiesArg;
  String? syncHistoryArg;
  String? storedHistory;
  String? persistedProfile;
  String? reboundProfile;
  String? filedEvent;

  /// Sentinel: the live engine's own profile JSON — distinct from anything
  /// in the sync payload so re-assembly would be caught.
  static const engineProfile = '{"live":"ENGINE_PROFILE"}';

  @override
  Future<String> readBenchmarkHistory(EnginesHandle handle) async {
    calls.add('readHistory');
    return historyReturn;
  }

  @override
  Future<String> syncBenchmarkFromActivities(
    EnginesHandle handle, {
    required String activitiesJson,
    required String candidateHistoryJson,
  }) async {
    calls.add('sync');
    if (failSync) throw Exception('engine boom');
    syncActivitiesArg = activitiesJson;
    syncHistoryArg = candidateHistoryJson;
    return syncReturn;
  }

  @override
  Future<void> writeBenchmarkHistory(EnginesHandle handle,
      {required String historyJson}) async {
    calls.add('writeHistory');
    storedHistory = historyJson;
  }

  @override
  Future<String> postprocessProfile(EnginesHandle handle) async {
    calls.add('postprocessProfile');
    return engineProfile;
  }

  @override
  Future<void> writeProfile(EnginesHandle handle, {required String json}) async {
    calls.add('writeProfile');
    persistedProfile = json;
  }

  @override
  Future<void> mergeProfileBenchmarks(EnginesHandle handle,
      {required String athleteProfileJson}) async {
    calls.add('mergeProfileBenchmarks');
    persistedProfile = athleteProfileJson;
  }

  @override
  Future<void> updateProfile(EnginesHandle handle,
      {required String athleteProfileJson}) async {
    calls.add('updateProfile');
    reboundProfile = athleteProfileJson;
  }

  @override
  Future<String> writeBenchmarkEvent(EnginesHandle handle,
      {required String eventJson}) async {
    calls.add('writeEvent');
    filedEvent = eventJson;
    return '{"audit_id":"a1"}';
  }

  @override
  Object? noSuchMethod(Invocation invocation) => null;
}

/// A canned engine PROMOTE response (shape per FFI_API_CONTRACT §4.15).
final _promoteJson = jsonEncode({
  'decision': 'promote',
  'cs_m_s': 4.12,
  'threshold_pace_sec_km': 243,
  'applied': true,
  'event': {
    'epoch_day': 20642,
    'sport': 'running',
    'kind': 'promote',
    'benchmark': 'threshold_pace_sec_km',
    'old_value': 250.0,
    'new_value': 243.0,
    'unit': 'sec_per_km',
    'measured_gain_pct': 3.0,
    'fit_r_squared': 0.99,
    'n_anchors': 6,
    'confirming_days': 2,
    'rate_capped': false,
  },
  'candidate_history': {
    'power': <Object>[],
    'speed': [
      {'epoch_day': 20640},
      {'epoch_day': 20642},
    ],
  },
  'athlete_profile': {'sport': 'running', 'threshold_pace_sec_km': 243},
});

final _holdJson = jsonEncode({
  'decision': 'hold',
  'reason': 'awaiting_pattern:1/2',
  'applied': false,
  'event': null,
  'candidate_history': {
    'power': <Object>[],
    'speed': [
      {'epoch_day': 20642},
    ],
  },
  'athlete_profile': {'sport': 'running', 'threshold_pace_sec_km': 250},
});

void main() {
  final handle = _FakeHandle();

  test('promote runs the full courier chain in order, all verbatim', () async {
    final binding = _RecordingBinding(syncReturn: _promoteJson)
      ..historyReturn = '{"power":[],"speed":[{"epoch_day":20640}]}';
    final service = BenchmarkSyncService(binding: binding, handle: handle);

    final outcome =
        await service.run(activityStreamsJson: '[{"samples":[4.2],"sample_rate_hz":1.0}]');

    expect(
      binding.calls,
      [
        'readHistory',
        'sync',
        'writeHistory',
        'postprocessProfile',
        'mergeProfileBenchmarks',
        'updateProfile',
        'writeEvent',
      ],
      reason: 'the courier order IS the contract',
    );
    // The history handed to the engine is exactly what the vault returned.
    expect(binding.syncHistoryArg, binding.historyReturn);
    // The streams pass through untouched.
    expect(binding.syncActivitiesArg, '[{"samples":[4.2],"sample_rate_hz":1.0}]');
    // The stored window is the engine's returned one (semantically verbatim).
    expect(jsonDecode(binding.storedHistory!),
        jsonDecode(_promoteJson)['candidate_history']);
    // The persisted + re-bound profile is the LIVE ENGINE'S own JSON —
    // proving no Dart re-assembly of the sync payload.
    expect(binding.persistedProfile, _RecordingBinding.engineProfile);
    expect(binding.reboundProfile, _RecordingBinding.engineProfile);
    // The filed event is the engine's own event.
    expect(jsonDecode(binding.filedEvent!), jsonDecode(_promoteJson)['event']);

    expect(outcome, isNotNull);
    expect(outcome!.decision, 'promote');
    expect(outcome.applied, isTrue);
    expect(outcome.eventJson, isNotNull);
  });

  test('hold stores the pruned window but writes no profile and no event',
      () async {
    final binding = _RecordingBinding(syncReturn: _holdJson);
    final service = BenchmarkSyncService(binding: binding, handle: handle);

    final outcome = await service.run(activityStreamsJson: '[]');

    expect(binding.calls, ['readHistory', 'sync', 'writeHistory'],
        reason: 'a hold is not an event — nothing else may be touched');
    expect(binding.persistedProfile, isNull);
    expect(binding.filedEvent, isNull);
    expect(outcome!.decision, 'hold');
    expect(outcome.applied, isFalse);
    expect(outcome.eventJson, isNull, reason: 'honest absence');
  });

  test('an engine failure writes nothing and returns null', () async {
    final binding = _RecordingBinding(syncReturn: _promoteJson)..failSync = true;
    final service = BenchmarkSyncService(binding: binding, handle: handle);

    final outcome = await service.run(activityStreamsJson: '[]');

    expect(outcome, isNull);
    expect(binding.calls, ['readHistory', 'sync'],
        reason: 'no write may follow a failed engine call');
    expect(binding.storedHistory, isNull);
    expect(binding.persistedProfile, isNull);
    expect(binding.filedEvent, isNull);
  });
}

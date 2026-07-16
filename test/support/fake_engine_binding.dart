// BS-017 stage 2 — the SHARED fake engine binding for headless Tier-1 tests.
//
// Rule-9 clean (BS-017 §a): this is a PURE FAKE at the binding seam. It
// COMPUTES NOTHING — it replays pinned engine JSON the test author supplies
// via [FakeEngineBinding.canned]. It is never a second engine, never an
// assembler tier, never a fallback source of values: an unmatched method
// replays a benign EMPTY ('{}' / '[]'), which every screen already treats as
// honest absence. The engine still DECIDES; the fake only stands in for the
// wire so screens pump headless with zero native library.
//
// Generalized from the existing `_RecordingBinding implements
// RustEngineBinding` pattern (test/ingest_adapter_test.dart,
// test/you_erase_test.dart, test/sensor_check_screen_test.dart).

import 'dart:typed_data';

import 'package:mivalta_flutter/rust_engine.dart';

/// Opaque FRB handle stand-in — screens only hold it and hand it back.
class FakeEnginesHandle implements EnginesHandle {
  @override
  Object? noSuchMethod(Invocation invocation) => null;
}

/// Canned value that makes a seam FAIL (the replayed future throws), for
/// engine-failure honest-absence assertions. The screen's catch path is the
/// behaviour under test — never a fabricated stand-in value.
class EngineCallFailure {
  const EngineCallFailure([this.message = 'canned engine failure']);
  final String message;
}

/// Fake binding: method-name → canned response replay.
///
/// [canned] values per method name:
///   * `String`  — replayed verbatim as the raw JSON the engine would return.
///   * `bool`    — for the bool-returning seams (`hasPersistedState`,
///                 `isLearningPaused`, `writeReadinessAssessment`).
///   * [EngineCallFailure] — the seam throws (engine-failure path).
///   * absent    — benign empty: `'[]'` for array-shaped reads, `'{}'`
///                 otherwise (honest absence, never a composed value).
class FakeEngineBinding implements RustEngineBinding {
  FakeEngineBinding({Map<String, Object>? canned, FakeEnginesHandle? handle})
      : canned = Map.of(canned ?? const {}),
        handle = handle ?? FakeEnginesHandle();

  /// Method-name → pinned engine JSON (or [EngineCallFailure] / bool).
  final Map<String, Object> canned;

  /// The handle returned by the (normally unused) construct* seams.
  final FakeEnginesHandle handle;

  /// Every seam name invoked, in order — for call-witness assertions.
  final List<String> calls = [];

  /// Seams whose real engine payload is a JSON ARRAY — their benign empty is
  /// `'[]'` so screens parse an empty list (honest absence), not a cast error.
  static const Set<String> _arrayShaped = {
    'readDailyLoads',
    'readBiometricHistory',
    'readRecentActivities',
    'readReadinessHistory',
    'readActivitiesInRange',
    'readAuditTrail',
    'readMetricAcrossActivities',
    'readRawObservationsByType',
    'readRawObservationsByActivity',
    'listDataSources',
    'fitnessSeries',
    'recommendWorkoutWithHistory',
  };

  Future<String> _replay(String name) {
    calls.add(name);
    final value = canned[name];
    if (value is EngineCallFailure) {
      return Future<String>.error(StateError(value.message));
    }
    if (value is String) return Future<String>.value(value);
    return Future<String>.value(_arrayShaped.contains(name) ? '[]' : '{}');
  }

  bool _replayBool(String name, {bool fallback = false}) {
    calls.add(name);
    final value = canned[name];
    if (value is EngineCallFailure) throw StateError(value.message);
    return value is bool ? value : fallback;
  }

  // ── Non-String-returning seams need explicit typed overrides (a
  //    noSuchMethod Future<String> would fail the implicit return cast). ──

  @override
  Future<EnginesHandle> constructEnginesFresh({
    required String athleteProfileJson,
    required String tablesJson,
    required String vaultPath,
  }) async {
    calls.add('constructEnginesFresh');
    return handle;
  }

  @override
  Future<EnginesHandle> constructEnginesFromState({
    required String athleteProfileJson,
    required String tablesJson,
    required String vaultPath,
    required String viterbiStateJson,
  }) async {
    calls.add('constructEnginesFromState');
    return handle;
  }

  @override
  Future<EnginesHandle> constructEngines({
    required String athleteProfileJson,
    required String tablesJson,
    required String vaultPath,
  }) async {
    calls.add('constructEngines');
    return handle;
  }

  @override
  Future<bool> hasPersistedState({
    required String athleteProfileJson,
    required String vaultPath,
  }) async =>
      _replayBool('hasPersistedState');

  @override
  Future<String?> readPersistedState({
    required String athleteProfileJson,
    required String vaultPath,
  }) async {
    calls.add('readPersistedState');
    return canned['readPersistedState'] as String?;
  }

  @override
  Future<String?> readProfileFromVault({
    required String athleteId,
    required String vaultPath,
  }) async {
    calls.add('readProfileFromVault');
    return canned['readProfileFromVault'] as String?;
  }

  @override
  Future<bool> isLearningPaused(EnginesHandle handle) async =>
      _replayBool('isLearningPaused');

  @override
  Future<bool> writeReadinessAssessment(
    EnginesHandle handle, {
    required String date,
  }) async =>
      _replayBool('writeReadinessAssessment');

  @override
  Future<int> writeRawObservation(EnginesHandle handle,
      {required String json}) async {
    calls.add('writeRawObservation');
    return 0;
  }

  @override
  Future<Uint8List> exportEncryptedVault(
    EnginesHandle handle, {
    required String athleteId,
    required String passphrase,
  }) async {
    calls.add('exportEncryptedVault');
    return Uint8List(0);
  }

  // ── Everything else returns Future<String> (or Future<void>, which a
  //    Future<String> satisfies) and routes through the canned replay. ──

  @override
  Object? noSuchMethod(Invocation invocation) {
    if (invocation.isMethod) {
      return _replay(_symbolName(invocation.memberName));
    }
    return super.noSuchMethod(invocation);
  }

  /// `Symbol("foo")` → `foo`. Test-only reflection convenience — tests are
  /// never minified, so the literal symbol name is stable.
  static String _symbolName(Symbol symbol) {
    final raw = symbol.toString();
    return raw.substring('Symbol("'.length, raw.length - 2);
  }
}

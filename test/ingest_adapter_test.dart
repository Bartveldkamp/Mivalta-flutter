// Task 0 — the shared vault-first ingest adapter.
//
// Pins the contract every input surface (BLE, Polar, health-store) relies on:
// one observation runs writeRawObservation → normalizeObservation →
// (writeBiometricFromObservation) → processObservation →
// markRawObservationProcessed, in that order, couriering the engine's normalized
// output forward (never a Dart-fabricated value). FFI is faked via a recording
// binding (the private ctor blocks subclassing; implement the interface).

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mivalta_flutter/rust_engine.dart';
import 'package:mivalta_flutter/services/ingest_adapter.dart';

class _FakeHandle implements EnginesHandle {
  @override
  Object? noSuchMethod(Invocation invocation) => null;
}

/// Records the five ingest calls in order, returns a distinct normalized
/// sentinel so we can prove process/mark consume THAT engine output (not the
/// raw vendor JSON, not a Dart value).
class _RecordingBinding implements RustEngineBinding {
  final List<String> calls = [];
  String? rawJson;
  ({String vendor, String json})? normalizeArgs;
  String? biometricJson;
  String? processedJson;
  ({int id, String observationJson})? markArgs;
  final List<String> activityWrites = [];

  /// The assessment process_observation returns (workout-core load courier).
  String assessmentReturn = '{}';

  /// When set, process_observation throws — exercises the workout core's
  /// load-absent-row-then-rethrow failure path.
  bool failProcess = false;

  @override
  Future<int> writeRawObservation(EnginesHandle handle,
      {required String json}) async {
    calls.add('raw');
    rawJson = json;
    return 42; // the row id step 5 must echo back
  }

  @override
  Future<String> normalizeObservation(EnginesHandle handle,
      {required String vendor, required String json}) async {
    calls.add('normalize');
    normalizeArgs = (vendor: vendor, json: json);
    return 'NORMALIZED'; // sentinel: the engine's normalized output
  }

  @override
  Future<void> writeBiometricFromObservation(EnginesHandle handle,
      {required String json}) async {
    calls.add('biometric');
    biometricJson = json;
  }

  @override
  Future<String> processObservation(EnginesHandle handle,
      {required String observationJson}) async {
    calls.add('process');
    processedJson = observationJson;
    if (failProcess) throw Exception('engine boom');
    return assessmentReturn;
  }

  @override
  Future<void> markRawObservationProcessed(EnginesHandle handle,
      {required int id, required String observationJson}) async {
    calls.add('mark');
    markArgs = (id: id, observationJson: observationJson);
  }

  @override
  Future<void> writeActivity(EnginesHandle handle,
      {required String activityJson}) async {
    calls.add('writeActivity');
    activityWrites.add(activityJson);
  }

  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not faked');
}

void main() {
  group('buildRawObservationJson', () {
    test('encodes the audit envelope with timestamp+vendor anchored to date noon UTC', () {
      final out = buildRawObservationJson(
        date: '2026-06-23',
        source: 'polar',
        dataType: 'biometric',
        payload: '{"hrv":55}',
      );
      final decoded = jsonDecode(out) as Map<String, dynamic>;
      expect(decoded['date'], '2026-06-23');
      expect(decoded['timestamp'], '2026-06-23T12:00:00.000Z');
      expect(decoded['source'], 'polar');
      expect(decoded['vendor'], 'polar'); // same as source
      expect(decoded['data_type'], 'biometric');
      expect(decoded['vendor_json'], '{"hrv":55}'); // raw vendor payload
    });

    test('vendor override: dispatch token diverges from the stored source', () {
      // The BLE split (T3/A5): audit keeps the device-specific id on `source`;
      // `vendor` carries the normalizer dispatch token.
      final out = buildRawObservationJson(
        date: '2026-06-23',
        source: 'polar_h10',
        dataType: 'activity',
        payload: '{"readings":[{"hr":60}]}',
        vendor: 'ble_hr',
      );
      final decoded = jsonDecode(out) as Map<String, dynamic>;
      expect(decoded['source'], 'polar_h10'); // device id, audit-preserved
      expect(decoded['vendor'], 'ble_hr'); // the dispatch key
    });
  });

  group('IngestAdapter.ingestObservation', () {
    test('runs the five steps in order, couriering normalized output forward',
        () async {
      final binding = _RecordingBinding();
      final result = await IngestAdapter(binding: binding, handle: _FakeHandle())
          .ingestObservation(
        date: '2026-06-23',
        source: 'polar',
        vendorJson: '{"hrv":55}',
        hasBiometrics: true,
      );

      // Exact order — the vault-first audited sequence.
      expect(binding.calls, ['raw', 'normalize', 'biometric', 'process', 'mark']);

      // Raw envelope carries the vendor payload + source.
      expect(jsonDecode(binding.rawJson!)['vendor_json'], '{"hrv":55}');
      expect(jsonDecode(binding.rawJson!)['source'], 'polar');

      // Normalize gets the RAW vendor json + the vendor id (engine dispatch).
      expect(binding.normalizeArgs!.vendor, 'polar');
      expect(binding.normalizeArgs!.json, '{"hrv":55}');

      // Steps 3/4/5 consume the engine's NORMALIZED output — never the raw json,
      // never a Dart-built value (Law 2 courier check).
      expect(binding.biometricJson, 'NORMALIZED');
      expect(binding.processedJson, 'NORMALIZED');
      expect(binding.markArgs!.observationJson, 'NORMALIZED');

      // Step 5 echoes the row id from step 1.
      expect(binding.markArgs!.id, 42);

      expect(result.mutated, isTrue);
      expect(result.hadBiometrics, isTrue);
    });

    test('skips the biometric write when hasBiometrics is false (activity-only)',
        () async {
      final binding = _RecordingBinding();
      final result = await IngestAdapter(binding: binding, handle: _FakeHandle())
          .ingestObservation(
        date: '2026-06-23',
        source: 'ble_hr',
        vendorJson: '{"hr":[120,121]}',
        hasBiometrics: false,
      );

      // No biometric step; the HMM still advances + raw still marked.
      expect(binding.calls, ['raw', 'normalize', 'process', 'mark']);
      expect(binding.biometricJson, isNull);
      expect(result.mutated, isTrue);
      expect(result.hadBiometrics, isFalse);
    });

    test('vendor override dispatches the token; source keeps the device id',
        () async {
      final binding = _RecordingBinding();
      await IngestAdapter(binding: binding, handle: _FakeHandle())
          .ingestObservation(
        date: '2026-06-23',
        source: 'polar_h10',
        vendor: 'ble_hr',
        vendorJson: '{"source":"polar_h10","readings":[{"hr":60}]}',
        hasBiometrics: false,
        dataType: 'activity',
      );

      // The FFI dispatch arg is the TOKEN, never the strap model id (the
      // engine dispatcher would reject it: "Unknown vendor: polar_h10").
      expect(binding.normalizeArgs!.vendor, 'ble_hr');
      // The stored envelope splits the same way.
      final raw = jsonDecode(binding.rawJson!) as Map<String, dynamic>;
      expect(raw['source'], 'polar_h10');
      expect(raw['vendor'], 'ble_hr');
    });
  });

  group('IngestAdapter.ingestWorkout', () {
    test('build → normalize → process → writeActivity, engine load couriered',
        () async {
      // process_observation returns the engine's assessment; the core couriers
      // its recorded_load onto the activity row (Dart computes NO load).
      final binding = _RecordingBinding()
        ..assessmentReturn = '{"recorded_load":62.5}';

      final result = await IngestAdapter(binding: binding, handle: _FakeHandle())
          .ingestWorkout(
        activityId: 'hk_1',
        date: '2026-06-30',
        activityType: 'ride',
        durationMinutes: 60.0,
        source: 'apple',
        start: DateTime.utc(2026, 6, 30, 17),
        avgHr: 145,
        maxHr: 172,
      );

      // Exact order: no biometric write, no record_activity (no double-count).
      expect(binding.calls, ['normalize', 'process', 'writeActivity']);

      // normalize() receives the WORKOUT-shaped apple payload (duration in
      // seconds, avg HR under associatedSamples) — not a biometric wire.
      final obs = jsonDecode(binding.normalizeArgs!.json) as Map<String, dynamic>;
      final workout = obs['workout'] as Map<String, dynamic>;
      expect(workout['duration'], 3600.0); // 60 min → 3600 s (unit conv)
      expect(workout['associatedSamples']['heartRate']['average'], 145);
      expect(binding.normalizeArgs!.vendor, 'apple');

      // process() consumes the engine's normalized output (Law 2 courier).
      expect(binding.processedJson, 'NORMALIZED');

      // The engine's recorded_load lands on load_uls — couriered, not computed.
      final act = jsonDecode(binding.activityWrites.single) as Map<String, dynamic>;
      expect(act['load_uls'], 62.5);
      expect(act['activity_type'], 'ride');
      expect(act['avg_heart_rate'], 145);
      expect(act['max_heart_rate'], 172);

      expect(result.recordedLoad, 62.5);
      expect(result.activityId, 'hk_1');
    });

    test(
        'couriers raw hr_samples to the engine (Law 2 — engine computes the mean)',
        () async {
      final binding = _RecordingBinding()
        ..assessmentReturn = '{"recorded_load":50.0}';

      // apple: raw samples land under associatedSamples.heartRate.samples.
      await IngestAdapter(binding: binding, handle: _FakeHandle()).ingestWorkout(
        activityId: 'hk_2',
        date: '2026-06-30',
        activityType: 'ride',
        durationMinutes: 60.0,
        source: 'apple',
        avgHr: 145,
        maxHr: 172,
        hrSamples: const [150.0, 160.0, 170.0],
      );
      final apple = jsonDecode(binding.normalizeArgs!.json) as Map<String, dynamic>;
      final hr = (apple['workout']['associatedSamples']['heartRate'])
          as Map<String, dynamic>;
      expect(hr['samples'], const [150.0, 160.0, 170.0],
          reason: 'raw samples couriered untransformed — the engine averages');

      // health_connect: raw samples land under exercise.hr_samples.
      await IngestAdapter(binding: binding, handle: _FakeHandle()).ingestWorkout(
        activityId: 'hc_2',
        date: '2026-06-30',
        activityType: 'ride',
        durationMinutes: 60.0,
        source: 'health_connect',
        avgHr: 145,
        hrSamples: const [150.0, 160.0, 170.0],
      );
      final hc = jsonDecode(binding.normalizeArgs!.json) as Map<String, dynamic>;
      expect((hc['exercise'] as Map<String, dynamic>)['hr_samples'],
          const [150.0, 160.0, 170.0]);
    });

    test('engine recorded no load → load_uls omitted (honest absence)', () async {
      final binding = _RecordingBinding()..assessmentReturn = '{}';

      final result = await IngestAdapter(binding: binding, handle: _FakeHandle())
          .ingestWorkout(
        activityId: 'hk_2',
        date: '2026-06-30',
        activityType: 'run',
        durationMinutes: 40.0,
        source: 'apple',
      );

      final act = jsonDecode(binding.activityWrites.single) as Map<String, dynamic>;
      expect(act.containsKey('load_uls'), isFalse);
      expect(result.recordedLoad, isNull);
    });

    test('engine failure: writes the load-absent row, THEN rethrows (fail loud)',
        () async {
      final binding = _RecordingBinding()..failProcess = true;

      await expectLater(
        IngestAdapter(binding: binding, handle: _FakeHandle()).ingestWorkout(
          activityId: 'hk_3',
          date: '2026-06-30',
          activityType: 'ride',
          durationMinutes: 30.0,
          source: 'apple',
        ),
        throwsA(isA<Exception>()),
      );

      // The journey row is still written (load-absent) before the rethrow — the
      // activity log is never silently dropped (Law 6).
      expect(binding.calls, ['normalize', 'process', 'writeActivity']);
      final act = jsonDecode(binding.activityWrites.single) as Map<String, dynamic>;
      expect(act.containsKey('load_uls'), isFalse);
      expect(act['activity_type'], 'ride');
    });
  });
}

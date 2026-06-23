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
    return '{}';
  }

  @override
  Future<void> markRawObservationProcessed(EnginesHandle handle,
      {required int id, required String observationJson}) async {
    calls.add('mark');
    markArgs = (id: id, observationJson: observationJson);
  }

  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not faked');
}

void main() {
  group('buildRawObservationJson', () {
    test('encodes the audit envelope verbatim', () {
      final out = buildRawObservationJson(
        date: '2026-06-23',
        source: 'polar',
        dataType: 'biometric',
        payload: '{"hrv":55}',
      );
      expect(jsonDecode(out), {
        'date': '2026-06-23',
        'source': 'polar',
        'data_type': 'biometric',
        'payload': '{"hrv":55}',
      });
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
      expect(jsonDecode(binding.rawJson!)['payload'], '{"hrv":55}');
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
  });
}

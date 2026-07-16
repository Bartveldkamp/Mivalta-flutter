// BLE HR session + service — packaging contract + end-to-end courier.
//
// Proves the session packs decoded readings into the ble.rs vendor-JSON
// contract, and that the service couriers a captured session through the shared
// Task-0 IngestAdapter (normalize → process → mark) with the FFI vendor arg
// PINNED to 'ble_hr' (BleHrService.bleVendor) while the device-specific id
// rides in the payload's `source` (ble.rs:44) — no fabricated values, empty
// sessions ingest nothing. Transport + FFI are faked (headless); live pairing
// is device-lab verified.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mivalta_flutter/rust_engine.dart';
import 'package:mivalta_flutter/services/ingest_adapter.dart';
import 'package:mivalta_flutter/services/ble/ble_transport.dart';
import 'package:mivalta_flutter/services/ble/ble_hr_service.dart';

class _FakeHandle implements EnginesHandle {
  @override
  Object? noSuchMethod(Invocation invocation) => null;
}

class _RecordingBinding implements RustEngineBinding {
  String? rawJson;
  ({String vendor, String json})? normalizeArgs;
  String? processedJson;
  bool biometricWritten = false;

  @override
  Future<int> writeRawObservation(EnginesHandle handle,
      {required String json}) async {
    rawJson = json;
    return 7;
  }

  @override
  Future<String> normalizeObservation(EnginesHandle handle,
      {required String vendor, required String json}) async {
    normalizeArgs = (vendor: vendor, json: json);
    return 'NORMALIZED';
  }

  @override
  Future<void> writeBiometricFromObservation(EnginesHandle handle,
      {required String json}) async {
    biometricWritten = true;
  }

  @override
  Future<String> processObservation(EnginesHandle handle,
      {required String observationJson}) async {
    processedJson = observationJson;
    return '{}';
  }

  @override
  Future<void> markRawObservationProcessed(EnginesHandle handle,
      {required int id, required String observationJson}) async {}

  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not faked');
}

/// Fake radio: replays a scripted notification stream; records connect/disconnect.
class _FakeTransport implements BleTransport {
  _FakeTransport(this._notifications);
  final List<List<int>> _notifications;
  bool connected = false;
  bool disconnected = false;

  @override
  Stream<BleDevice> scanForHeartRate() =>
      Stream.value(const BleDevice(id: 'dev1', name: 'Polar H10'));

  @override
  Future<void> connect(String deviceId) async {
    connected = true;
  }

  @override
  Future<void> disconnect() async {
    disconnected = true;
  }

  @override
  Stream<List<int>> heartRateNotifications() =>
      Stream.fromIterable(_notifications);
}

void main() {
  group('BleHrSession packaging (ble.rs contract)', () {
    test('packs decoded readings into the readings[] vendor JSON', () {
      final start = DateTime.utc(2026, 6, 23, 10, 0, 0);
      final s = BleHrSession(source: 'polar_h10', startedAt: start);
      // hr 60 + RR 1000ms at t=0; hr 62 at t=1s
      s.addNotification([0x10, 60, 0x00, 0x04], at: start);
      s.addNotification([0x00, 62],
          at: start.add(const Duration(seconds: 1)));

      final v = jsonDecode(s.toVendorJson(date: '2026-06-23'));
      expect(v['source'], 'polar_h10');
      expect(v['date'], '2026-06-23');
      expect(v['session_type'], 'workout');
      final readings = v['readings'] as List;
      expect(readings.length, 2);
      expect(readings[0]['hr'], 60);
      expect((readings[0]['rr'] as List).first, closeTo(1000.0, 1e-9));
      expect(readings[0]['ts'], closeTo(0.0, 1e-9));
      expect(readings[1]['hr'], 62);
      expect(readings[1]['ts'], closeTo(1.0, 1e-9));
      expect(v['duration_seconds'], 1);
    });

    test('malformed packets are dropped, never fabricated', () {
      final s = BleHrSession(source: 'ble_hr');
      s.addNotification([0x00]); // too short → dropped
      s.addNotification([]); // empty → dropped
      expect(s.isEmpty, isTrue);
    });

    test('empty session refuses to package (fail loud, no empty payload)', () {
      final s = BleHrSession(source: 'ble_hr');
      expect(() => s.toVendorJson(date: '2026-06-23'), throwsStateError);
    });
  });

  group('BleHrService end-to-end courier', () {
    test('captured session normalizes + processes via the BLE source', () async {
      final transport = _FakeTransport([
        [0x10, 60, 0x00, 0x04],
        [0x00, 62],
      ]);
      final binding = _RecordingBinding();
      final svc = BleHrService(
        transport: transport,
        adapter: IngestAdapter(binding: binding, handle: _FakeHandle()),
      );

      await svc.startSession('dev1', source: 'polar_h10');
      // Let the scripted notification stream drain.
      await Future<void>.delayed(Duration.zero);
      final result = await svc.stopSessionAndIngest(date: '2026-06-23');

      expect(transport.connected, isTrue);
      expect(transport.disconnected, isTrue);
      expect(result, isNotNull);
      expect(result!.hadBiometrics, isFalse); // workout obs, not a daily pillar
      expect(binding.biometricWritten, isFalse);
      // THE T3 VENDOR PIN: the FFI dispatch token is 'ble_hr' for EVERY
      // BLE-recorded observation (the engine dispatcher, T2 contract, accepts
      // "ble"|"ble_hr" — never a strap model id). The device-specific id
      // stays inside the payload's `source`, which ble.rs reads (ble.rs:44).
      expect(binding.normalizeArgs!.vendor, BleHrService.bleVendor);
      final sentPayload =
          jsonDecode(binding.normalizeArgs!.json) as Map<String, dynamic>;
      expect(sentPayload['source'], 'polar_h10');
      expect(sentPayload['readings'], isNotEmpty);
      // The stored raw-observation envelope splits the same way: audit keeps
      // the device id on `source`, the dispatch token on `vendor`.
      final rawEnvelope = jsonDecode(binding.rawJson!) as Map<String, dynamic>;
      expect(rawEnvelope['source'], 'polar_h10');
      expect(rawEnvelope['vendor'], BleHrService.bleVendor);
      // Engine's normalized output is what gets processed (courier check).
      expect(binding.processedJson, 'NORMALIZED');
    });

    test('a session with no readings ingests nothing (honest no-op)', () async {
      final transport = _FakeTransport([
        [0x00], // only malformed packets
      ]);
      final binding = _RecordingBinding();
      final svc = BleHrService(
        transport: transport,
        adapter: IngestAdapter(binding: binding, handle: _FakeHandle()),
      );
      await svc.startSession('dev1');
      await Future<void>.delayed(Duration.zero);
      final result = await svc.stopSessionAndIngest(date: '2026-06-23');

      expect(result, isNull);
      expect(binding.normalizeArgs, isNull); // nothing couriered
      expect(transport.disconnected, isTrue);
    });
  });
}

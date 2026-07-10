// SensorCheckScreen — BLE strap pairing UI over the (already-tested) service.
//
// The service/packaging/courier is proven in ble_hr_service_test.dart; this
// pins the SCREEN's contract: a scanned strap renders, connecting shows the
// live reading witness, and — the honest-absence rule — a session that captured
// no readings surfaces "No heart-rate readings were captured." (never a fake
// "saved"). The engine bootstrap + runtime permission are bypassed via the
// screen's test seams so the flow runs headless (no radio, no native FRB lib).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mivalta_flutter/rust_engine.dart';
import 'package:mivalta_flutter/screens/sensor_check_screen.dart';
import 'package:mivalta_flutter/services/ble/ble_hr_service.dart';
import 'package:mivalta_flutter/services/ble/ble_transport.dart';
import 'package:mivalta_flutter/services/ingest_adapter.dart';

class _FakeHandle implements EnginesHandle {
  @override
  Object? noSuchMethod(Invocation invocation) => null;
}

/// Records whether anything was couriered to the engine (proves the honest
/// no-op path ingests NOTHING on an empty session).
class _RecordingBinding implements RustEngineBinding {
  ({String vendor, String json})? normalizeArgs;

  @override
  Future<int> writeRawObservation(EnginesHandle handle,
          {required String json}) async =>
      7;

  @override
  Future<String> normalizeObservation(EnginesHandle handle,
      {required String vendor, required String json}) async {
    normalizeArgs = (vendor: vendor, json: json);
    return 'NORMALIZED';
  }

  @override
  Future<void> writeBiometricFromObservation(EnginesHandle handle,
      {required String json}) async {}

  @override
  Future<String> processObservation(EnginesHandle handle,
          {required String observationJson}) async =>
      '{}';

  @override
  Future<void> markRawObservationProcessed(EnginesHandle handle,
      {required int id, required String observationJson}) async {}

  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not faked');
}

/// Fake radio: advertises one strap, replays a scripted notification stream.
class _FakeTransport implements BleTransport {
  _FakeTransport(this._notifications);
  final List<List<int>> _notifications;
  bool disconnected = false;

  @override
  Stream<BleDevice> scanForHeartRate() =>
      Stream.value(const BleDevice(id: 'dev1', name: 'Polar H10'));

  @override
  Future<void> connect(String deviceId) async {}

  @override
  Future<void> disconnect() async {
    disconnected = true;
  }

  @override
  Stream<List<int>> heartRateNotifications() =>
      Stream.fromIterable(_notifications);
}

Widget _host(BleHrService service) => MaterialApp(
      home: SensorCheckScreen(
        serviceBuilder: () async => service,
        skipPermissionRequest: true,
      ),
    );

BleHrService _service(_FakeTransport transport, _RecordingBinding binding) =>
    BleHrService(
      transport: transport,
      adapter: IngestAdapter(binding: binding, handle: _FakeHandle()),
    );

void main() {
  testWidgets('scanned strap renders, then a captured session saves',
      (tester) async {
    final transport = _FakeTransport([
      [0x10, 60, 0x00, 0x04], // hr 60 + RR
      [0x00, 62], // hr 62
    ]);
    final binding = _RecordingBinding();
    await tester.pumpWidget(_host(_service(transport, binding)));
    // Let the injected builder resolve + scan stream emit the device.
    await tester.pump();
    await tester.pump();
    expect(find.text('Polar H10'), findsOneWidget);

    await tester.tap(find.text('Polar H10'));
    await tester.pump(); // connect() + notification drain
    await tester.pump(const Duration(seconds: 1)); // live-count poll fires

    expect(find.text('Save session'), findsOneWidget);
    await tester.tap(find.text('Save session'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Session saved.'), findsOneWidget);
    expect(transport.disconnected, isTrue);
    // A real session was couriered via the BLE source.
    expect(binding.normalizeArgs, isNotNull);
    expect(binding.normalizeArgs!.vendor, 'ble_hr');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a session with no valid readings → honest absence, no fake save',
      (tester) async {
    final transport = _FakeTransport([
      [0x00], // malformed only → dropped, never fabricated
    ]);
    final binding = _RecordingBinding();
    await tester.pumpWidget(_host(_service(transport, binding)));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Polar H10'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Save session'));
    await tester.pump();
    await tester.pump();

    expect(
      find.text('No heart-rate readings were captured.'),
      findsOneWidget,
    );
    // Honest no-op: nothing was couriered to the engine.
    expect(binding.normalizeArgs, isNull);
    expect(transport.disconnected, isTrue);
    expect(tester.takeException(), isNull);
  });
}

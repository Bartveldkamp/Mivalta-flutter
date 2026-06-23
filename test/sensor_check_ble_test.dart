// SensorCheckScreen — BLE HR-strap wiring (Task A production caller).
//
// Proves the wired pair → live → save flow drives BleHrService end-to-end and
// couriers the captured session through the engine ingest, and that WITHOUT a
// service the screen keeps its honest stub (behaviour-preserving). Transport +
// FFI are faked (headless); live pairing is device-lab verified.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mivalta_flutter/rust_engine.dart';
import 'package:mivalta_flutter/screens/sensor_check_screen.dart';
import 'package:mivalta_flutter/services/ingest_adapter.dart';
import 'package:mivalta_flutter/services/ble/ble_transport.dart';
import 'package:mivalta_flutter/services/ble/ble_hr_service.dart';

class _FakeHandle implements EnginesHandle {
  @override
  Object? noSuchMethod(Invocation invocation) => null;
}

class _RecordingBinding implements RustEngineBinding {
  ({String vendor, String json})? normalizeArgs;

  @override
  Future<int> writeRawObservation(EnginesHandle handle,
      {required String json}) async => 1;

  @override
  Future<String> normalizeObservation(EnginesHandle handle,
      {required String vendor, required String json}) async {
    normalizeArgs = (vendor: vendor, json: json);
    return 'NORMALIZED';
  }

  @override
  Future<String> processObservation(EnginesHandle handle,
      {required String observationJson}) async => '{}';

  @override
  Future<void> markRawObservationProcessed(EnginesHandle handle,
      {required int id, required String observationJson}) async {}

  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not faked');
}

class _FakeTransport implements BleTransport {
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
      Stream.fromIterable([
        [0x10, 60, 0x00, 0x04], // hr 60 + one RR
      ]);
}

void main() {
  testWidgets('no service → honest stub (Pair button absent, staged note shown)',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SensorCheckScreen()));
    expect(find.text(kPairHrButtonLabel), findsNothing);
    expect(find.text(kLiveWorkoutButtonLabel), findsOneWidget); // disabled stub
    expect(find.text(kSensorHrNotConnectedCopy), findsOneWidget);
  });

  testWidgets('wired service → pair → live → save couriers to the engine',
      (tester) async {
    final binding = _RecordingBinding();
    final transport = _FakeTransport();
    final svc = BleHrService(
      transport: transport,
      adapter: IngestAdapter(binding: binding, handle: _FakeHandle()),
    );

    // Push the screen onto a real navigator so its post-save pop returns cleanly.
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(ctx).push(
                MaterialPageRoute<void>(
                  builder: (_) => SensorCheckScreen(bleService: svc),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Wired path shows the real Pair affordance, not the disabled stub.
    expect(find.text(kPairHrButtonLabel), findsOneWidget);

    // Pair → scanning → the fake strap appears.
    await tester.tap(find.text(kPairHrButtonLabel));
    await tester.pump(); // scanning
    await tester.pump(); // scan stream delivers the device
    expect(find.text('Polar H10'), findsOneWidget);

    // Connect → live (a periodic display tick is now active, so avoid
    // pumpAndSettle until the session is stopped and the tick is cancelled).
    final deviceButton = find.widgetWithText(OutlinedButton, 'Polar H10');
    await tester.ensureVisible(deviceButton);
    await tester.pump();
    await tester.tap(deviceButton);
    await tester.pump(); // startSession future begins
    await tester.pump(const Duration(milliseconds: 200)); // connect + buffer
    await tester.pump();
    expect(find.text(kBleStopSaveButtonLabel), findsOneWidget);

    // Stop & save → the captured session couriers through the engine ingest.
    // (Discrete pumps, not pumpAndSettle — the saving-phase progress indicator
    // is an infinite animation that never "settles".)
    await tester.tap(find.text(kBleStopSaveButtonLabel));
    await tester.pump(); // cancels the live tick, renders saving, begins ingest
    await tester.pump(const Duration(milliseconds: 200)); // ingest + pop run
    await tester.pump();

    expect(transport.disconnected, isTrue);
    expect(binding.normalizeArgs, isNotNull);
    expect(binding.normalizeArgs!.vendor, 'ble_hr'); // default BLE source
  });
}

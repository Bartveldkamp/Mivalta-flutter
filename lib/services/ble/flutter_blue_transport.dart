// Real BLE radio transport over flutter_blue_plus.
//
// The ONLY file that imports flutter_blue_plus — it adapts the plugin to the
// MiValta [BleTransport] interface so all session/decode/packaging logic stays
// plugin-agnostic and headless-testable (ble_hr_service.dart + its tests).
//
// DEVICE-LAB VERIFIED: live scan/connect/notify needs a real Bluetooth radio +
// a real HR strap, so this file is compile/analyze-checked here but its live
// behaviour is signed off on the Mac/device lab (no radio in CI/headless).

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'ble_transport.dart';

/// Bluetooth SIG short UUIDs for the Heart Rate Service + Measurement char.
final Guid _hrServiceGuid = Guid('180D');
final Guid _hrMeasurementGuid = Guid('2A37');

class FlutterBlueTransport implements BleTransport {
  BluetoothDevice? _device;

  @override
  Stream<BleDevice> scanForHeartRate() async* {
    await FlutterBluePlus.startScan(
      withServices: [_hrServiceGuid],
      timeout: const Duration(seconds: 15),
    );
    // De-dupe across the rolling scan-results snapshots.
    final seen = <String>{};
    await for (final results in FlutterBluePlus.scanResults) {
      for (final r in results) {
        final id = r.device.remoteId.str;
        if (seen.add(id)) {
          final name = r.device.platformName.isNotEmpty
              ? r.device.platformName
              : r.advertisementData.advName;
          yield BleDevice(id: id, name: name);
        }
      }
    }
  }

  @override
  Future<void> connect(String deviceId) async {
    await FlutterBluePlus.stopScan();
    final device = BluetoothDevice.fromId(deviceId);
    await device.connect();
    _device = device;
  }

  @override
  Future<void> disconnect() async {
    final d = _device;
    _device = null;
    if (d != null) {
      await d.disconnect();
    }
  }

  @override
  Stream<List<int>> heartRateNotifications() async* {
    final device = _device;
    if (device == null) {
      throw StateError('FlutterBlueTransport: connect() before subscribing');
    }
    final services = await device.discoverServices();
    BluetoothCharacteristic? hrChar;
    for (final s in services) {
      if (s.uuid == _hrServiceGuid) {
        for (final c in s.characteristics) {
          if (c.uuid == _hrMeasurementGuid) {
            hrChar = c;
            break;
          }
        }
      }
    }
    if (hrChar == null) {
      throw StateError(
          'FlutterBlueTransport: Heart Rate Measurement (0x2A37) not found');
    }
    await hrChar.setNotifyValue(true);
    yield* hrChar.onValueReceived;
  }
}

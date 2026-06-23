// BLE transport abstraction — the seam between MiValta's BLE logic and the
// concrete radio plugin (flutter_blue_plus).
//
// All MiValta BLE orchestration depends on THIS interface, never on
// flutter_blue_plus directly, so the session/packaging/lifecycle logic is fully
// unit-testable with a fake transport (no radio, no strap). The real radio impl
// (FlutterBlueTransport) is the only file that imports the plugin, and is
// verified on the device lab (live pairing needs a real strap + Bluetooth).

/// A discovered BLE peripheral advertising the Heart Rate Service (0x180D).
class BleDevice {
  const BleDevice({required this.id, required this.name});

  /// Stable platform device identifier (used to reconnect a known strap).
  final String id;

  /// Advertised name (e.g. "Polar H10 1234ABCD") — display only.
  final String name;
}

/// The radio operations MiValta needs. Implemented for real by
/// `FlutterBlueTransport` (device lab) and by fakes in tests.
abstract class BleTransport {
  /// Scan for peripherals advertising the Heart Rate Service (0x180D). Emits
  /// each discovered device; the caller stops the scan by cancelling.
  Stream<BleDevice> scanForHeartRate();

  /// Connect (and bond if required) to a device by id.
  Future<void> connect(String deviceId);

  /// Disconnect the current device.
  Future<void> disconnect();

  /// Stream of raw Heart Rate Measurement (0x2A37) notification payloads from
  /// the connected device. Each event is the characteristic's raw bytes — the
  /// decode lives in `hr_measurement.dart`, not here (transport stays dumb).
  Stream<List<int>> heartRateNotifications();
}

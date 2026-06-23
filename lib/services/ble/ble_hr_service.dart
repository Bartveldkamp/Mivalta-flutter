// BLE HR-strap session service (Task A).
//
// Orchestrates: scan (0x180D) → connect → subscribe (0x2A37) → buffer decoded
// HR/RR readings for the session → on stop, package to the engine's BLE vendor
// JSON and courier through the shared Task-0 IngestAdapter (the SAME vault-first
// path BLE/Polar/health all use). COURIER ONLY (Law 2): the engine
// (gatc-normalizer/ble.rs) computes HRV/RMSSD, load, and recovery — Dart only
// un-packs device bytes and shuttles them. Malformed packets are dropped, never
// turned into a fabricated reading.
//
// Live pairing (the FlutterBlueTransport radio impl) is verified on the device
// lab; everything in THIS file is unit-tested headless via a fake transport.

import 'dart:async';
import 'dart:convert';

import '../ingest_adapter.dart';
import 'ble_transport.dart';
import 'hr_measurement.dart';

/// Accumulates decoded HR/RR readings for one live session and packages them
/// into the `ble.rs` vendor-JSON contract. Pure (no transport) — fully testable.
///
/// `ble.rs` expects: `{source, date, timestamp?, readings:[{hr, rr:[ms], ts}],
/// duration_seconds?}` with a non-empty `readings` array carrying at least one
/// `hr`. `ts` is seconds since session start.
class BleHrSession {
  BleHrSession({required this.source, DateTime? startedAt})
      : startedAt = startedAt ?? DateTime.now();

  /// Vendor/device source id the engine dispatches on (e.g. "ble_hr",
  /// "polar_h10"). Standard HR-profile straps all normalize via `ble.rs`.
  final String source;
  final DateTime startedAt;

  final List<Map<String, dynamic>> _readings = [];

  /// True until at least one valid HR reading lands — guards against shipping an
  /// empty `readings` array (`ble.rs` rejects it; honest absence, not a fake).
  bool get isEmpty => _readings.isEmpty;
  int get readingCount => _readings.length;

  /// Decode one raw 0x2A37 notification and buffer it. Drops malformed/empty
  /// packets silently (no fabricated HR). `at` defaults to now.
  void addNotification(List<int> raw, {DateTime? at}) {
    final m = decodeHeartRateMeasurement(raw);
    if (m == null) return;
    final ts = (at ?? DateTime.now()).difference(startedAt).inMilliseconds / 1000.0;
    _readings.add({
      'hr': m.heartRate,
      'rr': m.rrIntervalsMs,
      'ts': ts < 0 ? 0.0 : ts,
    });
  }

  /// Package to the `ble.rs` vendor JSON. `date` is the ISO day (YYYY-MM-DD).
  /// Throws [StateError] if no readings were captured — the caller must not
  /// ingest an empty session (fail loud, never an empty/fake payload).
  String toVendorJson({required String date}) {
    if (_readings.isEmpty) {
      throw StateError('BleHrSession: no readings captured — nothing to ingest');
    }
    final durationSeconds = (_readings.last['ts'] as double).round();
    return jsonEncode({
      'source': source,
      'date': date,
      'timestamp': startedAt.toUtc().toIso8601String(),
      'readings': _readings,
      'duration_seconds': durationSeconds,
      'session_type': 'workout',
    });
  }
}

/// Drives a BLE HR session end-to-end over a [BleTransport], couriering the
/// captured session into the engine via [IngestAdapter].
class BleHrService {
  BleHrService({required this.transport, required this.adapter});

  final BleTransport transport;
  final IngestAdapter adapter;

  BleHrSession? _session;
  StreamSubscription<List<int>>? _sub;

  /// Scan for HR-profile straps (0x180D). The caller renders the stream and
  /// picks a device; cancelling the subscription stops the scan.
  Stream<BleDevice> scan() => transport.scanForHeartRate();

  /// Connect to a chosen strap and begin buffering a live session. `source` is
  /// the device id the engine normalizes on (default "ble_hr").
  Future<void> startSession(
    String deviceId, {
    String source = 'ble_hr',
    DateTime? startedAt,
  }) async {
    await transport.connect(deviceId);
    _session = BleHrSession(source: source, startedAt: startedAt);
    _sub = transport.heartRateNotifications().listen((raw) {
      _session?.addNotification(raw);
    });
  }

  /// Most recent buffered HR (for the live display), or null before any reading.
  int get readingCount => _session?.readingCount ?? 0;

  /// Stop the session, disconnect, and courier the captured stream into the
  /// engine via the shared adapter. Returns the [IngestResult], or null when the
  /// session captured no readings (honest no-op — nothing ingested, no fake).
  /// `date` is the ISO session day.
  Future<IngestResult?> stopSessionAndIngest({required String date}) async {
    // Stop receiving (cleanup — not awaited; the notification listener is
    // null-guarded on `_session`, so a late packet during teardown is dropped,
    // never mis-attributed). Awaiting a subscription cancel must not gate the
    // ingest path.
    unawaited(_sub?.cancel());
    _sub = null;
    await transport.disconnect();

    final session = _session;
    _session = null;
    if (session == null || session.isEmpty) return null;

    // BLE-HR is a WORKOUT observation (engine computes load + post-workout
    // recovery from HR/RR); it is not a daily resting biometric, so the Journey
    // biometric-pillar write is skipped (hasBiometrics:false) — the HMM still
    // advances on the workout observation.
    return adapter.ingestObservation(
      date: date,
      source: session.source,
      vendorJson: session.toVendorJson(date: date),
      hasBiometrics: false,
      dataType: 'activity',
    );
  }

  /// Abort without ingesting (user cancelled / lost connection). Safe to call
  /// repeatedly.
  Future<void> abort() async {
    unawaited(_sub?.cancel());
    _sub = null;
    _session = null;
    await transport.disconnect();
  }
}

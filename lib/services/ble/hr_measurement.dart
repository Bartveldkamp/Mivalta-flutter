// Bluetooth SIG Heart Rate Measurement characteristic (0x2A37) decoder.
//
// Pure, deterministic byte → (hr, rr-intervals) parse per the public GATC Heart
// Rate Service (0x180D) spec — the same wire format every standard strap emits
// (Polar Verity Sense / H10, Garmin HRM, Wahoo TICKR). NO engine math here: this
// only un-packs the device's own bytes into honest values; HRV (RMSSD) and load
// are the engine's job (gatc-normalizer/ble.rs). Courier, not compute (Law 2).
//
// Wire format (Heart Rate Measurement, 0x2A37):
//   byte 0  Flags:
//     bit 0  HR value format   (0 = uint8, 1 = uint16 LE)
//     bit 1-2 sensor contact   (ignored here)
//     bit 3  Energy Expended present (uint16 LE)
//     bit 4  RR-Interval(s) present  (uint16 LE each, unit = 1/1024 s)
//   HR value (1 or 2 bytes per bit 0)
//   [Energy Expended: 2 bytes] if bit 3
//   [RR intervals: 2 bytes each] if bit 4 — fills the remaining bytes
// RR is converted to milliseconds: ms = raw * 1000 / 1024.

/// One decoded Heart Rate Measurement notification.
class HrMeasurement {
  const HrMeasurement({required this.heartRate, required this.rrIntervalsMs});

  /// Instantaneous heart rate (bpm).
  final int heartRate;

  /// RR intervals from THIS notification, in milliseconds (may be empty — many
  /// straps emit RR only intermittently, and chest straps emit 0–n per packet).
  final List<double> rrIntervalsMs;
}

/// Decode a raw 0x2A37 payload. Returns `null` for an empty/truncated packet
/// (honest absence — never a fabricated HR). Throws nothing: a malformed packet
/// is dropped by the caller, not turned into a fake reading.
HrMeasurement? decodeHeartRateMeasurement(List<int> bytes) {
  if (bytes.length < 2) return null; // need at least flags + 1 HR byte

  final flags = bytes[0];
  final hr16 = (flags & 0x01) != 0;
  final energyPresent = (flags & 0x08) != 0;
  final rrPresent = (flags & 0x10) != 0;

  var offset = 1;

  // Heart rate value.
  final int heartRate;
  if (hr16) {
    if (bytes.length < offset + 2) return null;
    heartRate = bytes[offset] | (bytes[offset + 1] << 8); // LE
    offset += 2;
  } else {
    heartRate = bytes[offset];
    offset += 1;
  }

  // Energy Expended (skip — not part of the HR/RR stream the engine consumes).
  if (energyPresent) {
    offset += 2;
    if (offset > bytes.length) return null; // truncated
  }

  // RR intervals (uint16 LE, unit 1/1024 s) → ms.
  final rr = <double>[];
  if (rrPresent) {
    while (offset + 1 < bytes.length) {
      final raw = bytes[offset] | (bytes[offset + 1] << 8); // LE
      rr.add(raw * 1000.0 / 1024.0);
      offset += 2;
    }
  }

  return HrMeasurement(heartRate: heartRate, rrIntervalsMs: rr);
}

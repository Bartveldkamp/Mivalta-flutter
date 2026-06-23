// Heart Rate Measurement (0x2A37) decoder — spec conformance.
//
// Vectors per the Bluetooth SIG Heart Rate Service. Proves HR format (uint8 /
// uint16 LE), Energy-Expended skip, RR-interval extraction + 1/1024 s → ms
// conversion, and honest-null on truncated/empty packets (never a fabricated HR).

import 'package:flutter_test/flutter_test.dart';
import 'package:mivalta_flutter/services/ble/hr_measurement.dart';

void main() {
  group('decodeHeartRateMeasurement', () {
    test('uint8 HR, no RR', () {
      final m = decodeHeartRateMeasurement([0x00, 60])!;
      expect(m.heartRate, 60);
      expect(m.rrIntervalsMs, isEmpty);
    });

    test('uint16 HR (LE), no RR', () {
      // flags bit0=1 → uint16; 0x00C8 = 200 bpm
      final m = decodeHeartRateMeasurement([0x01, 0xC8, 0x00])!;
      expect(m.heartRate, 200);
      expect(m.rrIntervalsMs, isEmpty);
    });

    test('uint8 HR + one RR interval (1024 → 1000 ms)', () {
      // flags bit4=1 → RR present; 1024 = 0x0400 LE → 1000.0 ms
      final m = decodeHeartRateMeasurement([0x10, 60, 0x00, 0x04])!;
      expect(m.heartRate, 60);
      expect(m.rrIntervalsMs, [closeTo(1000.0, 1e-9)]);
    });

    test('uint8 HR + multiple RR intervals', () {
      // two RR: 1024 (→1000ms) and 512 (→500ms)
      final m = decodeHeartRateMeasurement([0x10, 60, 0x00, 0x04, 0x00, 0x02])!;
      expect(m.heartRate, 60);
      expect(m.rrIntervalsMs.length, 2);
      expect(m.rrIntervalsMs[0], closeTo(1000.0, 1e-9));
      expect(m.rrIntervalsMs[1], closeTo(500.0, 1e-9));
    });

    test('Energy Expended present is skipped, no RR', () {
      // flags bit3=1 → 2 energy bytes (0x03E8) then nothing
      final m = decodeHeartRateMeasurement([0x08, 60, 0xE8, 0x03])!;
      expect(m.heartRate, 60);
      expect(m.rrIntervalsMs, isEmpty);
    });

    test('Energy Expended + RR: energy skipped, RR decoded', () {
      // flags bit3|bit4 = 0x18; energy 0x03E8 then RR 1024
      final m =
          decodeHeartRateMeasurement([0x18, 60, 0xE8, 0x03, 0x00, 0x04])!;
      expect(m.heartRate, 60);
      expect(m.rrIntervalsMs, [closeTo(1000.0, 1e-9)]);
    });

    test('uint16 HR + RR together', () {
      // flags bit0|bit4 = 0x11; HR 0x004B=75; RR 1024
      final m = decodeHeartRateMeasurement([0x11, 0x4B, 0x00, 0x00, 0x04])!;
      expect(m.heartRate, 75);
      expect(m.rrIntervalsMs, [closeTo(1000.0, 1e-9)]);
    });

    test('empty / single-byte packet → null (honest absence)', () {
      expect(decodeHeartRateMeasurement([]), isNull);
      expect(decodeHeartRateMeasurement([0x00]), isNull);
    });

    test('truncated uint16 HR → null', () {
      // flags says uint16 but only one HR byte present
      expect(decodeHeartRateMeasurement([0x01, 0x4B]), isNull);
    });

    test('odd trailing RR byte is ignored (no half-interval fabricated)', () {
      // one full RR (1024) then a dangling byte
      final m = decodeHeartRateMeasurement([0x10, 60, 0x00, 0x04, 0x05])!;
      expect(m.rrIntervalsMs, [closeTo(1000.0, 1e-9)]);
    });
  });
}

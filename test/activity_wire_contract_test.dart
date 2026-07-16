// PINNING TEST #4 (LAST-INCH T3) — Dart activity-wire builders vs the
// engine's serde-required fields.
//
// Engine wire: `ActivityWire`, mivalta-rust-engine
// crates/gatc-ffi/src/lib.rs:4553-4567 (verified against source 2026-07-16;
// re-verify at the pinned rev on every engine-pin bump — an engine-side field
// added WITHOUT `Option`/`#[serde(default)]` must break THIS test):
//
//   completed_at      chrono::DateTime<Utc>  REQUIRED — must parse as UTC; a
//                                            local ISO string without the
//                                            trailing 'Z' fails chrono
//                                            ("premature end of input")
//   power_samples     Vec<f64>               REQUIRED — no serde default; an
//                                            omitted field fails the WHOLE
//                                            wire ("missing field
//                                            power_samples")
//   hr_samples        Option<Vec<f64>>       optional (#[serde(default)])
//   sample_rate_hz    f64                    default_one_hz
//   power_timestamps  Option<Vec<f64>>       optional
//   hr_timestamps     Option<Vec<f64>>       optional
//   max_gap_secs      Option<f64>            optional
//
// Every Dart builder that feeds computeTimeInZone is enumerated here (traced
// this session — the ONLY two callers in lib/):
//   1. buildRevealActivityJson — lib/screens/session_reveal_screen.dart
//      (session reveal, from the live recorder's samples);
//   2. HealthIngestService.buildHrActivityJson — lib/services/health_ingest.dart
//      (health-store workout HR stream, per-sample timestamps).
//
// The A4 two-defect regression this pins against: the reveal payload once (a)
// omitted power_samples entirely and (b) serialized completed_at from a LOCAL
// DateTime — each alone fails engine-side serde, silently swallowed into the
// "no zones" absence state.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mivalta_flutter/screens/session_reveal_screen.dart';
import 'package:mivalta_flutter/services/health_ingest.dart';
import 'package:mivalta_flutter/services/session_recorder.dart';

/// Assert the serde-REQUIRED half of the ActivityWire contract on a decoded
/// builder output: `completed_at` is a UTC ('Z'-suffixed, parseable) instant
/// and `power_samples` is a present List (empty allowed — honest absence is
/// an empty stream, never a missing field).
void expectRequiredWireFields(Map<String, dynamic> wire) {
  expect(wire.containsKey('completed_at'), isTrue,
      reason: 'completed_at is serde-required');
  final completedAt = wire['completed_at'] as String;
  expect(completedAt, endsWith('Z'),
      reason: 'chrono DateTime<Utc> rejects a zone-less local ISO string');
  expect(DateTime.parse(completedAt).isUtc, isTrue);

  expect(wire.containsKey('power_samples'), isTrue,
      reason: 'power_samples has no #[serde(default)] — omission fails the '
          'whole wire');
  expect(wire['power_samples'], isA<List<dynamic>>());
}

void main() {
  group('buildRevealActivityJson (session reveal → computeTimeInZone)', () {
    // A deliberately LOCAL (non-UTC) end time — the A4 defect-2 shape.
    final localEnd = DateTime(2026, 7, 16, 18, 30, 5);

    test('HR-only session: full required wire, honest-empty power', () {
      final session = CompletedSession(
        sport: 'running',
        startTime: DateTime(2026, 7, 16, 17, 30, 5),
        endTime: localEnd,
        elapsedSeconds: 3600,
        hrSamples: const [120, 135, 150],
      );

      final wire =
          jsonDecode(buildRevealActivityJson(session)) as Map<String, dynamic>;
      expectRequiredWireFields(wire);

      // Defect 2 regression: the local end time is converted, not passed raw.
      expect(wire['completed_at'],
          localEnd.toUtc().toIso8601String());
      // Defect 1 regression: no power recorded → PRESENT empty list.
      expect(wire['power_samples'], isEmpty);
      // Real recorder samples couriered verbatim; 1 Hz is the recorder's
      // real sampling cadence, not a guess.
      expect(wire['hr_samples'], const [120, 135, 150]);
      expect(wire['sample_rate_hz'], 1);
    });

    test('recorded watts are couriered verbatim (real data beats parity)', () {
      final session = CompletedSession(
        sport: 'cycling',
        startTime: DateTime(2026, 7, 16, 17, 30, 5),
        endTime: localEnd,
        elapsedSeconds: 3600,
        hrSamples: const [120, 135],
        powerSamples: const [200, 210, 215],
      );

      final wire =
          jsonDecode(buildRevealActivityJson(session)) as Map<String, dynamic>;
      expectRequiredWireFields(wire);
      expect(wire['power_samples'], const [200, 210, 215]);
    });
  });

  group('HealthIngestService.buildHrActivityJson → computeTimeInZone', () {
    test('emits the full required wire from local platform timestamps', () {
      final start = DateTime(2026, 7, 16, 7, 0, 0); // local, like the plugin
      final end = DateTime(2026, 7, 16, 8, 0, 0);
      final json = HealthIngestService.buildHrActivityJson(
        workoutStart: start,
        workoutEnd: end,
        hrSamples: [
          (t: start.add(const Duration(seconds: 10)), bpm: 110.0),
          (t: start.add(const Duration(seconds: 20)), bpm: 120.0),
          (t: start.add(const Duration(seconds: 30)), bpm: 130.0),
        ],
      );
      expect(json, isNotNull);

      final wire = jsonDecode(json!) as Map<String, dynamic>;
      expectRequiredWireFields(wire);

      // Health stores carry no power stream → honest-empty, present.
      expect(wire['power_samples'], isEmpty);
      // The per-sample-dwell path: parallel hr streams, positive rate.
      expect((wire['hr_samples'] as List).length,
          (wire['hr_timestamps'] as List).length);
      expect(wire['sample_rate_hz'], greaterThan(0));
    });
  });
}

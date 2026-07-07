// Phase 4 (clean) — the benchmark stream courier + sport gate.
//
// Pins the COURIER contract, not any math: the recorder's RAW samples pass
// through unchanged with a unit tag; the engine (PR #397) owns the km/h→m/s
// conversion and the validation. Runner speed and cyclist power are symmetric;
// each sport is fed only its own stream, never the other's.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mivalta_flutter/services/benchmark_sync.dart';

void main() {
  group('benchmarkStreamsForSession — raw courier + sport gate', () {
    test('running couriers RAW km/h speed + unit tag (no Dart conversion)', () {
      final s = benchmarkStreamsForSession('running', [18.0, 14.4], null);
      expect(s, isNotNull);
      final wire = (jsonDecode(s!) as List).first as Map;
      // The samples are the recorder's km/h VALUES, untouched — the engine
      // divides by 3.6, not Dart. (18 stays 18, not 5.)
      expect((wire['samples'] as List).cast<double>(), [18.0, 14.4]);
      expect(wire['unit'], 'km_h');
      expect(wire['sample_rate_hz'], 1.0);
    });

    test(
      'cycling couriers RAW watts power + unit tag (the symmetric wire)',
      () {
        final s = benchmarkStreamsForSession('cycling', null, [250, 300, 0]);
        expect(s, isNotNull);
        final wire = (jsonDecode(s!) as List).first as Map;
        // Watts passed through as-is — including 0 (the engine keeps coasting).
        expect((wire['samples'] as List).cast<double>(), [250.0, 300.0, 0.0]);
        expect(wire['unit'], 'watts');
      },
    );

    test('each sport is fed ONLY its own stream, never the other\'s', () {
      // A runner with (accidentally) power samples still syncs from speed only.
      final run = benchmarkStreamsForSession('running', [12.0], [300]);
      expect(jsonDecode(run!).first['unit'], 'km_h');
      // A cyclist with (accidentally) speed samples syncs from power only.
      final ride = benchmarkStreamsForSession('cycling', [40.0], [280]);
      expect(jsonDecode(ride!).first['unit'], 'watts');
    });

    test('no stream for the sport, or an unsupported sport → null', () {
      // Running with no speed samples, cycling with no power — honest absence.
      expect(benchmarkStreamsForSession('running', null, [300]), isNull);
      expect(benchmarkStreamsForSession('running', const [], null), isNull);
      expect(benchmarkStreamsForSession('cycling', [40.0], null), isNull);
      expect(benchmarkStreamsForSession('cycling', null, const []), isNull);
      // Swim / anything else never feeds a benchmark from this path.
      expect(benchmarkStreamsForSession('swimming', [4.0], [200]), isNull);
    });
  });
}

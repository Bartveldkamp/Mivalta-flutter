// Tests for the Time-in-Zone model + chart (Monitor analytics).
//
// The model maps the engine's `compute_time_in_zone` wire shape; the chart
// renders it. No Dart-side binning — these assert parse + render fidelity only.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mivalta_flutter/models/time_in_zone.dart';
import 'package:mivalta_flutter/services/health_ingest.dart';
import 'package:mivalta_flutter/widgets/analytics/time_in_zone_chart.dart';

/// A representative engine payload: 9 canonical buckets, most time in Z2.
Map<String, dynamic> _sampleJson() => {
      'anchor': 'hr',
      'seconds': [
        {'zone': 'R', 'seconds': 0.0},
        {'zone': 'Z1', 'seconds': 300.0},
        {'zone': 'Z2', 'seconds': 600.0},
        {'zone': 'Z3', 'seconds': 0.0},
        {'zone': 'Z4', 'seconds': 120.0},
        {'zone': 'Z5', 'seconds': 0.0},
        {'zone': 'Z6', 'seconds': 0.0},
        {'zone': 'Z7', 'seconds': 0.0},
        {'zone': 'Z8', 'seconds': 0.0},
      ],
      'total_seconds': 1020.0,
    };

void main() {
  group('TimeInZone model', () {
    test('parses the engine wire shape with concrete values', () {
      final tiz = TimeInZone.fromJson(_sampleJson());
      expect(tiz.anchor, 'hr');
      expect(tiz.zones.length, 9, reason: 'R, Z1..Z8 always present');
      expect(tiz.totalSeconds, 1020.0);
      expect(tiz.isEmpty, isFalse);

      final z2 = tiz.zones.firstWhere((z) => z.zone == 'Z2');
      expect(z2.seconds, 600.0);
      expect(z2.minutes, 10, reason: '600 s = 10 min');

      // Dominant zone selection (engine owns the numbers; we only pick).
      expect(tiz.dominant?.zone, 'Z2');
      // Fraction is a pure ratio for bar sizing.
      expect(tiz.fraction(z2), closeTo(600.0 / 1020.0, 1e-9));
    });

    test('empty / malformed payloads are honestly empty, never thrown', () {
      expect(const TimeInZone(anchor: '', zones: [], totalSeconds: 0).isEmpty,
          isTrue);
      expect(TimeInZone.fromJson(null).isEmpty, isTrue);
      expect(TimeInZone.fromJson('not a map').isEmpty, isTrue);
      expect(TimeInZone.fromJson({'anchor': 'hr'}).zones, isEmpty);
    });
  });

  group('HealthIngestService.buildHrActivityJson (workout-sample ingest)', () {
    final start = DateTime.utc(2026, 6, 1, 12, 0, 0);

    test('maps intra-workout HR samples to the engine activity wire', () {
      // 600 one-per-second samples across a 600 s (10 min) workout.
      final end = start.add(const Duration(seconds: 600));
      final samples = List.generate(
        600,
        (i) => (t: start.add(Duration(seconds: i)), bpm: 150.0),
      );

      final json = HealthIngestService.buildHrActivityJson(
        workoutStart: start,
        workoutEnd: end,
        hrSamples: samples,
      );
      expect(json, isNotNull);
      final m = jsonDecode(json!) as Map<String, dynamic>;
      expect((m['hr_samples'] as List).length, 600);
      expect(m['sample_rate_hz'], 1.0, reason: '600 samples / 600 s = 1 Hz');
      expect(m['power_samples'], isEmpty);
      // Per-sample timestamps (epoch seconds) drive the engine's true-dwell
      // binning; parallel to hr_samples, monotonic, 1 s apart here.
      final ts = (m['hr_timestamps'] as List).cast<num>();
      expect(ts.length, 600);
      expect(ts[1] - ts[0], 1.0, reason: '1 s between readings');
      // Even-dwell fallback rate still makes total ≈ session (engine: n / rate).
      expect((m['hr_samples'] as List).length / (m['sample_rate_hz'] as num),
          600);
    });

    test('drops zero-bpm dropouts and orders by time', () {
      final end = start.add(const Duration(seconds: 4));
      final samples = [
        (t: start.add(const Duration(seconds: 2)), bpm: 152.0),
        (t: start.add(const Duration(seconds: 0)), bpm: 0.0), // dropout
        (t: start.add(const Duration(seconds: 1)), bpm: 148.0),
      ];
      final json = HealthIngestService.buildHrActivityJson(
        workoutStart: start,
        workoutEnd: end,
        hrSamples: samples,
      );
      final m = jsonDecode(json!) as Map<String, dynamic>;
      expect(m['hr_samples'], [148.0, 152.0], reason: 'dropout gone, sorted');
    });

    test('returns null for too-few samples or a non-positive window', () {
      expect(
        HealthIngestService.buildHrActivityJson(
          workoutStart: start,
          workoutEnd: start.add(const Duration(seconds: 60)),
          hrSamples: [(t: start, bpm: 150.0)],
        ),
        isNull,
        reason: 'a single sample is not a distribution',
      );
      expect(
        HealthIngestService.buildHrActivityJson(
          workoutStart: start,
          workoutEnd: start, // zero-length window
          hrSamples: [
            (t: start, bpm: 150.0),
            (t: start, bpm: 151.0),
          ],
        ),
        isNull,
      );
    });
  });

  group('TimeInZoneChart widget', () {
    testWidgets('renders a bar + minute label per non-empty zone', (t) async {
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TimeInZoneChart(data: TimeInZone.fromJson(_sampleJson())),
        ),
      ));

      expect(find.text('Time in zone'), findsOneWidget);
      expect(find.text('Heart rate'), findsOneWidget, reason: 'hr anchor label');

      // Only the three zones with time render (Z1, Z2, Z4); empties are hidden.
      expect(find.text('Z2'), findsOneWidget);
      expect(find.text('Z1'), findsOneWidget);
      expect(find.text('Z4'), findsOneWidget);
      expect(find.text('Z3'), findsNothing);

      // Engine-computed minutes are surfaced verbatim.
      expect(find.text('10m'), findsOneWidget, reason: 'Z2 = 600 s');
      expect(find.text('5m'), findsOneWidget, reason: 'Z1 = 300 s');
      expect(find.text('2m'), findsOneWidget, reason: 'Z4 = 120 s');
    });

    testWidgets('shows the no-data state for an empty distribution', (t) async {
      await t.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: TimeInZoneChart(
            data: TimeInZone(anchor: '', zones: [], totalSeconds: 0),
          ),
        ),
      ));
      expect(find.text('No zone data for this activity yet.'), findsOneWidget);
      expect(find.text('Time in zone'), findsNothing);
    });
  });
}

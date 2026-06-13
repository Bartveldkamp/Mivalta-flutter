// Tests for the DEBUG-only DemoSeeder.
//
// The seeder's whole reason to exist is to give a data-starved simulator real
// functionality WITHOUT faking the display. These tests pin that contract:
//   - it feeds each day through normalize -> process (the REAL ingest path),
//   - it persists only the engine's OWN computed state (never a fabricated one),
//   - it dates the seeded window to end today (calendar-day windowing safety),
//   - it clamps to the season length.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mivalta_flutter/debug/demo_seeder.dart';
import 'package:mivalta_flutter/rust_engine.dart';

class _FakeHandle implements EnginesHandle {
  @override
  Object? noSuchMethod(Invocation invocation) => null;
}

/// Records the calls the seeder makes. Implements (not extends) the binding —
/// the private constructor blocks subclassing — and overrides only the four
/// methods the seeder touches; everything else no-ops.
class _RecordingBinding implements RustEngineBinding {
  final List<({String vendor, String json})> normalized = [];
  final List<String> processed = [];
  int saveStateCalls = 0;
  final List<String> persistedStates = [];

  int _counter = 0;

  @override
  Future<String> normalizeObservation(
    EnginesHandle handle, {
    required String vendor,
    required String json,
  }) async {
    normalized.add((vendor: vendor, json: json));
    // Return a distinct sentinel so we can prove process() gets THIS output.
    return 'normalized:${_counter++}';
  }

  @override
  Future<String> processObservation(
    EnginesHandle handle, {
    required String observationJson,
  }) async {
    processed.add(observationJson);
    return '{}';
  }

  @override
  Future<String> saveState(EnginesHandle handle) async {
    saveStateCalls++;
    // The engine's OWN serialized state — what an honest persist must store.
    return '{"engine_state":true}';
  }

  @override
  Future<void> writeViterbiState(
    EnginesHandle handle, {
    required String stateJson,
  }) async {
    persistedStates.add(stateJson);
  }

  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not faked');
}

List<Map<String, dynamic>> _season(int n) => [
      for (var i = 0; i < n; i++)
        {
          'offset': -(n - 1 - i),
          'resting_heart_rate': {'value': 53.0 + i, 'unit': 'count/min'},
          'hrv_sdnn': {'value': 64.0 - i, 'unit': 'ms'},
          'oxygen_saturation': {'value': 0.98, 'unit': '%'},
          'sleep_hours': 7.5,
        },
    ];

void main() {
  group('DemoSeeder', () {
    test('feeds each day through normalize -> process, persists once', () async {
      final binding = _RecordingBinding();
      final seeder = DemoSeeder(
        binding: binding,
        handle: _FakeHandle(),
        seasonLoader: () async => _season(5),
      );

      final result = await seeder.seedSeason(days: 3);

      expect(result.daysSeeded, 3);
      expect(result.daysAvailable, 5);
      expect(binding.normalized.length, 3);
      expect(binding.processed.length, 3);

      // Every observation entered as the Apple HealthKit vendor wire.
      expect(binding.normalized.every((c) => c.vendor == 'apple'), isTrue);

      // process() received exactly what normalize() returned — the real
      // pipeline, in order, not a shortcut.
      expect(binding.processed, ['normalized:0', 'normalized:1', 'normalized:2']);
    });

    test('persists ONLY the engine-computed state — never a fabricated one',
        () async {
      final binding = _RecordingBinding();
      final seeder = DemoSeeder(
        binding: binding,
        handle: _FakeHandle(),
        seasonLoader: () async => _season(4),
      );

      await seeder.seedSeason(days: 4);

      // State persisted exactly once, and it is verbatim the engine's own
      // saveState() output. The seeder authors no readiness/state of its own.
      expect(binding.saveStateCalls, 1);
      expect(binding.persistedStates, ['{"engine_state":true}']);
    });

    test('clamps requested days to the season length', () async {
      final binding = _RecordingBinding();
      final seeder = DemoSeeder(
        binding: binding,
        handle: _FakeHandle(),
        seasonLoader: () async => _season(6),
      );

      final result = await seeder.seedSeason(days: 1000);
      expect(result.daysSeeded, 6);
      expect(binding.processed.length, 6);
    });

    test('dates the seeded window to END today (no stale observations)',
        () async {
      final binding = _RecordingBinding();
      final seeder = DemoSeeder(
        binding: binding,
        handle: _FakeHandle(),
        seasonLoader: () async => _season(5),
      );

      await seeder.seedSeason(days: 3);

      final dates = binding.normalized
          .map((c) => jsonDecode(c.json)['date'] as String)
          .toList();

      final now = DateTime.now();
      String iso(DateTime d) =>
          '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';

      // Oldest first, last entry is today; 3 consecutive days ending today.
      expect(dates.last, iso(DateTime(now.year, now.month, now.day)));
      expect(dates.first,
          iso(DateTime(now.year, now.month, now.day).subtract(const Duration(days: 2))));
    });

    test('seeding zero days touches nothing (no empty-persist)', () async {
      final binding = _RecordingBinding();
      final seeder = DemoSeeder(
        binding: binding,
        handle: _FakeHandle(),
        seasonLoader: () async => _season(5),
      );

      final result = await seeder.seedSeason(days: 0);
      expect(result.daysSeeded, 0);
      expect(binding.normalized, isEmpty);
      expect(binding.processed, isEmpty);
      expect(binding.saveStateCalls, 0);
      expect(binding.persistedStates, isEmpty);
    });

    test('builds the HealthKit wire: scalar metrics + one nightly sleep sample',
        () async {
      final binding = _RecordingBinding();
      final seeder = DemoSeeder(
        binding: binding,
        handle: _FakeHandle(),
        seasonLoader: () async => _season(2),
      );

      await seeder.seedSeason(days: 1);

      final wire = jsonDecode(binding.normalized.single.json) as Map<String, dynamic>;
      expect(wire['resting_heart_rate'], isNotNull);
      expect(wire['hrv_sdnn'], isNotNull);
      expect(wire['oxygen_saturation'], isNotNull);
      final sleep = wire['sleep_samples'] as List;
      expect(sleep, hasLength(1));
      // AsleepUnspecified (code 1) — the normalizer counts it as sleep.
      expect((sleep.single as Map)['value'], 1);
    });
  });
}

// Tests for the DEBUG-only DemoSeeder.
//
// The seeder's whole reason to exist is to give a data-starved simulator real
// functionality WITHOUT faking the display. These tests pin that contract:
//   - it feeds each day through the SHARED 5-step vault-first IngestAdapter path
//     (write raw -> normalize -> write biometric -> process -> mark processed) —
//     the SAME audited path production uses, so the seeded vault carries the
//     biometric rows the Journey/HRV/RHR/sleep surfaces read,
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
/// the private constructor blocks subclassing — and overrides only the methods
/// the seeder touches via the shared IngestAdapter (writeRawObservation,
/// normalizeObservation, writeBiometricFromObservation, processObservation,
/// markRawObservationProcessed, saveState, writeViterbiState); everything else
/// no-ops/throws.
class _RecordingBinding implements RustEngineBinding {
  final List<String> rawWrites = [];
  final List<({String vendor, String json})> normalized = [];
  final List<String> biometricWrites = [];
  final List<String> processed = [];
  final List<({int id, String observationJson})> marked = [];
  int saveStateCalls = 0;
  final List<String> persistedStates = [];
  final List<String> activityWrites = [];

  int _counter = 0;
  int _rawId = 0;

  @override
  Future<int> writeRawObservation(
    EnginesHandle handle, {
    required String json,
  }) async {
    rawWrites.add(json);
    return _rawId++;
  }

  @override
  Future<String> normalizeObservation(
    EnginesHandle handle, {
    required String vendor,
    required String json,
  }) async {
    normalized.add((vendor: vendor, json: json));
    // Return a distinct sentinel so we can prove the downstream steps get THIS
    // output (biometric write, process, mark all receive the normalized form).
    return 'normalized:${_counter++}';
  }

  @override
  Future<void> writeBiometricFromObservation(
    EnginesHandle handle, {
    required String json,
  }) async {
    biometricWrites.add(json);
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
  Future<void> markRawObservationProcessed(
    EnginesHandle handle, {
    required int id,
    required String observationJson,
  }) async {
    marked.add((id: id, observationJson: observationJson));
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
  Future<void> writeActivity(
    EnginesHandle handle, {
    required String activityJson,
  }) async {
    activityWrites.add(activityJson);
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
    test('feeds each day through the full 5-step vault-first path, persists once',
        () async {
      final binding = _RecordingBinding();
      final seeder = DemoSeeder(
        binding: binding,
        handle: _FakeHandle(),
        seasonLoader: () async => _season(5),
      );

      final result = await seeder.seedSeason(days: 3);

      expect(result.daysSeeded, 3);
      expect(result.daysAvailable, 5);

      // All five vault-first steps ran once per seeded day — the SAME audited
      // path production uses, not a hand-rolled subset.
      expect(binding.rawWrites.length, 3);
      expect(binding.normalized.length, 3);
      expect(binding.biometricWrites.length, 3,
          reason: 'biometric rows MUST be written — the Journey/HRV/RHR/sleep '
              'tiles read these; skipping them was the false-witness bug');
      expect(binding.processed.length, 3);
      expect(binding.marked.length, 3);

      // Every observation entered as the Apple HealthKit vendor wire.
      expect(binding.normalized.every((c) => c.vendor == 'apple'), isTrue);

      // The biometric write, process, and mark steps each received exactly what
      // normalize() returned — the real pipeline, in order, not a shortcut.
      expect(
          binding.biometricWrites, ['normalized:0', 'normalized:1', 'normalized:2']);
      expect(binding.processed, ['normalized:0', 'normalized:1', 'normalized:2']);
      expect(binding.marked.map((m) => m.observationJson).toList(),
          ['normalized:0', 'normalized:1', 'normalized:2']);
      // mark closes the SAME raw row the write opened (ids returned in order).
      expect(binding.marked.map((m) => m.id).toList(), [0, 1, 2]);
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
      expect(binding.rawWrites, isEmpty);
      expect(binding.normalized, isEmpty);
      expect(binding.biometricWrites, isEmpty);
      expect(binding.processed, isEmpty);
      expect(binding.marked, isEmpty);
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

    test('null-HRV day → wire OMITS hrv_sdnn (honest absence), keeps RHR + sleep',
        () async {
      final binding = _RecordingBinding();
      final seeder = DemoSeeder(
        binding: binding,
        handle: _FakeHandle(),
        // A day with no hrv_sdnn — a night with no HRV reading (mirrors the
        // null-HRV day now in demo_season.json for the witness pass §8.0).
        seasonLoader: () async => [
          {
            'offset': 0,
            'resting_heart_rate': {'value': 53.0, 'unit': 'count/min'},
            'oxygen_saturation': {'value': 0.98, 'unit': '%'},
            'sleep_hours': 7.5,
          },
        ],
      );

      await seeder.seedSeason(days: 1);

      final wire =
          jsonDecode(binding.normalized.single.json) as Map<String, dynamic>;
      // Absent HRV is OMITTED, never sent as null (honest absence, Charter).
      expect(wire.containsKey('hrv_sdnn'), isFalse,
          reason: 'absent HRV must be omitted, not sent as null');
      // The rest of the day still couriers through.
      expect(wire['resting_heart_rate'], isNotNull);
      expect(wire['sleep_samples'], isNotNull);
    });

    test('a fixture day with a workout drives the REAL shared workout core',
        () async {
      final binding = _RecordingBinding();
      final seeder = DemoSeeder(
        binding: binding,
        handle: _FakeHandle(),
        // A day carrying a completed workout (§8.0 activity seed) — given
        // session scalars only (no HR series; TIZ is not seeded — Option B).
        seasonLoader: () async => [
          {
            'offset': 0,
            'resting_heart_rate': {'value': 53.0, 'unit': 'count/min'},
            'hrv_sdnn': {'value': 64.0, 'unit': 'ms'},
            'oxygen_saturation': {'value': 0.98, 'unit': '%'},
            'sleep_hours': 7.5,
            'workout': {
              'activity_type': 'ride',
              'duration_min': 60,
              'avg_hr': 145,
              'max_hr': 165,
            },
          },
        ],
      );

      final result = await seeder.seedSeason(days: 1);

      expect(result.workoutsSeeded, 1);

      // The workout rode the SAME real core production uses → exactly one
      // activity row written, carrying the couriered session scalars.
      expect(binding.activityWrites, hasLength(1));
      final act =
          jsonDecode(binding.activityWrites.single) as Map<String, dynamic>;
      expect(act['activity_type'], 'ride');
      expect(act['duration_minutes'], 60.0);
      expect(act['avg_heart_rate'], 145);
      expect(act['max_heart_rate'], 165);
      expect(act['source'], 'apple');
      // The fake binding's process returns '{}' (no engine load) → the row omits
      // load_uls (honest absence), never a Dart-fabricated load.
      expect(act.containsKey('load_uls'), isFalse);

      // The workout also went through normalize+process (HMM advanced): the day
      // produced TWO normalize calls — the biometric wire AND the workout wire,
      // the latter carrying the apple `workout` object.
      expect(binding.normalized.length, 2);
      expect(
        binding.normalized
            .any((c) => (jsonDecode(c.json) as Map).containsKey('workout')),
        isTrue,
        reason: 'the workout couriered through the real normalize/process path',
      );
    });

    test('a day with no workout ingests none (workoutsSeeded 0, no rows)',
        () async {
      final binding = _RecordingBinding();
      final seeder = DemoSeeder(
        binding: binding,
        handle: _FakeHandle(),
        seasonLoader: () async => _season(3),
      );

      final result = await seeder.seedSeason(days: 3);

      expect(result.workoutsSeeded, 0);
      expect(binding.activityWrites, isEmpty);
    });
  });
}

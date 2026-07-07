// DEBUG-ONLY developer tool — seeds a *simulated athlete*.
//
// WHAT THIS IS (and is not):
//   It replays a committed, SYNTHETIC season of raw HealthKit-shaped biometrics
//   (assets/debug/demo_season.json) through the EXACT SAME ingest path a real
//   watch/Oura sync uses: the shared `IngestAdapter.ingestObservation` 5-step
//   vault-first sequence (write raw -> normalize -> write biometric -> process
//   -> mark processed) -> saveState/writeViterbiState. Routing through the
//   adapter (not a hand-rolled subset) is what makes this claim true and writes
//   the biometric rows the Journey/HRV/RHR/sleep surfaces read.
//
//   A day may also carry a completed `workout` (§8.0 activity seed): it is
//   ingested through the SAME real workout core production uses
//   (`IngestAdapter.ingestWorkout`), so the engine computes the HR-based load
//   and the vault-backed surfaces — Journey row, workout-detail, post-workout
//   report — paint from real engine output. Time-in-zone is deliberately NOT
//   seeded (it is a live-capture surface, witnessed via a real/injected
//   workout), so the fixture carries no HR series and the seeder couriers only
//   the given session scalars.
//
//   The engine genuinely computes every readiness state and load from this
//   input. Nothing on the DISPLAY side is fabricated — the only synthetic thing
//   is the biometric + workout stream, exactly as it would be on a bench test.
//   This is the on-device analog of dev_sim / realworld_sim: synthetic INPUT,
//   real PIPELINE.
//
//   It is NOT a "fake screen": it never writes a readiness score, a state, or
//   Josi prose. It cannot, by construction — it only feeds raw observations and
//   lets the real HMM decide. (Architecture rule 3 + the locked honest-silence
//   rule stay intact.)
//
// SAFETY (the no-destroy guarantee):
//   * Every call site is gated behind `kDebugMode`, so this is compiled out of
//     release builds entirely.
//   * Seeding only ADDS real-pipeline observations to the vault — the same
//     bytes a watch would write. It cannot corrupt the production flow.
//   * To return to honest cold-start, use Settings -> "Delete All My Data"
//     (the existing crypto-erase), which wipes the vault and re-onboards.
//
// Dates are assigned at replay time (each day's `offset` -> today + offset)
// because the Viterbi monitor uses calendar-day windowing (42-day window, stale
// data excluded); baking absolute past dates into the fixture would make it
// stale on load.

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../rust_engine.dart';
import '../services/benchmark_sync.dart';
import '../services/ingest_adapter.dart' as ingest;

/// Outcome of a seed run — how many days were replayed out of the season.
class DemoSeedResult {
  const DemoSeedResult({
    required this.daysSeeded,
    required this.daysAvailable,
    this.workoutsSeeded = 0,
  });

  final int daysSeeded;
  final int daysAvailable;

  /// How many completed workouts in the seeded window were ingested through the
  /// real workout core (§8.0 activity seed). 0 when the seeded slice has none.
  final int workoutsSeeded;
}

/// Replays the committed demo season through the real engine ingest path.
/// Construct with the SAME binding + handle the home owns so the simulated
/// observations land in the live engine/vault.
class DemoSeeder {
  DemoSeeder({
    required this.binding,
    required this.handle,
    this.seasonLoader,
  });

  final RustEngineBinding binding;
  final EnginesHandle handle;

  /// Test seam: override where the season comes from. Production leaves this
  /// null and reads the committed asset.
  final Future<List<Map<String, dynamic>>> Function()? seasonLoader;

  static const String _assetPath = 'assets/debug/demo_season.json';

  /// Vendor key for the Apple HealthKit normalizer — identical to the iOS auto
  /// sync (`HealthIngestService` uses `'apple'`).
  static const String _vendor = 'apple';

  Future<List<Map<String, dynamic>>> _loadSeason() =>
      (seasonLoader ?? _loadFromAsset)();

  Future<List<Map<String, dynamic>>> _loadFromAsset() async {
    final raw = await rootBundle.loadString(_assetPath);
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return (decoded['days'] as List)
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList(growable: false);
  }

  /// Turn one fixture row (scalar biometrics + `offset` + `sleep_hours`) into
  /// the HealthKit wire the normalizer expects — assigning the real date and
  /// synthesizing a single nightly sleep sample. Transport only: it shapes
  /// INPUT, it computes nothing about readiness.
  Map<String, dynamic> _toHealthKitJson(Map<String, dynamic> row, DateTime today) {
    final offset = (row['offset'] as num).toInt();
    final date = DateTime(today.year, today.month, today.day)
        .add(Duration(days: offset));
    final dateStr = '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';

    // Omit absent biometrics rather than send `null` — honest absence (Charter
    // PRIME DIRECTIVE). A fixture day may legitimately lack a metric (e.g. a
    // night with no HRV reading); the normalizer then sees the field as absent,
    // not as a fabricated/null value, so the no-HRV path renders honestly.
    final wire = <String, dynamic>{'date': dateStr};
    if (row['resting_heart_rate'] != null) {
      wire['resting_heart_rate'] = row['resting_heart_rate'];
    }
    if (row['hrv_sdnn'] != null) wire['hrv_sdnn'] = row['hrv_sdnn'];
    if (row['oxygen_saturation'] != null) {
      wire['oxygen_saturation'] = row['oxygen_saturation'];
    }

    // One consolidated AsleepUnspecified (code 1) sample spanning the night,
    // waking at 07:00 on `date`. The normalizer aggregates asleep stages into
    // total sleep; a single span is sufficient for the total-sleep signal.
    final sleepHours = (row['sleep_hours'] as num?)?.toDouble();
    if (sleepHours != null && sleepHours > 0) {
      final wake = DateTime(date.year, date.month, date.day, 7);
      final start = wake.subtract(
        Duration(minutes: (sleepHours * 60).round()),
      );
      wire['sleep_samples'] = [
        {
          'value': 1,
          'startDate': start.toUtc().toIso8601String(),
          'endDate': wake.toUtc().toIso8601String(),
        },
      ];
    }
    return wire;
  }

  /// Ingest the day's completed `workout` (if the fixture row carries one)
  /// through the SAME real shared workout core production uses
  /// (`IngestAdapter.ingestWorkout`). Transport only: it couriers the fixture's
  /// given session scalars (activity_type, duration, avg/max HR) to the engine,
  /// which computes the HR-based load; it computes nothing about readiness or
  /// load (Law 2). Returns true when a workout was ingested, false otherwise.
  Future<bool> _seedWorkout(
    ingest.IngestAdapter adapter,
    Map<String, dynamic> row,
    DateTime today,
    String dateStr,
  ) async {
    final workout = row['workout'];
    if (workout is! Map) return false;
    final w = workout.cast<String, dynamic>();

    // Anchor the session at 17:00 on the seeded day — a real start-time the
    // engine uses for the per-activity load anchor (and cross-source dedup). The
    // id mirrors the production HealthKit id shape ('hk_<startEpochMs>').
    final offset = (row['offset'] as num).toInt();
    final day = DateTime(today.year, today.month, today.day)
        .add(Duration(days: offset));
    final start = DateTime(day.year, day.month, day.day, 17);

    await adapter.ingestWorkout(
      activityId: 'hk_${start.millisecondsSinceEpoch}',
      date: dateStr,
      activityType: w['activity_type'] as String,
      durationMinutes: (w['duration_min'] as num).toDouble(),
      source: _vendor,
      start: start,
      avgHr: (w['avg_hr'] as num?)?.toInt(),
      maxHr: (w['max_hr'] as num?)?.toInt(),
    );
    return true;
  }

  /// Replay the first [days] entries of the season (oldest first, ending today)
  /// through the shared `IngestAdapter` 5-step vault-first path, then persist
  /// HMM state — the SAME audited path `HealthIngestService.syncHealthData`
  /// uses. Returns how many days were fed.
  ///
  /// [days] is clamped to the season length; pass a large number to seed the
  /// full ~30-day arc, or e.g. 10 for a mid-calibration state.
  Future<DemoSeedResult> seedSeason({required int days}) async {
    final season = await _loadSeason();
    // Keep this an int (num.clamp returns num) — it indexes sublist below.
    final n = days < 0 ? 0 : (days > season.length ? season.length : days);
    final today = DateTime.now();

    // Take the most RECENT n days so the seeded window always ends today.
    final slice = season.sublist(season.length - n);

    // Route every seeded day through the SAME audited 5-step vault-first path
    // production uses (HealthIngestService + BLE/Polar all funnel through this
    // one adapter): write raw -> normalize -> write biometric -> process ->
    // mark processed. The adapter runs all five steps internally, so we must
    // NOT also call normalize/process here (that would double-process). Writing
    // the biometric row is what makes HRV/RHR/sleep tiles + the Journey screen
    // render real data during the device witness. Every demo_season row carries
    // RHR+HRV+sleep, so hasBiometrics is always true.
    final adapter = ingest.IngestAdapter(binding: binding, handle: handle);
    var mutated = 0;
    var workoutsSeeded = 0;
    for (final row in slice) {
      final wire = _toHealthKitJson(row, today);
      await adapter.ingestObservation(
        date: wire['date'] as String,
        source: _vendor,
        vendorJson: jsonEncode(wire),
        hasBiometrics: true,
      );
      mutated++;

      // §8.0 activity seed: a day may carry a completed `workout`. Route it
      // through the SAME real workout core production uses
      // (IngestAdapter.ingestWorkout) — the engine computes the HR-based load
      // and the vault-backed surfaces (Journey row, workout-detail, post-workout
      // report) paint from real engine output. Time-in-zone is NOT seeded
      // (Option B): it is a live-capture surface witnessed via a real/injected
      // workout, so the fixture carries no HR series and we courier only the
      // given session scalars. No load/HR math in Dart (Law 2).
      if (await _seedWorkout(adapter, row, today, wire['date'] as String)) {
        workoutsSeeded++;
      }
    }

    // Persist exactly as the real sync does — an unpersisted HMM advance is
    // lost on the next restart. Workouts advance the HMM too (the workout core's
    // process_observation auto-records load), so persist if EITHER mutated.
    if (mutated > 0 || workoutsSeeded > 0) {
      final stateJson = await binding.saveState(handle);
      await binding.writeViterbiState(handle, stateJson: stateJson);
    }

    return DemoSeedResult(
      daysSeeded: n,
      daysAvailable: season.length,
      workoutsSeeded: workoutsSeeded,
    );
  }

  /// DEBUG witness for the CLOSED benchmark loop (founder 2026-07-07): drives
  /// two synthetic maximal-effort days through the REAL courier chain
  /// ([BenchmarkSyncService] → engine gate → vault ledger) and returns the
  /// engine's decisions, verbatim.
  ///
  /// Day 1 must HOLD (`awaiting_pattern:1/2` — the level never rises on one
  /// workout); calling again on a later calendar day PROMOTES, writes the
  /// profile, and files the `benchmark_change` ledger event. Same
  /// synthetic-INPUT / real-PIPELINE contract as [seedSeason]: the engine
  /// genuinely fits, gates, applies, and records — nothing display-side is
  /// fabricated. The streams are the athlete's sport-native unit built from
  /// the bound profile's own benchmark scaled by [gainFraction] (engine
  /// reads the sport; a cyclist gets watts, a runner m/s — never crossed).
  ///
  /// NOTE on dates: the engine keys the evidence window off the REAL device
  /// date (one candidate per calendar day), so a same-day re-run replaces
  /// day-1 evidence instead of confirming it — exactly the anti-double-count
  /// rule. The two-day witness therefore needs two real calendar days (or a
  /// simulator clock change); the outcome strings make the current state
  /// visible either way.
  Future<BenchmarkSyncOutcome?> runBenchmarkSyncWitness({
    required List<List<double>> effortStreams,
  }) async {
    final streams = [
      for (final samples in effortStreams)
        {'samples': samples, 'sample_rate_hz': 1.0},
    ];
    return BenchmarkSyncService(binding: binding, handle: handle)
        .run(activityStreamsJson: jsonEncode(streams));
  }
}

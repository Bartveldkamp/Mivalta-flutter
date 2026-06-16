// DEBUG-ONLY developer tool — seeds a *simulated athlete*.
//
// WHAT THIS IS (and is not):
//   It replays a committed, SYNTHETIC season of raw HealthKit-shaped biometrics
//   (assets/debug/demo_season.json) through the SAME vault-first ingest path a
//   real watch/Oura sync uses: normalizeObservation -> writeBiometric ->
//   processObservation -> saveState/writeViterbiState (mirroring
//   HealthIngestService.syncHealthData, health_ingest.dart:414-431). The engine
//   genuinely computes every readiness state from this input. Nothing on the
//   DISPLAY side is fabricated — the only synthetic thing is the biometric
//   stream, exactly as it would be on a bench test. This is the on-device
//   analog of dev_sim / realworld_sim: synthetic INPUT, real PIPELINE.
//
//   The season is biometric-only (no workouts), so the production workout path
//   (writeActivity) has nothing to mirror; the empty training-load panel on a
//   seeded run is honest-absence, not a gap. writeBiometric uses the SAME
//   pre-HMM normalized payload production uses, so it does not (and must not)
//   backfill readiness_score — see seedSeason for why.
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

/// Outcome of a seed run — how many days were replayed out of the season.
class DemoSeedResult {
  const DemoSeedResult({required this.daysSeeded, required this.daysAvailable});

  final int daysSeeded;
  final int daysAvailable;
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

    final wire = <String, dynamic>{
      'date': dateStr,
      'resting_heart_rate': row['resting_heart_rate'],
      'hrv_sdnn': row['hrv_sdnn'],
      'oxygen_saturation': row['oxygen_saturation'],
    };

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

  /// Replay the first [days] entries of the season (oldest first, ending today)
  /// through normalize -> process, then persist HMM state — mirroring
  /// `HealthIngestService.syncHealthData`. Returns how many days were fed.
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

    var mutated = 0;
    for (final row in slice) {
      final vendorJson = jsonEncode(_toHealthKitJson(row, today));
      final normalized = await binding.normalizeObservation(
        handle,
        vendor: _vendor,
        json: vendorJson,
      );
      // Mirror production HealthIngestService order (health_ingest.dart:414-431):
      // normalize -> writeBiometric (populates the vault `biometrics` table that
      // the trend / source-tier / Journey HRV-RHR-sleep pillars read) ->
      // processObservation (advances the HMM). Before this, the seeder fed only
      // the HMM, leaving the vault analytics tables empty — the cause of the
      // "No data yet" / "No history" panels on a seeded restart.
      //
      // FAITHFUL REPLICATION INCLUDING PRODUCTION'S GAP: we pass the SAME
      // pre-HMM `normalized` payload production passes. It carries no
      // readiness_score (that is computed by processObservation, AFTER this
      // write), so the biometric row is written with readiness_score = NULL —
      // exactly as production writes it. We deliberately do NOT write
      // readiness_score here: doing so would fabricate the value whose absence
      // is under test and green the trend over a real production gap. If
      // production doesn't persist it, neither does the seeder.
      //
      // The season is biometric-only (no workouts), so there is no writeActivity
      // to mirror — the empty training-load panel is honest-absence, not a gap.
      await binding.writeBiometric(handle, json: normalized);
      await binding.processObservation(handle, observationJson: normalized);
      mutated++;
    }

    // Persist exactly as the real sync does — an unpersisted HMM advance is
    // lost on the next restart.
    if (mutated > 0) {
      final stateJson = await binding.saveState(handle);
      await binding.writeViterbiState(handle, stateJson: stateJson);
    }

    return DemoSeedResult(daysSeeded: n, daysAvailable: season.length);
  }
}

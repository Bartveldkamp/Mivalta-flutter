// Benchmark sync courier — the app-side half of the CLOSED benchmark loop
// (rust-engine `gatc_postprocess::benchmark`, registry v2.43; founder
// decisions 2026-07-07: auto-apply + full ledger + the pattern rule).
//
// The ENGINE does everything that is coaching: merge streams → sport-native
// fit → confirm/promote gate over the remembered evidence window → write the
// benchmark into its own bound profile → emit the ledger event. This service
// does everything that is transport, in a fixed order, all VERBATIM:
//
//   1. read_benchmark_history   (vault → "null" on first run)
//   2. sync_benchmark_from_activities (ONE engine call)
//   3. write_benchmark_history  (store the returned window verbatim)
//   4. when applied:
//      a. write_profile         (persist the engine's OWN profile JSON —
//                                fetched back from the live engine, never
//                                re-assembled in Dart)
//      b. update_profile        (re-bind every profile-bound engine)
//      c. write_benchmark_event (file the ledger event verbatim)
//
// No math, no thresholds, no assembly anywhere in this file (Law 2) — not even
// a unit conversion: the app couriers the recorder's RAW samples plus a unit
// tag, and the ENGINE normalizes (km/h→m/s) and validates them (PR #171 review,
// engine PR #397). A sync with no usable streams is still meaningful: the
// engine prunes the evidence window and holds honestly — the wire stays live
// until real stream sources (GPS speed / BLE power meters) land.

import 'dart:convert';

import 'package:flutter/foundation.dart' show kDebugMode;

import '../rust_engine.dart';

/// Display-side outcome of one benchmark sync — parsed for the caller's
/// convenience; every value is the engine's own output, untouched.
class BenchmarkSyncOutcome {
  const BenchmarkSyncOutcome({
    required this.decision,
    required this.applied,
    this.eventJson,
  });

  /// The engine's decision tag: `promote`, `demote`, or `hold`.
  final String decision;

  /// True iff the engine wrote a new benchmark into the profile.
  final bool applied;

  /// The ledger event JSON (verbatim engine output) when [applied];
  /// null on a hold — honest absence, nothing was decided out loud.
  final String? eventJson;
}

/// The benchmark stream wire a completed SESSION should sync, or `null` when
/// this session's sport / stream doesn't feed a benchmark from the in-app
/// recorder. Pure transport: the raw recorded samples are couriered with a
/// unit tag; the ENGINE converts + validates (engine PR #397). No Dart math.
///
/// - **Running** → the speed stream, tagged `km_h` (the recorder's unit); the
///   engine normalizes to m/s for the Critical Speed fit.
/// - **Cycling** → the power stream, tagged `watts`, for the Critical Power
///   fit — the exact mirror (founder 2026-07-07). Runners are never fed watts,
///   cyclists never fed speed.
/// - Any other sport, or no samples for the sport's stream → `null` (no sync
///   from this path; honest absence).
String? benchmarkStreamsForSession(
  String sport,
  List<double>? speedSamplesKmh,
  List<int>? powerSamplesWatts,
) {
  switch (sport.toLowerCase()) {
    case 'running':
      final s = speedSamplesKmh ?? const [];
      if (s.isEmpty) return null;
      return jsonEncode([
        {'samples': s, 'sample_rate_hz': 1.0, 'unit': 'km_h'},
      ]);
    case 'cycling':
      final p = powerSamplesWatts ?? const [];
      if (p.isEmpty) return null;
      return jsonEncode([
        {
          'samples': [for (final w in p) w.toDouble()],
          'sample_rate_hz': 1.0,
          'unit': 'watts',
        },
      ]);
    default:
      return null;
  }
}

/// Runs the courier chain around `sync_benchmark_from_activities`.
class BenchmarkSyncService {
  BenchmarkSyncService({required this.binding, required this.handle});

  final RustEngineBinding binding;
  final EnginesHandle handle;

  /// Run one benchmark sync over [activityStreamsJson] — the engine wire
  /// `[{"samples":[…],"sample_rate_hz":1.0}]` (watts for a cyclist, m/s for
  /// a runner; the caller passes only REAL recorded streams, `[]` when none
  /// exist — never a stand-in).
  ///
  /// Returns the engine's outcome, or null when the chain failed (the error
  /// is named in debug; the benchmark simply doesn't move — the vault and
  /// profile are only ever touched with engine-produced values).
  Future<BenchmarkSyncOutcome?> run({
    required String activityStreamsJson,
  }) async {
    try {
      // 1. The remembered evidence window ("null" on first run).
      final history = await binding.readBenchmarkHistory(handle);

      // 2. ONE engine call — fit, gate, apply, all engine-side.
      final raw = await binding.syncBenchmarkFromActivities(
        handle,
        activitiesJson: activityStreamsJson,
        candidateHistoryJson: history,
      );
      final sync = jsonDecode(raw) as Map<String, dynamic>;

      // 3. Store the returned window verbatim for the next sync. jsonEncode
      //    of the undecoded subtree is the closest Dart gets to verbatim; the
      //    engine's serde re-reads it semantically (field-for-field).
      await binding.writeBenchmarkHistory(
        handle,
        historyJson: jsonEncode(sync['candidate_history']),
      );

      final applied = sync['applied'] == true;
      String? eventJson;
      if (applied) {
        // 4a. Persist the promotion by MERGING it into the stored VaultProfile.
        //     The engine reads the profile it now holds (byte-exact engine
        //     output, never a Dart re-assembly), overwrites only the coaching
        //     anchors, and keeps athlete_id + personal data. This replaces the
        //     old writeProfile(postprocessProfile()) path, which fed a bare
        //     AthleteProfile (no athlete_id) to the VaultProfile writer — serde
        //     rejected it, the error was swallowed, and the improvement was
        //     silently lost on the next launch.
        final profileJson = await binding.postprocessProfile(handle);
        await binding.mergeProfileBenchmarks(
          handle,
          athleteProfileJson: profileJson,
        );
        // 4b. Every profile-bound engine re-binds to the promoted benchmark.
        await binding.updateProfile(handle, athleteProfileJson: profileJson);
        // 4c. The coach says it out loud — file the ledger event.
        eventJson = jsonEncode(sync['event']);
        await binding.writeBenchmarkEvent(handle, eventJson: eventJson);
      }

      return BenchmarkSyncOutcome(
        decision: (sync['decision'] ?? '') as String,
        applied: applied,
        eventJson: eventJson,
      );
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('BenchmarkSyncService.run: ${e.runtimeType}: $e');
      }
      return null;
    }
  }
}

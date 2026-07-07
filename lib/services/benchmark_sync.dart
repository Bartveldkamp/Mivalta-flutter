// Benchmark sync courier — the app-side half of the CLOSED benchmark loop
// (rust-engine `gatc_postprocess::benchmark`, registry v2.42; founder
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
// No math, no thresholds, no assembly anywhere in this file (Law 2). A sync
// with no usable streams is still meaningful: the engine prunes the evidence
// window and holds honestly — the wire stays live until real stream sources
// (GPS speed / power meters) land.

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
  Future<BenchmarkSyncOutcome?> run({required String activityStreamsJson}) async {
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
        // 4a. Persist the profile AS THE LIVE ENGINE NOW HOLDS IT — fetched
        //     back from the engine itself, byte-exact engine output, never a
        //     Dart re-assembly of the sync payload.
        final profileJson = await binding.postprocessProfile(handle);
        await binding.writeProfile(handle, json: profileJson);
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

// Task 0 — the shared vault-first ingest adapter.
//
// BLE (live straps), Polar (Accesslink upload), and the existing health-store
// auto-sync all funnel vendor observations through this ONE proven path
// (NEXT_BUILD_BRIEF §B):
//   writeRawObservation → normalizeObservation → (writeBiometricFromObservation)
//   → processObservation → markRawObservationProcessed
// extracted verbatim from HealthIngestService so every input surface couriers
// through the same audited, vault-first sequence instead of duplicating it.
//
// COURIER ONLY (Law 2): no engine math in Dart. The adapter shuttles raw vendor
// JSON to the engine and the engine's normalized output onward; every value is
// the engine's. State persistence (saveState / writeViterbiState) stays the
// caller's BATCH concern — persist once after a batch when `mutated` is set,
// exactly as health_ingest did (an unpersisted HMM advance is lost on restart).

import 'dart:convert';

import '../rust_engine.dart';

/// Build the raw-observation JSON envelope persisted by `writeRawObservation`
/// BEFORE normalization (audit + replay). The shared ingest core owns this;
/// `HealthIngestService.buildRawObservationJson` delegates here.
String buildRawObservationJson({
  required String date,
  required String source,
  required String dataType,
  required String payload,
}) {
  return jsonEncode({
    'date': date,
    'source': source,
    'data_type': dataType,
    'payload': payload,
  });
}

/// Build the workout-shaped vendor payload the Rust normalizer expects, from
/// fields the platform already recorded. ZERO-FABRICATION transport: this does
/// NO load computation — it only shuttles duration (converted minutes → the
/// seconds/minutes shape each normalizer reads), avg HR, and calories. The
/// engine computes the real, method-tagged load downstream.
///
/// Single source of truth (Task 0): both the production health-store path
/// (`HealthIngestService`, whose static delegates here) and the DEBUG demo
/// seeder build this shape via this one function, so neither can drift.
///
/// Per-source workout shape (READ from the rust engine, not invented):
///   - 'apple'          → healthkit.rs reads the `workout` object: `duration`
///     (SECONDS), `totalEnergyBurned`, `associatedSamples.heartRate.average`.
///   - 'health_connect' → health_connect.rs reads the `exercise` object:
///     `duration_min` (MINUTES), `calories`, `avg_hr`.
///
/// `duration` in seconds (apple) = `durationMinutes * 60` is a UNIT conversion
/// for the payload, NOT a load computation. `start` (when present) is forwarded
/// so the engine anchors the load at a per-activity start-time (cross-source
/// dedup); absent → the engine degrades to the day-level anchor (fail-safe).
String buildWorkoutObservationJson({
  required String date,
  required String source,
  required double durationMinutes,
  DateTime? start,
  int? avgHr,
  int? calories,
}) {
  final startIso = start?.toUtc().toIso8601String();
  if (source == 'apple') {
    return jsonEncode({
      'date': date,
      'workout': <String, dynamic>{
        if (startIso != null) 'start': startIso,
        'duration': durationMinutes * 60.0, // minutes → seconds (unit conv)
        if (calories != null) 'totalEnergyBurned': calories,
        if (avgHr != null)
          'associatedSamples': {
            'heartRate': {'average': avgHr},
          },
      },
    });
  }
  // health_connect
  return jsonEncode({
    'date': date,
    'exercise': <String, dynamic>{
      if (startIso != null) 'start': startIso,
      'duration_min': durationMinutes,
      if (calories != null) 'calories': calories,
      if (avgHr != null) 'avg_hr': avgHr,
    },
  });
}

/// Build the VaultActivity JSON for a completed workout (schema from
/// gatc-vault/models.rs). Optional fields are omitted when absent — honest
/// absence, never a fabricated default. `load_uls` carries the ENGINE's computed
/// load ([recordedLoad]) when present; when null it is omitted (the engine
/// recorded no load, or the engine pin predates `recorded_load`).
String buildWorkoutActivityJson({
  required String id,
  required String date,
  required String activityType,
  required double durationMinutes,
  double? distanceKm,
  int? avgHr,
  int? maxHr,
  int? calories,
  required String source,
  double? recordedLoad,
}) {
  return jsonEncode({
    'id': id,
    'date': date,
    'activity_type': activityType,
    'duration_minutes': durationMinutes,
    if (distanceKm != null) 'distance_km': distanceKm,
    if (avgHr != null) 'avg_heart_rate': avgHr,
    if (maxHr != null) 'max_heart_rate': maxHr,
    if (calories != null) 'calories': calories,
    'source': source,
    if (recordedLoad != null) 'load_uls': recordedLoad,
  });
}

/// Extract the engine-computed Universal Load Score from a `DailyAssessment`
/// JSON (A5 load half). Returns the `recorded_load` value the ENGINE computed
/// and recorded for this workout, or `null` for honest absence — the field is
/// absent (older engine pin), the engine recorded no load (`load_method` None →
/// no HR/calories/positive duration), or the value is non-finite.
///
/// Pure extraction: NO load computation in Dart (Law 2). The edge only reads and
/// couriers the engine's number.
double? recordedLoadFromAssessment(String assessmentJson) {
  final decoded = jsonDecode(assessmentJson);
  if (decoded is! Map<String, dynamic>) return null;
  final v = decoded['recorded_load'];
  if (v is num && v.isFinite) return v.toDouble();
  return null;
}

/// Outcome of one observation ingest.
class IngestResult {
  const IngestResult({required this.mutated, required this.hadBiometrics});

  /// `processObservation` ran → the HMM advanced → the caller MUST persist state
  /// (saveState + writeViterbiState) at the end of the batch.
  final bool mutated;

  /// The normalized observation carried biometric content (RHR/HRV/sleep) and a
  /// biometric row was written for the Journey pillars.
  final bool hadBiometrics;
}

/// Outcome of one workout ingest (the shared activity core).
class WorkoutIngestResult {
  const WorkoutIngestResult({
    required this.activityId,
    required this.recordedLoad,
  });

  /// The vault activity id the row was written under.
  final String activityId;

  /// The ENGINE's computed Universal Load Score couriered onto the row, or null
  /// for honest absence (engine recorded no load / pin predates recorded_load).
  final double? recordedLoad;
}

/// The shared vault-first ingest adapter. Construct with the engine binding +
/// handle; call [ingestObservation] once per vendor observation. The caller owns
/// batching, error handling (a thrown step aborts that one observation), and the
/// single end-of-batch state persist.
class IngestAdapter {
  const IngestAdapter({required this.binding, required this.handle});

  final RustEngineBinding binding;
  final EnginesHandle handle;

  /// Run the five-step vault-first ingest for ONE vendor observation.
  ///
  /// [source] is the vendor id the engine normalizer dispatches on (e.g.
  /// `apple`, `health_connect`, `polar`, `ble_hr`/`polar_h10`). [vendorJson] is
  /// the raw vendor payload. [hasBiometrics] gates the biometric-row write (a
  /// pure activity observation skips step 3 but still advances the HMM).
  ///
  /// Throws if any engine step fails — the caller catches and counts the
  /// observation as skipped (fail loud, never silently drop — Law 6).
  Future<IngestResult> ingestObservation({
    required String date,
    required String source,
    required String vendorJson,
    required bool hasBiometrics,
    String dataType = 'biometric',
  }) async {
    // Step 1: persist the raw vendor payload BEFORE any processing.
    final rawObsJson = buildRawObservationJson(
      date: date,
      source: source,
      dataType: dataType,
      payload: vendorJson,
    );
    final rawId = await binding.writeRawObservation(handle, json: rawObsJson);

    // Step 2: normalize through the engine (HRV semantics, bounds clamping,
    // sleep aggregation — all engine-side).
    final normalizedJson = await binding.normalizeObservation(
      handle,
      vendor: source,
      json: vendorJson,
    );

    // Step 3: normalized biometrics → vault (Journey HRV/RHR/sleep pillars).
    if (hasBiometrics) {
      await binding.writeBiometricFromObservation(handle, json: normalizedJson);
    }

    // Step 4: feed the normalized observation into the HMM (advances state).
    await binding.processObservation(handle, observationJson: normalizedJson);

    // Step 5: mark the raw observation processed with its normalized form.
    await binding.markRawObservationProcessed(
      handle,
      id: rawId,
      observationJson: normalizedJson,
    );

    return IngestResult(mutated: true, hadBiometrics: hasBiometrics);
  }

  /// Ingest ONE completed workout through the engine — the activity analog of
  /// [ingestObservation]. This is the SINGLE shared orchestration that both the
  /// production health-store path (`HealthIngestService._ingestWorkout`, after
  /// it extracts these primitives from a `HealthDataPoint`) and the DEBUG demo
  /// seeder call, so neither can drift from the other (the #115 shared-path
  /// decision, applied to activities).
  ///
  /// Sequence (A5 load half): build the workout-shaped vendor payload →
  /// `normalizeObservation` → `processObservation` (the engine computes AND
  /// auto-records the real, method-tagged load — we do NOT also call
  /// `record_activity`, which would double-count) → read the engine's
  /// `recorded_load` off the returned assessment → `writeActivity` with that
  /// engine load couriered onto `load_uls`.
  ///
  /// On a normalize/process FAILURE the journey row is still written
  /// (load-absent) so the activity log is never silently dropped, then the error
  /// PROPAGATES so the caller counts the skip (fail loud — Law 6).
  ///
  /// COURIER ONLY (Law 2): every value is the platform's input or the engine's
  /// output. No load math in Dart, not even a mean — the caller supplies the
  /// scalar avg/max HR its platform already summarized.
  Future<WorkoutIngestResult> ingestWorkout({
    required String activityId,
    required String date,
    required String activityType,
    required double durationMinutes,
    required String source,
    DateTime? start,
    double? distanceKm,
    int? avgHr,
    int? maxHr,
    int? calories,
  }) async {
    final workoutObsJson = buildWorkoutObservationJson(
      date: date,
      source: source,
      durationMinutes: durationMinutes,
      start: start,
      avgHr: avgHr,
      calories: calories,
    );

    double? recordedLoad;
    try {
      final normalizedJson = await binding.normalizeObservation(
        handle,
        vendor: source,
        json: workoutObsJson,
      );
      // SOLE load-recording path: process_observation auto-records the
      // engine-computed load (no record_activity → no double-count). load_method
      // None (no HR/calories/positive duration) → the engine records NO load
      // (honest absence, the engine's verdict, not a Dart fallback).
      final assessmentJson = await binding.processObservation(
        handle,
        observationJson: normalizedJson,
      );
      recordedLoad = recordedLoadFromAssessment(assessmentJson);
    } catch (_) {
      // Engine could not process — still persist the journey row (load-absent),
      // preserving the activity log, then re-raise for the caller's skip count.
      await binding.writeActivity(
        handle,
        activityJson: buildWorkoutActivityJson(
          id: activityId,
          date: date,
          activityType: activityType,
          durationMinutes: durationMinutes,
          distanceKm: distanceKm,
          avgHr: avgHr,
          maxHr: maxHr,
          calories: calories,
          source: source,
          recordedLoad: null,
        ),
      );
      rethrow;
    }

    // Persist to the vault (journey list). `load_uls` carries the ENGINE's
    // computed load when present — couriered, not computed in Dart.
    await binding.writeActivity(
      handle,
      activityJson: buildWorkoutActivityJson(
        id: activityId,
        date: date,
        activityType: activityType,
        durationMinutes: durationMinutes,
        distanceKm: distanceKm,
        avgHr: avgHr,
        maxHr: maxHr,
        calories: calories,
        source: source,
        recordedLoad: recordedLoad,
      ),
    );

    return WorkoutIngestResult(activityId: activityId, recordedLoad: recordedLoad);
  }
}

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
}

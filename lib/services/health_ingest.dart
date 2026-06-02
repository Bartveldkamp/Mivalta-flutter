// PR-E: Health Connect (Android) + HealthKit (iOS) auto-ingest service.
//
// ZERO-FABRICATION BOUNDARY: Dart shuttles raw platform data to the Rust
// normalizer. No physiology transforms, no HRV semantics, no bounds clamping,
// no sleep-stage aggregation in Dart. The Rust normalizer owns all that —
// Dart is a pure JSON courier.
//
// Source strings per the Rust normalizer contract:
//   - Android Health Connect: "health_connect"
//   - iOS HealthKit: "apple"
//
// Health Connect JSON schema (from gatc-normalizer/src/health_connect.rs):
// {
//   "date": "2026-06-15",
//   "resting_heart_rate": 58,
//   "hrv_rmssd": 45.0,
//   "oxygen_saturation": 0.97,
//   "sleep_hours": 7.5,
//   "sleep_stages": [ { "stage": 5, "startTime": "...", "endTime": "..." } ],
//   "steps": 8200,
//   "exercise": { ... }  // Deferred — exerciseType impedance mismatch
// }

import 'dart:convert';
import 'dart:io' show Platform;

import 'package:health/health.dart';

import '../rust_engine.dart';

/// Result of a health data sync operation.
class HealthSyncResult {
  const HealthSyncResult({
    required this.success,
    required this.observationsProcessed,
    this.error,
    this.permissionDenied = false,
  });

  final bool success;
  final int observationsProcessed;
  final String? error;
  final bool permissionDenied;

  /// No-data result: permission granted but no health data available.
  static const noData = HealthSyncResult(
    success: true,
    observationsProcessed: 0,
  );

  /// Permission denied result.
  static const denied = HealthSyncResult(
    success: false,
    observationsProcessed: 0,
    permissionDenied: true,
  );
}

/// Service for ingesting health data from platform health stores.
///
/// Reads biometrics from Health Connect (Android) or HealthKit (iOS), maps
/// them to the Rust normalizer's expected JSON format, and feeds them into
/// the HMM via process_observation.
///
/// Exercise ingestion is deferred due to exerciseType impedance mismatch:
/// the engine expects raw Android Health Connect integer codes, but the
/// Flutter health plugin exposes its own enum. Biometrics (RHR/HRV/sleep)
/// drive readiness — landing those first.
class HealthIngestService {
  HealthIngestService({
    required this.binding,
    required this.handle,
  }) : _health = Health();

  final RustEngineBinding binding;
  final EnginesHandle handle;
  final Health _health;

  /// The health data types we request read permission for.
  ///
  /// For Android Health Connect, we request RMSSD (not SDNN) because that's
  /// what Health Connect's HeartRateVariabilityRmssdRecord provides.
  /// SDNN is reserved for the iOS HealthKit path (PR-E.2).
  static const List<HealthDataType> _readTypes = [
    HealthDataType.HEART_RATE,
    HealthDataType.RESTING_HEART_RATE,
    // Health Connect provides RMSSD, not SDNN
    HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
    // Individual sleep stage records — Rust aggregates these
    HealthDataType.SLEEP_AWAKE,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_REM,
    // SpO2
    HealthDataType.BLOOD_OXYGEN,
    // Steps (informational, not critical for readiness)
    HealthDataType.STEPS,
  ];

  /// Request health data permissions from the platform.
  /// Returns true if permissions were granted, false otherwise.
  Future<bool> requestPermissions() async {
    try {
      // Configure the health plugin
      await _health.configure();

      // Check if Health Connect is available (Android) or HealthKit (iOS)
      final isAvailable = await _health.isHealthConnectAvailable();
      if (!isAvailable && Platform.isAndroid) {
        // Health Connect not installed on Android
        return false;
      }

      // Request authorization for read-only access
      final granted = await _health.requestAuthorization(
        _readTypes,
        permissions: _readTypes.map((_) => HealthDataAccess.READ).toList(),
      );

      return granted;
    } catch (e) {
      // Permission request failed
      return false;
    }
  }

  /// Check if health data permissions are already granted.
  Future<bool> hasPermissions() async {
    try {
      await _health.configure();

      // Check authorization status for all types
      final statuses = await Future.wait(
        _readTypes.map((type) => _health.hasPermissions([type])),
      );

      // All types must be authorized
      return statuses.every((s) => s == true);
    } catch (e) {
      return false;
    }
  }

  /// Sync health data from the platform health store.
  ///
  /// Fetches the last [days] of data, normalizes it through the Rust
  /// normalizer, and feeds it into the HMM via process_observation.
  ///
  /// Returns a [HealthSyncResult] indicating success/failure and
  /// the number of observations processed (only counts days with
  /// real biometric content: RHR, HRV, or sleep).
  Future<HealthSyncResult> syncHealthData({int days = 7}) async {
    try {
      // Check permissions first
      final hasPerms = await hasPermissions();
      if (!hasPerms) {
        return HealthSyncResult.denied;
      }

      // Fetch health data for the last N days
      final now = DateTime.now();
      final start = now.subtract(Duration(days: days));

      final healthData = await _health.getHealthDataFromTypes(
        types: _readTypes,
        startTime: start,
        endTime: now,
      );

      if (healthData.isEmpty) {
        return HealthSyncResult.noData;
      }

      // Group data by date for daily observations
      final byDate = _groupByDate(healthData);

      var processed = 0;
      for (final entry in byDate.entries) {
        final date = entry.key;
        final records = entry.value;

        // Map platform records to normalizer JSON
        final result = _mapToNormalizerJson(date, records);
        if (result == null) continue;

        final (vendorJson, hasBiometrics) = result;

        // Source string per platform
        final source = Platform.isAndroid ? 'health_connect' : 'apple';

        try {
          // Normalize through Rust — this is where HRV semantics,
          // bounds clamping, and sleep aggregation happen
          final normalizedJson = await binding.normalizeObservation(
            handle,
            vendor: source,
            json: vendorJson,
          );

          // Feed the normalized observation into the HMM
          await binding.processObservation(
            handle,
            observationJson: normalizedJson,
          );

          // Only count if we had real biometric content (RHR/HRV/sleep)
          if (hasBiometrics) {
            processed++;
          }
        } catch (e) {
          // Skip this observation if normalization fails
          // (e.g., missing required fields)
          continue;
        }
      }

      // Persist the updated HMM state
      if (processed > 0) {
        final stateJson = await binding.saveState(handle);
        await binding.writeViterbiState(handle, stateJson: stateJson);
      }

      return HealthSyncResult(
        success: true,
        observationsProcessed: processed,
      );
    } catch (e) {
      return HealthSyncResult(
        success: false,
        observationsProcessed: 0,
        error: e.toString(),
      );
    }
  }

  /// Group health data points by date (YYYY-MM-DD).
  Map<String, List<HealthDataPoint>> _groupByDate(List<HealthDataPoint> data) {
    final byDate = <String, List<HealthDataPoint>>{};
    for (final point in data) {
      final date = _formatDate(point.dateFrom);
      byDate.putIfAbsent(date, () => []).add(point);
    }
    return byDate;
  }

  /// Format a DateTime as YYYY-MM-DD.
  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  /// Format a DateTime as RFC3339 for sleep_stages.
  String _formatRfc3339(DateTime dt) {
    return dt.toUtc().toIso8601String();
  }

  /// Map platform health records to the Rust normalizer's expected JSON.
  ///
  /// ZERO-FABRICATION: This method only shuttles raw values. It does NOT:
  /// - Transform HRV (the value is RMSSD from Health Connect)
  /// - Clamp bounds (Rust normalizer does that)
  /// - Aggregate sleep stages (Rust normalizer does that)
  /// - Synthesize missing fields (if no data, we send null)
  ///
  /// Returns null if there's no data for the date.
  /// Returns (json, hasBiometrics) where hasBiometrics indicates if we had
  /// real biometric content (RHR/HRV/sleep) that drives readiness.
  (String, bool)? _mapToNormalizerJson(
    String date,
    List<HealthDataPoint> records,
  ) {
    // Extract values by type — raw, no transforms
    double? restingHr;
    double? hrvRmssd;
    double? oxygenSaturation;
    double? steps;

    // Sleep stages — emit as array for Rust to aggregate
    final sleepStages = <Map<String, dynamic>>[];

    for (final record in records) {
      switch (record.type) {
        case HealthDataType.RESTING_HEART_RATE:
          final value = _extractNumericValue(record);
          if (value != null) {
            restingHr ??= value;
          }
          break;

        case HealthDataType.HEART_RATE_VARIABILITY_RMSSD:
          final value = _extractNumericValue(record);
          if (value != null) {
            // Raw RMSSD from Health Connect — Rust knows this is RMSSD
            hrvRmssd ??= value;
          }
          break;

        case HealthDataType.BLOOD_OXYGEN:
          final value = _extractNumericValue(record);
          if (value != null) {
            // Normalize to 0-1 fraction if > 1 (some devices report 0-100)
            oxygenSaturation ??= value > 1 ? value / 100.0 : value;
          }
          break;

        case HealthDataType.STEPS:
          final value = _extractNumericValue(record);
          if (value != null) {
            steps = (steps ?? 0) + value;
          }
          break;

        // Sleep stages — emit individual records for Rust aggregation
        case HealthDataType.SLEEP_AWAKE:
        case HealthDataType.SLEEP_DEEP:
        case HealthDataType.SLEEP_LIGHT:
        case HealthDataType.SLEEP_REM:
          final stageCode = _sleepStageToHcCode(record.type);
          if (stageCode != null) {
            sleepStages.add({
              'stage': stageCode,
              'startTime': _formatRfc3339(record.dateFrom),
              'endTime': _formatRfc3339(record.dateTo),
            });
          }
          break;

        default:
          break;
      }
    }

    // If we have no data at all, return null
    if (restingHr == null &&
        hrvRmssd == null &&
        sleepStages.isEmpty &&
        oxygenSaturation == null &&
        steps == null) {
      return null;
    }

    // Check if we have real biometric content (drives readiness)
    final hasBiometrics =
        restingHr != null || hrvRmssd != null || sleepStages.isNotEmpty;

    // Build the vendor-specific JSON for the normalizer
    // Key names match health_connect.rs schema exactly
    // ignore: use_null_aware_elements (Dart 3.7 syntax not applicable here)
    final payload = <String, dynamic>{
      'date': date,
      if (restingHr != null) 'resting_heart_rate': restingHr.round(),
      if (hrvRmssd != null) 'hrv_rmssd': hrvRmssd,
      if (oxygenSaturation != null) 'oxygen_saturation': oxygenSaturation,
      if (sleepStages.isNotEmpty) 'sleep_stages': sleepStages,
      if (steps != null) 'steps': steps.round(),
      // Exercise deferred — exerciseType impedance mismatch:
      // Engine expects raw HC integer codes, Flutter plugin exposes enum.
      // Biometrics (RHR/HRV/sleep) drive readiness — land those first.
    };

    return (jsonEncode(payload), hasBiometrics);
  }

  /// Map Flutter health plugin's sleep stage types to Health Connect codes.
  ///
  /// Health Connect sleep stage codes (from SleepSessionRecord):
  ///   1 = Awake
  ///   4 = Light
  ///   5 = Deep
  ///   6 = REM
  int? _sleepStageToHcCode(HealthDataType type) {
    switch (type) {
      case HealthDataType.SLEEP_AWAKE:
        return 1; // STAGE_TYPE_AWAKE
      case HealthDataType.SLEEP_LIGHT:
        return 4; // STAGE_TYPE_LIGHT
      case HealthDataType.SLEEP_DEEP:
        return 5; // STAGE_TYPE_DEEP
      case HealthDataType.SLEEP_REM:
        return 6; // STAGE_TYPE_REM
      default:
        return null;
    }
  }

  /// Extract a numeric value from a HealthDataPoint.
  double? _extractNumericValue(HealthDataPoint point) {
    final value = point.value;
    if (value is NumericHealthValue) {
      return value.numericValue.toDouble();
    }
    return null;
  }
}

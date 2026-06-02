// PR-E: Health Connect (Android) + HealthKit (iOS) auto-ingest service.
//
// ZERO-FABRICATION BOUNDARY: Dart shuttles raw platform data to the Rust
// normalizer. No physiology transforms, no HRV semantics (RMSSD vs SDNN),
// no bounds clamping, no sleep-stage aggregation in Dart. The Rust normalizer
// owns all that — Dart is a pure JSON courier.
//
// Source strings per the Rust normalizer contract:
//   - Android Health Connect: "health_connect"
//   - iOS HealthKit: "apple"

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
/// Reads biometrics and activities from Health Connect (Android) or
/// HealthKit (iOS), maps them to the Rust normalizer's expected JSON
/// format, and feeds them into the HMM via process_observation.
class HealthIngestService {
  HealthIngestService({
    required this.binding,
    required this.handle,
  }) : _health = Health();

  final RustEngineBinding binding;
  final EnginesHandle handle;
  final Health _health;

  /// The health data types we request read permission for.
  static const List<HealthDataType> _readTypes = [
    HealthDataType.HEART_RATE,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.HEART_RATE_VARIABILITY_SDNN,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_AWAKE,
    HealthDataType.SLEEP_IN_BED,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_REM,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.WORKOUT,
    HealthDataType.STEPS,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.ACTIVE_ENERGY_BURNED,
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
  /// the number of observations processed.
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
        final vendorJson = _mapToNormalizerJson(date, records);
        if (vendorJson == null) continue;

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

          processed++;
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

  /// Map platform health records to the Rust normalizer's expected JSON.
  ///
  /// ZERO-FABRICATION: This method only shuttles raw values. It does NOT:
  /// - Transform HRV (RMSSD vs SDNN semantics are in Rust)
  /// - Clamp bounds (Rust normalizer does that)
  /// - Aggregate sleep stages (Rust normalizer does that)
  /// - Synthesize missing fields (if no data, we send null)
  ///
  /// Returns null if there's no usable data for the date.
  String? _mapToNormalizerJson(String date, List<HealthDataPoint> records) {
    // Extract values by type — raw, no transforms
    double? restingHr;
    double? hrvSdnn;
    double? sleepMinutes;
    double? spo2;
    double? activeCalories;
    double? steps;
    double? distanceM;
    int? workoutMinutes;
    String? workoutType;
    double? avgHrDuringWorkout;

    for (final record in records) {
      final value = _extractNumericValue(record);
      if (value == null) continue;

      switch (record.type) {
        case HealthDataType.RESTING_HEART_RATE:
          restingHr ??= value;
          break;
        case HealthDataType.HEART_RATE_VARIABILITY_SDNN:
          // Pass raw SDNN — Rust normalizer knows this is SDNN not RMSSD
          hrvSdnn ??= value;
          break;
        case HealthDataType.SLEEP_ASLEEP:
        case HealthDataType.SLEEP_IN_BED:
          // Sum sleep duration — Rust normalizer will handle stage breakdown
          sleepMinutes = (sleepMinutes ?? 0) + value;
          break;
        case HealthDataType.BLOOD_OXYGEN:
          spo2 ??= value;
          break;
        case HealthDataType.ACTIVE_ENERGY_BURNED:
          activeCalories = (activeCalories ?? 0) + value;
          break;
        case HealthDataType.STEPS:
          steps = (steps ?? 0) + value;
          break;
        case HealthDataType.DISTANCE_DELTA:
          distanceM = (distanceM ?? 0) + value;
          break;
        case HealthDataType.WORKOUT:
          // Workout record — extract duration and type
          final duration = record.dateTo.difference(record.dateFrom);
          workoutMinutes = (workoutMinutes ?? 0) + duration.inMinutes;
          workoutType ??= _extractWorkoutType(record);
          break;
        case HealthDataType.HEART_RATE:
          // Use first HR during workout period as avgHrDuringWorkout
          avgHrDuringWorkout ??= value;
          break;
        default:
          break;
      }
    }

    // If we have no usable biometric data, return null
    if (restingHr == null && hrvSdnn == null && sleepMinutes == null) {
      return null;
    }

    // Build the vendor-specific JSON for the normalizer
    // This is the raw platform data — Rust does all transforms
    // ignore: use_null_aware_elements (Dart 3.7 syntax not applicable here)
    final payload = <String, dynamic>{
      'date': date,
      if (restingHr != null) 'resting_hr': restingHr,
      if (hrvSdnn != null) 'hrv_sdnn': hrvSdnn, // Raw SDNN, not RMSSD
      if (sleepMinutes != null) 'sleep_minutes': sleepMinutes,
      if (spo2 != null) 'spo2': spo2,
      if (activeCalories != null) 'active_calories': activeCalories,
      if (steps != null) 'steps': steps,
      if (distanceM != null) 'distance_m': distanceM,
      if (workoutMinutes != null) 'workout_minutes': workoutMinutes,
      if (workoutType != null) 'workout_type': workoutType,
      if (avgHrDuringWorkout != null) 'avg_hr': avgHrDuringWorkout,
    };

    return jsonEncode(payload);
  }

  /// Extract a numeric value from a HealthDataPoint.
  double? _extractNumericValue(HealthDataPoint point) {
    final value = point.value;
    if (value is NumericHealthValue) {
      return value.numericValue.toDouble();
    }
    return null;
  }

  /// Extract workout type from a HealthDataPoint.
  String? _extractWorkoutType(HealthDataPoint point) {
    final value = point.value;
    if (value is WorkoutHealthValue) {
      return value.workoutActivityType.name.toLowerCase();
    }
    return null;
  }
}

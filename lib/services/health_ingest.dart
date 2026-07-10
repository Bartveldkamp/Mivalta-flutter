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
//   "sleep_stages": [ { "stage": 5, "startTime": "...", "endTime": "..." } ],
//   "steps": 8200,
// }
// Sleep stage codes: 1=Awake, 4=Light, 5=Deep, 6=REM
//
// HealthKit JSON schema (from gatc-normalizer/src/healthkit.rs):
// {
//   "date": "2026-06-15",
//   "resting_heart_rate": { "value": 58.0, "unit": "count/min" },
//   "hrv_sdnn": { "value": 42.5, "unit": "ms" },
//   "oxygen_saturation": { "value": 0.97, "unit": "%" },
//   "sleep_samples": [ { "value": 4, "startDate": "...", "endDate": "..." } ]
// }
// Sleep sample values: 0=InBed, 1=AsleepUnspecified, 2=Awake, 3=AsleepCore(light),
//                      4=AsleepDeep, 5=AsleepREM
//
// Workout ingestion (MAC_BRIEF_WORKOUT_INGEST):
//   The Flutter health plugin exposes HealthWorkoutActivityType; we map it to
//   the engine's activity_type strings (VaultActivity.activity_type). For types
//   without a clean mapping, we pass the plugin name as-is and let the engine's
//   fail-loud validation decide (never silently drop a workout).

import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:health/health.dart';

import '../models/time_in_zone.dart';
import '../rust_engine.dart';
import 'benchmark_sync.dart';
import 'ingest_adapter.dart' as ingest;

// ============================================================================
// Workout type mapping: HealthWorkoutActivityType → engine activity_type
// ============================================================================
//
// Maps Flutter health plugin's workout types to engine-accepted activity_type
// strings (from gatc-vault/models.rs VaultActivity). Engine accepts: 'run',
// 'ride', 'swim', 'strength', 'walk', 'hike', 'other', etc.
//
// Transport-only mapping table — no physiology semantics in Dart.

const Map<HealthWorkoutActivityType, String> _kWorkoutTypeToActivityType = {
  // Cycling family → 'ride'
  HealthWorkoutActivityType.BIKING: 'ride',
  HealthWorkoutActivityType.BIKING_STATIONARY: 'ride',
  HealthWorkoutActivityType.HAND_CYCLING: 'ride',

  // Running family → 'run'
  HealthWorkoutActivityType.RUNNING: 'run',
  HealthWorkoutActivityType.RUNNING_TREADMILL: 'run',
  HealthWorkoutActivityType.TRACK_AND_FIELD: 'run',

  // Swimming family → 'swim'
  HealthWorkoutActivityType.SWIMMING: 'swim',
  HealthWorkoutActivityType.SWIMMING_OPEN_WATER: 'swim',
  HealthWorkoutActivityType.SWIMMING_POOL: 'swim',
  HealthWorkoutActivityType.WATER_FITNESS: 'swim',

  // Strength training → 'strength'
  HealthWorkoutActivityType.STRENGTH_TRAINING: 'strength',
  HealthWorkoutActivityType.TRADITIONAL_STRENGTH_TRAINING: 'strength',
  HealthWorkoutActivityType.FUNCTIONAL_STRENGTH_TRAINING: 'strength',
  HealthWorkoutActivityType.WEIGHTLIFTING: 'strength',
  HealthWorkoutActivityType.CALISTHENICS: 'strength',
  HealthWorkoutActivityType.CORE_TRAINING: 'strength',

  // Walking → 'walk'
  HealthWorkoutActivityType.WALKING: 'walk',
  HealthWorkoutActivityType.WALKING_TREADMILL: 'walk',

  // Hiking → 'hike'
  HealthWorkoutActivityType.HIKING: 'hike',
  HealthWorkoutActivityType.CLIMBING: 'hike',
  HealthWorkoutActivityType.ROCK_CLIMBING: 'hike',

  // Rowing → 'row'
  HealthWorkoutActivityType.ROWING: 'row',
  HealthWorkoutActivityType.ROWING_MACHINE: 'row',

  // Elliptical / cardio machines → 'elliptical'
  HealthWorkoutActivityType.ELLIPTICAL: 'elliptical',
  HealthWorkoutActivityType.STAIR_CLIMBING: 'elliptical',
  HealthWorkoutActivityType.STAIR_CLIMBING_MACHINE: 'elliptical',
  HealthWorkoutActivityType.STAIRS: 'elliptical',
  HealthWorkoutActivityType.STEP_TRAINING: 'elliptical',

  // Yoga / flexibility → 'yoga'
  HealthWorkoutActivityType.YOGA: 'yoga',
  HealthWorkoutActivityType.PILATES: 'yoga',
  HealthWorkoutActivityType.FLEXIBILITY: 'yoga',
  HealthWorkoutActivityType.TAI_CHI: 'yoga',
  HealthWorkoutActivityType.MIND_AND_BODY: 'yoga',
  HealthWorkoutActivityType.BARRE: 'yoga',

  // HIIT / interval → 'hiit'
  HealthWorkoutActivityType.HIGH_INTENSITY_INTERVAL_TRAINING: 'hiit',
  HealthWorkoutActivityType.MIXED_CARDIO: 'hiit',
  HealthWorkoutActivityType.CROSS_TRAINING: 'hiit',

  // Skiing → 'ski'
  HealthWorkoutActivityType.CROSS_COUNTRY_SKIING: 'ski',
  HealthWorkoutActivityType.DOWNHILL_SKIING: 'ski',
  HealthWorkoutActivityType.SKIING: 'ski',
  HealthWorkoutActivityType.SNOWBOARDING: 'ski',
  HealthWorkoutActivityType.SNOWSHOEING: 'ski',
  HealthWorkoutActivityType.SNOW_SPORTS: 'ski',

  // Skating → 'skate'
  HealthWorkoutActivityType.SKATING: 'skate',
  HealthWorkoutActivityType.ICE_SKATING: 'skate',

  // Combat / martial arts → 'martial_arts'
  HealthWorkoutActivityType.MARTIAL_ARTS: 'martial_arts',
  HealthWorkoutActivityType.BOXING: 'martial_arts',
  HealthWorkoutActivityType.KICKBOXING: 'martial_arts',
  HealthWorkoutActivityType.WRESTLING: 'martial_arts',
  HealthWorkoutActivityType.FENCING: 'martial_arts',

  // Dance → 'dance'
  HealthWorkoutActivityType.DANCING: 'dance',
  HealthWorkoutActivityType.CARDIO_DANCE: 'dance',
  HealthWorkoutActivityType.SOCIAL_DANCE: 'dance',

  // Ball sports → 'ball_sport'
  HealthWorkoutActivityType.TENNIS: 'ball_sport',
  HealthWorkoutActivityType.TABLE_TENNIS: 'ball_sport',
  HealthWorkoutActivityType.BADMINTON: 'ball_sport',
  HealthWorkoutActivityType.SQUASH: 'ball_sport',
  HealthWorkoutActivityType.RACQUETBALL: 'ball_sport',
  HealthWorkoutActivityType.PICKLEBALL: 'ball_sport',
  HealthWorkoutActivityType.VOLLEYBALL: 'ball_sport',
  HealthWorkoutActivityType.BASKETBALL: 'ball_sport',
  HealthWorkoutActivityType.SOCCER: 'ball_sport',
  HealthWorkoutActivityType.AMERICAN_FOOTBALL: 'ball_sport',
  HealthWorkoutActivityType.AUSTRALIAN_FOOTBALL: 'ball_sport',
  HealthWorkoutActivityType.RUGBY: 'ball_sport',
  HealthWorkoutActivityType.HANDBALL: 'ball_sport',
  HealthWorkoutActivityType.HOCKEY: 'ball_sport',
  HealthWorkoutActivityType.LACROSSE: 'ball_sport',
  HealthWorkoutActivityType.BASEBALL: 'ball_sport',
  HealthWorkoutActivityType.SOFTBALL: 'ball_sport',
  HealthWorkoutActivityType.CRICKET: 'ball_sport',
  HealthWorkoutActivityType.GOLF: 'ball_sport',
  HealthWorkoutActivityType.WATER_POLO: 'ball_sport',
  HealthWorkoutActivityType.FRISBEE_DISC: 'ball_sport',
  HealthWorkoutActivityType.DISC_SPORTS: 'ball_sport',

  // Water sports → 'water_sport'
  HealthWorkoutActivityType.SAILING: 'water_sport',
  HealthWorkoutActivityType.SURFING: 'water_sport',
  HealthWorkoutActivityType.PADDLE_SPORTS: 'water_sport',
  HealthWorkoutActivityType.SCUBA_DIVING: 'water_sport',
  HealthWorkoutActivityType.WATER_SPORTS: 'water_sport',

  // Jump rope → 'jump_rope'
  HealthWorkoutActivityType.JUMP_ROPE: 'jump_rope',

  // Gymnastics → 'gymnastics'
  HealthWorkoutActivityType.GYMNASTICS: 'gymnastics',

  // Recovery → 'recovery'
  HealthWorkoutActivityType.COOLDOWN: 'recovery',
  HealthWorkoutActivityType.PREPARATION_AND_RECOVERY: 'recovery',

  // Other / misc → passed as-is
  HealthWorkoutActivityType.OTHER: 'other',
};

/// Map a Flutter health plugin workout type to the engine's activity_type.
///
/// For types without a mapping, returns the enum name lowercased (e.g.,
/// 'archery', 'curling') and lets the engine's fail-loud validation decide.
String mapWorkoutType(HealthWorkoutActivityType type) {
  return _kWorkoutTypeToActivityType[type] ?? type.name.toLowerCase();
}

/// Result of a health data sync operation.
class HealthSyncResult {
  const HealthSyncResult({
    required this.success,
    required this.observationsProcessed,
    this.workoutsProcessed = 0,
    this.error,
    this.permissionDenied = false,
    this.skippedDays = 0,
    this.skippedWorkouts = 0,
  });

  final bool success;
  final int observationsProcessed;

  /// Number of workouts written to the vault (MAC_BRIEF_WORKOUT_INGEST).
  final int workoutsProcessed;
  final String? error;
  final bool permissionDenied;

  /// FL-4: days that failed a per-observation normalize/process and were
  /// dropped. Surfaced (not silently swallowed) so the caller can tell a
  /// partial sync from a clean one.
  final int skippedDays;

  /// Workouts that failed to ingest (surfaced, not swallowed).
  final int skippedWorkouts;

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

/// What the caller should do after a background health sync.
enum HealthSyncOutcome {
  /// Fresh observations landed — refresh the surface.
  refreshed,

  /// Nothing landed: permission denied, OR granted-but-empty. On iOS a
  /// HealthKit READ denial is indistinguishable from "no data" by design, so
  /// both collapse here — surface the connect affordance, never fabricate.
  needsConnect,

  /// A real failure (transport/plugin), NOT a denial — leave prior vault data
  /// untouched and do not nag.
  unchanged,
}

/// Classify a sync result WITHOUT trusting the (iOS-unreliable) permission
/// query: decide off "attempted + nothing landed", not the permission flag
/// alone. This is the honest-absence rule for the health path.
HealthSyncOutcome classifyHealthSync(HealthSyncResult r) {
  // Anything reached the vault — daily biometrics or a workout — counts.
  if (r.observationsProcessed > 0 || r.workoutsProcessed > 0) {
    return HealthSyncOutcome.refreshed;
  }
  // A genuine error that is NOT a denial: keep what we already have.
  if (!r.success && !r.permissionDenied && r.error != null) {
    return HealthSyncOutcome.unchanged;
  }
  // Denied OR granted-but-empty → both want the connect affordance (iOS-safe).
  return HealthSyncOutcome.needsConnect;
}

/// Service for ingesting health data from platform health stores.
///
/// Reads biometrics from Health Connect (Android) or HealthKit (iOS), maps
/// them to the Rust normalizer's expected JSON format, and feeds them into
/// the HMM via process_observation.
///
/// Also ingests workouts (MAC_BRIEF_WORKOUT_INGEST): completed workouts are
/// written to the vault via write_activity, enabling post-workout reports,
/// energy-system rotation, and power analytics.
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
  /// Platform-specific HRV:
  /// - Android Health Connect: RMSSD (HeartRateVariabilityRmssdRecord)
  /// - iOS HealthKit: SDNN (HKQuantityTypeIdentifierHeartRateVariabilitySDNN)
  ///
  /// The Flutter health plugin exposes platform-specific HRV via separate types.
  static List<HealthDataType> get _readTypes {
    final types = <HealthDataType>[
      HealthDataType.HEART_RATE,
      HealthDataType.RESTING_HEART_RATE,
      // SpO2
      HealthDataType.BLOOD_OXYGEN,
      // Steps (informational, not critical for readiness)
      HealthDataType.STEPS,
      // Workout sessions — bound the HR window for time-in-zone.
      HealthDataType.WORKOUT,
    ];

    if (Platform.isAndroid) {
      // Android Health Connect: RMSSD
      types.add(HealthDataType.HEART_RATE_VARIABILITY_RMSSD);
      // Individual sleep stage records (stage codes 1=Awake, 4=Light, 5=Deep, 6=REM)
      types.addAll([
        HealthDataType.SLEEP_AWAKE,
        HealthDataType.SLEEP_DEEP,
        HealthDataType.SLEEP_LIGHT,
        HealthDataType.SLEEP_REM,
      ]);
    } else if (Platform.isIOS) {
      // iOS HealthKit: SDNN
      types.add(HealthDataType.HEART_RATE_VARIABILITY_SDNN);
      // HealthKit sleep categories (value codes 0=InBed, 1=Unspecified, 2=Awake,
      // 3=Core/Light, 4=Deep, 5=REM)
      types.addAll([
        HealthDataType.SLEEP_IN_BED,
        HealthDataType.SLEEP_ASLEEP,
        HealthDataType.SLEEP_AWAKE,
        HealthDataType.SLEEP_DEEP,
        HealthDataType.SLEEP_LIGHT,
        HealthDataType.SLEEP_REM,
      ]);
    }

    return types;
  }

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
      var mutated = 0; // FL-4: any observation that advanced the HMM state
      var skipped = 0; // FL-4: days dropped by a per-observation failure
      // #3 write-back: the latest date whose observation actually advanced the
      // HMM — the row the engine's current readiness gets written back to. ISO
      // dates sort lexically, so max() is robust to byDate iteration order.
      String? latestProcessedDate;
      // De-silence: the first per-day failure cause, surfaced in the result so
      // a SYSTEMIC failure (every day failing the same way) is diagnosable by
      // the caller, not just a kDebugMode print.
      String? firstSkipReason;
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
          // ================================================================
          // VAULT-FIRST INGEST (NEXT_BUILD_BRIEF §B) — Task 0 shared adapter
          // ================================================================
          // Order: raw → normalize → biometric → HMM → mark processed.
          // The sequence lives in IngestAdapter so BLE/Polar/health all courier
          // through the SAME audited path; this call is a faithful extraction of
          // the former inline loop (behaviour-preserving — see ingest_adapter).
          final result =
              await ingest.IngestAdapter(binding: binding, handle: handle)
                  .ingestObservation(
            date: date,
            source: source,
            vendorJson: vendorJson,
            hasBiometrics: hasBiometrics,
          );
          // processObservation always advanced the HMM → persist after the batch.
          if (result.mutated) {
            mutated++;
            if (latestProcessedDate == null ||
                date.compareTo(latestProcessedDate) > 0) {
              latestProcessedDate = date;
            }
          }
          // Only count days that carried real biometric content (RHR/HRV/sleep).
          if (result.hadBiometrics) {
            processed++;
          }
        } catch (e) {
          // FL-4: a failed day was previously dropped silently while the sync
          // still reported success. Count it and (in debug) name the cause so a
          // partial sync is diagnosable on-device.
          skipped++;
          firstSkipReason ??= '${e.runtimeType}: $e';
          if (kDebugMode) {
            // ignore: avoid_print
            print('health sync: skipped $date — ${e.runtimeType}: $e');
          }
          continue;
        }
      }

      // FL-4: persist on ANY state mutation, not just biometric-bearing days —
      // processObservation advances the HMM for every observation and an
      // unpersisted advance is lost on the next restart (compounds engine A).
      if (mutated > 0) {
        final stateJson = await binding.saveState(handle);
        await binding.writeViterbiState(handle, stateJson: stateJson);
        // #3 readiness write-back: persist the engine's CURRENT 4-axis readiness
        // indicator to the latest processed day's biometrics row, so the Journey
        // charts read it back. The shim owns the honest-absence skip (no readiness
        // yet → no row written, never a fabricated 0); Dart only couriers the date.
        if (latestProcessedDate != null) {
          await binding.writeReadinessAssessment(handle,
              date: latestProcessedDate);
        }
      }

      // ====================================================================
      // MAC_BRIEF_WORKOUT_INGEST: Process workouts into the vault.
      // ====================================================================
      //
      // For each WORKOUT session not yet ingested:
      //   1. Build VaultActivity JSON (transport-only mapping)
      //   2. write_activity → persist to vault (journey list)
      //   3. normalize the workout payload → process_observation, which lets
      //      the ENGINE compute and auto-record the real load (NO Dart load
      //      math, NO separate record_activity — that would double-count).
      //   4. Persist HMM state
      //
      // Idempotency: key by workout start time to avoid re-ingesting.

      final workouts = healthData
          .where((p) => p.type == HealthDataType.WORKOUT)
          .toList();
      var workoutsProcessed = 0;
      var skippedWorkouts = 0;

      for (final workout in workouts) {
        try {
          final activityId = await _ingestWorkout(workout, healthData);
          if (activityId != null) {
            workoutsProcessed++;
          }
        } catch (e) {
          skippedWorkouts++;
          if (kDebugMode) {
            // ignore: avoid_print
            print('workout ingest: skipped ${workout.dateFrom} — ${e.runtimeType}: $e');
          }
        }
      }

      // Persist HMM state if any workouts were ingested.
      if (workoutsProcessed > 0) {
        final stateJson = await binding.saveState(handle);
        await binding.writeViterbiState(handle, stateJson: stateJson);

        // Benchmark sync — the CLOSED loop (founder 2026-07-07). HealthKit
        // gives this path no watts/speed sample streams yet (HR only), so
        // the streams list is honestly EMPTY — the engine prunes its
        // evidence window and holds; the moment a real stream source lands
        // (GPS speed / power meter), this same wire carries it. Never a
        // stand-in stream (Law 3: HR is neither watts nor m/s).
        await BenchmarkSyncService(binding: binding, handle: handle)
            .run(activityStreamsJson: '[]');
      }

      // De-silence (Law 6 — fail loud over fail quiet): decide success/error
      // from the per-day tallies via the pure, unit-tested `buildSyncResult`. A
      // SYSTEMIC failure (every biometric day failed) must never report
      // success: true — that is what hid the writeBiometric type mismatch.
      return buildSyncResult(
        processed: processed,
        skipped: skipped,
        workoutsProcessed: workoutsProcessed,
        skippedWorkouts: skippedWorkouts,
        firstSkipReason: firstSkipReason,
      );
    } catch (e) {
      return HealthSyncResult(
        success: false,
        observationsProcessed: 0,
        error: e.toString(),
      );
    }
  }

  /// De-silence decision (Law 6 — fail loud over fail quiet): build the sync
  /// result from the per-day tallies. A SYSTEMIC failure — biometric days were
  /// present but EVERY one failed (`processed == 0 && skipped > 0`) — is a
  /// contract/structural break, not a data gap, so it reports `success: false`
  /// with the captured cause; it must never be hidden behind `success: true`
  /// (the mechanism that masked the UniversalObservation→VaultBiometric type
  /// mismatch — writeBiometric rejecting every row). A no-attempts sync
  /// (`processed == 0 && skipped == 0`, e.g. workout-only) is NOT a failure.
  /// Partial failures stay `success: true` but remain visible via
  /// `skippedDays`. Pure + static so it is unit-tested without the platform.
  static HealthSyncResult buildSyncResult({
    required int processed,
    required int skipped,
    required int workoutsProcessed,
    required int skippedWorkouts,
    String? firstSkipReason,
  }) {
    final systemicFailure = processed == 0 && skipped > 0;
    return HealthSyncResult(
      success: !systemicFailure,
      observationsProcessed: processed,
      workoutsProcessed: workoutsProcessed,
      error: systemicFailure
          ? 'All $skipped biometric day(s) failed to ingest — '
              '${firstSkipReason ?? 'unknown error'}'
          : null,
      skippedDays: skipped,
      skippedWorkouts: skippedWorkouts,
    );
  }

  /// Ingest a single workout into the vault.
  ///
  /// Returns the activity ID if successfully ingested, null if already exists.
  Future<String?> _ingestWorkout(
    HealthDataPoint workout,
    List<HealthDataPoint> allHealthData,
  ) async {
    // Extract workout value for type and calories.
    final workoutValue = workout.value;
    if (workoutValue is! WorkoutHealthValue) return null;

    // Build a stable ID from the workout start time for idempotency.
    // Format: "hc_{start_epoch_ms}" (Health Connect) or "hk_{start_epoch_ms}" (HealthKit)
    final prefix = Platform.isAndroid ? 'hc' : 'hk';
    final activityId = '${prefix}_${workout.dateFrom.millisecondsSinceEpoch}';

    // Check if already ingested by reading recent activities.
    // (This is a simple idempotency check; a more robust approach would use
    // local storage keyed by activity ID.)
    // TODO: Replace with local storage check for better performance.

    final workoutType = workoutValue.workoutActivityType;
    final activityType = mapWorkoutType(workoutType);

    final durationMinutes = workout.dateTo.difference(workout.dateFrom).inMinutes.toDouble();
    if (durationMinutes <= 0) return null;

    final distanceKm = workoutValue.totalDistance != null
        ? workoutValue.totalDistance! / 1000.0
        : null;

    // Collect HR samples within the workout window for avg/max HR.
    final hrPoints = allHealthData.where((p) =>
        p.type == HealthDataType.HEART_RATE &&
        !p.dateFrom.isBefore(workout.dateFrom) &&
        !p.dateTo.isAfter(workout.dateTo));
    int? avgHr;
    int? maxHr;
    List<double>? hrSamples;
    if (hrPoints.isNotEmpty) {
      final hrValues = hrPoints
          .map((p) => _extractNumericValue(p))
          .whereType<double>()
          .toList();
      if (hrValues.isNotEmpty) {
        // Courier the RAW samples to the engine (Charter Law 2 — the engine
        // computes the mean for the load path). avgHr/maxHr remain a Dart
        // summary ONLY for the display activity row, never the load-path input.
        hrSamples = hrValues;
        avgHr = (hrValues.reduce((a, b) => a + b) / hrValues.length).round();
        maxHr = hrValues.reduce((a, b) => a > b ? a : b).round();
      }
    }

    final caloriesRounded = workoutValue.totalEnergyBurned?.round();

    // ====================================================================
    // ZERO-FABRICATION load (A5) — delegated to the shared activity core.
    // ====================================================================
    //
    // The engine computes + auto-records the real, method-tagged Universal Load
    // Score INTERNALLY (process_observation: HeartRateQuadratic → Calories →
    // DurationOnly → None) and the core couriers that engine load onto the
    // activity row's `load_uls`. Dart does NO load math and does NOT call
    // record_activity (no double-count). On engine failure the core still writes
    // the journey row (load-absent) then rethrows, so this method's caller
    // (syncHealthData) counts the skip — fail loud (skippedWorkouts++).
    //
    // This is the SAME `IngestAdapter.ingestWorkout` core the DEBUG demo seeder
    // calls; the only difference is where the primitives come from (a real
    // HealthDataPoint here, synthetic fixture values there) — one orchestration,
    // no drift (#115 shared-path decision, applied to activities).
    //
    // Line-2 follow-up (tracked, post-continuity): the normalizer's load_score
    // is the simpler producer (HR-quadratic / cal÷10 / duration-based), NOT the
    // full Banister TRIMP in gatc-viterbi load.rs. Upgrading the HR→load
    // fidelity to full TRIMP is a tracked engine-side Line-2 item.
    final source = Platform.isAndroid ? 'health_connect' : 'apple';
    await ingest.IngestAdapter(binding: binding, handle: handle).ingestWorkout(
      activityId: activityId,
      date: _formatDate(workout.dateFrom),
      activityType: activityType,
      durationMinutes: durationMinutes,
      source: source,
      start: workout.dateFrom,
      distanceKm: distanceKm,
      avgHr: avgHr,
      maxHr: maxHr,
      hrSamples: hrSamples,
      calories: caloriesRounded,
    );

    return activityId;
  }

  /// Extract the engine-computed Universal Load Score from a `DailyAssessment`
  /// JSON (A5 load half). Returns the `recorded_load` value the ENGINE computed
  /// and recorded for this workout, or `null` for honest absence — the field is
  /// absent (older engine pin), the engine recorded no load (`load_method`
  /// None → no HR/calories/positive duration), or the value is non-finite.
  ///
  /// Pure extraction: NO load computation in Dart (Law 2). The edge only reads
  /// and couriers the engine's number. Canonical impl in the shared ingest
  /// adapter (Task 0); this static is retained for existing callers/tests.
  static double? recordedLoadFromAssessment(String assessmentJson) =>
      ingest.recordedLoadFromAssessment(assessmentJson);

  /// Build the VaultActivity JSON for a completed workout (schema from
  /// gatc-vault/models.rs). Optional fields are omitted when absent — honest
  /// absence, never a fabricated default. `load_uls` carries the ENGINE's
  /// computed load ([recordedLoad]) when present; when null it is omitted (the
  /// engine recorded no load, or the engine pin predates `recorded_load`).
  static String buildWorkoutActivityJson({
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
  }) =>
      ingest.buildWorkoutActivityJson(
        id: id,
        date: date,
        activityType: activityType,
        durationMinutes: durationMinutes,
        distanceKm: distanceKm,
        avgHr: avgHr,
        maxHr: maxHr,
        calories: calories,
        source: source,
        recordedLoad: recordedLoad,
      );

  /// Build the workout-shaped vendor payload the Rust normalizer expects, from
  /// fields the platform already recorded. ZERO-FABRICATION transport: this
  /// does NO load computation — it only shuttles duration (converted minutes →
  /// the seconds/minutes shape each normalizer reads), avg HR, and calories.
  /// The engine computes the real, method-tagged load downstream.
  ///
  /// Per-source workout shape (READ from the rust engine, not invented):
  ///   - 'apple'          → healthkit.rs `normalize_observation` reads the
  ///     `workout` object: `duration` (SECONDS), `totalEnergyBurned`,
  ///     `associatedSamples.heartRate.average`.
  ///   - 'health_connect' → health_connect.rs `normalize_observation` reads the
  ///     `exercise` object: `duration_min` (MINUTES), `calories`, `avg_hr`.
  ///
  /// `duration` in seconds (apple) = `durationMinutes * 60` is a UNIT
  /// conversion for the payload, NOT a load computation.
  ///
  /// `workoutActivityType` / `exerciseType` are deliberately omitted: the
  /// Flutter health plugin exposes a `HealthWorkoutActivityType` enum, not the
  /// platform's numeric HK/HC code the normalizer maps from. Omitting it means
  /// the engine leaves the observation's `activity_type` absent for this load
  /// (it does NOT affect the load magnitude, which derives from HR / calories /
  /// duration) — honest absence over a guessed code. The activity_type STRING
  /// still rides the unchanged `writeActivity` payload for the journey list.
  ///
  /// Canonical impl in the shared ingest adapter (Task 0); this static is
  /// retained for existing callers/tests.
  static String buildWorkoutObservationJson({
    required String date,
    required String source,
    required double durationMinutes,
    DateTime? start,
    int? avgHr,
    int? calories,
  }) =>
      ingest.buildWorkoutObservationJson(
        date: date,
        source: source,
        durationMinutes: durationMinutes,
        start: start,
        avgHr: avgHr,
        calories: calories,
      );

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
  /// - Transform HRV (value is RMSSD on Android, SDNN on iOS)
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
    return Platform.isIOS
        ? _mapToHealthKitJson(date, records)
        : _mapToHealthConnectJson(date, records);
  }

  /// Map Health Connect (Android) records to the normalizer JSON.
  /// Schema: health_connect.rs
  (String, bool)? _mapToHealthConnectJson(
    String date,
    List<HealthDataPoint> records,
  ) {
    double? restingHr;
    double? hrvRmssd;
    double? oxygenSaturation;
    double? steps;
    final sleepStages = <Map<String, dynamic>>[];

    for (final record in records) {
      switch (record.type) {
        case HealthDataType.RESTING_HEART_RATE:
          final value = _extractNumericValue(record);
          if (value != null) restingHr ??= value;
          break;

        case HealthDataType.HEART_RATE_VARIABILITY_RMSSD:
          final value = _extractNumericValue(record);
          if (value != null) hrvRmssd ??= value;
          break;

        case HealthDataType.BLOOD_OXYGEN:
          final value = _extractNumericValue(record);
          if (value != null) {
            oxygenSaturation ??= value > 1 ? value / 100.0 : value;
          }
          break;

        case HealthDataType.STEPS:
          final value = _extractNumericValue(record);
          if (value != null) steps = (steps ?? 0) + value;
          break;

        // Health Connect sleep stages (stage codes 1=Awake, 4=Light, 5=Deep, 6=REM)
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

    if (restingHr == null &&
        hrvRmssd == null &&
        sleepStages.isEmpty &&
        oxygenSaturation == null &&
        steps == null) {
      return null;
    }

    final hasBiometrics =
        restingHr != null || hrvRmssd != null || sleepStages.isNotEmpty;

    // Key names match health_connect.rs schema exactly
    final payload = <String, dynamic>{
      'date': date,
      if (restingHr != null) 'resting_heart_rate': restingHr.round(),
      if (hrvRmssd != null) 'hrv_rmssd': hrvRmssd,
      if (oxygenSaturation != null) 'oxygen_saturation': oxygenSaturation,
      if (sleepStages.isNotEmpty) 'sleep_stages': sleepStages,
      if (steps != null) 'steps': steps.round(),
    };

    return (jsonEncode(payload), hasBiometrics);
  }

  /// Map HealthKit (iOS) records to the normalizer JSON.
  /// Schema: healthkit.rs
  (String, bool)? _mapToHealthKitJson(
    String date,
    List<HealthDataPoint> records,
  ) {
    double? restingHr;
    double? hrvSdnn;
    double? oxygenSaturation;
    double? steps;
    final sleepSamples = <Map<String, dynamic>>[];

    for (final record in records) {
      switch (record.type) {
        case HealthDataType.RESTING_HEART_RATE:
          final value = _extractNumericValue(record);
          if (value != null) restingHr ??= value;
          break;

        // iOS HealthKit provides SDNN, not RMSSD
        case HealthDataType.HEART_RATE_VARIABILITY_SDNN:
          final value = _extractNumericValue(record);
          if (value != null) hrvSdnn ??= value;
          break;

        case HealthDataType.BLOOD_OXYGEN:
          final value = _extractNumericValue(record);
          if (value != null) {
            oxygenSaturation ??= value > 1 ? value / 100.0 : value;
          }
          break;

        case HealthDataType.STEPS:
          final value = _extractNumericValue(record);
          if (value != null) steps = (steps ?? 0) + value;
          break;

        // HealthKit sleep categories (value codes per healthkit.rs):
        // 0=InBed, 1=AsleepUnspecified, 2=Awake, 3=AsleepCore, 4=AsleepDeep, 5=AsleepREM
        case HealthDataType.SLEEP_IN_BED:
          sleepSamples.add({
            'value': 0, // InBed
            'startDate': _formatRfc3339(record.dateFrom),
            'endDate': _formatRfc3339(record.dateTo),
          });
          break;
        case HealthDataType.SLEEP_ASLEEP:
          sleepSamples.add({
            'value': 1, // AsleepUnspecified
            'startDate': _formatRfc3339(record.dateFrom),
            'endDate': _formatRfc3339(record.dateTo),
          });
          break;
        case HealthDataType.SLEEP_AWAKE:
          sleepSamples.add({
            'value': 2, // Awake
            'startDate': _formatRfc3339(record.dateFrom),
            'endDate': _formatRfc3339(record.dateTo),
          });
          break;
        case HealthDataType.SLEEP_LIGHT:
          sleepSamples.add({
            'value': 3, // AsleepCore (light sleep)
            'startDate': _formatRfc3339(record.dateFrom),
            'endDate': _formatRfc3339(record.dateTo),
          });
          break;
        case HealthDataType.SLEEP_DEEP:
          sleepSamples.add({
            'value': 4, // AsleepDeep
            'startDate': _formatRfc3339(record.dateFrom),
            'endDate': _formatRfc3339(record.dateTo),
          });
          break;
        case HealthDataType.SLEEP_REM:
          sleepSamples.add({
            'value': 5, // AsleepREM
            'startDate': _formatRfc3339(record.dateFrom),
            'endDate': _formatRfc3339(record.dateTo),
          });
          break;

        default:
          break;
      }
    }

    if (restingHr == null &&
        hrvSdnn == null &&
        sleepSamples.isEmpty &&
        oxygenSaturation == null &&
        steps == null) {
      return null;
    }

    final hasBiometrics =
        restingHr != null || hrvSdnn != null || sleepSamples.isNotEmpty;

    // Key names match healthkit.rs schema exactly
    // The normalizer supports both wrapped { "value": X } and direct numeric
    final payload = <String, dynamic>{
      'date': date,
      if (restingHr != null) 'resting_heart_rate': restingHr,
      if (hrvSdnn != null) 'hrv_sdnn': hrvSdnn,
      if (oxygenSaturation != null) 'oxygen_saturation': oxygenSaturation,
      if (sleepSamples.isNotEmpty) 'sleep_samples': sleepSamples,
      if (steps != null) 'steps': steps.round(),
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

  // ===========================================================================
  // Workout time-in-zone — intra-workout HR samples → engine producer.
  //
  // Health Connect / HealthKit expose per-reading HEART_RATE samples (the same
  // stream a watch records during a session). We bound them by the workout's
  // WORKOUT session window and hand the raw stream to the engine, which bins it
  // through MiValta's own zone_anchors scale (no Dart-side binning).
  // ===========================================================================

  /// Build the engine activity wire from intra-workout HR samples.
  ///
  /// ZERO-FABRICATION transport: orders the samples by time, drops non-positive
  /// (dropout) readings, and emits `hr_samples` alongside `hr_timestamps` (each
  /// reading's epoch seconds). The engine bins by TRUE per-sample dwell — each
  /// reading credited for the gap until the next, with its own adaptive
  /// pause/dropout clamp — which is exact for the irregular sampling these
  /// stores produce. No dwell math in Dart: we only forward the timestamps the
  /// platform already recorded.
  ///
  /// `sample_rate_hz` is still emitted as the engine's uniform fallback for any
  /// consumer that ignores timestamps (`rate = n / duration_seconds`, so total
  /// dwell ≈ the session). The timestamped path supersedes it in the engine.
  ///
  /// Returns null when there are too few samples or the window is non-positive —
  /// the caller renders the honest no-data state rather than a thin guess.
  static String? buildHrActivityJson({
    required DateTime workoutStart,
    required DateTime workoutEnd,
    required List<({DateTime t, double bpm})> hrSamples,
  }) {
    final valid = hrSamples.where((s) => s.bpm > 0).toList()
      ..sort((a, b) => a.t.compareTo(b.t));
    if (valid.length < 2) return null;

    final durationSeconds = workoutEnd.difference(workoutStart).inSeconds;
    if (durationSeconds <= 0) return null;

    final rateHz = valid.length / durationSeconds;
    return jsonEncode({
      'completed_at': workoutEnd.toUtc().toIso8601String(),
      'power_samples': <double>[],
      'hr_samples': valid.map((s) => s.bpm).toList(growable: false),
      'hr_timestamps': valid
          .map((s) => s.t.millisecondsSinceEpoch / 1000.0)
          .toList(growable: false),
      'sample_rate_hz': rateHz,
    });
  }

  /// Build the JSON for a raw vendor observation (vault-first ingest §B).
  ///
  /// This wraps the vendor payload with metadata required by the engine's
  /// `write_raw_observation` FFI call. The raw observation is stored
  /// *before* normalization for audit + replay capability.
  ///
  /// [date] is the ISO 8601 date string (e.g., '2026-06-13').
  /// [source] is the vendor identifier ('apple' or 'health_connect').
  /// [dataType] is typically 'biometric' for daily observations.
  /// [payload] is the vendor-specific JSON payload to preserve.
  static String buildRawObservationJson({
    required String date,
    required String source,
    required String dataType,
    required String payload,
  }) =>
      // Single source of truth lives in the shared ingest adapter (Task 0);
      // this static is retained for existing callers/tests.
      ingest.buildRawObservationJson(
        date: date,
        source: source,
        dataType: dataType,
        payload: payload,
      );

  /// Compute the time-in-zone distribution for the athlete's most recent
  /// workout in the last [lookbackDays] days, by pulling its intra-workout HR
  /// samples and binning them through the engine (`computeTimeInZone`).
  ///
  /// Returns null when permissions are missing, there is no recent workout, or
  /// the HR stream is too thin — every failure is swallowed into a null so the
  /// detail surface degrades to its no-data state, never an error.
  Future<TimeInZone?> latestWorkoutTimeInZone({int lookbackDays = 14}) async {
    try {
      if (!await hasPermissions()) return null;

      final now = DateTime.now();
      final from = now.subtract(Duration(days: lookbackDays));

      final workouts = await _health.getHealthDataFromTypes(
        types: [HealthDataType.WORKOUT],
        startTime: from,
        endTime: now,
      );
      if (workouts.isEmpty) return null;
      workouts.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));
      final workout = workouts.first;

      final hrPoints = await _health.getHealthDataFromTypes(
        types: [HealthDataType.HEART_RATE],
        startTime: workout.dateFrom,
        endTime: workout.dateTo,
      );

      final samples = <({DateTime t, double bpm})>[];
      for (final p in hrPoints) {
        final bpm = _extractNumericValue(p);
        if (bpm != null) samples.add((t: p.dateFrom, bpm: bpm));
      }

      final activityJson = buildHrActivityJson(
        workoutStart: workout.dateFrom,
        workoutEnd: workout.dateTo,
        hrSamples: samples,
      );
      if (activityJson == null) return null;

      final tizJson = await binding.computeTimeInZone(
        handle,
        activityJson: activityJson,
      );
      return TimeInZone.fromJson(jsonDecode(tizJson));
    } catch (e) {
      // Degrade to "no time-in-zone" but name the cause in debug — a blanket
      // swallow hid engine errors (profile mismatch, malformed wire) and made
      // on-device diagnosis impossible (#51 review).
      if (kDebugMode) {
        // ignore: avoid_print
        print('latestWorkoutTimeInZone: ${e.runtimeType}: $e');
      }
      return null;
    }
  }
}

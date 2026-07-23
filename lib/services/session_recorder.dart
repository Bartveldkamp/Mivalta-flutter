// Session Recorder Service — BS-010
//
// DART-SIDE recorder: sensor capture (HR, GPS) is app-side work.
// Engine enters ONLY at session end (BS-011 ingest).
// Live zones are BLOCKED on engine gap G4 — raw numbers only.

import 'dart:async';
import 'package:flutter/foundation.dart';

/// Session state during recording.
enum SessionState { idle, recording, paused }

/// Snapshot of live sensor data.
class LiveSensorData {
  const LiveSensorData({
    this.heartRate,
    this.speed,
    this.distance,
    this.avgSpeed,
    this.avgHeartRate,
    this.pace,
    this.avgPace,
  });

  /// Current heart rate in bpm (null if no sensor).
  final int? heartRate;

  /// Current speed in km/h (null if no GPS).
  final double? speed;

  /// Total distance in km.
  final double? distance;

  /// Average speed in km/h.
  final double? avgSpeed;

  /// Average heart rate in bpm.
  final int? avgHeartRate;

  /// Current pace in seconds per km (null if no speed).
  final int? pace;

  /// Average pace in seconds per km.
  final int? avgPace;

  /// Whether we have any live heart rate data.
  bool get hasHeartRate => heartRate != null;

  /// Whether we have any GPS data.
  bool get hasGps => speed != null || distance != null;

  /// Format pace as mm:ss/km.
  static String formatPace(int? secondsPerKm) {
    if (secondsPerKm == null) return '--:--';
    final minutes = secondsPerKm ~/ 60;
    final seconds = secondsPerKm % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

/// Completed session data for hand-off to reveal screen.
class CompletedSession {
  const CompletedSession({
    required this.sport,
    required this.startTime,
    required this.endTime,
    required this.elapsedSeconds,
    this.distanceKm,
    this.avgHeartRate,
    this.maxHeartRate,
    this.avgSpeedKmh,
    this.hrSamples,
    this.speedSamples,
    this.powerSamples,
  });

  final String sport;
  final DateTime startTime;
  final DateTime endTime;
  final int elapsedSeconds;
  final double? distanceKm;
  final int? avgHeartRate;
  final int? maxHeartRate;
  final double? avgSpeedKmh;

  /// Raw HR samples (1 Hz) for post-processing.
  final List<int>? hrSamples;

  /// Raw speed samples (1 Hz) for post-processing.
  final List<double>? speedSamples;

  /// Raw power samples (watts, 1 Hz) for post-processing — the cyclist's
  /// Critical Power stream, the mirror of [speedSamples] for runners. Source
  /// is a BLE power meter (pending, like GPS for speed); null until one is
  /// connected — honest absence, never fabricated watts.
  final List<int>? powerSamples;

  /// Duration as HH:MM:SS.
  String get formattedDuration {
    final hours = elapsedSeconds ~/ 3600;
    final minutes = (elapsedSeconds % 3600) ~/ 60;
    final seconds = elapsedSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Pace as mm:ss/km (if distance > 0).
  String? get formattedPace {
    if (distanceKm == null || distanceKm! <= 0) return null;
    final secondsPerKm = elapsedSeconds / distanceKm!;
    final minutes = secondsPerKm ~/ 60;
    final seconds = (secondsPerKm % 60).round();
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // NOTE: the vault serialization of a completed session lives in
  // `buildRevealActivityJson` (session_reveal_screen.dart) — the one real
  // serializer. A duplicate `toJson()` here (zero callers) was removed in the
  // dead-code sweep; do not reintroduce a second serialization of the same
  // session shape.
}

/// Session recorder — Dart-side, no engine until session end.
///
/// Usage:
/// 1. Create recorder with sport
/// 2. Call start() to begin
/// 3. Listen to streams for elapsed/sensors
/// 4. Call pause()/resume() as needed
/// 5. Call stop() to complete — returns CompletedSession
class SessionRecorder {
  SessionRecorder({required this.sport});

  final String sport;

  SessionState _state = SessionState.idle;
  SessionState get state => _state;

  DateTime? _startTime;
  DateTime? _endTime;
  int _elapsedSeconds = 0;

  Timer? _elapsedTimer;
  Timer? _sensorTimer;

  // Sample buffers (1 Hz).
  final List<int> _hrSamples = [];
  final List<double> _speedSamples = [];
  final List<int> _powerSamples = [];

  // Live sensor state (simulated for now — BLE integration pending).
  int? _currentHr;
  double? _currentSpeed;
  int? _currentPower;
  double _distance = 0;

  // Stream controllers.
  final _elapsedController = StreamController<int>.broadcast();
  final _sensorController = StreamController<LiveSensorData>.broadcast();
  final _stateController = StreamController<SessionState>.broadcast();

  /// Stream of elapsed seconds (updates every second).
  Stream<int> get elapsedStream => _elapsedController.stream;

  /// Stream of live sensor data (updates every second).
  Stream<LiveSensorData> get sensorStream => _sensorController.stream;

  /// Stream of session state changes.
  Stream<SessionState> get stateStream => _stateController.stream;

  /// Current elapsed seconds.
  int get elapsedSeconds => _elapsedSeconds;

  /// Current sensor data snapshot.
  LiveSensorData get currentSensorData => _buildSensorData();

  /// Format elapsed as HH:MM:SS or MM:SS.
  String get formattedElapsed {
    final hours = _elapsedSeconds ~/ 3600;
    final minutes = (_elapsedSeconds % 3600) ~/ 60;
    final seconds = _elapsedSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Start recording.
  void start() {
    if (_state != SessionState.idle) return;

    _startTime = DateTime.now();
    _elapsedSeconds = 0;
    _hrSamples.clear();
    _speedSamples.clear();
    _powerSamples.clear();
    _distance = 0;

    _state = SessionState.recording;
    _stateController.add(_state);

    // Elapsed timer — ticks every second.
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_state == SessionState.recording) {
        _elapsedSeconds++;
        _elapsedController.add(_elapsedSeconds);
      }
    });

    // Sensor poll timer — samples every second.
    _sensorTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_state == SessionState.recording) {
        _pollSensors();
        _sensorController.add(_buildSensorData());
      }
    });

    debugPrint('Session started: sport=$sport');
  }

  /// Pause recording.
  void pause() {
    if (_state != SessionState.recording) return;

    _state = SessionState.paused;
    _stateController.add(_state);
    debugPrint('Session paused at $_elapsedSeconds seconds');
  }

  /// Resume recording.
  void resume() {
    if (_state != SessionState.paused) return;

    _state = SessionState.recording;
    _stateController.add(_state);
    debugPrint('Session resumed');
  }

  /// Stop recording and return completed session.
  CompletedSession stop() {
    _endTime = DateTime.now();
    _state = SessionState.idle;
    _stateController.add(_state);

    _elapsedTimer?.cancel();
    _sensorTimer?.cancel();

    final completed = CompletedSession(
      sport: sport,
      startTime: _startTime ?? DateTime.now(),
      endTime: _endTime!,
      elapsedSeconds: _elapsedSeconds,
      distanceKm: _distance > 0 ? _distance : null,
      avgHeartRate: _hrSamples.isNotEmpty
          ? (_hrSamples.reduce((a, b) => a + b) / _hrSamples.length).round()
          : null,
      maxHeartRate: _hrSamples.isNotEmpty
          ? _hrSamples.reduce((a, b) => a > b ? a : b)
          : null,
      avgSpeedKmh: _speedSamples.isNotEmpty
          ? _speedSamples.reduce((a, b) => a + b) / _speedSamples.length
          : null,
      hrSamples: _hrSamples.isNotEmpty ? List.from(_hrSamples) : null,
      speedSamples: _speedSamples.isNotEmpty ? List.from(_speedSamples) : null,
      powerSamples: _powerSamples.isNotEmpty ? List.from(_powerSamples) : null,
    );

    debugPrint('Session stopped: ${completed.formattedDuration}');
    return completed;
  }

  /// Dispose resources.
  void dispose() {
    _elapsedTimer?.cancel();
    _sensorTimer?.cancel();
    _elapsedController.close();
    _sensorController.close();
    _stateController.close();
  }

  /// Poll sensors for current values.
  /// TODO: Wire BLE HR strap, GPS location.
  /// For now, values are null (honest absence).
  void _pollSensors() {
    // BLE HR strap integration pending — _currentHr stays null.
    // GPS integration pending — _currentSpeed stays null.
    // BLE power-meter integration pending — _currentPower stays null.
    // This is correct honest-absence behavior per BS-010.

    // Record samples if we have values.
    if (_currentHr != null) {
      _hrSamples.add(_currentHr!);
    }
    if (_currentSpeed != null) {
      _speedSamples.add(_currentSpeed!);
      // Accumulate distance (speed is km/h, sample is 1 second).
      _distance += _currentSpeed! / 3600;
    }
    if (_currentPower != null) {
      _powerSamples.add(_currentPower!);
    }
  }

  /// Build current sensor data snapshot.
  LiveSensorData _buildSensorData() {
    final avgHr = _hrSamples.isNotEmpty
        ? (_hrSamples.reduce((a, b) => a + b) / _hrSamples.length).round()
        : null;
    final avgSpeed = _speedSamples.isNotEmpty
        ? _speedSamples.reduce((a, b) => a + b) / _speedSamples.length
        : null;

    int? pace;
    int? avgPace;
    if (_currentSpeed != null && _currentSpeed! > 0) {
      pace = (3600 / _currentSpeed!).round();
    }
    if (avgSpeed != null && avgSpeed > 0) {
      avgPace = (3600 / avgSpeed).round();
    }

    return LiveSensorData(
      heartRate: _currentHr,
      speed: _currentSpeed,
      distance: _distance > 0 ? _distance : null,
      avgSpeed: avgSpeed,
      avgHeartRate: avgHr,
      pace: pace,
      avgPace: avgPace,
    );
  }

  // === Test/Debug support ===

  /// Inject simulated HR value (for testing).
  @visibleForTesting
  void injectHeartRate(int? hr) {
    _currentHr = hr;
  }

  /// Inject simulated speed value (for testing).
  @visibleForTesting
  void injectSpeed(double? speedKmh) {
    _currentSpeed = speedKmh;
  }

  /// Inject a power sample (watts) — the BLE power-meter seam, the mirror of
  /// [injectSpeed]. Test/integration entry until a real power meter is wired;
  /// null until one is connected (honest absence, never fabricated watts).
  @visibleForTesting
  void injectPower(int? watts) {
    _currentPower = watts;
  }
}

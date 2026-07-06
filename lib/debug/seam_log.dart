// BS-018: Wiring stamp — kDebugMode-only seam call logger.
//
// Every FFI seam records its result via SeamLog.record(name, result).
// The wiring stamp panel reads these entries to show health status.
// In release builds, all calls compile to no-ops.
//
// Usage:
//   final sw = Stopwatch()..start();
//   try {
//     final result = await binding.someSeam(handle);
//     SeamLog.ok('someSeam', sw.elapsedMilliseconds);
//     // ... use result
//   } catch (e) {
//     SeamLog.error('someSeam', sw.elapsedMilliseconds, e);
//     // ... handle error
//   }

import 'package:flutter/foundation.dart';

/// Result status for a seam call.
enum SeamStatus { ok, error, notCalled }

/// A single seam call record.
class SeamRecord {
  const SeamRecord({
    required this.name,
    required this.status,
    required this.durationMs,
    this.errorType,
    required this.timestamp,
  });

  final String name;
  final SeamStatus status;
  final int durationMs;
  final String? errorType;
  final DateTime timestamp;

  @override
  String toString() {
    final statusStr = switch (status) {
      SeamStatus.ok => 'ok',
      SeamStatus.error => 'error:${errorType ?? 'unknown'}',
      SeamStatus.notCalled => 'not-called',
    };
    return '$name · $statusStr · ${durationMs}ms';
  }
}

/// kDebugMode-only seam call logger.
///
/// In release builds, all methods are no-ops (compiled out).
abstract final class SeamLog {
  // Internal storage — only populated in debug mode.
  static final Map<String, SeamRecord> _records = {};

  /// Record a successful seam call.
  static void ok(String name, int durationMs) {
    if (!kDebugMode) return;
    _records[name] = SeamRecord(
      name: name,
      status: SeamStatus.ok,
      durationMs: durationMs,
      timestamp: DateTime.now(),
    );
  }

  /// Record a failed seam call.
  static void error(String name, int durationMs, Object error) {
    if (!kDebugMode) return;
    _records[name] = SeamRecord(
      name: name,
      status: SeamStatus.error,
      durationMs: durationMs,
      errorType: error.runtimeType.toString(),
      timestamp: DateTime.now(),
    );
  }

  /// Mark a seam as not-called this session.
  static void notCalled(String name) {
    if (!kDebugMode) return;
    if (!_records.containsKey(name)) {
      _records[name] = SeamRecord(
        name: name,
        status: SeamStatus.notCalled,
        durationMs: 0,
        timestamp: DateTime.now(),
      );
    }
  }

  /// Get all recorded seams (most recent call per seam).
  static List<SeamRecord> get entries {
    if (!kDebugMode) return const [];
    return _records.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  /// Clear all records (e.g., on hot reload).
  static void clear() {
    if (!kDebugMode) return;
    _records.clear();
  }

  /// Count of seams with ok status.
  static int get okCount {
    if (!kDebugMode) return 0;
    return _records.values.where((r) => r.status == SeamStatus.ok).length;
  }

  /// Count of seams with error status.
  static int get errorCount {
    if (!kDebugMode) return 0;
    return _records.values.where((r) => r.status == SeamStatus.error).length;
  }

  /// Total seams recorded.
  static int get totalCount {
    if (!kDebugMode) return 0;
    return _records.length;
  }
}

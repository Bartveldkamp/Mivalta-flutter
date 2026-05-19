// Day-7 hardware-verification telemetry. Thin Dart wrapper over the
// `com.mivalta.flutter/hw_telemetry` MethodChannel exposed by
// `android/app/src/main/kotlin/.../MainActivity.kt`. Sampling cadence
// is driven by callers (a periodic timer during a V10.1 run);
// `peakPssDuring` runs the timer + collects max for one
// generation-shaped Future.

import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart';

class HwTelemetry {
  HwTelemetry._();

  static const MethodChannel _ch =
      MethodChannel('com.mivalta.flutter/hw_telemetry');

  /// Current Debug.MemoryInfo.totalPss in KB, or `-1` on the host /
  /// non-Android platforms. Single-shot; the V10.1 overlay polls
  /// this on a 250ms timer during a generation run.
  static Future<int> pssKb() async {
    try {
      final v = await _ch.invokeMethod<int>('pssKb');
      return v ?? -1;
    } on MissingPluginException {
      return -1;
    } on PlatformException {
      return -1;
    }
  }

  /// `Build.MODEL` from Android (e.g. "edge 60"). Empty on host.
  static Future<String> deviceModel() async {
    try {
      return await _ch.invokeMethod<String>('deviceModel') ?? '';
    } on MissingPluginException {
      return '';
    }
  }

  /// `Build.VERSION.RELEASE` from Android (e.g. "14"). Empty on host.
  static Future<String> osRelease() async {
    try {
      return await _ch.invokeMethod<String>('osRelease') ?? '';
    } on MissingPluginException {
      return '';
    }
  }

  /// SHA-256 of the running APK, lowercase hex. Matches
  /// `sha256sum app-debug.apk` on Hetzner so the founder's results
  /// doc lines up with the build artifact identity. Empty on host.
  static Future<String> apkSha256() async {
    try {
      return await _ch.invokeMethod<String>('apkSha256') ?? '';
    } on MissingPluginException {
      return '';
    }
  }

  /// Run [work] and concurrently sample PSS every [interval]. Returns
  /// `(workResult, peakPssKb)`. If the platform channel is unavailable
  /// (host runs, or production-build flavours that strip it), the
  /// peak comes back as `-1`. Sampling is debug-only by default so
  /// release builds don't pay the 4Hz IPC cost.
  static Future<({T result, int peakPssKb})> peakPssDuring<T>(
    Future<T> Function() work, {
    Duration interval = const Duration(milliseconds: 250),
    bool forceSample = false,
  }) async {
    if (!kDebugMode && !forceSample) {
      final result = await work();
      return (result: result, peakPssKb: -1);
    }
    var peak = -1;
    final timer = Timer.periodic(interval, (_) async {
      final v = await pssKb();
      if (v > peak) peak = v;
    });
    try {
      final result = await work();
      // Final sample after the work finishes — captures any
      // post-decode allocations the timer missed.
      final last = await pssKb();
      if (last > peak) peak = last;
      return (result: result, peakPssKb: peak);
    } finally {
      timer.cancel();
    }
  }
}

// Round 3 items 11+18 (FOUNDER_FEEDBACK_2026-06-12): local weather via Apple
// WeatherKit — the founder-approved OS-LEVEL exception to the no-cloud rule
// (CLAUDE.md rule 6). The fetch is performed by the OS frame (WeatherKit +
// CoreLocation) on the native side; MiValta servers are never involved and
// no MiValta-originated HTTP happens here.
//
// This file is pure transport + parsing. ANY failure (no iOS 16, permission
// denied, WeatherKit error, Android = no implementation yet) returns null and
// the UI renders honest absence — no icon, no fabricated conditions.

import 'package:flutter/services.dart';

/// One day of the 7-day forecast, parsed from the native payload.
class WeatherDay {
  const WeatherDay({
    required this.date,
    required this.symbol,
    required this.condition,
    required this.highC,
    required this.lowC,
  });

  /// yyyy-MM-dd (device-local calendar day).
  final String date;

  /// Apple SF Symbol name (e.g. `cloud.rain`) — mapped to a Material glyph
  /// at the display layer via a fixed dictionary.
  final String symbol;

  /// Human condition text from the OS (e.g. `Mostly Clear`).
  final String condition;
  final double highC;
  final double lowC;
}

/// Current conditions + up to 7 daily entries, verbatim from the OS.
class WeatherReport {
  const WeatherReport({
    required this.symbol,
    required this.condition,
    required this.temperatureC,
    required this.daily,
  });

  final String symbol;
  final String condition;
  final double temperatureC;
  final List<WeatherDay> daily;
}

class WeatherService {
  static const MethodChannel _channel = MethodChannel('mivalta/weather');

  /// Returns null on ANY failure — callers render honest absence.
  /// Android: the channel has no handler yet (equivalent t.b.d. per founder
  /// decision 18), so this returns null there too.
  static Future<WeatherReport?> fetch() async {
    try {
      final raw = await _channel.invokeMethod<dynamic>('getWeather');
      if (raw is! Map) return null;
      return _parse(raw);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  static WeatherReport? _parse(Map<dynamic, dynamic> raw) {
    final symbol = raw['symbol'];
    final condition = raw['condition'];
    final temp = raw['temperatureC'];
    final daily = raw['daily'];
    if (symbol is! String || condition is! String || temp is! num) {
      return null;
    }
    final days = <WeatherDay>[];
    if (daily is List) {
      for (final d in daily) {
        if (d is! Map) continue;
        final date = d['date'];
        final s = d['symbol'];
        final c = d['condition'];
        final hi = d['highC'];
        final lo = d['lowC'];
        if (date is String &&
            s is String &&
            c is String &&
            hi is num &&
            lo is num) {
          days.add(WeatherDay(
            date: date,
            symbol: s,
            condition: c,
            highC: hi.toDouble(),
            lowC: lo.toDouble(),
          ));
        }
      }
    }
    return WeatherReport(
      symbol: symbol,
      condition: condition,
      temperatureC: temp.toDouble(),
      daily: days,
    );
  }
}

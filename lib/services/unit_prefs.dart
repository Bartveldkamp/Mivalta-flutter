// NEXT_BUILD_BRIEF §D: Unit system preference (metric vs imperial).
//
// DISPLAY FORMATTING ONLY — the engine stays SI (metric) internally.
// This preference only affects how values are rendered in the UI.
//
// Examples:
//   - Distances: km vs mi
//   - Pace: min/km vs min/mi
//   - Speed: km/h vs mph
//   - Temperature: °C vs °F (if ever shown)
//   - Weight: kg vs lb (if ever shown)
//
// Honest-failure contract: any load failure → default to metric.

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// The unit system for display formatting.
enum UnitSystem { metric, imperial }

/// Loads/saves the user's unit system preference.
class UnitPrefs {
  UnitPrefs({Directory? dir}) : _dir = dir; // ignore: prefer_initializing_formals

  static const _fileName = 'unit_prefs.json';

  final Directory? _dir;

  Future<File> _file() async {
    final dir = _dir ?? await getApplicationSupportDirectory();
    return File('${dir.path}/$_fileName');
  }

  /// The current unit system. Any failure → metric (the engine default).
  Future<UnitSystem> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return UnitSystem.metric;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) return UnitSystem.metric;
      final system = decoded['unit_system'];
      if (system == 'imperial') return UnitSystem.imperial;
      return UnitSystem.metric;
    } catch (_) {
      return UnitSystem.metric;
    }
  }

  /// Best-effort save; failures are silent.
  Future<void> save(UnitSystem system) async {
    try {
      final file = await _file();
      await file.writeAsString(jsonEncode({
        'unit_system': system == UnitSystem.imperial ? 'imperial' : 'metric',
      }));
    } catch (_) {
      // Silent — UI preference only.
    }
  }
}

// =============================================================================
// Unit conversion helpers (engine SI → display units)
// =============================================================================

/// Format distance in the user's preferred unit.
/// [km] is the distance in kilometers (engine SI).
String formatDistance(double km, UnitSystem system) {
  if (system == UnitSystem.imperial) {
    final mi = km * 0.621371;
    return mi < 10 ? '${mi.toStringAsFixed(1)} mi' : '${mi.round()} mi';
  }
  return km < 10 ? '${km.toStringAsFixed(1)} km' : '${km.round()} km';
}

/// Format pace in the user's preferred unit.
/// [secPerKm] is seconds per kilometer (engine SI).
String formatPace(int secPerKm, UnitSystem system) {
  if (system == UnitSystem.imperial) {
    // Convert sec/km → sec/mi
    final secPerMi = (secPerKm * 1.60934).round();
    final min = secPerMi ~/ 60;
    final sec = secPerMi % 60;
    return '$min:${sec.toString().padLeft(2, '0')} /mi';
  }
  final min = secPerKm ~/ 60;
  final sec = secPerKm % 60;
  return '$min:${sec.toString().padLeft(2, '0')} /km';
}

/// Format speed in the user's preferred unit.
/// [kmh] is speed in km/h (engine SI).
String formatSpeed(double kmh, UnitSystem system) {
  if (system == UnitSystem.imperial) {
    final mph = kmh * 0.621371;
    return '${mph.toStringAsFixed(1)} mph';
  }
  return '${kmh.toStringAsFixed(1)} km/h';
}

/// Format elevation in the user's preferred unit.
/// [meters] is elevation in meters (engine SI).
String formatElevation(double meters, UnitSystem system) {
  if (system == UnitSystem.imperial) {
    final feet = meters * 3.28084;
    return '${feet.round()} ft';
  }
  return '${meters.round()} m';
}

/// Format weight in the user's preferred unit.
/// [kg] is weight in kilograms (engine SI).
String formatWeight(double kg, UnitSystem system) {
  if (system == UnitSystem.imperial) {
    final lb = kg * 2.20462;
    return '${lb.toStringAsFixed(1)} lb';
  }
  return '${kg.toStringAsFixed(1)} kg';
}

/// The unit label for distance.
String distanceUnit(UnitSystem system) =>
    system == UnitSystem.imperial ? 'mi' : 'km';

/// The unit label for pace.
String paceUnit(UnitSystem system) =>
    system == UnitSystem.imperial ? '/mi' : '/km';

/// The unit label for speed.
String speedUnit(UnitSystem system) =>
    system == UnitSystem.imperial ? 'mph' : 'km/h';

/// The unit label for elevation.
String elevationUnit(UnitSystem system) =>
    system == UnitSystem.imperial ? 'ft' : 'm';

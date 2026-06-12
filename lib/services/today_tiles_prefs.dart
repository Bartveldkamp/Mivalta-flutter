// Round 3 item 12: persistence for the user-configurable today-tiles.
//
// Pure UI preference — which tiles the user wants on the home. NOT coaching
// data, NOT engine state, so it lives in a tiny plaintext JSON file beside
// the pointer file (same app-support directory ProfileService uses), not in
// the encrypted vault.
//
// Honest-failure contract: ANY load failure (no file, malformed JSON, missing
// plugin in the test harness) → the default all-on set. Saves are best-effort
// and silent — a failed write must never break the home.

import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../copy/today_facts_labels.dart';

/// Loads/saves the set of enabled today-tile ids. Production call site:
/// ReadinessScreen. [dir] is injectable so unit tests can round-trip through
/// a temp directory without path_provider.
class TodayTilesPrefs {
  TodayTilesPrefs({Directory? dir}) : _dir = dir; // ignore: prefer_initializing_formals

  static const _fileName = 'today_tiles.json';

  final Directory? _dir;

  Future<File> _file() async {
    final dir = _dir ?? await getApplicationSupportDirectory();
    return File('${dir.path}/$_fileName');
  }

  /// The enabled tile ids, filtered to known ids. Any failure → defaults.
  Future<Set<String>> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return Set.of(kDefaultTodayTiles);
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        return Set.of(kDefaultTodayTiles);
      }
      final enabled = decoded['enabled'];
      if (enabled is! List) return Set.of(kDefaultTodayTiles);
      return enabled
          .whereType<String>()
          .where(kTodayTileIds.contains)
          .toSet();
    } catch (_) {
      return Set.of(kDefaultTodayTiles);
    }
  }

  /// Best-effort save; failures are silent (the in-memory state already
  /// reflects the user's choice for this session).
  Future<void> save(Set<String> enabled) async {
    try {
      final file = await _file();
      await file.writeAsString(jsonEncode({
        'enabled': [
          for (final id in kTodayTileIds)
            if (enabled.contains(id)) id,
        ],
      }));
    } catch (_) {
      // Silent — UI preference only.
    }
  }
}

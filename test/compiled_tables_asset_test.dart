// M4 — stale-compiled-tables crash guard.
//
// The engine fail-loud panics at launch on a missing REQUIRED table (the #121
// class: `REQUIRED table missing: card='anaerobic_execution_policy',
// table='phase_execution'` — a re-pin that forgot to resync assets/
// compiled_tables.json). This runs in `flutter test` (part of both the smoke
// and drift-guard CI jobs), so an asset that lost a load-bearing table is caught
// here, not as a device launch crash.
//
// SCOPE (honest): this is a PRESENCE guard for the known load-bearing / crash
// tables + a sanity size check — NOT a full asset-vs-engine-pin parity check.
// True parity (regenerate `gatc-export` at the pinned rev and diff) needs the
// engine source in CI and is tracked separately; this catches the specific
// recurrence class cheaply.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compiled_tables.json is present, parses, and carries required tables', () {
    final file = File('assets/compiled_tables.json');
    expect(file.existsSync(), isTrue,
        reason: 'assets/compiled_tables.json must be committed');

    final decoded = jsonDecode(file.readAsStringSync());
    expect(decoded, isA<Map>(), reason: 'asset must be a JSON object of tables');
    final tables = (decoded as Map).keys.cast<String>().toSet();

    // Sanity: the full card set is large (268 at the current b7264cb pin). A
    // sharply smaller count means a truncated/partial export.
    expect(tables.length, greaterThan(200),
        reason: 'asset looks truncated (${tables.length} tables)');

    // Load-bearing tables the engine's require_table() panics without at launch.
    // anaerobic_execution_policy:phase_execution is the exact #121 crash table.
    const required = <String>[
      'anaerobic_execution_policy:phase_execution',
      'zone_anchors:power_zones',
      'zone_anchors:hr_zones',
      'zone_physiology:zone_physiology',
      'load_monitoring:readiness_levels',
    ];
    for (final t in required) {
      expect(tables.contains(t), isTrue,
          reason: 'required table "$t" missing — assets/compiled_tables.json is '
              'likely stale vs the engine pin; regenerate (cargo run -p '
              'gatc-export at the pinned rev) and resync the asset');
    }
  });
}

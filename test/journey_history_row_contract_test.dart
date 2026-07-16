// PR-T1 A3 — the read_readiness_history row → journey arc contract, pinned.
//
// The engine's read_readiness_history returns serde-serialized
// `VaultBiometric` rows (gatc-vault/src/models.rs — `readiness_score`,
// `readiness_level`, no serde rename; the gatc-ffi writeback test asserts
// rows[0]["readiness_level"] verbatim, gatc-ffi/src/lib.rs). The journey arc
// previously read entry['level'] — a key those rows never carry (that key
// belongs to the readiness_indicator payload) — so `level` was always null
// and every arc dot fell back to the unknown-level color (the A3 finding).
// This test pins the row keys so a rename on either side fails HERE, not
// silently on an athlete's phone.

import 'package:flutter_test/flutter_test.dart';

import 'package:mivalta_flutter/screens/journey_screen.dart';

void main() {
  test('journey history row parse reads the VaultBiometric keys', () {
    final parsed = parseReadinessHistoryRow(<String, dynamic>{
      'date': '2026-07-16',
      'readiness_score': 72,
      'readiness_level': 'green',
    });

    expect(parsed.level, 'green',
        reason: 'the arc dot color reads readiness_level — level is the '
            'readiness_indicator key and never appears on history rows');
    expect(parsed.score, 72,
        reason: 'the arc y-position reads readiness_score verbatim');
  });

  test('absent fields parse to honest null, never a stand-in', () {
    final parsed =
        parseReadinessHistoryRow(<String, dynamic>{'date': '2026-07-16'});

    expect(parsed.score, isNull);
    expect(parsed.level, isNull);
  });
}

// Zone display names — canonical mapping from engine zone codes to UI labels.
//
// Engine truth (gatc-advisor workout_suggester ZONE tags): Z1 Recovery,
// Z2 Endurance, Z3 Tempo, Z4 Threshold, Z5 VO₂max, Z6 Anaerobic, Z7 Neuromuscular.
// Z8 is used elsewhere but mapped to Max power. REST is a special case.
//
// LOCKED (DR-018 A3): this is the SINGLE source of truth for zone→name mapping
// in the app. Do not duplicate this mapping elsewhere.

import 'package:flutter/material.dart';
import 'tokens.dart';

/// Returns (energyName, color) for a zone code.
///
/// LEVELS LAW (founder 2026-07-10, DECISIONS Entry AP; communication shape
/// amended by the founder exemplar 2026-07-13 — engine #406/#411): the level
/// LEADS; the zone code may ride NESTED behind it ("Endurance · Z2") but never
/// travels alone or in front. See [zoneDisplayLabel]. The engine mapping stays
/// the same; only what the athlete sees changes.
(String, Color) zoneDisplayNameAndColor(String zone) {
  return switch (zone.toUpperCase()) {
    'Z1' => ('Recovery', MivaltaColors.stateProductive),
    'Z2' => ('Endurance', MivaltaColors.stateProductive),
    'Z3' => ('Tempo', MivaltaColors.stateProductive),
    'Z4' => ('Threshold', MivaltaColors.stateAccumulated),
    'Z5' => ('VO₂max', MivaltaColors.stateAccumulated),
    'Z6' => ('Anaerobic', MivaltaColors.levelRed),
    'Z7' => ('Neuromuscular', MivaltaColors.levelRed),
    'Z8' => ('Max power', MivaltaColors.levelRed),
    'REST' => ('Rest day', MivaltaColors.textSecondary),
    _ => (zone, MivaltaColors.textSecondary), // Unknown → show raw
  };
}

/// Formats a zone for athlete display: level leading, code nested
/// ("Endurance · Z2").
///
/// LEVELS LAW communication shape (Entry AP as amended by the 2026-07-13
/// founder exemplar, engine docs/LEVELS_LAW.md): the level name LEADS and the
/// zone code follows as a secondary detail — legal because it is nested, never
/// alone. (The bare-name form shipped in #180 predates the amendment; #406
/// made nested-code the canonical shape.) REST has no code to nest.
String zoneDisplayLabel(String zone) {
  final upperZone = zone.toUpperCase();
  if (upperZone == 'REST') return 'Rest day';
  final (name, _) = zoneDisplayNameAndColor(zone);
  // Unknown zone → fail-visible: the raw code once, never a fabricated
  // "CODE · CODE" pair; the engine only emits canonical zones on this path.
  if (name == zone) return zone;
  return '$name · $upperZone';
}

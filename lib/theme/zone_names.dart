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
/// LEVELS LAW (founder 2026-07-10, DECISIONS Entry AP): athlete-facing surfaces
/// speak the level name only, never the raw zone code. This SUPERSEDES the
/// older SR1-07 "Tempo · Z3" ruling — the code suffix is gone (see
/// [zoneDisplayLabel]). The engine mapping stays the same; only what the
/// athlete sees changes.
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

/// Formats a zone for athlete display: the level name only ("Tempo").
///
/// LEVELS LAW (Entry AP, supersedes SR1-07): NO raw zone-code suffix. The zone
/// code stays internal; the athlete sees only what the work is.
String zoneDisplayLabel(String zone) {
  final upperZone = zone.toUpperCase();
  if (upperZone == 'REST') return 'Rest day';
  final (name, _) = zoneDisplayNameAndColor(zone);
  // Unknown zone → fail-visible (return the raw code) rather than a fabricated
  // level name; the engine only emits canonical zones on this path.
  return name;
}

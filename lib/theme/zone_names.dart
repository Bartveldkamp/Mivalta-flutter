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
/// Energy name comes first per SR1-07 ruling ("Tempo · Z3", never bare "Z3").
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

/// Formats zone for full display: "Tempo · Z3" (energy name first).
String zoneDisplayLabel(String zone) {
  final upperZone = zone.toUpperCase();
  if (upperZone == 'REST') return 'Rest day';
  final (name, _) = zoneDisplayNameAndColor(zone);
  // If unknown zone, just return as-is
  if (name == zone) return zone;
  return '$name · $upperZone';
}

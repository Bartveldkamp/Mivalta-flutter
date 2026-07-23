// Zone display — the athlete-facing rendering of an engine zone code.
//
// LEVELS LAW (founder 2026-07-18, Option 1): the athlete vocabulary is the
// engine's SIX metabolic levels ONLY — the words come from
// `kMetabolicLevelLabels` (lib/copy/level_labels.dart), the Dart render of the
// engine's `gatc_types::METABOLIC_LEVEL_LABELS` single source of truth. The
// level LEADS; the zone code rides NESTED behind it ("Aerobic endurance · Z2").
// There is exactly ONE athlete vocabulary in the app now — the former per-zone
// words (Recovery/Endurance/Anaerobic/Neuromuscular/Max power) and the divergent
// copy/zone_labels.dart are removed. Z6/Z7/Z8 all read "Anaerobic / neuro".
//
// The zone→level correspondence below mirrors the engine's
// `MetabolicLevel::classify` (R/Z1→base, Z2→endurance, Z3→tempo, Z4→threshold,
// Z5→VO₂max, Z6/Z7/Z8→anaerobic/neuro) — a fixed structural map, NOT a
// computation. Dart never authors a level word; it looks the label up from the
// engine-owned list. This carving is the DRIFT GUARD's subject: every zone→level
// pairing is pinned to the engine in test/zone_names_test.dart, so a Dart mirror
// that diverges from `classify` fails CI.
//
// SINGLE SOURCE (universal-model alignment, 2026-07-23): this file is the ONE
// Dart zone-display source — both the metabolic-level LABEL and the zone COLOUR.
// The former divergent `zoneColor()` in theme/tokens.dart (dead, and disagreeing
// on several bands) was removed; do not reintroduce a second zone→colour or
// zone→level map anywhere in Dart.

import 'package:flutter/material.dart';
import '../copy/level_labels.dart';
import 'tokens.dart';

/// Zone code → (engine metabolic-level id, colour). The colour is the state
/// scale used as an intensity ramp (see tokens.dart), not a separate palette.
(String, Color) _zoneLevelIdAndColor(String zone) {
  return switch (zone.toUpperCase()) {
    'R' || 'Z1' => ('aerobic_base', MivaltaColors.stateProductive),
    'Z2' => ('aerobic_endurance', MivaltaColors.stateProductive),
    'Z3' => ('tempo', MivaltaColors.stateProductive),
    'Z4' => ('threshold', MivaltaColors.stateAccumulated),
    'Z5' => ('vo2max', MivaltaColors.stateAccumulated),
    'Z6' || 'Z7' || 'Z8' => ('anaerobic_neuro', MivaltaColors.levelRed),
    _ => ('', MivaltaColors.textSecondary),
  };
}

/// The athlete-facing label for an engine level id, from the single engine-owned
/// list. Empty when the id is unknown (fail-visible, never a fabricated word).
String _labelForLevelId(String id) {
  for (final (levelId, label) in kMetabolicLevelLabels) {
    if (levelId == id) return label;
  }
  return '';
}

/// Returns (metabolic-level label, colour) for a zone code — the 6-level
/// vocabulary, engine-owned words. Rest days render a plain day word (not a
/// training intensity); an unknown zone shows the raw code (fail-visible).
(String, Color) zoneDisplayNameAndColor(String zone) {
  final upperZone = zone.toUpperCase();
  if (upperZone == 'REST' || upperZone == 'OFF') {
    return ('Rest day', MivaltaColors.textSecondary);
  }
  final (levelId, color) = _zoneLevelIdAndColor(zone);
  final label = _labelForLevelId(levelId);
  if (label.isEmpty) return (zone, MivaltaColors.textSecondary); // unknown → raw
  return (label, color);
}

/// Formats a zone for athlete display: the metabolic level LEADING, the zone
/// code NESTED ("Aerobic endurance · Z2"). LEVELS LAW communication shape.
/// REST/OFF have no code to nest; an unknown zone fails visible (raw code once,
/// never a fabricated "CODE · CODE" pair).
String zoneDisplayLabel(String zone) {
  final upperZone = zone.toUpperCase();
  if (upperZone == 'REST' || upperZone == 'OFF') return 'Rest day';
  final (name, _) = zoneDisplayNameAndColor(zone);
  if (name == zone) return zone;
  return '$name · $upperZone';
}

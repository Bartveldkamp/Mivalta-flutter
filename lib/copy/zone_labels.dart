// Consumer-facing labels for the engine's training zones (F-ZONE, founder
// 2026-06-15). Pure label layer — engine zone string in → fixed consumer copy
// out — exactly the sanctioned pattern in HOME_REDESIGN_BRIEF.md §2/§5
// (raw Z1–Z8 codes are FORBIDDEN on user surfaces). Nothing here computes,
// thresholds, or re-derives; the engine still owns the zone itself.
//
// Naming rule (founder check 2026-06-15): label each zone by the ENERGY SYSTEM
// the engine assigns it (`energy_systems:zone_map` primary_system /
// `josi_explanations:zone_purpose_rules`), NOT by mapping the zone NUMBER to the
// Coggan ladder. MiValta's engine numbering is shifted vs Coggan (the engine
// puts VO2max at Z4/Z5, threshold at Z3), so naming by number would print a word
// that contradicts what the engine computed. Naming by system keeps the label
// physiologically true and collapses to the 6 canonical energy systems:
//
//   R      → Recovery     (recovery)
//   Z1, Z2 → Endurance    (endurance)
//   Z3     → Threshold    (steady_state_threshold)
//   Z4, Z5 → VO2 Max      (aerobic_power)
//   Z6     → Anaerobic    (anaerobic_power)
//   Z7, Z8 → Sprint       (neuromuscular)

/// Engine zone code (e.g. "Z4", "R") → consumer energy-system label (e.g.
/// "VO2 Max"), matching the system the engine assigns the zone. Case-insensitive.
/// Unknown/empty → null so callers render honest absence rather than a raw code
/// (never show "Z?" to a user).
String? zoneLabel(String? zone) {
  switch ((zone ?? '').trim().toUpperCase()) {
    case 'R':
      return 'Recovery';
    case 'Z1':
    case 'Z2':
      return 'Endurance';
    case 'Z3':
      return 'Threshold';
    case 'Z4':
    case 'Z5':
      return 'VO2 Max';
    case 'Z6':
      return 'Anaerobic';
    case 'Z7':
    case 'Z8':
      return 'Sprint';
    default:
      return null;
  }
}

/// Zone-cap phrasing for the readiness "what's available today" chip, e.g.
/// zone cap "Z8" → "Up to Sprint", "R" → "Recovery only". Null when the engine
/// gave a code we have no label for (caller omits the chip).
String? zoneCapLabel(String? zone) {
  final label = zoneLabel(zone);
  if (label == null) return null;
  if ((zone ?? '').trim().toUpperCase() == 'R') return 'Recovery only';
  return 'Up to $label';
}

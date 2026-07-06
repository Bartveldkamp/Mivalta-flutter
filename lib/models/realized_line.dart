// Display-side parse model for the engine's RealizedLine — the deterministic
// Josi voice line produced by `gatc_ffi::realize_*` seams and couriered across
// the FFI as JSON.
//
// Four voice surfaces (V6):
//   S1: realize_workout_reflection — post-workout reaction
//   S2: realize_advisor_line — state/readiness reaction (Today headline)
//   S3: realize_advisory_offer — advisor offer line + why/purpose disclosure
//   S4: realize_day_summary — end-of-day summary
//
// DISPLAY ONLY (architecture rule 3): this parses the engine's output; it
// computes nothing, substitutes no slot, formats no number, and never branches
// logic on the safety items. The fidelity firewall already ran IN RUST — Flutter
// renders `text` and `safety` verbatim.

import 'dart:convert';

class RealizedLine {
  const RealizedLine({
    required this.text,
    required this.safety,
    required this.degraded,
    this.degradeReason,
    this.why,
    this.purpose,
  });

  /// The firewall-validated Josi line — rendered verbatim as the headline.
  final String text;

  /// Engine-owned verbatim safety cautions. Rendered as-is, ALWAYS, never
  /// branched on or softened — the firewall preserved them; the surface honors
  /// that.
  final List<String> safety;

  /// True when the engine degraded to its plain render (a card line could not be
  /// faithfully filled). Informational only — `text` is still engine-truth.
  final bool degraded;

  /// Telemetry only — NEVER shown to user. Explains why the line degraded.
  final String? degradeReason;

  /// The readiness-aware reason for this workout (S3 disclosure).
  /// Card-templated, from the option itself.
  final String? why;

  /// What the prescribed zone trains (S3 disclosure).
  /// From `coach_cues:zone_purpose`.
  final String? purpose;

  factory RealizedLine.fromJson(Map<String, dynamic> json) {
    final rawSafety = json['safety'];
    return RealizedLine(
      text: json['text'] as String? ?? '',
      safety: rawSafety is List
          ? rawSafety.map((e) => e.toString()).toList(growable: false)
          : const <String>[],
      degraded: json['degraded'] as bool? ?? false,
      degradeReason: json['degrade_reason'] as String?,
      why: json['why'] as String?,
      purpose: json['purpose'] as String?,
    );
  }

  /// Parse from the raw JSON string the facade returns.
  static RealizedLine parse(String jsonStr) =>
      RealizedLine.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
}

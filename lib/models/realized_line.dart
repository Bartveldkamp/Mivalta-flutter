// Display-side parse model for the engine's RealizedLine — the deterministic
// Josi ADVISOR line produced by `gatc_ffi::realize_advisor_line` and couriered
// across the FFI as JSON.
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

  factory RealizedLine.fromJson(Map<String, dynamic> json) {
    final rawSafety = json['safety'];
    return RealizedLine(
      text: json['text'] as String? ?? '',
      safety: rawSafety is List
          ? rawSafety.map((e) => e.toString()).toList(growable: false)
          : const <String>[],
      degraded: json['degraded'] as bool? ?? false,
    );
  }

  /// Parse from the raw JSON string the facade returns.
  static RealizedLine parse(String jsonStr) =>
      RealizedLine.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
}

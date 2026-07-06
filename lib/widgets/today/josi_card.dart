// Josi Card — the unified voice presenter (BS-016 B0).
//
// One renderer for all four voice surfaces (S1–S4). LOCKED rules:
// - text VERBATIM — no interpolation, no truncation, no case changes
// - safety[] always rendered, never collapsed, never decorative
// - degraded==true renders IDENTICALLY (no badge, no suffix, no error styling)
// - Josi is a PRESENTER — text only, no chat, no input, no TTS
//
// Callers: Today (S2 state headline), Reveal/workout detail (S1 reflection),
// Advisor (S3 offer), Today evening + Journey (S4 day summary).

import 'package:flutter/material.dart';

import '../../models/realized_line.dart';
import '../../theme/tokens.dart';

/// The Josi card — unified voice presenter per BS-016 B0.
class JosiCard extends StatelessWidget {
  const JosiCard({
    super.key,
    this.realizedLine,
    this.fallbackLine,
    this.confidenceAdvisory,
    this.showNumbers = false,
  });

  /// The realized line from the engine — primary source.
  /// Contains text, safety[], degraded (ignored for styling), why, purpose.
  final RealizedLine? realizedLine;

  /// Fallback: the state_recommendation line (pre-voice-surfaces behaviour).
  /// Used when realizedLine is absent or empty.
  final String? fallbackLine;

  /// BS-008 P-4: Confidence advisory sub-line from engine.
  /// Only rendered when showNumbers is true.
  final String? confidenceAdvisory;

  /// BS-008 P-4: Whether to show the confidence advisory (onboarding_detail = 'numbers').
  final bool showNumbers;

  /// Resolve the display line: realized → fallback → null.
  String? get _displayLine {
    if (realizedLine != null && realizedLine!.text.isNotEmpty) {
      return realizedLine!.text;
    }
    return fallbackLine;
  }

  /// Safety lines to render (from realized line).
  List<String> get _safetyLines => realizedLine?.safety ?? const [];

  @override
  Widget build(BuildContext context) {
    final line = _displayLine;
    if (line == null || line.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(MivaltaSpace.x4),
      decoration: BoxDecoration(
        color: MivaltaColors.surface1,
        border: Border.all(color: MivaltaColors.cardBorder),
        borderRadius: BorderRadius.circular(MivaltaRadii.lg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Josi avatar dot (26px gradient treatment)
          _buildJosiAvatar(),
          const SizedBox(width: MivaltaSpace.x3),
          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Main line — VERBATIM, no parsing
                Text(
                  line,
                  style: MivaltaType.body.copyWith(
                    color: MivaltaColors.textSecondary,
                    height: 1.55,
                  ),
                ),

                // Safety lines (if any) — always rendered, never collapsed
                if (_safetyLines.isNotEmpty) ...[
                  const SizedBox(height: MivaltaSpace.x2),
                  ..._safetyLines.map(_buildSafetyLine),
                ],

                // BS-008 P-4: Confidence advisory (only when showNumbers = true)
                if (showNumbers &&
                    confidenceAdvisory != null &&
                    confidenceAdvisory!.isNotEmpty) ...[
                  const SizedBox(height: MivaltaSpace.x2),
                  Text(
                    confidenceAdvisory!,
                    style: MivaltaType.small.copyWith(
                      color: MivaltaColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Josi avatar — 26px gradient dot (existing treatment from auth/promise).
  Widget _buildJosiAvatar() {
    return Container(
      width: 26,
      height: 26,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            MivaltaColors.primaryGreen,
            MivaltaColors.tertiaryTealSolid,
          ],
        ),
      ),
    );
  }

  /// Safety line — textSecondary (NOT muted — always legible), no icon, no collapse.
  Widget _buildSafetyLine(String safety) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        safety,
        style: MivaltaType.small.copyWith(
          color: MivaltaColors.textSecondary,
        ),
      ),
    );
  }
}

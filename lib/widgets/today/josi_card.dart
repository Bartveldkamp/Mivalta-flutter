// Josi Card — the state-grounded Josi line.
//
// BS-007: Primary source is realize_advisor_line → RealizedLine {text, safety[], degraded}.
// Falls back to state_recommendation when the realizer is absent or empty.
// Josi is a PRESENTER (locked, founder 2026-06-12) — she renders as text, no chat, no TTS.

import 'package:flutter/material.dart';

import '../../models/realized_line.dart';
import '../../theme/tokens.dart';

/// The Josi card — state recommendation rendered as text.
class JosiCard extends StatelessWidget {
  const JosiCard({
    super.key,
    this.realizedLine,
    this.fallbackLine,
    this.confidenceAdvisory,
    this.showNumbers = false,
  });

  /// BS-007: The realized advisor line from the engine — primary source.
  /// Contains text, safety[], and degraded flag.
  final RealizedLine? realizedLine;

  /// Fallback: the state_recommendation line (pre-BS-007 behaviour).
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

  /// Whether to show " · limited read" suffix (degraded flag).
  bool get _isDegraded => realizedLine?.degraded ?? false;

  /// Safety lines to render (from realized line).
  List<String> get _safetyLines => realizedLine?.safety ?? const [];

  @override
  Widget build(BuildContext context) {
    final line = _displayLine;
    if (line == null || line.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MivaltaColors.surface1.withValues(alpha: 0.03),
        border: Border.all(
          color: MivaltaColors.textPrimary.withValues(alpha: 0.08),
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Eyebrow
          Row(
            children: [
              Icon(
                Icons.auto_awesome,
                size: 18,
                color: MivaltaColors.stateProductive,
              ),
              const SizedBox(width: 9),
              Text(
                'JOSI',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                  color: MivaltaColors.textPrimary.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),

          // Main line with optional " · limited read" suffix
          _buildMainLine(line),

          // Safety lines (if any)
          if (_safetyLines.isNotEmpty) ...[
            const SizedBox(height: 8),
            ..._safetyLines.map(_buildSafetyLine),
          ],

          // BS-008 P-4: Confidence advisory (only when showNumbers = true)
          if (showNumbers && confidenceAdvisory != null && confidenceAdvisory!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              confidenceAdvisory!,
              style: MivaltaType.small.copyWith(
                color: MivaltaColors.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Main line with bolded key phrase and optional degraded suffix.
  Widget _buildMainLine(String text) {
    // Parse **bold** markdown and render as rich text
    final spans = <InlineSpan>[];
    final regex = RegExp(r'\*\*(.+?)\*\*');
    var lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: MivaltaColors.stateRecovered,
        ),
      ));
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    // Add degraded suffix if needed
    if (_isDegraded) {
      spans.add(TextSpan(
        text: ' · limited read',
        style: TextStyle(
          fontWeight: FontWeight.w400,
          color: MivaltaColors.textMuted,
        ),
      ));
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 15,
          height: 1.45,
          color: MivaltaColors.textPrimary,
        ),
        children: spans.isEmpty ? [TextSpan(text: text)] : spans,
      ),
    );
  }

  /// Safety line — rendered in accumulated (steady caution) color.
  Widget _buildSafetyLine(String safety) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        safety,
        style: MivaltaType.small.copyWith(
          color: MivaltaColors.stateAccumulated,
        ),
      ),
    );
  }
}

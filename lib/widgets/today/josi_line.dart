// JosiLine — Josi's one-line read with avatar.
// Per Today-Modular.html: avatar circle + prose text with optional bold emphasis.
// Josi is a PRESENTER, not a chatbox — tap reveals the "why", no conversation.
//
// The text comes from the engine's realizedLine (deterministic, firewall-validated)
// or falls back to state_recommendation. Engine-computed; Dart only renders.

import 'package:flutter/material.dart';

import '../../models/realized_line.dart';
import '../../theme/tokens.dart';

/// Josi's one-line verdict on the Today screen.
///
/// Shows an avatar circle with the auto_awesome icon, followed by the realized
/// line text. When [realizedLine] is provided, it renders with proper bold
/// emphasis. Falls back to [fallbackText] when no realized line is available.
class JosiLine extends StatelessWidget {
  const JosiLine({
    super.key,
    this.realizedLine,
    this.fallbackText,
    this.onTapWhy,
    this.showWhyButton = true,
  });

  /// The engine-realized line with text and safety status.
  final RealizedLine? realizedLine;

  /// Fallback text when realizedLine is unavailable.
  final String? fallbackText;

  /// Callback when "Why?" is tapped (reveals the reasoning).
  final VoidCallback? onTapWhy;

  /// Whether to show the "Why?" button.
  final bool showWhyButton;

  /// Get the text to display (realized line or fallback).
  String get _text => realizedLine?.text ?? fallbackText ?? '';

  @override
  Widget build(BuildContext context) {
    if (_text.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(MivaltaSpace.x4),
      decoration: BoxDecoration(
        color: MivaltaColors.cardBackground,
        border: Border.all(color: MivaltaColors.cardBorder),
        borderRadius: BorderRadius.circular(MivaltaRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with icon and label
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
                style: MivaltaTextStyles.cardHeader(),
              ),
            ],
          ),
          const SizedBox(height: 9),
          // The prose line
          _buildJosiText(),
          // Why button
          if (showWhyButton && onTapWhy != null) ...[
            const SizedBox(height: MivaltaSpace.x2),
            GestureDetector(
              onTap: onTapWhy,
              child: Text(
                'Why?',
                style: MivaltaTextStyles.small(
                  color: MivaltaColors.textMuted,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build the Josi text with bold emphasis for parts wrapped in <b></b>.
  Widget _buildJosiText() {
    final text = _text;

    // Parse bold tags (simplified: split on <b> and </b>)
    final parts = <TextSpan>[];
    final pattern = RegExp(r'<b>(.*?)</b>');
    var lastEnd = 0;

    for (final match in pattern.allMatches(text)) {
      // Add text before the match
      if (match.start > lastEnd) {
        parts.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: MivaltaTextStyles.josiLine(),
        ));
      }
      // Add the bold text
      parts.add(TextSpan(
        text: match.group(1),
        style: MivaltaTextStyles.josiEmphasis(),
      ));
      lastEnd = match.end;
    }

    // Add remaining text
    if (lastEnd < text.length) {
      parts.add(TextSpan(
        text: text.substring(lastEnd),
        style: MivaltaTextStyles.josiLine(),
      ));
    }

    // If no bold tags found, just show plain text
    if (parts.isEmpty) {
      return Text(
        text,
        style: MivaltaTextStyles.josiLine(),
      );
    }

    return RichText(
      text: TextSpan(children: parts),
    );
  }
}

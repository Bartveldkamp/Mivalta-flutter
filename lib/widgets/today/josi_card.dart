// Josi Card — the state-grounded Josi line.
//
// Per Today-Modular.html: "JOSI" eyebrow + the state_recommendation line
// with bolded key phrase. Josi is a PRESENTER (locked, founder 2026-06-12) —
// she renders as text, no chat, no TTS.

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// The Josi card — state recommendation rendered as text.
class JosiCard extends StatelessWidget {
  const JosiCard({
    super.key,
    required this.line,
  });

  /// The state_recommendation line from the engine. May contain **bold**
  /// markdown fragments for the key phrase.
  final String? line;

  @override
  Widget build(BuildContext context) {
    if (line == null || line!.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MivaltaColors.surface1.withValues(alpha:0.03),
        border: Border.all(
          color: MivaltaColors.textPrimary.withValues(alpha:0.08),
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
                  color: MivaltaColors.textPrimary.withValues(alpha:0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          // Line with bolded key phrase
          _buildRichLine(line!),
        ],
      ),
    );
  }

  /// Parse simple **bold** markdown and render as rich text.
  Widget _buildRichLine(String text) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'\*\*(.+?)\*\*');
    var lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      // Text before the match
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      // The bolded text
      spans.add(TextSpan(
        text: match.group(1),
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: MivaltaColors.stateRecovered, // #7FE3B0 per design
        ),
      ));
      lastEnd = match.end;
    }
    // Remaining text
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
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
}

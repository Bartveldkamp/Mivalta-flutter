// PR-B: Calm readiness hero ring. All inputs come verbatim from
// ViterbiEngine.readiness_indicator(); this widget renders, never computes.
//
// The ring color is determined by the engine's LEVEL field, not by
// re-deriving from the score. Display-only — no thresholds in Dart.
//
// PR-C: Migrated to tokens-only (no inline Colors/hex). Color flows through
// readinessLevelColor() from tokens.dart.
//
// Step 2 (HOME_REDESIGN_BRIEF §4): the state element is SIZED BY DATA
// SUFFICIENCY. While the engine is still calibrating ([learning]) the ring
// renders small (~120dp) and muted; the full 220dp hero with level color,
// level label, and confidence row appears only when the engine is confident.
// The learning gate is computed by the CALLER from engine signals only
// (insufficient data OR a non-empty confidence_advisory) — never a Dart
// threshold on the confidence scalar.

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Calm readiness state element. All inputs come verbatim from
/// ViterbiEngine.readiness_indicator(); this widget renders, never computes.
class ReadinessRing extends StatelessWidget {
  const ReadinessRing({
    super.key,
    required this.score,      // indicator['score'] as num, rounded; null = no data
    required this.level,      // indicator['level'] verbatim; drives color
    required this.confidence, // indicator['confidence'] 0..1
    required this.noData,
    required this.learning,
  });

  final int? score;
  final String? level;
  final double? confidence;
  final bool noData;

  /// Engine still calibrating (brief §4 sizing gate, computed by the caller
  /// from engine signals only): render the small muted ring, not the hero.
  final bool learning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Sizing by data sufficiency: small while learning, full hero when
    // confident. Pure presentation of an engine-signalled state.
    final double dimension = learning ? 120 : 220;
    final double stroke = learning ? 8 : 14;
    final TextStyle? centerStyle = learning
        ? theme.textTheme.headlineMedium
        : theme.textTheme.displayLarge;

    if (noData) {
      // No-data state (founder 2026-06-12 no-data redesign): the ring renders
      // in its CALM muted state — empty track, quiet em-dash, no color, no
      // fabricated score. The LOCKED F1 copy is carried by Josi's card and
      // must appear exactly ONCE on the home, so it does NOT repeat here.
      // Never bare floating text as the hero.
      return SizedBox(
        width: dimension,
        height: dimension,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: dimension,
              height: dimension,
              child: CircularProgressIndicator(
                value: 0, // nothing to claim — track only, no arc
                strokeWidth: stroke,
                backgroundColor:
                    MivaltaColors.textMuted.withValues(alpha: 0.15),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  MivaltaColors.textMuted,
                ),
              ),
            ),
            Text(
              '—',
              style: centerStyle?.copyWith(color: MivaltaColors.textMuted),
            ),
          ],
        ),
      );
    }

    if (learning) {
      // Learning state (brief §4): data exists but the engine says it is
      // still calibrating. Small muted ring — the engine's score renders
      // (visual + number, §9 no-naked-numbers), but in the muted palette:
      // no level color claimed, no level label, no confidence row, until
      // the engine is confident.
      return SizedBox(
        width: dimension,
        height: dimension,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: dimension,
              height: dimension,
              child: CircularProgressIndicator(
                value: (score ?? 0) / 100.0,
                strokeWidth: stroke,
                backgroundColor:
                    MivaltaColors.textMuted.withValues(alpha: 0.15),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  MivaltaColors.textMuted,
                ),
              ),
            ),
            Text(
              '${score ?? '—'}',
              style: centerStyle?.copyWith(color: MivaltaColors.textMuted),
            ),
          ],
        ),
      );
    }

    // Color is chosen by the engine's LEVEL via tokens — never re-derived from score.
    final color = readinessLevelColor(level);
    return SizedBox(
      width: dimension,
      height: dimension,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: dimension,
            height: dimension,
            child: CircularProgressIndicator(
              value: (score ?? 0) / 100.0,
              strokeWidth: stroke,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${score ?? '—'}',
                style: theme.textTheme.displayLarge?.copyWith(color: color),
              ),
              Text(level ?? '—', style: theme.textTheme.titleMedium),
              if (confidence != null)
                Text(
                  'confidence ${(confidence! * 100).round()}%',
                  style: theme.textTheme.bodySmall,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// PR-B: Calm readiness hero ring. All inputs come verbatim from
// ViterbiEngine.readiness_indicator(); this widget renders, never computes.
//
// The ring color is determined by the engine's LEVEL field, not by
// re-deriving from the score. Display-only — no thresholds in Dart.
//
// PR-C: Migrated to tokens-only (no inline Colors/hex). Color flows through
// readinessLevelColor() from tokens.dart.

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Calm readiness hero. All inputs come verbatim from
/// ViterbiEngine.readiness_indicator(); this widget renders, never computes.
class ReadinessRing extends StatelessWidget {
  const ReadinessRing({
    super.key,
    required this.score,      // indicator['score'] as num, rounded; null = no data
    required this.level,      // indicator['level'] verbatim; drives color
    required this.confidence, // indicator['confidence'] 0..1
    required this.noData,
  });

  final int? score;
  final String? level;
  final double? confidence;
  final bool noData;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (noData) {
      // No-data hero (founder 2026-06-12 no-data redesign): the ring renders
      // in its CALM muted state — empty track, quiet em-dash, no color, no
      // fabricated score. The LOCKED F1 copy is carried by Josi's card and
      // must appear exactly ONCE on the home, so it does NOT repeat here.
      // Never bare floating text as the hero.
      return SizedBox(
        width: 220,
        height: 220,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 220,
              height: 220,
              child: CircularProgressIndicator(
                value: 0, // nothing to claim — track only, no arc
                strokeWidth: 14,
                backgroundColor:
                    MivaltaColors.textMuted.withValues(alpha: 0.15),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  MivaltaColors.textMuted,
                ),
              ),
            ),
            Text(
              '—',
              style: theme.textTheme.displayLarge
                  ?.copyWith(color: MivaltaColors.textMuted),
            ),
          ],
        ),
      );
    }
    // Color is chosen by the engine's LEVEL via tokens — never re-derived from score.
    final color = readinessLevelColor(level);
    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 220,
            height: 220,
            child: CircularProgressIndicator(
              value: (score ?? 0) / 100.0,
              strokeWidth: 14,
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

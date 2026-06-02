// PR-B: Calm readiness hero ring. All inputs come verbatim from
// ViterbiEngine.readiness_indicator(); this widget renders, never computes.
//
// The ring color is determined by the engine's LEVEL field, not by
// re-deriving from the score. Display-only — no thresholds in Dart.

import 'package:flutter/material.dart';

import '../copy/f1.dart';

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

  // Color is chosen by the engine's LEVEL, not by the UI re-deriving from score.
  Color _levelColor(BuildContext ctx) {
    switch ((level ?? '').toLowerCase()) {
      case 'green':
        return const Color(0xFF2BD974);
      case 'yellow':
        return const Color(0xFFE8C547);
      case 'orange':
        return const Color(0xFFE6872F);
      case 'red':
        return const Color(0xFFE5484D);
      default:
        return Theme.of(ctx).colorScheme.outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (noData) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          kF1NoDataCopy, // LOCKED F1 copy
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
      );
    }
    final color = _levelColor(context);
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

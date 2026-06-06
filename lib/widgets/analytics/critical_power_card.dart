// Critical Power card — Monitor analytics, next-gen UI.
//
// Display-only (UI_UX_DIRECTION §2.1 insight-first): the meaning sentence on
// top, the numbers below. CP is the headline; W′ (reserve) and the fit quality
// sit underneath. Every value engine-computed; omitted/empty when absent.

import 'package:flutter/material.dart';

import '../../models/critical_power.dart';
import '../../theme/tokens.dart';

class CriticalPowerCard extends StatelessWidget {
  const CriticalPowerCard({super.key, required this.cp});

  final CriticalPower cp;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(MivaltaSpace.x4),
      decoration: BoxDecoration(
        color: MivaltaColors.surface1,
        borderRadius: BorderRadius.circular(MivaltaRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CRITICAL POWER',
            style: textTheme.labelSmall?.copyWith(
              letterSpacing: 1.2,
              color: MivaltaColors.textMuted,
            ),
          ),
          const SizedBox(height: MivaltaSpace.x2),

          if (cp.isEmpty)
            Text(
              'No power data yet.',
              style: textTheme.bodyMedium?.copyWith(color: MivaltaColors.textMuted),
            )
          else ...[
            // Insight-first: the meaning, then the number.
            Text(
              'The highest power you can hold — and your reserve above it.',
              style: textTheme.bodyMedium?.copyWith(color: MivaltaColors.textSecondary),
            ),
            const SizedBox(height: MivaltaSpace.x4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${cp.cpWatts.round()}',
                  style: textTheme.displaySmall?.copyWith(
                    color: MivaltaColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: MivaltaSpace.x1),
                Padding(
                  padding: const EdgeInsets.only(bottom: MivaltaSpace.x1),
                  child: Text(
                    'W',
                    style: textTheme.titleMedium?.copyWith(color: MivaltaColors.textMuted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: MivaltaSpace.x4),
            Wrap(
              spacing: MivaltaSpace.x6,
              runSpacing: MivaltaSpace.x4,
              children: [
                _Metric('Reserve (W′)', '${cp.wPrimeKj.toStringAsFixed(1)} kJ'),
                _Metric('Fit', 'r² ${cp.rSquared.toStringAsFixed(2)}'),
                _Metric('From', '${cp.nPoints} points'),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: textTheme.labelSmall?.copyWith(color: MivaltaColors.textMuted)),
        const SizedBox(height: 2),
        Text(
          value,
          style: textTheme.titleMedium?.copyWith(
            color: MivaltaColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

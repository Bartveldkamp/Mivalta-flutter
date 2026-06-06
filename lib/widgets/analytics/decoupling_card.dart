// Aerobic decoupling card — Monitor analytics, next-gen UI.
//
// Display-only (UI_UX §2.5 opaque data surface). Shows the engine's trailing
// 7/14/28-day HR-decoupling means side by side. Each value is engine-computed;
// this widget formats and labels them — no thresholds or math in Dart.

import 'package:flutter/material.dart';

import '../../models/decoupling_trend.dart';
import '../../theme/tokens.dart';

class DecouplingCard extends StatelessWidget {
  const DecouplingCard({super.key, required this.trend});

  final DecouplingTrend trend;

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
            'Aerobic decoupling',
            style: textTheme.titleMedium?.copyWith(
              color: MivaltaColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: MivaltaSpace.x1),
          Text(
            'HR drift over a steady effort — lower is more durable.',
            style: textTheme.bodySmall?.copyWith(color: MivaltaColors.textMuted),
          ),
          const SizedBox(height: MivaltaSpace.x3),
          if (!trend.hasData)
            Text(
              'No aerobic decoupling readings yet.',
              style: textTheme.bodyMedium?.copyWith(color: MivaltaColors.textMuted),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _Readout(label: '7-day', pct: trend.short, textTheme: textTheme),
                _Readout(label: '14-day', pct: trend.mid, textTheme: textTheme),
                _Readout(label: '28-day', pct: trend.long, textTheme: textTheme),
              ],
            ),
        ],
      ),
    );
  }
}

class _Readout extends StatelessWidget {
  const _Readout({required this.label, required this.pct, required this.textTheme});

  final String label;
  final double? pct;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          pct == null ? '—' : '${pct!.toStringAsFixed(1)}%',
          style: textTheme.titleLarge?.copyWith(
            color: pct == null ? MivaltaColors.textMuted : MivaltaColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: MivaltaSpace.x1),
        Text(
          label,
          style: textTheme.labelSmall?.copyWith(color: MivaltaColors.textMuted),
        ),
      ],
    );
  }
}

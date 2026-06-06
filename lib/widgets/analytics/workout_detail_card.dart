// Workout Detail card — Monitor analytics, next-gen UI.
//
// Display-only (UI_UX §2.1 insight-first). Grade + sport/date on top, then the
// metric grid (duration, power/pace, HR, decoupling, efficiency, zone
// compliance). Every value engine-computed; numbers verbatim, omitted if absent.

import 'package:flutter/material.dart';

import '../../models/workout_detail.dart';
import '../../theme/tokens.dart';

class WorkoutDetailCard extends StatelessWidget {
  const WorkoutDetailCard({super.key, required this.detail});

  final WorkoutDetail detail;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final metrics = <_MetricCell>[
      if (detail.durationMin != null)
        _MetricCell('Duration', '${detail.durationMin} min'),
      if (detail.avgWatts != null) _MetricCell('Avg power', '${detail.avgWatts}W'),
      if (detail.avgPaceMss != null) _MetricCell('Avg pace', detail.avgPaceMss!),
      if (detail.avgHr != null) _MetricCell('Avg HR', '${detail.avgHr} bpm'),
      if (detail.decouplingPct != null)
        _MetricCell('Decoupling', '${detail.decouplingPct!.toStringAsFixed(1)}%'),
      if (detail.efficiencyFactor != null)
        _MetricCell('Efficiency', detail.efficiencyFactor!.toStringAsFixed(2)),
      if (detail.zoneCompliancePct != null)
        _MetricCell('Zone match', '${detail.zoneCompliancePct!.round()}%'),
    ];

    return Container(
      padding: const EdgeInsets.all(MivaltaSpace.x4),
      decoration: BoxDecoration(
        color: MivaltaColors.surface1,
        borderRadius: BorderRadius.circular(MivaltaRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Insight-first header: grade + sport/date.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  detail.sport.isEmpty ? 'Workout' : _titleCase(detail.sport),
                  style: textTheme.titleMedium?.copyWith(
                    color: MivaltaColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (detail.grade != null && detail.grade!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: MivaltaSpace.x2,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _gradeColor(detail.grade!).withAlpha(40),
                    borderRadius: BorderRadius.circular(MivaltaRadii.sm),
                  ),
                  child: Text(
                    detail.grade!,
                    style: textTheme.labelSmall?.copyWith(
                      color: _gradeColor(detail.grade!),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          if (detail.date.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              detail.date,
              style: textTheme.labelSmall?.copyWith(color: MivaltaColors.textMuted),
            ),
          ],
          const SizedBox(height: MivaltaSpace.x4),

          if (metrics.isEmpty)
            Text(
              'No metrics for this workout.',
              style: textTheme.bodyMedium?.copyWith(color: MivaltaColors.textMuted),
            )
          else
            Wrap(
              spacing: MivaltaSpace.x6,
              runSpacing: MivaltaSpace.x4,
              children: metrics,
            ),
        ],
      ),
    );
  }

  static String _titleCase(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  /// Engine decides the grade; this only maps it to the semantic palette.
  static Color _gradeColor(String grade) => switch (grade.toLowerCase()) {
        'excellent' => MivaltaColors.levelGreen,
        'good' => MivaltaColors.stateProductive,
        'fair' => MivaltaColors.levelYellow,
        'poor' => MivaltaColors.levelOrange,
        _ => MivaltaColors.textMuted,
      };
}

class _MetricCell extends StatelessWidget {
  const _MetricCell(this.label, this.value);
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

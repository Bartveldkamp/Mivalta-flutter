// Post-Workout Report card — Advisory, next-gen UI.
//
// Display-only (UI_UX_DIRECTION §2.1 insight-first, v1.4 Advisory = present-and-
// offer over bounded engine output). Leads with what the session built (the
// meaning), then the engine's quality summary and the stimulus/cost note, with
// sport/zone/duration context. Every string is engine/card-sourced; fields
// absent on the report are simply omitted (no fabrication).

import 'package:flutter/material.dart';

import '../../models/workout_report.dart';
import '../../theme/tokens.dart';

class PostWorkoutReportCard extends StatelessWidget {
  const PostWorkoutReportCard({super.key, required this.report});

  final WorkoutReport report;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final context_ = <String>[
      if (report.durationMin > 0) '${report.durationMin.round()} min',
      if (report.avgHr != null) '${report.avgHr} bpm avg',
      if (report.rpe != null) 'RPE ${report.rpe}',
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
          // Header: label + sport/date + zone badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'POST-WORKOUT REPORT',
                style: textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.2,
                  color: MivaltaColors.textMuted,
                ),
              ),
              if (report.zone.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: MivaltaSpace.x2,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: MivaltaColors.primaryGreen.withAlpha(40),
                    borderRadius: BorderRadius.circular(MivaltaRadii.sm),
                  ),
                  child: Text(
                    report.zone,
                    style: textTheme.labelSmall?.copyWith(
                      color: MivaltaColors.primaryGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: MivaltaSpace.x2),

          // Sport · date · context metrics
          Text(
            [
              if (report.sport.isNotEmpty) _titleCase(report.sport),
              if (report.date.isNotEmpty) report.date,
              ...context_,
            ].join('  ·  '),
            style: textTheme.bodySmall?.copyWith(color: MivaltaColors.textMuted),
          ),

          // Insight-first: what the session built
          if (report.whatItBuilds.isNotEmpty) ...[
            const SizedBox(height: MivaltaSpace.x4),
            Text(
              report.whatItBuilds,
              style: textTheme.bodyLarge?.copyWith(color: MivaltaColors.textPrimary),
            ),
          ],

          // Energy system trained (card-sourced tag)
          if (report.energySystem.isNotEmpty) ...[
            const SizedBox(height: MivaltaSpace.x2),
            Text(
              'Energy system: ${report.energySystem}',
              style: textTheme.bodySmall?.copyWith(color: MivaltaColors.textSecondary),
            ),
          ],

          // Quality summary (verbatim)
          if (report.qualitySummary.isNotEmpty) ...[
            const SizedBox(height: MivaltaSpace.x3),
            Text(
              report.qualitySummary,
              style: textTheme.bodyMedium?.copyWith(color: MivaltaColors.textSecondary),
            ),
          ],

          // Stimulus / cost note (card-sourced)
          if (report.stimulusCostNote.isNotEmpty) ...[
            const SizedBox(height: MivaltaSpace.x2),
            Text(
              report.stimulusCostNote,
              style: textTheme.bodySmall?.copyWith(color: MivaltaColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  static String _titleCase(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

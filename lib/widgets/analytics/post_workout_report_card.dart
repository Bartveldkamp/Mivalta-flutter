// Post-Workout Report card — Advisory, next-gen UI.
//
// Display-only (UI_UX_DIRECTION §2.1 insight-first, v1.4 Advisory = present-and-
// offer over bounded engine output). A3 (verdict-first): the engine's verdict
// prose leads — quality summary then stimulus/cost note — followed by the
// reasons (what the session built, energy system), with the raw stats
// collapsible beneath. Verdict → reasons → data; never raw data first.
// Every string is engine/card-sourced; fields absent on the report are simply
// omitted (no fabrication).

import 'package:flutter/material.dart';

import '../../models/workout_report.dart';
import '../../theme/tokens.dart';

class PostWorkoutReportCard extends StatefulWidget {
  const PostWorkoutReportCard({super.key, required this.report});

  final WorkoutReport report;

  @override
  State<PostWorkoutReportCard> createState() => _PostWorkoutReportCardState();
}

class _PostWorkoutReportCardState extends State<PostWorkoutReportCard> {
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final report = widget.report;

    // The raw stats line — data, shown last and only on request.
    final stats = <String>[
      if (report.sport.isNotEmpty) _titleCase(report.sport),
      if (report.date.isNotEmpty) report.date,
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
          // Header: label + zone badge
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

          // ── VERDICT (first, always): the engine's quality summary leads. ──
          if (report.qualitySummary.isNotEmpty) ...[
            const SizedBox(height: MivaltaSpace.x3),
            Text(
              report.qualitySummary,
              style: textTheme.bodyLarge?.copyWith(
                color: MivaltaColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],

          // Stimulus / cost note — part of the verdict read (card-sourced).
          if (report.stimulusCostNote.isNotEmpty) ...[
            const SizedBox(height: MivaltaSpace.x2),
            Text(
              report.stimulusCostNote,
              style: textTheme.bodyMedium?.copyWith(
                color: MivaltaColors.textSecondary,
              ),
            ),
          ],

          // ── REASONS: what the session built (card-sourced meaning). ──
          if (report.whatItBuilds.isNotEmpty) ...[
            const SizedBox(height: MivaltaSpace.x3),
            Text(
              report.whatItBuilds,
              style: textTheme.bodyMedium?.copyWith(
                color: MivaltaColors.textSecondary,
              ),
            ),
          ],
          if (report.energySystem.isNotEmpty) ...[
            const SizedBox(height: MivaltaSpace.x2),
            Text(
              'Energy system: ${report.energySystem}',
              style: textTheme.bodySmall?.copyWith(
                color: MivaltaColors.textSecondary,
              ),
            ),
          ],

          // ── DATA: raw stats, collapsible beneath (never first). ──
          if (stats.isNotEmpty) ...[
            const SizedBox(height: MivaltaSpace.x2),
            InkWell(
              onTap: () => setState(() => _showDetails = !_showDetails),
              borderRadius: BorderRadius.circular(MivaltaRadii.sm),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: MivaltaSpace.x1),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _showDetails ? 'Hide details' : 'Details',
                      style: textTheme.labelLarge?.copyWith(
                        color: MivaltaColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Icon(
                      _showDetails ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: MivaltaColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: MivaltaMotion.fast,
              alignment: Alignment.topCenter,
              child: _showDetails
                  ? Padding(
                      padding: const EdgeInsets.only(top: MivaltaSpace.x1),
                      child: Text(
                        stats.join('  ·  '),
                        style: textTheme.bodySmall?.copyWith(
                          color: MivaltaColors.textMuted,
                        ),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ],
      ),
    );
  }

  static String _titleCase(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

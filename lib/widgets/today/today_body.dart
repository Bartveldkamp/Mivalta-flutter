// TodayBody — the design-UI visual layer for the Today screen.
// Per Today-Modular.html: glow hero, Josi line, decision chip, module cards.
//
// This replaces ThreeZoneHome with the new design while preserving all
// engine wiring. Engine DECIDES; this only renders.
//
// Read-only for now; edit mode (drag-reorder, hide/show) is a follow-up PR.

import 'package:flutter/material.dart';

import '../../copy/zone_labels.dart';
import '../../screens/readiness_screen.dart' show HomeData;
import '../../theme/tokens.dart';
import 'decision_chip.dart';
import 'glow_hero.dart';
import 'josi_line.dart';
import 'module_card.dart';

/// Humanize fatigue state for display. Only transforms at the LABEL layer;
/// never recomputes the state itself.
String _humanizeFatigueState(String? state) {
  if (state == null) return '';
  // IllnessRisk → Illness risk
  return state.replaceAllMapped(
    RegExp(r'([a-z])([A-Z])'),
    (m) => '${m[1]} ${m[2]!.toLowerCase()}',
  );
}

/// Format sleep hours as Xh Ym (e.g., "7h 42m").
String _formatSleepHours(double? hours) {
  if (hours == null) return '—';
  final totalMinutes = (hours * 60).round();
  final h = totalMinutes ~/ 60;
  final m = totalMinutes % 60;
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}

/// The Today screen body with the design-UI visual layer.
///
/// Receives [HomeData] from the existing engine wiring and renders it
/// using the new design components.
class TodayBody extends StatelessWidget {
  const TodayBody({
    super.key,
    required this.data,
    required this.onTapGlow,
    required this.onTapAdvisor,
    required this.onTapLatestWorkout,
  });

  final HomeData data;
  final VoidCallback onTapGlow;
  final VoidCallback onTapAdvisor;
  final void Function(String date) onTapLatestWorkout;

  /// Whether this is a rest day (session zone 'R').
  bool get _isRest => (data.sessionZone ?? '').toUpperCase() == 'R';

  /// Get the decision text based on engine data.
  String get _decisionText {
    if (data.insufficientData) {
      return 'Learning your baseline...';
    }
    if (_isRest) {
      return 'Rest today';
    }
    if (data.workoutTitle != null) {
      return 'Train as planned';
    }
    return 'Ready to train';
  }

  @override
  Widget build(BuildContext context) {
    final err = data.error;
    if (err != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(MivaltaSpace.x5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error, color: MivaltaColors.levelRed, size: 48),
              const SizedBox(height: MivaltaSpace.x4),
              SelectableText(err, style: MivaltaTextStyles.body()),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: MivaltaSpace.x4,
        vertical: MivaltaSpace.x4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ============ GLOW HERO ============
          Center(
            child: GlowHero(
              score: data.readinessScore,
              stateWord: _humanizeFatigueState(data.fatigueState),
              fatigueState: data.fatigueState,
              noData: data.insufficientData,
              onTap: data.insufficientData ? null : onTapGlow,
            ),
          ),
          const SizedBox(height: MivaltaSpace.x5),

          // ============ JOSI LINE ============
          JosiLine(
            realizedLine: data.realizedLine,
            fallbackText: data.stateRecommendation,
            showWhyButton: !data.insufficientData,
          ),
          const SizedBox(height: MivaltaSpace.x4),

          // ============ DECISION CHIP ============
          Center(
            child: DecisionChip(
              text: _decisionText,
              isRest: _isRest,
              noData: data.insufficientData,
              onTap: data.insufficientData ? null : onTapAdvisor,
            ),
          ),
          const SizedBox(height: MivaltaSpace.x5),

          // ============ YOUR DAY EYEBROW ============
          if (!data.insufficientData) ...[
            Text(
              'YOUR DAY',
              style: MivaltaTextStyles.eyebrow(),
            ),
            const SizedBox(height: MivaltaSpace.x3),

            // ============ LOAD & SLEEP CARD ============
            ModuleCard(
              icon: Icons.show_chart,
              title: 'Load & Sleep',
              child: Column(
                children: [
                  if (data.todayLoad != null)
                    MetricRow(
                      label: 'Today\'s load',
                      value: data.todayLoad!.round().toString(),
                    ),
                  if (data.lastNightSleepHours != null) ...[
                    const SizedBox(height: MivaltaSpace.x2),
                    MetricRow(
                      label: 'Last night',
                      value: _formatSleepHours(data.lastNightSleepHours),
                    ),
                  ],
                  if (data.acwrZone != null &&
                      data.acwrZone != 'insufficient_data') ...[
                    const SizedBox(height: MivaltaSpace.x2),
                    MetricRow(
                      label: 'Training load',
                      value: data.acwrZone ?? '',
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: MivaltaSpace.x3),

            // ============ SUGGESTED WORKOUT CARD ============
            if (data.workoutTitle != null)
              ModuleCard(
                icon: Icons.lightbulb_outline,
                title: 'Suggested workout',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            data.workoutTitle!,
                            style: MivaltaTextStyles.body(
                              weight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (data.durationMin != null)
                          Text(
                            '${data.durationMin} min',
                            style: MivaltaTextStyles.small(),
                          ),
                      ],
                    ),
                    if (data.sessionZone != null) ...[
                      const SizedBox(height: MivaltaSpace.x2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: MivaltaSpace.x2,
                          vertical: MivaltaSpace.x1,
                        ),
                        decoration: BoxDecoration(
                          color: zoneColor(data.sessionZone).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(MivaltaRadii.sm),
                        ),
                        child: Text(
                          zoneLabel(data.sessionZone) ?? data.sessionZone!,
                          style: MivaltaTextStyles.small(
                            color: zoneColor(data.sessionZone),
                          ),
                        ),
                      ),
                    ],
                    if (data.focusCue != null && data.focusCue!.isNotEmpty) ...[
                      const SizedBox(height: MivaltaSpace.x3),
                      Text(
                        data.focusCue!,
                        style: MivaltaTextStyles.body().copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    const SizedBox(height: MivaltaSpace.x3),
                    // See options button
                    GestureDetector(
                      onTap: onTapAdvisor,
                      child: Text(
                        'See workout options',
                        style: MivaltaTextStyles.body(
                          color: MivaltaColors.stateProductive,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: MivaltaSpace.x3),

            // ============ LATEST WORKOUT ============
            if (data.latestActivity != null)
              _LatestWorkoutCard(
                activity: data.latestActivity!,
                onTap: () => onTapLatestWorkout(data.latestActivity!.date),
              ),
          ],

          // ============ LEARNING STATE ============
          if (data.insufficientData) ...[
            const SizedBox(height: MivaltaSpace.x4),
            _LearningCard(observationDays: data.observationDays),
          ],

          const SizedBox(height: MivaltaSpace.x5),
        ],
      ),
    );
  }
}

/// Card shown when data is still being gathered.
class _LearningCard extends StatelessWidget {
  const _LearningCard({required this.observationDays});

  final int observationDays;

  String get _line => observationDays > 0
      ? "I'm still learning you — day $observationDays."
      : "I'm still learning you.";

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(MivaltaSpace.x4),
      decoration: BoxDecoration(
        color: MivaltaColors.cardBackground,
        border: Border.all(color: MivaltaColors.cardBorder),
        borderRadius: BorderRadius.circular(MivaltaRadii.card),
      ),
      child: Row(
        children: [
          const Icon(Icons.edit_note, color: MivaltaColors.textMuted),
          const SizedBox(width: MivaltaSpace.x3),
          Expanded(
            child: Text(
              _line,
              style: MivaltaTextStyles.body(color: MivaltaColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Card showing the latest completed workout.
class _LatestWorkoutCard extends StatelessWidget {
  const _LatestWorkoutCard({
    required this.activity,
    required this.onTap,
  });

  final dynamic activity; // ActivitySummary
  final VoidCallback onTap;

  static String _titleCase(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    final sport = activity.sport as String? ?? '';
    final durationMin = activity.durationMin as int?;
    final loadUls = activity.loadUls as double?;

    final meta = <String>[
      if (durationMin != null) '$durationMin min',
      if (loadUls != null) 'load ${loadUls.round()}',
    ];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(MivaltaSpace.x4),
        decoration: BoxDecoration(
          color: MivaltaColors.cardBackground,
          border: Border.all(color: MivaltaColors.cardBorder),
          borderRadius: BorderRadius.circular(MivaltaRadii.card),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LATEST WORKOUT',
                    style: MivaltaTextStyles.cardHeader(),
                  ),
                  const SizedBox(height: MivaltaSpace.x1),
                  Text(
                    [
                      sport.isEmpty ? 'Workout' : _titleCase(sport),
                      ...meta,
                    ].join('  ·  '),
                    style: MivaltaTextStyles.body(weight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: MivaltaColors.textMuted),
          ],
        ),
      ),
    );
  }
}

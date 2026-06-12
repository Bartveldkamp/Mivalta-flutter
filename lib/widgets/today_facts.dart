// Today-facts tiles (HOME_REDESIGN_BRIEF §4 item 3, §5) — sleep last night,
// training load, today's load, plus the reserved weather slot. Plain human
// words/numbers ONLY: every engine value passes through the fixed
// dictionaries in lib/copy/today_facts_labels.dart; raw enums, ACWR ratios
// and monotony scalars are FORBIDDEN here (depth lives in Explore).
//
// DISPLAY ONLY: the engine decides zones and statuses; this widget renders
// fixed copy keyed on them. Number formatting is presentation. The
// training-load tile's tap-through reveals the engine's own
// `acwr_recommendation` prose VERBATIM — verdict→reasons ordering, no
// invented text.
//
// §9 no-naked-numbers: every tile pairs its value with an icon so the
// one-second read lands without parsing digits.

import 'package:flutter/material.dart';

import '../copy/today_facts_labels.dart';
import '../theme/tokens.dart';

/// The 2×2 today-facts grid under the state element. Production call site:
/// [ThreeZoneHome]. Public so widget tests can pump it with engine-shaped
/// values directly.
class TodayFacts extends StatefulWidget {
  const TodayFacts({
    super.key,
    this.sleepHours,
    this.acwrZone,
    this.acwrRecommendation,
    this.dataStatus,
    this.todayLoad,
  });

  /// Last night's `sleep_hours` row from the engine's biometric history
  /// (null → honest "No sleep data yet").
  final double? sleepHours;

  /// Engine `context_widget.acwr_zone` — labelled via the fixed dictionary,
  /// never shown raw.
  final String? acwrZone;

  /// Engine `context_widget.acwr_recommendation` prose — revealed verbatim
  /// on tile tap (the "why" of the load label).
  final String? acwrRecommendation;

  /// Engine `context_widget.data_status` — gates the load label honestly.
  final String? dataStatus;

  /// Engine `readDailyLoads` row for today (null → nothing logged).
  final double? todayLoad;

  @override
  State<TodayFacts> createState() => _TodayFactsState();
}

class _TodayFactsState extends State<TodayFacts> {
  bool _showLoadWhy = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // Sleep last night — engine value verbatim, formatted; else honest empty.
    final sleep = widget.sleepHours;
    final sleepValue =
        sleep != null ? '${sleep.toStringAsFixed(1)} h sleep' : kSleepEmptyCopy;

    // Training load — fixed dictionary keyed on the engine's zone, gated on
    // the engine's own data_status. Unknown zone or unavailable status →
    // learning copy, never the raw string.
    final loadLabel = loadContextAvailable(widget.dataStatus)
        ? trainingLoadLabel(widget.acwrZone)
        : null;
    final recommendation = widget.acwrRecommendation;
    final hasLoadWhy = loadLabel != null &&
        recommendation != null &&
        recommendation.isNotEmpty;

    // Today's load — presence of an engine row = trained; else honest empty.
    final todayLoad = widget.todayLoad;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // IntrinsicHeight: equal-height tile pairs without unbounded-stretch
        // constraints inside the scroll column.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _FactTile(
                  icon: Icons.bedtime_outlined,
                  label: kSleepTileLabel,
                  value: sleepValue,
                  muted: sleep == null,
                ),
              ),
              const SizedBox(width: MivaltaSpace.x3),
              Expanded(
                child: _FactTile(
                  icon: Icons.show_chart,
                  label: kTrainingLoadTileLabel,
                  value: loadLabel ?? kTrainingLoadLearningCopy,
                  muted: loadLabel == null,
                  onTap: hasLoadWhy
                      ? () => setState(() => _showLoadWhy = !_showLoadWhy)
                      : null,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: MivaltaSpace.x3),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _FactTile(
                  icon: Icons.bolt_outlined,
                  label: kTodayLoadTileLabel,
                  value: todayLoad != null
                      ? kTodayLoadTrainedCopy
                      : kTodayLoadEmptyCopy,
                  detail: todayLoad?.round().toString(),
                  muted: todayLoad == null,
                ),
              ),
              const SizedBox(width: MivaltaSpace.x3),
              // Weather — reserved slot, no wiring (decision pending, §7).
              const Expanded(
                child: _FactTile(
                  icon: Icons.cloud_outlined,
                  label: kWeatherTileLabel,
                  value: kWeatherSoonCopy,
                  muted: true,
                ),
              ),
            ],
          ),
        ),
        // Tap-through: the engine's load recommendation prose, verbatim.
        if (hasLoadWhy)
          AnimatedSize(
            duration: MivaltaMotion.fast,
            alignment: Alignment.topCenter,
            child: _showLoadWhy
                ? Padding(
                    padding: const EdgeInsets.only(top: MivaltaSpace.x2),
                    child: Text(
                      recommendation,
                      style: textTheme.bodySmall?.copyWith(
                        color: MivaltaColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
      ],
    );
  }
}

/// One fact tile: icon + muted heading + one-line human value (+ optional
/// small detail number). Muted presentation for empty/learning/stub states.
class _FactTile extends StatelessWidget {
  const _FactTile({
    required this.icon,
    required this.label,
    required this.value,
    this.detail,
    this.muted = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? detail;
  final bool muted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final valueColor =
        muted ? MivaltaColors.textMuted : MivaltaColors.textPrimary;

    final tile = Container(
      padding: const EdgeInsets.all(MivaltaSpace.x3),
      decoration: BoxDecoration(
        color: MivaltaColors.surface1,
        borderRadius: BorderRadius.circular(MivaltaRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 16,
                color:
                    muted ? MivaltaColors.textMuted : MivaltaColors.primaryGreen,
              ),
              const SizedBox(width: MivaltaSpace.x2),
              Expanded(
                child: Text(
                  label,
                  style: textTheme.labelSmall?.copyWith(
                    color: MivaltaColors.textMuted,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: MivaltaSpace.x2),
          Text(
            value,
            style: textTheme.bodyMedium?.copyWith(
              color: valueColor,
              fontWeight: muted ? FontWeight.w400 : FontWeight.w600,
              height: 1.2,
            ),
          ),
          if (detail != null) ...[
            const SizedBox(height: 2),
            Text(
              detail!,
              style: textTheme.bodySmall?.copyWith(
                color: MivaltaColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return tile;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(MivaltaRadii.md),
      child: tile,
    );
  }
}

// Journey tab — Round 3 item 19 (docs/FOUNDER_FEEDBACK_2026-06-12.md): the
// 2nd anchor renders the athlete's JOURNEY — the calibration/learning arc
// ("day X of ~28"), week-in-review, and baseline evolution. Past + becoming,
// not future planning (beta is MONITOR+ADVISORY; the Plan placeholder is
// gone).
//
// ENGINE-GROUNDED ONLY (architecture rules 1/3): every value here is an
// engine read rendered verbatim — readBiometricHistory distinct-date count
// (same presentation counting as the home's learning ring), readDailyLoads
// rows, fitnessSeries via the existing FitnessTrend model + chart. Honest
// empty states everywhere; nothing fabricated. Milestones (founder item 19)
// have NO engine surface yet — ENGINE GAP, not faked here.
//
// Same data/view split as the home (ThreeZoneHome + HomeData): JourneyScreen
// fetches into JourneyData, JourneyView renders it, so widget tests pump
// seeded engine-shaped values directly.

import 'dart:convert';

import 'package:flutter/material.dart';

import '../copy/journey_labels.dart';
import '../models/fitness_trend.dart';
import '../rust_engine.dart';
import '../theme/tokens.dart';
import '../widgets/analytics/fitness_trend_chart.dart';

/// Everything the Journey renders, fetched in one pass. Engine values
/// verbatim; null/empty fields mean the engine had nothing — the view shows
/// the honest empty copy, never invented content.
class JourneyData {
  /// Distinct dates in readBiometricHistory — the learning-arc day count
  /// (presentation counting only, same as HomeData.observationDays; explicit
  /// engine field remains flagged as a gap).
  int observationDays = 0;

  /// readDailyLoads(7) rows verbatim: (date, load).
  List<(String, double)> weekLoads = const [];

  /// fitnessSeries(90) — long-term Banister baseline (the slow shape).
  FitnessTrend? trend;

  String? error;
}

/// The Journey anchor. [binding]/[handle] are null until the Today tab's
/// engine bootstrap completes (the shell shares the ONE engine instance) —
/// until then the view shows the honest loading copy.
class JourneyScreen extends StatefulWidget {
  const JourneyScreen({super.key, required this.binding, required this.handle});

  final RustEngineBinding? binding;
  final EnginesHandle? handle;

  @override
  State<JourneyScreen> createState() => _JourneyScreenState();
}

class _JourneyScreenState extends State<JourneyScreen> {
  JourneyData? _data;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void didUpdateWidget(covariant JourneyScreen old) {
    super.didUpdateWidget(old);
    // The shell rebuilds us with the binding once the engine is ready.
    if (widget.binding != old.binding || widget.handle != old.handle) {
      _fetch();
    }
  }

  Future<void> _fetch() async {
    final b = widget.binding;
    final h = widget.handle;
    if (b == null || h == null) return;

    final d = JourneyData();
    try {
      // Learning arc: distinct observed dates (presentation counting,
      // mirrors the home's learning ring — 365-day window covers any
      // calibration period honestly).
      final bio = jsonDecode(await b.readBiometricHistory(h, days: 365));
      if (bio is List) {
        d.observationDays = bio
            .whereType<Map>()
            .map((e) => e['date']?.toString())
            .whereType<String>()
            .toSet()
            .length;
      }

      // Week in review: the engine's daily load rows, verbatim.
      final loads = jsonDecode(await b.readDailyLoads(h, days: 7));
      if (loads is List) {
        d.weekLoads = [
          for (final row in loads)
            if (row is List &&
                row.length >= 2 &&
                row[0] is String &&
                row[1] is num)
              (row[0] as String, (row[1] as num).toDouble()),
        ];
      }

      // Baseline evolution: the existing fitness-trend surface.
      d.trend = FitnessTrend.fromJson(
        jsonDecode(await b.fitnessSeries(h, days: 90)),
      );
    } catch (e) {
      d.error = e.toString();
    }
    if (!mounted) return;
    setState(() => _data = d);
  }

  @override
  Widget build(BuildContext context) => JourneyView(data: _data);
}

/// Display layer for the Journey. [data] null = engine not ready yet (honest
/// loading copy). Public so widget tests pump seeded engine-shaped values.
class JourneyView extends StatelessWidget {
  const JourneyView({super.key, required this.data});

  final JourneyData? data;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final d = data;

    return Scaffold(
      backgroundColor: MivaltaColors.surfaceBackground,
      appBar: AppBar(
        backgroundColor: MivaltaColors.surfaceBackground,
        foregroundColor: MivaltaColors.textPrimary,
        title: const Text(kJourneyTitle),
      ),
      body: d == null
          ? Center(
              child: Text(
                kJourneyLoadingCopy,
                style: textTheme.bodyMedium?.copyWith(
                  color: MivaltaColors.textMuted,
                ),
              ),
            )
          : d.error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: MivaltaSpace.x6,
                    ),
                    child: Text(
                      kJourneyErrorCopy,
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color: MivaltaColors.textSecondary,
                      ),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(MivaltaSpace.x4),
                  children: [
                    _LearningArcCard(days: d.observationDays),
                    const SizedBox(height: MivaltaSpace.x3),
                    _WeekInReviewCard(weekLoads: d.weekLoads),
                    const SizedBox(height: MivaltaSpace.x3),
                    _BaselineCard(trend: d.trend),
                  ],
                ),
    );
  }
}

/// Section card scaffold: muted heading + content, surface1 like the home's
/// fact tiles.
class _JourneyCard extends StatelessWidget {
  const _JourneyCard({required this.heading, required this.child});

  final String heading;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(MivaltaSpace.x4),
      decoration: BoxDecoration(
        color: MivaltaColors.surface1,
        borderRadius: BorderRadius.circular(MivaltaRadii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: textTheme.labelSmall?.copyWith(
              color: MivaltaColors.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: MivaltaSpace.x3),
          child,
        ],
      ),
    );
  }
}

/// The calibration/learning arc — "day X of ~28" with a thin progress bar
/// (X/28 clamped is presentation normalization, like the why-reveal bars).
class _LearningArcCard extends StatelessWidget {
  const _LearningArcCard({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return _JourneyCard(
      heading: kJourneyLearningHeading,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            days > 0 ? journeyLearningLine(days) : kJourneyLearningEmptyCopy,
            style: textTheme.bodyMedium?.copyWith(
              color: days > 0
                  ? MivaltaColors.textPrimary
                  : MivaltaColors.textMuted,
              fontWeight: days > 0 ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          if (days > 0) ...[
            const SizedBox(height: MivaltaSpace.x2),
            ClipRRect(
              borderRadius: BorderRadius.circular(MivaltaRadii.sm),
              child: LinearProgressIndicator(
                value: (days / 28).clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: MivaltaColors.surface2,
                color: MivaltaColors.primaryGreen,
              ),
            ),
          ],
          const SizedBox(height: MivaltaSpace.x2),
          Text(
            kJourneyCalibrationCopy,
            style: textTheme.bodySmall?.copyWith(
              color: MivaltaColors.textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

/// Week in review — the engine's daily load rows verbatim (weekday name is
/// date formatting, the load number renders rounded for presentation).
class _WeekInReviewCard extends StatelessWidget {
  const _WeekInReviewCard({required this.weekLoads});

  final List<(String, double)> weekLoads;

  static String _weekdayName(String date) {
    final parsed = DateTime.tryParse(date);
    if (parsed == null) return date;
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[parsed.weekday - 1];
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return _JourneyCard(
      heading: kJourneyWeekHeading,
      child: weekLoads.isEmpty
          ? Text(
              kJourneyWeekEmptyCopy,
              style: textTheme.bodyMedium?.copyWith(
                color: MivaltaColors.textMuted,
              ),
            )
          : Column(
              children: [
                for (final (date, load) in weekLoads) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _weekdayName(date),
                          style: textTheme.bodyMedium?.copyWith(
                            color: MivaltaColors.textSecondary,
                          ),
                        ),
                      ),
                      Text(
                        '${load.round()}',
                        style: textTheme.bodyMedium?.copyWith(
                          color: MivaltaColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if ((date, load) != weekLoads.last)
                    const SizedBox(height: MivaltaSpace.x2),
                ],
              ],
            ),
    );
  }
}

/// Baseline evolution — the existing Banister fitness-trend chart, or the
/// honest empty copy before the first workouts.
class _BaselineCard extends StatelessWidget {
  const _BaselineCard({required this.trend});

  final FitnessTrend? trend;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final t = trend;
    if (t == null || t.isEmpty) {
      return _JourneyCard(
        heading: kJourneyBaselineHeading,
        child: Text(
          kJourneyBaselineEmptyCopy,
          style: textTheme.bodyMedium?.copyWith(
            color: MivaltaColors.textMuted,
          ),
        ),
      );
    }
    // The chart is already a self-contained surface1 card.
    return FitnessTrendChart(trend: t);
  }
}

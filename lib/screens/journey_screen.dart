// Journey tab — NEXT_BUILD_BRIEF §C: the personalized depth page.
//
// Three pillars (JOURNEY_SPEC.md):
// 1. Load-vs-recovery divergence (readDailyLoads + readReadinessHistory +
//    fitnessSeries incl. form/freshness)
// 2. Per-session detail (VaultActivity via readRecentActivities)
// 3. Adaptation proof = EF + HR-recovery trends (readMetricAcrossActivities)
// Plus the calibration arc ("learning you — day X").
//
// Also: HRV/RHR/Sleep overviews from readBiometricHistory (now populated
// because of vault-first ingest §B).
//
// ENGINE-GROUNDED ONLY (architecture rules 1/3): every value here is an
// engine read rendered verbatim. Honest empty states everywhere; nothing
// fabricated. Same data/view split as the home.

import 'dart:convert';

import 'package:flutter/material.dart';

import '../copy/journey_labels.dart';
import '../models/fitness_trend.dart';
import '../rust_engine.dart';
import '../services/journey_tiles_prefs.dart';
import '../theme/tokens.dart';
import '../widgets/analytics/fitness_trend_chart.dart';

/// Everything the Journey renders, fetched in one pass. Engine values
/// verbatim; null/empty fields mean the engine had nothing — the view shows
/// the honest empty copy, never invented content.
class JourneyData {
  /// Distinct dates in readBiometricHistory — the learning-arc day count.
  int observationDays = 0;

  /// readDailyLoads(28) rows verbatim: (date, load) for 4 weeks.
  List<(String, double)> monthLoads = const [];

  /// readReadinessHistory(28) rows: (date, score) for recovery trend.
  List<(String, double)> readinessHistory = const [];

  /// fitnessSeries(90) — Banister fitness/fatigue/form.
  FitnessTrend? trend;

  /// readBiometricHistory(28) rows for HRV/RHR/Sleep overviews.
  List<BiometricSample> biometricHistory = const [];

  /// readRecentActivities(10) — recent workouts list.
  List<ActivitySummary> recentActivities = const [];

  /// readMetricAcrossActivities('efficiency_factor') — EF trend.
  List<(String, double)> efTrend = const [];

  /// readMetricAcrossActivities('hr_recovery') — HR recovery trend.
  List<(String, double)> hrRecoveryTrend = const [];

  String? error;
}

/// A single biometric sample row from readBiometricHistory.
class BiometricSample {
  final String date;
  final double? hrvRmssd;
  final double? restingHr;
  final double? sleepHours;

  const BiometricSample({
    required this.date,
    this.hrvRmssd,
    this.restingHr,
    this.sleepHours,
  });

  factory BiometricSample.fromJson(Map json) => BiometricSample(
        date: json['date']?.toString() ?? '',
        hrvRmssd: (json['hrv_rmssd'] as num?)?.toDouble(),
        restingHr: (json['resting_hr'] as num?)?.toDouble(),
        sleepHours: (json['sleep_hours'] as num?)?.toDouble(),
      );
}

/// Summary of a recent activity from readRecentActivities.
class ActivitySummary {
  final String activityId;
  final String activityType;
  final String completedAt;
  final int durationSecs;
  final double? loadUls;
  final double? avgHr;
  final double? efficiencyFactor;
  final double? hrDecouplingPct;

  const ActivitySummary({
    required this.activityId,
    required this.activityType,
    required this.completedAt,
    required this.durationSecs,
    this.loadUls,
    this.avgHr,
    this.efficiencyFactor,
    this.hrDecouplingPct,
  });

  factory ActivitySummary.fromJson(Map json) => ActivitySummary(
        activityId: json['activity_id']?.toString() ?? '',
        activityType: json['activity_type']?.toString() ?? 'other',
        completedAt: json['completed_at']?.toString() ?? '',
        durationSecs: (json['duration_secs'] as num?)?.toInt() ?? 0,
        loadUls: (json['load_uls'] as num?)?.toDouble(),
        avgHr: (json['avg_hr'] as num?)?.toDouble(),
        efficiencyFactor: (json['efficiency_factor'] as num?)?.toDouble(),
        hrDecouplingPct: (json['hr_decoupling_pct'] as num?)?.toDouble(),
      );
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
  Set<String> _enabledTiles = Set.of(kDefaultJourneyTiles);
  final _prefs = JourneyTilesPrefs();

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _fetch();
  }

  Future<void> _loadPrefs() async {
    final tiles = await _prefs.load();
    if (!mounted) return;
    setState(() => _enabledTiles = tiles);
  }

  void _onTilesChanged(Set<String> tiles) {
    setState(() => _enabledTiles = tiles);
    _prefs.save(tiles);
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
      // Learning arc: distinct observed dates (365-day window).
      final bio = jsonDecode(await b.readBiometricHistory(h, days: 365));
      if (bio is List) {
        d.observationDays = bio
            .whereType<Map>()
            .map((e) => e['date']?.toString())
            .whereType<String>()
            .toSet()
            .length;
      }

      // Month of loads for load-vs-recovery divergence (28 days).
      final loads = jsonDecode(await b.readDailyLoads(h, days: 28));
      if (loads is List) {
        d.monthLoads = [
          for (final row in loads)
            if (row is List &&
                row.length >= 2 &&
                row[0] is String &&
                row[1] is num)
              (row[0] as String, (row[1] as num).toDouble()),
        ];
      }

      // Readiness history for recovery trend (28 days).
      final readiness = jsonDecode(await b.readReadinessHistory(h, days: 28));
      if (readiness is List) {
        d.readinessHistory = [
          for (final row in readiness.whereType<Map>())
            if (row['date'] != null && row['readiness_score'] is num)
              (
                row['date'].toString(),
                (row['readiness_score'] as num).toDouble(),
              ),
        ];
      }

      // Fitness series for trend (90 days) — includes form/freshness.
      d.trend = FitnessTrend.fromJson(
        jsonDecode(await b.fitnessSeries(h, days: 90)),
      );

      // Biometric history for HRV/RHR/Sleep overviews (28 days).
      final bioHistory = jsonDecode(await b.readBiometricHistory(h, days: 28));
      if (bioHistory is List) {
        d.biometricHistory = [
          for (final row in bioHistory.whereType<Map>())
            BiometricSample.fromJson(row),
        ];
      }

      // Recent activities for workouts list.
      final activities = jsonDecode(await b.readRecentActivities(h, limit: 10));
      if (activities is List) {
        d.recentActivities = [
          for (final row in activities.whereType<Map>())
            ActivitySummary.fromJson(row),
        ];
      }

      // Efficiency factor trend for adaptation proof.
      // Query across all activity types (passing empty string means no filter).
      final ef = jsonDecode(
        await b.readMetricAcrossActivities(
          h,
          metric: 'efficiency_factor',
          activityType: '',  // All activity types
          limit: 20,
        ),
      );
      if (ef is List) {
        d.efTrend = [
          for (final row in ef.whereType<Map>())
            if (row['completed_at'] != null && row['value'] is num)
              (
                row['completed_at'].toString(),
                (row['value'] as num).toDouble(),
              ),
        ];
      }

      // HR recovery trend for adaptation proof.
      final hrRec = jsonDecode(
        await b.readMetricAcrossActivities(
          h,
          metric: 'hr_recovery',
          activityType: '',  // All activity types
          limit: 20,
        ),
      );
      if (hrRec is List) {
        d.hrRecoveryTrend = [
          for (final row in hrRec.whereType<Map>())
            if (row['completed_at'] != null && row['value'] is num)
              (
                row['completed_at'].toString(),
                (row['value'] as num).toDouble(),
              ),
        ];
      }
    } catch (e) {
      d.error = e.toString();
    }
    if (!mounted) return;
    setState(() => _data = d);
  }

  @override
  Widget build(BuildContext context) => JourneyView(
        data: _data,
        enabledTiles: _enabledTiles,
        onTilesChanged: _onTilesChanged,
      );
}

/// Display layer for the Journey. [data] null = engine not ready yet (honest
/// loading copy). Public so widget tests pump seeded engine-shaped values.
class JourneyView extends StatelessWidget {
  const JourneyView({
    super.key,
    required this.data,
    this.enabledTiles = const {},
    this.onTilesChanged,
  });

  final JourneyData? data;
  final Set<String> enabledTiles;
  final ValueChanged<Set<String>>? onTilesChanged;

  void _showTilePicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: MivaltaColors.surface1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(MivaltaRadii.lg)),
      ),
      builder: (ctx) => _JourneyTilePicker(
        enabled: enabledTiles,
        onChanged: (tiles) {
          onTilesChanged?.call(tiles);
          Navigator.pop(ctx);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final d = data;

    // Build the list of visible cards based on enabled tiles.
    List<Widget> buildCards() {
      final cards = <Widget>[];

      if (enabledTiles.contains('learning')) {
        cards.add(_LearningArcCard(days: d!.observationDays));
      }
      if (enabledTiles.contains('load_recovery')) {
        if (cards.isNotEmpty) cards.add(const SizedBox(height: MivaltaSpace.x3));
        cards.add(_LoadRecoveryCard(
          monthLoads: d!.monthLoads,
          readinessHistory: d.readinessHistory,
        ));
      }
      if (enabledTiles.contains('fitness')) {
        if (cards.isNotEmpty) cards.add(const SizedBox(height: MivaltaSpace.x3));
        cards.add(_FitnessFormCard(trend: d!.trend));
      }
      if (enabledTiles.contains('hrv')) {
        if (cards.isNotEmpty) cards.add(const SizedBox(height: MivaltaSpace.x3));
        cards.add(_BiometricCard(
          heading: kJourneyHrvHeading,
          emptyCopy: kJourneyHrvEmptyCopy,
          data: d!.biometricHistory
              .where((s) => s.hrvRmssd != null)
              .map((s) => (s.date, s.hrvRmssd!))
              .toList(),
          unit: 'ms',
        ));
      }
      if (enabledTiles.contains('rhr')) {
        if (cards.isNotEmpty) cards.add(const SizedBox(height: MivaltaSpace.x3));
        cards.add(_BiometricCard(
          heading: kJourneyRhrHeading,
          emptyCopy: kJourneyRhrEmptyCopy,
          data: d!.biometricHistory
              .where((s) => s.restingHr != null)
              .map((s) => (s.date, s.restingHr!))
              .toList(),
          unit: 'bpm',
        ));
      }
      if (enabledTiles.contains('sleep')) {
        if (cards.isNotEmpty) cards.add(const SizedBox(height: MivaltaSpace.x3));
        cards.add(_BiometricCard(
          heading: kJourneySleepHeading,
          emptyCopy: kJourneySleepEmptyCopy,
          data: d!.biometricHistory
              .where((s) => s.sleepHours != null)
              .map((s) => (s.date, s.sleepHours!))
              .toList(),
          unit: 'hrs',
        ));
      }
      if (enabledTiles.contains('workouts')) {
        if (cards.isNotEmpty) cards.add(const SizedBox(height: MivaltaSpace.x3));
        cards.add(_WorkoutsCard(activities: d!.recentActivities));
      }
      if (enabledTiles.contains('adaptation')) {
        if (cards.isNotEmpty) cards.add(const SizedBox(height: MivaltaSpace.x3));
        cards.add(_AdaptationCard(
          efTrend: d!.efTrend,
          hrRecoveryTrend: d.hrRecoveryTrend,
        ));
      }

      return cards;
    }

    return Scaffold(
      backgroundColor: MivaltaColors.surfaceBackground,
      appBar: AppBar(
        backgroundColor: MivaltaColors.surfaceBackground,
        foregroundColor: MivaltaColors.textPrimary,
        title: const Text(kJourneyTitle),
        actions: [
          if (d != null && d.error == null && onTilesChanged != null)
            IconButton(
              icon: const Icon(Icons.tune),
              tooltip: kJourneyTilePickerTooltip,
              onPressed: () => _showTilePicker(context),
            ),
        ],
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
                  children: buildCards(),
                ),
    );
  }
}

/// Bottom sheet picker for configuring which Journey cards are visible.
class _JourneyTilePicker extends StatefulWidget {
  const _JourneyTilePicker({required this.enabled, required this.onChanged});

  final Set<String> enabled;
  final ValueChanged<Set<String>> onChanged;

  @override
  State<_JourneyTilePicker> createState() => _JourneyTilePickerState();
}

class _JourneyTilePickerState extends State<_JourneyTilePicker> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set.of(widget.enabled);
  }

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        MivaltaSpace.x4,
        MivaltaSpace.x4,
        MivaltaSpace.x4,
        MivaltaSpace.x4 + bottomPadding,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            kJourneyTilePickerTitle,
            style: textTheme.titleMedium?.copyWith(
              color: MivaltaColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: MivaltaSpace.x4),
          Wrap(
            spacing: MivaltaSpace.x2,
            runSpacing: MivaltaSpace.x2,
            children: [
              for (final id in kJourneyTileIds)
                FilterChip(
                  label: Text(journeyTileName(id)),
                  selected: _selected.contains(id),
                  onSelected: (_) => _toggle(id),
                  selectedColor: MivaltaColors.primaryGreen.withValues(alpha: 0.3),
                  checkmarkColor: MivaltaColors.primaryGreen,
                  backgroundColor: MivaltaColors.surface2,
                  labelStyle: textTheme.bodyMedium?.copyWith(
                    color: MivaltaColors.textPrimary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: MivaltaSpace.x4),
          FilledButton(
            onPressed: () => widget.onChanged(_selected),
            style: FilledButton.styleFrom(
              backgroundColor: MivaltaColors.primaryGreen,
              foregroundColor: MivaltaColors.surfaceBackground,
            ),
            child: const Text('Done'),
          ),
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

/// Load vs Recovery divergence — THE spine of Journey.
/// Shows load (training stress) vs recovery (readiness) as dual sparklines.
class _LoadRecoveryCard extends StatelessWidget {
  const _LoadRecoveryCard({
    required this.monthLoads,
    required this.readinessHistory,
  });

  final List<(String, double)> monthLoads;
  final List<(String, double)> readinessHistory;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hasLoad = monthLoads.isNotEmpty;
    final hasRecovery = readinessHistory.isNotEmpty;

    if (!hasLoad && !hasRecovery) {
      return _JourneyCard(
        heading: kJourneyLoadRecoveryHeading,
        child: Text(
          kJourneyLoadRecoveryEmptyCopy,
          style: textTheme.bodyMedium?.copyWith(
            color: MivaltaColors.textMuted,
          ),
        ),
      );
    }

    return _JourneyCard(
      heading: kJourneyLoadRecoveryHeading,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Load sparkline
          if (hasLoad) ...[
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: MivaltaColors.primaryGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: MivaltaSpace.x2),
                Text(
                  'Load',
                  style: textTheme.bodySmall?.copyWith(
                    color: MivaltaColors.textSecondary,
                  ),
                ),
                const Spacer(),
                Text(
                  '${monthLoads.last.$2.round()}',
                  style: textTheme.bodyMedium?.copyWith(
                    color: MivaltaColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: MivaltaSpace.x2),
            SizedBox(
              height: 40,
              child: _SimpleSparkline(
                data: monthLoads.map((e) => e.$2).toList(),
                color: MivaltaColors.primaryGreen,
              ),
            ),
          ],
          if (hasLoad && hasRecovery) const SizedBox(height: MivaltaSpace.x3),
          // Recovery sparkline
          if (hasRecovery) ...[
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: MivaltaColors.textSecondary.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: MivaltaSpace.x2),
                Text(
                  'Recovery',
                  style: textTheme.bodySmall?.copyWith(
                    color: MivaltaColors.textSecondary,
                  ),
                ),
                const Spacer(),
                Text(
                  '${readinessHistory.last.$2.round()}',
                  style: textTheme.bodyMedium?.copyWith(
                    color: MivaltaColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: MivaltaSpace.x2),
            SizedBox(
              height: 40,
              child: _SimpleSparkline(
                data: readinessHistory.map((e) => e.$2).toList(),
                color: MivaltaColors.textSecondary.withValues(alpha: 0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Fitness / Form / Freshness card — shows the Banister trend with form
/// (race-readiness / freshness) highlighted.
class _FitnessFormCard extends StatelessWidget {
  const _FitnessFormCard({required this.trend});

  final FitnessTrend? trend;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final t = trend;
    if (t == null || t.isEmpty) {
      return _JourneyCard(
        heading: kJourneyFitnessHeading,
        child: Text(
          kJourneyFitnessEmptyCopy,
          style: textTheme.bodyMedium?.copyWith(
            color: MivaltaColors.textMuted,
          ),
        ),
      );
    }

    final latest = t.latest;
    // Show the current form value prominently
    return _JourneyCard(
      heading: kJourneyFitnessHeading,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (latest != null) ...[
            Row(
              children: [
                Expanded(
                  child: _MetricRow(
                    label: 'Fitness',
                    value: latest.fitness.round().toString(),
                    color: MivaltaColors.primaryGreen,
                  ),
                ),
                Expanded(
                  child: _MetricRow(
                    label: 'Form',
                    value: latest.form.round().toString(),
                    color: latest.form >= 0
                        ? MivaltaColors.primaryGreen
                        : MivaltaColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: MivaltaSpace.x3),
          ],
          // Use the existing FitnessTrendChart
          FitnessTrendChart(trend: t),
        ],
      ),
    );
  }
}

/// Generic biometric overview card (HRV, RHR, Sleep).
class _BiometricCard extends StatelessWidget {
  const _BiometricCard({
    required this.heading,
    required this.emptyCopy,
    required this.data,
    required this.unit,
  });

  final String heading;
  final String emptyCopy;
  final List<(String, double)> data;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (data.isEmpty) {
      return _JourneyCard(
        heading: heading,
        child: Text(
          emptyCopy,
          style: textTheme.bodyMedium?.copyWith(
            color: MivaltaColors.textMuted,
          ),
        ),
      );
    }

    final latest = data.last.$2;
    // Format based on unit
    final formatted = unit == 'hrs'
        ? latest.toStringAsFixed(1)
        : latest.round().toString();

    return _JourneyCard(
      heading: heading,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                formatted,
                style: textTheme.headlineMedium?.copyWith(
                  color: MivaltaColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: MivaltaSpace.x1),
              Text(
                unit,
                style: textTheme.bodyMedium?.copyWith(
                  color: MivaltaColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: MivaltaSpace.x2),
          SizedBox(
            height: 40,
            child: _SimpleSparkline(
              data: data.map((e) => e.$2).toList(),
              color: MivaltaColors.primaryGreen,
            ),
          ),
        ],
      ),
    );
  }
}

/// Recent workouts list card.
class _WorkoutsCard extends StatelessWidget {
  const _WorkoutsCard({required this.activities});

  final List<ActivitySummary> activities;

  static String _formatDuration(int secs) {
    final mins = secs ~/ 60;
    if (mins < 60) return '${mins}m';
    final hours = mins ~/ 60;
    final remMins = mins % 60;
    return remMins > 0 ? '${hours}h ${remMins}m' : '${hours}h';
  }

  static String _formatActivityType(String type) {
    // Capitalize first letter
    if (type.isEmpty) return 'Other';
    return type[0].toUpperCase() + type.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (activities.isEmpty) {
      return _JourneyCard(
        heading: kJourneyWorkoutsHeading,
        child: Text(
          kJourneyWorkoutsEmptyCopy,
          style: textTheme.bodyMedium?.copyWith(
            color: MivaltaColors.textMuted,
          ),
        ),
      );
    }

    return _JourneyCard(
      heading: kJourneyWorkoutsHeading,
      child: Column(
        children: [
          for (var i = 0; i < activities.length; i++) ...[
            _WorkoutRow(activity: activities[i]),
            if (i < activities.length - 1)
              const Divider(
                height: MivaltaSpace.x3,
                color: MivaltaColors.surface2,
              ),
          ],
        ],
      ),
    );
  }
}

/// Single workout row in the list.
class _WorkoutRow extends StatelessWidget {
  const _WorkoutRow({required this.activity});

  final ActivitySummary activity;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final date = DateTime.tryParse(activity.completedAt);
    final dateStr = date != null
        ? '${date.day}/${date.month}'
        : '';

    return Row(
      children: [
        // Activity type icon placeholder (colored circle)
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: MivaltaColors.surface2,
            borderRadius: BorderRadius.circular(MivaltaRadii.sm),
          ),
          child: Center(
            child: Text(
              _activityEmoji(activity.activityType),
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
        const SizedBox(width: MivaltaSpace.x3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _WorkoutsCard._formatActivityType(activity.activityType),
                style: textTheme.bodyMedium?.copyWith(
                  color: MivaltaColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '$dateStr · ${_WorkoutsCard._formatDuration(activity.durationSecs)}',
                style: textTheme.bodySmall?.copyWith(
                  color: MivaltaColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (activity.loadUls != null)
          Text(
            '${activity.loadUls!.round()}',
            style: textTheme.bodyMedium?.copyWith(
              color: MivaltaColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }

  static String _activityEmoji(String type) {
    return switch (type.toLowerCase()) {
      'ride' || 'cycling' => '🚴',
      'run' || 'running' => '🏃',
      'swim' || 'swimming' => '🏊',
      'walk' || 'walking' => '🚶',
      'strength' => '💪',
      'yoga' => '🧘',
      'hike' || 'hiking' => '🥾',
      'row' || 'rowing' => '🚣',
      _ => '🏋️',
    };
  }
}

/// Adaptation trends card — EF + HR recovery.
class _AdaptationCard extends StatelessWidget {
  const _AdaptationCard({
    required this.efTrend,
    required this.hrRecoveryTrend,
  });

  final List<(String, double)> efTrend;
  final List<(String, double)> hrRecoveryTrend;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hasEf = efTrend.isNotEmpty;
    final hasHrRec = hrRecoveryTrend.isNotEmpty;

    if (!hasEf && !hasHrRec) {
      return _JourneyCard(
        heading: kJourneyAdaptationHeading,
        child: Text(
          kJourneyAdaptationEmptyCopy,
          style: textTheme.bodyMedium?.copyWith(
            color: MivaltaColors.textMuted,
          ),
        ),
      );
    }

    return _JourneyCard(
      heading: kJourneyAdaptationHeading,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasEf) ...[
            Text(
              kJourneyEfTrendLabel,
              style: textTheme.bodySmall?.copyWith(
                color: MivaltaColors.textSecondary,
              ),
            ),
            const SizedBox(height: MivaltaSpace.x1),
            Row(
              children: [
                Text(
                  efTrend.last.$2.toStringAsFixed(2),
                  style: textTheme.headlineSmall?.copyWith(
                    color: MivaltaColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: MivaltaSpace.x2),
                Expanded(
                  child: SizedBox(
                    height: 30,
                    child: _SimpleSparkline(
                      data: efTrend.map((e) => e.$2).toList(),
                      color: MivaltaColors.primaryGreen,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (hasEf && hasHrRec) const SizedBox(height: MivaltaSpace.x3),
          if (hasHrRec) ...[
            Text(
              kJourneyHrRecoveryLabel,
              style: textTheme.bodySmall?.copyWith(
                color: MivaltaColors.textSecondary,
              ),
            ),
            const SizedBox(height: MivaltaSpace.x1),
            Row(
              children: [
                Text(
                  '${hrRecoveryTrend.last.$2.round()}',
                  style: textTheme.headlineSmall?.copyWith(
                    color: MivaltaColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: MivaltaSpace.x1),
                Text(
                  'bpm',
                  style: textTheme.bodySmall?.copyWith(
                    color: MivaltaColors.textSecondary,
                  ),
                ),
                const SizedBox(width: MivaltaSpace.x2),
                Expanded(
                  child: SizedBox(
                    height: 30,
                    child: _SimpleSparkline(
                      data: hrRecoveryTrend.map((e) => e.$2).toList(),
                      color: MivaltaColors.primaryGreen,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Simple sparkline chart using CustomPainter.
class _SimpleSparkline extends StatelessWidget {
  const _SimpleSparkline({required this.data, required this.color});

  final List<double> data;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    return CustomPaint(
      size: Size.infinite,
      painter: _SparklinePainter(data: data, color: color),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.data, required this.color});

  final List<double> data;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final min = data.reduce((a, b) => a < b ? a : b);
    final max = data.reduce((a, b) => a > b ? a : b);
    final range = max - min;
    if (range == 0) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final stepX = size.width / (data.length - 1);

    for (var i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y = size.height - ((data[i] - min) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SparklinePainter oldDelegate) =>
      data != oldDelegate.data || color != oldDelegate.color;
}

/// Small metric row with label and value.
class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(
            color: MivaltaColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: textTheme.headlineSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// Explore screen — the on-request "dig in" view (vision §14.6 HISTORY).
//
// Display-only. Two data-ready sections (no engine work):
//   • BIOMETRICS — pick a metric (RHR / HRV / Sleep / Wellness / Temp) and a
//     range (7 / 30 / 90 days). The ENGINE does the range filtering via
//     read_biometric_history(days); Dart only derives the chosen metric's series
//     and renders it. Range change → re-fetch; metric change → re-derive.
//   • WORKOUTS — the last N completed activities (read_recent_activities); tap a
//     row to load its full detail (get_workout_detail) on demand.
//
// Load/strain by-range rollups (week/meso/month) land here next (needs a bridge).

import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/activity_summary.dart';
import '../models/biometric_series.dart';
import '../models/load_context.dart';
import '../rust_engine.dart';
import '../theme/tokens.dart';
import '../widgets/analytics/biometric_chart.dart';
import '../widgets/analytics/load_strain_card.dart';
import 'workout_detail_page.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key, required this.binding, required this.handle});

  final RustEngineBinding binding;
  final EnginesHandle handle;

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  // Biometrics state
  BiometricMetric _metric = BiometricMetric.restingHr;
  int _rangeDays = 30;
  dynamic _bioHistory; // decoded read_biometric_history(_rangeDays)
  bool _bioLoading = true;

  // Workouts state
  List<ActivitySummary> _workouts = const [];

  // Load/strain rollup (engine context widget)
  LoadContext? _loadContext;

  static const _ranges = <int>[7, 30, 90];

  @override
  void initState() {
    super.initState();
    _fetchBiometrics();
    _fetchLoadContext();
    _fetchWorkouts();
  }

  Future<void> _fetchLoadContext() async {
    try {
      final json = await widget.binding.getContextWidget(widget.handle);
      final ctx = LoadContext.fromJson(jsonDecode(json));
      if (mounted) setState(() => _loadContext = ctx);
    } catch (_) {
      // Leave null — the section renders its loading/empty path.
    }
  }

  Future<void> _fetchBiometrics() async {
    setState(() => _bioLoading = true);
    dynamic decoded;
    try {
      final json =
          await widget.binding.readBiometricHistory(widget.handle, days: _rangeDays);
      decoded = jsonDecode(json);
    } catch (_) {
      decoded = null;
    }
    if (!mounted) return;
    setState(() {
      _bioHistory = decoded;
      _bioLoading = false;
    });
  }

  Future<void> _fetchWorkouts() async {
    try {
      final json =
          await widget.binding.readRecentActivities(widget.handle, limit: 20);
      final list = ActivitySummary.listFromJson(jsonDecode(json));
      if (mounted) setState(() => _workouts = list);
    } catch (_) {
      // No activities yet — the section shows its empty copy.
    }
  }

  void _onRange(int days) {
    if (days == _rangeDays) return;
    setState(() => _rangeDays = days);
    _fetchBiometrics();
  }

  void _openWorkout(ActivitySummary a) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WorkoutDetailPage(
          binding: widget.binding,
          handle: widget.handle,
          date: a.date,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final series = BiometricSeries.fromHistory(_bioHistory, _metric);

    return Scaffold(
      backgroundColor: MivaltaColors.surfaceBackground,
      appBar: AppBar(
        backgroundColor: MivaltaColors.surfaceBackground,
        foregroundColor: MivaltaColors.textPrimary,
        title: const Text('Explore'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(MivaltaSpace.x4),
        children: [
          // ---- BIOMETRICS ----
          _label('BIOMETRICS', textTheme),
          const SizedBox(height: MivaltaSpace.x2),
          _ChipRow(
            labels: BiometricMetric.values.map((m) => m.label).toList(),
            selectedIndex: BiometricMetric.values.indexOf(_metric),
            onSelected: (i) => setState(() => _metric = BiometricMetric.values[i]),
          ),
          const SizedBox(height: MivaltaSpace.x2),
          _ChipRow(
            labels: _ranges.map((d) => '${d}d').toList(),
            selectedIndex: _ranges.indexOf(_rangeDays),
            onSelected: (i) => _onRange(_ranges[i]),
          ),
          const SizedBox(height: MivaltaSpace.x3),
          if (_bioLoading)
            const Padding(
              padding: EdgeInsets.all(MivaltaSpace.x5),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            BiometricChart(series: series),

          const SizedBox(height: MivaltaSpace.x6),

          // ---- LOAD & STRAIN ----
          _label('LOAD & STRAIN', textTheme),
          const SizedBox(height: MivaltaSpace.x3),
          if (_loadContext == null)
            const Padding(
              padding: EdgeInsets.all(MivaltaSpace.x5),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            LoadStrainCard(context_: _loadContext!),

          const SizedBox(height: MivaltaSpace.x6),

          // ---- WORKOUTS ----
          _label('WORKOUTS', textTheme),
          const SizedBox(height: MivaltaSpace.x3),
          if (_workouts.isEmpty)
            Text(
              'No workouts yet.',
              style: textTheme.bodyMedium?.copyWith(color: MivaltaColors.textMuted),
            )
          else
            for (final a in _workouts) ...[
              _WorkoutRow(activity: a, onTap: () => _openWorkout(a)),
              const SizedBox(height: MivaltaSpace.x2),
            ],
        ],
      ),
    );
  }

  Widget _label(String text, TextTheme textTheme) => Text(
        text,
        style: textTheme.labelSmall?.copyWith(
          letterSpacing: 1.2,
          color: MivaltaColors.textMuted,
        ),
      );
}

/// Selectable chip row (single-select).
class _ChipRow extends StatelessWidget {
  const _ChipRow({
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> labels;
  final int selectedIndex;
  final void Function(int) onSelected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Wrap(
      spacing: MivaltaSpace.x2,
      runSpacing: MivaltaSpace.x2,
      children: [
        for (var i = 0; i < labels.length; i++)
          GestureDetector(
            onTap: () => onSelected(i),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: MivaltaSpace.x3,
                vertical: MivaltaSpace.x2,
              ),
              decoration: BoxDecoration(
                color: i == selectedIndex
                    ? MivaltaColors.primaryGreen
                    : MivaltaColors.surface2,
                borderRadius: BorderRadius.circular(MivaltaRadii.sm),
              ),
              child: Text(
                labels[i],
                style: textTheme.bodySmall?.copyWith(
                  color: i == selectedIndex
                      ? MivaltaColors.surfaceBackground
                      : MivaltaColors.textSecondary,
                  fontWeight: i == selectedIndex ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// One workout row in the history list.
class _WorkoutRow extends StatelessWidget {
  const _WorkoutRow({required this.activity, required this.onTap});

  final ActivitySummary activity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final meta = <String>[
      if (activity.durationMin != null) '${activity.durationMin} min',
      if (activity.avgHr != null) '${activity.avgHr} bpm',
      if (activity.loadUls != null) 'load ${activity.loadUls!.round()}',
    ];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(MivaltaSpace.x3),
        decoration: BoxDecoration(
          color: MivaltaColors.surface1,
          borderRadius: BorderRadius.circular(MivaltaRadii.sm),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.sport.isEmpty
                        ? 'Workout'
                        : _titleCase(activity.sport),
                    style: textTheme.bodyLarge?.copyWith(
                      color: MivaltaColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [activity.date, ...meta].join('  ·  '),
                    style: textTheme.bodySmall?.copyWith(color: MivaltaColors.textMuted),
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

  static String _titleCase(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

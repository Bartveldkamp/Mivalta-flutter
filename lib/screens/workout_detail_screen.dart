// Workout Detail screen — Phase 2 (give the stored data a face).
//
// Display-only. One FFI call (`get_workout_detail(date)`); every value is
// engine-produced and rendered as-is. A `null` field is honest absence and
// simply doesn't render — no thresholds, no math, no stand-ins (Laws 2/3).
//
// Shows, when the engine has them: the grade + quality metrics (as before),
// the session basics, the device-collected parameters (power/cadence/speed/
// elevation/running-index the athlete's device reported), and the per-workout
// time-in-metabolic-level distribution (which energy system was trained, how
// long) — the substrate the benchmark model learns from.

import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/workout_detail.dart';
import '../rust_engine.dart';
import '../theme/tokens.dart';

class WorkoutDetailScreen extends StatefulWidget {
  const WorkoutDetailScreen({
    super.key,
    required this.binding,
    required this.handle,
    required this.date,
    required this.sportLabel,
  });

  final RustEngineBinding binding;
  final EnginesHandle handle;

  /// `YYYY-MM-DD` — the day whose first activity to detail.
  final String date;

  /// Human sport label for the app bar (already formatted by the caller).
  final String sportLabel;

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  bool _loading = true;
  String? _error;
  WorkoutDetail? _detail;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await widget.binding
          .getWorkoutDetail(widget.handle, date: widget.date);
      final decoded = jsonDecode(raw);
      setState(() {
        // The engine returns null (JSON `null`) when no activity exists.
        _detail = decoded == null ? null : WorkoutDetail.fromJson(decoded);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not load this workout.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MivaltaColors.surfaceBackground,
      appBar: AppBar(
        backgroundColor: MivaltaColors.surfaceBackground,
        foregroundColor: MivaltaColors.textPrimary,
        title: Text(widget.sportLabel),
        elevation: 0,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(
                  color: MivaltaColors.stateProductive,
                ),
              )
            : _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Text(_error!,
            style: const TextStyle(color: MivaltaColors.textSecondary)),
      );
    }
    final d = _detail;
    if (d == null) {
      return const Center(
        child: Text('No workout on this day.',
            style: TextStyle(color: MivaltaColors.textSecondary)),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(MivaltaSpace.x4),
      children: [
        if (d.grade != null && d.grade!.isNotEmpty) _gradeChip(d.grade!),
        const SizedBox(height: MivaltaSpace.x4),
        _section('Session', _sessionRows(d)),
        if (_deviceRows(d).isNotEmpty) ...[
          const SizedBox(height: MivaltaSpace.x4),
          _section('From your device', _deviceRows(d)),
        ],
        if (_qualityRows(d).isNotEmpty) ...[
          const SizedBox(height: MivaltaSpace.x4),
          _section('Quality', _qualityRows(d)),
        ],
        if (d.timeInZone != null && d.timeInZone!.metabolicSeconds.isNotEmpty) ...[
          const SizedBox(height: MivaltaSpace.x4),
          _metabolicSection(d.timeInZone!.metabolicSeconds),
        ],
      ],
    );
  }

  // ---- Rows (only present values render; null = honest absence) ----

  List<_Metric> _sessionRows(WorkoutDetail d) => [
        if (d.durationMin != null) _Metric('Duration', '${d.durationMin} min'),
        if (d.distanceKm != null)
          _Metric('Distance', '${d.distanceKm!.toStringAsFixed(1)} km'),
        if (d.avgHr != null) _Metric('Avg HR', '${d.avgHr} bpm'),
        if (d.maxHr != null) _Metric('Max HR', '${d.maxHr} bpm'),
        if (d.avgPaceMss != null) _Metric('Avg pace', d.avgPaceMss!),
        if (d.avgWatts != null) _Metric('Norm power', '${d.avgWatts} W'),
        if (d.calories != null) _Metric('Calories', '${d.calories}'),
        if (d.source != null && d.source!.isNotEmpty)
          _Metric('Source', d.source!),
      ];

  List<_Metric> _deviceRows(WorkoutDetail d) => [
        if (d.avgPowerWatts != null)
          _Metric('Avg power', '${d.avgPowerWatts!.round()} W'),
        if (d.maxPowerWatts != null)
          _Metric('Max power', '${d.maxPowerWatts!.round()} W'),
        if (d.avgCadence != null)
          _Metric('Avg cadence', d.avgCadence!.round().toString()),
        if (d.maxCadence != null)
          _Metric('Max cadence', d.maxCadence!.round().toString()),
        if (d.avgSpeedMs != null)
          _Metric('Avg speed', '${(d.avgSpeedMs! * 3.6).toStringAsFixed(1)} km/h'),
        if (d.maxSpeedMs != null)
          _Metric('Max speed', '${(d.maxSpeedMs! * 3.6).toStringAsFixed(1)} km/h'),
        if (d.elevationGainM != null)
          _Metric('Ascent', '${d.elevationGainM!.round()} m'),
        if (d.elevationLossM != null)
          _Metric('Descent', '${d.elevationLossM!.round()} m'),
        if (d.runningIndex != null)
          _Metric('Running Index', d.runningIndex!.toStringAsFixed(0)),
      ];

  List<_Metric> _qualityRows(WorkoutDetail d) => [
        if (d.decouplingPct != null)
          _Metric('Decoupling', '${d.decouplingPct!.toStringAsFixed(1)}%'),
        if (d.efficiencyFactor != null)
          _Metric('Efficiency', d.efficiencyFactor!.toStringAsFixed(2)),
        if (d.zoneCompliancePct != null)
          _Metric('Zone compliance', '${d.zoneCompliancePct!.round()}%'),
      ];

  // ---- Widgets ----

  Widget _gradeChip(String grade) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: MivaltaSpace.x3, vertical: MivaltaSpace.x2),
        decoration: BoxDecoration(
          color: MivaltaColors.surface2,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.grade, size: 16, color: MivaltaColors.stateProductive),
            const SizedBox(width: MivaltaSpace.x2),
            Text(grade,
                style: const TextStyle(
                  color: MivaltaColors.textPrimary,
                  fontWeight: FontWeight.w600,
                )),
          ],
        ),
      );

  Widget _section(String title, List<_Metric> metrics) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(),
              style: const TextStyle(
                color: MivaltaColors.textMuted,
                fontSize: 12,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w600,
              )),
          const SizedBox(height: MivaltaSpace.x2),
          ...metrics.map(_metricRow),
        ],
      );

  Widget _metricRow(_Metric m) => Padding(
        padding: const EdgeInsets.symmetric(vertical: MivaltaSpace.x1),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(m.label,
                style: const TextStyle(color: MivaltaColors.textSecondary)),
            Text(m.value,
                style: const TextStyle(
                  color: MivaltaColors.textPrimary,
                  fontWeight: FontWeight.w600,
                )),
          ],
        ),
      );

  /// The six metabolic levels the engine trained, in fixed physiological
  /// order. Only levels with time render (a level at 0 s is not shown). The
  /// engine already summed the seconds; Dart only formats minutes and the
  /// relative bar width — no thresholds or re-derivation.
  Widget _metabolicSection(Map<String, double> metabolic) {
    const order = [
      ('aerobic_base', 'Aerobic base'),
      ('aerobic_endurance', 'Aerobic endurance'),
      ('tempo', 'Tempo'),
      ('threshold', 'Threshold'),
      ('vo2max', 'VO₂max'),
      ('anaerobic_neuro', 'Anaerobic / neuro'),
    ];
    final present = [
      for (final (key, label) in order)
        if ((metabolic[key] ?? 0) > 0) (label, metabolic[key]!),
    ];
    if (present.isEmpty) return const SizedBox.shrink();
    final maxSecs =
        present.map((e) => e.$2).reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('ENERGY SYSTEMS TRAINED',
            style: TextStyle(
              color: MivaltaColors.textMuted,
              fontSize: 12,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
            )),
        const SizedBox(height: MivaltaSpace.x3),
        for (final (label, secs) in present) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: const TextStyle(color: MivaltaColors.textSecondary)),
              Text('${(secs / 60).round()} min',
                  style: const TextStyle(
                    color: MivaltaColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  )),
            ],
          ),
          const SizedBox(height: MivaltaSpace.x1),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: maxSecs > 0 ? secs / maxSecs : 0,
              minHeight: 6,
              backgroundColor: MivaltaColors.surface2,
              valueColor: const AlwaysStoppedAnimation(
                  MivaltaColors.stateProductive),
            ),
          ),
          const SizedBox(height: MivaltaSpace.x3),
        ],
      ],
    );
  }
}

class _Metric {
  const _Metric(this.label, this.value);
  final String label;
  final String value;
}

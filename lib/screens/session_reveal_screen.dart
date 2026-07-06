// Session Reveal Screen — BS-011
//
// The "Evening Reveal" — post-workout report showing what the session did.
// One scroll, calm. Verdict first, then session facts, time-in-zone, tomorrow.
// Engine enters at session end; Dart displays only.
// No share button, no badges — the reveal is for the athlete.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../models/time_in_zone.dart';
import '../models/workout_report.dart';
import '../rust_engine.dart';
import '../services/profile_service.dart';
import '../services/session_recorder.dart';
import '../theme/tokens.dart';
import '../theme/zone_names.dart';
import 'today_screen.dart';

/// Post-workout reveal — shows what the session did.
class SessionRevealScreen extends StatefulWidget {
  const SessionRevealScreen({
    super.key,
    required this.session,
  });

  final CompletedSession session;

  @override
  State<SessionRevealScreen> createState() => _SessionRevealScreenState();
}

class _SessionRevealScreenState extends State<SessionRevealScreen> {
  WorkoutReport? _report;
  TimeInZone? _timeInZone;
  String? _acwrBand;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initEngineAndLoadData();
  }

  Future<void> _initEngineAndLoadData() async {
    try {
      // Bootstrap FRB.
      final binding = await RustEngineBinding.bootstrap();
      // binding available for this session.

      // Load profile.
      final profileJson = await ProfileService.loadProfile();
      if (profileJson == null) {
        // No profile — proceed without engine features.
        setState(() => _loading = false);
        return;
      }

      // Load tables.
      final tablesJson =
          await rootBundle.loadString('assets/compiled_tables.json');
      final vaultPath = await ProfileService.getVaultPath();

      // Check for persisted state.
      final hasState = await binding.hasPersistedState(
        athleteProfileJson: profileJson,
        vaultPath: vaultPath,
      );

      EnginesHandle handle;
      if (hasState) {
        final stateJson = await binding.readPersistedState(
          athleteProfileJson: profileJson,
          vaultPath: vaultPath,
        );
        if (stateJson != null) {
          handle = await binding.constructEnginesFromState(
            athleteProfileJson: profileJson,
            tablesJson: tablesJson,
            vaultPath: vaultPath,
            viterbiStateJson: stateJson,
          );
        } else {
          handle = await binding.constructEnginesFresh(
            athleteProfileJson: profileJson,
            tablesJson: tablesJson,
            vaultPath: vaultPath,
          );
        }
      } else {
        handle = await binding.constructEnginesFresh(
          athleteProfileJson: profileJson,
          tablesJson: tablesJson,
          vaultPath: vaultPath,
        );
      }
      // handle available for this session.

      // Now load reveal data.
      await _loadRevealData(binding, handle);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadRevealData(
    RustEngineBinding binding,
    EnginesHandle handle,
  ) async {
    try {
      // Format date as YYYY-MM-DD for engine.
      final date = widget.session.endTime;
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      // Try to get post-workout report from engine.
      // This requires the session to be in the vault (which happens via ingest).
      // For now, if it fails, we proceed with the session data we have.
      try {
        final factsJson = await binding.completedWorkoutFacts(
          handle,
          date: dateStr,
        );

        if (factsJson != 'null' && factsJson.isNotEmpty) {
          final reportJson = await binding.buildPostWorkoutReport(
            handle,
            factsJson: factsJson,
          );
          _report = WorkoutReport.fromJson(jsonDecode(reportJson));
        }
      } catch (e) {
        // No facts in vault yet — that's OK, we proceed with session data.
        debugPrint('Post-workout report not available: $e');
      }

      // Compute time-in-zone from recorded samples if available.
      if (widget.session.hrSamples != null &&
          widget.session.hrSamples!.isNotEmpty) {
        try {
          final activityJson = jsonEncode({
            'completed_at': widget.session.endTime.toIso8601String(),
            'hr_samples': widget.session.hrSamples,
            'sample_rate_hz': 1,
          });

          final tizJson = await binding.computeTimeInZone(
            handle,
            activityJson: activityJson,
          );
          _timeInZone = TimeInZone.fromJson(jsonDecode(tizJson));
        } catch (e) {
          // Time-in-zone computation failed — show honest absence.
          debugPrint('Time-in-zone computation failed: $e');
        }
      }

      // Get ACWR for "what it means for tomorrow".
      try {
        final acwrJson = await binding.getAcwr(handle);
        final acwr = jsonDecode(acwrJson) as Map<String, dynamic>;
        _acwrBand = acwr['recommendation'] as String?;
      } catch (_) {
        // ACWR not available — honest absence.
      }

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MivaltaColors.surfaceBackground,
      body: SafeArea(
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(
                  color: MivaltaColors.stateProductive,
                ),
              )
            : _error != null
                ? _buildError()
                : _buildContent(),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MivaltaSpace.x4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: MivaltaColors.stateOverreached,
            ),
            const SizedBox(height: MivaltaSpace.x3),
            Text(
              'Unable to load reveal',
              style: MivaltaType.cardTitle.copyWith(
                color: MivaltaColors.textPrimary,
              ),
            ),
            const SizedBox(height: MivaltaSpace.x2),
            Text(
              _error!,
              style: MivaltaType.small.copyWith(
                color: MivaltaColors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: MivaltaSpace.x5),
            TextButton(
              onPressed: _navigateToToday,
              child: Text(
                'Back to Today',
                style: MivaltaType.body.copyWith(
                  color: MivaltaColors.stateProductive,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Reveal header with gradient.
          _buildHeader(),

          // Session averages strip.
          _buildAverages(),

          // Josi verdict line.
          _buildVerdict(),

          // Time-in-zone section.
          _buildTimeInZone(),

          // What it means for tomorrow.
          if (_acwrBand != null) _buildTomorrow(),

          // Done button.
          _buildActions(),

          const SizedBox(height: MivaltaSpace.x6),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final session = widget.session;
    final energySystem = _report?.energySystem ?? '';

    return Container(
      padding: const EdgeInsets.fromLTRB(
        MivaltaSpace.x4,
        MivaltaSpace.x5,
        MivaltaSpace.x4,
        MivaltaSpace.x4,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            MivaltaColors.stateProductive.withValues(alpha: 0.10),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        children: [
          // "Session complete" badge.
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle,
                size: 15,
                color: MivaltaColors.stateProductive,
              ),
              const SizedBox(width: 6),
              Text(
                '${_sportLabel(session.sport).toUpperCase()} COMPLETE',
                style: MivaltaType.label.copyWith(
                  color: MivaltaColors.stateProductive,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),

          const SizedBox(height: MivaltaSpace.x2),

          // Energy system title (from report, or sport fallback).
          Text(
            energySystem.isNotEmpty ? energySystem : _sportLabel(session.sport),
            style: MivaltaType.display.copyWith(
              color: MivaltaColors.textPrimary,
              fontSize: 25,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: MivaltaSpace.x3),

          // Structure chips (duration, distance).
          Wrap(
            spacing: 7,
            runSpacing: 7,
            alignment: WrapAlignment.center,
            children: [
              _StructureChip(label: session.formattedDuration),
              if (session.distanceKm != null)
                _StructureChip(
                  label: '${session.distanceKm!.toStringAsFixed(1)} km',
                ),
              if (session.formattedPace != null)
                _StructureChip(label: '${session.formattedPace} /km'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAverages() {
    final session = widget.session;

    return Container(
      decoration: BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(
            color: MivaltaColors.textPrimary.withValues(alpha: 0.07),
          ),
        ),
      ),
      child: Row(
        children: [
          // Avg HR.
          Expanded(
            child: _AverageCell(
              value: session.avgHeartRate?.toString() ?? '—',
              label: 'AVG HR',
              absent: session.avgHeartRate == null,
            ),
          ),
          // Avg Speed.
          Expanded(
            child: _AverageCell(
              value: session.avgSpeedKmh != null
                  ? session.avgSpeedKmh!.toStringAsFixed(1)
                  : '—',
              label: 'AVG KM/H',
              absent: session.avgSpeedKmh == null,
            ),
          ),
          // Max HR.
          Expanded(
            child: _AverageCell(
              value: session.maxHeartRate?.toString() ?? '—',
              label: 'MAX HR',
              absent: session.maxHeartRate == null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerdict() {
    // Use engine's quality summary if available, otherwise show a generic line.
    final verdictLine = _report?.qualitySummary ?? _report?.autocue;

    // If no engine verdict, show honest interim.
    if (verdictLine == null || verdictLine.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(MivaltaSpace.x4),
        child: Container(
          padding: const EdgeInsets.all(MivaltaSpace.x4),
          decoration: BoxDecoration(
            color: MivaltaColors.textPrimary.withValues(alpha: 0.035),
            border: Border.all(
              color: MivaltaColors.textPrimary.withValues(alpha: 0.085),
            ),
            borderRadius: BorderRadius.circular(MivaltaRadii.lg),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Josi avatar.
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: const Alignment(-0.2, -0.3),
                    colors: [
                      MivaltaColors.stateProductive,
                      MivaltaColors.stateProductive.withValues(alpha: 0.7),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: MivaltaSpace.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'JOSI',
                      style: MivaltaType.label.copyWith(
                        color: MivaltaColors.stateProductive,
                        fontSize: 10,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Session logged. Quality read arrives once more data is in.',
                      style: MivaltaType.body.copyWith(
                        color: MivaltaColors.textPrimary,
                        fontSize: 14,
                        height: 1.46,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(MivaltaSpace.x4),
      child: Container(
        padding: const EdgeInsets.all(MivaltaSpace.x4),
        decoration: BoxDecoration(
          color: MivaltaColors.textPrimary.withValues(alpha: 0.035),
          border: Border.all(
            color: MivaltaColors.textPrimary.withValues(alpha: 0.085),
          ),
          borderRadius: BorderRadius.circular(MivaltaRadii.lg),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Josi avatar.
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: const Alignment(-0.2, -0.3),
                  colors: [
                    MivaltaColors.stateProductive,
                    MivaltaColors.stateProductive.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),
            const SizedBox(width: MivaltaSpace.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'JOSI',
                    style: MivaltaType.label.copyWith(
                      color: MivaltaColors.stateProductive,
                      fontSize: 10,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    verdictLine,
                    style: MivaltaType.body.copyWith(
                      color: MivaltaColors.textPrimary,
                      fontSize: 14,
                      height: 1.46,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeInZone() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MivaltaSpace.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section eyebrow.
          Text(
            'TIME IN ZONE',
            style: MivaltaType.label.copyWith(
              color: MivaltaColors.textMuted,
              fontSize: 10,
              letterSpacing: 1,
            ),
          ),

          const SizedBox(height: MivaltaSpace.x2),

          // Time-in-zone card or honest absence.
          if (_timeInZone == null || _timeInZone!.isEmpty)
            _buildTimeInZoneAbsent()
          else
            _buildTimeInZoneChart(),
        ],
      ),
    );
  }

  Widget _buildTimeInZoneAbsent() {
    final hasHr = widget.session.hrSamples != null &&
        widget.session.hrSamples!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(MivaltaSpace.x4),
      decoration: BoxDecoration(
        color: MivaltaColors.textPrimary.withValues(alpha: 0.02),
        border: Border.all(
          color: MivaltaColors.textPrimary.withValues(alpha: 0.16),
          style: BorderStyle.solid,
        ),
        borderRadius: BorderRadius.circular(MivaltaRadii.md),
      ),
      child: Row(
        children: [
          Icon(
            Icons.monitor_heart_outlined,
            size: 20,
            color: MivaltaColors.textMuted,
          ),
          const SizedBox(width: MivaltaSpace.x3),
          Expanded(
            child: Text(
              hasHr
                  ? 'Zone calculation requires your threshold to be set.'
                  : 'Zones need heart rate or power data. Add a sensor for the zone breakdown.',
              style: MivaltaType.small.copyWith(
                color: MivaltaColors.textMuted,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeInZoneChart() {
    final tiz = _timeInZone!;

    return Container(
      padding: const EdgeInsets.all(MivaltaSpace.x4),
      decoration: BoxDecoration(
        color: MivaltaColors.textPrimary.withValues(alpha: 0.03),
        border: Border.all(
          color: MivaltaColors.textPrimary.withValues(alpha: 0.08),
        ),
        borderRadius: BorderRadius.circular(MivaltaRadii.md),
      ),
      child: Column(
        children: [
          for (final zone in tiz.zones)
            if (zone.seconds > 0) _ZoneRow(zone: zone, total: tiz.totalSeconds),
        ],
      ),
    );
  }

  Widget _buildTomorrow() {
    return Padding(
      padding: const EdgeInsets.all(MivaltaSpace.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WHAT IT MEANS',
            style: MivaltaType.label.copyWith(
              color: MivaltaColors.textMuted,
              fontSize: 10,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: MivaltaSpace.x2),
          Container(
            padding: const EdgeInsets.all(MivaltaSpace.x4),
            decoration: BoxDecoration(
              color: MivaltaColors.textPrimary.withValues(alpha: 0.03),
              border: Border.all(
                color: MivaltaColors.textPrimary.withValues(alpha: 0.08),
              ),
              borderRadius: BorderRadius.circular(MivaltaRadii.md),
            ),
            child: Text(
              _acwrBand!,
              style: MivaltaType.body.copyWith(
                color: MivaltaColors.textPrimary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        MivaltaSpace.x4,
        MivaltaSpace.x4,
        MivaltaSpace.x4,
        0,
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: _navigateToToday,
          icon: const Icon(Icons.check, size: 18),
          label: const Text('Done'),
          style: ElevatedButton.styleFrom(
            backgroundColor: MivaltaColors.stateProductive,
            foregroundColor: MivaltaColors.surfaceBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(MivaltaRadii.md),
            ),
            elevation: 0,
          ),
        ),
      ),
    );
  }

  void _navigateToToday() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(
        builder: (context) => const TodayScreen(),
      ),
    );
  }

  String _sportLabel(String sport) {
    return switch (sport.toLowerCase()) {
      'cycling' => 'Ride',
      'running' => 'Run',
      'walking' => 'Walk',
      _ => 'Session',
    };
  }
}

/// Structure chip (duration, distance, pace).
class _StructureChip extends StatelessWidget {
  const _StructureChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: MivaltaColors.stateProductive.withValues(alpha: 0.1),
        border: Border.all(
          color: MivaltaColors.stateProductive.withValues(alpha: 0.22),
        ),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: MivaltaType.label.copyWith(
          color: MivaltaColors.stateRecovered,
          fontSize: 11,
          fontFamily: 'JetBrainsMono',
        ),
      ),
    );
  }
}

/// Average cell in the strip.
class _AverageCell extends StatelessWidget {
  const _AverageCell({
    required this.value,
    required this.label,
    this.absent = false,
  });

  final String value;
  final String label;
  final bool absent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: MivaltaSpace.x3),
      child: Column(
        children: [
          Text(
            value,
            style: MivaltaType.display.copyWith(
              color: absent
                  ? MivaltaColors.textPrimary.withValues(alpha: 0.3)
                  : MivaltaColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: MivaltaType.label.copyWith(
              color: MivaltaColors.textMuted,
              fontSize: 9,
              letterSpacing: 0.3,
            ),
          ),
          if (absent)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'no sensor',
                style: MivaltaType.small.copyWith(
                  color: MivaltaColors.textPrimary.withValues(alpha: 0.3),
                  fontSize: 8,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Time-in-zone row with bar.
class _ZoneRow extends StatelessWidget {
  const _ZoneRow({required this.zone, required this.total});

  final ZoneSeconds zone;
  final double total;

  @override
  Widget build(BuildContext context) {
    final fraction = total > 0 ? zone.seconds / total : 0.0;
    final minutes = (zone.seconds / 60).round();
    final (name, color) = zoneDisplayNameAndColor(zone.zone);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          // Zone label (name + code).
          SizedBox(
            width: 120,
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: name,
                    style: MivaltaType.small.copyWith(
                      color: MivaltaColors.stateRecovered,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(
                    text: ' ${zone.zone}',
                    style: MivaltaType.small.copyWith(
                      color: MivaltaColors.textMuted,
                      fontSize: 10,
                      fontFamily: 'JetBrainsMono',
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bar.
          Expanded(
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: MivaltaColors.textPrimary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(3),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: fraction.clamp(0, 1),
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),

          // Minutes.
          SizedBox(
            width: 38,
            child: Text(
              minutes > 0 ? '$minutes\'' : '—',
              style: MivaltaType.small.copyWith(
                color: MivaltaColors.textMuted,
                fontSize: 11,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

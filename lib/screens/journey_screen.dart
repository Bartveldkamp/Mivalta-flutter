// Journey Screen — BS-015: the story of me (past + present, no future).
//
// Vision: Screen-Journey-You.html, Journey-You-Elite.html, Journey-You-Wellness.html.
// Engine DECIDES, Flutter DISPLAYS. Every number is a LIVE FFI call; fabricate nothing.
//
// Anatomy (top → bottom, one scroll):
// 1. Masthead — same two-tier as Today (reused)
// 2. THE ARC (hero) — readiness trend, 28 days (read_readiness_history)
// 3. LOAD (module card) — daily load bars, 14 days (read_daily_loads)
// 4. TIME IN ZONE (module card) — honest-absent until aggregate API exists
// 5. FITNESS SHAPE (module card) — fitness/fatigue/form (fitness_series)
// 6. AHEAD (section) — honest-absent placeholder

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kDebugMode, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/activity_summary.dart';
import '../models/metabolic_rollup.dart';
import '../models/metric_trend.dart';
import '../models/realized_line.dart';
import '../models/sleep_trend.dart';
import '../rust_engine.dart';
import '../services/profile_service.dart';
import '../theme/tokens.dart';
import '../widgets/today/josi_card.dart';
import '../widgets/today/module_card.dart';
import '../widgets/make_it_yours_sheet.dart';
import '../widgets/mivalta_bottom_nav.dart';
import 'workout_detail_screen.dart';

/// Parse one `read_readiness_history` row into the arc's (score, level) pair.
///
/// The rows are serde-serialized `VaultBiometric` (gatc-vault/src/models.rs:
/// `readiness_score: Option<i32>`, `readiness_level: Option<String>` — no
/// serde rename). `readiness_level` is NOT `level` — that key belongs to the
/// readiness_indicator payload only. Pure and top-level so the contract keys
/// are pinned by test (journey_history_row_contract_test.dart); absent fields
/// stay null (honest absence, never a stand-in).
@visibleForTesting
({int? score, String? level}) parseReadinessHistoryRow(
        Map<String, dynamic> row) =>
    (
      score: (row['readiness_score'] as num?)?.toInt(),
      level: row['readiness_level'] as String?,
    );

class JourneyScreen extends StatefulWidget {
  const JourneyScreen({super.key, this.binding, this.handle});

  /// BS-017 test seam: injected engine binding. Null in prod → bootstrap().
  final RustEngineBinding? binding;

  /// BS-017 test seam: injected engine handle. Null in prod → construct below.
  final EnginesHandle? handle;

  @override
  State<JourneyScreen> createState() => _JourneyScreenState();
}

class _JourneyScreenState extends State<JourneyScreen> {
  bool _loading = true;
  String? _error;

  // PR-C1: retained for the history list's detail-navigation and the
  // "Show older" window refetch (couriers only; the engine owns the data).
  RustEngineBinding? _binding;
  EnginesHandle? _handle;

  // HISTORY — every stored workout in the requested window, newest first.
  // The window is a REQUEST parameter (how much to ask the engine for),
  // not a computation; "Show older" widens it by 90 days per tap.
  List<ActivitySummary> _history = const [];
  int _historyDays = 90;
  bool _historyLoading = false;

  // RECALL — engine-summed time-in-metabolic-level rollups.
  MetabolicRollup? _weekRollup;
  MetabolicRollup? _monthRollup;

  // TRENDS — engine-sloped HRV / RHR windows.
  MetricTrend? _hrvTrend;
  MetricTrend? _rhrTrend;

  // SLEEP — recorded nights from biometric history (verbatim hours).
  SleepTrend _sleep = const SleepTrend(nights: []);

  // Arc data (readiness history)
  List<_ReadinessPoint> _arcPoints = const [];
  int _observationDays = 0;
  String? _todayLevel;

  // Load data (daily loads)
  List<double> _loads = const [];
  double? _loadCeiling;
  String? _loadBandLine;

  // Fitness data
  List<double> _fitnessSeries = const [];
  List<double> _fatigueSeries = const [];

  // BS-016 S4: Day summary (Josi's end-of-day line)
  RealizedLine? _todaySummary;

  @override
  void initState() {
    super.initState();
    _initEngine();
  }

  Future<void> _initEngine() async {
    try {
      final binding = widget.binding ?? await RustEngineBinding.bootstrap();
      final profileJson = await ProfileService.loadProfile();

      if (profileJson == null) {
        setState(() {
          _error = 'No profile';
          _loading = false;
        });
        return;
      }

      final tablesJson = await rootBundle.loadString('assets/compiled_tables.json');
      final vaultPath = await ProfileService.getVaultPath();

      final hasState = await binding.hasPersistedState(
        athleteProfileJson: profileJson,
        vaultPath: vaultPath,
      );

      EnginesHandle handle;
      if (widget.handle != null) {
        handle = widget.handle!;
      } else if (hasState) {
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

      await _loadJourneyData(binding, handle);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadJourneyData(RustEngineBinding binding, EnginesHandle handle) async {
    _binding = binding;
    _handle = handle;

    // PR-C1: HISTORY — ask the engine for the current window (newest first
    // for display; the engine returns the stored rows verbatim).
    await _fetchHistory(binding, handle);

    // PR-C1: RECALL — engine-summed rollups for the last 7 / 28 days.
    try {
      final week = await binding.metabolicTimeInZoneRollup(handle,
          start: _isoDaysAgo(7), end: _isoDaysAgo(0));
      _weekRollup = MetabolicRollup.fromJson(jsonDecode(week));
    } catch (e) {
      debugPrint('metabolicTimeInZoneRollup(7d) failed: $e');
    }
    try {
      final month = await binding.metabolicTimeInZoneRollup(handle,
          start: _isoDaysAgo(28), end: _isoDaysAgo(0));
      _monthRollup = MetabolicRollup.fromJson(jsonDecode(month));
    } catch (e) {
      debugPrint('metabolicTimeInZoneRollup(28d) failed: $e');
    }

    // PR-C1: TRENDS — the engine's sloped HRV / RHR windows, rendered verbatim.
    try {
      _hrvTrend = MetricTrend.fromJson(jsonDecode(await binding.hrvTrend(handle)));
    } catch (e) {
      debugPrint('hrvTrend failed: $e');
    }
    try {
      _rhrTrend = MetricTrend.fromJson(jsonDecode(await binding.rhrTrend(handle)));
    } catch (e) {
      debugPrint('rhrTrend failed: $e');
    }

    // PR-C1: SLEEP — recorded nights (verbatim hours from biometric history).
    try {
      final bio = await binding.readBiometricHistory(handle, days: 28);
      _sleep = SleepTrend.fromJson(jsonDecode(bio));
    } catch (e) {
      debugPrint('readBiometricHistory(sleep) failed: $e');
    }

    // 1. Arc — readiness history (28 days)
    try {
      final historyJson = await binding.readReadinessHistory(handle, days: 28);
      final history = jsonDecode(historyJson) as List;
      final points = <_ReadinessPoint>[];
      for (final entry in history) {
        if (entry is Map<String, dynamic>) {
          final parsed = parseReadinessHistoryRow(entry);
          points.add(_ReadinessPoint(
            score: parsed.score,
            level: parsed.level,
          ));
        }
      }
      _arcPoints = points;
    } catch (e) {
      debugPrint('readReadinessHistory failed: $e');
    }

    // Observation count (for "day N of your story")
    try {
      final diagJson = await binding.personalizationDiagnostics(handle);
      final diag = jsonDecode(diagJson) as Map<String, dynamic>;
      _observationDays = (diag['observation_count'] as num?)?.toInt() ?? 0;
    } catch (_) {}

    // Today's level (for arc subtitle)
    try {
      final indicatorJson = await binding.readinessIndicator(handle);
      final indicator = jsonDecode(indicatorJson) as Map<String, dynamic>;
      _todayLevel = indicator['level'] as String?;
    } catch (_) {}

    // 2. Load — daily loads (14 days)
    try {
      final loadsJson = await binding.readDailyLoads(handle, days: 14);
      final loads = jsonDecode(loadsJson) as List;
      final loadValues = <double>[];
      for (final entry in loads) {
        if (entry is List && entry.length >= 2) {
          loadValues.add((entry[1] as num?)?.toDouble() ?? 0.0);
        }
      }
      _loads = loadValues;
    } catch (e) {
      debugPrint('readDailyLoads failed: $e');
    }

    // ACWR for load ceiling + band line
    try {
      final acwrJson = await binding.getAcwr(handle);
      final acwr = jsonDecode(acwrJson) as Map<String, dynamic>;
      _loadCeiling = (acwr['chronic_load'] as num?)?.toDouble();
      _loadBandLine = acwr['recommendation'] as String?;
    } catch (_) {}

    // 3. Fitness series (42 days)
    try {
      final fitnessJson = await binding.fitnessSeries(handle, days: 42);
      final fitness = jsonDecode(fitnessJson) as List;
      final fitnessValues = <double>[];
      final fatigueValues = <double>[];
      for (final entry in fitness) {
        if (entry is Map<String, dynamic>) {
          fitnessValues.add((entry['fitness'] as num?)?.toDouble() ?? 0.0);
          fatigueValues.add((entry['fatigue'] as num?)?.toDouble() ?? 0.0);
        }
      }
      _fitnessSeries = fitnessValues;
      _fatigueSeries = fatigueValues;
    } catch (e) {
      debugPrint('fitnessSeries failed: $e');
    }

    // BS-016 S4: Day summary — Josi closes the day.
    try {
      final today = DateTime.now();
      final dateStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final summaryJson = await binding.realizeDaySummary(handle, date: dateStr);
      _todaySummary = RealizedLine.parse(summaryJson);
    } catch (e) {
      // Honest absence — no summary if no data for today
      debugPrint('realizeDaySummary failed: $e');
    }

    setState(() => _loading = false);
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
            : _buildContent(),
      ),
      bottomNavigationBar: const MivaltaBottomNav(activeTab: NavTab.journey),
    );
  }

  Widget _buildContent() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(MivaltaSpace.x4),
          child: Text(
            'Unable to load: $_error',
            style: const TextStyle(color: MivaltaColors.levelRed),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        // Masthead — same as Today
        SliverToBoxAdapter(child: _buildMasthead()),

        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: MivaltaSpace.x4),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: MivaltaSpace.x5),

              // BS-016 S4: Today's summary — Josi closes the day
              if (_todaySummary != null) ...[
                _buildSectionEyebrow('TODAY'),
                const SizedBox(height: MivaltaSpace.x3),
                _buildDaySummaryCard(),
                const SizedBox(height: MivaltaSpace.x5),
              ],

              // Section: THE ARC
              _buildSectionEyebrow('YOUR ARC'),
              const SizedBox(height: MivaltaSpace.x3),
              _buildArcCard(),

              const SizedBox(height: MivaltaSpace.x5),

              // Section: LOAD
              _buildSectionEyebrow('LOAD · 14 DAYS'),
              const SizedBox(height: MivaltaSpace.x3),
              _buildLoadCard(),

              const SizedBox(height: MivaltaSpace.x5),

              // Section: TIME IN ZONE (honest-absent)
              _buildSectionEyebrow('TIME IN ZONE'),
              const SizedBox(height: MivaltaSpace.x3),
              _buildTimeInZoneCard(),

              const SizedBox(height: MivaltaSpace.x5),

              // Section: FITNESS SHAPE
              _buildSectionEyebrow('FITNESS SHAPE · 6 WEEKS'),
              const SizedBox(height: MivaltaSpace.x3),
              _buildFitnessCard(),

              const SizedBox(height: MivaltaSpace.x5),

              // PR-C1: TRENDS — engine HRV/RHR windows
              _buildSectionEyebrow('RECOVERY TRENDS'),
              const SizedBox(height: MivaltaSpace.x3),
              _buildTrendsCard(),

              const SizedBox(height: MivaltaSpace.x5),

              // PR-C1: SLEEP — recorded nights, verbatim
              _buildSectionEyebrow('SLEEP'),
              const SizedBox(height: MivaltaSpace.x3),
              _buildSleepCard(),

              const SizedBox(height: MivaltaSpace.x5),

              // PR-C1: HISTORY — open any past workout
              _buildSectionEyebrow('HISTORY'),
              const SizedBox(height: MivaltaSpace.x3),
              _buildHistoryCard(),

              const SizedBox(height: MivaltaSpace.x5),

              // Section: AHEAD (honest-absent placeholder)
              _buildSectionEyebrow('AHEAD'),
              const SizedBox(height: MivaltaSpace.x3),
              _buildAheadCard(),

              const SizedBox(height: MivaltaSpace.x6),

              // D6 build stamp (kDebugMode only)
              if (kDebugMode)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: MivaltaSpace.x4),
                    child: Text(
                      'build ${const String.fromEnvironment('BUILD_SHA', defaultValue: 'dev')}',
                      style: MivaltaType.small.copyWith(
                        fontSize: 10,
                        color: MivaltaColors.textMuted,
                      ),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ],
    );
  }

  /// `yyyy-MM-dd` for N days ago — a request parameter for engine reads
  /// (window shaping, not computation).
  String _isoDaysAgo(int days) {
    final d = DateTime.now().subtract(Duration(days: days));
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<void> _fetchHistory(RustEngineBinding binding, EnginesHandle handle) async {
    try {
      final json = await binding.readActivitiesInRange(handle,
          start: _isoDaysAgo(_historyDays), end: _isoDaysAgo(0));
      final rows = ActivitySummary.listFromJson(jsonDecode(json));
      // Newest first for display (ISO dates sort lexically). Ordering is
      // presentation; the engine returned the rows verbatim.
      rows.sort((a, b) => b.date.compareTo(a.date));
      _history = rows;
    } catch (e) {
      debugPrint('readActivitiesInRange failed: $e');
    }
  }

  Future<void> _showOlder() async {
    final binding = _binding;
    final handle = _handle;
    if (binding == null || handle == null) return;
    setState(() {
      _historyDays += 90;
      _historyLoading = true;
    });
    await _fetchHistory(binding, handle);
    if (mounted) setState(() => _historyLoading = false);
  }

  /// HISTORY — every stored workout, tappable into the full detail. The
  /// engine pages arbitrarily far back; "Show older" widens the request.
  Widget _buildHistoryCard() {
    if (_history.isEmpty) {
      return const ModuleCard(
        title: 'Workout history',
        icon: Icons.history,
        child: _HonestAbsence(
          label: 'No workouts recorded yet',
          unlock: 'Finished workouts appear here, as far back as you train',
        ),
      );
    }
    return ModuleCard(
      title: 'Workout history',
      icon: Icons.history,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final a in _history) _historyRow(a),
          const SizedBox(height: MivaltaSpace.x2),
          Center(
            child: _historyLoading
                ? const Padding(
                    padding: EdgeInsets.all(MivaltaSpace.x2),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : TextButton(
                    onPressed: _showOlder,
                    child: Text(
                      'Show older · past $_historyDays days shown',
                      style: MivaltaType.small
                          .copyWith(color: MivaltaColors.textSecondary),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _historyRow(ActivitySummary a) {
    final binding = _binding;
    final handle = _handle;
    return InkWell(
      onTap: (binding != null && handle != null)
          ? () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => WorkoutDetailScreen(
                    binding: binding,
                    handle: handle,
                    date: a.date,
                    activityId: a.id,
                    sportLabel: _formatSportLabel(a.sport),
                  ),
                ),
              )
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: MivaltaSpace.x2),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_formatSportLabel(a.sport), style: MivaltaType.body),
                  Text(a.date,
                      style: MivaltaType.small
                          .copyWith(color: MivaltaColors.textMuted)),
                ],
              ),
            ),
            if (a.durationMin != null)
              Text('${a.durationMin} min',
                  style: MivaltaType.small
                      .copyWith(color: MivaltaColors.textSecondary)),
            const SizedBox(width: MivaltaSpace.x2),
            const Icon(Icons.chevron_right,
                size: 16, color: MivaltaColors.textMuted),
          ],
        ),
      ),
    );
  }

  /// Display capitalisation only — the engine's sport id is the value.
  String _formatSportLabel(String sport) =>
      sport.isEmpty ? sport : sport[0].toUpperCase() + sport.substring(1);

  Widget _rollupColumn(String heading, MetabolicRollup? rollup) {
    final rows = rollup?.nonZeroMinuteRows ?? const [];
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(heading,
              style:
                  MivaltaType.small.copyWith(color: MivaltaColors.textMuted)),
          const SizedBox(height: MivaltaSpace.x2),
          if (rollup == null || rollup.isEmpty)
            Text('No recorded training',
                style: MivaltaType.small
                    .copyWith(color: MivaltaColors.textMuted))
          else
            for (final (label, minutes) in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(label, style: MivaltaType.small),
                    Text('$minutes min',
                        style: MivaltaType.small
                            .copyWith(color: MivaltaColors.textSecondary)),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _trendRow(String label, MetricTrend? trend) {
    if (trend == null || trend.isInsufficient) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: MivaltaSpace.x1),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: MivaltaType.body),
            Text('Not enough data yet',
                style:
                    MivaltaType.small.copyWith(color: MivaltaColors.textMuted)),
          ],
        ),
      );
    }
    // Render the engine's own direction words (underscores humanised — a
    // formatting courtesy, not a re-derivation) for each honest window.
    String directionOf(WindowTrend w) =>
        w.available ? w.direction.replaceAll('_', ' ') : '—';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MivaltaSpace.x1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: MivaltaType.body),
          const SizedBox(height: 2),
          Row(
            children: [
              for (final (name, w) in [
                ('7d', trend.short),
                ('28d', trend.mid),
                ('90d', trend.long)
              ]) ...[
                Text('$name: ${directionOf(w)}',
                    style: MivaltaType.small
                        .copyWith(color: MivaltaColors.textSecondary)),
                const SizedBox(width: MivaltaSpace.x3),
              ],
              if (trend.short.draft || trend.mid.draft || trend.long.draft)
                Text('DRAFT bands',
                    style: MivaltaType.small
                        .copyWith(fontSize: 10, color: MivaltaColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  /// TRENDS — the engine's sloped HRV / RHR windows, verbatim directions.
  Widget _buildTrendsCard() {
    return ModuleCard(
      title: 'Recovery trends',
      icon: Icons.monitor_heart_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _trendRow('HRV', _hrvTrend),
          _trendRow('Resting HR', _rhrTrend),
        ],
      ),
    );
  }

  /// SLEEP — recorded nights, verbatim hours (no score is fabricated; a
  /// sleep *score* concept does not exist in the engine yet).
  Widget _buildSleepCard() {
    if (_sleep.isEmpty) {
      return const ModuleCard(
        title: 'Sleep',
        icon: Icons.bedtime_outlined,
        child: _HonestAbsence(
          label: 'No sleep data yet',
          unlock: 'Nights sync from your health sources',
        ),
      );
    }
    final recent = _sleep.nights.length <= 7
        ? _sleep.nights
        : _sleep.nights.sublist(_sleep.nights.length - 7);
    return ModuleCard(
      title: 'Sleep',
      icon: Icons.bedtime_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final n in recent.reversed)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(n.date,
                      style: MivaltaType.small
                          .copyWith(color: MivaltaColors.textMuted)),
                  Text('${n.hours.toStringAsFixed(1)} h',
                      style: MivaltaType.small
                          .copyWith(color: MivaltaColors.textSecondary)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMasthead() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(MivaltaSpace.x4, 8, MivaltaSpace.x4, 0),
      child: Column(
        children: [
          // Row 1: brand masthead, centered
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset('assets/mivalta-logo.svg', width: 22, height: 22),
              const SizedBox(width: 9),
              Text(
                'MiValta',
                style: GoogleFonts.zenDots(
                  fontSize: 19,
                  letterSpacing: 0.19,
                  color: MivaltaColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: MivaltaSpace.x3),
          // Row 2: Journey title + tune button (W5)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Journey',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: MivaltaColors.textPrimary,
                ),
              ),
              // W5: Tune button (customization sheet)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _showCustomizeSheet,
                child: const Icon(
                  Icons.tune,
                  size: 20,
                  color: MivaltaColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// W5: Show "Make it yours" customization sheet.
  void _showCustomizeSheet() {
    MakeItYoursSheet.show(
      context,
      screenName: 'Journey',
    );
  }

  Widget _buildSectionEyebrow(String text) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'Inter',
        fontWeight: FontWeight.w700,
        fontSize: 10,
        letterSpacing: 1.1,
        color: MivaltaColors.textSoft45,
      ),
    );
  }

  /// BS-016 B3: Day summary — Josi closes the day.
  /// Uses the same JosiCard as Today evening state (same card, all three shapes).
  Widget _buildDaySummaryCard() {
    return JosiCard(
      realizedLine: _todaySummary,
      fallbackLine: 'Your day is complete.',
    );
  }

  /// THE ARC — readiness trend, 28 days.
  Widget _buildArcCard() {
    final hasData = _arcPoints.length >= 7;

    return ModuleCard(
      title: 'Readiness trend',
      icon: Icons.show_chart,
      child: hasData
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 80,
                  child: CustomPaint(
                    size: const Size(double.infinity, 80),
                    painter: _ArcPainter(points: _arcPoints),
                  ),
                ),
                const SizedBox(height: MivaltaSpace.x3),
                Text(
                  _todayLevel != null
                      ? '${_capitalize(_todayLevel!)} · day $_observationDays of your story'
                      : 'Day $_observationDays of your story',
                  style: MivaltaType.small.copyWith(
                    color: MivaltaColors.textSecondary,
                  ),
                ),
              ],
            )
          : _HonestAbsence(
              label: 'Your arc draws itself as your days accumulate',
              unlock: 'Day $_observationDays — keep going',
            ),
    );
  }

  /// LOAD — daily load bars, 14 days.
  Widget _buildLoadCard() {
    final hasData = _loads.isNotEmpty;

    return ModuleCard(
      title: 'Training load',
      icon: Icons.trending_up,
      child: hasData
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 60,
                  child: CustomPaint(
                    size: const Size(double.infinity, 60),
                    painter: _LoadBarsPainter(
                      loads: _loads,
                      ceiling: _loadCeiling,
                    ),
                  ),
                ),
                if (_loadBandLine != null) ...[
                  const SizedBox(height: MivaltaSpace.x2),
                  Text(
                    _loadBandLine!,
                    style: MivaltaType.small.copyWith(
                      color: MivaltaColors.textSecondary,
                    ),
                  ),
                ],
              ],
            )
          : const _HonestAbsence(
              label: 'No load data yet',
              unlock: 'Log workouts to see your load trend',
            ),
    );
  }

  /// TIME IN ZONE — honest-absent (aggregate API not yet available).
  Widget _buildTimeInZoneCard() {
    // PR-C1: the engine aggregate landed (metabolic_time_in_zone_rollup —
    // summed engine-side from stored per-workout atoms; Law 2 intact).
    final bothEmpty = (_weekRollup == null || _weekRollup!.isEmpty) &&
        (_monthRollup == null || _monthRollup!.isEmpty);
    if (bothEmpty) {
      return const ModuleCard(
        title: 'Trained time by level',
        icon: Icons.stacked_bar_chart,
        child: _HonestAbsence(
          label: 'No recorded training in the last month',
          unlock: 'Workouts with sensor streams fill this in',
        ),
      );
    }
    return ModuleCard(
      title: 'Trained time by level',
      icon: Icons.stacked_bar_chart,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _rollupColumn('THIS WEEK', _weekRollup),
          const SizedBox(width: MivaltaSpace.x4),
          _rollupColumn('LAST 28 DAYS', _monthRollup),
        ],
      ),
    );
  }

  /// FITNESS SHAPE — fitness/fatigue/form, 42 days.
  Widget _buildFitnessCard() {
    final hasData = _fitnessSeries.length >= 7;

    return ModuleCard(
      title: 'Fitness & fatigue',
      icon: Icons.timeline,
      child: hasData
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 80,
                  child: CustomPaint(
                    size: const Size(double.infinity, 80),
                    painter: _FitnessPainter(
                      fitness: _fitnessSeries,
                      fatigue: _fatigueSeries,
                    ),
                  ),
                ),
                const SizedBox(height: MivaltaSpace.x3),
                Text(
                  'Fitness builds slow. Fatigue fades fast. The gap is form.',
                  style: MivaltaType.small.copyWith(
                    color: MivaltaColors.textSecondary,
                  ),
                ),
              ],
            )
          : const _HonestAbsence(
              label: 'Fitness shape building',
              unlock: 'A few more weeks of data to see the trend',
            ),
    );
  }

  /// AHEAD — honest-absent placeholder (Forward-Horizon).
  Widget _buildAheadCard() {
    return ModuleCard(
      title: 'Forward horizon',
      icon: Icons.calendar_today,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _HonestAbsence(
            label: 'No horizon yet',
            unlock: 'The engine plans day by day for now',
          ),
          const SizedBox(height: MivaltaSpace.x2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: MivaltaColors.textMuted.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'engine gap G3',
              style: MivaltaType.small.copyWith(
                fontSize: 10,
                color: MivaltaColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _capitalize(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

// ─── Painters ───

class _ReadinessPoint {
  _ReadinessPoint({this.score, this.level});
  final int? score;
  final String? level;
}

/// Arc painter — readiness trend line with state-colored dots.
class _ArcPainter extends CustomPainter {
  _ArcPainter({required this.points});
  final List<_ReadinessPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final validPoints = points.where((p) => p.score != null).toList();
    if (validPoints.isEmpty) return;

    final maxScore = validPoints.map((p) => p.score!).reduce(math.max);
    final minScore = validPoints.map((p) => p.score!).reduce(math.min);
    final range = (maxScore - minScore).clamp(1, 100);

    final path = Path();
    final dotPaint = Paint()..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..color = MivaltaColors.stateProductive.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (int i = 0; i < validPoints.length; i++) {
      final point = validPoints[i];
      final x = (i / (validPoints.length - 1).clamp(1, validPoints.length)) * size.width;
      final normalized = (point.score! - minScore) / range;
      final y = size.height - (normalized * (size.height - 16)) - 8;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Draw line
    canvas.drawPath(path, linePaint);

    // Draw dots with state colors
    for (int i = 0; i < validPoints.length; i++) {
      final point = validPoints[i];
      final x = (i / (validPoints.length - 1).clamp(1, validPoints.length)) * size.width;
      final normalized = (point.score! - minScore) / range;
      final y = size.height - (normalized * (size.height - 16)) - 8;

      dotPaint.color = readinessLevelColor(point.level);
      canvas.drawCircle(Offset(x, y), 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ArcPainter oldDelegate) =>
      oldDelegate.points != points;
}

/// Load bars painter — daily load bars.
class _LoadBarsPainter extends CustomPainter {
  _LoadBarsPainter({required this.loads, this.ceiling});
  final List<double> loads;
  final double? ceiling;

  @override
  void paint(Canvas canvas, Size size) {
    if (loads.isEmpty) return;

    final maxLoad = ceiling ?? loads.reduce(math.max);
    if (maxLoad == 0) return;

    final barWidth = (size.width / loads.length) - 4;
    final paint = Paint()
      ..color = MivaltaColors.stateProductive
      ..style = PaintingStyle.fill;

    for (int i = 0; i < loads.length; i++) {
      final load = loads[i];
      final height = (load / maxLoad) * (size.height - 8);
      final x = i * (barWidth + 4) + 2;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, size.height - height, barWidth, height),
        const Radius.circular(2),
      );
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LoadBarsPainter oldDelegate) =>
      oldDelegate.loads != loads || oldDelegate.ceiling != ceiling;
}

/// Fitness painter — fitness/fatigue dual lines.
class _FitnessPainter extends CustomPainter {
  _FitnessPainter({required this.fitness, required this.fatigue});
  final List<double> fitness;
  final List<double> fatigue;

  @override
  void paint(Canvas canvas, Size size) {
    if (fitness.isEmpty) return;

    final allValues = [...fitness, ...fatigue];
    final maxVal = allValues.reduce(math.max);
    final minVal = allValues.reduce(math.min);
    final range = (maxVal - minVal).clamp(1.0, double.infinity);

    void drawLine(List<double> values, Color color) {
      if (values.isEmpty) return;
      final path = Path();
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      for (int i = 0; i < values.length; i++) {
        final x = (i / (values.length - 1).clamp(1, values.length)) * size.width;
        final normalized = (values[i] - minVal) / range;
        final y = size.height - (normalized * (size.height - 8)) - 4;

        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, paint);
    }

    // Fitness = stateProductive, Fatigue = stateAccumulated
    drawLine(fitness, MivaltaColors.stateProductive);
    drawLine(fatigue, MivaltaColors.stateAccumulated.withValues(alpha: 0.7));
  }

  @override
  bool shouldRepaint(covariant _FitnessPainter oldDelegate) =>
      oldDelegate.fitness != fitness || oldDelegate.fatigue != fatigue;
}

// ─── Shared widgets ───

/// Honest-absence pattern for module cards.
class _HonestAbsence extends StatelessWidget {
  const _HonestAbsence({required this.label, required this.unlock});

  final String label;
  final String unlock;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: MivaltaColors.textSoft70,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          unlock,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: MivaltaColors.textSoft45,
          ),
        ),
      ],
    );
  }
}

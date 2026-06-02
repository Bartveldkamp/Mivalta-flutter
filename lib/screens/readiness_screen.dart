// PR-B: Three-zone PULL home. Display only — every value comes verbatim from
// engine output via the FRB methods bound in PR-A. No thresholds, no math,
// no fallback logic in Dart.
//
// Three zones per UI_UX_DIRECTION.md v1.1 (dark-first, calm, honest, agency):
//   Zone 1 — State (hero): ReadinessRing + state_recommendation prose + fatigue badge
//   Zone 2 — Today: SessionWidget fields (workout_title, zone, target, focus_cue, rationale)
//   Zone 3 — Context: ACWR/monotony/strain + alerts + sparkline + source tier swatch
//
// On insufficient data (no observations yet → advisories.last_observation_at
// == null), Zone 1 shows the LOCKED F1 copy instead of a ring. Zones 2/3
// show their engine-provided empty prose.
//
// **Continuity**: Uses a PERSISTENT vault path (mivalta-vault) and restores
// the ViterbiEngine from persisted state on subsequent launches.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import '../canonical_seed.dart';
import '../rust_engine.dart';
import '../theme/source_tier.dart';
import '../theme/tokens.dart';
import '../widgets/readiness_ring.dart';
import 'advisor_screen.dart';
import 'debug_swatch_exerciser.dart';
import 'manual_entry_screen.dart';
import 'readiness_detail_screen.dart';

/// Humanize fatigue state for display. Only transforms at the LABEL layer;
/// never recomputes the state itself.
String _humanizeFatigueState(String? state) {
  if (state == null) return '—';
  // IllnessRisk → Illness risk
  return state.replaceAllMapped(
    RegExp(r'([a-z])([A-Z])'),
    (m) => '${m[1]} ${m[2]!.toLowerCase()}',
  );
}

class _HomeData {
  // Zone 1 — State (hero)
  int? readinessScore;           // from indicator['score'], rounded
  String? readinessLevel;        // indicator['level'] verbatim
  double? confidence;            // indicator['confidence']
  String? stateRecommendation;   // FIXED: stateWidget['state_recommendation']
  String? confidenceAdvisory;    // FIXED: stateWidget['confidence_advisory']
  String? fatigueState;          // viterbiFatigueState().state

  // Zone 2 — Today (from SessionWidget)
  String? workoutTitle;          // sessionWidget['workout_title']
  int? durationMin;              // sessionWidget['duration_min']
  String? sessionZone;           // sessionWidget['zone']
  int? targetWatts;              // sessionWidget['target_watts']
  String? targetPaceMss;         // sessionWidget['target_pace_mss']
  String? focusCue;              // sessionWidget['focus_cue']
  String? rationaleProse;        // sessionWidget['rationale_prose']
  String? zoneCap;               // zoneCapWithAdvisories().zone

  // Zone 3 — Context (from ContextWidget)
  double? acwr;                  // contextWidget['acwr']
  String? acwrZone;              // contextWidget['acwr_zone']
  String? acwrRecommendation;    // contextWidget['acwr_recommendation']
  double? monotony;              // contextWidget['monotony']
  double? strain;                // contextWidget['strain']
  String? monotonyZone;          // contextWidget['monotony_zone']
  String? monotonyRecommendation;// contextWidget['monotony_recommendation']
  String? lastWorkout;           // contextWidget['last_workout']
  List<String> reactiveAlerts = const [];    // contextWidget['reactive_alerts']
  List<String> patternAdvisories = const []; // contextWidget['pattern_advisories']
  List<double> historyScores = const [];     // FIXED: readReadinessHistory['readiness_score']
  SourceTier? sourceTier;        // lastObservationSourceTier()

  // State
  bool insufficientData = false;
  String? error;
}

class ReadinessScreen extends StatefulWidget {
  const ReadinessScreen({super.key});

  @override
  State<ReadinessScreen> createState() => _ReadinessScreenState();
}

class _ReadinessScreenState extends State<ReadinessScreen> {
  _HomeData _data = _HomeData();
  bool _loading = true;

  // PR-C: Store handle and binding for navigation to detail screen
  EnginesHandle? _handle;
  RustEngineBinding? _binding;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    // Local non-null snapshot, mirroring the Day-3 BLOCKER 2 fix —
    // multiple awaits with State mutation in between is reentrancy bait
    // unless the work happens against a local capture.
    final d = _HomeData();
    RustEngineBinding? localBinding;
    EnginesHandle? localHandle;
    try {
      localBinding = await RustEngineBinding.bootstrap();
      final binding = localBinding; // local alias for cleaner code below
      final tablesJson =
          await rootBundle.loadString('assets/compiled_tables.json');
      final support = await getApplicationSupportDirectory();

      // MVP-1: PERSISTENT vault path — no more throwaway day4-vault / day7-vault
      final vaultDir = Directory('${support.path}/mivalta-vault');
      if (!await vaultDir.exists()) await vaultDir.create(recursive: true);

      final profileJson = CanonicalSeed.vaultProfileJson();

      // Continuity: check for persisted state and restore if it exists
      final persistedState = await binding.readPersistedState(
        athleteProfileJson: profileJson,
        vaultPath: vaultDir.path,
      );

      if (persistedState != null) {
        // Subsequent launch: restore from persisted state
        localHandle = await binding.constructEnginesFromState(
          athleteProfileJson: profileJson,
          tablesJson: tablesJson,
          vaultPath: vaultDir.path,
          viterbiStateJson: persistedState,
        );
      } else {
        // First run: construct fresh and persist immediately
        localHandle = await binding.constructEnginesFresh(
          athleteProfileJson: profileJson,
          tablesJson: tablesJson,
          vaultPath: vaultDir.path,
        );
        // Persist immediately so next launch can restore
        final stateJson = await binding.saveState(localHandle);
        await binding.writeViterbiState(localHandle, stateJson: stateJson);
      }
      final handle = localHandle; // local alias for cleaner code below

      // ---------- Zone 1: State (hero) ----------

      // readiness_indicator — the 4-axis blend headline
      final indicatorJson = await binding.readinessIndicator(handle);
      final indicator = jsonDecode(indicatorJson) as Map<String, dynamic>;
      final num? score = indicator['score'] as num?;
      d.readinessScore = score?.round();
      d.readinessLevel = indicator['level']?.toString();
      d.confidence = (indicator['confidence'] as num?)?.toDouble();

      // Check for insufficient data via readinessScore advisories
      final readinessJson = await binding.readinessScore(handle);
      final readiness = jsonDecode(readinessJson) as Map<String, dynamic>;
      final advisoriesObj = readiness['advisories'];
      if (advisoriesObj is Map) {
        d.insufficientData = advisoriesObj['last_observation_at'] == null;
      }

      // StateWidget — FIXED: use real field names from engine schema
      final stateWidgetJson = await binding.getStateWidget(handle);
      final stateWidget = jsonDecode(stateWidgetJson);
      if (stateWidget is Map) {
        d.stateRecommendation = stateWidget['state_recommendation']?.toString();
        d.confidenceAdvisory = stateWidget['confidence_advisory']?.toString();
      }

      // Fatigue state badge
      final snapshotJson = await binding.viterbiFatigueState(handle);
      final snapshot = jsonDecode(snapshotJson) as Map<String, dynamic>;
      d.fatigueState = snapshot['state']?.toString();

      // ---------- Zone 2: Today ----------

      // SessionWidget — FIXED: use real field names from engine schema
      final sessionWidgetJson = await binding.getSessionWidget(handle);
      final sessionWidget = jsonDecode(sessionWidgetJson);
      if (sessionWidget is Map) {
        d.workoutTitle = sessionWidget['workout_title']?.toString();
        d.durationMin = sessionWidget['duration_min'] as int?;
        d.sessionZone = sessionWidget['zone']?.toString();
        d.targetWatts = sessionWidget['target_watts'] as int?;
        d.targetPaceMss = sessionWidget['target_pace_mss']?.toString();
        d.focusCue = sessionWidget['focus_cue']?.toString();
        d.rationaleProse = sessionWidget['rationale_prose']?.toString();
      }

      // Zone cap
      final zoneJson = await binding.zoneCapWithAdvisories(handle);
      final zone = jsonDecode(zoneJson) as Map<String, dynamic>;
      d.zoneCap = zone['zone']?.toString();

      // ---------- Zone 3: Context ----------

      // ContextWidget — FIXED: use real field names from engine schema
      final contextWidgetJson = await binding.getContextWidget(handle);
      final contextWidget = jsonDecode(contextWidgetJson);
      if (contextWidget is Map) {
        d.acwr = (contextWidget['acwr'] as num?)?.toDouble();
        d.acwrZone = contextWidget['acwr_zone']?.toString();
        d.acwrRecommendation = contextWidget['acwr_recommendation']?.toString();
        d.monotony = (contextWidget['monotony'] as num?)?.toDouble();
        d.strain = (contextWidget['strain'] as num?)?.toDouble();
        d.monotonyZone = contextWidget['monotony_zone']?.toString();
        d.monotonyRecommendation = contextWidget['monotony_recommendation']?.toString();
        d.lastWorkout = contextWidget['last_workout']?.toString();

        final alerts = contextWidget['reactive_alerts'];
        if (alerts is List) {
          d.reactiveAlerts = alerts.map((e) => e.toString()).toList();
        }
        final advisories = contextWidget['pattern_advisories'];
        if (advisories is List) {
          d.patternAdvisories = advisories.map((e) => e.toString()).toList();
        }
      }

      // Readiness history sparkline (14 days)
      // FIXED: use 'readiness_score' not 'score'
      final historyJson = await binding.readReadinessHistory(handle, days: 14);
      final history = jsonDecode(historyJson);
      if (history is List) {
        d.historyScores = history
            .map((e) {
              if (e is Map) {
                final s = e['readiness_score']; // FIXED: was 'score'
                if (s is num) return s.toDouble();
              }
              return null;
            })
            .whereType<double>()
            .toList();
      }

      // Source tier swatch
      final tierJson = await binding.lastObservationSourceTier(handle);
      d.sourceTier = sourceTierFromEngine(jsonDecode(tierJson));
    } catch (e) {
      d.error = '${e.runtimeType}: $e';
    }
    if (!mounted) return;
    setState(() {
      _data = d;
      _loading = false;
      _handle = localHandle;
      _binding = localBinding;
    });
  }

  void _openReadinessDetail() {
    final handle = _handle;
    final binding = _binding;
    if (handle == null || binding == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReadinessDetailScreen(
          handle: handle,
          binding: binding,
        ),
      ),
    );
  }

  void _openDebugExerciser() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const DebugSwatchExerciser()),
    );
  }

  void _openV10Spike() {
    Navigator.of(context).pushNamed('/v10-spike');
  }

  Future<void> _openManualEntry() async {
    final handle = _handle;
    final binding = _binding;
    if (handle == null || binding == null) return;

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ManualEntryScreen(
          binding: binding,
          handle: handle,
        ),
      ),
    );

    // Refresh data if manual entry was submitted
    if (result == true && mounted) {
      setState(() => _loading = true);
      _fetch();
    }
  }

  void _openAdvisor() {
    final handle = _handle;
    final binding = _binding;
    if (handle == null || binding == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdvisorScreen(
          binding: binding,
          handle: handle,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MivaltaColors.surfaceBackground, // Dark-first per UI_UX_DIRECTION
      appBar: AppBar(
        backgroundColor: MivaltaColors.surfaceBackground,
        foregroundColor: MivaltaColors.textPrimary,
        title: const Text('MiValta'),
        actions: kDebugMode
            ? [
                PopupMenuButton<String>(
                  icon: const Icon(Icons.bug_report),
                  tooltip: 'Debug tools',
                  onSelected: (value) {
                    switch (value) {
                      case 'swatch':
                        _openDebugExerciser();
                      case 'v10':
                        _openV10Spike();
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'swatch',
                      child: Text('SourceTier exerciser'),
                    ),
                    PopupMenuItem(
                      value: 'v10',
                      child: Text('V10.1 LLM spike'),
                    ),
                  ],
                ),
              ]
            : null,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _ThreeZoneHome(
              data: _data,
              onTapRing: _openReadinessDetail,
              onTapAdvisor: _openAdvisor,
            ),
      // PR-D: FAB for manual entry
      floatingActionButton: _loading
          ? null
          : FloatingActionButton(
              onPressed: _openManualEntry,
              backgroundColor: MivaltaColors.primaryGreen,
              foregroundColor: MivaltaColors.textPrimary,
              tooltip: 'Log today',
              child: const Icon(Icons.add),
            ),
    );
  }
}

class _ThreeZoneHome extends StatelessWidget {
  const _ThreeZoneHome({
    required this.data,
    required this.onTapRing,
    required this.onTapAdvisor,
  });
  final _HomeData data;
  final VoidCallback onTapRing;
  final VoidCallback onTapAdvisor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Theme is wired via mivaltaDarkTheme() in main.dart — no inline color overrides.
    final textTheme = theme.textTheme;

    final err = data.error;
    if (err != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(MivaltaSpace.x5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error, color: theme.colorScheme.error, size: 48),
              const SizedBox(height: MivaltaSpace.x4),
              SelectableText(err, style: textTheme.bodyMedium),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: MivaltaSpace.x5,
        vertical: MivaltaSpace.x4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ============ ZONE 1: STATE (HERO) ============
          _Zone1State(data: data, textTheme: textTheme, onTapRing: onTapRing),
          const SizedBox(height: MivaltaSpace.x6),

          // ============ ZONE 2: TODAY ============
          _Zone2Today(data: data, textTheme: textTheme, onTapAdvisor: onTapAdvisor),
          const SizedBox(height: MivaltaSpace.x6),

          // ============ ZONE 3: CONTEXT ============
          _Zone3Context(data: data, textTheme: textTheme),
          const SizedBox(height: MivaltaSpace.x5),
        ],
      ),
    );
  }
}

/// Zone 1 — State (hero): ReadinessRing + state_recommendation + fatigue badge
class _Zone1State extends StatelessWidget {
  const _Zone1State({
    required this.data,
    required this.textTheme,
    required this.onTapRing,
  });
  final _HomeData data;
  final TextTheme textTheme;
  final VoidCallback onTapRing;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Hero ring (or F1 no-data copy) — tap to open detail screen
        Center(
          child: GestureDetector(
            onTap: data.insufficientData ? null : onTapRing,
            child: ReadinessRing(
              score: data.readinessScore,
              level: data.readinessLevel,
              confidence: data.confidence,
              noData: data.insufficientData,
            ),
          ),
        ),
        const SizedBox(height: MivaltaSpace.x4),

        // State recommendation prose (verbatim from engine)
        if (data.stateRecommendation != null &&
            data.stateRecommendation!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: MivaltaSpace.x4),
            child: Text(
              data.stateRecommendation!,
              style: textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),

        // Confidence advisory (honest-confidence, shown when non-null)
        if (data.confidenceAdvisory != null &&
            data.confidenceAdvisory!.isNotEmpty) ...[
          const SizedBox(height: MivaltaSpace.x2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: MivaltaSpace.x4),
            child: Text(
              data.confidenceAdvisory!,
              style: textTheme.bodySmall?.copyWith(color: MivaltaColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ),
        ],
        const SizedBox(height: MivaltaSpace.x3),

        // Fatigue state badge — color via fatigueStateColor() from tokens.dart
        if (data.fatigueState != null)
          _Badge(
            label: _humanizeFatigueState(data.fatigueState),
            color: fatigueStateColor(data.fatigueState),
          ),
      ],
    );
  }
}

/// Zone 2 — Today: SessionWidget fields + zone cap
class _Zone2Today extends StatelessWidget {
  const _Zone2Today({
    required this.data,
    required this.textTheme,
    required this.onTapAdvisor,
  });
  final _HomeData data;
  final TextTheme textTheme;
  final VoidCallback onTapAdvisor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TODAY',
          style: textTheme.labelSmall?.copyWith(
            letterSpacing: 1.2,
            color: MivaltaColors.textMuted,
          ),
        ),
        const SizedBox(height: MivaltaSpace.x3),

        // Zone cap chip
        if (data.zoneCap != null)
          _Badge(
            label: 'Up to ${data.zoneCap}',
            color: MivaltaColors.textMuted,
          ),
        const SizedBox(height: MivaltaSpace.x4),

        // Workout card (from SessionWidget real fields)
        if (data.workoutTitle != null)
          Container(
            padding: const EdgeInsets.all(MivaltaSpace.x4),
            decoration: BoxDecoration(
              color: MivaltaColors.surface1,
              borderRadius: BorderRadius.circular(MivaltaRadii.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title + duration
                Row(
                  children: [
                    Icon(Icons.fitness_center, color: MivaltaColors.textSecondary),
                    const SizedBox(width: MivaltaSpace.x3),
                    Expanded(
                      child: Text(
                        data.workoutTitle!,
                        style: textTheme.titleMedium,
                      ),
                    ),
                    if (data.durationMin != null)
                      Text(
                        '${data.durationMin} min',
                        style: textTheme.bodySmall?.copyWith(
                          color: MivaltaColors.textMuted,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: MivaltaSpace.x2),

                // Zone + target
                Row(
                  children: [
                    if (data.sessionZone != null)
                      _Badge(label: data.sessionZone!, color: MivaltaColors.textMuted),
                    const SizedBox(width: MivaltaSpace.x2),
                    if (data.targetWatts != null)
                      Text(
                        '${data.targetWatts}W',
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else if (data.targetPaceMss != null)
                      Text(
                        data.targetPaceMss!,
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),

                // Focus cue
                if (data.focusCue != null && data.focusCue!.isNotEmpty) ...[
                  const SizedBox(height: MivaltaSpace.x3),
                  Text(
                    data.focusCue!,
                    style: textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],

                // Rationale prose (the "why")
                if (data.rationaleProse != null &&
                    data.rationaleProse!.isNotEmpty) ...[
                  const SizedBox(height: MivaltaSpace.x2),
                  Text(
                    data.rationaleProse!,
                    style: textTheme.bodySmall?.copyWith(color: MivaltaColors.textMuted),
                  ),
                ],
              ],
            ),
          ),

        // PR-D: "See Options" button to open advisor
        const SizedBox(height: MivaltaSpace.x4),
        OutlinedButton(
          onPressed: onTapAdvisor,
          style: OutlinedButton.styleFrom(
            foregroundColor: MivaltaColors.textSecondary,
            side: const BorderSide(color: MivaltaColors.surface2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(MivaltaRadii.sm),
            ),
          ),
          child: Text(
            'See workout options',
            style: textTheme.labelLarge?.copyWith(
              color: MivaltaColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Zone 3 — Context: ACWR/monotony/strain + alerts + sparkline + source tier
class _Zone3Context extends StatelessWidget {
  const _Zone3Context({required this.data, required this.textTheme});
  final _HomeData data;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CONTEXT',
          style: textTheme.labelSmall?.copyWith(
            letterSpacing: 1.2,
            color: MivaltaColors.textMuted,
          ),
        ),
        const SizedBox(height: MivaltaSpace.x3),

        // Sparkline (14-day history)
        if (data.historyScores.isNotEmpty)
          SizedBox(
            height: 40,
            child: _Sparkline(scores: data.historyScores),
          ),
        const SizedBox(height: MivaltaSpace.x4),

        // ACWR block
        if (data.acwr != null) ...[
          _MetricRow(
            label: 'ACWR',
            value: data.acwr!.toStringAsFixed(2),
            zone: data.acwrZone,
            textTheme: textTheme,
          ),
          if (data.acwrRecommendation != null &&
              data.acwrRecommendation!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(
                top: MivaltaSpace.x1,
                bottom: MivaltaSpace.x2,
              ),
              child: Text(
                data.acwrRecommendation!,
                style: textTheme.bodySmall?.copyWith(color: MivaltaColors.textMuted),
              ),
            ),
        ],

        // Monotony + Strain block
        if (data.monotony != null || data.strain != null) ...[
          Row(
            children: [
              if (data.monotony != null)
                Expanded(
                  child: _MetricRow(
                    label: 'Monotony',
                    value: data.monotony!.toStringAsFixed(2),
                    zone: data.monotonyZone,
                    textTheme: textTheme,
                  ),
                ),
              if (data.strain != null)
                Expanded(
                  child: _MetricRow(
                    label: 'Strain',
                    value: data.strain!.toStringAsFixed(0),
                    zone: null,
                    textTheme: textTheme,
                  ),
                ),
            ],
          ),
          if (data.monotonyRecommendation != null &&
              data.monotonyRecommendation!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(
                top: MivaltaSpace.x1,
                bottom: MivaltaSpace.x2,
              ),
              child: Text(
                data.monotonyRecommendation!,
                style: textTheme.bodySmall?.copyWith(color: MivaltaColors.textMuted),
              ),
            ),
        ],

        // Last workout
        if (data.lastWorkout != null && data.lastWorkout!.isNotEmpty) ...[
          const SizedBox(height: MivaltaSpace.x2),
          Text(
            'Last: ${data.lastWorkout}',
            style: textTheme.bodySmall?.copyWith(color: MivaltaColors.textMuted),
          ),
        ],

        // Reactive alerts (verbatim list)
        if (data.reactiveAlerts.isNotEmpty) ...[
          const SizedBox(height: MivaltaSpace.x3),
          for (final alert in data.reactiveAlerts)
            Padding(
              padding: const EdgeInsets.only(bottom: MivaltaSpace.x1),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber,
                      size: 16, color: MivaltaColors.cautionYellow),
                  const SizedBox(width: MivaltaSpace.x2),
                  Expanded(
                    child: Text(alert, style: textTheme.bodySmall),
                  ),
                ],
              ),
            ),
        ],

        // Pattern advisories (verbatim list)
        if (data.patternAdvisories.isNotEmpty) ...[
          const SizedBox(height: MivaltaSpace.x2),
          for (final advisory in data.patternAdvisories)
            Padding(
              padding: const EdgeInsets.only(bottom: MivaltaSpace.x1),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline,
                      size: 16, color: MivaltaColors.textMuted),
                  const SizedBox(width: MivaltaSpace.x2),
                  Expanded(
                    child: Text(
                      advisory,
                      style: textTheme.bodySmall?.copyWith(color: MivaltaColors.textMuted),
                    ),
                  ),
                ],
              ),
            ),
        ],

        const SizedBox(height: MivaltaSpace.x3),

        // Source tier swatch
        Row(
          children: [
            Text(
              'Data source: ',
              style: textTheme.bodySmall?.copyWith(color: MivaltaColors.textMuted),
            ),
            if (data.sourceTier != null)
              _SourceTierChip(tier: data.sourceTier!)
            else
              Text(
                'No data yet',
                style: textTheme.bodySmall?.copyWith(color: MivaltaColors.textMuted),
              ),
          ],
        ),
      ],
    );
  }
}

/// Metric row for ACWR/monotony/strain display
class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.value,
    required this.zone,
    required this.textTheme,
  });
  final String label;
  final String value;
  final String? zone;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: textTheme.bodySmall?.copyWith(color: MivaltaColors.textMuted),
        ),
        Text(
          value,
          style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        if (zone != null) ...[
          const SizedBox(width: MivaltaSpace.x2),
          _Badge(label: zone!, color: _zoneColor(zone)),
        ],
      ],
    );
  }

  /// Zone color from token constants. Maps ACWR/monotony zone strings to the
  /// appropriate level color. Engine decides the zone; we just render it.
  Color _zoneColor(String? zone) {
    switch (zone?.toLowerCase()) {
      case 'optimal':
      case 'green':
        return MivaltaColors.levelGreen;
      case 'caution':
      case 'yellow':
        return MivaltaColors.levelYellow;
      case 'danger':
      case 'red':
        return MivaltaColors.levelRed;
      default:
        return MivaltaColors.textMuted;
    }
  }
}

/// Simple badge chip
class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MivaltaSpace.x3,
        vertical: MivaltaSpace.x1 + 2, // 6.0
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(MivaltaRadii.lg),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w500),
      ),
    );
  }
}

/// Source tier chip using LOCKED tokens from source_tier.dart
class _SourceTierChip extends StatelessWidget {
  const _SourceTierChip({required this.tier});
  final SourceTier tier;

  @override
  Widget build(BuildContext context) {
    final color = kSourceTierColor[tier]!;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MivaltaSpace.x2,
        vertical: MivaltaSpace.x1,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(MivaltaRadii.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: MivaltaSpace.x2,
            height: MivaltaSpace.x2,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: MivaltaSpace.x1 + 2), // 6.0
          Text(
            kSourceTierLabel[tier]!,
            style: TextStyle(color: color, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Simple sparkline for readiness history
class _Sparkline extends StatelessWidget {
  const _Sparkline({required this.scores});
  final List<double> scores;

  @override
  Widget build(BuildContext context) {
    if (scores.isEmpty) return const SizedBox.shrink();

    return CustomPaint(
      painter: _SparklinePainter(scores: scores),
      size: const Size(double.infinity, 40),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.scores});
  final List<double> scores;

  @override
  void paint(Canvas canvas, Size size) {
    if (scores.isEmpty) return;

    final paint = Paint()
      ..color = MivaltaColors.levelGreen
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final minScore = scores.reduce((a, b) => a < b ? a : b);
    final maxScore = scores.reduce((a, b) => a > b ? a : b);
    final range = maxScore - minScore;

    final path = Path();
    for (var i = 0; i < scores.length; i++) {
      final x = (i / (scores.length - 1)) * size.width;
      final normalized = range > 0 ? (scores[i] - minScore) / range : 0.5;
      final y = size.height - (normalized * size.height * 0.8) - size.height * 0.1;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

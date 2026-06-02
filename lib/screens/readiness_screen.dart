// PR-B: Three-zone PULL home. Display only — every value comes verbatim from
// engine output via the FRB methods bound in PR-A. No thresholds, no math,
// no fallback logic in Dart.
//
// Three zones per UI_UX_DIRECTION.md v1.1 (dark-first, calm, honest, agency):
//   Zone 1 — State (hero): ReadinessRing + getStateWidget prose + fatigue badge
//   Zone 2 — Today: getSessionWidget + zone cap chip + recommended workout
//   Zone 3 — Context: getContextWidget + sparkline + source tier swatch
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
import '../widgets/readiness_ring.dart';
import 'debug_swatch_exerciser.dart';

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
  int? readinessScore;       // FIXED: from indicator['score'], rounded
  String? readinessLevel;    // indicator['level'] verbatim
  double? confidence;        // indicator['confidence']
  String? stateWidgetProse;  // getStateWidget() verbatim
  String? fatigueState;      // viterbiFatigueState().state

  // Zone 2 — Today
  String? sessionWidgetProse; // getSessionWidget() verbatim
  String? zoneCap;            // zoneCapWithAdvisories().zone
  String? workoutTitle;       // recommendWorkout()[0].title
  String? workoutZone;        // recommendWorkout()[0].zone

  // Zone 3 — Context
  String? contextWidgetProse; // getContextWidget() verbatim
  List<double> historyScores = const []; // readReadinessHistory sparkline
  SourceTier? sourceTier;     // lastObservationSourceTier()

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
    try {
      final binding = await RustEngineBinding.bootstrap();
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

      final EnginesHandle handle;
      if (persistedState != null) {
        // Subsequent launch: restore from persisted state
        handle = await binding.constructEnginesFromState(
          athleteProfileJson: profileJson,
          tablesJson: tablesJson,
          vaultPath: vaultDir.path,
          viterbiStateJson: persistedState,
        );
      } else {
        // First run: construct fresh and persist immediately
        handle = await binding.constructEnginesFresh(
          athleteProfileJson: profileJson,
          tablesJson: tablesJson,
          vaultPath: vaultDir.path,
        );
        // Persist immediately so next launch can restore
        final stateJson = await binding.saveState(handle);
        await binding.writeViterbiState(handle, stateJson: stateJson);
      }

      // ---------- Zone 1: State (hero) ----------

      // FIXED (PR-B): readiness_indicator — the 4-axis blend headline
      // The hero number is 'score' (a float), NOT 'blend'.
      final indicatorJson = await binding.readinessIndicator(handle);
      final indicator = jsonDecode(indicatorJson) as Map<String, dynamic>;
      final num? score = indicator['score'] as num?; // FIXED: was 'blend' as int?
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

      // State widget prose (verbatim)
      final stateWidgetJson = await binding.getStateWidget(handle);
      final stateWidget = jsonDecode(stateWidgetJson);
      if (stateWidget is Map) {
        d.stateWidgetProse = stateWidget['prose']?.toString();
      }

      // Fatigue state badge
      final snapshotJson = await binding.viterbiFatigueState(handle);
      final snapshot = jsonDecode(snapshotJson) as Map<String, dynamic>;
      d.fatigueState = snapshot['state']?.toString();

      // ---------- Zone 2: Today ----------

      // Session widget prose (verbatim)
      final sessionWidgetJson = await binding.getSessionWidget(handle);
      final sessionWidget = jsonDecode(sessionWidgetJson);
      if (sessionWidget is Map) {
        d.sessionWidgetProse = sessionWidget['prose']?.toString();
      }

      // Zone cap
      final zoneJson = await binding.zoneCapWithAdvisories(handle);
      final zone = jsonDecode(zoneJson) as Map<String, dynamic>;
      d.zoneCap = zone['zone']?.toString();

      // Recommended workout
      final workoutsJson = await binding.recommendWorkout(handle);
      final workouts = jsonDecode(workoutsJson);
      if (workouts is List && workouts.isNotEmpty) {
        final first = workouts.first;
        if (first is Map) {
          d.workoutTitle = first['title']?.toString();
          d.workoutZone = first['zone']?.toString();
        }
      }

      // ---------- Zone 3: Context ----------

      // Context widget prose (verbatim)
      final contextWidgetJson = await binding.getContextWidget(handle);
      final contextWidget = jsonDecode(contextWidgetJson);
      if (contextWidget is Map) {
        d.contextWidgetProse = contextWidget['prose']?.toString();
      }

      // Readiness history sparkline (14 days)
      final historyJson = await binding.readReadinessHistory(handle, days: 14);
      final history = jsonDecode(historyJson);
      if (history is List) {
        d.historyScores = history
            .map((e) {
              if (e is Map) {
                final s = e['score'];
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
    });
  }

  void _openDebugExerciser() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const DebugSwatchExerciser()),
    );
  }

  void _openV10Spike() {
    Navigator.of(context).pushNamed('/v10-spike');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Dark-first per UI_UX_DIRECTION
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
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
          : _ThreeZoneHome(data: _data),
    );
  }
}

class _ThreeZoneHome extends StatelessWidget {
  const _ThreeZoneHome({required this.data});
  final _HomeData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme.apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
    );

    final err = data.error;
    if (err != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error, color: theme.colorScheme.error, size: 48),
              const SizedBox(height: 16),
              SelectableText(err, style: textTheme.bodyMedium),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ============ ZONE 1: STATE (HERO) ============
          _Zone1State(data: data, textTheme: textTheme),
          const SizedBox(height: 32),

          // ============ ZONE 2: TODAY ============
          _Zone2Today(data: data, textTheme: textTheme),
          const SizedBox(height: 32),

          // ============ ZONE 3: CONTEXT ============
          _Zone3Context(data: data, textTheme: textTheme),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Zone 1 — State (hero): ReadinessRing + prose + fatigue badge
class _Zone1State extends StatelessWidget {
  const _Zone1State({required this.data, required this.textTheme});
  final _HomeData data;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Hero ring (or F1 no-data copy)
        Center(
          child: ReadinessRing(
            score: data.readinessScore,
            level: data.readinessLevel,
            confidence: data.confidence,
            noData: data.insufficientData,
          ),
        ),
        const SizedBox(height: 16),

        // State widget prose (verbatim)
        if (data.stateWidgetProse != null && data.stateWidgetProse!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              data.stateWidgetProse!,
              style: textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
        const SizedBox(height: 12),

        // Fatigue state badge
        if (data.fatigueState != null)
          _Badge(
            label: _humanizeFatigueState(data.fatigueState),
            color: _fatigueStateColor(data.fatigueState),
          ),
      ],
    );
  }

  Color _fatigueStateColor(String? state) {
    switch (state?.toLowerCase()) {
      case 'recovered':
        return const Color(0xFF2BD974);
      case 'productive':
        return const Color(0xFF00C6A7);
      case 'accumulated':
        return const Color(0xFFE8C547);
      case 'overreached':
        return const Color(0xFFE6872F);
      case 'illnessrisk':
        return const Color(0xFFE5484D);
      default:
        return Colors.grey;
    }
  }
}

/// Zone 2 — Today: session prose + zone cap chip + recommended workout
class _Zone2Today extends StatelessWidget {
  const _Zone2Today({required this.data, required this.textTheme});
  final _HomeData data;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TODAY',
          style: textTheme.labelSmall?.copyWith(
            letterSpacing: 1.2,
            color: Colors.white54,
          ),
        ),
        const SizedBox(height: 12),

        // Zone cap chip
        if (data.zoneCap != null)
          _Badge(
            label: 'Today: up to ${data.zoneCap}',
            color: Colors.white24,
          ),
        const SizedBox(height: 12),

        // Session widget prose (verbatim)
        if (data.sessionWidgetProse != null &&
            data.sessionWidgetProse!.isNotEmpty)
          Text(
            data.sessionWidgetProse!,
            style: textTheme.bodyMedium,
          ),
        const SizedBox(height: 12),

        // Recommended workout
        if (data.workoutTitle != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.fitness_center, color: Colors.white70),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.workoutTitle!,
                        style: textTheme.titleMedium,
                      ),
                      if (data.workoutZone != null)
                        Text(
                          'Intensity: ${data.workoutZone}',
                          style: textTheme.bodySmall?.copyWith(
                            color: Colors.white54,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Zone 3 — Context: context prose + sparkline + source tier
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
            color: Colors.white54,
          ),
        ),
        const SizedBox(height: 12),

        // Sparkline (14-day history)
        if (data.historyScores.isNotEmpty)
          SizedBox(
            height: 40,
            child: _Sparkline(scores: data.historyScores),
          ),
        const SizedBox(height: 12),

        // Context widget prose (verbatim)
        if (data.contextWidgetProse != null &&
            data.contextWidgetProse!.isNotEmpty)
          Text(
            data.contextWidgetProse!,
            style: textTheme.bodyMedium,
          ),
        const SizedBox(height: 12),

        // Source tier swatch
        Row(
          children: [
            Text(
              'Data source: ',
              style: textTheme.bodySmall?.copyWith(color: Colors.white54),
            ),
            if (data.sourceTier != null)
              _SourceTierChip(tier: data.sourceTier!)
            else
              Text(
                'No data yet',
                style: textTheme.bodySmall?.copyWith(color: Colors.white54),
              ),
          ],
        ),
      ],
    );
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w500),
      ),
    );
  }
}

/// Source tier chip using LOCKED tokens
class _SourceTierChip extends StatelessWidget {
  const _SourceTierChip({required this.tier});
  final SourceTier tier;

  @override
  Widget build(BuildContext context) {
    final color = kSourceTierColor[tier]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
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
      ..color = const Color(0xFF2BD974)
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

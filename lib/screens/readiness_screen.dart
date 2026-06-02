// MVP-1 readiness screen. Display only — every value comes verbatim from
// engine output via the FRB methods bound in PR-A. No thresholds,
// no math, no fallback logic in Dart.
//
// Six sections, top to bottom:
//   a. Readiness indicator      — readiness_indicator() — 4-axis blend headline
//   b. Readiness score          — readiness_score().score (legacy backup)
//   c. Fatigue state            — get_readiness().state
//   d. Zone cap + advisories    — zone_cap_with_advisories().zone +
//                                  readiness_score().advisories.recommendations[]
//   e. Recommended workout      — recommend_workout()[0].title + zone
//   f. Data source tier         — legend of the 4 LOCKED SourceTier swatches
//
// On insufficient data (no observations yet → advisories
// .last_observation_at == null) the F1 no-data line replaces section a.
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
import '../copy/f1.dart';
import '../rust_engine.dart';
import '../theme/source_tier.dart';
import 'debug_swatch_exerciser.dart';

class _ReadinessData {
  // MVP-1: readiness_indicator headline (4-axis blend)
  String? readinessLevel;
  int? readinessBlend;
  double? confidence;

  int? score;
  String? fatigueState;
  String? zoneCap;
  List<String> advisories = const <String>[];
  String? workoutTitle;
  String? workoutZone;
  bool insufficientData = false;
  String? error;
  // Parsed SourceTier from VaultEngine.last_observation_source_tier.
  // null ⇒ engine returned JSON null (no observations yet) ⇒ section
  // renders the F1 no-data copy. Some(tier) ⇒ section renders the
  // single LOCKED swatch for that tier.
  SourceTier? sourceTier;
}

class ReadinessScreen extends StatefulWidget {
  const ReadinessScreen({super.key});

  @override
  State<ReadinessScreen> createState() => _ReadinessScreenState();
}

class _ReadinessScreenState extends State<ReadinessScreen> {
  _ReadinessData _data = _ReadinessData();
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
    final d = _ReadinessData();
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

      // MVP-1: readiness_indicator — the 4-axis blend headline
      final indicatorJson = await binding.readinessIndicator(handle);
      final indicator = jsonDecode(indicatorJson) as Map<String, dynamic>;
      d.readinessLevel = indicator['level']?.toString();
      d.readinessBlend = indicator['blend'] as int?;
      d.confidence = (indicator['confidence'] as num?)?.toDouble();

      final readinessJson = await binding.readinessScore(handle);
      final readiness = jsonDecode(readinessJson) as Map<String, dynamic>;
      d.score = readiness['score'] as int?;
      final advisoriesObj = readiness['advisories'];
      if (advisoriesObj is Map) {
        // No observation yet ⇒ insufficient data per the engine's own
        // "honest empty" contract on PendingAdvisories.
        d.insufficientData = advisoriesObj['last_observation_at'] == null;
        final recs = advisoriesObj['recommendations'];
        if (recs is List) {
          d.advisories = recs.map((e) => e.toString()).toList(growable: false);
        }
      }

      final snapshotJson = await binding.viterbiFatigueState(handle);
      final snapshot = jsonDecode(snapshotJson) as Map<String, dynamic>;
      d.fatigueState = snapshot['state']?.toString();

      final zoneJson = await binding.zoneCapWithAdvisories(handle);
      final zone = jsonDecode(zoneJson) as Map<String, dynamic>;
      d.zoneCap = zone['zone']?.toString();

      final workoutsJson = await binding.recommendWorkout(handle);
      final workouts = jsonDecode(workoutsJson);
      if (workouts is List && workouts.isNotEmpty) {
        final first = workouts.first;
        if (first is Map) {
          d.workoutTitle = first['title']?.toString();
          d.workoutZone = first['zone']?.toString();
        }
      }

      // Source tier of the most recent biometric. Raw JSON is
      // either a PascalCase variant string ("Medical" / "Device" /
      // "Partial" / "Manual") or `null` — see
      // VaultEngine::last_observation_source_tier in rust-engine.
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
    // Import the V10SpikeScreen from main.dart dynamically to avoid
    // circular imports. For now, we use a lazy import pattern.
    Navigator.of(context).pushNamed('/v10-spike');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Readiness'),
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
          : _ReadinessBody(data: _data),
    );
  }
}

class _ReadinessBody extends StatelessWidget {
  const _ReadinessBody({required this.data});
  final _ReadinessData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Local non-null capture before the closure — matches the Day-3
    // `_run()` snapshot pattern and removes the `!` operator entirely.
    // The closure now reasons about its own `err` binding, not the
    // mutable State field.
    final err = data.error;
    Widget engineDependent(Widget child) =>
        err != null ? _ErrorRow(message: err) : child;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // MVP-1: readiness_indicator is the headline (4-axis blend)
        _Section(
          label: 'Readiness (4-axis blend)',
          body: engineDependent(
            data.insufficientData
                ? Text(kF1NoDataCopy, style: theme.textTheme.bodyLarge)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(
                        data.readinessLevel ?? '—',
                        style: theme.textTheme.displaySmall,
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        'blend: ${data.readinessBlend ?? '—'} / confidence: ${data.confidence?.toStringAsFixed(2) ?? '—'}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 16),
        // Legacy readiness_score (kept for comparison)
        _Section(
          label: 'Readiness score (legacy)',
          body: engineDependent(
            SelectableText(
              data.score?.toString() ?? '—',
              style: theme.textTheme.headlineSmall,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _Section(
          label: 'Fatigue state',
          body: engineDependent(
            SelectableText(
              data.fatigueState ?? '—',
              style: theme.textTheme.headlineSmall,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _Section(
          label: 'Zone cap + advisories',
          body: engineDependent(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  data.zoneCap ?? '—',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                if (data.advisories.isEmpty)
                  Text('(no advisories yet)',
                      style: theme.textTheme.bodySmall)
                else
                  ...data.advisories
                      .map((a) => _AdvisoryBullet(text: a)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _Section(
          label: 'Recommended workout',
          body: engineDependent(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  data.workoutTitle ?? '—',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                SelectableText(
                  'intensity: ${data.workoutZone ?? '—'}',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _Section(
          label: 'Data source tier',
          body: engineDependent(SourceTierIndicator(tier: data.sourceTier)),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.body});
  final String label;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label.toUpperCase(),
            style: theme.textTheme.labelSmall
                ?.copyWith(letterSpacing: 1.2)),
        const SizedBox(height: 4),
        body,
      ],
    );
  }
}

class _AdvisoryBullet extends StatelessWidget {
  const _AdvisoryBullet({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• '),
          Expanded(child: SelectableText(text)),
        ],
      ),
    );
  }
}


class _ErrorRow extends StatelessWidget {
  const _ErrorRow({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.error, color: theme.colorScheme.error),
        const SizedBox(width: 8),
        Expanded(child: SelectableText(message)),
      ],
    );
  }
}

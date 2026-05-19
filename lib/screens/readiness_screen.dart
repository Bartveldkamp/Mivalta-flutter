// F1 readiness screen. Display only — every value comes verbatim from
// engine output via the 6 FRB methods bound on Day 3. No thresholds,
// no math, no fallback logic in Dart.
//
// Five sections, top to bottom:
//   a. Readiness score          — readiness_score().score
//   b. Fatigue state            — get_readiness().state
//   c. Zone cap + advisories    — zone_cap_with_advisories().zone +
//                                  readiness_score().advisories.recommendations[]
//   d. Recommended workout      — recommend_workout()[0].title + zone
//   e. Data source tier         — legend of the 4 LOCKED SourceTier
//                                  swatches. The engine does NOT yet
//                                  return which tier applies to the
//                                  current state — see PR body
//                                  ESCALATE note.
//
// On insufficient data (no observations yet → advisories
// .last_observation_at == null) the F1 no-data line replaces section a.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import '../canonical_seed.dart';
import '../copy/f1.dart';
import '../rust_engine.dart';
import '../theme/source_tier.dart';

class _ReadinessData {
  int? score;
  String? fatigueState;
  String? zoneCap;
  List<String> advisories = const <String>[];
  String? workoutTitle;
  String? workoutZone;
  bool insufficientData = false;
  String? error;
  // Day-5: parsed SourceTier from VaultEngine.last_observation_source_tier.
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
      final vaultDir = Directory('${support.path}/day4-vault');
      if (!await vaultDir.exists()) await vaultDir.create(recursive: true);
      final handle = await binding.constructEngines(
        athleteProfileJson: CanonicalSeed.vaultProfileJson(),
        tablesJson: tablesJson,
        vaultPath: vaultDir.path,
      );

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

      // Day-5: source tier of the most recent biometric. Raw JSON is
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Readiness')),
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
        _Section(
          label: 'Readiness score',
          body: engineDependent(
            data.insufficientData
                ? Text(kF1NoDataCopy, style: theme.textTheme.bodyLarge)
                : SelectableText(
                    data.score?.toString() ?? '—',
                    style: theme.textTheme.displayMedium,
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

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
//
// **PR-F**: Now accepts profileJson as a constructor parameter (from onboarding
// or loaded from persistence) instead of using the hardcoded canonical_seed.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import '../models/activity_summary.dart';
import '../rust_engine.dart';
import '../services/health_ingest.dart';
import '../theme/source_tier.dart';
import '../theme/tokens.dart';
import '../widgets/josi_presenter.dart';
import '../widgets/readiness_ring.dart';
import 'advisor_screen.dart';
import 'explore_screen.dart';
import 'debug_swatch_exerciser.dart';
import 'manual_entry_screen.dart';
import 'readiness_detail_screen.dart';
import 'settings_screen.dart';

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

/// PR-F: Fallback profile if none provided (should not happen in production).
/// This is a minimal profile that satisfies the engine's required fields.
/// In practice, onboarding always provides a profile before ReadinessScreen.
String _fallbackProfile() {
  return jsonEncode({
    'athlete_id': 'fallback-user',
    'age': 30,
    'sex': 'male',
    'level': 'intermediate',
    'goal_type': 'general_fitness',
    'goal_class': 'stay_fit',
    'sport': 'cycling',
    'weekly_hours': 5.0,
    'training_years': 1,
    'recent_activity': 'trained',
    'threshold_hr': null,
    'ftp_watts': null,
    'threshold_pace_sec_km': null,
    'power_profile': null,
    'meso_length': 21,
    'meso_train_days': [0, 1, 2, 3, 4],
    'meso_off_days': [5, 6],
    'meso_minutes': 300,
    'availability': <String, int>{},
  });
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
  double? todayLoad;             // readDailyLoads()[today] — cumulative load today

  // Item 2: Latest completed workout (for home workout row)
  ActivitySummary? latestActivity; // readRecentActivities(limit: 1)[0]

  // State
  bool insufficientData = false;
  String? error;
  // FL-3: set when a corrupt/incompatible persisted blob forced a fresh
  // start. Surfaced once (non-silent), never swallowed.
  bool historyReset = false;
}

class ReadinessScreen extends StatefulWidget {
  /// PR-F: Accept profileJson from onboarding or persistence.
  /// The profile is used to construct engines — no longer uses canonical_seed.
  /// FL-16: this is always a COMPLETE AthleteProfile — a fresh onboarding is
  /// engine-completed in main.dart before this screen is shown.
  const ReadinessScreen({super.key, this.profileJson});

  /// The athlete profile JSON. If null, falls back to a minimal default
  /// (should not happen in production — onboarding always provides a profile).
  final String? profileJson;

  @override
  State<ReadinessScreen> createState() => _ReadinessScreenState();
}

class _ReadinessScreenState extends State<ReadinessScreen>
    with WidgetsBindingObserver {
  _HomeData _data = _HomeData();
  bool _loading = true;
  bool _syncing = false;

  // PR-C: Store handle and binding for navigation to detail screen
  EnginesHandle? _handle;
  RustEngineBinding? _binding;

  // PR-E: Health ingest service for auto-sync
  HealthIngestService? _healthService;

  @override
  void initState() {
    super.initState();
    // FL-6: persist engine state on background/detach, not only on explicit
    // state-changing ops — an OS kill between a mutation and its save would
    // otherwise lose the advance.
    WidgetsBinding.instance.addObserver(this);
    _fetch();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // The callback is synchronous, so this is a fire-and-forget async save.
      // `paused` is the reliable window (the app is backgrounded but alive);
      // on `detached` the isolate may be torn down before the write completes,
      // so that path is genuinely best-effort, not a guarantee (#52 review).
      final handle = _handle;
      final binding = _binding;
      if (handle != null && binding != null) {
        () async {
          try {
            final stateJson = await binding.saveState(handle);
            await binding.writeViterbiState(handle, stateJson: stateJson);
          } catch (e) {
            if (kDebugMode) {
              // ignore: avoid_print
              print('lifecycle save failed — ${e.runtimeType}: $e');
            }
          }
        }();
      }
    }
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

      // PR-F: Use the provided profile JSON (from onboarding or persistence).
      // FL-16: a fresh onboarding profile is engine-completed in main.dart
      // before this screen, so `profileJson` is always a complete profile here.
      final profileJson = widget.profileJson ?? _fallbackProfile();

      // Continuity: check for persisted state and restore if it exists
      final persistedState = await binding.readPersistedState(
        athleteProfileJson: profileJson,
        vaultPath: vaultDir.path,
      );

      if (persistedState != null) {
        // Subsequent launch: restore from persisted state.
        // FL-3: a corrupt/legacy/incompatible blob must NOT brick every
        // relaunch. If restore throws, fall back to a fresh engine, OVERWRITE
        // the bad blob so the next launch restores cleanly, and surface a
        // one-time "history reset" notice (not silent).
        try {
          localHandle = await binding.constructEnginesFromState(
            athleteProfileJson: profileJson,
            tablesJson: tablesJson,
            vaultPath: vaultDir.path,
            viterbiStateJson: persistedState,
          );
        } catch (e) {
          // Capture WHY the restore failed before discarding the blob, so a
          // field "history reset" is diagnosable rather than mysterious
          // (#51 review).
          if (kDebugMode) {
            // ignore: avoid_print
            print('persisted-state restore failed — ${e.runtimeType}: $e');
          }
          localHandle = await binding.constructEnginesFresh(
            athleteProfileJson: profileJson,
            tablesJson: tablesJson,
            vaultPath: vaultDir.path,
          );
          final stateJson = await binding.saveState(localHandle);
          await binding.writeViterbiState(localHandle, stateJson: stateJson);
          d.historyReset = true;
        }
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

      // PR-E: Attempt health data auto-sync on launch (Android only for now).
      // Permission-denied or no-data is NOT an error — we just continue with
      // whatever state the engine already has. Zero-fabrication: if we can't
      // get real data, we don't pretend to have any.
      if (Platform.isAndroid) {
        final healthService = HealthIngestService(
          binding: binding,
          handle: handle,
        );
        _healthService = healthService;

        final syncResult = await healthService.syncHealthData(days: 7);
        if (kDebugMode &&
            (syncResult.observationsProcessed > 0 ||
                syncResult.skippedDays > 0)) {
          // ignore: avoid_print
          print('PR-E: Health sync processed '
              '${syncResult.observationsProcessed} days'
              '${syncResult.skippedDays > 0 ? ', skipped ${syncResult.skippedDays}' : ''}');
        }
      }

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

      // Today's load chip (Item 7) — engine-computed cumulative load for today
      // No Dart math: engine sums the day's load_uls; we just select today's row.
      final loadsJson = await binding.readDailyLoads(handle, days: 7);
      final loads = jsonDecode(loadsJson);
      if (loads is List && loads.isNotEmpty) {
        // Engine returns [[date, load], ...] most-recent-last; find today's row
        final todayStr = DateTime.now().toIso8601String().substring(0, 10);
        for (final row in loads.reversed) {
          if (row is List && row.length >= 2 && row[0] == todayStr) {
            d.todayLoad = (row[1] as num?)?.toDouble();
            break;
          }
        }
      }

      // Item 2: Latest completed workout for the home workout row
      // (time · load, tap to detail). Engine fetch, Dart display only.
      final activitiesJson = await binding.readRecentActivities(handle, limit: 1);
      final activities = ActivitySummary.listFromJson(jsonDecode(activitiesJson));
      if (activities.isNotEmpty) {
        d.latestActivity = activities.first;
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
    // FL-3: surface the one-time history reset non-silently after the frame.
    if (d.historyReset) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Saved history could not be read and was reset. '
              'Your recent trend will rebuild over the next few days.',
            ),
          ),
        );
      });
    }
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

  /// Open the on-request Explore view (biometrics + workout history).
  void _openExplore() {
    final handle = _handle;
    final binding = _binding;
    if (handle == null || binding == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ExploreScreen(
          binding: binding,
          handle: handle,
        ),
      ),
    );
  }

  /// Item 2: Open workout detail for a specific date.
  void _openWorkoutDetail(String date) {
    final handle = _handle;
    final binding = _binding;
    if (handle == null || binding == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _WorkoutDetailPage(
          binding: binding,
          handle: handle,
          date: date,
        ),
      ),
    );
  }

  /// PR-G: Open settings screen.
  void _openSettings() {
    final handle = _handle;
    final binding = _binding;
    if (handle == null || binding == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(
          binding: binding,
          handle: handle,
          profileJson: widget.profileJson ?? _fallbackProfile(),
          onDataCleared: () {
            // After data erasure, navigate back to the app entry point
            // which will detect no profile and show onboarding.
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
        ),
      ),
    );
  }

  /// PR-E: Manual health sync with permission request.
  /// Called when user taps the sync button. Requests permissions if needed,
  /// then syncs health data and refreshes the display.
  Future<void> _syncHealthData() async {
    if (!Platform.isAndroid) {
      // iOS not supported yet (PR-E.2)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Health sync coming to iOS soon')),
        );
      }
      return;
    }

    final handle = _handle;
    final binding = _binding;
    if (handle == null || binding == null) return;

    setState(() => _syncing = true);

    try {
      var healthService = _healthService;
      if (healthService == null) {
        healthService = HealthIngestService(binding: binding, handle: handle);
        _healthService = healthService;
      }

      // Check permissions first
      final hasPerms = await healthService.hasPermissions();
      if (!hasPerms) {
        // Request permissions
        final granted = await healthService.requestPermissions();
        if (!granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Health permissions required for auto-sync'),
              ),
            );
          }
          return;
        }
      }

      // Sync health data
      final result = await healthService.syncHealthData(days: 7);

      if (mounted) {
        if (result.success && result.observationsProcessed > 0) {
          // FL-4: surface skipped days so a partial sync is visible, not silent.
          final skipped = result.skippedDays > 0
              ? ' (${result.skippedDays} skipped)'
              : '';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Synced ${result.observationsProcessed} days of health data$skipped'),
            ),
          );
          // Refresh display with new data
          setState(() => _loading = true);
          _fetch();
        } else if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No new health data to sync')),
          );
        } else if (result.permissionDenied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Health permissions not granted')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Sync failed: ${result.error ?? "unknown error"}')),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _syncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MivaltaColors.surfaceBackground, // Dark-first per UI_UX_DIRECTION
      appBar: AppBar(
        backgroundColor: MivaltaColors.surfaceBackground,
        foregroundColor: MivaltaColors.textPrimary,
        title: const Text('MiValta'),
        actions: [
          // Explore — on-request biometrics + workout history
          if (!_loading)
            IconButton(
              icon: const Icon(Icons.insights_outlined),
              tooltip: 'Explore',
              onPressed: _openExplore,
            ),
          // PR-E: Health sync button (Android only for now)
          if (Platform.isAndroid && !_loading)
            _syncing
                ? const Padding(
                    padding: EdgeInsets.all(MivaltaSpace.x4),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.sync),
                    tooltip: 'Sync health data',
                    onPressed: _syncHealthData,
                  ),
          // PR-G: Settings button
          if (!_loading)
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Settings',
              onPressed: _openSettings,
            ),
          // Debug menu (debug mode only)
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.bug_report),
              tooltip: 'SourceTier exerciser',
              onPressed: _openDebugExerciser,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _ThreeZoneHome(
              data: _data,
              onTapRing: _openReadinessDetail,
              onTapAdvisor: _openAdvisor,
              onTapLatestWorkout: _openWorkoutDetail,
              onTapStartWorkout: _openAdvisor, // Item 6: start = advisor
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
    required this.onTapLatestWorkout,
    required this.onTapStartWorkout,
  });
  final _HomeData data;
  final VoidCallback onTapRing;
  final VoidCallback onTapAdvisor;
  final void Function(String date) onTapLatestWorkout; // Item 2
  final VoidCallback onTapStartWorkout;                // Item 6

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
          // ============ JOSI — PRESENTER (autocue) ============
          // Josi reads the situation; the zones below are the deeper layer.
          JosiPresenter(
            insufficientData: data.insufficientData,
            stateRecommendation: data.stateRecommendation,
            confidenceAdvisory: data.confidenceAdvisory,
            workoutTitle: data.workoutTitle,
            durationMin: data.durationMin,
            sessionZone: data.sessionZone,
            rationaleProse: data.rationaleProse,
          ),
          const SizedBox(height: MivaltaSpace.x5),

          // ============ ZONE 1: STATE (HERO) ============
          _Zone1State(data: data, textTheme: textTheme, onTapRing: onTapRing),
          const SizedBox(height: MivaltaSpace.x6),

          // ============ ZONE 2: TODAY ============
          _Zone2Today(data: data, textTheme: textTheme, onTapAdvisor: onTapAdvisor),
          const SizedBox(height: MivaltaSpace.x6),

          // ============ ZONE 3: CONTEXT ============
          _Zone3Context(
            data: data,
            textTheme: textTheme,
            onTapLatestWorkout: onTapLatestWorkout,
            onTapStartWorkout: onTapStartWorkout,
          ),
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

        // State recommendation prose (verbatim from engine). Founder feedback
        // 2026-06-12 item 1: with insufficient data the state layer says
        // NOTHING — no prior-based prose, no badge. Honest silence; the F1
        // copy in the ring is the only voice.
        if (!data.insufficientData &&
            data.stateRecommendation != null &&
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

        // Fatigue state badge + today's load chip (Item 7: load next to state)
        // Gated on data sufficiency (feedback item 1): no state from priors.
        if ((data.fatigueState != null || data.todayLoad != null) &&
            !data.insufficientData)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (data.fatigueState != null)
                _Badge(
                  label: _humanizeFatigueState(data.fatigueState),
                  color: fatigueStateColor(data.fatigueState),
                ),
              if (data.fatigueState != null && data.todayLoad != null)
                const SizedBox(width: MivaltaSpace.x2),
              // Today's load chip — engine value, no Dart math
              if (data.todayLoad != null)
                _Badge(
                  label: '${data.todayLoad!.round()} load',
                  color: MivaltaColors.textMuted,
                ),
            ],
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
  const _Zone3Context({
    required this.data,
    required this.textTheme,
    required this.onTapLatestWorkout,
    required this.onTapStartWorkout,
  });
  final _HomeData data;
  final TextTheme textTheme;
  final void Function(String date) onTapLatestWorkout; // Item 2
  final VoidCallback onTapStartWorkout;                // Item 6

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

        // Item 2: Latest workout row (tappable → detail)
        // Shows duration · load; replaces the old static "Last: ..." text
        if (data.latestActivity != null) ...[
          const SizedBox(height: MivaltaSpace.x2),
          _LatestWorkoutRow(
            activity: data.latestActivity!,
            onTap: () => onTapLatestWorkout(data.latestActivity!.date),
          ),
        ] else if (data.lastWorkout != null && data.lastWorkout!.isNotEmpty) ...[
          // Fallback to engine's lastWorkout string if no activity record yet
          const SizedBox(height: MivaltaSpace.x2),
          Text(
            'Last: ${data.lastWorkout}',
            style: textTheme.bodySmall?.copyWith(color: MivaltaColors.textMuted),
          ),
        ],

        // Item 6: Quick "start workout" link
        const SizedBox(height: MivaltaSpace.x3),
        GestureDetector(
          onTap: onTapStartWorkout,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.play_arrow, size: 18, color: MivaltaColors.primaryGreen),
              const SizedBox(width: MivaltaSpace.x1),
              Text(
                'Start a workout',
                style: textTheme.labelLarge?.copyWith(
                  color: MivaltaColors.primaryGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

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
    // Use Wrap to handle narrow constraints (e.g. when inside Expanded in the
    // Monotony/Strain row). Prevents 75px overflow on smaller screens.
    return Wrap(
      spacing: MivaltaSpace.x1,
      runSpacing: MivaltaSpace.x1,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          '$label: ',
          style: textTheme.bodySmall?.copyWith(color: MivaltaColors.textMuted),
        ),
        Text(
          value,
          style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        if (zone != null)
          _Badge(label: zone!, color: _zoneColor(zone)),
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
      // FL-7: a single-point series makes (i / (length-1)) = 0/0 = NaN and the
      // sparkline renders blank. Mirror the detail screen's guard: pin a lone
      // point to the left edge.
      final x = scores.length == 1
          ? 0.0
          : (i / (scores.length - 1)) * size.width;
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

/// Item 2: Tappable latest-workout row for the home. Shows duration · load.
/// Uses ActivitySummary from readRecentActivities(limit: 1).
class _LatestWorkoutRow extends StatelessWidget {
  const _LatestWorkoutRow({required this.activity, required this.onTap});

  final ActivitySummary activity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final meta = <String>[
      if (activity.durationMin != null) '${activity.durationMin} min',
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
                    'Latest workout',
                    style: textTheme.bodySmall?.copyWith(
                      color: MivaltaColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      activity.sport.isEmpty
                          ? 'Workout'
                          : _titleCase(activity.sport),
                      ...meta,
                    ].join('  ·  '),
                    style: textTheme.bodyMedium?.copyWith(
                      color: MivaltaColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
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

/// On-tap per-workout detail page — loads `get_workout_detail(date)` on demand.
/// (Shared pattern with ExploreScreen's _WorkoutDetailPage.)
class _WorkoutDetailPage extends StatelessWidget {
  const _WorkoutDetailPage({
    required this.binding,
    required this.handle,
    required this.date,
  });

  final RustEngineBinding binding;
  final EnginesHandle handle;
  final String date;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MivaltaColors.surfaceBackground,
      appBar: AppBar(
        backgroundColor: MivaltaColors.surfaceBackground,
        foregroundColor: MivaltaColors.textPrimary,
        title: const Text('Workout'),
      ),
      body: FutureBuilder<String>(
        future: binding.getWorkoutDetail(handle, date: date),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          Widget unavailable() => Center(
                child: Padding(
                  padding: const EdgeInsets.all(MivaltaSpace.x5),
                  child: Text(
                    'Workout detail unavailable.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: MivaltaColors.textMuted),
                  ),
                ),
              );
          if (snap.hasError || snap.data == null) {
            return unavailable();
          }
          // Parse defensively — schema drift would otherwise show a red screen.
          final dynamic decoded;
          try {
            decoded = jsonDecode(snap.data!);
          } catch (_) {
            return unavailable();
          }
          // Import the full card only when data is valid
          return SingleChildScrollView(
            padding: const EdgeInsets.all(MivaltaSpace.x4),
            child: _WorkoutDetailCard(detail: decoded),
          );
        },
      ),
    );
  }
}

/// Inline workout detail card — mirrors WorkoutDetailCard pattern but inline here
/// to keep the file self-contained for the home's on-tap detail flow.
class _WorkoutDetailCard extends StatelessWidget {
  const _WorkoutDetailCard({required this.detail});
  final dynamic detail;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final d = detail as Map<String, dynamic>?;
    if (d == null) return const SizedBox.shrink();

    final activityType = d['activity_type']?.toString() ?? 'Workout';
    final date = d['date']?.toString() ?? '';
    final durationMin = d['duration_minutes'] as int?;
    final avgHr = d['avg_heart_rate'] as int?;
    final loadUls = (d['load_uls'] as num?)?.toDouble();

    return Container(
      padding: const EdgeInsets.all(MivaltaSpace.x4),
      decoration: BoxDecoration(
        color: MivaltaColors.surface1,
        borderRadius: BorderRadius.circular(MivaltaRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            activityType.isEmpty
                ? 'Workout'
                : activityType[0].toUpperCase() + activityType.substring(1),
            style: textTheme.titleLarge?.copyWith(
              color: MivaltaColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: MivaltaSpace.x1),
          Text(
            date,
            style: textTheme.bodySmall?.copyWith(color: MivaltaColors.textMuted),
          ),
          const SizedBox(height: MivaltaSpace.x4),

          // Metrics row
          Row(
            children: [
              if (durationMin != null) ...[
                _MetricTile(label: 'Duration', value: '$durationMin min'),
                const SizedBox(width: MivaltaSpace.x4),
              ],
              if (avgHr != null) ...[
                _MetricTile(label: 'Avg HR', value: '$avgHr bpm'),
                const SizedBox(width: MivaltaSpace.x4),
              ],
              if (loadUls != null)
                _MetricTile(label: 'Load', value: '${loadUls.round()}'),
            ],
          ),
        ],
      ),
    );
  }
}

/// Simple metric tile for workout detail display.
class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(color: MivaltaColors.textMuted),
        ),
        Text(
          value,
          style: textTheme.bodyLarge?.copyWith(
            color: MivaltaColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

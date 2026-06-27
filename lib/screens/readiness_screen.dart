// PR-B: Three-zone PULL home. Display only — every value comes verbatim from
// engine output via the FRB methods bound in PR-A. No thresholds, no math,
// no fallback logic in Dart.
//
// Three zones per UI_UX_DIRECTION.md v1.1 (dark-first, calm, honest, agency):
//   Zone 1 — State (hero): ReadinessLightField (readiness-as-light, §17.2) +
//            state_recommendation prose + fatigue badge
//   Zone 2 — Today: SessionWidget fields (workout_title, zone, target, focus_cue, rationale)
//   Zone 3 — Context: alerts + sparkline + latest workout + source tier swatch
//   (step 3, HOME_REDESIGN_BRIEF §5: raw ACWR/monotony/strain moved OFF this
//   screen — the human-language today-facts tiles replace them; depth lives
//   in Explore)
//
// On insufficient data (the engine's readiness_indicator() returns zero
// confidence — it has not yet learned enough of this athlete to speak), Zone 1
// shows the LOCKED F1 copy instead of a ring. Zones 2/3 show their
// engine-provided empty prose. See [insufficientDataFromConfidence].
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

import '../copy/today_facts_labels.dart';
import '../copy/zone_labels.dart';
import '../models/activity_summary.dart';
import '../models/workout_option.dart';
import '../rust_engine.dart';
import '../services/ble/ble_hr_service.dart';
import '../services/ble/flutter_blue_transport.dart';
import '../services/health_ingest.dart';
import '../services/ingest_adapter.dart';
import '../services/today_tiles_prefs.dart';
import '../services/weather_service.dart';
import '../theme/source_tier.dart';
import '../theme/tokens.dart';
import '../widgets/josi_presenter.dart';
import '../widgets/readiness_light_field.dart';
import '../widgets/today_facts.dart';
import '../widgets/weather.dart';
import 'advisor_screen.dart';
import 'manual_entry_screen.dart';
import 'readiness_detail_screen.dart';
import 'sensor_check_screen.dart';
import 'workout_detail_page.dart';

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

/// The insufficient-data gate. Maps the engine's own no-data verdict to the
/// home's "we need more data" presentation — it is NOT a Dart threshold.
///
/// `ViterbiMonitor::readiness_indicator()` (gatc-viterbi) returns an explicit
/// no-data result — score 0, **confidence 0**, empty contributions — when it
/// has neither HMM posteriors nor any z-score history to stand on, rather than
/// reading absent z-scores as "exactly at baseline" and fabricating a healthy
/// number. Its doc-comment contract is explicit: *"Consumers gate their 'need
/// more data' copy on the zero confidence."* We honour that here.
///
/// This verdict is PERSISTED: `zscore_history` and the HMM posteriors are saved
/// on every state-changing op and restored on launch, so once the model has
/// learned an athlete's baseline it keeps surfacing readiness across app
/// restarts. (The earlier gate keyed off `advisories.last_observation_at`,
/// a transient cache that resets to null on every state restore — it falsely
/// re-triggered "we need more data" after each relaunch even for a fully
/// learned model.)
bool insufficientDataFromConfidence(double? confidence) =>
    confidence == null || confidence == 0.0;

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

/// Display-only snapshot of engine output for the home. Public (not
/// underscore-private) so widget tests can pump [ThreeZoneHome] directly —
/// same precedent as [AdvisorOptionsList] and [PrivacyMomentPage]. Production
/// call site: [_ReadinessScreenState.build].
class HomeData {
  // Zone 1 — State (hero)
  int? readinessScore;           // HEADLINE: indicator['score'] (4-axis blend) — decision (1) 2026-06-17
  double? confidence;            // indicator['confidence'] — no-data/learning gate
  String? level;                 // HEADLINE band: indicator['level'] (Green/Yellow/Orange/Red) → colour + word
  // Item 4: indicator['contributions'] — 4-axis reasons for Josi's why-reveal
  List<Map<String, dynamic>> contributions = const [];
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

  // Today-facts tiles (step 3, HOME_REDESIGN_BRIEF §5) — labelled via the
  // fixed dictionaries in lib/copy/today_facts_labels.dart, never shown raw.
  // Raw acwr/monotony/strain scalars are no longer fetched for the home;
  // Explore's LoadContext model surfaces them in depth independently.
  String? acwrZone;              // contextWidget['acwr_zone']
  String? acwrRecommendation;    // contextWidget['acwr_recommendation']
  String? dataStatus;            // contextWidget['data_status']
  double? lastNightSleepHours;   // readBiometricHistory sleep_hours, last night

  // Zone 3 — Context (from ContextWidget)
  String? lastWorkout;           // contextWidget['last_workout']
  List<String> reactiveAlerts = const [];    // contextWidget['reactive_alerts']
  List<String> patternAdvisories = const []; // contextWidget['pattern_advisories']
  List<double> historyScores = const [];     // FIXED: readReadinessHistory['readiness_score']
  SourceTier? sourceTier;        // lastObservationSourceTier()
  double? todayLoad;             // readDailyLoads()[today] — cumulative load today

  // Item 2: Latest completed workout (for home workout row)
  ActivitySummary? latestActivity; // readRecentActivities(limit: 1)[0]

  // Step 2 (HOME_REDESIGN_BRIEF §4): days with observations the engine has
  // returned — drives the learning ring's "day X" why line. Counting rows
  // the engine returned is presentation only (ENGINE GAP: an explicit
  // observation_days field is flagged in brief §7).
  int observationDays = 0;     // readBiometricHistory distinct-date row count

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
  const ReadinessScreen({super.key, this.profileJson, this.onEngineReady});

  /// The athlete profile JSON. If null, falls back to a minimal default
  /// (should not happen in production — onboarding always provides a profile).
  final String? profileJson;

  /// Nav-shell hook (HOME_REDESIGN_BRIEF step 1): this screen owns engine
  /// construction (ONE instance per app); the shell needs the same
  /// binding/handle for the You tab's settings/trends entries. Called once
  /// bootstrap succeeds. Null when pumped standalone (tests, pre-shell).
  final void Function(RustEngineBinding binding, EnginesHandle handle)?
      onEngineReady;

  @override
  State<ReadinessScreen> createState() => _ReadinessScreenState();
}

class _ReadinessScreenState extends State<ReadinessScreen>
    with WidgetsBindingObserver {
  HomeData _data = HomeData();
  bool _loading = true;
  bool _syncing = false;

  // Round 3 items 11+18: OS-level weather (WeatherKit). null = honest
  // absence — no icon, no forecast, no fabricated conditions.
  WeatherReport? _weather;
  bool _showForecast = false;

  // Round 3 item 12: which today-facts tiles the user wants on the home.
  // Pure UI preference — persisted as plain JSON, defaults to all on.
  final TodayTilesPrefs _tilesPrefs = TodayTilesPrefs();
  Set<String> _visibleTiles = Set.of(kDefaultTodayTiles);

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
    _loadWeather();
    _loadTilePrefs();
  }

  /// Item 12: restore the user's tile choices (any failure → defaults).
  Future<void> _loadTilePrefs() async {
    final tiles = await _tilesPrefs.load();
    if (!mounted) return;
    setState(() => _visibleTiles = tiles);
  }

  /// Item 12: the tile-picker sheet — one switch per tile, persisted on
  /// every toggle (best-effort).
  void _openTilePicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: MivaltaColors.surface2,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(MivaltaRadii.lg)),
      ),
      builder: (_) => TodayTilePicker(
        visibleTiles: _visibleTiles,
        onChanged: (next) {
          setState(() => _visibleTiles = next);
          _tilesPrefs.save(next);
        },
      ),
    );
  }

  /// Items 11+18: fetch local weather through the OS frame (WeatherKit via
  /// the `mivalta/weather` channel). Any failure → [_weather] stays null and
  /// the home renders honest absence.
  Future<void> _loadWeather() async {
    final report = await WeatherService.fetch();
    if (!mounted || report == null) return;
    setState(() => _weather = report);
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
    final d = HomeData();
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
          // Proof instrument (kDebugMode), symmetric with the failure log
          // below: an affirmative restore-SUCCESS line so a cold-restart proof
          // can confirm restoration POSITIVELY — not merely the absence of an
          // error — and cross-check that the surviving value came from the
          // vault. Reads straight from the persisted blob the engine just
          // restored from (`current_state` + `observation_count` are top-level
          // in ViterbiMonitor::save_state). Pure observation: no engine call,
          // no behavioural change, never affects the restore.
          if (kDebugMode) {
            try {
              final restored =
                  jsonDecode(persistedState) as Map<String, dynamic>;
              // ignore: avoid_print
              print(
                'persisted-state restored — '
                'current_state=${restored['current_state']}, '
                'obs=${restored['observation_count']}',
              );
            } catch (_) {
              // Log-only; a parse hiccup must never affect a successful restore.
            }
          }
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

      // readiness_indicator — NO LONGER the headline number. Kept ONLY for
      // (a) the no-data/learning GATE: its confidence is 0 on cold-start and
      // earns up over the ~28-day population→personal handover
      // (gatc-viterbi baseline.rs §4.7 confidence-earned personal_weight), and
      // (b) the "why" contributions below. The headline number/word/color all
      // come from the single snapshot object (see the fatigue-state block).
      final indicatorJson = await binding.readinessIndicator(handle);
      final indicator = jsonDecode(indicatorJson) as Map<String, dynamic>;
      d.confidence = (indicator['confidence'] as num?)?.toDouble();
      // Decision (1), 2026-06-17: the HEADLINE is the 4-axis readiness
      // indicator, NOT the lone HMM posterior. It is honest under sparse
      // sensors — an axis with no data drops its weight (Fitness → 0% with no
      // workouts), whereas the HMM always decodes a crisp state and looks
      // confident on thin data. Number + band-level (→ colour + word) both come
      // from this ONE object, so the three faces can never disagree.
      d.readinessScore = (indicator['score'] as num?)?.round();
      d.level = indicator['level']?.toString();

      // Item 4: 4-axis contributions for the why-reveal (same shape the
      // detail screen renders; Josi shows the compact cut).
      final contributions = indicator['contributions'];
      if (contributions is List) {
        d.contributions =
            contributions.whereType<Map<String, dynamic>>().toList();
      }

      // Insufficient-data gate — the engine's verdict on whether it has
      // learned enough of THIS athlete to speak. readiness_indicator() returns
      // an explicit no-data result (score 0, confidence 0, empty contributions)
      // when it has neither HMM posteriors nor any z-score history to stand on;
      // its contract is explicit (gatc-viterbi readiness_indicator no-data
      // guard). See [insufficientDataFromConfidence] for the full rationale —
      // we read the same `confidence` the headline already parsed above, which
      // is the PERSISTED learning verdict (survives app restarts), not the
      // transient advisories.last_observation_at the gate used to key off.
      d.insufficientData = insufficientDataFromConfidence(d.confidence);

      // State advisory — card prose (state recommendation + low-confidence
      // advisory), engine-owned. Dashboard removal Phase 2: replaces
      // getStateWidget; identical field names, sourced from ViterbiEngine.
      final stateAdvisoryJson = await binding.stateAdvisory(handle);
      final stateAdvisory = jsonDecode(stateAdvisoryJson);
      if (stateAdvisory is Map) {
        d.stateRecommendation = stateAdvisory['state_recommendation']?.toString();
        d.confidenceAdvisory = stateAdvisory['confidence_advisory']?.toString();
      }

      // The HMM fatigue STATE (Recovered/.../IllnessRisk). NO LONGER the
      // headline number/word — that is the indicator above. Kept ONLY for the
      // ring's glow-feel + safety haptic (lightProfileForState) and relocated
      // to the detail's fatigue-state line, where it cannot contradict the
      // band hero. The cold-start default is never shown: the insufficientData
      // gate (indicator confidence == 0 during the ~28-day learning period)
      // suppresses the whole hero until real data is earned.
      final snapshotJson = await binding.viterbiFatigueState(handle);
      final snapshot = jsonDecode(snapshotJson) as Map<String, dynamic>;
      d.fatigueState = snapshot['state']?.toString();

      // Step 2: observation-day count for the learning ring's "day X" why.
      // Engine rows in (one daily snapshot per observed day), distinct-date
      // count out — presentation counting only, no meaning derived (brief
      // §4; explicit observation_days engine field flagged in §7). 365-day
      // window: generous enough to cover any calibration period honestly.
      final bioJson = await binding.readBiometricHistory(handle, days: 365);
      final bio = jsonDecode(bioJson);
      if (bio is List) {
        d.observationDays = bio
            .whereType<Map>()
            .map((e) => e['date']?.toString())
            .whereType<String>()
            .toSet()
            .length;

        // Step 3 (brief §5): last night's sleep for the sleep tile. The row
        // dated today carries this morning's record of last night; fall back
        // to yesterday's row. Date matching is presentation; the engine's
        // sleep_hours value renders verbatim.
        double? sleepFor(String date) {
          for (final row in bio.whereType<Map>()) {
            if (row['date']?.toString() == date) {
              final s = row['sleep_hours'];
              if (s is num) return s.toDouble();
            }
          }
          return null;
        }

        final now = DateTime.now();
        final todayStr = now.toIso8601String().substring(0, 10);
        final yesterdayStr = now
            .subtract(const Duration(days: 1))
            .toIso8601String()
            .substring(0, 10);
        d.lastNightSleepHours = sleepFor(todayStr) ?? sleepFor(yesterdayStr);
      }

      // ---------- Zone 2: Today ----------

      // Today's session — the advisor's option A, read directly from the engine
      // (dashboard removal Phase 2: replaces getSessionWidget). The shim
      // assembles the advisor call from engine values in Rust; the home passes
      // nothing it derives (couriering guard). Option A is the primary suggestion.
      final optionsJson = await binding.recommendWorkoutWithHistory(handle);
      final optionsRaw = jsonDecode(optionsJson);
      if (optionsRaw is List && optionsRaw.isNotEmpty) {
        final a = WorkoutOption.fromJson(optionsRaw.first);
        d.workoutTitle = a.title;
        d.durationMin = a.durationMin;
        d.sessionZone = a.zone;
        d.targetWatts = a.targetWatts;
        d.targetPaceMss = a.targetPaceMss;
        d.focusCue = a.focusCue;
        d.rationaleProse = a.why;
      }

      // Zone cap
      final zoneJson = await binding.zoneCapWithAdvisories(handle);
      final zone = jsonDecode(zoneJson) as Map<String, dynamic>;
      d.zoneCap = zone['zone']?.toString();

      // ---------- Zone 3: Context ----------

      // Load context — read directly from the engines (dashboard removal Phase 2:
      // replaces getContextWidget). ACWR zone + recommendation from get_acwr; raw
      // acwr/monotony scalars stay off the home (Explore surfaces those).
      final acwrJson = await binding.getAcwr(handle);
      final acwr = jsonDecode(acwrJson);
      if (acwr is Map) {
        d.acwrZone = acwr['zone']?.toString();
        d.acwrRecommendation = acwr['recommendation']?.toString();
        // FLAG 2 (founder-approved): the home gates the today-facts on the
        // engine's honest-absence zone, not a dashboard data_status. A real
        // reading carries a zone other than "insufficient_data".
        d.dataStatus = (d.acwrZone == 'insufficient_data') ? 'insufficient' : 'ok';
      }

      // Last workout: one-line summary, narrative-formatted by the engine
      // (returns the string directly; empty when no activities).
      d.lastWorkout = await binding.lastWorkoutSummary(handle);

      // Reactive alerts + pattern advisories from the engine's pending advisories
      // (ReactiveAlert.message / PatternAdvisory.description).
      final pendingJson = await binding.pendingAdvisories(handle);
      final pending = jsonDecode(pendingJson);
      if (pending is Map) {
        final alerts = pending['reactive_alerts'];
        if (alerts is List) {
          d.reactiveAlerts = alerts
              .whereType<Map>()
              .map((e) => e['message']?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toList();
        }
        final patterns = pending['pattern_advisories'];
        if (patterns is List) {
          d.patternAdvisories = patterns
              .whereType<Map>()
              .map((e) => e['description']?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toList();
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
    // Nav shell: share the ONE engine instance with the You tab.
    final readyBinding = localBinding;
    final readyHandle = localHandle;
    if (readyBinding != null && readyHandle != null) {
      widget.onEngineReady?.call(readyBinding, readyHandle);
    }
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

  /// Step 4 (HOME_REDESIGN_BRIEF §4 item 5): Start workout → sensor check
  /// (honest states), with manual logging as the working capture path until
  /// the live screen lands. Engine-free screen; the manual path closes it
  /// and reuses the existing manual-entry flow.
  void _openSensorCheck() {
    // Wire the BLE HR-strap capture when the engine is live (Task A): the
    // session couriers through the shared vault-first IngestAdapter over the
    // real radio transport. Engine not ready → null → the screen's honest stub.
    final handle = _handle;
    final binding = _binding;
    final BleHrService? bleService = (handle != null && binding != null)
        ? BleHrService(
            transport: FlutterBlueTransport(),
            adapter: IngestAdapter(binding: binding, handle: handle),
          )
        : null;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SensorCheckScreen(
          bleService: bleService,
          onLogManually: () {
            Navigator.of(context).pop(); // close the sensor check
            _openManualEntry();
          },
        ),
      ),
    );
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

  /// Item 2: Open workout detail for a specific date.
  void _openWorkoutDetail(String date) {
    final handle = _handle;
    final binding = _binding;
    if (handle == null || binding == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WorkoutDetailPage(
          binding: binding,
          handle: handle,
          date: date,
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
        // Round 3 item 10 (founder): title stays CENTERED — liked.
        centerTitle: true,
        title: const Text('MiValta'),
        // Round 3 item 10: Start workout as a compact control in the
        // top-LEFT corner beside the centered title. Round 3-FINAL item 20
        // (founder): subtle/refined, NOT a solid green disc — hairline
        // outline, green glyph, no fill. Same destination: sensor check.
        leading: _loading
            ? null
            : Center(
                child: IconButton.outlined(
                  style: IconButton.styleFrom(
                    foregroundColor: MivaltaColors.primaryGreen,
                    side: const BorderSide(color: MivaltaColors.surface2),
                    minimumSize: const Size(36, 36),
                    padding: EdgeInsets.zero,
                  ),
                  tooltip: 'Start workout',
                  icon: const Icon(Icons.play_arrow_rounded, size: 20),
                  onPressed: _openSensorCheck,
                ),
              ),
        // Step-1 slimdown (HOME_REDESIGN_BRIEF §3): settings/trends/debug
        // actions migrated to the You tab. Sync stays — it's a Today data
        // action, not a settings one.
        actions: [
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
          // LAST-TWO item 24 (was round 3 items 11+18 / 21): the local
          // condition WITH temperature ("☀ 18°") right of the centered
          // title — only when the OS actually returned weather (honest
          // absence otherwise). Quiet tint; green while the week is open.
          if (_weather != null)
            Tooltip(
              message: 'Weather',
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: _showForecast
                      ? MivaltaColors.primaryGreen
                      : MivaltaColors.textSecondary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: MivaltaSpace.x2,
                  ),
                  minimumSize: const Size(0, 36),
                ),
                onPressed: () =>
                    setState(() => _showForecast = !_showForecast),
                icon: Icon(weatherGlyph(_weather!.symbol), size: 18),
                label: Text('${_weather!.temperatureC.round()}°'),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              fit: StackFit.expand,
              children: [
                ThreeZoneHome(
                  data: _data,
                  onTapRing: _openReadinessDetail,
                  onTapAdvisor: _openAdvisor,
                  onTapLatestWorkout: _openWorkoutDetail,
                  // Item 12: user-chosen tiles + the picker entry point.
                  visibleTiles: _visibleTiles,
                  onEditTiles: _openTilePicker,
                ),
                // Item 24: tap the condition → the GLASSY week floats over
                // the home (the home stays visible beneath, §15.5 glass).
                // Tapping anywhere outside it — or the icon again — closes.
                if (_showForecast && _weather != null) ...[
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _showForecast = false),
                    ),
                  ),
                  Positioned(
                    top: MivaltaSpace.x2,
                    left: MivaltaSpace.x5,
                    right: MivaltaSpace.x5,
                    child: WeatherWeekOverlay(report: _weather!),
                  ),
                ],
              ],
            ),
      // Round 3 item 9: the green "+" FAB is GONE (founder: not nice, not
      // useful — the home stays calm). Manual logging lives behind Start
      // workout → sensor check → "Log a workout manually".
    );
  }
}

/// The home body — Josi (presenter) above the three-zone PULL layout
/// (DESIGN_BUILD_SPEC §3). Public so widget tests can pump it with a seeded
/// [HomeData] (the screen itself needs the FFI binding). Production call
/// site: [_ReadinessScreenState.build].
class ThreeZoneHome extends StatelessWidget {
  const ThreeZoneHome({
    super.key,
    required this.data,
    required this.onTapRing,
    required this.onTapAdvisor,
    required this.onTapLatestWorkout,
    this.visibleTiles = kDefaultTodayTiles,
    this.onEditTiles,
  });
  final HomeData data;
  final VoidCallback onTapRing;
  final VoidCallback onTapAdvisor;
  final void Function(String date) onTapLatestWorkout; // Item 2
  // Item 12: which today-facts tiles render + the picker entry point.
  final Set<String> visibleTiles;
  final VoidCallback? onEditTiles;

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
          // ============ JOSI — ONE-LINE VERDICT (step 2) ============
          // One spoken line + why-reveal; the session moved to its own card.
          JosiPresenter(
            insufficientData: data.insufficientData,
            stateRecommendation: data.stateRecommendation,
            confidenceAdvisory: data.confidenceAdvisory,
            rationaleProse: data.rationaleProse,
            contributions: data.contributions,
          ),
          const SizedBox(height: MivaltaSpace.x5),

          // ============ ZONE 1: STATE (HERO) ============
          _Zone1State(data: data, textTheme: textTheme, onTapRing: onTapRing),
          const SizedBox(height: MivaltaSpace.x6),

          // ============ TODAY-FACTS TILES (step 3, item 12) ============
          // Sleep / training load / today's load — plain human words via
          // the fixed dictionaries; raw enums never reach here. User-
          // configurable: [visibleTiles] picks the grid, the tune affordance
          // opens the picker. (Weather is the app-bar icon, item 21.)
          TodayFacts(
            sleepHours: data.lastNightSleepHours,
            acwrZone: data.acwrZone,
            acwrRecommendation: data.acwrRecommendation,
            dataStatus: data.dataStatus,
            todayLoad: data.todayLoad,
            visibleTiles: visibleTiles,
            onEditTiles: onEditTiles,
          ),
          const SizedBox(height: MivaltaSpace.x6),

          // ============ ZONE 2: TODAY ============
          _Zone2Today(data: data, textTheme: textTheme, onTapAdvisor: onTapAdvisor),
          const SizedBox(height: MivaltaSpace.x6),

          // Round 3 item 10: the in-column Start-workout button moved to a
          // compact control in the home app bar's top-left (founder request);
          // the scroll column stays calm.

          // ============ ZONE 3: CONTEXT ============
          _Zone3Context(
            data: data,
            textTheme: textTheme,
            onTapLatestWorkout: onTapLatestWorkout,
          ),
          const SizedBox(height: MivaltaSpace.x5),
        ],
      ),
    );
  }
}

/// Zone 1 — the adaptive STATE ELEMENT (step 2, HOME_REDESIGN_BRIEF §4):
/// sized by data sufficiency. Small muted ring while the engine is learning
/// (with its own "why" — "I'm still learning you — day X."), full hero ring
/// only when confident. Josi's card above is the ONE home surface for the
/// verdict prose and the confidence advisory, so neither repeats here.
class _Zone1State extends StatelessWidget {
  const _Zone1State({
    required this.data,
    required this.textTheme,
    required this.onTapRing,
  });
  final HomeData data;
  final TextTheme textTheme;
  final VoidCallback onTapRing;

  /// Sizing gate — ENGINE SIGNALS ONLY (brief §4): the engine reports it is
  /// still calibrating via insufficient data OR a non-empty
  /// confidence_advisory. No Dart threshold on the confidence scalar.
  bool get _learning =>
      data.insufficientData || ((data.confidenceAdvisory ?? '').isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final learning = _learning;
    return Column(
      children: [
        // The state element — tap to open detail screen (data present only).
        Center(
          child: GestureDetector(
            onTap: data.insufficientData ? null : onTapRing,
            child: ReadinessLightField(
              fatigueState: data.fatigueState, // glow-feel + safety haptic only
              level: data.level, // band → colour (indicator-sourced)
              stateWord: data.level, // hero word = band, not the HMM state
              score: data.readinessScore, // indicator['score']
              noData: data.insufficientData,
              learning: learning,
            ),
          ),
        ),

        // The learning ring's own "why" (brief §4 item 2): a quiet reveal
        // explaining why the element is small. Verdict prose and confidence
        // advisory live in Josi's card (exactly once on the home).
        if (learning) ...[
          const SizedBox(height: MivaltaSpace.x2),
          _LearningWhy(observationDays: data.observationDays),
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

/// Step 2 (HOME_REDESIGN_BRIEF §4 item 2): the learning state element's
/// "why" — explains the small ring honestly. "I'm still learning you —
/// day X." where X is [observationDays], the count of days with
/// observations the engine returned (counting is presentation; explicit
/// engine field flagged in brief §7). With zero observed days the day
/// suffix is omitted (grammar formatting of a count, not a threshold).
/// Copy flagged for founder review (brief §7).
class _LearningWhy extends StatefulWidget {
  const _LearningWhy({required this.observationDays});

  final int observationDays;

  @override
  State<_LearningWhy> createState() => _LearningWhyState();
}

class _LearningWhyState extends State<_LearningWhy> {
  bool _show = false;

  String get _line => widget.observationDays > 0
      ? "I'm still learning you — day ${widget.observationDays}."
      : "I'm still learning you.";

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _show = !_show),
          borderRadius: BorderRadius.circular(MivaltaRadii.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: MivaltaSpace.x2,
              vertical: MivaltaSpace.x1,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _show ? 'Hide why' : 'Why?',
                  style: textTheme.labelMedium?.copyWith(
                    color: MivaltaColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Icon(
                  _show ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: MivaltaColors.textMuted,
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: MivaltaMotion.fast,
          alignment: Alignment.topCenter,
          child: _show
              ? Padding(
                  padding: const EdgeInsets.only(top: MivaltaSpace.x1),
                  child: Text(
                    _line,
                    style: textTheme.bodySmall?.copyWith(
                      color: MivaltaColors.textMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              : const SizedBox(width: double.infinity),
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
  final HomeData data;
  final TextTheme textTheme;
  final VoidCallback onTapAdvisor;

  /// A2 (rest with equal visual weight): a rest day is content, not absence.
  /// When the engine prescribes rest (session zone 'R'), the same full card
  /// renders with rest-specific presentation — recovery icon + recovered-state
  /// accent — instead of the generic workout dumbbell. Presentation mapping
  /// of an engine value only (same pattern as the advisor's zone colors).
  bool get _isRest => (data.sessionZone ?? '').toUpperCase() == 'R';

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

        // No-data redesign (founder 2026-06-12): with insufficient data there
        // are NO prescriptions from priors — no cap chip, no session card, no
        // workout options. Zone 2 keeps its rhythm (DESIGN_BUILD_SPEC §3) with
        // a calm learn-you placeholder instead of going empty or error-y.
        if (data.insufficientData) ...[
          Container(
            padding: const EdgeInsets.all(MivaltaSpace.x4),
            decoration: BoxDecoration(
              color: MivaltaColors.surface1,
              borderRadius: BorderRadius.circular(MivaltaRadii.md),
            ),
            child: Row(
              children: [
                const Icon(Icons.edit_note, color: MivaltaColors.textMuted),
                const SizedBox(width: MivaltaSpace.x3),
                Expanded(
                  child: Text(
                    // Placeholder copy from the founder's 2026-06-12 no-data
                    // redesign brief ("first, let's learn you — log a few
                    // days"), sentence-cased. Flagged for founder review.
                    "First, let's learn you — log a few days.",
                    style: textTheme.bodyMedium?.copyWith(
                      color: MivaltaColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[

        // Zone cap chip — consumer label, never the raw Z-code (brief §5)
        if (zoneCapLabel(data.zoneCap) != null)
          _Badge(
            label: zoneCapLabel(data.zoneCap)!,
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
                    Icon(
                      _isRest ? Icons.self_improvement : Icons.fitness_center,
                      color: _isRest
                          ? MivaltaColors.stateRecovered
                          : MivaltaColors.textSecondary,
                    ),
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
                    if (zoneLabel(data.sessionZone) != null)
                      _Badge(
                        label: zoneLabel(data.sessionZone)!,
                        color: _isRest
                            ? MivaltaColors.stateRecovered
                            : MivaltaColors.textMuted,
                      ),
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

        // PR-D: "See Options" button to open advisor. Hidden on insufficient
        // data — the advisor surfaces prior-derived prescriptions, and the
        // no-data home makes no prescriptions from priors.
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
      ],
    );
  }
}

/// Zone 3 — Context: sparkline + latest workout + alerts/advisories + source
/// tier. Raw ACWR/monotony/strain moved off the home in step 3 (brief §5).
class _Zone3Context extends StatelessWidget {
  const _Zone3Context({
    required this.data,
    required this.textTheme,
    required this.onTapLatestWorkout,
  });
  final HomeData data;
  final TextTheme textTheme;
  final void Function(String date) onTapLatestWorkout; // Item 2

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

        // Step 3 (brief §5): the raw ACWR / monotony / strain rows that lived
        // here moved off the home — the today-facts tiles present the load in
        // human language; depth lives in Explore's load & strain card.

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

        // Step 4: the quick "start workout" link moved up — the Today
        // Start-workout button (→ sensor check) replaces it.

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

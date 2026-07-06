// Today Screen — the home.
//
// Per Today-Modular.html: glow hero → Josi line → decision chip → module cards.
// Engine DECIDES, Flutter DISPLAYS. Wires to real engine data via HomeData.
//
// DR-001 corrections applied:
// - "Today" left-aligned in app bar
// - Hero number in Inter (not Zen Dots)
// - Josi line from state_recommendation
// - Recovered = #7FE3B0

import 'dart:convert';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/activity_summary.dart';
import '../models/home_data.dart';
import '../models/realized_line.dart';
import '../models/workout_option.dart';
import '../rust_engine.dart';
import '../services/morning_read_gate.dart';
import '../services/notification_service.dart';
import '../services/profile_service.dart';
import '../services/weather_service.dart';
import '../debug/seam_log.dart';
import '../theme/tokens.dart';
import '../theme/zone_names.dart';
import '../widgets/today/glow_hero.dart';
import '../widgets/today/josi_card.dart';
import '../widgets/today/metric_bar.dart';
import '../widgets/today/module_card.dart';
import '../widgets/today/sleep_stage_ring.dart';
import '../widgets/today/masthead.dart';
import '../widgets/today/why_unfold.dart';
import 'advisor_screen.dart';
import 'journey_screen.dart';
import 'session_start_screen.dart';
import 'you_screen.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> with WidgetsBindingObserver {
  HomeData _data = HomeData();
  bool _loading = true;
  WeatherReport? _weather;
  // BS-003: Store binding and handle for Advisor navigation
  RustEngineBinding? _binding;
  EnginesHandle? _handle;
  // BS-008 P-4: Detail preference from onboarding
  bool _showNumbers = false;

  @override
  void initState() {
    super.initState();
    // BS-012 N3: Register lifecycle observer for app resume trigger.
    WidgetsBinding.instance.addObserver(this);
    _initEngine();
    _fetchWeather();
    _loadDetailPreference();
  }

  @override
  void dispose() {
    // BS-012 N3: Unregister lifecycle observer.
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// BS-012 N3: App lifecycle callback for notification scheduling.
  /// Evaluates the morning read gate on app resume.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scheduleMorningReadIfNeeded();
    }
  }

  /// BS-008 P-4: Load onboarding_detail preference.
  Future<void> _loadDetailPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final detail = prefs.getString('onboarding_detail') ?? 'simple';
    if (mounted) {
      setState(() => _showNumbers = detail == 'numbers');
    }
  }

  /// BS-012 N3: Evaluate the morning read gate and schedule notification.
  ///
  /// Called on:
  /// - App resume (lifecycle callback)
  /// - Post-ingest (after home data loads)
  ///
  /// The gate reads engine outputs and decides whether to fire based on:
  /// - Coach presence setting (from SharedPreferences)
  /// - State change vs last delivered read
  /// - Pending advisories
  /// - Calibration milestone changes
  Future<void> _scheduleMorningReadIfNeeded() async {
    final binding = _binding;
    final handle = _handle;
    if (binding == null || handle == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final gate = MorningReadGate(prefs: prefs);

      // The ENGINE decides fire/silent (rust-engine #388): Dart couriers the
      // delivery context in and renders the card-worded verdict out. An
      // engine error is honest absence — silent, never a fabricated read.
      final verdictJson = await binding.morningReadVerdict(
        handle,
        presence: gate.presenceToken,
        lastDeliveredState: gate.lastDeliveredState,
        lastDeliveredBucket: gate.lastDeliveredBucket,
        alreadyNotifiedToday: gate.alreadyNotifiedToday,
      );
      final result = gate.parseVerdict(verdictJson);

      // Schedule (or cancel) the notification based on the engine verdict.
      await NotificationService.instance.scheduleMorningRead(result: result);

      // If we scheduled a notification, mark it as delivered so we don't
      // re-notify for the same state on the next resume.
      if (result.shouldFire) {
        gate.markDelivered(
          state: result.state,
          calibrationBucket: result.sufficiencyBucket,
        );
      }

      if (kDebugMode) {
        // ignore: avoid_print
        print('[TodayScreen] Morning read verdict: ${result.reason}');
      }
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[TodayScreen] Morning read scheduling failed: $e');
      }
    }
  }

  Future<void> _fetchWeather() async {
    final report = await WeatherService.fetch();
    if (mounted) {
      setState(() => _weather = report);
    }
  }

  Future<void> _initEngine() async {
    try {
      // Bootstrap FRB
      final binding = await RustEngineBinding.bootstrap();

      // Load profile
      final profileJson = await ProfileService.loadProfile();
      if (profileJson == null) {
        // No profile — show honest absence
        setState(() {
          _data.insufficientData = true;
          _loading = false;
        });
        return;
      }

      // Load tables
      final tablesJson = await rootBundle.loadString('assets/compiled_tables.json');
      final vaultPath = await ProfileService.getVaultPath();

      // Check for persisted state
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

      // BS-003: Store binding and handle for Advisor navigation
      _binding = binding;
      _handle = handle;

      // Load home data
      await _loadHomeData(binding, handle);

      // BS-012 N3: Schedule morning read notification post-ingest.
      // The gate evaluates whether to fire based on state changes, advisories,
      // and calibration milestones since the last delivered notification.
      await _scheduleMorningReadIfNeeded();
    } catch (e) {
      setState(() {
        _data.error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadHomeData(RustEngineBinding binding, EnginesHandle handle) async {
    final data = HomeData();

    try {
      // Zone 1 — Readiness indicator (headline)
      final swIndicator = Stopwatch()..start();
      final indicatorJson = await binding.readinessIndicator(handle);
      SeamLog.ok('readinessIndicator', swIndicator.elapsedMilliseconds);
      final indicator = jsonDecode(indicatorJson) as Map<String, dynamic>;
      data.readinessScore = (indicator['score'] as num?)?.toInt();
      data.confidence = (indicator['confidence'] as num?)?.toDouble();
      data.level = indicator['level'] as String?;
      data.contributions = (indicator['contributions'] as List?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          const [];

      // Check insufficient data gate
      data.insufficientData = insufficientDataFromConfidence(data.confidence);

      // BS-008 P-1: Personalization diagnostics (calibrated-to-you line)
      final swDiag = Stopwatch()..start();
      try {
        final diagJson = await binding.personalizationDiagnostics(handle);
        SeamLog.ok('personalizationDiagnostics', swDiag.elapsedMilliseconds);
        final diag = jsonDecode(diagJson) as Map<String, dynamic>;
        data.calibrationObservations = (diag['observation_count'] as num?)?.toInt();
        data.calibrationConfidence = diag['confidence'] as String?;
      } catch (e) {
        SeamLog.error('personalizationDiagnostics', swDiag.elapsedMilliseconds, e);
        // Honest absence — diagnostics not yet available
      }

      // State advisory (for Josi fallback)
      final swState = Stopwatch()..start();
      final stateJson = await binding.stateAdvisory(handle);
      SeamLog.ok('stateAdvisory', swState.elapsedMilliseconds);
      final stateMap = jsonDecode(stateJson) as Map<String, dynamic>;
      data.stateRecommendation = stateMap['state_recommendation'] as String?;
      data.confidenceAdvisory = stateMap['confidence_advisory'] as String?;

      // BS-007: Realized advisor line (primary Josi line)
      // Date in YYYY-MM-DD format for the engine
      final today = DateTime.now();
      final dateStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      final swRealize = Stopwatch()..start();
      try {
        final realizedJson = await binding.realizeAdvisorLine(handle, date: dateStr);
        SeamLog.ok('realizeAdvisorLine', swRealize.elapsedMilliseconds);
        data.realizedLine = RealizedLine.parse(realizedJson);
      } catch (e) {
        SeamLog.error('realizeAdvisorLine', swRealize.elapsedMilliseconds, e);
        // Honest absence — fall back to stateRecommendation
        debugPrint('realizeAdvisorLine failed: $e');
      }

      // Fatigue state (for glow color + state word)
      // Engine returns {"state":"Recovered",...} — key is "state", not "fatigue_state"
      final swFatigue = Stopwatch()..start();
      final fatigueJson = await binding.viterbiFatigueState(handle);
      SeamLog.ok('viterbiFatigueState', swFatigue.elapsedMilliseconds);
      final fatigueMap = jsonDecode(fatigueJson) as Map<String, dynamic>;
      data.fatigueState = fatigueMap['state'] as String?;

      // Zone 2 — Today load (for module card)
      final swLoads = Stopwatch()..start();
      try {
        final loadsJson = await binding.readDailyLoads(handle, days: 1);
        SeamLog.ok('readDailyLoads', swLoads.elapsedMilliseconds);
        final loads = jsonDecode(loadsJson) as List;
        if (loads.isNotEmpty) {
          final todayLoad = loads.last;
          if (todayLoad is List && todayLoad.length >= 2) {
            data.todayLoad = (todayLoad[1] as num?)?.toDouble();
          }
        }
      } catch (e) {
        SeamLog.error('readDailyLoads', swLoads.elapsedMilliseconds, e);
        // Honest absence
      }

      // BS-005: ACWR for Load ceiling + band line
      final swAcwr = Stopwatch()..start();
      try {
        final acwrJson = await binding.getAcwr(handle);
        SeamLog.ok('getAcwr', swAcwr.elapsedMilliseconds);
        final acwr = jsonDecode(acwrJson) as Map<String, dynamic>;
        data.acwrValue = (acwr['acwr'] as num?)?.toDouble();
        data.loadCeiling = (acwr['chronic_load'] as num?)?.toDouble();
        data.loadBandLine = acwr['recommendation'] as String?;
        data.acwrZone = acwr['zone'] as String?;
      } catch (e) {
        SeamLog.error('getAcwr', swAcwr.elapsedMilliseconds, e);
        // Honest absence — no ACWR yet
      }

      // BS-005: Source tier for caption
      final swTier = Stopwatch()..start();
      try {
        final tierJson = await binding.lastObservationSourceTier(handle);
        SeamLog.ok('lastObservationSourceTier', swTier.elapsedMilliseconds);
        final tier = jsonDecode(tierJson);
        if (tier != null && tier is String) {
          data.sourceTierLabel = _formatSourceTier(tier);
        }
      } catch (e) {
        SeamLog.error('lastObservationSourceTier', swTier.elapsedMilliseconds, e);
        // Honest absence
      }

      // Sleep (for module card)
      final swBio = Stopwatch()..start();
      try {
        final bioJson = await binding.readBiometricHistory(handle, days: 1);
        SeamLog.ok('readBiometricHistory', swBio.elapsedMilliseconds);
        final bio = jsonDecode(bioJson) as List;
        if (bio.isNotEmpty) {
          final lastBio = bio.last as Map<String, dynamic>;
          data.lastNightSleepHours = (lastBio['sleep_hours'] as num?)?.toDouble();
        }
      } catch (e) {
        SeamLog.error('readBiometricHistory', swBio.elapsedMilliseconds, e);
        // Honest absence
      }

      // Zone cap (for decision chip)
      final swZoneCap = Stopwatch()..start();
      try {
        final zoneCapJson = await binding.zoneCapWithAdvisories(handle);
        SeamLog.ok('zoneCapWithAdvisories', swZoneCap.elapsedMilliseconds);
        final zoneCapMap = jsonDecode(zoneCapJson) as Map<String, dynamic>;
        data.zoneCap = zoneCapMap['zone'] as String?;
      } catch (e) {
        SeamLog.error('zoneCapWithAdvisories', swZoneCap.elapsedMilliseconds, e);
        // Honest absence
      }

      // Workout suggestion (for module card).
      // The engine (AdvisorEngine::recommend_workout) serializes a BARE JSON
      // ARRAY of WorkoutOptionData — NOT an object with a `suggestions` wrapper
      // (the previous code cast the array to a Map, which threw and left the card
      // permanently on "No suggestion yet"). Parse all options through the
      // shared, tested WorkoutOption model — duration lives in
      // `structure.total_minutes`, there is no top-level `duration_min`.
      // BS-003: Store full options list for Advisor screen.
      final swWorkout = Stopwatch()..start();
      try {
        final workoutJson = await binding.recommendWorkout(handle);
        SeamLog.ok('recommendWorkout', swWorkout.elapsedMilliseconds);
        final decoded = jsonDecode(workoutJson);
        if (decoded is List && decoded.isNotEmpty) {
          final options = decoded.map((e) => WorkoutOption.fromJson(e)).toList();
          data.workoutOptions = options;
          // Primary display (option A) for Today card
          final option = options.first;
          data.workoutTitle = option.title;
          data.sessionZone = option.zone;
          data.durationMin = option.durationMin;
          data.focusCue = option.focusCue;
        }
      } catch (e) {
        SeamLog.error('recommendWorkout', swWorkout.elapsedMilliseconds, e);
        // Honest absence
      }

      // BS-016 S1: Recent activities + post-workout reflection.
      // Fetch today's latest activity and get the coach reaction.
      try {
        final activitiesJson = await binding.readRecentActivities(handle, limit: 5);
        final activities = ActivitySummary.listFromJson(jsonDecode(activitiesJson));
        if (activities.isNotEmpty) {
          final latest = activities.first;
          data.latestActivity = latest;

          // Only fetch reflection for today's activities
          if (latest.date == dateStr) {
            try {
              final reflectionJson = await binding.realizeWorkoutReflection(
                handle,
                activityId: latest.id,
                date: dateStr,
              );
              data.workoutReflection = RealizedLine.parse(reflectionJson);
            } catch (e) {
              // Honest absence — activity may lack quality metrics ("logged, not judged")
              debugPrint('realizeWorkoutReflection failed: $e');
            }
          }
        }
      } catch (_) {
        // Honest absence — no recent activities
      }

      // The load chain awaits several FFI calls (S1 extended it further);
      // the screen can be disposed mid-load (e.g. the notification tap
      // rebuilds the Today route), so guard before touching state.
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _data.error = e.toString();
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
            : _buildContent(),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  void _startWorkout() {
    // BS-010: Navigate to session start screen.
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => const SessionStartScreen(),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: MivaltaColors.surfaceBackground,
        border: Border(
          top: BorderSide(
            color: MivaltaColors.textPrimary.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.wb_sunny_outlined,
                activeIcon: Icons.wb_sunny,
                label: 'Today',
                isActive: true,
                // Today is active — no navigation
              ),
              _NavItem(
                icon: Icons.route_outlined,
                activeIcon: Icons.route,
                label: 'Journey',
                isActive: false,
                onTap: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const JourneyScreen()),
                ),
              ),
              _NavItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'You',
                isActive: false,
                // DR-023 T2: Wire to YouScreen (no longer a stub)
                onTap: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const YouScreen()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_data.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(MivaltaSpace.x4),
          child: Text(
            'Unable to load: ${_data.error}',
            style: MivaltaType.body.copyWith(color: MivaltaColors.levelRed),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        // Masthead — BS-002: two-tier brand header (wordmark + action row)
        SliverToBoxAdapter(
          child: TodayMasthead(
            onStartWorkout: _startWorkout,
            weather: _weather,
          ),
        ),

        // Content
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: MivaltaSpace.x4),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // BS-002 Step 3: 24px from masthead micro-row to glow hero
              const SizedBox(height: MivaltaSpace.x5), // 24px

              // Glow hero
              GlowHero(
                score: _data.readinessScore,
                fatigueState: _data.fatigueState,
                insufficientData: _data.insufficientData,
              ),

              // BS-008 P-1: Calibrated-to-you line under hero
              // Engine decides confidence bucket; Dart only renders.
              if (_data.calibrationObservations != null) ...[
                const SizedBox(height: MivaltaSpace.x2),
                Center(
                  child: Text(
                    _data.isCalibrated
                        ? 'From ${_data.calibrationObservations} days of your data'
                        : 'Learning you · day ${_data.calibrationObservations}',
                    style: MivaltaType.small.copyWith(
                      color: MivaltaColors.textMuted,
                    ),
                  ),
                ),
              ],

              // BS-007: Josi card — primary from realizedLine, fallback to stateRecommendation
              // BS-001 Step 6: collapse hero void when absent
              if (_hasJosiLine()) ...[
                const SizedBox(height: MivaltaSpace.x3),
                JosiCard(
                  realizedLine: _data.realizedLine,
                  fallbackLine: _data.stateRecommendation,
                  confidenceAdvisory: _data.confidenceAdvisory,
                  showNumbers: _showNumbers,
                ),
                // BS-007 Step 2: Why? unfold — evidence layer under Josi.
                // Collapses when contributions[] is empty (honest absence).
                WhyUnfold(
                  contributions: _data.contributions,
                  confidenceText: _data.confidenceAdvisory,
                ),
              ],

              // Decision chip — BS-001 Step 7: honest-absent (hidden, collapse)
              // DR-012 + DR-023 T1: Z8 is the ceiling (no restriction) — must NOT render.
              // The chip is a DECISION only when the engine RESTRICTS (Z1–Z7, REST).
              // A healthy day (Z8) with a session suggestion shows the zone on the
              // workout card — under the hero it read as "MiValta tells you what to do."
              () {
                final restrictiveCap = _isRestrictiveCap(_data.zoneCap);
                final showChip = !_data.insufficientData && restrictiveCap;
                return showChip
                    ? Column(
                        children: [
                          const SizedBox(height: MivaltaSpace.x3),
                          _DecisionChip(zoneCap: _data.zoneCap),
                        ],
                      )
                    : const SizedBox.shrink();
              }(),

              // Spacing before cards: reduced when Josi + chip both absent
              // DR-012 + DR-023 T1: use same restrictive-cap logic for spacer
              () {
                final hasJosi = _hasJosiLine();
                final restrictiveCap = _isRestrictiveCap(_data.zoneCap);
                final showChip = !_data.insufficientData && restrictiveCap;
                return SizedBox(
                  height: (!hasJosi && !showChip) ? MivaltaSpace.x2 : MivaltaSpace.x4,
                );
              }(),

              // "Your day" section eyebrow — DR-023 T3: token sweep (was 10px, below floor)
              Padding(
                padding: const EdgeInsets.only(bottom: MivaltaSpace.x3),
                child: Text(
                  'YOUR DAY',
                  style: MivaltaType.label.copyWith(color: MivaltaColors.textSoft45),
                ),
              ),

              // Module cards (I2 fix: honest-absence pattern, never blank)
              // BS-005: Load card with MetricBar (sharp bar + bold number)
              ModuleCard(
                title: 'Load today',
                icon: Icons.trending_up,
                // Rule 3 (no fabricated defaults): the ranged bar only renders
                // when the engine has provided a real load ceiling (chronic-load
                // baseline from ACWR). Before that exists we do NOT invent a
                // "600" range — we show honest absence of the range.
                child: (_data.todayLoad != null && _data.loadCeiling != null)
                    ? MetricBar(
                        value: _data.todayLoad,
                        max: _data.loadCeiling!,
                        ceiling: _data.loadCeiling,
                        color: MivaltaColors.stateProductive,
                        scaleStart: '0',
                        scaleEnd: _data.loadCeiling!.round().toString(),
                        caption: _buildLoadCaption(),
                      )
                    : _data.todayLoad != null
                        ? const _HonestAbsence(
                            label: 'Load range still building',
                            unlock: 'A few more logged days set your baseline',
                          )
                        : const _HonestAbsence(
                            label: 'No activity recorded',
                            unlock: 'Log a workout to see your load',
                          ),
              ),

              const SizedBox(height: MivaltaSpace.x3),

              // Daily activity card
              ModuleCard(
                title: 'Daily activity',
                icon: Icons.directions_walk,
                child: const _HonestAbsence(
                  label: 'No activity data',
                  unlock: 'Connect a health source for steps & movement',
                ),
              ),

              const SizedBox(height: MivaltaSpace.x3),

              // BS-016 S1: Recent workout with coach reflection (today only).
              // Shows the latest workout + Josi's post-workout reaction.
              ..._recentWorkoutCard(),

              // BS-006: Sleep stage ring (full 360° donut sliced into stages).
              // Engine doesn't provide per-stage minutes yet — placeholder ⚠
              // Shows honest-absent variant until stage data is available.
              ModuleCard(
                title: 'Sleep',
                icon: Icons.bedtime,
                child: SleepStageRing(
                  stages: null, // Engine lacks stage data — honest-absent
                  needMinutes: _data.sleepNeedHours != null
                      ? (_data.sleepNeedHours! * 60).round()
                      : null,
                  sourceTier: _data.sourceTierLabel,
                ),
              ),

              const SizedBox(height: MivaltaSpace.x3),

              // Suggested workout card — BS-003: tappable → Advisor screen
              ModuleCard(
                title: 'Suggested workout',
                icon: Icons.fitness_center,
                onTap: _data.workoutOptions.isNotEmpty
                    ? () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => AdvisorScreen(
                              options: _data.workoutOptions,
                              binding: _binding!,
                              handle: _handle!,
                              readinessLevel: _data.level, // BS-016 S3
                            ),
                          ),
                        )
                    : null,
                trailing: _data.workoutOptions.isNotEmpty
                    ? const Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: MivaltaColors.textSecondary,
                      )
                    : null,
                child: _data.workoutTitle != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // BS-003: Zone chip (energy name first — LOCKED voice rule)
                          if (_data.sessionZone != null) ...[
                            _ZoneChip(zone: _data.sessionZone!),
                            const SizedBox(height: 6),
                          ],
                          Text(
                            _data.workoutTitle!,
                            style: MivaltaType.cardTitle.copyWith(
                              color: MivaltaColors.textPrimary,
                            ),
                          ),
                          // BS-003: Duration + focusCue preview
                          if (_data.durationMin != null || _data.focusCue != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              _buildWorkoutSubtitle(),
                              style: MivaltaType.small.copyWith(
                                color: MivaltaColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      )
                    : const _HonestAbsence(
                        label: 'No suggestion yet',
                        // BS-003: Updated copy (no gamification)
                        unlock: 'MiValta suggests sessions once it\'s read a few of your days.',
                      ),
              ),

              const SizedBox(height: MivaltaSpace.x6),

              // D6: kDebugMode-only build stamp for screenshot SHA verification.
              // Pass SHA at build time: --dart-define=BUILD_SHA=$(git rev-parse --short HEAD)
              // Compiled out of release builds.
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

              // BS-018: kDebugMode-only wiring stamp — seam health panel.
              // Shows ok/error/not-called status for each FFI seam.
              if (kDebugMode) _WiringStamp(),
            ]),
          ),
        ),
      ],
    );
  }

  /// BS-005: Format source tier for MetricBar caption.
  String _formatSourceTier(String tier) {
    return switch (tier.toLowerCase()) {
      'medical' => 'Medical-sourced',
      'device' => 'Device-sourced',
      'partial' => 'Partial data',
      'manual' => 'Manual entry',
      _ => tier,
    };
  }

  /// BS-005: Build Load caption with band line + source tier.
  String _buildLoadCaption() {
    final parts = <String>[];
    if (_data.loadBandLine != null && _data.loadBandLine!.isNotEmpty) {
      parts.add(_data.loadBandLine!);
    } else {
      parts.add('Training load');
    }
    if (_data.sourceTierLabel != null) {
      parts.add(_data.sourceTierLabel!);
    }
    return parts.join(' · ');
  }

  /// BS-007: Check if there's a Josi line to display (realized or fallback).
  bool _hasJosiLine() {
    if (_data.realizedLine != null && _data.realizedLine!.text.isNotEmpty) {
      return true;
    }
    return _data.stateRecommendation != null && _data.stateRecommendation!.isNotEmpty;
  }

  /// DR-012: A zone CAP is a decision only when it holds the athlete back.
  /// Z8 is the ceiling (no restriction) — it must NOT render as a decision chip.
  bool _isRestrictiveCap(String? zone) {
    if (zone == null || zone.isEmpty) return false;
    return switch (zone.toUpperCase()) {
      'Z1' || 'Z2' || 'Z3' || 'Z4' || 'Z5' || 'Z6' || 'Z7' || 'REST' => true,
      _ => false, // Z8 (ceiling) + unknown → collapse
    };
  }

  /// BS-003: Build workout subtitle (duration + focusCue).
  String _buildWorkoutSubtitle() {
    final parts = <String>[];
    if (_data.durationMin != null) {
      parts.add('${_data.durationMin} min');
    }
    if (_data.focusCue != null && _data.focusCue!.isNotEmpty) {
      parts.add(_data.focusCue!);
    }
    return parts.join(' · ');
  }

  /// BS-016 S1: Recent workout card with Josi's post-workout reflection
  /// (renders only for a same-day activity). Built from LOCAL captures of the
  /// mutable HomeData fields — no `!` between null-check and use, so the card
  /// always renders one consistent snapshot (#155 review).
  List<Widget> _recentWorkoutCard() {
    final latest = _data.latestActivity;
    if (latest == null || latest.date != _todayDateStr()) return const [];
    final reflection = _data.workoutReflection;
    return [
      ModuleCard(
        title: 'Recent workout',
        icon: Icons.check_circle_outline,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Activity summary row
            Row(
              children: [
                Text(
                  _formatSport(latest.sport),
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: MivaltaColors.textPrimary,
                  ),
                ),
                if (latest.durationMin != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '${latest.durationMin} min',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: MivaltaColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
            // S1: Coach reflection line
            if (reflection != null) ...[
              const SizedBox(height: 8),
              Text(
                reflection.text,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: MivaltaColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
              // Safety items always render
              if (reflection.safety.isNotEmpty) ...[
                const SizedBox(height: 6),
                ...reflection.safety.map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 14,
                          color: MivaltaColors.stateAccumulated,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            s,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: MivaltaColors.stateAccumulated,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
      const SizedBox(height: MivaltaSpace.x3),
    ];
  }

  /// BS-016 S1: Get today's date string for activity date comparison.
  String _todayDateStr() {
    final today = DateTime.now();
    return '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
  }

  /// BS-016 S1: Format sport name for display.
  String _formatSport(String sport) {
    if (sport.isEmpty) return 'Workout';
    // Capitalize first letter
    return '${sport[0].toUpperCase()}${sport.substring(1)}';
  }
}

/// Honest-absence pattern for module cards (I2): named state + actionable unlock.
/// DR-023 T3: token sweep — uses MivaltaType tokens.
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
          style: MivaltaType.body.copyWith(
            fontWeight: FontWeight.w500,
            color: MivaltaColors.textSoft70,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          unlock,
          style: MivaltaType.label.copyWith(
            fontWeight: FontWeight.w400,
            color: MivaltaColors.textSoft45,
          ),
        ),
      ],
    );
  }
}

/// BS-003: Zone chip for workout card. ENERGY NAME FIRST (SR1-07 ruling).
/// Maps zone code (Z1-Z8) to energy name + colour.
class _ZoneChip extends StatelessWidget {
  const _ZoneChip({required this.zone});

  final String zone;

  @override
  Widget build(BuildContext context) {
    final (name, color) = _zoneNameAndColor(zone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$name · $zone', // ENERGY NAME FIRST
        style: MivaltaType.label.copyWith(
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }

  // DR-018 A3: use shared zone naming (engine truth)
  (String, Color) _zoneNameAndColor(String zone) => zoneDisplayNameAndColor(zone);
}

/// Bottom nav item for Today/Journey/You.
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? MivaltaColors.stateProductive
        : MivaltaColors.textSecondary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: color,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: MivaltaType.label.copyWith(
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Decision chip — shows the zone cap (engine restriction) for today.
/// V2 (DR-004): check_circle icon (teal), radius md (12), label white.
/// DR-005: Zone codes must be paired with level names, never bare.
/// DR-023 T1: chip is a DECISION only when engine RESTRICTS — no sessionZone fallback.
class _DecisionChip extends StatelessWidget {
  const _DecisionChip({required this.zoneCap});

  final String? zoneCap;

  @override
  Widget build(BuildContext context) {
    if (zoneCap == null || zoneCap!.isEmpty) {
      // No chip to show — honest absence
      return const SizedBox.shrink();
    }

    final chipText = zoneDisplayLabel(zoneCap!);

    // BS-001 Step 7 present-treatment: check_circle teal, radius md (12),
    // bg rgba(0,198,167,.10), border rgba(0,198,167,.28), label white
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: MivaltaColors.stateProductive.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(MivaltaRadii.md), // 12
          border: Border.all(
            color: MivaltaColors.stateProductive.withValues(alpha: 0.28),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle,
              color: MivaltaColors.stateProductive,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              chipText,
              style: MivaltaType.small.copyWith(
                fontWeight: FontWeight.w600,
                color: MivaltaColors.textPrimary, // white, not teal
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// BS-018: kDebugMode-only wiring stamp panel.
///
/// Shows seam health status: one row per seam with name, result (ok/error), and ms.
/// Tapping the header expands/collapses the detail rows. The witness pass reads
/// this panel on device to verify that every seam says `ok` against real data.
class _WiringStamp extends StatefulWidget {
  const _WiringStamp();

  @override
  State<_WiringStamp> createState() => _WiringStampState();
}

class _WiringStampState extends State<_WiringStamp> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final entries = SeamLog.entries;
    final okCount = SeamLog.okCount;
    final errorCount = SeamLog.errorCount;
    final total = SeamLog.totalCount;

    // Header color: green if all ok, yellow if any errors, gray if empty.
    final headerColor = errorCount > 0
        ? MivaltaColors.cautionYellow
        : okCount > 0
            ? MivaltaColors.stateProductive
            : MivaltaColors.textMuted;

    return Column(
      children: [
        // Header — tap to expand/collapse
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: MivaltaSpace.x3,
              vertical: MivaltaSpace.x2,
            ),
            decoration: BoxDecoration(
              color: MivaltaColors.surface1,
              borderRadius: BorderRadius.circular(MivaltaRadii.sm),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _expanded ? Icons.unfold_less : Icons.unfold_more,
                  size: 14,
                  color: MivaltaColors.textMuted,
                ),
                const SizedBox(width: 6),
                Text(
                  'seams $okCount/$total ok',
                  style: MivaltaType.small.copyWith(
                    fontSize: 10,
                    color: headerColor,
                  ),
                ),
                if (errorCount > 0) ...[
                  const SizedBox(width: 6),
                  Text(
                    '($errorCount errors)',
                    style: MivaltaType.small.copyWith(
                      fontSize: 10,
                      color: MivaltaColors.cautionYellow,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // Detail rows (expanded)
        if (_expanded && entries.isNotEmpty) ...[
          const SizedBox(height: MivaltaSpace.x2),
          Container(
            padding: const EdgeInsets.all(MivaltaSpace.x3),
            decoration: BoxDecoration(
              color: MivaltaColors.surface1,
              borderRadius: BorderRadius.circular(MivaltaRadii.sm),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: entries.map((record) {
                final statusColor = switch (record.status) {
                  SeamStatus.ok => MivaltaColors.stateProductive,
                  SeamStatus.error => MivaltaColors.cautionYellow,
                  SeamStatus.notCalled => MivaltaColors.textMuted,
                };
                final statusText = switch (record.status) {
                  SeamStatus.ok => 'ok',
                  SeamStatus.error => 'err:${record.errorType ?? '?'}',
                  SeamStatus.notCalled => 'not-called',
                };
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          record.name,
                          style: MivaltaType.small.copyWith(
                            fontSize: 10,
                            color: MivaltaColors.textSecondary,
                          ),
                        ),
                      ),
                      Text(
                        statusText,
                        style: MivaltaType.small.copyWith(
                          fontSize: 10,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${record.durationMs}ms',
                        style: MivaltaType.small.copyWith(
                          fontSize: 10,
                          color: MivaltaColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],

        const SizedBox(height: MivaltaSpace.x4),
      ],
    );
  }
}


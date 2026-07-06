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
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/home_data.dart';
import '../models/realized_line.dart';
import '../models/workout_option.dart';
import '../rust_engine.dart';
import '../services/morning_read_gate.dart';
import '../services/notification_service.dart';
import '../services/profile_service.dart';
import '../services/weather_service.dart';
import '../theme/tokens.dart';
import '../theme/zone_names.dart';
import '../widgets/today/glow_hero.dart';
import '../widgets/today/josi_card.dart';
import '../widgets/today/metric_bar.dart';
import '../widgets/today/module_card.dart';
import '../widgets/today/sleep_stage_ring.dart';
import '../widgets/today/why_unfold.dart';
import 'advisor_screen.dart';
import 'journey_screen.dart';
import 'session_start_screen.dart';

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
      final indicatorJson = await binding.readinessIndicator(handle);
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
      try {
        final diagJson = await binding.personalizationDiagnostics(handle);
        final diag = jsonDecode(diagJson) as Map<String, dynamic>;
        data.calibrationObservations = (diag['observation_count'] as num?)?.toInt();
        data.calibrationConfidence = diag['confidence'] as String?;
      } catch (_) {
        // Honest absence — diagnostics not yet available
      }

      // State advisory (for Josi fallback)
      final stateJson = await binding.stateAdvisory(handle);
      final stateMap = jsonDecode(stateJson) as Map<String, dynamic>;
      data.stateRecommendation = stateMap['state_recommendation'] as String?;
      data.confidenceAdvisory = stateMap['confidence_advisory'] as String?;

      // BS-007: Realized advisor line (primary Josi line)
      // Date in YYYY-MM-DD format for the engine
      final today = DateTime.now();
      final dateStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      try {
        final realizedJson = await binding.realizeAdvisorLine(handle, date: dateStr);
        data.realizedLine = RealizedLine.parse(realizedJson);
      } catch (e) {
        // Honest absence — fall back to stateRecommendation
        debugPrint('realizeAdvisorLine failed: $e');
      }

      // Fatigue state (for glow color + state word)
      // Engine returns {"state":"Recovered",...} — key is "state", not "fatigue_state"
      final fatigueJson = await binding.viterbiFatigueState(handle);
      final fatigueMap = jsonDecode(fatigueJson) as Map<String, dynamic>;
      data.fatigueState = fatigueMap['state'] as String?;

      // Zone 2 — Today load (for module card)
      try {
        final loadsJson = await binding.readDailyLoads(handle, days: 1);
        final loads = jsonDecode(loadsJson) as List;
        if (loads.isNotEmpty) {
          final todayLoad = loads.last;
          if (todayLoad is List && todayLoad.length >= 2) {
            data.todayLoad = (todayLoad[1] as num?)?.toDouble();
          }
        }
      } catch (_) {
        // Honest absence
      }

      // BS-005: ACWR for Load ceiling + band line
      try {
        final acwrJson = await binding.getAcwr(handle);
        final acwr = jsonDecode(acwrJson) as Map<String, dynamic>;
        data.acwrValue = (acwr['acwr'] as num?)?.toDouble();
        data.loadCeiling = (acwr['chronic_load'] as num?)?.toDouble();
        data.loadBandLine = acwr['recommendation'] as String?;
        data.acwrZone = acwr['zone'] as String?;
      } catch (_) {
        // Honest absence — no ACWR yet
      }

      // BS-005: Source tier for caption
      try {
        final tierJson = await binding.lastObservationSourceTier(handle);
        final tier = jsonDecode(tierJson);
        if (tier != null && tier is String) {
          data.sourceTierLabel = _formatSourceTier(tier);
        }
      } catch (_) {
        // Honest absence
      }

      // Sleep (for module card)
      try {
        final bioJson = await binding.readBiometricHistory(handle, days: 1);
        final bio = jsonDecode(bioJson) as List;
        if (bio.isNotEmpty) {
          final lastBio = bio.last as Map<String, dynamic>;
          data.lastNightSleepHours = (lastBio['sleep_hours'] as num?)?.toDouble();
        }
      } catch (_) {
        // Honest absence
      }

      // Zone cap (for decision chip)
      try {
        final zoneCapJson = await binding.zoneCapWithAdvisories(handle);
        final zoneCapMap = jsonDecode(zoneCapJson) as Map<String, dynamic>;
        data.zoneCap = zoneCapMap['zone'] as String?;
      } catch (_) {
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
      try {
        final workoutJson = await binding.recommendWorkout(handle);
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
      } catch (_) {
        // Honest absence
      }

      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
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

  /// Two-tier masthead — BS-002 (Bart-approved variant 1b).
  /// Row 1: Brand wordmark centered. Row 2: Start workout left, weather right.
  Widget _buildMasthead() {
    return Padding(
      // horizontal = x4 (16) to align with module-card edges; top = 8
      padding: const EdgeInsets.fromLTRB(MivaltaSpace.x4, 8, MivaltaSpace.x4, 0),
      child: Column(
        children: [
          // ── Row 1 · brand masthead, centered ──
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset('assets/mivalta-logo.svg', width: 22, height: 22),
              const SizedBox(width: 9),
              Text(
                'MiValta',
                style: GoogleFonts.zenDots(
                  fontSize: 19,
                  letterSpacing: 0.19, // ~0.01em × 19
                  color: MivaltaColors.textPrimary,
                ),
              ),
            ],
          ),

          const SizedBox(height: MivaltaSpace.x3), // 12px

          // ── Row 2 · action micro-row ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // left · Start workout (labeled text-button, brand green)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _startWorkout,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_arrow, size: 18, color: MivaltaColors.primaryGreen),
                    SizedBox(width: 6),
                    Text(
                      'Start workout',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: MivaltaColors.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ),

              // right · weather (glanceable, text-secondary)
              _buildWeatherSlot(),
            ],
          ),
        ],
      ),
    );
  }

  /// Weather slot — real OS-provided data if available, honest absence otherwise.
  /// Rule 6: weather comes from Apple WeatherKit via the OS frame; on any failure
  /// we render nothing (no icon, no forecast), never a fabricated condition.
  Widget _buildWeatherSlot() {
    if (_weather != null) {
      final tempC = _weather!.temperatureC.round();
      final icon = _iconForWeatherSymbol(_weather!.symbol);
      final condition = _conditionForSymbol(_weather!.symbol);
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: MivaltaColors.textSecondary),
          const SizedBox(width: 5),
          Text(
            '$condition $tempC°',
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 15,
              color: MivaltaColors.textSecondary,
            ),
          ),
        ],
      );
    }
    // Honest absence (Rule 6): no real weather → render nothing, never a
    // fabricated "Sunny 18°" placeholder.
    return const SizedBox.shrink();
  }

  /// Map weather symbol to Material icon.
  IconData _iconForWeatherSymbol(String symbol) {
    return switch (symbol.toLowerCase()) {
      'sun.max' || 'sun.max.fill' => Icons.wb_sunny,
      'cloud.sun' || 'cloud.sun.fill' => Icons.wb_cloudy,
      'cloud' || 'cloud.fill' => Icons.cloud,
      'cloud.rain' || 'cloud.rain.fill' => Icons.grain,
      'cloud.heavyrain' || 'cloud.heavyrain.fill' => Icons.water_drop,
      'cloud.snow' || 'cloud.snow.fill' => Icons.ac_unit,
      'cloud.bolt' || 'cloud.bolt.fill' => Icons.bolt,
      'moon' || 'moon.fill' => Icons.nightlight,
      'cloud.moon' || 'cloud.moon.fill' => Icons.nights_stay,
      _ => Icons.wb_sunny_outlined,
    };
  }

  /// Map weather symbol to condition text.
  String _conditionForSymbol(String symbol) {
    return switch (symbol.toLowerCase()) {
      'sun.max' || 'sun.max.fill' => 'Sunny',
      'cloud.sun' || 'cloud.sun.fill' => 'Partly cloudy',
      'cloud' || 'cloud.fill' => 'Cloudy',
      'cloud.rain' || 'cloud.rain.fill' => 'Rain',
      'cloud.heavyrain' || 'cloud.heavyrain.fill' => 'Heavy rain',
      'cloud.snow' || 'cloud.snow.fill' => 'Snow',
      'cloud.bolt' || 'cloud.bolt.fill' => 'Thunderstorm',
      'moon' || 'moon.fill' => 'Clear',
      'cloud.moon' || 'cloud.moon.fill' => 'Partly cloudy',
      _ => 'Sunny',
    };
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

  /// BS-008 E-1: Shows an inline honest interim state for stub tabs (Journey/You).
  void _showInterimState(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          backgroundColor: MivaltaColors.surfaceBackground,
          appBar: AppBar(
            backgroundColor: MivaltaColors.surfaceBackground,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: MivaltaColors.textPrimary),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              title,
              style: MivaltaType.titleM.copyWith(color: MivaltaColors.textPrimary),
            ),
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(MivaltaSpace.x6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 48,
                    color: MivaltaColors.textMuted,
                  ),
                  const SizedBox(height: MivaltaSpace.x4),
                  Text(
                    message,
                    style: MivaltaType.body.copyWith(
                      color: MivaltaColors.textMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
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
                onTap: () => _showInterimState(
                  context,
                  icon: Icons.person_outline,
                  title: 'You',
                  message: 'Your profile, sources and privacy controls '
                      'land here soon.',
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
            style: const TextStyle(color: MivaltaColors.levelRed),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        // Masthead — BS-002: two-tier brand header (wordmark + action row)
        SliverToBoxAdapter(
          child: _buildMasthead(),
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
              // DR-012: Z8 is the ceiling (no restriction) — must NOT render.
              // Only restrictive caps (Z1–Z7, REST) or a session zone warrant the chip.
              () {
                final restrictiveCap = _isRestrictiveCap(_data.zoneCap);
                final hasSession = _data.sessionZone != null && _data.sessionZone!.isNotEmpty;
                final showChip = !_data.insufficientData && (restrictiveCap || hasSession);
                return showChip
                    ? Column(
                        children: [
                          const SizedBox(height: MivaltaSpace.x3),
                          _DecisionChip(
                            zoneCap: restrictiveCap ? _data.zoneCap : null,
                            sessionZone: _data.sessionZone,
                          ),
                        ],
                      )
                    : const SizedBox.shrink();
              }(),

              // Spacing before cards: reduced when Josi + chip both absent
              // DR-012: use same restrictive-cap logic for spacer
              () {
                final hasJosi = _hasJosiLine();
                final restrictiveCap = _isRestrictiveCap(_data.zoneCap);
                final hasSession = _data.sessionZone != null && _data.sessionZone!.isNotEmpty;
                final showChip = !_data.insufficientData && (restrictiveCap || hasSession);
                return SizedBox(
                  height: (!hasJosi && !showChip) ? MivaltaSpace.x2 : MivaltaSpace.x4,
                );
              }(),

              // "Your day" section eyebrow
              Padding(
                padding: const EdgeInsets.only(bottom: MivaltaSpace.x3),
                child: Text(
                  'YOUR DAY',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    letterSpacing: 1.1,
                    color: MivaltaColors.textSoft45,
                  ),
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
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: MivaltaColors.textPrimary,
                            ),
                          ),
                          // BS-003: Duration + focusCue preview
                          if (_data.durationMin != null || _data.focusCue != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              _buildWorkoutSubtitle(),
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
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
}

/// Honest-absence pattern for module cards (I2): named state + actionable unlock.
/// BS-001 Step 9: primary 15px w500 rgba(244,245,244,.7); guidance 12px rgba(244,245,244,.45)
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
            fontSize: 15, // BS-001: 15px
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
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
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
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
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

/// Decision chip — shows the zone cap or primary action for today.
/// V2 (DR-004): check_circle icon (teal), radius md (12), label white.
/// DR-005: Zone codes must be paired with level names, never bare.
/// Until engine provides level names (HANDOFF §8.2), we map to readable phrases.
class _DecisionChip extends StatelessWidget {
  const _DecisionChip({
    required this.zoneCap,
    required this.sessionZone,
  });

  final String? zoneCap;
  final String? sessionZone;

  @override
  Widget build(BuildContext context) {
    // Show zone cap if available, otherwise session zone, otherwise honest absence
    final rawZone = zoneCap ?? sessionZone;

    if (rawZone == null || rawZone.isEmpty) {
      // No chip to show — honest absence
      return const SizedBox.shrink();
    }

    final chipText = zoneDisplayLabel(rawZone);

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
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
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


// Onboarding Screen — 6-step intake flow (BS-002-onboarding v3).
//
// Sits between Auth and Today. Collects RAW answers, marshals to inputs_json,
// calls build_onboarding_profile → write_profile_to_vault → construct_engines_fresh.
// Engine DECIDES (goal_class, meso, anchor gating); Dart is pure transport.
//
// v3 (Bart's device review): Condensed from 9 to 6 screens, explain-why everywhere,
// actionable data sources step (Apple Health connect), no gear quiz.
//
// Flow: Promise → Sport → Aim+Detail → About You → Anchors → Data Sources → Payoff.

import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../rust_engine.dart';
import '../services/profile_service.dart';
import '../theme/tokens.dart';
import 'today_screen.dart';

/// The 6-step onboarding intake flow (v3 — condensed, explain-why).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  // Current step (0-indexed, 0-6 for 7 steps including payoff)
  int _currentStep = 0;

  // Entrance animation
  late AnimationController _entranceController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // ─── Engine payload fields (v2/v3 contract) ───
  // W14: Changed to multi-select — engine takes primary + secondary if contract has field.
  // Until engine contract verified, first selected = primary, rest = secondary.
  final Set<String> _selectedSports = {}; // W14: multi-select
  String? _sport; // Primary sport (first selected, for engine contract)
  String? _aim; // 'perform' | 'healthy' | 'both' → maps to goal_type
  String? _ageBand; // UI label → age int
  String? _sex; // 'female' | 'male' | 'prefer_not_say' (omitted from inputs_json if prefer_not_say)
  String? _level; // 'beginner' | 'novice' | 'intermediate' | 'advanced'
  String? _experience; // '<1' | '1-3' | '3-10' | '10+' → training_years int
  String? _weeklyHours; // '2-3' | '4-6' | '7-10' | '10+' → weekly_hours double
  double? _ftp; // null = "I don't know" (optional)
  double? _thresholdPace; // null = "I don't know" (optional)
  bool _ftpUnknown = false;
  bool _paceUnknown = false;

  // ─── App-side prefs (NOT sent to engine) ───
  String? _detail; // 'simple' | 'numbers' — stored locally

  // ─── Data sources state (v3) ───
  bool _healthConnected = false;
  bool _healthDenied = false;

  // Loading state for final step
  bool _isSubmitting = false;
  String? _error;

  // W14: Disclosure expansion state for "How your private profile works"
  bool _profileDisclosureExpanded = false;

  // C6: Persisted athlete_id (generated once, never changes).
  String _athleteId = const Uuid().v4();

  @override
  void initState() {
    super.initState();
    _loadPersistedAthleteId();
    _entranceController = AnimationController(
      vsync: this,
      duration: MivaltaMotion.standard, // 280ms
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: MivaltaMotion.standardEase),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 9), end: Offset.zero).animate(
      CurvedAnimation(parent: _entranceController, curve: MivaltaMotion.decelerate),
    );
    _entranceController.forward();
  }

  /// C6: Load persisted athlete_id or keep the generated one.
  Future<void> _loadPersistedAthleteId() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('athlete_id');
    if (stored != null) {
      _athleteId = stored;
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  /// Animate entrance when step changes.
  void _animateEntrance() {
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    if (reducedMotion) {
      _entranceController.value = 1.0;
    } else {
      _entranceController.forward(from: 0.0);
    }
  }

  /// v3: 7 steps total: Promise(0) → Sport(1) → Aim+Detail(2) → AboutYou(3) →
  /// Anchors(4, conditional) → DataSources(5) → Payoff(6)
  int get _totalSteps => 7;

  /// Anchors step shows only if sport is cycling or running.
  bool get _showAnchors => _sport == 'cycling' || _sport == 'running';

  /// Check if current step's need() is satisfied.
  bool get _canContinue {
    switch (_currentStep) {
      case 0: // Promise — always enabled
        return true;
      case 1: // Profile/Sport — W14: at least one sport selected
        return _selectedSports.isNotEmpty;
      case 2: // Aim + Detail — both required
        return _aim != null && _detail != null;
      case 3: // About You (age + sex + level + experience + hours) — all required
        return _ageBand != null &&
            _sex != null &&
            _level != null &&
            _experience != null &&
            _weeklyHours != null;
      case 4: // Anchors — optional (always enabled)
        return true;
      case 5: // Data Sources — optional (always enabled)
        return true;
      case 6: // Payoff — always enabled
        return true;
      default:
        return false;
    }
  }

  /// Go to next step.
  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      int nextStep = _currentStep + 1;
      // Skip Anchors (step 4) if sport doesn't need it
      if (nextStep == 4 && !_showAnchors) {
        nextStep = 5;
      }
      setState(() => _currentStep = nextStep);
      _animateEntrance();
    } else {
      // Final step — submit
      _submit();
    }
  }

  /// Go to previous step.
  void _prevStep() {
    if (_currentStep > 0) {
      int prevStep = _currentStep - 1;
      // Skip Anchors (step 4) if sport doesn't need it
      if (prevStep == 4 && !_showAnchors) {
        prevStep = 3;
      }
      setState(() => _currentStep = prevStep);
      _animateEntrance();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ENGINE PAYLOAD MAPPING (v2/v3 contract)
  // ─────────────────────────────────────────────────────────────────────────

  /// Map age band label → representative int.
  int _ageBandToInt(String? band) => switch (band) {
        '18–29' => 25,
        '30–39' => 35,
        '40–49' => 45,
        '50–59' => 55,
        '60+' => 65,
        _ => 35,
      };

  /// Map experience label → training_years int.
  int _experienceToYears(String? exp) => switch (exp) {
        '<1' => 0,
        '1-3' => 2,
        '3-10' => 6,
        '10+' => 12,
        _ => 2,
      };

  /// Map weekly hours label → weekly_hours double.
  double _hoursLabelToDouble(String? label) => switch (label) {
        '2-3' => 3.0,
        '4-6' => 5.0,
        '7-10' => 8.5,
        '10+' => 12.0,
        _ => 5.0,
      };

  /// Map aim → goal_type (engine vocabulary).
  /// C5 fix: engine only accepts 'performance' | 'general_fitness' (no 'balanced').
  String _aimToGoalType(String? aim) => switch (aim) {
        'perform' => 'performance',
        'healthy' => 'general_fitness',
        'both' => 'general_fitness', // C5: engine has no 'balanced'
        _ => 'general_fitness',
      };

  /// Build inputs_json for engine (v2/v3 contract).
  Map<String, dynamic> _buildInputsJson() {
    final inputs = <String, dynamic>{
      'athlete_id': _athleteId,
      'age': _ageBandToInt(_ageBand),
      'level': _level,
      'sport': _sport,
      'goal_type': _aimToGoalType(_aim),
      'weekly_hours': _hoursLabelToDouble(_weeklyHours),
      'training_years': _experienceToYears(_experience),
    };

    // §0b: sex is optional — omit if "I'd rather not say"
    if (_sex != null && _sex != 'prefer_not_say') {
      inputs['sex'] = _sex;
    }

    // Optional anchors — null means "I don't know"
    if (_sport == 'cycling') {
      inputs['ftp_watts'] = _ftpUnknown ? null : _ftp?.toInt();
    }
    if (_sport == 'running') {
      final paceMinKm = _paceUnknown ? null : _thresholdPace;
      inputs['threshold_pace_sec_km'] = paceMinKm != null ? (paceMinKm * 60).toInt() : null;
    }

    return inputs;
  }

  /// Save app-side prefs (detail, athlete_id) locally.
  Future<void> _saveLocalPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('athlete_id', _athleteId);
    if (_detail != null) {
      await prefs.setString('onboarding_detail', _detail!);
    }
    // v3: health_connected status
    await prefs.setBool('health_connected', _healthConnected);
  }

  /// Submit onboarding — call engine, write profile, route to Today.
  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      await _saveLocalPrefs();

      final inputsJson = jsonEncode(_buildInputsJson());
      debugPrint('Onboarding inputs_json: $inputsJson');

      // 1. Build profile from inputs
      final profileJson = await RustEngineBinding.buildOnboardingProfile(inputsJson);
      debugPrint('Onboarding profile JSON: $profileJson');

      // 2. Write profile to vault
      final vaultPath = await ProfileService.getVaultPath();
      final binding = await RustEngineBinding.bootstrap();
      await binding.writeProfileToVault(
        athleteProfileJson: profileJson,
        vaultPath: vaultPath,
      );

      // 3. Save profile locally
      await ProfileService.saveProfile(profileJson);

      // 4. Construct engines fresh
      final tablesJson = await rootBundle.loadString('assets/compiled_tables.json');
      final handle = await binding.constructEnginesFresh(
        athleteProfileJson: profileJson,
        tablesJson: tablesJson,
        vaultPath: vaultPath,
      );
      debugPrint('Onboarding: Engines constructed, handle=$handle');

      // 5. Route to Today
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const TodayScreen()),
        );
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _error = e.toString();
      });
      debugPrint('Onboarding error: $e');
    }
  }

  /// v3: Request Apple Health permission.
  Future<void> _connectAppleHealth() async {
    try {
      final health = Health();
      await health.configure();

      final types = [
        HealthDataType.HEART_RATE,
        HealthDataType.RESTING_HEART_RATE,
        HealthDataType.HEART_RATE_VARIABILITY_SDNN,
        HealthDataType.SLEEP_ASLEEP,
        HealthDataType.SLEEP_AWAKE,
        HealthDataType.SLEEP_IN_BED,
        HealthDataType.WORKOUT,
      ];

      final permissions = types.map((t) => HealthDataAccess.READ).toList();
      final granted = await health.requestAuthorization(types, permissions: permissions);

      setState(() {
        _healthConnected = granted;
        _healthDenied = !granted;
      });
    } catch (e) {
      debugPrint('Health connect error: $e');
      setState(() {
        _healthDenied = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.of(context).disableAnimations;

    return Scaffold(
      backgroundColor: MivaltaColors.surfaceBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Progress dots (not on step 0 Promise)
            if (_currentStep > 0) _buildProgressDots(),

            // Step content
            Expanded(
              child: reducedMotion
                  ? _buildStepContent()
                  : AnimatedBuilder(
                      animation: _entranceController,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: _slideAnimation.value,
                          child: Opacity(
                            opacity: _fadeAnimation.value,
                            child: child,
                          ),
                        );
                      },
                      child: _buildStepContent(),
                    ),
            ),

            // Error message
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: MivaltaSpace.x4),
                child: Container(
                  padding: const EdgeInsets.all(MivaltaSpace.x3),
                  decoration: BoxDecoration(
                    color: MivaltaColors.levelRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(MivaltaRadii.md),
                  ),
                  child: Text(
                    "Something didn't take — try again",
                    style: MivaltaType.small.copyWith(color: MivaltaColors.levelRed),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

            // Bottom buttons
            _buildBottomButtons(),

            const SizedBox(height: MivaltaSpace.x4),
          ],
        ),
      ),
    );
  }

  /// Progress dots — step k of total.
  Widget _buildProgressDots() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MivaltaSpace.x4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_totalSteps, (index) {
          // Skip Anchors dot if not applicable
          final isAnchorsStep = index == 4;
          if (isAnchorsStep && !_showAnchors) {
            return const SizedBox.shrink();
          }

          final isDone = index < _currentStep;
          final isCurrent = index == _currentStep;

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDone
                  ? MivaltaColors.stateProductive
                  : isCurrent
                      ? MivaltaColors.textPrimary
                      : MivaltaColors.textMuted.withValues(alpha: 0.3),
            ),
          );
        }),
      ),
    );
  }

  /// Step content switcher.
  Widget _buildStepContent() {
    return switch (_currentStep) {
      0 => _buildPromiseStep(),
      1 => _buildSportStep(),
      2 => _buildAimDetailStep(), // v3: combined
      3 => _buildAboutYouStep(), // v3: all basics on one screen
      4 => _buildAnchorsStep(), // v3: with explanation
      5 => _buildDataSourcesStep(), // v3: replaces gear
      6 => _buildPayoffStep(),
      _ => const SizedBox.shrink(),
    };
  }

  /// Bottom buttons.
  Widget _buildBottomButtons() {
    final showBack = _currentStep > 0 && _currentStep < _totalSteps - 1;
    final isLastStep = _currentStep == _totalSteps - 1;
    final buttonText = _currentStep == 0
        ? 'Get started'
        : isLastStep
            ? 'Enter MiValta'
            : 'Continue';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MivaltaSpace.x4),
      child: Column(
        children: [
          if (showBack)
            Semantics(
              button: true,
              label: 'Back',
              child: GestureDetector(
                onTap: _prevStep,
                child: Container(
                  height: 44,
                  alignment: Alignment.center,
                  child: Text(
                    'Back',
                    style: MivaltaType.body.copyWith(color: MivaltaColors.textSecondary),
                  ),
                ),
              ),
            ),

          if (showBack) const SizedBox(height: MivaltaSpace.x2),

          Semantics(
            button: true,
            enabled: _canContinue && !_isSubmitting,
            label: buttonText,
            child: GestureDetector(
              onTap: _canContinue && !_isSubmitting ? _nextStep : null,
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: _canContinue
                      ? MivaltaColors.stateProductive
                      : MivaltaColors.stateProductive.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: MivaltaColors.surfaceBackground,
                        ),
                      )
                    : Text(
                        buttonText,
                        style: MivaltaType.body.copyWith(
                          color: MivaltaColors.surfaceBackground,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STEP BUILDERS (v3)
  // ─────────────────────────────────────────────────────────────────────────

  /// BS-002a Round 3 (redline RL-promise-r3.html): Glow HUGS the 96px mark.
  /// Layout box = logo size (96), halos overflow unclipped via Clip.none.
  /// Halo sizes: 245 outer, 162 mid (same as auth, per redline).
  Widget _buildPromiseGlow() {
    // Round 3 redline: layout box = 96px, halos overflow
    const logoSize = 96.0;
    // Redline spec: 245 outer, 162 mid (same blurs as auth)
    const outerSize = 245.0;
    const midSize = 162.0;

    return SizedBox(
      width: logoSize,
      height: logoSize,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none, // Round 3: halos may overflow
        children: [
          // Outer halo (positioned to overflow center)
          Positioned(
            left: (logoSize - outerSize) / 2,
            top: (logoSize - outerSize) / 2,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(
                sigmaX: MivaltaGlow.authOuterBlur,
                sigmaY: MivaltaGlow.authOuterBlur,
              ),
              child: Container(
                width: outerSize,
                height: outerSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      MivaltaColors.tertiaryTealSolid.withValues(
                        alpha: MivaltaGlow.authOuterAlpha,
                      ),
                      Colors.transparent,
                    ],
                    stops: [0.0, MivaltaGlow.authOuterStop],
                  ),
                ),
              ),
            ),
          ),

          // Mid halo (positioned to overflow center)
          Positioned(
            left: (logoSize - midSize) / 2,
            top: (logoSize - midSize) / 2,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(
                sigmaX: MivaltaGlow.authMidBlur,
                sigmaY: MivaltaGlow.authMidBlur,
              ),
              child: Container(
                width: midSize,
                height: midSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      MivaltaColors.tertiaryTealSolid.withValues(
                        alpha: MivaltaGlow.authMidAlpha,
                      ),
                      Colors.transparent,
                    ],
                    stops: [0.0, MivaltaGlow.authMidStop],
                  ),
                ),
              ),
            ),
          ),

          // Logo (96px) — Round 3: brand cover, match splash
          SvgPicture.asset(
            'assets/mivalta-logo.svg',
            width: logoSize,
            height: logoSize,
          ),
        ],
      ),
    );
  }

  /// Step 0: Promise (BS-002a Round 3 redline: RL-promise-r3.html).
  /// 94px below safe-area top, mark-to-title gap 20px, no restore link.
  Widget _buildPromiseStep() {
    // Round 3 redline: 94px below safe-area top (18% of 852px viewport - safe top)
    // NOT a percentage of available height; fixed 94px matches the redline exactly.
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(
          top: 94, // Redline: 94px below safe-area top
          left: MivaltaSpace.x4,
          right: MivaltaSpace.x4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Round 3: Logo (96px, glow hugs mark) — brand cover of intake.
            _buildPromiseGlow(),

            // Redline: 20px gap (visual mark edge → title cap)
            // Note: MivaltaSpace.x5 is 24px but redline specifies 20px exactly.
            const SizedBox(height: 20),

            // Title — MivaltaType.titleXL (40px, w700, -0.02em, lh 1.2)
            Text(
              'Your body.\nYour data.',
              style: MivaltaType.titleXL.copyWith(color: MivaltaColors.textPrimary),
              textAlign: TextAlign.center,
            ),

            // Redline: x4 = 16px (title → sub1)
            const SizedBox(height: MivaltaSpace.x4),

            // BS-002a FINAL: "Private by design."
            Text(
              'Private by design.',
              style: MivaltaType.body.copyWith(color: MivaltaColors.textSecondary),
              textAlign: TextAlign.center,
            ),

            // Redline: x2 = 8px (sub1 → sub2)
            const SizedBox(height: MivaltaSpace.x2),

            // BS-002a FINAL: "Let's personalize MiValta to you."
            Text(
              "Let's personalize MiValta to you.",
              style: MivaltaType.body.copyWith(color: MivaltaColors.textSecondary),
              textAlign: TextAlign.center,
            ),

            // Round 3: Restore link DELETED — seam doesn't exist yet (BS-017 blocked).
            // Returns with the real restore flow, on Auth, when the seam lands.
          ],
        ),
      ),
    );
  }

  /// Step 1: Profile (BS-002c v3 — redline RL-profile-r1.html).
  /// Two states: collapsed (default) + expanded disclosure.
  Widget _buildSportStep() {
    const sports = [
      ('running', Icons.directions_run, 'Running'),
      ('cycling', Icons.directions_bike, 'Cycling'),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: MivaltaSpace.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Redline: x6 top (24px)
          const SizedBox(height: MivaltaSpace.x6),

          // Redline: title-lg 24px
          Text(
            'Your profile',
            style: MivaltaType.titleL.copyWith(color: MivaltaColors.textPrimary),
          ),

          // Redline: x3 (12px) gap to sub
          const SizedBox(height: MivaltaSpace.x3),

          // BS-002c v3: Sub with bold last line (verbatim)
          RichText(
            text: TextSpan(
              style: MivaltaType.body.copyWith(
                color: MivaltaColors.textSecondary,
                height: 1.5,
              ),
              children: [
                const TextSpan(
                  text: 'With your input, MiValta builds a personal profile that '
                      'becomes more accurate over time as it learns from and '
                      'with you.\n\n',
                ),
                TextSpan(
                  text: 'Your data stays on your device. Never on a server. '
                      'Real privacy. Real control.',
                  style: MivaltaType.body.copyWith(
                    color: MivaltaColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Redline: x4 (16px) gap to disclosure
          const SizedBox(height: MivaltaSpace.x4),

          // BS-002c v2: Disclosure row
          _buildProfileDisclosure(),

          // Redline: x5 (20px) gap to question lead
          const SizedBox(height: MivaltaSpace.x5),

          // Redline: lead = body weight 600
          Text(
            "Let's start with your sports.",
            style: MivaltaType.body.copyWith(
              color: MivaltaColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),

          // Redline: x1 (4px) gap to caption
          const SizedBox(height: MivaltaSpace.x1),

          // Redline: caption = small textSecondary
          Text(
            'Select all that apply.',
            style: MivaltaType.small.copyWith(color: MivaltaColors.textSecondary),
          ),

          // Redline: x3 (12px) gap to first sport row, then x3 between rows
          const SizedBox(height: MivaltaSpace.x3),

          // Multi-select sports (checkbox semantics)
          ...sports.map((s) {
            final (id, icon, label) = s;
            final isSelected = _selectedSports.contains(id);
            return _buildSportRow(
              icon: icon,
              label: label,
              isSelected: isSelected,
              onTap: () => setState(() {
                if (isSelected) {
                  _selectedSports.remove(id);
                } else {
                  _selectedSports.add(id);
                }
                // First selected = primary sport for engine
                _sport = _selectedSports.isNotEmpty ? _selectedSports.first : null;
              }),
            );
          }),

          // BS-002c v2: Footer REMOVED on this step (one-claim law).
          // Sub already says "Never on a server" — redundant.

          const SizedBox(height: MivaltaSpace.x4),
        ],
      ),
    );
  }

  /// BS-002c v3: Disclosure row with expandable privacy explanation.
  /// Redline: RL-profile-r1.html — both states (collapsed + expanded).
  Widget _buildProfileDisclosure() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Disclosure row: lock glyph + label + chevron (≥44px)
        GestureDetector(
          onTap: () => setState(() => _profileDisclosureExpanded = !_profileDisclosureExpanded),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            child: Row(
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 18,
                  color: MivaltaColors.textSecondary,
                ),
                const SizedBox(width: MivaltaSpace.x2),
                Expanded(
                  // BS-002c v2: Label text — turns textPrimary when open
                  child: Text(
                    'Why we ask these questions',
                    style: MivaltaType.body.copyWith(
                      color: _profileDisclosureExpanded
                          ? MivaltaColors.textPrimary
                          : MivaltaColors.textSecondary,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: _profileDisclosureExpanded ? 0.5 : 0.0,
                  duration: MivaltaMotion.standard,
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    size: 24,
                    color: MivaltaColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Expanded body — AnimatedSize for smooth expand/collapse (280ms)
        AnimatedSize(
          duration: MivaltaMotion.standard,
          curve: MivaltaMotion.standardEase,
          alignment: Alignment.topLeft,
          child: _profileDisclosureExpanded
              ? Padding(
                  // Redline: indent 26px (aligns under label, not lock)
                  padding: const EdgeInsets.only(
                    top: MivaltaSpace.x3,
                    left: 26,
                  ),
                  // BS-002c v3: Full disclosure body (verbatim)
                  child: RichText(
                    text: TextSpan(
                      style: MivaltaType.small.copyWith(
                        color: MivaltaColors.textSecondary,
                        height: 1.55,
                      ),
                      children: [
                        const TextSpan(
                          text: "Every answer you provide helps MiValta build a profile "
                              "that is uniquely yours. Because no two people are the same, "
                              "your profile continuously evolves as it learns from and "
                              "with you.\n\n",
                        ),
                        const TextSpan(
                          text: "The more you choose to share — such as your sports, goals, "
                              "training history, wearable data and your own feedback — the "
                              "better MiValta understands your body, your habits and your "
                              "progress. Over time, this enables increasingly accurate "
                              "insights, more meaningful feedback and, if you choose, "
                              "highly personalized training plans.\n\n",
                        ),
                        const TextSpan(
                          text: "Your profile is built and stored entirely on your device, "
                              "where MiValta's AI runs locally. Your health data, training "
                              "history and personal profile are never uploaded to MiValta "
                              "or any server.\n\n",
                        ),
                        const TextSpan(
                          text: "Your account exists only to manage your email, membership "
                              "and access to premium features. It is never connected to "
                              "your personal profile or your health and training data.\n\n",
                        ),
                        // Closing line: weight 600 / textPrimary
                        TextSpan(
                          text: "Your data remains yours. Your profile remains yours. Always.",
                          style: MivaltaType.small.copyWith(
                            color: MivaltaColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            height: 1.55,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  /// Step 2: Aim + Detail (v3: combined on one screen).
  Widget _buildAimDetailStep() {
    const aims = [
      ('perform', 'Perform', 'Train to compete and hit personal bests'),
      ('healthy', 'Stay fit & healthy', 'Move regularly without overtraining'),
      ('both', 'A bit of both', 'Balance performance with sustainable fitness'),
    ];

    const details = [
      ('simple', 'Just tell me what to do', 'Clear guidance without the numbers'),
      ('numbers', 'Show me the numbers too', 'See the data behind the decisions'),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: MivaltaSpace.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: MivaltaSpace.x6),

          Text(
            'Your aim',
            style: MivaltaType.titleL.copyWith(color: MivaltaColors.textPrimary),
          ),

          const SizedBox(height: MivaltaSpace.x4),

          ...aims.map((a) {
            final (id, title, desc) = a;
            final isSelected = _aim == id;
            return _buildOptionRow(
              title: title,
              description: desc,
              isSelected: isSelected,
              onTap: () => setState(() => _aim = id),
            );
          }),

          const SizedBox(height: MivaltaSpace.x4),

          // v3: Slim divider
          Container(
            height: 1,
            color: MivaltaColors.textMuted.withValues(alpha: 0.2),
          ),

          const SizedBox(height: MivaltaSpace.x4),

          // v3: Detail on same screen
          Text(
            'How should MiValta talk to you?',
            style: MivaltaType.cardTitle.copyWith(color: MivaltaColors.textSecondary),
          ),

          const SizedBox(height: MivaltaSpace.x3),

          ...details.map((d) {
            final (id, title, desc) = d;
            final isSelected = _detail == id;
            return _buildCompactOptionRow(
              title: title,
              description: desc,
              isSelected: isSelected,
              onTap: () => setState(() => _detail = id),
            );
          }),

          const SizedBox(height: MivaltaSpace.x4),
        ],
      ),
    );
  }

  /// Step 3: About You (v3: all basics on one scrollable screen).
  Widget _buildAboutYouStep() {
    const ageBands = ['18–29', '30–39', '40–49', '50–59', '60+'];
    // E6 flag-hide: "I'd rather not say" hidden until engine G9 (sex as Option) is live.
    // The engine requires a real sex value at current pin (a579584).
    const sexOptions = ['Female', 'Male'];
    const levels = [
      ('beginner', 'Beginner'),
      ('novice', 'Getting back'),
      ('intermediate', 'Trained'),
      ('advanced', 'Advanced'),
    ];
    const experience = [
      ('<1', 'Less than a year'),
      ('1-3', '1–3 years'),
      ('3-10', '3–10 years'),
      ('10+', '10+ years'),
    ];
    const hours = [
      ('2-3', '2–3 hours'),
      ('4-6', '4–6 hours'),
      ('7-10', '7–10 hours'),
      ('10+', '10+ hours'),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: MivaltaSpace.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: MivaltaSpace.x6),

          Text(
            'About you',
            style: MivaltaType.titleL.copyWith(color: MivaltaColors.textPrimary),
          ),

          const SizedBox(height: MivaltaSpace.x2),

          // v3: Intro explaining why
          Text(
            "Five quick facts — they set your starting zones and how hard MiValta lets a day be. All of it stays on this phone.",
            style: MivaltaType.small.copyWith(color: MivaltaColors.textMuted),
          ),

          const SizedBox(height: MivaltaSpace.x5),

          // Age band
          Text(
            'Age',
            style: MivaltaType.cardTitle.copyWith(color: MivaltaColors.textSecondary),
          ),
          const SizedBox(height: MivaltaSpace.x3),
          Wrap(
            spacing: MivaltaSpace.x2,
            runSpacing: MivaltaSpace.x2,
            children: ageBands.map((band) {
              final isSelected = _ageBand == band;
              return _buildSmallChip(
                label: band,
                isSelected: isSelected,
                onTap: () => setState(() => _ageBand = band),
              );
            }).toList(),
          ),

          const SizedBox(height: MivaltaSpace.x5),

          // Sex
          Text(
            'Sex',
            style: MivaltaType.cardTitle.copyWith(color: MivaltaColors.textSecondary),
          ),
          const SizedBox(height: MivaltaSpace.x2),
          Text(
            'Used only on-device, to set heart-rate zones.',
            style: MivaltaType.small.copyWith(color: MivaltaColors.textMuted),
          ),
          const SizedBox(height: MivaltaSpace.x3),
          Wrap(
            spacing: MivaltaSpace.x2,
            runSpacing: MivaltaSpace.x2,
            children: sexOptions.map((option) {
              // E6: simplified - no prefer_not_say case until G9 is live
              final value = option.toLowerCase();
              final isSelected = _sex == value;
              return _buildSmallChip(
                label: option,
                isSelected: isSelected,
                onTap: () => setState(() => _sex = value),
              );
            }).toList(),
          ),

          const SizedBox(height: MivaltaSpace.x5),

          // Level
          Text(
            'Current level',
            style: MivaltaType.cardTitle.copyWith(color: MivaltaColors.textSecondary),
          ),
          const SizedBox(height: MivaltaSpace.x3),
          Wrap(
            spacing: MivaltaSpace.x2,
            runSpacing: MivaltaSpace.x2,
            children: levels.map((l) {
              final (id, label) = l;
              final isSelected = _level == id;
              return _buildSmallChip(
                label: label,
                isSelected: isSelected,
                onTap: () => setState(() => _level = id),
              );
            }).toList(),
          ),

          const SizedBox(height: MivaltaSpace.x5),

          // Experience
          Text(
            'How long have you trained?',
            style: MivaltaType.cardTitle.copyWith(color: MivaltaColors.textSecondary),
          ),
          const SizedBox(height: MivaltaSpace.x3),
          Wrap(
            spacing: MivaltaSpace.x2,
            runSpacing: MivaltaSpace.x2,
            children: experience.map((e) {
              final (id, label) = e;
              final isSelected = _experience == id;
              return _buildSmallChip(
                label: label,
                isSelected: isSelected,
                onTap: () => setState(() => _experience = id),
              );
            }).toList(),
          ),

          const SizedBox(height: MivaltaSpace.x5),

          // Weekly hours
          Text(
            'Time you can give it, most weeks',
            style: MivaltaType.cardTitle.copyWith(color: MivaltaColors.textSecondary),
          ),
          const SizedBox(height: MivaltaSpace.x3),
          Wrap(
            spacing: MivaltaSpace.x2,
            runSpacing: MivaltaSpace.x2,
            children: hours.map((h) {
              final (id, label) = h;
              final isSelected = _weeklyHours == id;
              return _buildSmallChip(
                label: label,
                isSelected: isSelected,
                onTap: () => setState(() => _weeklyHours = id),
              );
            }).toList(),
          ),

          const SizedBox(height: MivaltaSpace.x5),

          // v3: Footer on every data screen
          Center(
            child: Text(
              'On this phone. Never on a server.',
              style: MivaltaType.small.copyWith(color: MivaltaColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: MivaltaSpace.x6),
        ],
      ),
    );
  }

  /// Step 4: Anchors (v3: with explanation).
  Widget _buildAnchorsStep() {
    final isRunning = _sport == 'running';
    final isCycling = _sport == 'cycling';

    // v3: Sport-specific title and intro
    final title = isRunning ? 'Your running threshold' : 'Your FTP';
    final intro = isRunning
        ? "If you know your threshold pace — the fastest pace you could hold for about an hour — MiValta sets your training zones from day one. From a recent race or test is perfect."
        : "If you know your FTP from a test or a head unit, MiValta sets your power zones from day one.";

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: MivaltaSpace.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: MivaltaSpace.x6),

          Text(
            title,
            style: MivaltaType.titleL.copyWith(color: MivaltaColors.textPrimary),
          ),

          const SizedBox(height: MivaltaSpace.x2),

          // v3: Explain why
          Text(
            intro,
            style: MivaltaType.body.copyWith(color: MivaltaColors.textSecondary),
          ),

          const SizedBox(height: MivaltaSpace.x5),

          // FTP (cycling)
          if (isCycling) ...[
            _buildAnchorInput(
              label: 'FTP (watts)',
              value: _ftp,
              isUnknown: _ftpUnknown,
              onChanged: (v) => setState(() {
                _ftp = v;
                _ftpUnknown = false;
              }),
              onUnknown: () => setState(() {
                _ftpUnknown = !_ftpUnknown;
                if (_ftpUnknown) _ftp = null;
              }),
            ),
          ],

          // Threshold pace (running)
          if (isRunning) ...[
            _buildAnchorInput(
              label: 'Threshold pace (min/km)',
              value: _thresholdPace,
              isUnknown: _paceUnknown,
              onChanged: (v) => setState(() {
                _thresholdPace = v;
                _paceUnknown = false;
              }),
              onUnknown: () => setState(() {
                _paceUnknown = !_paceUnknown;
                if (_paceUnknown) _thresholdPace = null;
              }),
            ),
          ],

          // v3: Reassurance line when "I don't know" is selected
          if (_ftpUnknown || _paceUnknown) ...[
            const SizedBox(height: MivaltaSpace.x4),
            Text(
              'MiValta will find it from your first sessions.',
              style: MivaltaType.body.copyWith(color: MivaltaColors.stateProductive),
            ),
          ],

          const SizedBox(height: MivaltaSpace.x5),

          // v3: Footer on every data screen
          Center(
            child: Text(
              'On this phone. Never on a server.',
              style: MivaltaType.small.copyWith(color: MivaltaColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: MivaltaSpace.x6),
        ],
      ),
    );
  }

  /// Step 5: Data Sources (v3: replaces gear, actionable).
  Widget _buildDataSourcesStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: MivaltaSpace.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: MivaltaSpace.x6),

          Text(
            'Where your data comes from',
            style: MivaltaType.titleL.copyWith(color: MivaltaColors.textPrimary),
          ),

          const SizedBox(height: MivaltaSpace.x2),

          Text(
            "Connect a source and MiValta reads sleep, heart rate and workouts automatically — on the phone, never through our servers.",
            style: MivaltaType.body.copyWith(color: MivaltaColors.textSecondary),
          ),

          const SizedBox(height: MivaltaSpace.x5),

          // Apple Health row (actionable)
          _buildDataSourceRow(
            icon: Icons.favorite,
            iconColor: MivaltaColors.levelRed,
            title: 'Apple Health',
            status: _healthConnected
                ? 'Connected ✓'
                : _healthDenied
                    ? 'Not now'
                    : null,
            buttonText: _healthConnected || _healthDenied ? null : 'Connect',
            onTap: _healthConnected || _healthDenied ? null : _connectAppleHealth,
          ),

          const SizedBox(height: MivaltaSpace.x4),

          // Platform rows (coming soon)
          _buildDataSourceRow(
            icon: Icons.directions_bike,
            iconColor: MivaltaColors.levelOrange,
            title: 'Strava',
            status: 'coming soon',
            isMuted: true,
            onTapInfo: () => _showPlatformInfo(context),
          ),

          const SizedBox(height: MivaltaSpace.x3),

          _buildDataSourceRow(
            icon: Icons.watch,
            iconColor: MivaltaColors.textSecondary,
            title: 'Garmin',
            status: 'coming soon',
            isMuted: true,
            onTapInfo: () => _showPlatformInfo(context),
          ),

          const SizedBox(height: MivaltaSpace.x3),

          _buildDataSourceRow(
            icon: Icons.monitor_heart,
            iconColor: MivaltaColors.levelRed,
            title: 'Polar',
            status: 'coming soon',
            isMuted: true,
            onTapInfo: () => _showPlatformInfo(context),
          ),

          const SizedBox(height: MivaltaSpace.x6),

          // v3: Footer on every data screen
          Center(
            child: Text(
              'On this phone. Never on a server.',
              style: MivaltaType.small.copyWith(color: MivaltaColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: MivaltaSpace.x4),
        ],
      ),
    );
  }

  /// Show platform sync info.
  void _showPlatformInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: MivaltaColors.surface1,
        title: Text(
          'Platform sync',
          style: MivaltaType.cardTitle.copyWith(color: MivaltaColors.textPrimary),
        ),
        content: Text(
          "Platform sync is on the roadmap — your watch's data already arrives via Apple Health.",
          style: MivaltaType.body.copyWith(color: MivaltaColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Got it',
              style: MivaltaType.body.copyWith(color: MivaltaColors.stateProductive),
            ),
          ),
        ],
      ),
    );
  }

  /// Step 6: Payoff (unchanged).
  Widget _buildPayoffStep() {
    final aimLine = switch (_aim) {
      'perform' => 'Ready to push your limits.',
      'healthy' => 'Built for sustainable fitness.',
      'both' => 'Balanced for performance and health.',
      _ => 'Tuned to your answers.',
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: MivaltaSpace.x4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPayoffGlow(),

            const SizedBox(height: MivaltaSpace.x5),

            Text(
              aimLine,
              style: MivaltaType.titleM.copyWith(color: MivaltaColors.textPrimary),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: MivaltaSpace.x4),

            Text(
              'Learning you — your first few days of data shape a picture just for you.',
              style: MivaltaType.body.copyWith(color: MivaltaColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Payoff mini glow.
  Widget _buildPayoffGlow() {
    const glowSize = MivaltaGlow.onbPayoffGlowSize;
    const color = MivaltaColors.stateProductive;

    return SizedBox(
      width: glowSize,
      height: glowSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: MivaltaGlow.onbPayoffOuterBlur,
              sigmaY: MivaltaGlow.onbPayoffOuterBlur,
            ),
            child: Container(
              width: glowSize,
              height: glowSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    color.withValues(alpha: MivaltaGlow.onbPayoffOuterAlpha),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.66],
                ),
              ),
            ),
          ),
          ImageFiltered(
            imageFilter: ImageFilter.blur(
              sigmaX: MivaltaGlow.onbPayoffMidBlur,
              sigmaY: MivaltaGlow.onbPayoffMidBlur,
            ),
            child: Container(
              width: glowSize * 0.7,
              height: glowSize * 0.7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    color.withValues(alpha: MivaltaGlow.onbPayoffMidAlpha),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.66],
                ),
              ),
            ),
          ),
          Text(
            'Good to go',
            style: MivaltaType.titleL.copyWith(color: MivaltaColors.textPrimary),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SHARED WIDGETS
  // ─────────────────────────────────────────────────────────────────────────

  /// Sport row.
  Widget _buildSportRow({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Semantics(
      toggled: isSelected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: MivaltaSpace.x3),
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(
            horizontal: MivaltaSpace.x4,
            vertical: MivaltaSpace.x4,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? MivaltaColors.stateProductive.withValues(alpha: 0.15)
                : MivaltaColors.surface1,
            borderRadius: BorderRadius.circular(MivaltaRadii.md),
            border: Border.all(
              color: isSelected
                  ? MivaltaColors.stateProductive
                  : MivaltaColors.textMuted.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 28,
                color: isSelected
                    ? MivaltaColors.stateProductive
                    : MivaltaColors.textSecondary,
              ),
              const SizedBox(width: MivaltaSpace.x4),
              Expanded(
                child: Text(
                  label,
                  style: MivaltaType.cardTitle.copyWith(
                    color: isSelected
                        ? MivaltaColors.stateProductive
                        : MivaltaColors.textPrimary,
                  ),
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle,
                  color: MivaltaColors.stateProductive,
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Small chip.
  Widget _buildSmallChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Semantics(
      toggled: isSelected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(
            horizontal: MivaltaSpace.x4,
            vertical: MivaltaSpace.x3,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? MivaltaColors.stateProductive.withValues(alpha: 0.15)
                : MivaltaColors.surface1,
            borderRadius: BorderRadius.circular(MivaltaRadii.md),
            border: Border.all(
              color: isSelected
                  ? MivaltaColors.stateProductive
                  : MivaltaColors.textMuted.withValues(alpha: 0.2),
            ),
          ),
          child: Text(
            label,
            style: MivaltaType.body.copyWith(
              color: isSelected
                  ? MivaltaColors.stateProductive
                  : MivaltaColors.textPrimary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  /// Option row.
  Widget _buildOptionRow({
    required String title,
    required String description,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Semantics(
      toggled: isSelected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: MivaltaSpace.x3),
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.all(MivaltaSpace.x4),
          decoration: BoxDecoration(
            color: isSelected
                ? MivaltaColors.stateProductive.withValues(alpha: 0.15)
                : MivaltaColors.surface1,
            borderRadius: BorderRadius.circular(MivaltaRadii.md),
            border: Border.all(
              color: isSelected
                  ? MivaltaColors.stateProductive
                  : MivaltaColors.textMuted.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: MivaltaType.cardTitle.copyWith(
                        color: isSelected
                            ? MivaltaColors.stateProductive
                            : MivaltaColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: MivaltaType.small.copyWith(
                        color: MivaltaColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle,
                  color: MivaltaColors.stateProductive,
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Compact option row.
  Widget _buildCompactOptionRow({
    required String title,
    required String description,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Semantics(
      toggled: isSelected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: MivaltaSpace.x2),
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(
            horizontal: MivaltaSpace.x4,
            vertical: MivaltaSpace.x3,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? MivaltaColors.stateProductive.withValues(alpha: 0.15)
                : MivaltaColors.surface1,
            borderRadius: BorderRadius.circular(MivaltaRadii.md),
            border: Border.all(
              color: isSelected
                  ? MivaltaColors.stateProductive
                  : MivaltaColors.textMuted.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: MivaltaType.body.copyWith(
                        color: isSelected
                            ? MivaltaColors.stateProductive
                            : MivaltaColors.textPrimary,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    Text(
                      description,
                      style: MivaltaType.small.copyWith(
                        color: MivaltaColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle,
                  color: MivaltaColors.stateProductive,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Anchor input with "I don't know" chip.
  Widget _buildAnchorInput({
    required String label,
    required double? value,
    required bool isUnknown,
    required ValueChanged<double?> onChanged,
    required VoidCallback onUnknown,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: MivaltaType.cardTitle.copyWith(color: MivaltaColors.textSecondary),
        ),

        const SizedBox(height: MivaltaSpace.x3),

        Row(
          children: [
            Expanded(
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: MivaltaSpace.x4),
                decoration: BoxDecoration(
                  color: isUnknown
                      ? MivaltaColors.textMuted.withValues(alpha: 0.1)
                      : MivaltaColors.surface1,
                  borderRadius: BorderRadius.circular(MivaltaRadii.md),
                  border: Border.all(
                    color: MivaltaColors.textMuted.withValues(alpha: 0.2),
                  ),
                ),
                child: TextField(
                  enabled: !isUnknown,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: MivaltaType.body.copyWith(color: MivaltaColors.textPrimary),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: isUnknown ? "I don't know" : 'Enter value',
                    hintStyle: MivaltaType.body.copyWith(color: MivaltaColors.textMuted),
                  ),
                  onChanged: (text) {
                    final v = double.tryParse(text);
                    onChanged(v);
                  },
                ),
              ),
            ),

            const SizedBox(width: MivaltaSpace.x3),

            _buildSmallChip(
              label: "I don't know",
              isSelected: isUnknown,
              onTap: onUnknown,
            ),
          ],
        ),
      ],
    );
  }

  /// Data source row (v3).
  Widget _buildDataSourceRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? status,
    String? buttonText,
    bool isMuted = false,
    VoidCallback? onTap,
    VoidCallback? onTapInfo,
  }) {
    return GestureDetector(
      onTap: onTap ?? onTapInfo,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(
          horizontal: MivaltaSpace.x4,
          vertical: MivaltaSpace.x3,
        ),
        decoration: BoxDecoration(
          color: MivaltaColors.surface1,
          borderRadius: BorderRadius.circular(MivaltaRadii.md),
          border: Border.all(
            color: MivaltaColors.textMuted.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 24,
              color: isMuted ? MivaltaColors.textMuted : iconColor,
            ),
            const SizedBox(width: MivaltaSpace.x4),
            Expanded(
              child: Text(
                title,
                style: MivaltaType.cardTitle.copyWith(
                  color: isMuted ? MivaltaColors.textMuted : MivaltaColors.textPrimary,
                ),
              ),
            ),
            if (status != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: MivaltaSpace.x3,
                  vertical: MivaltaSpace.x1,
                ),
                decoration: BoxDecoration(
                  color: status == 'Connected ✓'
                      ? MivaltaColors.stateProductive.withValues(alpha: 0.15)
                      : MivaltaColors.textMuted.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(MivaltaRadii.sm),
                ),
                child: Text(
                  status,
                  style: MivaltaType.small.copyWith(
                    color: status == 'Connected ✓'
                        ? MivaltaColors.stateProductive
                        : MivaltaColors.textMuted,
                  ),
                ),
              ),
            if (buttonText != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: MivaltaSpace.x4,
                  vertical: MivaltaSpace.x2,
                ),
                decoration: BoxDecoration(
                  color: MivaltaColors.stateProductive,
                  borderRadius: BorderRadius.circular(MivaltaRadii.sm),
                ),
                child: Text(
                  buttonText,
                  style: MivaltaType.body.copyWith(
                    color: MivaltaColors.surfaceBackground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

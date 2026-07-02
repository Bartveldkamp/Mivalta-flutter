// Onboarding Screen — 8-step intake flow (BS-002-onboarding v2).
//
// Sits between Auth and Today. Collects RAW answers, marshals to inputs_json,
// calls build_onboarding_profile → write_profile_to_vault → construct_engines_fresh.
// Engine DECIDES (goal_class, meso, anchor gating); Dart is pure transport.
//
// v2 (C4 fix): Engine contract requires specific fields — sport is SINGULAR,
// level/hours/years are required, sex is non-nullable (Female/Male only).
//
// Flow: Promise → Sport → Aim → Detail → Basics (age+sex) → Training (level+exp+hours)
//       → Anchors (conditional) → Gear → Payoff.

import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../rust_engine.dart';
import '../services/profile_service.dart';
import '../theme/tokens.dart';
import 'today_screen.dart';

/// The 8-step onboarding intake flow (v2 — engine contract aligned).
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  // Current step (0-indexed, 0-8 for 9 steps with training split)
  int _currentStep = 0;

  // Entrance animation
  late AnimationController _entranceController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // ─── Engine payload fields (v2 contract) ───
  String? _sport; // SINGULAR: 'cycling' | 'running' only (FL-17)
  String? _aim; // 'perform' | 'healthy' | 'both' → maps to goal_type
  String? _ageBand; // UI label → age int
  String? _sex; // 'female' | 'male' (non-nullable in engine)
  String? _level; // 'beginner' | 'novice' | 'intermediate' | 'advanced'
  String? _experience; // '<1' | '1-3' | '3-10' | '10+' → training_years int
  String? _weeklyHours; // '2-3' | '4-6' | '7-10' | '10+' → weekly_hours double
  double? _ftp; // null = "I don't know" (optional)
  double? _thresholdPace; // null = "I don't know" (optional)
  bool _ftpUnknown = false;
  bool _paceUnknown = false;

  // ─── App-side prefs (NOT sent to engine) ───
  String? _detail; // 'simple' | 'numbers' — stored locally
  final Set<String> _gear = {}; // stored locally

  // Loading state for final step
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
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

  /// Total steps: Promise(0) → Sport(1) → Aim(2) → Detail(3) → Basics(4) →
  /// Training(5) → Anchors(6, conditional) → Gear(7) → Payoff(8)
  int get _totalSteps => 9;

  /// Anchors step shows only if sport is cycling or running.
  bool get _showAnchors => _sport == 'cycling' || _sport == 'running';

  /// Check if current step's need() is satisfied.
  bool get _canContinue {
    switch (_currentStep) {
      case 0: // Promise — always enabled
        return true;
      case 1: // Sport — required (single choice)
        return _sport != null;
      case 2: // Aim — required
        return _aim != null;
      case 3: // Detail — required
        return _detail != null;
      case 4: // Basics (age + sex) — both required
        return _ageBand != null && _sex != null;
      case 5: // Training (level + experience + hours) — all required
        return _level != null && _experience != null && _weeklyHours != null;
      case 6: // Anchors — optional (always enabled)
        return true;
      case 7: // Gear — optional
        return true;
      case 8: // Payoff — always enabled
        return true;
      default:
        return false;
    }
  }

  /// Go to next step.
  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      int nextStep = _currentStep + 1;
      // Skip Anchors (step 6) if sport doesn't need it
      if (nextStep == 6 && !_showAnchors) {
        nextStep = 7;
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
      // Skip Anchors (step 6) if sport doesn't need it
      if (prevStep == 6 && !_showAnchors) {
        prevStep = 5;
      }
      setState(() => _currentStep = prevStep);
      _animateEntrance();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ENGINE PAYLOAD MAPPING (v2 contract)
  // ─────────────────────────────────────────────────────────────────────────

  /// Map age band label → representative int.
  int _ageBandToInt(String? band) => switch (band) {
        '18–29' => 25,
        '30–39' => 35,
        '40–49' => 45,
        '50–59' => 55,
        '60+' => 65,
        _ => 35, // fallback (shouldn't happen)
      };

  /// Map experience label → training_years int.
  int _experienceToYears(String? exp) => switch (exp) {
        '<1' => 0,
        '1-3' => 2,
        '3-10' => 6,
        '10+' => 12,
        _ => 2, // fallback
      };

  /// Map weekly hours label → weekly_hours double.
  double _hoursLabelToDouble(String? label) => switch (label) {
        '2-3' => 3.0,
        '4-6' => 5.0,
        '7-10' => 8.5,
        '10+' => 12.0,
        _ => 5.0, // fallback
      };

  /// Map aim → goal_type (engine vocabulary).
  /// Per v2: aim→goal_type via knowledge-card vocab.
  String _aimToGoalType(String? aim) => switch (aim) {
        'perform' => 'performance', // competitive goals
        'healthy' => 'general_fitness', // health/wellness
        'both' => 'balanced', // mixed
        _ => 'general_fitness', // fallback
      };

  /// Build inputs_json for engine (v2 contract).
  /// Required: athlete_id, age, sex, level, sport, goal_type, weekly_hours, training_years.
  /// Optional: threshold_hr, ftp_watts, threshold_pace_sec_km.
  Map<String, dynamic> _buildInputsJson() {
    final inputs = <String, dynamic>{
      'athlete_id': const Uuid().v4(),
      'age': _ageBandToInt(_ageBand),
      'sex': _sex, // 'male' | 'female' (non-nullable)
      'level': _level,
      'sport': _sport, // SINGULAR
      'goal_type': _aimToGoalType(_aim),
      'weekly_hours': _hoursLabelToDouble(_weeklyHours),
      'training_years': _experienceToYears(_experience),
    };

    // Optional anchors — null means "I don't know"
    if (_sport == 'cycling') {
      inputs['ftp_watts'] = _ftpUnknown ? null : _ftp?.toInt();
    }
    if (_sport == 'running') {
      // threshold_pace in min/km → sec/km
      final paceMinKm = _paceUnknown ? null : _thresholdPace;
      inputs['threshold_pace_sec_km'] = paceMinKm != null ? (paceMinKm * 60).toInt() : null;
    }

    return inputs;
  }

  /// Save app-side prefs (detail, gear) locally.
  Future<void> _saveLocalPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (_detail != null) {
      await prefs.setString('onboarding_detail', _detail!);
    }
    if (_gear.isNotEmpty) {
      await prefs.setStringList('onboarding_gear', _gear.toList());
    }
  }

  /// Submit onboarding — call engine, write profile, route to Today.
  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      // Save local prefs (detail, gear) — not sent to engine
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

      // 3. Save profile locally (for ProfileService.loadProfile)
      await ProfileService.saveProfile(profileJson);

      // 4. Construct engines fresh with new profile
      final tablesJson = await rootBundle.loadString('assets/compiled_tables.json');
      await binding.constructEnginesFresh(
        athleteProfileJson: profileJson,
        tablesJson: tablesJson,
        vaultPath: vaultPath,
      );

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
          final isAnchorsStep = index == 6;
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
      1 => _buildSportStep(), // v2: single sport
      2 => _buildAimStep(),
      3 => _buildDetailStep(),
      4 => _buildBasicsStep(), // age + sex
      5 => _buildTrainingStep(), // v2: level + experience + hours
      6 => _buildAnchorsStep(),
      7 => _buildGearStep(),
      8 => _buildPayoffStep(),
      _ => const SizedBox.shrink(),
    };
  }

  /// Bottom buttons — Continue + Back (from step 2).
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
          // Back button (ghost)
          if (showBack)
            GestureDetector(
              onTap: _prevStep,
              child: Container(
                height: 44,
                alignment: Alignment.center,
                child: Text(
                  'Back',
                  style: MivaltaType.body.copyWith(
                    color: MivaltaColors.textSecondary,
                  ),
                ),
              ),
            ),

          if (showBack) const SizedBox(height: MivaltaSpace.x2),

          // Continue button
          GestureDetector(
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
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STEP BUILDERS
  // ─────────────────────────────────────────────────────────────────────────

  /// Step 0: Promise (center layout).
  Widget _buildPromiseStep() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: MivaltaSpace.x4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Lock tile
            Container(
              width: MivaltaGlow.onbLockTileSize,
              height: MivaltaGlow.onbLockTileSize,
              decoration: BoxDecoration(
                color: MivaltaColors.stateProductive
                    .withValues(alpha: MivaltaGlow.onbLockTileAlpha),
                borderRadius: BorderRadius.circular(MivaltaGlow.onbLockTileRadius),
              ),
              child: const Icon(
                Icons.lock_outline,
                size: 32,
                color: MivaltaColors.stateProductive,
              ),
            ),

            const SizedBox(height: MivaltaSpace.x5),

            // Title
            Text(
              'Your body.\nYour data.',
              style: MivaltaType.titleXL.copyWith(color: MivaltaColors.textPrimary),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: MivaltaSpace.x4),

            // Sub
            Text(
              "Everything is computed on your phone. We can't see it — and we built it that way. Let's set MiValta up for you.",
              style: MivaltaType.body.copyWith(color: MivaltaColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Step 1: Sport (v2: SINGLE choice, Running/Cycling only).
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
          const SizedBox(height: MivaltaSpace.x6),

          Text(
            'Your main sport',
            style: MivaltaType.titleL.copyWith(color: MivaltaColors.textPrimary),
          ),

          const SizedBox(height: MivaltaSpace.x2),

          Text(
            "More sports are coming — pick the one MiValta should coach first.",
            style: MivaltaType.body.copyWith(color: MivaltaColors.textSecondary),
          ),

          const SizedBox(height: MivaltaSpace.x5),

          // Single-select option rows (not chips)
          ...sports.map((s) {
            final (id, icon, label) = s;
            final isSelected = _sport == id;
            return _buildSportRow(
              icon: icon,
              label: label,
              isSelected: isSelected,
              onTap: () => setState(() => _sport = id),
            );
          }),
        ],
      ),
    );
  }

  /// Step 2: Aim (single-option rows).
  Widget _buildAimStep() {
    const aims = [
      ('perform', 'Perform', 'Train to compete and hit personal bests'),
      ('healthy', 'Stay fit & healthy', 'Move regularly without overtraining'),
      ('both', 'A bit of both', 'Balance performance with sustainable fitness'),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: MivaltaSpace.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: MivaltaSpace.x6),

          Text(
            "What's your aim?",
            style: MivaltaType.titleL.copyWith(color: MivaltaColors.textPrimary),
          ),

          const SizedBox(height: MivaltaSpace.x5),

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
        ],
      ),
    );
  }

  /// Step 3: Detail (coaching density — app-side pref).
  Widget _buildDetailStep() {
    const options = [
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
            'How much detail?',
            style: MivaltaType.titleL.copyWith(color: MivaltaColors.textPrimary),
          ),

          const SizedBox(height: MivaltaSpace.x5),

          ...options.map((o) {
            final (id, title, desc) = o;
            final isSelected = _detail == id;
            return _buildOptionRow(
              title: title,
              description: desc,
              isSelected: isSelected,
              onTap: () => setState(() => _detail = id),
            );
          }),
        ],
      ),
    );
  }

  /// Step 4: Basics (age band + sex — v2: Female/Male only).
  Widget _buildBasicsStep() {
    const ageBands = ['18–29', '30–39', '40–49', '50–59', '60+'];
    // v2 (G9): Female/Male only — "Prefer not to say" not supported by engine
    const sexOptions = ['Female', 'Male'];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: MivaltaSpace.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: MivaltaSpace.x6),

          Text(
            'The engine needs two basics to read you correctly.',
            style: MivaltaType.titleL.copyWith(color: MivaltaColors.textPrimary),
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

          // Sex (v2: Female/Male only)
          Text(
            'Sex',
            style: MivaltaType.cardTitle.copyWith(color: MivaltaColors.textSecondary),
          ),

          const SizedBox(height: MivaltaSpace.x2),

          // v2 softening copy per spec
          Text(
            'Used only on-device, for heart-rate zones',
            style: MivaltaType.small.copyWith(color: MivaltaColors.textMuted),
          ),

          const SizedBox(height: MivaltaSpace.x3),

          Wrap(
            spacing: MivaltaSpace.x2,
            runSpacing: MivaltaSpace.x2,
            children: sexOptions.map((option) {
              final isSelected = _sex == option.toLowerCase();
              return _buildSmallChip(
                label: option,
                isSelected: isSelected,
                onTap: () => setState(() => _sex = option.toLowerCase()),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// Step 5: Training (v2: level + experience + weekly hours).
  Widget _buildTrainingStep() {
    const levels = [
      ('beginner', 'Beginner', 'Just getting started'),
      ('novice', 'Getting back', 'Returning after a break'),
      ('intermediate', 'Trained', 'Regular training for 1+ years'),
      ('advanced', 'Advanced', 'Structured training, racing'),
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
            'Your training background',
            style: MivaltaType.titleL.copyWith(color: MivaltaColors.textPrimary),
          ),

          const SizedBox(height: MivaltaSpace.x5),

          // Level
          Text(
            'Current level',
            style: MivaltaType.cardTitle.copyWith(color: MivaltaColors.textSecondary),
          ),

          const SizedBox(height: MivaltaSpace.x3),

          ...levels.map((l) {
            final (id, title, desc) = l;
            final isSelected = _level == id;
            return _buildCompactOptionRow(
              title: title,
              description: desc,
              isSelected: isSelected,
              onTap: () => setState(() => _level = id),
            );
          }),

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

          const SizedBox(height: MivaltaSpace.x4),
        ],
      ),
    );
  }

  /// Step 6: Anchors (conditional — FTP/threshold pace).
  Widget _buildAnchorsStep() {
    final showFtp = _sport == 'cycling';
    final showPace = _sport == 'running';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: MivaltaSpace.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: MivaltaSpace.x6),

          Text(
            'If you know it',
            style: MivaltaType.titleL.copyWith(color: MivaltaColors.textPrimary),
          ),

          const SizedBox(height: MivaltaSpace.x2),

          Text(
            "No idea? Perfect — most people don't. MiValta learns it from your sessions.",
            style: MivaltaType.body.copyWith(color: MivaltaColors.textSecondary),
          ),

          const SizedBox(height: MivaltaSpace.x5),

          // FTP (cycling)
          if (showFtp) ...[
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
            const SizedBox(height: MivaltaSpace.x4),
          ],

          // Threshold pace (running)
          if (showPace) ...[
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
        ],
      ),
    );
  }

  /// Step 7: Gear (multi-chip, optional — app-side pref).
  Widget _buildGearStep() {
    const gearOptions = [
      ('watch', Icons.watch, 'Watch'),
      ('ring', Icons.circle_outlined, 'Ring'),
      ('strap', Icons.monitor_heart, 'HR strap'),
      ('none', Icons.not_interested, 'None yet'),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: MivaltaSpace.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: MivaltaSpace.x6),

          Text(
            'What do you wear?',
            style: MivaltaType.titleL.copyWith(color: MivaltaColors.textPrimary),
          ),

          const SizedBox(height: MivaltaSpace.x2),

          Text(
            'This helps us understand your data sources.',
            style: MivaltaType.body.copyWith(color: MivaltaColors.textSecondary),
          ),

          const SizedBox(height: MivaltaSpace.x5),

          Wrap(
            spacing: MivaltaSpace.x3,
            runSpacing: MivaltaSpace.x3,
            children: gearOptions.map((g) {
              final (id, icon, label) = g;
              final isSelected = _gear.contains(id);
              return _buildChip(
                icon: icon,
                label: label,
                isSelected: isSelected,
                onTap: () {
                  setState(() {
                    if (id == 'none') {
                      // "None yet" exclusive-toggles others
                      if (isSelected) {
                        _gear.remove('none');
                      } else {
                        _gear.clear();
                        _gear.add('none');
                      }
                    } else {
                      _gear.remove('none'); // Clear "none" if selecting gear
                      if (isSelected) {
                        _gear.remove(id);
                      } else {
                        _gear.add(id);
                      }
                    }
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// Step 8: Payoff (confirmation).
  /// C2 (DR-017): day-zero (fresh engine, zero observations) has no readiness
  /// number — always show words variant with "Learning you" line.
  Widget _buildPayoffStep() {
    // C2: At onboarding, always words — no number yet
    const showNumbers = false;

    // Aim-based line
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
            // Mini glow — always words at day-zero
            _buildPayoffGlow(showNumbers: showNumbers),

            const SizedBox(height: MivaltaSpace.x5),

            // Aim line
            Text(
              aimLine,
              style: MivaltaType.titleM.copyWith(color: MivaltaColors.textPrimary),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: MivaltaSpace.x4),

            // C2: "Learning you" sub-line (day-zero honest absence)
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

  /// Payoff mini glow (150px, teal) with "Good to go".
  Widget _buildPayoffGlow({required bool showNumbers}) {
    const glowSize = MivaltaGlow.onbPayoffGlowSize;
    const color = MivaltaColors.stateProductive;

    return SizedBox(
      width: glowSize,
      height: glowSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer halo
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
          // Mid halo
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
          // Content — always words at day-zero
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

  /// Sport row (single-select with icon).
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

  /// Chip with icon (gear).
  Widget _buildChip({
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
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected
                    ? MivaltaColors.stateProductive
                    : MivaltaColors.textSecondary,
              ),
              const SizedBox(width: MivaltaSpace.x2),
              Text(
                label,
                style: MivaltaType.body.copyWith(
                  color: isSelected
                      ? MivaltaColors.stateProductive
                      : MivaltaColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Small chip (age, sex, experience, hours).
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

  /// Option row (aim, detail).
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

  /// Compact option row (level — smaller for more items).
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
                child: Row(
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
                    const SizedBox(width: MivaltaSpace.x2),
                    Text(
                      '· $description',
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

  /// Anchor input (FTP, threshold pace) with "I don't know" chip.
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
            // Numeric input
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

            // "I don't know" chip
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
}

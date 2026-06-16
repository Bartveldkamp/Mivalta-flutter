// PR-F: Onboarding wizard screen.
//
// Collects the user's athlete profile on first launch. Maps to the
// AthleteProfile schema expected by gatc-ffi's construct_engines_fresh().
//
// ZERO-FABRICATION: If the user doesn't know their FTP/threshold, we persist
// null — not a fabricated number. "I don't know" is a real, honest choice.
// The engine already handles absent anchors (falls back to HR/RPE).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/profile_service.dart';
import '../theme/tokens.dart';

/// Result of the onboarding flow.
///
/// FL-16: carries the RAW onboarding inputs (not a built profile). The engine
/// completes them into a full AthleteProfile downstream — the client computes
/// nothing.
class OnboardingResult {
  const OnboardingResult({required this.inputsJson});
  final String inputsJson;
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  final _builder = ProfileBuilder();
  int _currentPage = 0;

  // Form controllers
  final _ageController = TextEditingController();
  final _weeklyHoursController = TextEditingController();
  final _thresholdHrController = TextEditingController();
  final _ftpController = TextEditingController();
  final _paceMinController = TextEditingController();
  final _paceSecController = TextEditingController();

  // Form state
  String? _sex;
  Level? _level;
  Sport? _sport;
  GoalType? _goalType;
  bool _knowsThresholdHr = true;
  bool _knowsFtp = true;
  bool _knowsPace = true;

  static const _totalPages = 7;

  @override
  void initState() {
    super.initState();
    // _canProceed() (the Continue button) and the volume page's preset chips
    // read these controllers' .text during build. A TextEditingController
    // mutation — whether typed OR set programmatically by a preset chip — does
    // NOT trigger a rebuild on its own. On a page whose only input is a text
    // field (the volume page has no sibling control to incidentally rebuild),
    // that left the preset chip un-greened and Continue permanently disabled.
    // Rebuild on every change so both re-evaluate. (The age page worked only
    // incidentally — picking sex fired setState; this removes that fragility.)
    _ageController.addListener(_onFormFieldChanged);
    _weeklyHoursController.addListener(_onFormFieldChanged);
  }

  void _onFormFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _pageController.dispose();
    _ageController.dispose();
    _weeklyHoursController.dispose();
    _thresholdHrController.dispose();
    _ftpController.dispose();
    _paceMinController.dispose();
    _paceSecController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  bool _canProceed() {
    switch (_currentPage) {
      case 0: // Basic info
        return _ageController.text.isNotEmpty && _sex != null;
      case 1: // Sport
        return _sport != null;
      case 2: // Experience
        return _level != null &&
            (int.tryParse(_ageController.text) ?? 0) -
                    (_builder.trainingYears ?? 0) >=
                0;
      case 3: // Goal
        return _goalType != null;
      case 4: // Training volume
        return _weeklyHoursController.text.isNotEmpty;
      case 5: // Anchors
        return true; // All anchor fields are optional ("I don't know" is valid)
      case 6: // Privacy moment (A1) — informational, nothing to fill in
        return true;
      default:
        return false;
    }
  }

  void _finish() {
    // Build the profile from collected data
    _builder.age = int.tryParse(_ageController.text);
    _builder.sex = _sex;
    _builder.level = _level?.value;
    _builder.sport = _sport?.value;
    _builder.goalType = _goalType?.value;
    _builder.weeklyHours = double.tryParse(_weeklyHoursController.text);

    // Threshold HR — null if unknown
    if (_knowsThresholdHr && _thresholdHrController.text.isNotEmpty) {
      _builder.thresholdHr = int.tryParse(_thresholdHrController.text);
    } else {
      _builder.thresholdHr = null;
    }

    // Sport-specific anchors — null if unknown (ZERO-FABRICATION)
    if (_sport == Sport.cycling) {
      if (_knowsFtp && _ftpController.text.isNotEmpty) {
        _builder.ftpWatts = int.tryParse(_ftpController.text);
      } else {
        _builder.ftpWatts = null;
      }
    }

    if (_sport == Sport.running) {
      if (_knowsPace &&
          _paceMinController.text.isNotEmpty &&
          _paceSecController.text.isNotEmpty) {
        final min = int.tryParse(_paceMinController.text) ?? 0;
        final sec = int.tryParse(_paceSecController.text) ?? 0;
        _builder.thresholdPaceSecKm = min * 60 + sec;
      } else {
        _builder.thresholdPaceSecKm = null;
      }
    }

    if (!_builder.isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    final inputsJson = _builder.buildInputs();
    Navigator.of(context).pop(OnboardingResult(inputsJson: inputsJson));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MivaltaColors.surfaceBackground,
      appBar: AppBar(
        backgroundColor: MivaltaColors.surfaceBackground,
        foregroundColor: MivaltaColors.textPrimary,
        title: const Text('Setup'),
        leading: _currentPage > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _previousPage,
              )
            : null,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // Progress indicator
          LinearProgressIndicator(
            value: (_currentPage + 1) / _totalPages,
            backgroundColor: MivaltaColors.surface1,
            color: MivaltaColors.primaryGreen,
          ),
          // Page content
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (page) => setState(() => _currentPage = page),
              children: [
                _BasicInfoPage(
                  ageController: _ageController,
                  sex: _sex,
                  onSexChanged: (v) => setState(() => _sex = v),
                ),
                _SportPage(
                  sport: _sport,
                  onSportChanged: (v) => setState(() => _sport = v),
                ),
                _ExperiencePage(
                  level: _level,
                  onLevelChanged: (v) => setState(() => _level = v),
                  trainingYears: _builder.trainingYears,
                  onTrainingYearsChanged: (v) =>
                      setState(() => _builder.trainingYears = v),
                ),
                _GoalPage(
                  goalType: _goalType,
                  onGoalChanged: (v) => setState(() => _goalType = v),
                ),
                _VolumePage(
                  weeklyHoursController: _weeklyHoursController,
                ),
                _AnchorsPage(
                  sport: _sport,
                  knowsThresholdHr: _knowsThresholdHr,
                  onKnowsThresholdHrChanged: (v) =>
                      setState(() => _knowsThresholdHr = v),
                  thresholdHrController: _thresholdHrController,
                  knowsFtp: _knowsFtp,
                  onKnowsFtpChanged: (v) => setState(() => _knowsFtp = v),
                  ftpController: _ftpController,
                  knowsPace: _knowsPace,
                  onKnowsPaceChanged: (v) => setState(() => _knowsPace = v),
                  paceMinController: _paceMinController,
                  paceSecController: _paceSecController,
                ),
                const PrivacyMomentPage(),
              ],
            ),
          ),
          // Navigation buttons
          Padding(
            padding: const EdgeInsets.all(MivaltaSpace.x4),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _canProceed()
                    ? (_currentPage == _totalPages - 1 ? _finish : _nextPage)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: MivaltaColors.primaryGreen,
                  foregroundColor: MivaltaColors.textPrimary,
                  padding: const EdgeInsets.symmetric(vertical: MivaltaSpace.x4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(MivaltaRadii.md),
                  ),
                ),
                child: Text(
                  _currentPage == _totalPages - 1 ? 'Get Started' : 'Continue',
                  style: const TextStyle(
                    fontSize: 16,
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
}

// =============================================================================
// PAGE 1: Basic Info (Age, Sex)
// =============================================================================

class _BasicInfoPage extends StatelessWidget {
  const _BasicInfoPage({
    required this.ageController,
    required this.sex,
    required this.onSexChanged,
  });

  final TextEditingController ageController;
  final String? sex;
  final ValueChanged<String?> onSexChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(MivaltaSpace.x5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Let's get to know you",
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: MivaltaColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: MivaltaSpace.x2),
          Text(
            'This helps us personalize your training.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: MivaltaColors.textMuted,
                ),
          ),
          const SizedBox(height: MivaltaSpace.x6),

          // Age
          Text(
            'Age',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: MivaltaColors.textSecondary,
                ),
          ),
          const SizedBox(height: MivaltaSpace.x2),
          TextField(
            controller: ageController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(color: MivaltaColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Your age',
              hintStyle: const TextStyle(color: MivaltaColors.textMuted),
              filled: true,
              fillColor: MivaltaColors.surface1,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(MivaltaRadii.md),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: MivaltaSpace.x5),

          // Sex
          Text(
            'Sex',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: MivaltaColors.textSecondary,
                ),
          ),
          const SizedBox(height: MivaltaSpace.x2),
          Row(
            children: [
              Expanded(
                child: _SelectionChip(
                  label: 'Male',
                  selected: sex == 'male',
                  onTap: () => onSexChanged('male'),
                ),
              ),
              const SizedBox(width: MivaltaSpace.x3),
              Expanded(
                child: _SelectionChip(
                  label: 'Female',
                  selected: sex == 'female',
                  onTap: () => onSexChanged('female'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// PAGE 2: Sport Selection
// =============================================================================

class _SportPage extends StatelessWidget {
  const _SportPage({
    required this.sport,
    required this.onSportChanged,
  });

  final Sport? sport;
  final ValueChanged<Sport?> onSportChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(MivaltaSpace.x5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What do you train?',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: MivaltaColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: MivaltaSpace.x2),
          Text(
            'Choose your primary activity.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: MivaltaColors.textMuted,
                ),
          ),
          const SizedBox(height: MivaltaSpace.x6),
          ...Sport.values.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: MivaltaSpace.x3),
              child: _SelectionCard(
                title: s.label,
                selected: sport == s,
                onTap: () => onSportChanged(s),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// PAGE 3: Experience Level
// =============================================================================

class _ExperiencePage extends StatelessWidget {
  const _ExperiencePage({
    required this.level,
    required this.onLevelChanged,
    required this.trainingYears,
    required this.onTrainingYearsChanged,
  });

  final Level? level;
  final ValueChanged<Level?> onLevelChanged;
  final int? trainingYears;
  final ValueChanged<int?> onTrainingYearsChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(MivaltaSpace.x5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your experience',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: MivaltaColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: MivaltaSpace.x2),
          Text(
            'How long have you been training consistently?',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: MivaltaColors.textMuted,
                ),
          ),
          const SizedBox(height: MivaltaSpace.x6),
          ...Level.values.map(
            (l) => Padding(
              padding: const EdgeInsets.only(bottom: MivaltaSpace.x3),
              child: _SelectionCard(
                title: l.label,
                subtitle: l.description,
                selected: level == l,
                onTap: () {
                  onLevelChanged(l);
                  // Auto-set training years based on level
                  switch (l) {
                    case Level.beginner:
                      onTrainingYearsChanged(0);
                    case Level.intermediate:
                      onTrainingYearsChanged(2);
                    case Level.advanced:
                      onTrainingYearsChanged(5);
                    case Level.elite:
                      onTrainingYearsChanged(10);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// PAGE 4: Goal Selection
// =============================================================================

class _GoalPage extends StatelessWidget {
  const _GoalPage({
    required this.goalType,
    required this.onGoalChanged,
  });

  final GoalType? goalType;
  final ValueChanged<GoalType?> onGoalChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(MivaltaSpace.x5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "What's your goal?",
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: MivaltaColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: MivaltaSpace.x2),
          Text(
            "We'll tailor your training to match.",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: MivaltaColors.textMuted,
                ),
          ),
          const SizedBox(height: MivaltaSpace.x6),
          ...GoalType.values.map(
            (g) => Padding(
              padding: const EdgeInsets.only(bottom: MivaltaSpace.x3),
              child: _SelectionCard(
                title: g.label,
                subtitle: g.description,
                selected: goalType == g,
                onTap: () => onGoalChanged(g),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// PAGE 5: Training Volume
// =============================================================================

class _VolumePage extends StatelessWidget {
  const _VolumePage({
    required this.weeklyHoursController,
  });

  final TextEditingController weeklyHoursController;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(MivaltaSpace.x5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How much do you train?',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: MivaltaColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: MivaltaSpace.x2),
          Text(
            'Average hours per week.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: MivaltaColors.textMuted,
                ),
          ),
          const SizedBox(height: MivaltaSpace.x6),

          Text(
            'Weekly training hours',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: MivaltaColors.textSecondary,
                ),
          ),
          const SizedBox(height: MivaltaSpace.x2),
          TextField(
            controller: weeklyHoursController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            style: const TextStyle(color: MivaltaColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'e.g., 6',
              hintStyle: const TextStyle(color: MivaltaColors.textMuted),
              suffixText: 'hours/week',
              suffixStyle: const TextStyle(color: MivaltaColors.textMuted),
              filled: true,
              fillColor: MivaltaColors.surface1,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(MivaltaRadii.md),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: MivaltaSpace.x4),

          // Quick selection chips
          Wrap(
            spacing: MivaltaSpace.x2,
            children: [3, 5, 7, 10].map((h) {
              final isSelected = weeklyHoursController.text == h.toString();
              return ActionChip(
                label: Text('$h hrs'),
                labelStyle: TextStyle(
                  color: isSelected
                      ? MivaltaColors.textPrimary
                      : MivaltaColors.textSecondary,
                ),
                backgroundColor:
                    isSelected ? MivaltaColors.primaryGreen : MivaltaColors.surface1,
                side: BorderSide.none,
                onPressed: () => weeklyHoursController.text = h.toString(),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// PAGE 6: Anchors (Threshold HR, FTP, Pace)
// =============================================================================

class _AnchorsPage extends StatelessWidget {
  const _AnchorsPage({
    required this.sport,
    required this.knowsThresholdHr,
    required this.onKnowsThresholdHrChanged,
    required this.thresholdHrController,
    required this.knowsFtp,
    required this.onKnowsFtpChanged,
    required this.ftpController,
    required this.knowsPace,
    required this.onKnowsPaceChanged,
    required this.paceMinController,
    required this.paceSecController,
  });

  final Sport? sport;
  final bool knowsThresholdHr;
  final ValueChanged<bool> onKnowsThresholdHrChanged;
  final TextEditingController thresholdHrController;
  final bool knowsFtp;
  final ValueChanged<bool> onKnowsFtpChanged;
  final TextEditingController ftpController;
  final bool knowsPace;
  final ValueChanged<bool> onKnowsPaceChanged;
  final TextEditingController paceMinController;
  final TextEditingController paceSecController;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(MivaltaSpace.x5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your training zones',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: MivaltaColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: MivaltaSpace.x2),
          Text(
            "These help us set accurate targets. It's okay if you don't know — we'll use heart rate and perceived effort instead.",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: MivaltaColors.textMuted,
                ),
          ),
          const SizedBox(height: MivaltaSpace.x6),

          // Threshold HR (all sports)
          _AnchorField(
            label: 'Threshold Heart Rate',
            hint: 'e.g., 165',
            suffix: 'bpm',
            controller: thresholdHrController,
            knows: knowsThresholdHr,
            onKnowsChanged: onKnowsThresholdHrChanged,
          ),

          // FTP (cycling only)
          if (sport == Sport.cycling) ...[
            const SizedBox(height: MivaltaSpace.x5),
            _AnchorField(
              label: 'Functional Threshold Power (FTP)',
              hint: 'e.g., 250',
              suffix: 'watts',
              controller: ftpController,
              knows: knowsFtp,
              onKnowsChanged: onKnowsFtpChanged,
            ),
          ],

          // Threshold Pace (running only)
          if (sport == Sport.running) ...[
            const SizedBox(height: MivaltaSpace.x5),
            Text(
              'Threshold Pace',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: MivaltaColors.textSecondary,
                  ),
            ),
            const SizedBox(height: MivaltaSpace.x2),
            if (knowsPace)
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: paceMinController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(color: MivaltaColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'min',
                        hintStyle: const TextStyle(color: MivaltaColors.textMuted),
                        filled: true,
                        fillColor: MivaltaColors.surface1,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(MivaltaRadii.md),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: MivaltaSpace.x2),
                    child: Text(
                      ':',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: MivaltaColors.textSecondary,
                          ),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: paceSecController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: const TextStyle(color: MivaltaColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'sec',
                        hintStyle: const TextStyle(color: MivaltaColors.textMuted),
                        suffixText: '/km',
                        suffixStyle: const TextStyle(color: MivaltaColors.textMuted),
                        filled: true,
                        fillColor: MivaltaColors.surface1,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(MivaltaRadii.md),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: MivaltaSpace.x2),
            _DontKnowCheckbox(
              value: !knowsPace,
              onChanged: (v) => onKnowsPaceChanged(!v),
            ),
          ],
        ],
      ),
    );
  }
}

class _AnchorField extends StatelessWidget {
  const _AnchorField({
    required this.label,
    required this.hint,
    required this.suffix,
    required this.controller,
    required this.knows,
    required this.onKnowsChanged,
  });

  final String label;
  final String hint;
  final String suffix;
  final TextEditingController controller;
  final bool knows;
  final ValueChanged<bool> onKnowsChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: MivaltaColors.textSecondary,
              ),
        ),
        const SizedBox(height: MivaltaSpace.x2),
        if (knows)
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(color: MivaltaColors.textPrimary),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: MivaltaColors.textMuted),
              suffixText: suffix,
              suffixStyle: const TextStyle(color: MivaltaColors.textMuted),
              filled: true,
              fillColor: MivaltaColors.surface1,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(MivaltaRadii.md),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        const SizedBox(height: MivaltaSpace.x2),
        _DontKnowCheckbox(
          value: !knows,
          onChanged: (v) => onKnowsChanged(!v),
        ),
      ],
    );
  }
}

class _DontKnowCheckbox extends StatelessWidget {
  const _DontKnowCheckbox({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(MivaltaRadii.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: MivaltaSpace.x1),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: value,
                onChanged: (v) => onChanged(v ?? false),
                activeColor: MivaltaColors.primaryGreen,
                side: const BorderSide(color: MivaltaColors.textMuted),
              ),
            ),
            const SizedBox(width: MivaltaSpace.x2),
            Text(
              "I don't know",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: MivaltaColors.textMuted,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// PAGE 7: Privacy moment (NEXT_UPDATE_V2_ADOPTIONS A1)
// =============================================================================

/// The airplane-mode privacy moment — onboarding's final step.
///
/// Engines don't exist yet during onboarding (they're constructed after this
/// flow returns), so the "live compute as proof" IS the next screen: tapping
/// Get Started boots the engine and computes readiness fully on-device — with
/// airplane mode still on if the user enabled it.
///
/// ⚠ FOUNDER REVIEW: copy below is a draft per the A1 brief; goes through
/// founder review before lock.
///
/// PUBLIC so the privacy copy is pinned by widget test (same precedent as
/// AdvisorOptionsList); production call site is this screen's PageView.
class PrivacyMomentPage extends StatelessWidget {
  const PrivacyMomentPage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(MivaltaSpace.x5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: MivaltaSpace.x6),
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: MivaltaColors.surface1,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.airplanemode_active,
                size: 36,
                color: MivaltaColors.primaryGreen,
              ),
            ),
          ),
          const SizedBox(height: MivaltaSpace.x6),
          Text(
            'Turn on airplane mode.',
            style: textTheme.headlineSmall?.copyWith(
              color: MivaltaColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: MivaltaSpace.x3),
          Text(
            'Watch: the engine still works. '
            'Your data never leaves this phone.',
            style: textTheme.bodyLarge?.copyWith(
              color: MivaltaColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: MivaltaSpace.x5),
          Container(
            padding: const EdgeInsets.all(MivaltaSpace.x4),
            decoration: BoxDecoration(
              color: MivaltaColors.surface1,
              borderRadius: BorderRadius.circular(MivaltaRadii.md),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.lock_outline,
                  size: 20,
                  color: MivaltaColors.primaryGreen,
                ),
                const SizedBox(width: MivaltaSpace.x3),
                Expanded(
                  child: Text(
                    'Tap Get Started and your readiness is computed right '
                    'here, on this phone. No cloud. No account. '
                    'Nothing leaves.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: MivaltaColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SHARED WIDGETS
// =============================================================================

class _SelectionChip extends StatelessWidget {
  const _SelectionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(MivaltaRadii.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: MivaltaSpace.x4,
          vertical: MivaltaSpace.x3,
        ),
        decoration: BoxDecoration(
          color: selected ? MivaltaColors.primaryGreen : MivaltaColors.surface1,
          borderRadius: BorderRadius.circular(MivaltaRadii.md),
          border: Border.all(
            color: selected
                ? MivaltaColors.primaryGreen
                : MivaltaColors.surface2,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? MivaltaColors.textPrimary
                  : MivaltaColors.textSecondary,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectionCard extends StatelessWidget {
  const _SelectionCard({
    required this.title,
    this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(MivaltaRadii.md),
      child: Container(
        padding: const EdgeInsets.all(MivaltaSpace.x4),
        decoration: BoxDecoration(
          color: selected ? MivaltaColors.primaryGreen : MivaltaColors.surface1,
          borderRadius: BorderRadius.circular(MivaltaRadii.md),
          border: Border.all(
            color: selected
                ? MivaltaColors.primaryGreen
                : MivaltaColors.surface2,
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
                    style: TextStyle(
                      color: selected
                          ? MivaltaColors.textPrimary
                          : MivaltaColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: MivaltaSpace.x1),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: selected
                            ? MivaltaColors.textPrimary.withValues(alpha: 0.8)
                            : MivaltaColors.textMuted,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle,
                color: MivaltaColors.textPrimary,
              ),
          ],
        ),
      ),
    );
  }
}

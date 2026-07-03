// Advisor Screen — BS-003: The session offer (A/B/C options).
//
// Phase 2.2 — the core loop's second screen. Presents bounded workout options
// from `recommend_workout` FFI. Quick-adjust chips re-resolve (mood/equipment/
// terrain), option cards show zone (energy name first), detail state renders
// full structure, "This one today" persists choice locally.
//
// SCOPE BOUNDARY: the OFFER only. No live recording, no session player.
// Engine DECIDES, Flutter DISPLAYS.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/workout_option.dart';
import '../rust_engine.dart';
import '../services/profile_service.dart';
import '../theme/tokens.dart';
import '../theme/zone_names.dart';

/// Advisor screen showing workout options A/B/C with quick-adjust chips.
class AdvisorScreen extends StatefulWidget {
  const AdvisorScreen({
    super.key,
    required this.options,
    required this.binding,
    required this.handle,
    this.safetyAdvisories = const [],
  });

  /// Initial options from Today's recommend_workout call.
  final List<WorkoutOption> options;

  /// Engine binding for re-resolve calls.
  final RustEngineBinding binding;

  /// Engine handle for recommend_workout calls.
  final EnginesHandle handle;

  /// Safety advisories from realized line (degraded state). Rendered above
  /// options in stateAccumulated when non-empty.
  final List<String> safetyAdvisories;

  @override
  State<AdvisorScreen> createState() => _AdvisorScreenState();
}

class _AdvisorScreenState extends State<AdvisorScreen> {
  late List<WorkoutOption> _options;
  bool _loading = false;
  String? _error;

  // Quick-adjust chip selections (null = not selected)
  String? _selectedMood;
  String? _selectedEquipment;
  String? _selectedTerrain;

  // Selected option for detail view (null = list view)
  WorkoutOption? _selectedOption;

  // Profile sport for equipment value mapping
  String? _sport;

  // Today's date key for persisted choice
  String get _todayKey =>
      'chosen_option_${DateTime.now().toIso8601String().substring(0, 10)}';

  // Previously chosen option ID for today
  String? _chosenOptionId;

  /// Equipment display values — UI labels shown to user.
  List<String> get _equipmentValues => const ['outdoor', 'indoor'];

  /// Map UI equipment selection to engine-legal value.
  /// Engine matches: contains("outdoor"), contains("trainer"), contains("treadmill").
  /// "indoor" silently no-ops, so we send sport-specific values.
  String? get _equipmentValueForEngine {
    if (_selectedEquipment == null) return null;
    if (_selectedEquipment == 'outdoor') return 'outdoor';
    // "indoor" → trainer (cycling) or treadmill (running)
    if (_selectedEquipment == 'indoor') {
      return _sport == 'running' ? 'treadmill' : 'trainer';
    }
    return _selectedEquipment;
  }

  @override
  void initState() {
    super.initState();
    _options = widget.options;
    _loadChosenOption();
    _loadSport();
  }

  Future<void> _loadSport() async {
    final profileJson = await ProfileService.loadProfile();
    if (profileJson != null && mounted) {
      try {
        final decoded = jsonDecode(profileJson);
        if (decoded is Map && decoded['sport'] != null) {
          setState(() => _sport = decoded['sport'].toString());
        }
      } catch (_) {
        // Profile parse error — default to cycling
      }
    }
  }

  Future<void> _loadChosenOption() async {
    final prefs = await SharedPreferences.getInstance();
    final chosen = prefs.getString(_todayKey);
    if (chosen != null && mounted) {
      setState(() => _chosenOptionId = chosen);
    }
  }

  /// Re-resolve options with current chip selections.
  Future<void> _reResolve() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Use the passed binding and handle for re-resolve
      // Note: equipment uses mapped value (indoor → trainer/treadmill per sport)
      final workoutJson = await widget.binding.recommendWorkout(
        widget.handle,
        mood: _selectedMood,
        equipment: _equipmentValueForEngine,
        terrain: _selectedTerrain,
      );
      final decoded = jsonDecode(workoutJson);
      if (decoded is List) {
        final options = decoded.map((e) => WorkoutOption.fromJson(e)).toList();
        if (mounted) {
          setState(() {
            _options = options;
            _loading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Couldn\'t re-plan — try again';
          _loading = false;
        });
      }
    }
  }

  /// Persist chosen option and return to Today.
  Future<void> _chooseOption(WorkoutOption option) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_todayKey, option.optionId);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MivaltaColors.surfaceBackground,
      appBar: AppBar(
        backgroundColor: MivaltaColors.surfaceBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: MivaltaColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Today\'s options',
          style: MivaltaType.titleM.copyWith(color: MivaltaColors.textPrimary),
        ),
        centerTitle: false,
      ),
      body: _selectedOption != null
          ? _buildDetailView(_selectedOption!)
          : _buildListView(),
    );
  }

  /// List view: chip row + option cards.
  Widget _buildListView() {
    return Column(
      children: [
        // Quick-adjust chip row
        _buildChipRow(),
        const SizedBox(height: MivaltaSpace.x4),
        // Safety advisories (degraded state)
        if (widget.safetyAdvisories.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: MivaltaSpace.x4),
            child: _buildSafetyAdvisories(),
          ),
        // Options list
        Expanded(
          child: _options.isEmpty
              ? _buildHonestAbsent()
              : _buildOptionsList(),
        ),
      ],
    );
  }

  /// Safety advisories from realized line — steady, not alarm.
  Widget _buildSafetyAdvisories() {
    return Container(
      margin: const EdgeInsets.only(bottom: MivaltaSpace.x3),
      padding: const EdgeInsets.all(MivaltaSpace.x3),
      decoration: BoxDecoration(
        color: MivaltaColors.stateAccumulated.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: MivaltaColors.stateAccumulated.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widget.safetyAdvisories
            .map((advisory) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: MivaltaColors.stateAccumulated,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          advisory,
                          style: MivaltaType.small.copyWith(
                            color: MivaltaColors.stateAccumulated,
                          ),
                        ),
                      ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  /// Quick-adjust chip row for mood/equipment/terrain.
  Widget _buildChipRow() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MivaltaSpace.x4,
        vertical: MivaltaSpace.x2,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Mood chips — engine legal values: fun/easy/hard/mix
            // (NOT fresh/normal/tired — those panic the engine)
            _ChipGroup(
              label: 'In the mood for',
              values: const ['fun', 'easy', 'hard', 'mix'],
              selected: _selectedMood,
              onSelected: (v) {
                setState(() => _selectedMood = v);
                _reResolve();
              },
            ),
            const SizedBox(width: MivaltaSpace.x3),
            // Equipment chips — display label vs. sent value differ
            // Engine matches: contains("outdoor"), contains("trainer"),
            // contains("treadmill"). "indoor" silently no-ops.
            _ChipGroup(
              label: 'Equipment',
              values: _equipmentValues,
              selected: _selectedEquipment,
              onSelected: (v) {
                setState(() => _selectedEquipment = v);
                _reResolve();
              },
            ),
            const SizedBox(width: MivaltaSpace.x3),
            // Terrain chips — flat/hilly/trail are all engine-real
            _ChipGroup(
              label: 'Terrain',
              values: const ['flat', 'hilly', 'trail'],
              selected: _selectedTerrain,
              onSelected: (v) {
                setState(() => _selectedTerrain = v);
                _reResolve();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Options list with cards.
  Widget _buildOptionsList() {
    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: MivaltaSpace.x4),
          itemCount: _options.length + 1, // +1 for footer
          itemBuilder: (context, index) {
            if (index == _options.length) {
              // Footer line for easiest option
              return Padding(
                padding: const EdgeInsets.only(
                  top: MivaltaSpace.x4,
                  bottom: MivaltaSpace.x6,
                ),
                child: Text(
                  '...or take it easy — that\'s a real option too.',
                  style: MivaltaType.small.copyWith(
                    color: MivaltaColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              );
            }
            final option = _options[index];
            final isRecommended = index == 0;
            final isChosen = option.optionId == _chosenOptionId;
            return Padding(
              padding: const EdgeInsets.only(bottom: MivaltaSpace.x3),
              child: _OptionCard(
                option: option,
                isRecommended: isRecommended,
                isChosen: isChosen,
                onTap: () => setState(() => _selectedOption = option),
              ),
            );
          },
        ),
        // Loading overlay
        if (_loading)
          Positioned.fill(
            child: Container(
              color: MivaltaColors.surfaceBackground.withValues(alpha: 0.6),
              child: const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: MivaltaColors.stateProductive,
                  ),
                ),
              ),
            ),
          ),
        // Error card
        if (_error != null)
          Positioned(
            left: MivaltaSpace.x4,
            right: MivaltaSpace.x4,
            top: MivaltaSpace.x2,
            child: Container(
              padding: const EdgeInsets.all(MivaltaSpace.x3),
              decoration: BoxDecoration(
                color: MivaltaColors.stateAccumulated.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: MivaltaColors.stateAccumulated.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                _error!,
                style: MivaltaType.small.copyWith(
                  color: MivaltaColors.stateAccumulated,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Honest-absent state when no options available.
  Widget _buildHonestAbsent() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MivaltaSpace.x6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.fitness_center,
              size: 48,
              color: MivaltaColors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: MivaltaSpace.x4),
            Text(
              'Nothing to suggest yet',
              style: MivaltaType.titleM.copyWith(
                color: MivaltaColors.textPrimary,
              ),
            ),
            const SizedBox(height: MivaltaSpace.x2),
            Text(
              'MiValta suggests sessions once it\'s read a few of your days.',
              style: MivaltaType.body.copyWith(
                color: MivaltaColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Detail view for a selected option.
  Widget _buildDetailView(WorkoutOption option) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(MivaltaSpace.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back to list
          TextButton.icon(
            onPressed: () => setState(() => _selectedOption = null),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('All options'),
            style: TextButton.styleFrom(
              foregroundColor: MivaltaColors.textSecondary,
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: MivaltaSpace.x4),
          // Zone chip
          _ZoneChip(zone: option.zone),
          const SizedBox(height: MivaltaSpace.x3),
          // Title + expression badge
          Row(
            children: [
              Expanded(
                child: Text(
                  option.title,
                  style: MivaltaType.titleL.copyWith(
                    color: MivaltaColors.textPrimary,
                  ),
                ),
              ),
              if (option.expression != null)
                Container(
                  margin: const EdgeInsets.only(left: MivaltaSpace.x2),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: MivaltaColors.textSecondary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    option.expression!,
                    style: MivaltaType.small.copyWith(
                      color: MivaltaColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: MivaltaSpace.x2),
          // Why
          Text(
            option.why,
            style: MivaltaType.body.copyWith(
              color: MivaltaColors.textSecondary,
            ),
          ),
          const SizedBox(height: MivaltaSpace.x4),
          // Specs row
          _buildSpecsRow(option),
          const SizedBox(height: MivaltaSpace.x4),
          // Zone purpose (expandable — 2 lines collapsed, tappable "more")
          if (option.zonePurpose != null) ...[
            _ExpandableZonePurpose(text: option.zonePurpose!),
            const SizedBox(height: MivaltaSpace.x4),
          ],
          // Structure preview (TODO: full structure renderer)
          Container(
            padding: const EdgeInsets.all(MivaltaSpace.x3),
            decoration: BoxDecoration(
              color: MivaltaColors.surface1,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Session structure',
                  style: MivaltaType.cardTitle.copyWith(
                    color: MivaltaColors.textPrimary,
                  ),
                ),
                const SizedBox(height: MivaltaSpace.x2),
                // Placeholder for full structure renderer
                Text(
                  'Warmup → Main set → Cooldown',
                  style: MivaltaType.body.copyWith(
                    color: MivaltaColors.textSecondary,
                  ),
                ),
                if (option.focusCue != null) ...[
                  const SizedBox(height: MivaltaSpace.x2),
                  Text(
                    option.focusCue!,
                    style: MivaltaType.small.copyWith(
                      color: MivaltaColors.stateProductive,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: MivaltaSpace.x6),
          // "This one today" button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _chooseOption(option),
              style: ElevatedButton.styleFrom(
                backgroundColor: MivaltaColors.stateProductive,
                foregroundColor: MivaltaColors.surfaceBackground,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'This one today',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Specs row: duration, target watts/pace, tags.
  Widget _buildSpecsRow(WorkoutOption option) {
    final specs = <Widget>[];

    if (option.durationMin != null) {
      specs.add(_SpecItem(label: '${option.durationMin} min'));
    }
    if (option.targetWatts != null) {
      specs.add(_SpecItem(label: '${option.targetWatts} W'));
    }
    if (option.targetPaceMss != null) {
      specs.add(_SpecItem(label: option.targetPaceMss!));
    }
    for (final tag in option.tags) {
      specs.add(_SpecItem(label: tag, muted: true));
    }

    if (specs.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: MivaltaSpace.x2,
      runSpacing: MivaltaSpace.x2,
      children: specs,
    );
  }
}

/// Chip group for quick-adjust filters.
class _ChipGroup extends StatelessWidget {
  const _ChipGroup({
    required this.label,
    required this.values,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final List<String> values;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: MivaltaType.small.copyWith(
            color: MivaltaColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: values.map((v) {
            final isSelected = v == selected;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () => onSelected(isSelected ? null : v),
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? MivaltaColors.stateProductive.withValues(alpha: 0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? MivaltaColors.stateProductive
                          : MivaltaColors.textSecondary.withValues(alpha: 0.3),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _capitalize(v),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected
                          ? MivaltaColors.stateProductive
                          : MivaltaColors.textSecondary,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

/// Option card for workout selection.
class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.option,
    required this.isRecommended,
    required this.isChosen,
    required this.onTap,
  });

  final WorkoutOption option;
  final bool isRecommended;
  final bool isChosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MivaltaColors.surface1,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(MivaltaSpace.x3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isChosen
                  ? MivaltaColors.stateProductive
                  : MivaltaColors.textSecondary.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Zone chip + recommended/chosen badges
              Row(
                children: [
                  _ZoneChip(zone: option.zone),
                  const Spacer(),
                  if (isChosen)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: MivaltaColors.stateProductive.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check,
                            size: 14,
                            color: MivaltaColors.stateProductive,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Chosen',
                            style: MivaltaType.small.copyWith(
                              color: MivaltaColors.stateProductive,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (isRecommended)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: MivaltaColors.stateProductive.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Recommended',
                        style: MivaltaType.small.copyWith(
                          color: MivaltaColors.stateProductive,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: MivaltaSpace.x2),
              // Title + expression
              Row(
                children: [
                  Expanded(
                    child: Text(
                      option.title,
                      style: MivaltaType.cardTitle.copyWith(
                        color: MivaltaColors.textPrimary,
                      ),
                    ),
                  ),
                  if (option.expression != null)
                    Container(
                      margin: const EdgeInsets.only(left: MivaltaSpace.x2),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: MivaltaColors.textSecondary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        option.expression!,
                        style: MivaltaType.small.copyWith(
                          color: MivaltaColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: MivaltaSpace.x1),
              // Why
              Text(
                option.why,
                style: MivaltaType.body.copyWith(
                  color: MivaltaColors.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: MivaltaSpace.x2),
              // Specs row
              _buildSpecsRow(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpecsRow() {
    final specs = <String>[];
    if (option.durationMin != null) specs.add('${option.durationMin} min');
    if (option.targetWatts != null) specs.add('${option.targetWatts} W');
    if (option.targetPaceMss != null) specs.add(option.targetPaceMss!);

    if (specs.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        Text(
          specs.join(' · '),
          style: MivaltaType.small.copyWith(
            color: MivaltaColors.textSecondary,
          ),
        ),
        if (option.tags.isNotEmpty) ...[
          const SizedBox(width: MivaltaSpace.x2),
          Text(
            option.tags.join(' · '),
            style: MivaltaType.small.copyWith(
              color: MivaltaColors.textSecondary.withValues(alpha: 0.6),
            ),
          ),
        ],
      ],
    );
  }
}

/// Zone chip with energy name first.
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

/// Spec item chip for duration/watts/pace/tags.
class _SpecItem extends StatelessWidget {
  const _SpecItem({required this.label, this.muted = false});

  final String label;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: MivaltaColors.textSecondary.withValues(alpha: muted ? 0.05 : 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: MivaltaType.small.copyWith(
          color: MivaltaColors.textSecondary.withValues(alpha: muted ? 0.6 : 1.0),
        ),
      ),
    );
  }
}

/// Expandable zone purpose text — 2 lines collapsed with "more" tap.
class _ExpandableZonePurpose extends StatefulWidget {
  const _ExpandableZonePurpose({required this.text});

  final String text;

  @override
  State<_ExpandableZonePurpose> createState() => _ExpandableZonePurposeState();
}

class _ExpandableZonePurposeState extends State<_ExpandableZonePurpose> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.text,
            style: MivaltaType.small.copyWith(
              color: MivaltaColors.textSecondary,
            ),
            maxLines: _expanded ? null : 2,
            overflow: _expanded ? null : TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            _expanded ? 'less' : 'more',
            style: MivaltaType.small.copyWith(
              color: MivaltaColors.stateProductive,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

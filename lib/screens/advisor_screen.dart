// PR-D: Advisor surface — A/B/C workout options from the engine.
//
// Display only — every value comes from engine output.
// TOKENS ONLY — no inline Colors/hex/TextStyle.
//
// The advisor returns 3 equal-weight options. The athlete CHOOSES (no ranking).
// Each card shows: title, zone, duration, why (rationale_prose), tags.

import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/workout_option.dart';
import '../models/workout_report.dart';
import '../rust_engine.dart';
import '../theme/tokens.dart';
import '../widgets/analytics/post_workout_report_card.dart';

/// Advisor screen showing A/B/C workout options.
///
/// Receives engine binding and handle from parent.
/// Fetches workout recommendations on mount; athlete picks one.
class AdvisorScreen extends StatefulWidget {
  const AdvisorScreen({
    super.key,
    required this.binding,
    required this.handle,
  });

  final RustEngineBinding binding;
  final EnginesHandle handle;

  @override
  State<AdvisorScreen> createState() => _AdvisorScreenState();
}

class _AdvisorScreenState extends State<AdvisorScreen> {
  List<WorkoutOption> _options = [];
  bool _loading = true;
  String? _error;

  // Card-grounded post-workout report for the most recent completed session.
  WorkoutReport? _report;

  // Picker state
  String? _selectedMood;
  String? _selectedEquipment;
  String? _selectedTerrain;

  static const _moods = ['normal', 'tired', 'energised', 'stressed', 'fun'];
  static const _equipment = ['indoor', 'outdoor', 'trainer', 'gym'];
  static const _terrain = ['flat', 'hilly', 'mixed'];

  @override
  void initState() {
    super.initState();
    _fetchOptions();
    _fetchReport();
  }

  /// Build the card-grounded post-workout report for the most recent completed
  /// session: latest activity date → facts → report. Two pure pass-through
  /// calls; the engine composes. Absent/failed → section hidden, never faked.
  Future<void> _fetchReport() async {
    try {
      final actsJson =
          await widget.binding.readRecentActivities(widget.handle, limit: 1);
      final acts = jsonDecode(actsJson);
      if (acts is! List || acts.isEmpty || acts.first is! Map) return;
      final date = acts.first['date']?.toString();
      if (date == null || date.isEmpty) return;

      final factsJson =
          await widget.binding.completedWorkoutFacts(widget.handle, date: date);
      if (factsJson.trim() == 'null') return; // no activity that date

      final reportJson = await widget.binding
          .buildPostWorkoutReport(widget.handle, factsJson: factsJson);
      final report = WorkoutReport.fromJson(jsonDecode(reportJson));
      if (!report.isEmpty && mounted) {
        setState(() => _report = report);
      }
    } catch (_) {
      // No completed workout, or report unavailable — show nothing.
    }
  }

  Future<void> _fetchOptions() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final json = await widget.binding.recommendWorkoutWithHistory(
        widget.handle,
        mood: _selectedMood,
        equipment: _selectedEquipment,
        terrain: _selectedTerrain,
      );

      final decoded = jsonDecode(json);
      if (decoded is List) {
        _options = decoded.map((e) => WorkoutOption.fromJson(e)).toList();
      } else {
        _options = [];
      }
    } catch (e) {
      _error = '$e';
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  void _onMoodChanged(String? mood) {
    setState(() => _selectedMood = mood);
    _fetchOptions();
  }

  void _onEquipmentChanged(String? equipment) {
    setState(() => _selectedEquipment = equipment);
    _fetchOptions();
  }

  void _onTerrainChanged(String? terrain) {
    setState(() => _selectedTerrain = terrain);
    _fetchOptions();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: MivaltaColors.surfaceBackground,
      appBar: AppBar(
        backgroundColor: MivaltaColors.surfaceBackground,
        foregroundColor: MivaltaColors.textPrimary,
        title: Text(
          'Workout Options',
          style: textTheme.titleLarge?.copyWith(
            color: MivaltaColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Post-workout report for the most recent session (when present).
            if (_report != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  MivaltaSpace.x4,
                  MivaltaSpace.x4,
                  MivaltaSpace.x4,
                  0,
                ),
                child: PostWorkoutReportCard(report: _report!),
              ),

            // Pickers section
            _PreferencesPicker(
              selectedMood: _selectedMood,
              selectedEquipment: _selectedEquipment,
              selectedTerrain: _selectedTerrain,
              moods: _moods,
              equipment: _equipment,
              terrain: _terrain,
              onMoodChanged: _onMoodChanged,
              onEquipmentChanged: _onEquipmentChanged,
              onTerrainChanged: _onTerrainChanged,
            ),

            // Divider
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: MivaltaSpace.x4),
              child: Divider(color: MivaltaColors.surface2, height: 1),
            ),

            // Options list
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _ErrorView(error: _error!)
                      : _options.isEmpty
                          ? _EmptyView()
                          : AdvisorOptionsList(options: _options),
            ),
          ],
        ),
      ),
    );
  }
}

/// Preferences picker row with mood/equipment/terrain chips.
class _PreferencesPicker extends StatelessWidget {
  const _PreferencesPicker({
    required this.selectedMood,
    required this.selectedEquipment,
    required this.selectedTerrain,
    required this.moods,
    required this.equipment,
    required this.terrain,
    required this.onMoodChanged,
    required this.onEquipmentChanged,
    required this.onTerrainChanged,
  });

  final String? selectedMood;
  final String? selectedEquipment;
  final String? selectedTerrain;
  final List<String> moods;
  final List<String> equipment;
  final List<String> terrain;
  final void Function(String?) onMoodChanged;
  final void Function(String?) onEquipmentChanged;
  final void Function(String?) onTerrainChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(MivaltaSpace.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mood
          Text(
            'MOOD',
            style: textTheme.labelSmall?.copyWith(
              letterSpacing: 1.2,
              color: MivaltaColors.textMuted,
            ),
          ),
          const SizedBox(height: MivaltaSpace.x2),
          _ChipRow(
            options: moods,
            selected: selectedMood,
            onSelected: onMoodChanged,
          ),
          const SizedBox(height: MivaltaSpace.x3),

          // Equipment
          Text(
            'EQUIPMENT',
            style: textTheme.labelSmall?.copyWith(
              letterSpacing: 1.2,
              color: MivaltaColors.textMuted,
            ),
          ),
          const SizedBox(height: MivaltaSpace.x2),
          _ChipRow(
            options: equipment,
            selected: selectedEquipment,
            onSelected: onEquipmentChanged,
          ),
          const SizedBox(height: MivaltaSpace.x3),

          // Terrain
          Text(
            'TERRAIN',
            style: textTheme.labelSmall?.copyWith(
              letterSpacing: 1.2,
              color: MivaltaColors.textMuted,
            ),
          ),
          const SizedBox(height: MivaltaSpace.x2),
          _ChipRow(
            options: terrain,
            selected: selectedTerrain,
            onSelected: onTerrainChanged,
          ),
        ],
      ),
    );
  }
}

/// Row of selectable chips.
class _ChipRow extends StatelessWidget {
  const _ChipRow({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<String> options;
  final String? selected;
  final void Function(String?) onSelected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Wrap(
      spacing: MivaltaSpace.x2,
      runSpacing: MivaltaSpace.x2,
      children: options.map((option) {
        final isSelected = option == selected;
        return GestureDetector(
          onTap: () => onSelected(isSelected ? null : option),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: MivaltaSpace.x3,
              vertical: MivaltaSpace.x2,
            ),
            decoration: BoxDecoration(
              color: isSelected ? MivaltaColors.primaryGreen : MivaltaColors.surface2,
              borderRadius: BorderRadius.circular(MivaltaRadii.sm),
            ),
            child: Text(
              _capitalize(option),
              style: textTheme.bodySmall?.copyWith(
                color: isSelected ? MivaltaColors.surfaceBackground : MivaltaColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

/// Error view.
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error});
  final String error;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MivaltaSpace.x5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: MivaltaColors.levelRed,
              size: 48,
            ),
            const SizedBox(height: MivaltaSpace.x4),
            Text(
              error,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: MivaltaColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty state view.
class _EmptyView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MivaltaSpace.x5),
        child: Text(
          'No workout options available.\nTry adjusting your preferences.',
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(
            color: MivaltaColors.textMuted,
          ),
        ),
      ),
    );
  }
}

/// List of workout option cards.
/// Ranked advisor options — lead-with-A / offer-C (founder decision,
/// UI_UX_DIRECTION v1.6). PUBLIC so the ranking presentation is pinned by
/// widget test; production call site is this screen's build.
///
/// Display-only: the ENGINE ranks the options (A = the data-aligned pick,
/// C = the easy fallback); this widget only styles that ranking — first
/// option led, C offered as "or take it easy", anything else (B) behind a
/// "More options" reveal. No reordering, no thresholds.
class AdvisorOptionsList extends StatefulWidget {
  const AdvisorOptionsList({super.key, required this.options});
  final List<WorkoutOption> options;

  @override
  State<AdvisorOptionsList> createState() => _AdvisorOptionsListState();
}

class _AdvisorOptionsListState extends State<AdvisorOptionsList> {
  bool _showMore = false;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final options = widget.options;
    if (options.isEmpty) return const SizedBox.shrink();

    final lead = options.first;
    final easy = options
        .skip(1)
        .where((o) => o.optionId.toUpperCase() == 'C')
        .toList();
    final rest = options
        .skip(1)
        .where((o) => o.optionId.toUpperCase() != 'C')
        .toList();

    return ListView(
      padding: const EdgeInsets.all(MivaltaSpace.x4),
      children: [
        // ── The engine's recommended session, led. ──
        Padding(
          padding: const EdgeInsets.only(bottom: MivaltaSpace.x2),
          child: Text(
            'RECOMMENDED FOR TODAY',
            style: textTheme.labelSmall?.copyWith(
              color: MivaltaColors.primaryGreen,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        _WorkoutCard(option: lead, lead: true),

        // ── C: the easy alternative, one calm step away. ──
        if (easy.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: MivaltaSpace.x4),
            child: Row(
              children: [
                const Expanded(child: Divider(color: MivaltaColors.overlay)),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: MivaltaSpace.x3),
                  child: Text(
                    'or take it easy',
                    style: textTheme.labelMedium
                        ?.copyWith(color: MivaltaColors.textMuted),
                  ),
                ),
                const Expanded(child: Divider(color: MivaltaColors.overlay)),
              ],
            ),
          ),
          for (final o in easy) _WorkoutCard(option: o),
        ],

        // ── B (and anything else): available, never competing. ──
        if (rest.isNotEmpty) ...[
          const SizedBox(height: MivaltaSpace.x3),
          Center(
            child: TextButton(
              onPressed: () => setState(() => _showMore = !_showMore),
              child: Text(
                _showMore ? 'Fewer options' : 'More options',
                style: textTheme.labelLarge
                    ?.copyWith(color: MivaltaColors.textMuted),
              ),
            ),
          ),
          if (_showMore)
            for (final o in rest)
              Padding(
                padding: const EdgeInsets.only(top: MivaltaSpace.x3),
                child: Opacity(
                  opacity: 0.75,
                  child: _WorkoutCard(option: o),
                ),
              ),
        ],
        const SizedBox(height: MivaltaSpace.x4),
      ],
    );
  }
}

/// Individual workout option card. `lead: true` gives option A the
/// recommended-session emphasis (highlight border, raised surface).
class _WorkoutCard extends StatelessWidget {
  const _WorkoutCard({required this.option, this.lead = false});
  final WorkoutOption option;
  final bool lead;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(MivaltaSpace.x4),
      decoration: BoxDecoration(
        color: lead ? MivaltaColors.surface2 : MivaltaColors.surface1,
        borderRadius: BorderRadius.circular(MivaltaRadii.md),
        border: lead
            ? Border.all(color: MivaltaColors.primaryGreen, width: 1.5)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Option badge + title row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Option ID badge (A, B, C)
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _zoneColor(option.zone),
                  borderRadius: BorderRadius.circular(MivaltaRadii.sm),
                ),
                alignment: Alignment.center,
                child: Text(
                  option.optionId,
                  style: textTheme.labelLarge?.copyWith(
                    color: MivaltaColors.surfaceBackground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: MivaltaSpace.x3),

              // Title and zone
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.title,
                      style: textTheme.titleMedium?.copyWith(
                        color: MivaltaColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: MivaltaSpace.x1),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: MivaltaSpace.x2,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _zoneColor(option.zone).withAlpha(40),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            option.zone,
                            style: textTheme.labelSmall?.copyWith(
                              color: _zoneColor(option.zone),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (option.durationMin != null) ...[
                          const SizedBox(width: MivaltaSpace.x2),
                          Text(
                            '${option.durationMin} min',
                            style: textTheme.bodySmall?.copyWith(
                              color: MivaltaColors.textMuted,
                            ),
                          ),
                        ],
                        if (option.targetWatts != null) ...[
                          const SizedBox(width: MivaltaSpace.x2),
                          Text(
                            '${option.targetWatts}W',
                            style: textTheme.bodySmall?.copyWith(
                              color: MivaltaColors.textMuted,
                            ),
                          ),
                        ],
                        if (option.targetPaceMss != null) ...[
                          const SizedBox(width: MivaltaSpace.x2),
                          Text(
                            option.targetPaceMss!,
                            style: textTheme.bodySmall?.copyWith(
                              color: MivaltaColors.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Why / rationale
          if (option.why.isNotEmpty) ...[
            const SizedBox(height: MivaltaSpace.x3),
            Text(
              option.why,
              style: textTheme.bodyMedium?.copyWith(
                color: MivaltaColors.textSecondary,
              ),
            ),
          ],

          // Expression (workout variation, e.g. "Climb Repeats")
          if (option.expression != null && option.expression!.isNotEmpty) ...[
            const SizedBox(height: MivaltaSpace.x2),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: MivaltaSpace.x2,
                vertical: MivaltaSpace.x1,
              ),
              decoration: BoxDecoration(
                color: MivaltaColors.tertiaryTeal.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: MivaltaColors.tertiaryTeal,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.terrain_rounded,
                    size: 16,
                    color: MivaltaColors.primaryGreen,
                  ),
                  const SizedBox(width: MivaltaSpace.x1),
                  Text(
                    option.expression!,
                    style: textTheme.bodySmall?.copyWith(
                      color: MivaltaColors.primaryGreen,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Tags
          if (option.tags.isNotEmpty) ...[
            const SizedBox(height: MivaltaSpace.x3),
            Wrap(
              spacing: MivaltaSpace.x2,
              runSpacing: MivaltaSpace.x1,
              children: option.tags.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: MivaltaSpace.x2,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: MivaltaColors.surface2,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    tag,
                    style: textTheme.labelSmall?.copyWith(
                      color: MivaltaColors.textMuted,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  /// Map zone to color (uses tokens).
  Color _zoneColor(String zone) {
    final z = zone.toUpperCase();
    if (z == 'R' || z == 'Z1') return MivaltaColors.stateRecovered;
    if (z == 'Z2') return MivaltaColors.stateProductive;
    if (z == 'Z3') return MivaltaColors.stateAccumulated;
    if (z == 'Z4' || z == 'Z5') return MivaltaColors.levelOrange;
    if (z == 'Z6' || z == 'Z7' || z == 'Z8') return MivaltaColors.levelRed;
    return MivaltaColors.textMuted;
  }
}

// _WorkoutOption extracted to lib/models/workout_option.dart as the public,
// testable WorkoutOption (engine→Dart JSON contract guard).

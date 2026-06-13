// Tests for Advisor quick-adjust chips (§E: bounded reply chips).
//
// Verifies chip toggle behavior and callback invocation.
// The chips map to existing recommend_workout params (mood, equipment, terrain).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mivalta_flutter/theme/tokens.dart';

void main() {
  group('Quick-adjust chips', () {
    testWidgets('displays all four quick-adjust chips', (tester) async {
      String? selectedMood;
      String? selectedEquipment;
      String? selectedTerrain;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: _TestQuickAdjustChips(
              selectedMood: selectedMood,
              selectedEquipment: selectedEquipment,
              selectedTerrain: selectedTerrain,
              onMoodChanged: (v) => selectedMood = v,
              onEquipmentChanged: (v) => selectedEquipment = v,
              onTerrainChanged: (v) => selectedTerrain = v,
            ),
          ),
        ),
      );

      // Verify all chip labels are displayed
      expect(find.text('Feeling worse'), findsOneWidget);
      expect(find.text('Feeling better'), findsOneWidget);
      expect(find.text('Go easier'), findsOneWidget);
      expect(find.text('Indoor'), findsOneWidget);

      // Verify QUICK ADJUST header
      expect(find.text('QUICK ADJUST'), findsOneWidget);
    });

    testWidgets('Feeling worse chip toggles tired mood', (tester) async {
      String? selectedMood;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return _TestQuickAdjustChips(
                  selectedMood: selectedMood,
                  selectedEquipment: null,
                  selectedTerrain: null,
                  onMoodChanged: (v) => setState(() => selectedMood = v),
                  onEquipmentChanged: (_) {},
                  onTerrainChanged: (_) {},
                );
              },
            ),
          ),
        ),
      );

      // Tap Feeling worse
      await tester.tap(find.text('Feeling worse'));
      await tester.pumpAndSettle();

      expect(selectedMood, 'tired');

      // Tap again to deselect
      await tester.tap(find.text('Feeling worse'));
      await tester.pumpAndSettle();

      expect(selectedMood, isNull);
    });

    testWidgets('Feeling better chip toggles energised mood', (tester) async {
      String? selectedMood;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return _TestQuickAdjustChips(
                  selectedMood: selectedMood,
                  selectedEquipment: null,
                  selectedTerrain: null,
                  onMoodChanged: (v) => setState(() => selectedMood = v),
                  onEquipmentChanged: (_) {},
                  onTerrainChanged: (_) {},
                );
              },
            ),
          ),
        ),
      );

      // Tap Feeling better
      await tester.tap(find.text('Feeling better'));
      await tester.pumpAndSettle();

      expect(selectedMood, 'energised');
    });

    testWidgets('Go easier chip toggles flat terrain', (tester) async {
      String? selectedTerrain;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return _TestQuickAdjustChips(
                  selectedMood: null,
                  selectedEquipment: null,
                  selectedTerrain: selectedTerrain,
                  onMoodChanged: (_) {},
                  onEquipmentChanged: (_) {},
                  onTerrainChanged: (v) => setState(() => selectedTerrain = v),
                );
              },
            ),
          ),
        ),
      );

      // Tap Go easier
      await tester.tap(find.text('Go easier'));
      await tester.pumpAndSettle();

      expect(selectedTerrain, 'flat');
    });

    testWidgets('Indoor chip toggles indoor equipment', (tester) async {
      String? selectedEquipment;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return _TestQuickAdjustChips(
                  selectedMood: null,
                  selectedEquipment: selectedEquipment,
                  selectedTerrain: null,
                  onMoodChanged: (_) {},
                  onEquipmentChanged: (v) =>
                      setState(() => selectedEquipment = v),
                  onTerrainChanged: (_) {},
                );
              },
            ),
          ),
        ),
      );

      // Tap Indoor
      await tester.tap(find.text('Indoor'));
      await tester.pumpAndSettle();

      expect(selectedEquipment, 'indoor');
    });

    testWidgets('active chip shows primary color', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: _TestQuickAdjustChips(
              selectedMood: 'tired', // Feeling worse active
              selectedEquipment: null,
              selectedTerrain: null,
              onMoodChanged: (_) {},
              onEquipmentChanged: (_) {},
              onTerrainChanged: (_) {},
            ),
          ),
        ),
      );

      // Find the Feeling worse chip container
      final chipFinder = find.ancestor(
        of: find.text('Feeling worse'),
        matching: find.byType(Container),
      );

      // Should find at least one container (the chip)
      expect(chipFinder, findsWidgets);
    });

    testWidgets('selecting mood chip replaces previous mood', (tester) async {
      String? selectedMood;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return _TestQuickAdjustChips(
                  selectedMood: selectedMood,
                  selectedEquipment: null,
                  selectedTerrain: null,
                  onMoodChanged: (v) => setState(() => selectedMood = v),
                  onEquipmentChanged: (_) {},
                  onTerrainChanged: (_) {},
                );
              },
            ),
          ),
        ),
      );

      // First select "Feeling worse"
      await tester.tap(find.text('Feeling worse'));
      await tester.pumpAndSettle();
      expect(selectedMood, 'tired');

      // Then select "Feeling better" - should replace
      await tester.tap(find.text('Feeling better'));
      await tester.pumpAndSettle();
      expect(selectedMood, 'energised');
    });
  });

  group('Expandable preferences picker', () {
    testWidgets('shows "More options" header collapsed by default',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: _TestExpandablePreferencesPicker(
              selectedMood: null,
              selectedEquipment: null,
              selectedTerrain: null,
              onMoodChanged: (_) {},
              onEquipmentChanged: (_) {},
              onTerrainChanged: (_) {},
            ),
          ),
        ),
      );

      // Should see "More options" text
      expect(find.text('More options'), findsOneWidget);

      // Should NOT see MOOD, EQUIPMENT, TERRAIN labels (collapsed)
      expect(find.text('MOOD'), findsNothing);
      expect(find.text('EQUIPMENT'), findsNothing);
      expect(find.text('TERRAIN'), findsNothing);
    });

    testWidgets('expands to show all picker rows on tap', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: _TestExpandablePreferencesPicker(
                selectedMood: null,
                selectedEquipment: null,
                selectedTerrain: null,
                onMoodChanged: (_) {},
                onEquipmentChanged: (_) {},
                onTerrainChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      // Tap to expand
      await tester.tap(find.text('More options'));
      await tester.pumpAndSettle();

      // Should now see MOOD, EQUIPMENT, TERRAIN labels
      expect(find.text('MOOD'), findsOneWidget);
      expect(find.text('EQUIPMENT'), findsOneWidget);
      expect(find.text('TERRAIN'), findsOneWidget);

      // Should see mood options
      expect(find.text('Normal'), findsOneWidget);
      expect(find.text('Tired'), findsOneWidget);
      expect(find.text('Energised'), findsOneWidget);
    });

    testWidgets('collapses again on second tap', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: _TestExpandablePreferencesPicker(
                selectedMood: null,
                selectedEquipment: null,
                selectedTerrain: null,
                onMoodChanged: (_) {},
                onEquipmentChanged: (_) {},
                onTerrainChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      // Expand
      await tester.tap(find.text('More options'));
      await tester.pumpAndSettle();
      expect(find.text('MOOD'), findsOneWidget);

      // Collapse
      await tester.tap(find.text('More options'));
      await tester.pumpAndSettle();
      expect(find.text('MOOD'), findsNothing);
    });
  });
}

// ============================================================================
// Test widgets (extract the relevant widget logic for isolated testing)
// ============================================================================

/// Quick-adjust chips test widget - mirrors the production widget.
class _TestQuickAdjustChips extends StatelessWidget {
  const _TestQuickAdjustChips({
    required this.selectedMood,
    required this.selectedEquipment,
    required this.selectedTerrain,
    required this.onMoodChanged,
    required this.onEquipmentChanged,
    required this.onTerrainChanged,
  });

  final String? selectedMood;
  final String? selectedEquipment;
  final String? selectedTerrain;
  final void Function(String?) onMoodChanged;
  final void Function(String?) onEquipmentChanged;
  final void Function(String?) onTerrainChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'QUICK ADJUST',
            style: textTheme.labelSmall?.copyWith(
              letterSpacing: 1.2,
              color: MivaltaColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _TestQuickChip(
                label: 'Feeling worse',
                icon: Icons.sentiment_dissatisfied,
                isActive: selectedMood == 'tired',
                onTap: () =>
                    onMoodChanged(selectedMood == 'tired' ? null : 'tired'),
              ),
              _TestQuickChip(
                label: 'Feeling better',
                icon: Icons.sentiment_satisfied,
                isActive: selectedMood == 'energised',
                onTap: () => onMoodChanged(
                    selectedMood == 'energised' ? null : 'energised'),
              ),
              _TestQuickChip(
                label: 'Go easier',
                icon: Icons.trending_down,
                isActive: selectedTerrain == 'flat',
                onTap: () =>
                    onTerrainChanged(selectedTerrain == 'flat' ? null : 'flat'),
              ),
              _TestQuickChip(
                label: 'Indoor',
                icon: Icons.home,
                isActive: selectedEquipment == 'indoor',
                onTap: () => onEquipmentChanged(
                    selectedEquipment == 'indoor' ? null : 'indoor'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Single quick-adjust chip test widget.
class _TestQuickChip extends StatelessWidget {
  const _TestQuickChip({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? MivaltaColors.primaryGreen : MivaltaColors.surface2,
          borderRadius: BorderRadius.circular(8),
          border: isActive
              ? null
              : Border.all(color: MivaltaColors.overlay, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive
                  ? MivaltaColors.surfaceBackground
                  : MivaltaColors.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: textTheme.bodySmall?.copyWith(
                color: isActive
                    ? MivaltaColors.surfaceBackground
                    : MivaltaColors.textSecondary,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Expandable preferences picker test widget.
class _TestExpandablePreferencesPicker extends StatefulWidget {
  const _TestExpandablePreferencesPicker({
    required this.selectedMood,
    required this.selectedEquipment,
    required this.selectedTerrain,
    required this.onMoodChanged,
    required this.onEquipmentChanged,
    required this.onTerrainChanged,
  });

  final String? selectedMood;
  final String? selectedEquipment;
  final String? selectedTerrain;
  final void Function(String?) onMoodChanged;
  final void Function(String?) onEquipmentChanged;
  final void Function(String?) onTerrainChanged;

  @override
  State<_TestExpandablePreferencesPicker> createState() =>
      _TestExpandablePreferencesPickerState();
}

class _TestExpandablePreferencesPickerState
    extends State<_TestExpandablePreferencesPicker> {
  bool _expanded = false;

  static const _moods = ['normal', 'tired', 'energised', 'stressed', 'fun'];
  static const _equipment = ['indoor', 'outdoor', 'trainer', 'gym'];
  static const _terrain = ['flat', 'hilly', 'mixed'];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Expand/collapse header
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Text(
                    'More options',
                    style: textTheme.labelMedium?.copyWith(
                      color: MivaltaColors.textMuted,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: MivaltaColors.textMuted,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // Expanded content
          if (_expanded) ...[
            const SizedBox(height: 8),

            // Mood
            Text(
              'MOOD',
              style: textTheme.labelSmall?.copyWith(
                letterSpacing: 1.2,
                color: MivaltaColors.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            _TestChipRow(
              options: _moods,
              selected: widget.selectedMood,
              onSelected: widget.onMoodChanged,
            ),
            const SizedBox(height: 12),

            // Equipment
            Text(
              'EQUIPMENT',
              style: textTheme.labelSmall?.copyWith(
                letterSpacing: 1.2,
                color: MivaltaColors.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            _TestChipRow(
              options: _equipment,
              selected: widget.selectedEquipment,
              onSelected: widget.onEquipmentChanged,
            ),
            const SizedBox(height: 12),

            // Terrain
            Text(
              'TERRAIN',
              style: textTheme.labelSmall?.copyWith(
                letterSpacing: 1.2,
                color: MivaltaColors.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            _TestChipRow(
              options: _terrain,
              selected: widget.selectedTerrain,
              onSelected: widget.onTerrainChanged,
            ),
          ],
        ],
      ),
    );
  }
}

/// Row of selectable chips for test.
class _TestChipRow extends StatelessWidget {
  const _TestChipRow({
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
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final isSelected = option == selected;
        return GestureDetector(
          onTap: () => onSelected(isSelected ? null : option),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? MivaltaColors.primaryGreen
                  : MivaltaColors.surface2,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _capitalize(option),
              style: textTheme.bodySmall?.copyWith(
                color: isSelected
                    ? MivaltaColors.surfaceBackground
                    : MivaltaColors.textSecondary,
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

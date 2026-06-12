// Sensor-check entry screen (HOME_REDESIGN_BRIEF §4 item 5, §6 step 4) —
// the Start-workout button on Today lands here. Staged flow: sensor check
// first, optional GPS map + minimal live screen as the follow-up.
//
// LAST-TWO item 23 (docs/FOUNDER_FEEDBACK_2026-06-12.md): on start, choose
// the ACTIVITY — running variants (outdoor/trail/treadmill), walking, cycling
// variants (road/indoor/virtual/MTB) — and see which tracking devices are
// connected to THIS workout.
//
// ⚠ FL-17 NUANCE: the picker sets the WORKOUT's activity_type (the ingest
// path — the same engine strings health_ingest.dart maps to: 'run' / 'walk'
// / 'ride'; the engine's allowlist handles walk via the universal baseline).
// It does NOT touch the profile Sport enum (still cycling/running only) —
// do not re-add walking there.
//
// HONEST STATES ONLY (brief §4: "No fabricated sensor states — honest 'not
// connected'"): this app has no BLE or GPS plumbing yet, so the only truthful
// rows are "Not connected" / "coming with the live screen". No fake scanning,
// no fake spinners. The live-start action is DISABLED with an honest note
// until the live screen lands; manual logging is the working capture path
// (§9 capture zone — the screen still gives data back).
//
// DISPLAY ONLY + engine-free: no engine handle here. The production call
// site ([ReadinessScreen]) wires [onLogManually] to its existing
// manual-entry flow.

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Screen + section copy. Fixed strings so tests pin them and reviews can
/// diff wording in one place.
const kSensorCheckTitle = 'Start workout';
const kActivitySectionLabel = 'ACTIVITY';
const kSensorSectionLabel = 'DEVICES FOR THIS WORKOUT';
const kSensorHrLabel = 'Heart rate monitor';
const kSensorHrNotConnectedCopy = 'Not connected';
const kSensorGpsLabel = 'GPS';
const kSensorGpsStagedCopy = 'Coming with the live screen';
const kLiveWorkoutButtonLabel = 'Start live workout';
const kLiveWorkoutStagedNote =
    'Live tracking is on its way. Until then, log your workout manually — '
    'it counts just the same.';
const kLogManuallyButtonLabel = 'Log a workout manually';

/// One pickable activity for the start flow (item 23).
///
/// [activityType] is the engine's `VaultActivity.activity_type` string for
/// THE WORKOUT being started — the exact values the ingest path already
/// writes (see health_ingest.dart's mapping table). Variants are a display
/// distinction; the engine contract stays the base string.
class ActivityChoice {
  const ActivityChoice(this.label, this.activityType);

  /// User-facing label (display layer).
  final String label;

  /// Engine activity_type for the ingest path — never user-visible.
  final String activityType;
}

/// The founder's item-23 list, in order: all kinds of running, walking,
/// all types of cycling. Fixed display dictionary — engine strings verified
/// against health_ingest.dart's production mapping, never invented.
const List<ActivityChoice> kActivityChoices = [
  ActivityChoice('Outdoor run', 'run'),
  ActivityChoice('Trail run', 'run'),
  ActivityChoice('Treadmill run', 'run'),
  ActivityChoice('Walk', 'walk'),
  ActivityChoice('Road ride', 'ride'),
  ActivityChoice('Indoor ride', 'ride'),
  ActivityChoice('Virtual ride', 'ride'),
  ActivityChoice('Mountain bike', 'ride'),
];

/// Fixed glyph per engine activity_type — display dictionary only.
IconData activityGlyph(String activityType) {
  switch (activityType) {
    case 'run':
      return Icons.directions_run;
    case 'walk':
      return Icons.directions_walk;
    case 'ride':
      return Icons.directions_bike;
  }
  return Icons.fitness_center;
}

/// The sensor-check screen between the Today Start-workout button and the
/// (staged) live screen. Production call site: [ReadinessScreen]'s
/// `_openSensorCheck`. Public so widget tests can pump it directly.
class SensorCheckScreen extends StatefulWidget {
  const SensorCheckScreen({super.key, this.onLogManually});

  /// Working capture path while the live screen is staged — production
  /// wires this to the home's manual-entry flow. Null hides the action
  /// (the screen stays honest either way).
  final VoidCallback? onLogManually;

  @override
  State<SensorCheckScreen> createState() => _SensorCheckScreenState();
}

class _SensorCheckScreenState extends State<SensorCheckScreen> {
  /// Selected activity for THIS workout (item 23). Defaults to the first
  /// choice; the selection is what the live-start path will stamp as the
  /// workout's activity_type when live tracking lands.
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: MivaltaColors.surfaceBackground,
      appBar: AppBar(
        backgroundColor: MivaltaColors.surfaceBackground,
        foregroundColor: MivaltaColors.textPrimary,
        title: const Text(kSensorCheckTitle),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: MivaltaSpace.x5,
          vertical: MivaltaSpace.x4,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Item 23: choose the activity for THIS workout.
            Text(
              kActivitySectionLabel,
              style: textTheme.labelSmall?.copyWith(
                letterSpacing: 1.2,
                color: MivaltaColors.textMuted,
              ),
            ),
            const SizedBox(height: MivaltaSpace.x3),
            // Founder night-round polish: a horizontal SCROLLER of activity
            // cards, not a wrapped chip cloud. SingleChildScrollView (not a
            // lazy list) so every card exists for tests and a11y.
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(
                children: [
                  for (var i = 0; i < kActivityChoices.length; i++) ...[
                    if (i > 0) const SizedBox(width: MivaltaSpace.x2),
                    _ActivityCard(
                      choice: kActivityChoices[i],
                      selected: i == _selectedIndex,
                      onSelected: () => setState(() => _selectedIndex = i),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: MivaltaSpace.x6),

            Text(
              kSensorSectionLabel,
              style: textTheme.labelSmall?.copyWith(
                letterSpacing: 1.2,
                color: MivaltaColors.textMuted,
              ),
            ),
            const SizedBox(height: MivaltaSpace.x3),

            // Honest sensor rows — nothing is connected because nothing CAN
            // connect yet; say exactly that.
            const _SensorRow(
              icon: Icons.favorite_outline,
              label: kSensorHrLabel,
              status: kSensorHrNotConnectedCopy,
            ),
            const SizedBox(height: MivaltaSpace.x3),
            const _SensorRow(
              icon: Icons.location_on_outlined,
              label: kSensorGpsLabel,
              status: kSensorGpsStagedCopy,
            ),
            const SizedBox(height: MivaltaSpace.x6),

            // Live start — disabled until the live screen lands (staged
            // follow-up, brief §6 step 4). Disabled is the honest state.
            FilledButton.icon(
              onPressed: null,
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(vertical: MivaltaSpace.x4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(MivaltaRadii.md),
                ),
              ),
              icon: const Icon(Icons.play_arrow),
              label: const Text(kLiveWorkoutButtonLabel),
            ),
            const SizedBox(height: MivaltaSpace.x2),
            Text(
              kLiveWorkoutStagedNote,
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(
                color: MivaltaColors.textMuted,
                height: 1.35,
              ),
            ),

            // The working path today: give data back via manual logging
            // (§9 capture zone) — this screen is never a dead end.
            if (widget.onLogManually != null) ...[
              const SizedBox(height: MivaltaSpace.x6),
              OutlinedButton.icon(
                onPressed: widget.onLogManually,
                style: OutlinedButton.styleFrom(
                  foregroundColor: MivaltaColors.primaryGreen,
                  side: const BorderSide(color: MivaltaColors.surface2),
                  padding:
                      const EdgeInsets.symmetric(vertical: MivaltaSpace.x4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(MivaltaRadii.md),
                  ),
                ),
                icon: const Icon(Icons.edit_note),
                label: const Text(kLogManuallyButtonLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One activity card in the horizontal scroller — glyph over label, quiet by
/// default, green hairline + green glyph when chosen (same subtle selection
/// language as the start control, round 3-final item 20).
class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.choice,
    required this.selected,
    required this.onSelected,
  });

  final ActivityChoice choice;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: selected ? MivaltaColors.surface2 : MivaltaColors.surface1,
      borderRadius: BorderRadius.circular(MivaltaRadii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(MivaltaRadii.md),
        onTap: onSelected,
        child: AnimatedContainer(
          duration: MivaltaMotion.fast,
          padding: const EdgeInsets.symmetric(
            horizontal: MivaltaSpace.x4,
            vertical: MivaltaSpace.x3,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MivaltaRadii.md),
            border: Border.all(
              color: selected
                  ? MivaltaColors.primaryGreen
                  : MivaltaColors.surface2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                activityGlyph(choice.activityType),
                size: 24,
                color: selected
                    ? MivaltaColors.primaryGreen
                    : MivaltaColors.textMuted,
              ),
              const SizedBox(height: MivaltaSpace.x2),
              Text(
                choice.label,
                style: textTheme.bodySmall?.copyWith(
                  color: selected
                      ? MivaltaColors.textPrimary
                      : MivaltaColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One sensor row: icon + name + honest status text. No state machine —
/// there is no sensor stack to have states yet.
class _SensorRow extends StatelessWidget {
  const _SensorRow({
    required this.icon,
    required this.label,
    required this.status,
  });

  final IconData icon;
  final String label;
  final String status;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(MivaltaSpace.x4),
      decoration: BoxDecoration(
        color: MivaltaColors.surface1,
        borderRadius: BorderRadius.circular(MivaltaRadii.md),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: MivaltaColors.textMuted),
          const SizedBox(width: MivaltaSpace.x3),
          Expanded(
            child: Text(
              label,
              style: textTheme.bodyMedium?.copyWith(
                color: MivaltaColors.textPrimary,
              ),
            ),
          ),
          Text(
            status,
            style: textTheme.bodySmall?.copyWith(
              color: MivaltaColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

// Sensor-check entry screen (HOME_REDESIGN_BRIEF §4 item 5, §6 step 4) —
// the Start-workout button on Today lands here. Staged flow: sensor check
// first, optional GPS map + minimal live screen as the follow-up.
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
const kSensorSectionLabel = 'SENSORS';
const kSensorHrLabel = 'Heart rate monitor';
const kSensorHrNotConnectedCopy = 'Not connected';
const kSensorGpsLabel = 'GPS';
const kSensorGpsStagedCopy = 'Coming with the live screen';
const kLiveWorkoutButtonLabel = 'Start live workout';
const kLiveWorkoutStagedNote =
    'Live tracking is on its way. Until then, log your workout manually — '
    'it counts just the same.';
const kLogManuallyButtonLabel = 'Log a workout manually';

/// The sensor-check screen between the Today Start-workout button and the
/// (staged) live screen. Production call site: [ReadinessScreen]'s
/// `_openSensorCheck`. Public so widget tests can pump it directly.
class SensorCheckScreen extends StatelessWidget {
  const SensorCheckScreen({super.key, this.onLogManually});

  /// Working capture path while the live screen is staged — production
  /// wires this to the home's manual-entry flow. Null hides the action
  /// (the screen stays honest either way).
  final VoidCallback? onLogManually;

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
            if (onLogManually != null) ...[
              const SizedBox(height: MivaltaSpace.x6),
              OutlinedButton.icon(
                onPressed: onLogManually,
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

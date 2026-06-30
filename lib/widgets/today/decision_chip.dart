// DecisionChip — the training decision indicator.
// Per Today-Modular.html: a bordered chip with check icon showing the day's
// training decision ("Train as planned", "Rest today", etc.).
//
// The decision comes from the engine's session zone and workout recommendation.
// Engine DECIDES; Dart only renders.

import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// The training decision chip for the Today screen.
///
/// Shows a bordered chip with an icon and the training decision text.
/// When [isRest] is true, shows a rest-specific style. When [noData] is true,
/// shows an honest absence state.
class DecisionChip extends StatelessWidget {
  const DecisionChip({
    super.key,
    required this.text,
    this.isRest = false,
    this.noData = false,
    this.onTap,
  });

  /// The decision text to display ("Train as planned", "Rest today", etc.).
  final String text;

  /// Whether this is a rest day (changes icon and styling).
  final bool isRest;

  /// When true, shows honest absence styling.
  final bool noData;

  /// Callback when the chip is tapped.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color chipColor;
    final IconData icon;

    if (noData) {
      chipColor = MivaltaColors.textMuted;
      icon = Icons.help_outline;
    } else if (isRest) {
      chipColor = MivaltaColors.stateRecovered;
      icon = Icons.self_improvement;
    } else {
      chipColor = MivaltaColors.stateProductive;
      icon = Icons.check_circle_outline;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: MivaltaSpace.x4,
          vertical: MivaltaSpace.x3,
        ),
        decoration: BoxDecoration(
          color: chipColor.withValues(alpha: 0.1),
          border: Border.all(color: chipColor.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(MivaltaRadii.md),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: chipColor),
            const SizedBox(width: MivaltaSpace.x2),
            Text(
              text,
              style: MivaltaTextStyles.body(
                color: chipColor,
                weight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Plan tab — HONEST placeholder (HOME_REDESIGN_BRIEF §3, founder directive
// 2026-06-12). No fake roadmap, no fabricated calendar, no raw engine
// identifiers. Calm copy only: what Plan will become + what the engine needs
// first. Copy is FLAGGED FOR FOUNDER REVIEW before lock (brief §7).

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Placeholder copy — flagged for founder review (HOME_REDESIGN_BRIEF §7).
/// Kept as constants so the review can diff copy without reading the widget.
const kPlanPlaceholderTitle = 'Your plan will live here.';
const kPlanPlaceholderBody =
    'Josi builds it from how you actually train and recover — no guesses. '
    'Keep logging workouts and morning check-ins, and a week-by-week plan '
    'takes shape here.';

/// The Plan anchor. Honest placeholder this round: states what Plan will
/// become and what it needs first. Renders nothing engine-derived, so it is
/// identical across all four home states (no-data / low-confidence / normal /
/// red).
class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: MivaltaColors.surfaceBackground,
      appBar: AppBar(
        backgroundColor: MivaltaColors.surfaceBackground,
        foregroundColor: MivaltaColors.textPrimary,
        title: const Text('Plan'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: MivaltaSpace.x6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.route_outlined,
                size: 40,
                color: MivaltaColors.textMuted,
              ),
              const SizedBox(height: MivaltaSpace.x4),
              Text(
                kPlanPlaceholderTitle,
                textAlign: TextAlign.center,
                style: textTheme.titleMedium?.copyWith(
                  color: MivaltaColors.textPrimary,
                ),
              ),
              const SizedBox(height: MivaltaSpace.x2),
              Text(
                kPlanPlaceholderBody,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: MivaltaColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

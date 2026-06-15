// "How MiValta is learning you" — the honest model-trust surface (engine
// gap #2). Renders ViterbiEngine.personalization_diagnostics() +
// .validation_report() via the [LearningStatus] parse model. Display only:
// every value is a verbatim engine read; the card states the engine's own
// learning progress and validation verdict, and says so plainly when it has
// nothing yet (no fabricated progress, no decimals).
//
// Copy here is display labelling around engine values (same class as the
// existing "I'm still learning you — day X" line); the NUMBERS and BUCKETS are
// the engine's, never Dart's.

import 'package:flutter/material.dart';

import '../models/learning_status.dart';
import '../theme/tokens.dart';

class LearningStatusCard extends StatelessWidget {
  const LearningStatusCard({super.key, required this.status});

  final LearningStatus status;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // Learning-progress line (personalization_diagnostics).
    final String learningLine;
    if (!status.hasBegunLearning) {
      learningLine =
          "I haven't started learning your baseline yet — log a few days and I'll begin.";
    } else {
      final day = status.observationCount!;
      final bucket = status.confidenceBucket;
      learningLine = bucket == null
          ? 'Learning your baseline — day $day.'
          : 'Learning your baseline — day $day · $bucket confidence.';
    }

    // Validation line (validation_report): is the model proven for YOU yet.
    final String validationLine;
    if (!status.isValidated) {
      validationLine =
          'Not yet validated against your own outcomes — ${status.pairedObservations} paired day'
          '${status.pairedObservations == 1 ? '' : 's'} so far.';
    } else {
      validationLine =
          'Validated against ${status.pairedObservations} of your own days '
          '(${status.dataSufficiency} confidence over ${status.periodDays} days).';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(MivaltaSpace.x4),
      decoration: BoxDecoration(
        color: MivaltaColors.surface1,
        borderRadius: BorderRadius.circular(MivaltaRadii.md),
        border: Border.all(
          color: MivaltaColors.textMuted.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How MiValta is learning you',
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: MivaltaSpace.x2),
          Text(
            learningLine,
            style: textTheme.bodyMedium
                ?.copyWith(color: MivaltaColors.textSecondary),
          ),
          const SizedBox(height: MivaltaSpace.x2),
          Text(
            validationLine,
            style: textTheme.bodyMedium
                ?.copyWith(color: MivaltaColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

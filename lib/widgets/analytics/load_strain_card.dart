// Load & Strain card — Explore view.
//
// Display-only. Renders the engine's load rollup (LoadContext / context widget):
// ACWR with its zone + recommendation, and Foster monotony/strain with their
// zone + recommendation. Zone labels and recommendation prose are engine/
// card-sourced verbatim — Dart applies no thresholds and maps no zone→meaning.
// Honest empty states for cold-start and corrupt-state.

import 'package:flutter/material.dart';

import '../../models/load_context.dart';
import '../../theme/tokens.dart';

class LoadStrainCard extends StatelessWidget {
  const LoadStrainCard({super.key, required this.context_});

  /// Named `context_` to avoid shadowing the `BuildContext context` parameter.
  final LoadContext context_;

  @override
  Widget build(BuildContext buildContext) {
    final textTheme = Theme.of(buildContext).textTheme;

    if (!context_.available) {
      return _shell(
        child: Text(
          'Load context unavailable.',
          style: textTheme.bodyMedium?.copyWith(color: MivaltaColors.textMuted),
        ),
      );
    }
    if (!context_.hasReadings) {
      return _shell(
        child: Text(
          'Not enough training history yet.',
          style: textTheme.bodyMedium?.copyWith(color: MivaltaColors.textMuted),
        ),
      );
    }

    return _shell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MetricLine(
            label: 'ACWR',
            value: context_.acwr.toStringAsFixed(2),
            zone: context_.acwrZone,
          ),
          if (context_.acwrRecommendation.isNotEmpty) ...[
            const SizedBox(height: MivaltaSpace.x2),
            _prose(context_.acwrRecommendation, textTheme),
          ],
          const Divider(height: MivaltaSpace.x6, color: MivaltaColors.surface2),
          _MetricLine(
            label: 'Monotony',
            value: context_.monotony.toStringAsFixed(2),
            zone: context_.monotonyZone,
          ),
          const SizedBox(height: MivaltaSpace.x2),
          _MetricLine(
            label: 'Strain',
            value: context_.strain.round().toString(),
            zone: '',
          ),
          if (context_.monotonyRecommendation.isNotEmpty) ...[
            const SizedBox(height: MivaltaSpace.x2),
            _prose(context_.monotonyRecommendation, textTheme),
          ],
        ],
      ),
    );
  }

  Widget _shell({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(MivaltaSpace.x4),
        decoration: BoxDecoration(
          color: MivaltaColors.surface1,
          borderRadius: BorderRadius.circular(MivaltaRadii.md),
        ),
        child: child,
      );

  Widget _prose(String text, TextTheme textTheme) => Text(
        text,
        style: textTheme.bodySmall?.copyWith(color: MivaltaColors.textSecondary),
      );
}

class _MetricLine extends StatelessWidget {
  const _MetricLine({required this.label, required this.value, required this.zone});

  final String label;
  final String value;
  final String zone;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: textTheme.bodyMedium?.copyWith(color: MivaltaColors.textSecondary),
          ),
        ),
        Text(
          value,
          style: textTheme.titleMedium?.copyWith(
            color: MivaltaColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (zone.isNotEmpty) ...[
          const SizedBox(width: MivaltaSpace.x2),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: MivaltaSpace.x2,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: MivaltaColors.surface2,
              borderRadius: BorderRadius.circular(MivaltaRadii.sm),
            ),
            child: Text(
              zone,
              style: textTheme.labelSmall?.copyWith(color: MivaltaColors.textMuted),
            ),
          ),
        ],
      ],
    );
  }
}

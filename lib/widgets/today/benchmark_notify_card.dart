// Benchmark-change notify card — Phase 3 widget.
//
// The coach saying "you got measurably faster" out loud. Renders the engine's
// composed card: the headline, the before→after line, a tappable "why?" that
// reveals the engine's evidence disclosure, and a dismiss affordance. Every
// string is engine-composed and shown verbatim — no Dart phrasing, no math.

import 'package:flutter/material.dart';

import '../../models/benchmark_change_card.dart';
import '../../theme/tokens.dart';

class BenchmarkNotifyCard extends StatefulWidget {
  const BenchmarkNotifyCard({
    super.key,
    required this.card,
    required this.onDismiss,
  });

  final BenchmarkChangeCard card;
  final VoidCallback onDismiss;

  @override
  State<BenchmarkNotifyCard> createState() => _BenchmarkNotifyCardState();
}

class _BenchmarkNotifyCardState extends State<BenchmarkNotifyCard> {
  bool _showWhy = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.card;
    // A promotion is celebratory (brand green); a demote is a calm neutral.
    final accent = c.kind == 'promote'
        ? MivaltaColors.primaryGreen
        : MivaltaColors.textSecondary;

    return Container(
      margin: const EdgeInsets.only(bottom: MivaltaSpace.x3),
      padding: const EdgeInsets.all(MivaltaSpace.x4),
      decoration: BoxDecoration(
        color: MivaltaColors.surface1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                c.kind == 'promote'
                    ? Icons.trending_up
                    : Icons.trending_down,
                color: accent,
                size: 20,
              ),
              const SizedBox(width: MivaltaSpace.x2),
              Expanded(
                child: Text(
                  c.headline,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: MivaltaColors.textPrimary,
                  ),
                ),
              ),
              // Dismiss — acknowledge the notification.
              GestureDetector(
                onTap: widget.onDismiss,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close,
                      size: 18, color: MivaltaColors.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: MivaltaSpace.x2),
          Text(
            c.benchmarkLine,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: MivaltaColors.textSecondary,
            ),
          ),
          if (c.disclosure.isNotEmpty) ...[
            const SizedBox(height: MivaltaSpace.x2),
            GestureDetector(
              onTap: () => setState(() => _showWhy = !_showWhy),
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Why?',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: accent,
                    ),
                  ),
                  Icon(
                    _showWhy ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: accent,
                  ),
                ],
              ),
            ),
            if (_showWhy) ...[
              const SizedBox(height: MivaltaSpace.x1),
              ...c.disclosure.map(
                (line) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('· ',
                          style: TextStyle(color: MivaltaColors.textMuted)),
                      Expanded(
                        child: Text(
                          line,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            color: MivaltaColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

// Josi — the PRESENTER (autocue). Beta-MVP: MONITOR + ADVISORY.
//
// WHAT JOSI IS (and is not):
//   Josi READS OUT and EMPHASISES what the engine is reporting — she is a
//   PRESENTER, an autocue voice for the home. She is NOT a chat partner.
//   There is deliberately NO text box, NO open Q&A, NO conversation here.
//   The user's only interactions in beta are progressive disclosure ("why?")
//   and, on the Advisor screen, CHOOSING among the engine's suggested
//   workouts. Open/coaching conversation is COACH tier (Tier 3) and is out of
//   beta scope.
//
// WHERE JOSI'S KNOWLEDGE COMES FROM:
//   The engine + vault are the brains and the memory — they learn the athlete
//   over time. Josi is only the face/voice that presents what they know. She
//   computes nothing and remembers nothing herself.
//
// DISPLAY ONLY (architecture rule 1/3): every sentence Josi speaks is engine
// output rendered VERBATIM (state_recommendation, rationale_prose,
// confidence_advisory) or an engine VALUE (readiness score, session
// title/zone/duration). Josi only sequences and frames them in a spoken
// "autocue" voice — she invents nothing, so she cannot fabricate. On no data
// she presents the LOCKED F1 copy verbatim.

import 'package:flutter/material.dart';

import '../copy/f1.dart';
import '../theme/tokens.dart';

/// Josi's autocue read at the top of the home. Presents the engine's current
/// situation in a spoken voice; the three zones below are the "go deeper"
/// layer (progressive disclosure). No input surface.
class JosiPresenter extends StatefulWidget {
  const JosiPresenter({
    super.key,
    required this.insufficientData,
    this.stateRecommendation,
    this.confidenceAdvisory,
    this.workoutTitle,
    this.durationMin,
    this.sessionZone,
    this.rationaleProse,
  });

  /// No observations yet — Josi honestly presents the locked F1 no-data line.
  final bool insufficientData;

  /// Engine `state_widget.state_recommendation` — Josi's headline read.
  final String? stateRecommendation;

  /// Engine `state_widget.confidence_advisory` — honest "still learning you".
  final String? confidenceAdvisory;

  /// Engine `session_widget` values — today's session, presented plainly.
  final String? workoutTitle;
  final int? durationMin;
  final String? sessionZone;

  /// Engine `session_widget.rationale_prose` — revealed under "why?".
  final String? rationaleProse;

  @override
  State<JosiPresenter> createState() => _JosiPresenterState();
}

class _JosiPresenterState extends State<JosiPresenter> {
  bool _showWhy = false;

  bool get _hasWhy {
    final rationale = widget.rationaleProse;
    final advisory = widget.confidenceAdvisory;
    return (rationale != null && rationale.isNotEmpty) ||
        (advisory != null && advisory.isNotEmpty);
  }

  String? _sessionLine() {
    final title = widget.workoutTitle;
    if (title == null || title.isEmpty) return null;
    final parts = <String>[title];
    if (widget.durationMin != null) parts.add('${widget.durationMin} min');
    if (widget.sessionZone != null && widget.sessionZone!.isNotEmpty) {
      parts.add(widget.sessionZone!);
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // The headline spoken line: locked F1 copy on no-data, else the engine's
    // verbatim state recommendation.
    final headline = widget.insufficientData
        ? kF1NoDataCopy
        : (widget.stateRecommendation ?? '');

    // Nothing the engine has given us to present yet — stay silent rather than
    // invent. (Guards against an all-null transient before first load.)
    if (headline.isEmpty) return const SizedBox.shrink();

    final sessionLine = widget.insufficientData ? null : _sessionLine();
    // Local copies so null-safety is promotion-checked, not `!`-asserted
    // (adversarial review, PR #74).
    final rationale = widget.rationaleProse;
    final advisory = widget.confidenceAdvisory;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MivaltaSpace.x4,
        vertical: MivaltaSpace.x4,
      ),
      decoration: BoxDecoration(
        color: MivaltaColors.surface1,
        borderRadius: BorderRadius.circular(MivaltaRadii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Josi identity row — the presenter, named.
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: MivaltaColors.surface2,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.graphic_eq,
                  size: 16,
                  color: MivaltaColors.primaryGreen,
                ),
              ),
              const SizedBox(width: MivaltaSpace.x2),
              Text(
                'JOSI',
                style: textTheme.labelSmall?.copyWith(
                  color: MivaltaColors.textMuted,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: MivaltaSpace.x3),

          // Headline read (engine prose verbatim, or locked F1 copy).
          Text(
            headline,
            style: textTheme.titleMedium?.copyWith(
              color: MivaltaColors.textPrimary,
              height: 1.35,
            ),
          ),

          // Today's session, presented plainly (engine values).
          if (sessionLine != null) ...[
            const SizedBox(height: MivaltaSpace.x2),
            Text(
              'Today — $sessionLine',
              style: textTheme.bodyMedium?.copyWith(
                color: MivaltaColors.textSecondary,
              ),
            ),
          ],

          // "why?" — progressive disclosure of the engine's reasoning prose.
          // A reveal, never an input. No chat box.
          if (_hasWhy) ...[
            const SizedBox(height: MivaltaSpace.x2),
            InkWell(
              onTap: () => setState(() => _showWhy = !_showWhy),
              borderRadius: BorderRadius.circular(MivaltaRadii.sm),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: MivaltaSpace.x1),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _showWhy ? 'Hide why' : 'Why?',
                      style: textTheme.labelLarge?.copyWith(
                        color: MivaltaColors.primaryGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Icon(
                      _showWhy ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: MivaltaColors.primaryGreen,
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: MivaltaMotion.fast,
              alignment: Alignment.topCenter,
              child: _showWhy
                  ? Padding(
                      padding: const EdgeInsets.only(top: MivaltaSpace.x2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (rationale != null && rationale.isNotEmpty)
                            Text(
                              rationale,
                              style: textTheme.bodyMedium?.copyWith(
                                color: MivaltaColors.textSecondary,
                                height: 1.35,
                              ),
                            ),
                          if (advisory != null && advisory.isNotEmpty) ...[
                            const SizedBox(height: MivaltaSpace.x2),
                            Text(
                              advisory,
                              style: textTheme.bodySmall?.copyWith(
                                color: MivaltaColors.textMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ],
      ),
    );
  }
}

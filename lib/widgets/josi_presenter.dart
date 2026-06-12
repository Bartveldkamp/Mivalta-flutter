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
// confidence_advisory). Josi only sequences and frames them in a spoken
// "autocue" voice — she invents nothing, so she cannot fabricate. On no data
// she presents the LOCKED F1 copy verbatim.
//
// Step 2 (HOME_REDESIGN_BRIEF §4 item 1): Josi is the ONE-LINE VERDICT card —
// one spoken line plus the why-reveal (verdict → reasons → data). The session
// line moved out: today's session is its own card further down the Today
// column, so Josi no longer duplicates it.

import 'package:flutter/material.dart';

import '../copy/axis_labels.dart';
import '../copy/f1.dart';
import '../copy/trust_story.dart';
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
    this.rationaleProse,
    this.contributions = const [],
  });

  /// No observations yet — Josi honestly presents the locked F1 no-data line.
  final bool insufficientData;

  /// Engine `state_widget.state_recommendation` — Josi's one-line verdict.
  final String? stateRecommendation;

  /// Engine `state_widget.confidence_advisory` — honest "still learning you".
  final String? confidenceAdvisory;

  /// Engine `session_widget.rationale_prose` — revealed under "why?".
  final String? rationaleProse;

  /// Engine `readiness_indicator.contributions[]` — the 4-axis reasons,
  /// revealed under "why?" (founder feedback 2026-06-12 item 4: the why-tap
  /// shows WHICH SIGNALS MOVED, same data the detail screen renders).
  /// Each map carries `name`, `raw_score`, `weight`, `weighted` verbatim.
  final List<Map<String, dynamic>> contributions;

  @override
  State<JosiPresenter> createState() => _JosiPresenterState();
}

class _JosiPresenterState extends State<JosiPresenter> {
  bool _showWhy = false;

  bool get _hasWhy {
    // Item 13 (FOUNDER_FEEDBACK_2026-06-12): the F1 no-data line ALWAYS
    // explains itself — its "why" is the fixed trust story (what data is
    // needed, how the model works, the ~28-day calibration arc).
    if (widget.insufficientData) return true;
    final rationale = _revealRationale;
    final advisory = widget.confidenceAdvisory;
    return (rationale != null && rationale.isNotEmpty) ||
        (advisory != null && advisory.isNotEmpty) ||
        _revealContributions.isNotEmpty;
  }

  /// Contributions shown in the reveal. Gated on data sufficiency (feedback
  /// item 1): with no observations the signals are priors, so stay silent.
  List<Map<String, dynamic>> get _revealContributions =>
      widget.insufficientData ? const [] : widget.contributions;

  /// Rationale shown in the reveal. Gated the same way (founder 2026-06-12
  /// no-data redesign): the session rationale is prior-derived prose, so with
  /// no observations Josi does not present it. The confidence advisory stays —
  /// "still learning you" is honest on no data, and Josi is its ONE home
  /// surface.
  String? get _revealRationale =>
      widget.insufficientData ? null : widget.rationaleProse;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // The one spoken line: locked F1 copy on no-data, else the engine's
    // verbatim state recommendation.
    final headline = widget.insufficientData
        ? kF1NoDataCopy
        : (widget.stateRecommendation ?? '');

    // Nothing the engine has given us to present yet — stay silent rather than
    // invent. (Guards against an all-null transient before first load.)
    if (headline.isEmpty) return const SizedBox.shrink();

    // Local copies so null-safety is promotion-checked, not `!`-asserted
    // (adversarial review, PR #74).
    final rationale = _revealRationale;
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

          // The one-line verdict (engine prose verbatim, or locked F1 copy).
          Text(
            headline,
            style: textTheme.titleMedium?.copyWith(
              color: MivaltaColors.textPrimary,
              height: 1.35,
            ),
          ),

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
                      // Ordering rule (verdict → reasons → data): the engine's
                      // explainer prose first, then the 4-axis signal reasons,
                      // then the confidence note. Never raw data first.
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Item 13: on no data the why IS the trust story —
                          // fixed copy (lib/copy/trust_story.dart), in the
                          // founder's order: data needed → how the model
                          // works → how confidence is earned (~28 days).
                          if (widget.insufficientData)
                            _TrustStory(textTheme: textTheme),
                          if (rationale != null && rationale.isNotEmpty)
                            Text(
                              rationale,
                              style: textTheme.bodyMedium?.copyWith(
                                color: MivaltaColors.textSecondary,
                                height: 1.35,
                              ),
                            ),
                          // Which signals moved — the engine's 4-axis
                          // contributions, rendered verbatim (item 4).
                          if (_revealContributions.isNotEmpty) ...[
                            const SizedBox(height: MivaltaSpace.x3),
                            _ContributionRows(
                              contributions: _revealContributions,
                              textTheme: textTheme,
                            ),
                          ],
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

/// Item 13: the trust story shown under the F1 line's "why" — three fixed
/// paragraphs (lib/copy/trust_story.dart) in the founder's order. Pure copy,
/// nothing engine-derived, so it is honest even before the first observation.
class _TrustStory extends StatelessWidget {
  const _TrustStory({required this.textTheme});

  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final style = textTheme.bodyMedium?.copyWith(
      color: MivaltaColors.textSecondary,
      height: 1.35,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(kTrustStoryWhatData, style: style),
        const SizedBox(height: MivaltaSpace.x2),
        Text(kTrustStoryHowItWorks, style: style),
        const SizedBox(height: MivaltaSpace.x2),
        Text(kTrustStoryCalibration, style: style),
      ],
    );
  }
}

/// Compact "which signals moved" rows for the why-reveal — a lighter cut of
/// the detail screen's axis breakdown. Display-only: names humanized at the
/// label layer, values verbatim; bars scaled by the engine's own `weighted`
/// values (presentation normalization, no derived numbers shown).
class _ContributionRows extends StatelessWidget {
  const _ContributionRows({
    required this.contributions,
    required this.textTheme,
  });

  final List<Map<String, dynamic>> contributions;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    // Scale bars against the largest weighted contribution.
    double maxWeighted = 0;
    for (final c in contributions) {
      final w = (c['weighted'] as num?)?.toDouble() ?? 0;
      if (w > maxWeighted) maxWeighted = w;
    }
    if (maxWeighted <= 0) maxWeighted = 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final c in contributions) ...[
          Row(
            children: [
              Expanded(
                child: Text(
                  humanizeAxisName(c['name']?.toString()),
                  style: textTheme.bodySmall?.copyWith(
                    color: MivaltaColors.textSecondary,
                  ),
                ),
              ),
              if (c['raw_score'] is num)
                Text(
                  '${(c['raw_score'] as num).round()}',
                  style: textTheme.bodySmall?.copyWith(
                    color: MivaltaColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(MivaltaRadii.sm),
            child: LinearProgressIndicator(
              value: ((c['weighted'] as num?)?.toDouble() ?? 0) / maxWeighted,
              minHeight: 3,
              backgroundColor: MivaltaColors.surface2,
              color: MivaltaColors.primaryGreen,
            ),
          ),
          if (c != contributions.last) const SizedBox(height: MivaltaSpace.x2),
        ],
      ],
    );
  }
}

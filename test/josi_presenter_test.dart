// Tests for JosiPresenter — the autocue presenter on the home.
//
// Josi is a PRESENTER, not a chat. These tests pin that contract: she renders
// engine prose verbatim, reveals the engine's "why" on tap (no input box), and
// honestly presents the LOCKED F1 copy when there's no data.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mivalta_flutter/copy/f1.dart';
import 'package:mivalta_flutter/copy/trust_story.dart';
import 'package:mivalta_flutter/models/realized_line.dart';
import 'package:mivalta_flutter/theme/tokens.dart';
import 'package:mivalta_flutter/widgets/josi_presenter.dart';

Future<void> _pump(WidgetTester tester, Widget child) =>
    tester.pumpWidget(MaterialApp(
      theme: mivaltaDarkTheme(),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ));

void main() {
  group('JosiPresenter', () {
    testWidgets('presents the engine verdict as ONE line — no session line '
        '(step 2: session is its own card)', (tester) async {
      await _pump(
        tester,
        const JosiPresenter(
          insufficientData: false,
          stateRecommendation: 'Adapting well to the week — keep the rhythm.',
          rationaleProse: 'A clean stimulus while you are fresh.',
        ),
      );

      expect(find.text('JOSI'), findsOneWidget);
      // The one-line verdict — engine prose, verbatim.
      expect(find.text('Adapting well to the week — keep the rhythm.'),
          findsOneWidget);
      // No session line in Josi's card (HOME_REDESIGN_BRIEF §4 item 1).
      expect(find.textContaining('Today —'), findsNothing);
    });

    testWidgets('"why?" reveals the engine rationale on tap (no input box)', (tester) async {
      await _pump(
        tester,
        const JosiPresenter(
          insufficientData: false,
          stateRecommendation: 'Productive — good day to build.',
          rationaleProse: 'A clean stimulus while you are fresh.',
        ),
      );

      // No text input anywhere — Josi is a presenter, not a chat.
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(TextFormField), findsNothing);

      // Rationale hidden until asked.
      expect(find.text('A clean stimulus while you are fresh.'), findsNothing);
      expect(find.text('Why?'), findsOneWidget);

      await tester.tap(find.text('Why?'));
      await tester.pumpAndSettle();

      expect(find.text('A clean stimulus while you are fresh.'), findsOneWidget);
      expect(find.text('Hide why'), findsOneWidget);
    });

    testWidgets('no data → presents the LOCKED F1 copy, no session line', (tester) async {
      await _pump(
        tester,
        const JosiPresenter(
          insufficientData: true,
          // Even if upstream passes stale fields, no-data wins honestly.
          stateRecommendation: 'should not be shown',
        ),
      );

      expect(find.text(kF1NoDataCopy), findsOneWidget);
      expect(find.textContaining('Today —'), findsNothing);
      expect(find.text('should not be shown'), findsNothing);
    });

    testWidgets('no rationale/advisory → no "why?" affordance', (tester) async {
      await _pump(
        tester,
        const JosiPresenter(
          insufficientData: false,
          stateRecommendation: 'Recovered — fully charged.',
        ),
      );

      expect(find.text('Recovered — fully charged.'), findsOneWidget);
      expect(find.text('Why?'), findsNothing);
    });

    testWidgets('nothing to present yet → renders nothing (no fabrication)', (tester) async {
      await _pump(tester, const JosiPresenter(insufficientData: false));
      expect(find.byType(JosiPresenter), findsOneWidget);
      expect(find.text('JOSI'), findsNothing);
    });
  });

  // Item 4 (FOUNDER_FEEDBACK_2026-06-12): the why-tap shows WHICH SIGNALS
  // MOVED — the engine's 4-axis contributions, humanized at the label layer,
  // values verbatim. Ordering rule (A4): rationale → axis reasons → advisory.
  group('JosiPresenter why-reveal contributions', () {
    const contributions = [
      {'name': 'hmm_posteriors', 'raw_score': 72, 'weight': 0.4, 'weighted': 28.8},
      {'name': 'physio_zscore', 'raw_score': 55, 'weight': 0.3, 'weighted': 16.5},
    ];

    testWidgets('"why?" reveals humanized axis names + verbatim raw scores', (tester) async {
      await _pump(
        tester,
        const JosiPresenter(
          insufficientData: false,
          stateRecommendation: 'Productive — good day to build.',
          rationaleProse: 'Fatigue is clearing.',
          confidenceAdvisory: 'Still learning you.',
          contributions: contributions,
        ),
      );

      // Hidden until asked.
      expect(find.text('Fatigue model'), findsNothing);

      await tester.tap(find.text('Why?'));
      await tester.pumpAndSettle();

      // Humanized names (never raw engine keys), scores verbatim.
      expect(find.text('Fatigue model'), findsOneWidget);
      expect(find.text('Body signals'), findsOneWidget);
      expect(find.text('hmm_posteriors'), findsNothing);
      expect(find.text('72'), findsOneWidget);
      expect(find.text('55'), findsOneWidget);

      // A4 ordering: rationale (verdict prose) above the axis reasons,
      // advisory (data/confidence note) last.
      final rationaleY = tester.getTopLeft(find.text('Fatigue is clearing.')).dy;
      final axisY = tester.getTopLeft(find.text('Fatigue model')).dy;
      final advisoryY = tester.getTopLeft(find.text('Still learning you.')).dy;
      expect(rationaleY, lessThan(axisY));
      expect(axisY, lessThan(advisoryY));
    });

    testWidgets('contributions alone enable the "why?" affordance', (tester) async {
      await _pump(
        tester,
        const JosiPresenter(
          insufficientData: false,
          stateRecommendation: 'Productive — good day to build.',
          contributions: contributions,
        ),
      );
      expect(find.text('Why?'), findsOneWidget);
    });

    testWidgets('no data → contributions stay silent (priors, not signals)', (tester) async {
      await _pump(
        tester,
        const JosiPresenter(
          insufficientData: true,
          contributions: contributions,
        ),
      );
      // F1 honest no-data presentation. The "Why?" now exists (item 13 trust
      // story) but the prior-based contributions stay silent — no axis rows,
      // no scores (feedback item 1: silence over fabricated state).
      await tester.tap(find.text('Why?'));
      await tester.pumpAndSettle();
      expect(find.text('Fatigue model'), findsNothing);
      expect(find.text('72'), findsNothing);
      expect(find.text('hmm_posteriors'), findsNothing);
    });
  });

  // Item 13 (FOUNDER_FEEDBACK_2026-06-12): the "why" under the F1 line tells
  // the trust story — what data is needed, how the model works, how it earns
  // confidence over ~28 days. Fixed copy, pinned verbatim.
  group('JosiPresenter trust story (item 13)', () {
    testWidgets('F1 line always offers "Why?"; tap reveals the three trust '
        'paragraphs verbatim, in founder order', (tester) async {
      await _pump(tester, const JosiPresenter(insufficientData: true));

      expect(find.text(kF1NoDataCopy), findsOneWidget);
      expect(find.text('Why?'), findsOneWidget);
      // Hidden until asked.
      expect(find.text(kTrustStoryWhatData), findsNothing);

      await tester.tap(find.text('Why?'));
      await tester.pumpAndSettle();

      expect(find.text(kTrustStoryWhatData), findsOneWidget);
      expect(find.text(kTrustStoryHowItWorks), findsOneWidget);
      expect(find.text(kTrustStoryCalibration), findsOneWidget);

      // Founder order: data needed → how it works → calibration arc.
      final dataY = tester.getTopLeft(find.text(kTrustStoryWhatData)).dy;
      final howY = tester.getTopLeft(find.text(kTrustStoryHowItWorks)).dy;
      final calY = tester.getTopLeft(find.text(kTrustStoryCalibration)).dy;
      expect(dataY, lessThan(howY));
      expect(howY, lessThan(calY));
    });

    testWidgets('advisory still renders once, BELOW the trust story',
        (tester) async {
      await _pump(
        tester,
        const JosiPresenter(
          insufficientData: true,
          confidenceAdvisory: 'Confidence is low — still learning you.',
        ),
      );
      await tester.tap(find.text('Why?'));
      await tester.pumpAndSettle();

      expect(
        find.text('Confidence is low — still learning you.'),
        findsOneWidget,
      );
      final calY = tester.getTopLeft(find.text(kTrustStoryCalibration)).dy;
      final advisoryY = tester
          .getTopLeft(find.text('Confidence is low — still learning you.'))
          .dy;
      expect(calY, lessThan(advisoryY));
    });

    testWidgets('sufficient data → no trust story in the reveal',
        (tester) async {
      await _pump(
        tester,
        const JosiPresenter(
          insufficientData: false,
          stateRecommendation: 'Productive — good day to build.',
          rationaleProse: 'Fatigue is clearing.',
        ),
      );
      await tester.tap(find.text('Why?'));
      await tester.pumpAndSettle();

      expect(find.text('Fatigue is clearing.'), findsOneWidget);
      expect(find.text(kTrustStoryWhatData), findsNothing);
      expect(find.text(kTrustStoryHowItWorks), findsNothing);
      expect(find.text(kTrustStoryCalibration), findsNothing);
    });

    test('copy says it PLAINLY (round 3-final item 22): ~28 days of your '
        'data builds a personal profile — no jargon, no raw identifiers', () {
      // The calibration arc names the ~28-day window.
      expect(kTrustStoryCalibration.contains('28 days'), isTrue);
      // The framing is the personal profile of level + status.
      expect(kTrustStoryHowItWorks.contains('personal profile'), isTrue);
      // No raw engine identifiers or jargon leak into user-facing copy.
      const all = kTrustStoryWhatData +
          kTrustStoryHowItWorks +
          kTrustStoryCalibration;
      expect(all.contains('hmm'), isFalse);
      expect(all.contains('zscore'), isFalse);
      expect(all.contains('_'), isFalse);
      expect(all.toLowerCase().contains('model'), isFalse,
          reason: 'founder: simple human words — no model talk');
      expect(all.toLowerCase().contains('calibrat'), isFalse,
          reason: 'founder: simple human words — no calibration jargon');
    });
  });

  // Item 2 (the Mac round-trip): the deterministic, firewall-validated Josi line
  // from the FFI seam. When a RealizedLine is present its `text` is the headline
  // and its `safety` cautions render VERBATIM and ALWAYS (never branched on,
  // never under "why?"). Null → fall back to the state-recommendation line.
  group('JosiPresenter realized line (FFI seam)', () {
    testWidgets('renders realized text as headline + safety verbatim, always '
        '(no tap)', (tester) async {
      await _pump(
        tester,
        const JosiPresenter(
          insufficientData: false,
          realizedLine: RealizedLine(
            text: "You're recovered today — readiness is sitting comfortably.",
            safety: ['Focus on active recovery today.'],
            degraded: false,
          ),
          // Present, but the realized line must win.
          stateRecommendation: 'fallback should not show',
        ),
      );

      expect(
        find.text("You're recovered today — readiness is sitting comfortably."),
        findsOneWidget,
      );
      // Safety caution rendered verbatim WITHOUT opening "why?".
      expect(find.text('Focus on active recovery today.'), findsOneWidget);
      // Realized text wins over the fallback state recommendation.
      expect(find.text('fallback should not show'), findsNothing);
    });

    testWidgets('null realized line → falls back to state recommendation',
        (tester) async {
      await _pump(
        tester,
        const JosiPresenter(
          insufficientData: false,
          stateRecommendation: 'Productive — good day to build.',
        ),
      );
      expect(find.text('Productive — good day to build.'), findsOneWidget);
    });

    testWidgets('no data wins → realized text + safety are not shown',
        (tester) async {
      await _pump(
        tester,
        const JosiPresenter(
          insufficientData: true,
          realizedLine: RealizedLine(
            text: 'should not show',
            safety: ['should not show either'],
            degraded: false,
          ),
        ),
      );
      expect(find.text(kF1NoDataCopy), findsOneWidget);
      expect(find.text('should not show'), findsNothing);
      expect(find.text('should not show either'), findsNothing);
    });
  });
}

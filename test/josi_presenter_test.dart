// Tests for JosiPresenter — the autocue presenter on the home.
//
// Josi is a PRESENTER, not a chat. These tests pin that contract: she renders
// engine prose verbatim, reveals the engine's "why" on tap (no input box), and
// honestly presents the LOCKED F1 copy when there's no data.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mivalta_flutter/copy/f1.dart';
import 'package:mivalta_flutter/theme/tokens.dart';
import 'package:mivalta_flutter/widgets/josi_presenter.dart';

Future<void> _pump(WidgetTester tester, Widget child) =>
    tester.pumpWidget(MaterialApp(
      theme: mivaltaDarkTheme(),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ));

void main() {
  group('JosiPresenter', () {
    testWidgets('presents engine state read + session line verbatim', (tester) async {
      await _pump(
        tester,
        const JosiPresenter(
          insufficientData: false,
          stateRecommendation: 'Adapting well to the week — keep the rhythm.',
          workoutTitle: 'Sweet-spot intervals',
          durationMin: 50,
          sessionZone: 'Z4',
          rationaleProse: 'A clean stimulus while you are fresh.',
        ),
      );

      expect(find.text('JOSI'), findsOneWidget);
      // Headline read — engine prose, verbatim.
      expect(find.text('Adapting well to the week — keep the rhythm.'),
          findsOneWidget);
      // Session line — engine values, presented plainly.
      expect(find.text('Today — Sweet-spot intervals · 50 min · Z4'),
          findsOneWidget);
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
          workoutTitle: 'should not be shown',
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
      // F1 honest no-data presentation; no why affordance from prior-based
      // contributions (feedback item 1: silence over fabricated state).
      expect(find.text('Why?'), findsNothing);
      expect(find.text('Fatigue model'), findsNothing);
    });
  });
}

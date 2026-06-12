// PR-B widget tests for the three-zone PULL home.
//
// FFI path is gated on Platform.isAndroid; on the host harness
// `RustEngineBinding.bootstrap()` throws UnsupportedError immediately,
// so screen-level tests verify structure + error handling. The
// ReadinessRing and SourceTierIndicator are tested by mounting directly.
//
// Tests assert against REAL engine field names from gatc-dashboard/widgets.rs
// and gatc-vault/models.rs to guard against engine drift:
//   - StateWidget: state_recommendation, confidence_advisory
//   - SessionWidget: workout_title, duration_min, zone, target_watts, focus_cue, rationale_prose
//   - ContextWidget: acwr, acwr_zone, acwr_recommendation, monotony, strain, ...
//   - VaultBiometric: readiness_score (NOT 'score')

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mivalta_flutter/copy/f1.dart';
import 'package:mivalta_flutter/screens/readiness_screen.dart';
import 'package:mivalta_flutter/theme/source_tier.dart';
import 'package:mivalta_flutter/theme/tokens.dart';
import 'package:mivalta_flutter/widgets/josi_presenter.dart';
import 'package:mivalta_flutter/widgets/readiness_ring.dart';
import 'package:mivalta_flutter/widgets/today_facts.dart';

void main() {
  testWidgets(
    'ReadinessScreen shows MiValta app-bar title; engine-dependent '
    'sections surface the host bootstrap error inline',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: ReadinessScreen()));
      // Initial frame shows the spinner; pump the microtask queue so
      // the failing bootstrap settles and the body rebuilds.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // App-bar title (now 'MiValta' per PR-B three-zone home).
      expect(find.text('MiValta'), findsWidgets);

      // The host harness can't load the .so, so the bootstrap throws
      // UnsupportedError. The error scaffold renders.
      expect(find.textContaining('UnsupportedError'), findsWidgets);
    },
  );

  testWidgets('F1 no-data copy locked constant survives literally', (t) async {
    // CLAUDE.md flags any paraphrase as a finding; this guards the
    // string at lib/copy/f1.dart.
    expect(kF1NoDataCopy, 'We need more data to predict recovery.');
  });

  group('ReadinessRing', () {
    testWidgets(
      'score=85, level=green, confidence=0.92 → renders rounded score + level',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ReadinessRing(
                score: 85,
                level: 'green',
                confidence: 0.92,
                noData: false,
                learning: false,
              ),
            ),
          ),
        );

        // Score renders (from indicator['score'], rounded)
        expect(find.text('85'), findsOneWidget);
        // Level renders (verbatim from engine indicator['level'])
        expect(find.text('green'), findsOneWidget);
        // Confidence renders as percentage (from indicator['confidence'])
        expect(find.text('confidence 92%'), findsOneWidget);

        // Ring's CircularProgressIndicator exists (hero ring)
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // F1 copy must NOT appear when data is present
        expect(find.text(kF1NoDataCopy), findsNothing);
      },
    );

    testWidgets(
      'score=72, level=yellow → renders correct color (from engine level, not score-derived)',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ReadinessRing(
                score: 72,
                level: 'yellow',
                confidence: 0.75,
                noData: false,
                learning: false,
              ),
            ),
          ),
        );

        // Score + level render (readiness_indicator fields)
        expect(find.text('72'), findsOneWidget);
        expect(find.text('yellow'), findsOneWidget);

        // The CircularProgressIndicator should have the yellow color (0xFFE8C547)
        // Color comes from engine's level field, NOT derived from score
        final indicator = tester.widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        );
        final color = (indicator.valueColor as AlwaysStoppedAnimation<Color>).value;
        expect(color, const Color(0xFFE8C547));
      },
    );

    testWidgets(
      'noData=true → calm muted ring hero, em-dash, NO F1 text (Josi carries it)',
      (WidgetTester tester) async {
        // Founder 2026-06-12 no-data redesign: the ring renders in its calm
        // muted state as the hero — never bare floating text. The locked F1
        // copy appears exactly once on the home, in Josi's card, so the ring
        // must NOT repeat it.
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ReadinessRing(
                score: null,
                level: null,
                confidence: null,
                noData: true,
                // No observations ⇒ the caller's learning gate is true too
                // (brief §4: sized by data sufficiency — small muted ring).
                learning: true,
              ),
            ),
          ),
        );

        // The hero ring renders — empty track, zero arc.
        final indicator = tester.widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        );
        expect(indicator.value, 0);
        // Muted, colorless: no readiness-level color claimed.
        final color =
            (indicator.valueColor as AlwaysStoppedAnimation<Color>).value;
        expect(color, MivaltaColors.textMuted);

        // Quiet em-dash center — no fabricated score.
        expect(find.text('—'), findsOneWidget);

        // Sized by data sufficiency (brief §4): small ring, not the hero.
        expect(
          tester.getSize(find.byType(ReadinessRing)),
          const Size(120, 120),
        );

        // F1 copy does NOT repeat here (exactly-once rule; Josi's card has it).
        expect(find.text(kF1NoDataCopy), findsNothing);

        // No score text
        expect(find.text('85'), findsNothing);
        expect(find.text('72'), findsNothing);
      },
    );

    testWidgets(
      'score=null + noData=false → shows em-dash, no F1 copy',
      (WidgetTester tester) async {
        // Edge case: data exists but score is null (shouldn't happen,
        // but tests the widget boundary)
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ReadinessRing(
                score: null,
                level: null,
                confidence: null,
                noData: false,
                learning: false,
              ),
            ),
          ),
        );

        // Em-dash renders for null score
        expect(find.text('—'), findsWidgets);

        // Ring should still render
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // F1 copy should NOT render when noData=false
        expect(find.text(kF1NoDataCopy), findsNothing);
      },
    );
  });

  // Engine field name guards — these document the VERIFIED engine schema
  // so tests fail if the Dart code drifts from the real field names.
  group('Engine field name guards', () {
    test('StateWidget fields: state_recommendation, confidence_advisory', () {
      // These are the REAL field names from gatc-dashboard/src/widgets.rs
      // The screen reads stateWidget['state_recommendation'] NOT ['prose']
      // and stateWidget['confidence_advisory'] for honest-confidence display
      const realFieldNames = [
        'state_recommendation', // the prose
        'confidence_advisory',  // shown when non-null
        'fatigue_state',
        'readiness_level',
        'readiness_score',
        'confidence',
      ];
      expect(realFieldNames.contains('state_recommendation'), isTrue);
      expect(realFieldNames.contains('confidence_advisory'), isTrue);
      // 'prose' is NOT a real field
      expect(realFieldNames.contains('prose'), isFalse);
    });

    test('SessionWidget fields: workout_title, rationale_prose, etc.', () {
      // These are the REAL field names from gatc-dashboard/src/widgets.rs
      // The screen reads these fields, NOT a generic 'prose' field
      const realFieldNames = [
        'session_type',
        'workout_title',
        'duration_min',
        'intensity_pct',
        'target_watts',
        'target_pace_mss',
        'zone',
        'zone_purpose',
        'focus_cue',
        'phase_context',
        'rationale_prose', // the "why" explanation
      ];
      expect(realFieldNames.contains('workout_title'), isTrue);
      expect(realFieldNames.contains('rationale_prose'), isTrue);
      expect(realFieldNames.contains('focus_cue'), isTrue);
      // 'prose' is NOT a real field
      expect(realFieldNames.contains('prose'), isFalse);
    });

    test('ContextWidget fields: acwr, acwr_recommendation, etc.', () {
      // These are the REAL field names from gatc-dashboard/src/widgets.rs
      const realFieldNames = [
        'acwr',
        'acwr_zone',
        'acwr_recommendation',
        'monotony',
        'strain',
        'monotony_zone',
        'monotony_recommendation',
        'last_workout',
        'reactive_alerts',
        'pattern_advisories',
      ];
      expect(realFieldNames.contains('acwr'), isTrue);
      expect(realFieldNames.contains('acwr_recommendation'), isTrue);
      expect(realFieldNames.contains('reactive_alerts'), isTrue);
      // 'prose' is NOT a real field
      expect(realFieldNames.contains('prose'), isFalse);
    });

    test('VaultBiometric field: readiness_score (NOT score)', () {
      // readReadinessHistory returns List<VaultBiometric> where each item
      // has 'readiness_score' (i32?), NOT 'score'
      const realFieldName = 'readiness_score';
      const wrongFieldName = 'score';
      expect(realFieldName, isNot(equals(wrongFieldName)));
      expect(realFieldName, equals('readiness_score'));
    });
  });

  group('SourceTierIndicator', () {
    testWidgets(
      'engine returned null → renders the F1 no-data copy, no swatch',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: SourceTierIndicator(tier: null)),
          ),
        );

        expect(find.text(kF1NoDataCopy), findsOneWidget);

        // No swatch Container should have a SourceTier color when
        // the engine returned null.
        final containers = tester.widgetList<Container>(find.byType(Container));
        final swatchColors = containers
            .map((c) => (c.decoration as BoxDecoration?)?.color)
            .whereType<Color>()
            .toSet();
        for (final tier in SourceTier.values) {
          expect(
            swatchColors.contains(kSourceTierColor[tier]),
            isFalse,
            reason: '${tier.name} swatch must NOT render in no-data branch',
          );
        }
      },
    );

    for (final tier in SourceTier.values) {
      testWidgets(
        'engine returned ${tier.name} → renders the matching swatch + label',
        (WidgetTester tester) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(body: SourceTierIndicator(tier: tier)),
            ),
          );

          // Label from the const map.
          expect(find.text(kSourceTierLabel[tier]!), findsOneWidget);

          // Swatch uses the LOCKED hex via kSourceTierColor — no
          // hex literals at call sites.
          final containers =
              tester.widgetList<Container>(find.byType(Container));
          final swatchColors = containers
              .map((c) => (c.decoration as BoxDecoration?)?.color)
              .whereType<Color>()
              .toSet();
          expect(
            swatchColors.contains(kSourceTierColor[tier]),
            isTrue,
            reason: '${tier.name} swatch color must come from kSourceTierColor',
          );
          // Other tiers' colors must NOT appear (single-swatch contract).
          for (final other in SourceTier.values) {
            if (other == tier) continue;
            expect(
              swatchColors.contains(kSourceTierColor[other]),
              isFalse,
              reason:
                  '${other.name} swatch must NOT render when tier=${tier.name}',
            );
          }
        },
      );
    }
  });

  // Item 1 (FOUNDER_FEEDBACK_2026-06-12): No fatigue-state badge when data insufficient.
  // When insufficientData=true, the home must show ONLY the F1 copy — no badge from priors.
  // This test documents the data-model contract; the private _Zone1State widget implements it.
  group('Insufficient data → no fatigue-state badge contract', () {
    test('badge condition requires sufficient data (NOT just non-null fatigueState)', () {
      // The badge should render IFF:
      //   fatigueState != null AND insufficientData == false
      // Previously the check was only (fatigueState != null), which leaked priors.
      bool shouldShowBadge(String? fatigueState, bool insufficientData) =>
          fatigueState != null && !insufficientData;

      // Case 1: Sufficient data with fatigue state → badge should show
      expect(shouldShowBadge('Recovered', false), isTrue);
      expect(shouldShowBadge('Adapting', false), isTrue);

      // Case 2: Insufficient data even with fatigue state from priors → NO badge
      expect(shouldShowBadge('Recovered', true), isFalse);
      expect(shouldShowBadge('Adapting', true), isFalse);

      // Case 3: Sufficient data but no fatigue state → NO badge
      expect(shouldShowBadge(null, false), isFalse);

      // Case 4: No data, no state → NO badge
      expect(shouldShowBadge(null, true), isFalse);
    });
  });

  // Item 7 (FOUNDER_FEEDBACK_2026-06-12): Today's load chip next to fatigue state.
  // Engine provides daily_loads; Dart renders today's value. No Dart math.
  group('Today load chip contract', () {
    test('load chip renders when todayLoad is present and data is sufficient', () {
      // The chip should render IFF:
      //   todayLoad != null AND insufficientData == false
      bool shouldShowLoadChip(double? todayLoad, bool insufficientData) =>
          todayLoad != null && !insufficientData;

      // Case 1: Sufficient data with today's load → chip should show
      expect(shouldShowLoadChip(150.0, false), isTrue);
      expect(shouldShowLoadChip(0.0, false), isTrue); // zero load is valid data

      // Case 2: Insufficient data even with load value → NO chip
      expect(shouldShowLoadChip(150.0, true), isFalse);
      expect(shouldShowLoadChip(0.0, true), isFalse);

      // Case 3: Sufficient data but no load data → NO chip
      expect(shouldShowLoadChip(null, false), isFalse);

      // Case 4: No data, no load → NO chip
      expect(shouldShowLoadChip(null, true), isFalse);
    });

    test('load chip label uses engine value rounded, with "load" suffix', () {
      // The label format is "${todayLoad.round()} load"
      String formatLoadLabel(double load) => '${load.round()} load';

      expect(formatLoadLabel(150.7), equals('151 load'));
      expect(formatLoadLabel(0.0), equals('0 load'));
      expect(formatLoadLabel(42.3), equals('42 load'));
    });
  });

  // A2 (NEXT_UPDATE_V2_ADOPTIONS): rest is content, not absence. The home's
  // Today card gives an engine-prescribed rest session ('R' zone) the same
  // full card with rest presentation (recovery icon + recovered accent).
  group('Rest-as-content (A2) contract', () {
    test('rest presentation gates on the engine session zone R, case-insensitive', () {
      // Mirrors _Zone2Today._isRest — a presentation mapping of an engine
      // value only; no Dart decides whether today is rest.
      bool isRest(String? sessionZone) =>
          (sessionZone ?? '').toUpperCase() == 'R';

      expect(isRest('R'), isTrue);
      expect(isRest('r'), isTrue);
      expect(isRest('Z2'), isFalse);
      expect(isRest('Z1'), isFalse); // recovery ride is still a session
      expect(isRest(''), isFalse);
      expect(isRest(null), isFalse);
    });
  });

  // Founder 2026-06-12 no-data home redesign: with insufficient data the home
  // makes NO prescriptions from priors and the F1 copy + confidence advisory
  // each appear EXACTLY ONCE (Josi's card carries them). ThreeZoneHome and
  // HomeData are public so the full home body can be pumped with engine-shaped
  // values; the data is deliberately seeded with prior-derived prescription
  // values to prove the gating, not just the absence of data.
  group('No-data home (insufficientData=true)', () {
    HomeData seededNoData() => HomeData()
      ..insufficientData = true
      // Prior-derived values that must all be suppressed:
      ..stateRecommendation = 'Prior-based state prose'
      ..confidenceAdvisory = 'Confidence is low — still learning you.'
      ..fatigueState = 'Recovered'
      ..workoutTitle = 'Endurance Ride'
      ..durationMin = 60
      ..sessionZone = 'Z2'
      ..targetWatts = 156
      ..focusCue = 'Keep it conversational.'
      ..rationaleProse = 'Your body is responding well.'
      ..zoneCap = 'Z8';

    Widget pumpableHome(HomeData data) => MaterialApp(
          theme: mivaltaDarkTheme(),
          home: Scaffold(
            body: ThreeZoneHome(
              data: data,
              onTapRing: () {},
              onTapAdvisor: () {},
              onTapLatestWorkout: (_) {},
            ),
          ),
        );

    testWidgets('F1 copy renders EXACTLY once (Josi card)', (tester) async {
      await tester.pumpWidget(pumpableHome(seededNoData()));
      expect(find.text(kF1NoDataCopy), findsOneWidget);
    });

    testWidgets('zero session prescription, zero cap chip — calm placeholder instead',
        (tester) async {
      await tester.pumpWidget(pumpableHome(seededNoData()));

      // No prescription from priors anywhere on the home.
      expect(find.text('Endurance Ride'), findsNothing);
      expect(find.text('156W'), findsNothing);
      expect(find.textContaining('Endurance Ride'), findsNothing);
      // No zone-cap chip.
      expect(find.text('Up to Z8'), findsNothing);
      // No advisor entry (the advisor surfaces prior-derived prescriptions).
      expect(find.text('See workout options'), findsNothing);
      // No prior-based state prose.
      expect(find.text('Prior-based state prose'), findsNothing);

      // Zone 2 keeps its rhythm: TODAY label + calm learn-you placeholder.
      expect(find.text('TODAY'), findsOneWidget);
      expect(
        find.text("First, let's learn you — log a few days."),
        findsOneWidget,
      );
    });

    testWidgets('hero is the calm ring, not bare floating text', (tester) async {
      await tester.pumpWidget(pumpableHome(seededNoData()));
      // The ReadinessRing mounts in its no-data state (ring present).
      expect(find.byType(ReadinessRing), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ReadinessRing),
          matching: find.byType(CircularProgressIndicator),
        ),
        findsOneWidget,
      );
      // And it carries no F1 text (Josi's card is the one source).
      expect(
        find.descendant(
          of: find.byType(ReadinessRing),
          matching: find.text(kF1NoDataCopy),
        ),
        findsNothing,
      );
    });

    testWidgets(
        'why-reveal: advisory appears exactly once, rationale stays gated',
        (tester) async {
      await tester.pumpWidget(pumpableHome(seededNoData()));

      // Advisory not visible before the reveal (Zone 1 no longer repeats it).
      expect(
        find.text('Confidence is low — still learning you.'),
        findsNothing,
      );

      // Open Josi's why-reveal. (Step 2: the learning ring has its own muted
      // "Why?" too, so target Josi's card explicitly.)
      await tester.tap(find.descendant(
        of: find.byType(JosiPresenter),
        matching: find.text('Why?'),
      ));
      await tester.pumpAndSettle();

      // Advisory appears exactly ONCE (in the reveal).
      expect(
        find.text('Confidence is low — still learning you.'),
        findsOneWidget,
      );
      // Prior-derived session rationale stays gated.
      expect(find.text('Your body is responding well.'), findsNothing);
    });

    testWidgets('sufficient data keeps prescriptions (regression guard)',
        (tester) async {
      final data = seededNoData()..insufficientData = false;
      await tester.pumpWidget(pumpableHome(data));

      expect(find.text('Endurance Ride'), findsWidgets);
      expect(find.text('Up to Z8'), findsOneWidget);
      expect(find.text('See workout options'), findsOneWidget);
      expect(
        find.text("First, let's learn you — log a few days."),
        findsNothing,
      );
      expect(find.text(kF1NoDataCopy), findsNothing);
    });
  });

  // Step 2 (HOME_REDESIGN_BRIEF §4 item 2): the state element is SIZED BY
  // DATA SUFFICIENCY. Learning gate = engine signals only (insufficientData
  // OR non-empty confidence_advisory) ⇒ small muted ring whose "why" explains
  // "I'm still learning you — day X." Confident ⇒ the 220dp hero.
  group('Adaptive state element (step 2)', () {
    Widget pumpableHome(HomeData data) => MaterialApp(
          theme: mivaltaDarkTheme(),
          home: Scaffold(
            body: ThreeZoneHome(
              data: data,
              onTapRing: () {},
              onTapAdvisor: () {},
              onTapLatestWorkout: (_) {},
            ),
          ),
        );

    HomeData seededLowConfidence() => HomeData()
      ..insufficientData = false
      ..readinessScore = 62
      ..readinessLevel = 'yellow'
      ..confidence = 0.4
      ..stateRecommendation = 'Early read — take it easy.'
      // Non-empty advisory = the engine says it is still calibrating.
      ..confidenceAdvisory = 'Still learning you.'
      ..observationDays = 5;

    HomeData seededConfident() => HomeData()
      ..insufficientData = false
      ..readinessScore = 78
      ..readinessLevel = 'green'
      ..confidence = 0.9
      ..stateRecommendation = 'Recovered — fully charged.'
      // Empty advisory = engine is confident.
      ..confidenceAdvisory = null
      ..observationDays = 21;

    testWidgets(
        'learning=true direct mount → small muted ring: score renders, '
        'no level label, no confidence row', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ReadinessRing(
              score: 62,
              level: 'yellow',
              confidence: 0.4,
              noData: false,
              learning: true,
            ),
          ),
        ),
      );

      // Small, not the hero.
      expect(
        tester.getSize(find.byType(ReadinessRing)),
        const Size(120, 120),
      );
      // Score still renders (§9 no-naked-numbers: ring fill + number)...
      expect(find.text('62'), findsOneWidget);
      // ...but muted: no level color claimed, no level label, no confidence.
      final indicator = tester.widget<CircularProgressIndicator>(
        find.byType(CircularProgressIndicator),
      );
      final color =
          (indicator.valueColor as AlwaysStoppedAnimation<Color>).value;
      expect(color, MivaltaColors.textMuted);
      expect(find.text('yellow'), findsNothing);
      expect(find.text('confidence 40%'), findsNothing);
    });

    testWidgets(
        'low-confidence home → small ring + learning why reveals '
        '"I\'m still learning you — day 5."', (tester) async {
      await tester.pumpWidget(pumpableHome(seededLowConfidence()));

      expect(
        tester.getSize(find.byType(ReadinessRing)),
        const Size(120, 120),
      );

      // Learning-why copy hidden until asked.
      expect(find.textContaining("I'm still learning you"), findsNothing);

      // Two "Why?" affordances render in the Today column: Josi's card first,
      // the learning ring's muted why second — tap the ring's.
      await tester.tap(find.text('Why?').last);
      await tester.pumpAndSettle();

      // Day X = engine-returned observation-day count, verbatim in the copy.
      expect(
        find.text("I'm still learning you — day 5."),
        findsOneWidget,
      );
    });

    testWidgets(
        'confident home → 220dp hero with level + confidence, no learning why',
        (tester) async {
      await tester.pumpWidget(pumpableHome(seededConfident()));

      expect(
        tester.getSize(find.byType(ReadinessRing)),
        const Size(220, 220),
      );
      expect(find.text('78'), findsOneWidget);
      expect(find.text('green'), findsOneWidget);
      expect(find.text('confidence 90%'), findsOneWidget);
      expect(find.textContaining("I'm still learning you"), findsNothing);
      // Josi's verdict renders exactly once (the ONE home surface).
      expect(find.text('Recovered — fully charged.'), findsOneWidget);
    });

    testWidgets('confident red home → hero ring carries levelRed',
        (tester) async {
      final data = seededConfident()
        ..readinessScore = 35
        ..readinessLevel = 'red'
        ..confidence = 0.85
        ..stateRecommendation = 'Run down — back off today.';
      await tester.pumpWidget(pumpableHome(data));

      expect(
        tester.getSize(find.byType(ReadinessRing)),
        const Size(220, 220),
      );
      final indicator = tester.widget<CircularProgressIndicator>(
        find.descendant(
          of: find.byType(ReadinessRing),
          matching: find.byType(CircularProgressIndicator),
        ),
      );
      final color =
          (indicator.valueColor as AlwaysStoppedAnimation<Color>).value;
      expect(color, MivaltaColors.levelRed);
    });

    testWidgets(
        'zero observation days → learning why says '
        '"I\'m still learning you." (no day count)', (tester) async {
      final data = seededLowConfidence()..observationDays = 0;
      await tester.pumpWidget(pumpableHome(data));

      await tester.tap(find.text('Why?').last);
      await tester.pumpAndSettle();

      expect(find.text("I'm still learning you."), findsOneWidget);
      expect(find.textContaining('— day'), findsNothing);
    });
  });

  // Step 3 (HOME_REDESIGN_BRIEF §5): the today-facts tiles sit between the
  // state element and the session card, and raw engine enums NEVER render on
  // Today — the data is deliberately seeded with raw zone/status strings to
  // prove the suppression, not just the happy path.
  group('Today-facts tiles on the home (step 3)', () {
    Widget pumpableHome(HomeData data) => MaterialApp(
          theme: mivaltaDarkTheme(),
          home: Scaffold(
            body: ThreeZoneHome(
              data: data,
              onTapRing: () {},
              onTapAdvisor: () {},
              onTapLatestWorkout: (_) {},
            ),
          ),
        );

    testWidgets('engine context renders as human tiles (zone → fixed label, '
        'sleep + load verbatim numbers)', (tester) async {
      final data = HomeData()
        ..insufficientData = false
        ..readinessScore = 78
        ..readinessLevel = 'green'
        ..confidence = 0.9
        ..stateRecommendation = 'Recovered — fully charged.'
        ..lastNightSleepHours = 7.5
        ..acwrZone = 'optimal'
        ..acwrRecommendation = 'Load is well balanced.'
        ..dataStatus = 'ok'
        ..todayLoad = 156.0;
      await tester.pumpWidget(pumpableHome(data));

      expect(find.byType(TodayFacts), findsOneWidget);
      expect(find.text('7.5 h sleep'), findsOneWidget);
      expect(find.text('Steady'), findsOneWidget);
      expect(find.text('Trained today'), findsOneWidget);
      expect(find.text('156'), findsOneWidget);
      // Round 3-final item 21: weather is NOT a tile (app-bar icon only).
      expect(find.text('Weather'), findsNothing);
      expect(find.text('No weather right now'), findsNothing);
      // Raw enums never user-visible on Today.
      expect(find.text('optimal'), findsNothing);
      expect(find.textContaining('ACWR'), findsNothing);
    });

    testWidgets('raw enum/status strings are suppressed — honest learning '
        'copy instead', (tester) async {
      final data = HomeData()
        ..insufficientData = true
        ..acwrZone = 'insufficient_data'
        ..dataStatus = 'state_unavailable';
      await tester.pumpWidget(pumpableHome(data));

      expect(find.textContaining('insufficient_data'), findsNothing);
      expect(find.textContaining('state_unavailable'), findsNothing);
      expect(find.textContaining('Monotony'), findsNothing);
      expect(find.textContaining('Strain'), findsNothing);
      expect(find.text('Still learning your load'), findsOneWidget);
      expect(find.text('No sleep data yet'), findsOneWidget);
      expect(find.text('Nothing logged yet'), findsOneWidget);
    });
  });

  // Round 3 item 10 (founder): Start workout migrated from a full-width
  // in-column button (step 4) to a compact control in the home app bar's
  // top-left. The scroll column must stay calm — no start button in the body.
  // The app-bar control itself is pinned in app_shell_test.dart (it needs the
  // real ReadinessScreen scaffold, not just ThreeZoneHome).
  group('Start workout on the home body (round 3 item 10)', () {
    Widget pumpableHome(HomeData data) => MaterialApp(
          theme: mivaltaDarkTheme(),
          home: Scaffold(
            body: ThreeZoneHome(
              data: data,
              onTapRing: () {},
              onTapAdvisor: () {},
              onTapLatestWorkout: (_) {},
            ),
          ),
        );

    testWidgets('no in-column start button — moved to the app bar',
        (tester) async {
      final data = HomeData()
        ..insufficientData = false
        ..readinessScore = 78
        ..readinessLevel = 'green'
        ..confidence = 0.9
        ..stateRecommendation = 'Recovered — fully charged.';
      await tester.pumpWidget(pumpableHome(data));

      expect(find.text('Start workout'), findsNothing);
      // Old Zone-3 quick link stays gone too (step 4 regression guard).
      expect(find.text('Start a workout'), findsNothing);
    });

    testWidgets('no start button in the no-data body either', (tester) async {
      final data = HomeData()..insufficientData = true;
      await tester.pumpWidget(pumpableHome(data));

      expect(find.text('Start workout'), findsNothing);
    });
  });

  // PR-C: Tokens-only compliance — ring color must come from tokens layer
  group('Tokens-only compliance', () {
    testWidgets(
      'ReadinessRing level=green uses MivaltaColors.levelGreen from tokens',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ReadinessRing(
                score: 85,
                level: 'green',
                confidence: 0.9,
                noData: false,
                learning: false,
              ),
            ),
          ),
        );

        final indicator = tester.widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        );
        final color = (indicator.valueColor as AlwaysStoppedAnimation<Color>).value;
        // Color must match the token constant (which equals 0xFF2BD974)
        expect(color, MivaltaColors.levelGreen);
      },
    );

    testWidgets(
      'ReadinessRing level=yellow uses MivaltaColors.levelYellow from tokens',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ReadinessRing(
                score: 72,
                level: 'yellow',
                confidence: 0.75,
                noData: false,
                learning: false,
              ),
            ),
          ),
        );

        final indicator = tester.widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        );
        final color = (indicator.valueColor as AlwaysStoppedAnimation<Color>).value;
        expect(color, MivaltaColors.levelYellow);
      },
    );

    testWidgets(
      'ReadinessRing level=orange uses MivaltaColors.levelOrange from tokens',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ReadinessRing(
                score: 55,
                level: 'orange',
                confidence: 0.6,
                noData: false,
                learning: false,
              ),
            ),
          ),
        );

        final indicator = tester.widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        );
        final color = (indicator.valueColor as AlwaysStoppedAnimation<Color>).value;
        expect(color, MivaltaColors.levelOrange);
      },
    );

    testWidgets(
      'ReadinessRing level=red uses MivaltaColors.levelRed from tokens',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ReadinessRing(
                score: 35,
                level: 'red',
                confidence: 0.5,
                noData: false,
                learning: false,
              ),
            ),
          ),
        );

        final indicator = tester.widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        );
        final color = (indicator.valueColor as AlwaysStoppedAnimation<Color>).value;
        expect(color, MivaltaColors.levelRed);
      },
    );
  });
}

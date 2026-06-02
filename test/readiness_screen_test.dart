// PR-B widget tests for the three-zone PULL home.
//
// FFI path is gated on Platform.isAndroid; on the host harness
// `RustEngineBinding.bootstrap()` throws UnsupportedError immediately,
// so screen-level tests verify structure + error handling. The
// ReadinessRing and SourceTierIndicator are tested by mounting directly.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mivalta_flutter/copy/f1.dart';
import 'package:mivalta_flutter/screens/readiness_screen.dart';
import 'package:mivalta_flutter/theme/source_tier.dart';
import 'package:mivalta_flutter/widgets/readiness_ring.dart';

void main() {
  testWidgets(
    'ReadinessScreen shows Readiness app-bar title; engine-dependent '
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
              ),
            ),
          ),
        );

        // Score renders
        expect(find.text('85'), findsOneWidget);
        // Level renders (verbatim from engine)
        expect(find.text('green'), findsOneWidget);
        // Confidence renders as percentage
        expect(find.text('confidence 92%'), findsOneWidget);

        // Ring's CircularProgressIndicator exists (hero ring)
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // F1 copy must NOT appear when data is present
        expect(find.text(kF1NoDataCopy), findsNothing);
      },
    );

    testWidgets(
      'score=72, level=yellow → renders correct color (not derived from score)',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ReadinessRing(
                score: 72,
                level: 'yellow',
                confidence: 0.75,
                noData: false,
              ),
            ),
          ),
        );

        // Score + level render
        expect(find.text('72'), findsOneWidget);
        expect(find.text('yellow'), findsOneWidget);

        // The CircularProgressIndicator should have the yellow color (0xFFE8C547)
        final indicator = tester.widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        );
        final color = (indicator.valueColor as AlwaysStoppedAnimation<Color>).value;
        expect(color, const Color(0xFFE8C547));
      },
    );

    testWidgets(
      'noData=true → renders F1 copy, no ring, no score',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ReadinessRing(
                score: null,
                level: null,
                confidence: null,
                noData: true,
              ),
            ),
          ),
        );

        // F1 no-data copy renders
        expect(find.text(kF1NoDataCopy), findsOneWidget);

        // No CircularProgressIndicator (no ring)
        expect(find.byType(CircularProgressIndicator), findsNothing);

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
}

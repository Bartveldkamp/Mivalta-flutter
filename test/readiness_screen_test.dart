// Day-5 widget tests for the readiness screen + the new
// SourceTierIndicator. The FFI path is gated on Platform.isAndroid;
// on the host harness `RustEngineBinding.bootstrap()` throws
// UnsupportedError immediately, so the screen-level test exercises
// the error-rendered scaffold. The indicator's two branches
// (swatch / no-data copy) are exercised by mounting it directly.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mivalta_flutter/copy/f1.dart';
import 'package:mivalta_flutter/screens/readiness_screen.dart';
import 'package:mivalta_flutter/theme/source_tier.dart';

void main() {
  testWidgets(
    'ReadinessScreen renders the five section labels; engine-dependent '
    'sections surface the host bootstrap error inline',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: ReadinessScreen()));
      // Initial frame shows the spinner; pump the microtask queue so
      // the failing bootstrap settles and the body rebuilds.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // App-bar title.
      expect(find.text('Readiness'), findsWidgets);

      // The host harness can't load the .so, so the bootstrap throws
      // UnsupportedError before any section data is set. ALL FIVE
      // sections are engine-dependent now (Day-5 dropped the legend
      // placeholder in (e)), so each renders its own inline _ErrorRow
      // with ColorScheme.error.
      expect(find.textContaining('UnsupportedError'), findsNWidgets(5));

      // All five section labels render even on error.
      expect(find.text('READINESS SCORE', skipOffstage: false),
          findsOneWidget);
      expect(find.text('FATIGUE STATE', skipOffstage: false), findsOneWidget);
      expect(find.text('ZONE CAP + ADVISORIES', skipOffstage: false),
          findsOneWidget);
      expect(find.text('RECOMMENDED WORKOUT', skipOffstage: false),
          findsOneWidget);
      expect(find.text('DATA SOURCE TIER', skipOffstage: false),
          findsOneWidget);
    },
  );

  testWidgets('F1 no-data copy locked constant survives literally', (t) async {
    // CLAUDE.md flags any paraphrase as a finding; this guards the
    // string at lib/copy/f1.dart.
    expect(kF1NoDataCopy, 'We need more data to predict recovery.');
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

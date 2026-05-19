// Day-7 widget test for the SourceTier debug exerciser. FFI calls are
// Android-gated; this test exercises the screen scaffold (4 source
// buttons + Clear vault) and the kDebugSwatchSources contract that
// pairs each LOCKED tier with the source identifier rust-engine's
// classify_source maps into that tier.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mivalta_flutter/screens/debug_swatch_exerciser.dart';
import 'package:mivalta_flutter/theme/source_tier.dart';

void main() {
  group('todayIsoDate', () {
    test('pads single-digit month and day with leading zeros', () {
      expect(
        todayIsoDate(now: DateTime(2026, 1, 9)),
        '2026-01-09',
      );
    });

    test('renders two-digit month and day verbatim', () {
      expect(
        todayIsoDate(now: DateTime(2026, 12, 31)),
        '2026-12-31',
      );
    });
  });

  group('kDebugSwatchSources contract', () {
    test('every SourceTier has a source string', () {
      expect(kDebugSwatchSources.keys.toSet(), SourceTier.values.toSet());
    });

    test('source strings match the tier classify_source maps into', () {
      // Mirrors gatc-normalizer's classify_source — verified by
      // Track A's unit tests on rust-engine. If the engine tier
      // table moves, this test fails and forces the Dart-side
      // mapping to follow.
      expect(kDebugSwatchSources[SourceTier.medical], 'polar_h10');
      expect(kDebugSwatchSources[SourceTier.device], 'oura');
      expect(kDebugSwatchSources[SourceTier.partial], 'apple_health');
      expect(kDebugSwatchSources[SourceTier.manual], 'manual');
    });
  });

  testWidgets(
    'renders 4 source buttons + Clear vault + LOCKED labels',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: DebugSwatchExerciser()),
      );
      await tester.pump();

      expect(find.text('Debug — SourceTier exerciser'), findsWidgets);
      for (final tier in SourceTier.values) {
        expect(
          find.textContaining(kSourceTierLabel[tier]!, skipOffstage: false),
          findsOneWidget,
        );
        expect(
          find.textContaining(kDebugSwatchSources[tier]!,
              skipOffstage: false),
          findsOneWidget,
        );
      }
      expect(
        find.widgetWithText(
            OutlinedButton, 'Clear vault (day7-vault dir)',
            skipOffstage: false),
        findsOneWidget,
      );
    },
  );
}

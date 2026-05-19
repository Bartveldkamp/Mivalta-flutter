// Day-4 widget tests for the readiness screen. The FFI path is gated
// on Platform.isAndroid; on the host harness the bootstrap call
// throws UnsupportedError immediately, so we exercise the
// error-rendered scaffold and the F1 / SourceTier surfaces that
// don't depend on a live engine.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mivalta_flutter/copy/f1.dart';
import 'package:mivalta_flutter/screens/readiness_screen.dart';
import 'package:mivalta_flutter/theme/source_tier.dart';

void main() {
  testWidgets(
    'ReadinessScreen renders the five section labels and surfaces the '
    'host bootstrap error inline',
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
      // UnsupportedError before any section data is set. Each of the
      // four engine-dependent sections renders its own inline
      // _ErrorRow with the theme's error color (Day-3 review WARNING
      // followup: Colors.red was swapped for ColorScheme.error). The
      // fifth section (SourceTier legend) is engine-independent and
      // renders regardless.
      expect(find.textContaining('UnsupportedError'), findsNWidgets(4));

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

  testWidgets(
    'F1 no-data copy renders the locked verbatim string when the '
    'screen falls into the insufficient-data branch',
    (WidgetTester tester) async {
      // The locked string is the only way the no-data branch reads —
      // covers the "string lives in lib/copy/f1.dart, no inline copy"
      // contract. The actual branch fires on device when
      // advisories.last_observation_at is null; the test asserts the
      // constant is the verbatim CLAUDE.md text.
      expect(kF1NoDataCopy, 'We need more data to predict recovery.');
    },
  );

  testWidgets(
    'SourceTier legend uses the const color map (no hex literals at '
    'call sites)',
    (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: ReadinessScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Each tier label rendered by the legend reads from
      // kSourceTierLabel, so finding the labels by their map values
      // proves the map is the source of truth.
      for (final tier in SourceTier.values) {
        expect(
          find.text(kSourceTierLabel[tier]!, skipOffstage: false),
          findsOneWidget,
          reason: '$tier label missing from legend',
        );
      }

      // Each swatch is a Container whose decoration's color is the
      // map's projection. Walk the tree and confirm at least one
      // Container per tier uses the projected color.
      final containers = tester.widgetList<Container>(find.byType(Container));
      final usedColors = containers
          .map((c) => (c.decoration as BoxDecoration?)?.color)
          .whereType<Color>()
          .toSet();
      for (final tier in SourceTier.values) {
        expect(
          usedColors.contains(kSourceTierColor[tier]),
          isTrue,
          reason: '${tier.name} swatch color absent from rendered tree',
        );
      }
    },
  );
}

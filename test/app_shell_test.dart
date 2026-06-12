// Step-1 nav-shell tests (HOME_REDESIGN_BRIEF §3/§6): three anchors
// Today / Plan / You on a Material 3 NavigationBar, Plan as an honest
// placeholder, You as a hub of entries into existing screens.
//
// FFI path is gated; on the host harness `RustEngineBinding.bootstrap()`
// throws UnsupportedError which the Today tab catches and surfaces inline
// (same precedent as readiness_screen_test.dart). The shell itself renders
// no engine values.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mivalta_flutter/screens/app_shell.dart';
import 'package:mivalta_flutter/screens/plan_screen.dart';
import 'package:mivalta_flutter/screens/sensor_check_screen.dart';
import 'package:mivalta_flutter/screens/you_screen.dart';
import 'package:mivalta_flutter/theme/tokens.dart';

/// Minimal profile JSON for the shell — the shell only forwards it.
final String kTestProfileJson = jsonEncode({'athlete_id': 'test-user'});

/// Guard for the founder hard rule: no raw engine identifiers user-visible.
/// Scans every rendered Text for snake_case tokens (insufficient_data, ok,
/// acwr_zone, ...).
void expectNoRawEngineIdentifiers(WidgetTester tester) {
  final snake = RegExp(r'\b[a-z0-9]+_[a-z0-9_]+\b');
  for (final w in tester.widgetList<Text>(find.byType(Text))) {
    final s = w.data;
    if (s == null) continue;
    expect(snake.hasMatch(s), isFalse,
        reason: 'raw engine identifier leaked to UI: "$s"');
  }
}

Future<void> pumpShell(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: mivaltaDarkTheme(),
      home: AppShell(profileJson: kTestProfileJson),
    ),
  );
  // Let the Today tab's failing host bootstrap settle (UnsupportedError is
  // caught; _loading flips false).
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  group('AppShell navigation', () {
    testWidgets('shows three anchors: Today, Plan, You', (tester) async {
      await pumpShell(tester);

      expect(find.byType(NavigationBar), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Today'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Plan'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('You'),
        ),
        findsOneWidget,
      );

      // Default tab is Today — the home app bar title renders.
      expect(find.text('MiValta'), findsWidgets);
    });

    testWidgets('tabs switch: Plan shows placeholder, You shows hub, '
        'Today restores', (tester) async {
      await pumpShell(tester);

      // → Plan
      await tester.tap(find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Plan'),
      ));
      await tester.pumpAndSettle();
      expect(find.text(kPlanPlaceholderTitle), findsOneWidget);

      // → You
      await tester.tap(find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('You'),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Profile & settings'), findsOneWidget);

      // → back to Today (IndexedStack preserves it)
      await tester.tap(find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Today'),
      ));
      await tester.pumpAndSettle();
      expect(find.text('MiValta'), findsWidgets);
    });

    testWidgets('Today app bar is slim: no settings/explore/debug actions '
        '(migrated to You)', (tester) async {
      await pumpShell(tester);

      expect(find.byIcon(Icons.settings), findsNothing);
      expect(find.byIcon(Icons.insights_outlined), findsNothing);
      expect(find.byIcon(Icons.bug_report), findsNothing);
    });

    testWidgets('the green "+" FAB is gone — calm home (round 3 item 9); '
        'manual logging lives behind the start-workout flow', (tester) async {
      await pumpShell(tester);

      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.byTooltip('Log today'), findsNothing);
    });

    testWidgets('Start workout is a compact control in the app bar TOP-LEFT '
        '(round 3 item 10) — and the in-column button is gone', (tester) async {
      await pumpShell(tester);

      final control = find.byTooltip('Start workout');
      expect(control, findsOneWidget);
      expect(
        find.ancestor(of: control, matching: find.byType(AppBar)),
        findsOneWidget,
        reason: 'the start control must live in the home app bar',
      );

      // Top-left: sits in the leading slot, left of the title.
      final controlCenter = tester.getCenter(control);
      final titleCenter = tester.getCenter(
        find
            .descendant(of: find.byType(AppBar), matching: find.text('MiValta'))
            .first,
      );
      expect(controlCenter.dx, lessThan(titleCenter.dx));
      expect(tester.getTopLeft(control).dx, lessThan(100),
          reason: 'compact control hugs the top-left corner');

      // The full-width in-column button is gone from the body.
      expect(find.text('Start workout'), findsNothing);
    });

    testWidgets('MiValta title stays CENTERED beside the start control '
        '(round 3 item 10, founder: liked)', (tester) async {
      await pumpShell(tester);

      final appBarRect = tester.getRect(find.byType(AppBar));
      final titleCenter = tester.getCenter(
        find
            .descendant(of: find.byType(AppBar), matching: find.text('MiValta'))
            .first,
      );
      expect(titleCenter.dx, closeTo(appBarRect.center.dx, 1.0));
    });

    testWidgets('tapping the start control opens the sensor-check screen '
        '(same step-4 destination)', (tester) async {
      await pumpShell(tester);

      await tester.tap(find.byTooltip('Start workout'));
      await tester.pumpAndSettle();

      expect(find.byType(SensorCheckScreen), findsOneWidget);
      expect(find.text(kSensorSectionLabel), findsOneWidget);
    });
  });

  // Round 3 items 11+18: weather on the home. The OS channel is mocked here;
  // on a real device the data comes from Apple WeatherKit (the founder-
  // approved OS-level exception to the no-cloud rule, CLAUDE.md rule 6).
  group('Weather on the home (round 3 items 11+18)', () {
    const channel = MethodChannel('mivalta/weather');

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    void mockWeather() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        return {
          'symbol': 'cloud.rain',
          'condition': 'Rain',
          'temperatureC': 11.6,
          'daily': [
            {
              'date': '2026-06-12',
              'symbol': 'cloud.rain',
              'condition': 'Rain',
              'highC': 14.4,
              'lowC': 8.6,
            },
            {
              'date': '2026-06-13',
              'symbol': 'sun.max',
              'condition': 'Clear',
              'highC': 18.2,
              'lowC': 9.1,
            },
          ],
        };
      });
    }

    testWidgets('no OS weather → honest absence: no icon, no forecast',
        (tester) async {
      // No mock handler — same as Android today (no implementation).
      await pumpShell(tester);

      expect(find.byTooltip('Weather'), findsNothing);
      expect(find.text('14° / 9°'), findsNothing);
    });

    testWidgets('OS weather present → ONE condition icon in the app bar '
        'TOP-RIGHT, right of the centered title', (tester) async {
      mockWeather();
      await pumpShell(tester);

      final icon = find.byTooltip('Weather');
      expect(icon, findsOneWidget);
      expect(
        find.ancestor(of: icon, matching: find.byType(AppBar)),
        findsOneWidget,
      );

      final iconCenter = tester.getCenter(icon);
      final titleCenter = tester.getCenter(
        find
            .descendant(of: find.byType(AppBar), matching: find.text('MiValta'))
            .first,
      );
      expect(iconCenter.dx, greaterThan(titleCenter.dx),
          reason: 'condition icon sits top-right of the centered title');

      // Forecast stays closed until tapped.
      expect(find.text('14° / 9°'), findsNothing);
    });

    testWidgets('tap → the 7-day forecast drops down; tap again → it folds '
        'away', (tester) async {
      mockWeather();
      await pumpShell(tester);

      await tester.tap(find.byTooltip('Weather'));
      await tester.pumpAndSettle();
      expect(find.text('14° / 9°'), findsOneWidget);
      expect(find.text('18° / 9°'), findsOneWidget);
      expect(find.text('Clear'), findsOneWidget);

      await tester.tap(find.byTooltip('Weather'));
      await tester.pumpAndSettle();
      expect(find.text('14° / 9°'), findsNothing);
    });
  });

  group('PlanScreen (honest placeholder)', () {
    testWidgets('renders calm copy verbatim, no fabricated plan content',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: mivaltaDarkTheme(), home: const PlanScreen()),
      );

      expect(find.text('Your plan will live here.'), findsOneWidget);
      expect(
        find.text(
          'Josi builds it from how you actually train and recover — no '
          'guesses. Keep logging workouts and morning check-ins, and a '
          'week-by-week plan takes shape here.',
        ),
        findsOneWidget,
      );
      // No fake roadmap/calendar widgets.
      expect(find.byType(Table), findsNothing);
      expect(find.byType(GridView), findsNothing);

      expectNoRawEngineIdentifiers(tester);
    });
  });

  group('YouScreen (hub)', () {
    Future<void> pumpYou(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: mivaltaDarkTheme(),
          home: YouScreen(
            binding: null, // engine not bootstrapped (host harness)
            handle: null,
            profileJson: kTestProfileJson,
            onDataCleared: () {},
          ),
        ),
      );
    }

    testWidgets('regroups settings + trends + privacy entries',
        (tester) async {
      await pumpYou(tester);

      expect(find.text('Profile & settings'), findsOneWidget);
      expect(find.text('Trends & history'), findsOneWidget);
      expect(find.text('Privacy & data'), findsOneWidget);

      expectNoRawEngineIdentifiers(tester);
    });

    testWidgets('engine-backed entries are no-ops while binding/handle are '
        'null (no crash, no navigation)', (tester) async {
      await pumpYou(tester);

      await tester.tap(find.text('Profile & settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Trends & history'));
      await tester.pumpAndSettle();

      // Still on the hub — nothing was pushed.
      expect(find.text('You'), findsOneWidget);
      expect(find.text('Profile & settings'), findsOneWidget);
    });
  });
}

// Corridor Guard Integration Test — BS-008 Wave 1
//
// Drives Splash → Auth → Onboarding (full intake) → Today.
// This test is the CI corridor guard — any break in the flow fails the build.
//
// NOTE: Uses `pump()` with durations instead of `pumpAndSettle()` for screens
// with infinite animations (splash breathe, auth breathe). `pumpAndSettle()`
// never returns when animations loop forever.
//
// For witness screenshots, use `xcrun simctl io booted screenshot <name>.png`
// while running the app manually — Flutter's integration test takeScreenshot()
// returns identical images on iOS simulator.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mivalta_flutter/main.dart' as app;
import 'package:mivalta_flutter/services/profile_service.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Log checkpoint for debugging.
  void checkpoint(String name) {
    debugPrint('CORRIDOR CHECKPOINT: $name');
  }

  /// Pump frames until a specific widget is found, or timeout.
  Future<void> pumpUntilFound(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 30),
    Duration interval = const Duration(milliseconds: 100),
  }) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(interval);
      if (finder.evaluate().isNotEmpty) {
        return;
      }
    }
    throw TimeoutException('Widget not found: $finder', timeout);
  }

  /// Clear all persisted state for a fresh-install test.
  Future<void> clearAllState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    try {
      await ProfileService.deleteProfile();
    } catch (e) {
      debugPrint('Profile delete skipped: $e');
    }
  }

  group('Corridor Guard', () {
    testWidgets(
      'Splash → Auth → Onboarding (full intake) → Today',
      (WidgetTester tester) async {
        // ─── SETUP: Clear all state for fresh install ───
        await clearAllState();

        // Launch the app
        app.main();

        // Initial pump to start the app
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // ─── CORRIDOR 01: SPLASH ───
        // Let splash entrance animation run (2.5s entrance + warm-up)
        // Use pump() not pumpAndSettle() — breathe animations loop forever
        await tester.pump(const Duration(milliseconds: 500));
        checkpoint('corridor_01_splash');

        // Wait for splash to complete and route (entrance 2.5s + warmup ~1s)
        // Pump in increments to allow async callbacks
        for (int i = 0; i < 40; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        // ─── CORRIDOR 02: AUTH ───
        // Wait for auth screen to appear
        await pumpUntilFound(tester, find.text('Sign in with Apple'));
        await tester.pump(const Duration(milliseconds: 500));
        checkpoint('corridor_02_auth');

        // Tap "Sign in with Apple" (stub → completes auth as new account)
        await tester.tap(find.text('Sign in with Apple'));
        await tester.pump(const Duration(milliseconds: 100));

        // Wait for navigation to Onboarding
        await pumpUntilFound(tester, find.text('Your body.\nYour data.'));
        await tester.pump(const Duration(milliseconds: 300));

        // ─── CORRIDOR 03: ONBOARDING ───
        // Step 0: Promise
        expect(find.text('Your body.\nYour data.'), findsOneWidget);
        checkpoint('corridor_03_onboarding_promise');

        // Tap "Get started"
        await tester.tap(find.text('Get started'));
        await tester.pump(const Duration(milliseconds: 300));
        await pumpUntilFound(tester, find.text('Your sport'));

        // Step 1: Sport
        expect(find.text('Your sport'), findsOneWidget);
        checkpoint('onb_sport');

        // Tap "Running"
        await tester.tap(find.text('Running'));
        await tester.pump(const Duration(milliseconds: 100));
        // Tap "Continue"
        await tester.tap(find.text('Continue'));
        await tester.pump(const Duration(milliseconds: 300));
        await pumpUntilFound(tester, find.text('Your aim'));

        // Step 2: Aim + Detail
        expect(find.text('Your aim'), findsOneWidget);
        checkpoint('onb_aim_detail');

        // Tap "Perform" (aim)
        await tester.tap(find.text('Perform'));
        await tester.pump(const Duration(milliseconds: 100));
        // Tap "Show me the numbers too" (detail)
        await tester.tap(find.text('Show me the numbers too'));
        await tester.pump(const Duration(milliseconds: 100));
        // Tap "Continue"
        await tester.tap(find.text('Continue'));
        await tester.pump(const Duration(milliseconds: 300));
        await pumpUntilFound(tester, find.text('About you'));

        // Step 3: About You (age + sex + level + experience + hours)
        // This step requires scrolling as not all options fit on screen
        expect(find.text('About you'), findsOneWidget);
        checkpoint('onb_aboutyou');

        // Helper to scroll to and tap an item
        Future<void> scrollToAndTap(String text) async {
          final finder = find.text(text);
          // Ensure the widget is visible before tapping
          await tester.ensureVisible(finder);
          await tester.pump(const Duration(milliseconds: 100));
          await tester.tap(finder);
          await tester.pump(const Duration(milliseconds: 100));
        }

        // Select age band: 30-39
        await scrollToAndTap('30–39');
        // Select sex: Male
        await scrollToAndTap('Male');
        // Select level: Trained
        await scrollToAndTap('Trained');
        // Select experience: 3-10 years
        await scrollToAndTap('3–10 years');
        // Select weekly hours: 4-6 hours
        await scrollToAndTap('4–6 hours');

        // Scroll to and tap Continue button
        await tester.ensureVisible(find.text('Continue'));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.text('Continue'));
        await tester.pump(const Duration(milliseconds: 300));
        await pumpUntilFound(tester, find.text('Your running threshold'));

        // Step 4: Anchors (running threshold — we selected Running)
        expect(find.text('Your running threshold'), findsOneWidget);
        checkpoint('onb_anchors');

        // Tap "I don't know"
        await tester.tap(find.text("I don't know"));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.text('Continue'));
        await tester.pump(const Duration(milliseconds: 300));
        await pumpUntilFound(tester, find.text('Where your data comes from'));

        // Step 5: Data Sources
        expect(find.text('Where your data comes from'), findsOneWidget);
        checkpoint('onb_datasources');

        // Skip Apple Health connect (optional step)
        await tester.tap(find.text('Continue'));
        await tester.pump(const Duration(milliseconds: 300));
        await pumpUntilFound(tester, find.text('Ready to push your limits.'));

        // Step 6: Payoff
        expect(find.text('Ready to push your limits.'), findsOneWidget);
        checkpoint('onb_payoff');

        // Tap "Enter MiValta" to complete onboarding
        await tester.tap(find.text('Enter MiValta'));

        // Wait for engine construction and navigation to Today
        // This may take a few seconds due to engine bootstrap
        for (int i = 0; i < 50; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        // ─── CORRIDOR 04: TODAY ───
        checkpoint('corridor_04_today');

        // Verify we're no longer on onboarding screens
        expect(find.text('Enter MiValta'), findsNothing);
        expect(find.text('Your body.\nYour data.'), findsNothing);
        expect(find.text('Your aim'), findsNothing);

        debugPrint('Corridor complete: Splash → Auth → Onboarding → Today');
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });
}

/// Custom timeout exception.
class TimeoutException implements Exception {
  TimeoutException(this.message, this.duration);
  final String message;
  final Duration duration;
  @override
  String toString() => 'TimeoutException: $message (after $duration)';
}

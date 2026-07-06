// MiValta — production entry point.
//
// Fresh Today screen built from Claude Design specs. Engine DECIDES,
// Flutter DISPLAYS. See docs/UI_CLEANOUT_PLAN.md for the clean-out that
// preceded this fresh build.

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'package:shared_preferences/shared_preferences.dart';

import 'canonical_seed.dart';
import 'debug/demo_seeder.dart';
import 'rust_engine.dart';
import 'screens/splash_screen.dart';
import 'screens/today_screen.dart';
import 'services/notification_service.dart';
import 'services/profile_service.dart';
import 'theme/tokens.dart';

/// Global navigator key for notification tap navigation.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // BS-012 N3: Initialize notification service with tap→Today navigation.
  await NotificationService.instance.initialize(
    onTap: () {
      // Navigate to TodayScreen when notification is tapped.
      // Uses global navigator key for navigation outside widget tree.
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const TodayScreen()),
        (route) => false,
      );
    },
  );

  // DEBUG: seed demo athlete on boot (kDebugMode only, compiled out of release)
  // Enabled for BS-001 design verification with real engine-computed data
  // DISABLED for DR-017 final witness — fresh onboarding E2E
  // RE-ENABLED 2026-07-06 for the voice wiring train verification: the coach
  // lines need 30 days of engine-computed history to have anything true to
  // say. The DR-017 fresh-onboarding witness is complete (PR #152 report).
  if (kDebugMode) {
    await _seedDemoIfNeeded();
  }

  runApp(const MivaltaApp());
}

/// kDebugMode-only: seed the demo athlete if no profile exists.
/// Uses the real ingest path (DemoSeeder → IngestAdapter) so the engine
/// genuinely computes every readiness state from the seeded observations.
Future<void> _seedDemoIfNeeded() async {
  if (await ProfileService.hasPersistedProfile()) return; // skip if already seeded

  final binding = await RustEngineBinding.bootstrap();
  final profileJson = CanonicalSeed.vaultProfileJson();
  final tablesJson = await rootBundle.loadString('assets/compiled_tables.json');
  final vaultPath = await ProfileService.getVaultPath();

  // Save profile to vault
  await ProfileService.saveProfile(profileJson);

  // Construct engines fresh
  final handle = await binding.constructEnginesFresh(
    athleteProfileJson: profileJson,
    tablesJson: tablesJson,
    vaultPath: vaultPath,
  );

  // Seed 30 days of demo biometrics + workouts through real ingest path
  final seeder = DemoSeeder(binding: binding, handle: handle);
  await seeder.seedSeason(days: 30);

  // A seeded debug boot is by definition a "returning athlete": mark the
  // auth session so SplashScreen routes straight to Today. Without this the
  // stub auth flow lands on Onboarding, whose profile write would replace
  // the seeded athlete and orphan the 30 days of vault history.
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('has_auth_session', true);
}

class MivaltaApp extends StatelessWidget {
  const MivaltaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MiValta',
      theme: mivaltaDarkTheme(),
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey, // BS-012 N3: for notification tap navigation
      home: const SplashScreen(),
    );
  }
}

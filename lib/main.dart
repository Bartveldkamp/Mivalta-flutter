// MiValta — production entry point.
//
// Fresh Today screen built from Claude Design specs. Engine DECIDES,
// Flutter DISPLAYS. See docs/UI_CLEANOUT_PLAN.md for the clean-out that
// preceded this fresh build.

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'canonical_seed.dart';
import 'debug/demo_seeder.dart';
import 'rust_engine.dart';
import 'screens/today_screen.dart';
import 'services/profile_service.dart';
import 'theme/tokens.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // DEBUG: seed demo athlete on boot (kDebugMode only, compiled out of release)
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
}

class MivaltaApp extends StatelessWidget {
  const MivaltaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MiValta',
      theme: mivaltaDarkTheme(),
      debugShowCheckedModeBanner: false,
      home: const TodayScreen(),
    );
  }
}

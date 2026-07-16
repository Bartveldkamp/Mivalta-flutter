// BS-017 stage 2 — the headless test ENVIRONMENT for self-bootstrapping
// screens (Today / Journey / You).
//
// The screens touch more than the engine binding during `_initEngine`:
//   * ProfileService.loadProfile()  → path_provider + a stored profile file
//     (the legacy plaintext path, which needs NO native vault — the
//     pointer+vault path would call the real FRB init);
//   * SharedPreferences reads (detail/weather/coach-presence prefs);
//   * rootBundle 'assets/compiled_tables.json' (real declared asset — works
//     under `flutter test`, no mock needed);
//   * GoogleFonts (type tokens + masthead wordmark) — see
//     [_HangingFontHttpOverrides].
//
// All values here are ENVIRONMENT plumbing, not engine data: engine data is
// pinned per test through FakeEngineBinding.canned.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A realistic stored AthleteProfile (the shape ProfileService persists and
/// the You screen parses: sport / level / goal_type read directly). Fields
/// mirror ProfileBuilder.buildInputs() — raw inputs, no Dart-derived coaching.
const String kTestProfileJson = '{'
    '"athlete_id":"11111111-2222-4333-8444-555555555555",'
    '"age":35,"sex":"male","level":"intermediate","sport":"cycling",'
    '"goal_type":"general_fitness","weekly_hours":6.0,"training_years":4,'
    '"threshold_hr":165,"ftp_watts":250,"threshold_pace_sec_km":null'
    '}';

/// google_fonts (MivaltaType tokens, the masthead wordmark) tries to fetch
/// every font over HTTP in tests. flutter_test's stock mock client answers
/// 400 immediately, which makes google_fonts THROW an unhandled async error
/// the moment a `runAsync` yield lets the response arrive (setting
/// `allowRuntimeFetching = false` throws the same way, just earlier). The
/// honest headless posture: the fetch simply NEVER completes — the font
/// future stays pending (no error, no timer), and text renders in the test
/// fallback font, which these tests never assert on.
class _HangingFontHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      _HangingHttpClient();
}

class _HangingHttpClient implements HttpClient {
  @override
  Object? noSuchMethod(Invocation invocation) {
    if (invocation.isMethod) {
      // Every request-opening method resolves to a future that never
      // completes — a hung wire, not a fabricated response.
      return Completer<HttpClientRequest>().future;
    }
    return null;
  }
}

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.root);
  final String root;

  @override
  Future<String?> getApplicationSupportPath() async => root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;

  @override
  Future<String?> getTemporaryPath() async => root;
}

/// Install the headless environment for one test.
///
/// * Creates a fresh temp dir and points path_provider at it (so every test
///   is isolated — no leftover profile/dismissal files between tests).
/// * When [profileJson] is non-null, writes it as the legacy plaintext
///   profile file so `ProfileService.loadProfile()` returns it WITHOUT
///   touching the native vault. When null, no profile exists → the screens'
///   honest-absence path.
/// * Seeds SharedPreferences mock values ([prefs] merged over safe defaults:
///   weather off, simple detail — no platform channels get exercised).
/// * Pre-warms the rootBundle string cache for `compiled_tables.json` in the
///   REAL async zone. Traced this session: a 'flutter/assets' fetch initiated
///   from the widget (fake-async) zone completes only for the FIRST test in a
///   file — the flutter_test binding clears the asset cache between tests and
///   a second fake-zone platform fetch never delivers. With the cache warm,
///   the screens' `rootBundle.loadString` is a cache hit and never touches
///   the channel from the fake zone.
Future<Directory> installHeadlessEnv(
  WidgetTester tester, {
  String? profileJson,
  Map<String, Object> prefs = const {},
}) async {
  HttpOverrides.global = _HangingFontHttpOverrides();
  final dir = Directory.systemTemp.createTempSync('bs017_corridor_');
  PathProviderPlatform.instance = _FakePathProviderPlatform(dir.path);
  SharedPreferences.setMockInitialValues(<String, Object>{
    'onboarding_detail': 'simple',
    'show_weather': false,
    'coach_presence': 'moderate',
    ...prefs,
  });
  if (profileJson != null) {
    File('${dir.path}/athlete_profile.json').writeAsStringSync(profileJson);
  }
  await tester.runAsync(
      () => rootBundle.loadString('assets/compiled_tables.json'));
  return dir;
}

/// Pump the widget tree until the screen's loading spinner is gone.
///
/// The screens' `_initEngine` chain awaits real async work (temp-dir file
/// reads, the asset bundle) that the fake-async test zone does not drive, so
/// each iteration yields to the real event loop via `runAsync` and then pumps
/// a frame. Bounded — a screen that never finishes loading fails the test
/// loudly instead of hanging.
///
/// Deliberately NOT pumpAndSettle: screens carry looping/long animations
/// (glow transitions, progress indicators) that never settle.
Future<void> pumpUntilLoaded(WidgetTester tester, {int maxTries = 40}) async {
  for (var i = 0; i < maxTries; i++) {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 50));
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
      // One extra frame so post-load setState content is laid out.
      await tester.pump(const Duration(milliseconds: 50));
      return;
    }
  }
  fail('screen never finished loading (spinner still present '
      'after $maxTries pump iterations)');
}

/// A tall test viewport so lazily-built sliver content (Today's evening
/// section lives near the bottom of a SliverList) is actually built.
/// Restores the real view metrics on teardown.
void useTallTestViewport(WidgetTester tester,
    {Size size = const Size(600, 4000)}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

// ───────────────────────── canned engine JSON ─────────────────────────
//
// Realistic pinned engine payloads, field names verified against the REAL
// parsers this session:
//   readiness_indicator  → lib/screens/today_screen.dart _loadHomeData
//                          (score/level/confidence/contributions — shape per
//                          rust-engine docs/frontend/FFI_API_CONTRACT.md §7,
//                          ReadinessBlendResult)
//   state_advisory       → state_recommendation / confidence_advisory
//   get_readiness        → {"state": ...} (key is "state")
//   RealizedLine         → lib/models/realized_line.dart (text/safety/degraded)
//   WorkoutOptionData[]  → lib/models/workout_option.dart (bare JSON ARRAY)
//   AcwrResult           → acwr/zone/recommendation/chronic_load
//   morning_read_verdict → lib/services/morning_read_gate.dart parseVerdict
//                          (fire is REQUIRED — parse fails loud without it)

const String kCannedIndicatorHealthy =
    '{"score":87.0,"level":"green","confidence":0.82,"contributions":['
    '{"name":"viterbi_state","raw_score":90.0,"weight":0.5,"weighted":45.0},'
    '{"name":"physiological","raw_score":82.0,"weight":0.35,"weighted":28.7},'
    '{"name":"psychological","raw_score":88.0,"weight":0.15,"weighted":13.2}]}';

/// The engine's explicit no-data verdict (readiness_indicator on cold start):
/// score 0, confidence 0, empty contributions — the documented "consumers
/// gate their need-more-data copy on the zero confidence" contract.
const String kCannedIndicatorNoData =
    '{"score":0.0,"level":"red","confidence":0.0,"contributions":[]}';

const String kCannedStateAdvisory =
    '{"state_recommendation":"Body is absorbing the work. Keep today light.",'
    '"confidence_advisory":"Confidence is building - 21 days observed."}';

const String kCannedFatigueState = '{"state":"Productive"}';

const String kCannedZoneCapCeiling = '{"zone":"Z8","advisories":{}}';

const String kCannedAcwr =
    '{"acwr":1.05,"zone":"optimal","chronic_load":410.0,'
    '"recommendation":"Within your target band"}';

const String kCannedWorkoutOptions = '[{'
    '"option_id":"opt_a","title":"Steady aerobic ride","zone":"Z2",'
    '"why":"Aerobic base maintenance","tags":["endurance"],'
    '"structure":{"total_minutes":60,'
    '"main_set":{"cue_start":"Settle into a steady rhythm"}}}]';

const String kCannedMorningVerdictSilent =
    '{"fire":false,"reason":"no_change","state":"Productive",'
    '"sufficiency_bucket":"medium","title":"","body":""}';

const String kCannedDiagnostics =
    '{"observation_count":21,"confidence":"medium"}';

const String kCannedValidationReport =
    '{"data_sufficiency":"insufficient","paired_observations":3,'
    '"period_days":21,"overall_model_score":0.0}';

/// The baseline canned set that lets each of the three corridor screens load
/// to its content state. Tests copy it and override the seam under test.
Map<String, Object> cannedCorridorDefaults() => <String, Object>{
      'readinessIndicator': kCannedIndicatorHealthy,
      'personalizationDiagnostics': kCannedDiagnostics,
      'stateAdvisory': kCannedStateAdvisory,
      'viterbiFatigueState': kCannedFatigueState,
      'zoneCapWithAdvisories': kCannedZoneCapCeiling,
      'getAcwr': kCannedAcwr,
      'lastObservationSourceTier': '"Device"',
      'recommendWorkoutWithHistory': kCannedWorkoutOptions,
      'morningReadVerdict': kCannedMorningVerdictSilent,
      'validationReport': kCannedValidationReport,
      // Advisor line: the primary Josi voice line — pinned per test where the
      // verbatim contract is the assertion; this default keeps other screens
      // rendering a line.
      'realizeAdvisorLine':
          '{"text":"Recovered and ready - today can carry intensity.",'
              '"safety":[],"degraded":false}',
    };

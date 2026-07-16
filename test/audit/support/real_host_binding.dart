// HOST-ONLY REAL-ENGINE HARNESS (final integration audit, 2026-07-16).
// A REAL binding for host-side widget tests: implements the
// facade surface by forwarding every call 1:1 to the generated FRB bindings
// (the real .so), exactly as the production facade does. It exists only
// because `RustEngineBinding.bootstrap()` hard-throws off-device; there is
// ZERO logic here — pure courier (Law 2). Any facade method a screen calls
// that is not forwarded below FAILS LOUD via noSuchMethod, naming itself.
import 'package:mivalta_flutter/rust_engine.dart';
import 'package:mivalta_flutter/src/rust/api.dart' as rust;

class RealHostBinding implements RustEngineBinding {
  @override
  Future<String> readinessIndicator(EnginesHandle handle) =>
      rust.readinessIndicator(handle: handle);

  @override
  Future<String> readinessScore(EnginesHandle handle) =>
      rust.readinessScore(handle: handle);

  @override
  Future<String> stateAdvisory(EnginesHandle handle) =>
      rust.stateAdvisory(handle: handle);

  @override
  Future<String> realizeAdvisorLine(EnginesHandle handle,
          {required String date}) =>
      rust.realizeAdvisorLine(handle: handle, date: date);

  @override
  Future<String> realizeWorkoutReflection(EnginesHandle handle,
          {required String activityId, required String date}) =>
      rust.realizeWorkoutReflection(
          handle: handle, activityId: activityId, date: date);

  @override
  Future<String> realizeAdvisoryOffer(EnginesHandle handle,
          {required String optionJson,
          required String readinessLevel,
          required String date}) =>
      rust.realizeAdvisoryOffer(
          handle: handle,
          optionJson: optionJson,
          readinessLevel: readinessLevel,
          date: date);

  @override
  Future<String> realizeDaySummary(EnginesHandle handle,
          {required String date}) =>
      rust.realizeDaySummary(handle: handle, date: date);

  @override
  Future<String> morningReadVerdict(EnginesHandle handle,
          {required String presence,
          String? lastDeliveredState,
          String? lastDeliveredBucket,
          required bool alreadyNotifiedToday}) =>
      rust.morningReadVerdict(
          handle: handle,
          presence: presence,
          lastDeliveredState: lastDeliveredState,
          lastDeliveredBucket: lastDeliveredBucket,
          alreadyNotifiedToday: alreadyNotifiedToday);

  @override
  Future<String> getAcwr(EnginesHandle handle) => rust.getAcwr(handle: handle);

  @override
  Future<String> getMonotonyStrain(EnginesHandle handle) =>
      rust.getMonotonyStrain(handle: handle);

  @override
  Future<String> pendingAdvisories(EnginesHandle handle) =>
      rust.pendingAdvisories(handle: handle);

  @override
  Future<String> lastWorkoutSummary(EnginesHandle handle) =>
      rust.lastWorkoutSummary(handle: handle);

  @override
  Future<String> viterbiFatigueState(EnginesHandle handle) =>
      rust.viterbiFatigueState(handle: handle);

  @override
  Future<String> validationReport(EnginesHandle handle) =>
      rust.validationReport(handle: handle);

  @override
  Future<String> personalizationDiagnostics(EnginesHandle handle) =>
      rust.personalizationDiagnostics(handle: handle);

  @override
  Future<String> zoneCapWithAdvisories(EnginesHandle handle) =>
      rust.zoneCapWithAdvisories(handle: handle);

  @override
  Future<String> recommendWorkoutWithHistory(EnginesHandle handle,
          {String? mood, String? equipment, String? terrain}) =>
      rust.recommendWorkoutWithHistory(
          handle: handle, mood: mood, equipment: equipment, terrain: terrain);

  @override
  Future<String> vaultSnapshot(EnginesHandle handle) =>
      rust.vaultSnapshot(handle: handle);

  @override
  Future<String> lastObservationSourceTier(EnginesHandle handle) =>
      rust.lastObservationSourceTier(handle: handle);

  @override
  Future<String> readReadinessHistory(EnginesHandle handle,
          {required int days}) =>
      rust.readReadinessHistory(handle: handle, days: days);

  @override
  Future<String> readDailyLoads(EnginesHandle handle, {required int days}) =>
      rust.readDailyLoads(handle: handle, days: days);

  @override
  Future<String> listDataSources(EnginesHandle handle) =>
      rust.listDataSources(handle: handle);

  @override
  Future<String> readActivitiesInRange(EnginesHandle handle,
          {required String start, required String end}) =>
      rust.readActivitiesInRange(handle: handle, start: start, end: end);

  @override
  Future<String> metabolicTimeInZoneRollup(EnginesHandle handle,
          {required String start, required String end}) =>
      rust.metabolicTimeInZoneRollup(handle: handle, start: start, end: end);

  @override
  Future<String> hrvTrend(EnginesHandle handle) =>
      rust.hrvTrend(handle: handle);

  @override
  Future<String> rhrTrend(EnginesHandle handle) =>
      rust.rhrTrend(handle: handle);

  @override
  Future<String> readRecentActivities(EnginesHandle handle,
          {required int limit}) =>
      rust.readRecentActivities(handle: handle, limit: limit);

  @override
  Future<String> getWorkoutDetail(EnginesHandle handle,
          {required String date}) =>
      rust.getWorkoutDetail(handle: handle, date: date);

  @override
  Future<String> completedWorkoutFacts(EnginesHandle handle,
          {required String date}) =>
      rust.completedWorkoutFacts(handle: handle, date: date);

  @override
  Future<String> buildPostWorkoutReport(EnginesHandle handle,
          {required String factsJson}) =>
      rust.buildPostWorkoutReport(handle: handle, factsJson: factsJson);

  @override
  Future<String> readBiometricHistory(EnginesHandle handle,
          {required int days}) =>
      rust.readBiometricHistory(handle: handle, days: days);

  @override
  Future<String> fitnessSeries(EnginesHandle handle, {required int days}) =>
      rust.fitnessSeries(handle: handle, days: days);

  @override
  Future<String> computeTimeInZone(EnginesHandle handle,
          {required String activityJson}) =>
      rust.computeTimeInZone(handle: handle, activityJson: activityJson);

  @override
  Future<String> saveState(EnginesHandle handle) =>
      rust.saveState(handle: handle);

  @override
  Future<void> writeViterbiState(EnginesHandle handle,
          {required String stateJson}) =>
      rust.writeViterbiState(handle: handle, stateJson: stateJson);

  @override
  Future<bool> writeReadinessAssessment(EnginesHandle handle,
          {required String date}) =>
      rust.writeReadinessAssessment(handle: handle, date: date);

  @override
  Future<bool> hasPersistedState(
          {required String athleteProfileJson, required String vaultPath}) =>
      rust.hasPersistedState(
          athleteProfileJson: athleteProfileJson, vaultPath: vaultPath);

  @override
  Future<String?> readPersistedState(
          {required String athleteProfileJson, required String vaultPath}) =>
      rust.readPersistedState(
          athleteProfileJson: athleteProfileJson, vaultPath: vaultPath);

  @override
  Future<EnginesHandle> constructEnginesFresh(
          {required String athleteProfileJson,
          required String tablesJson,
          required String vaultPath}) =>
      rust.constructEnginesFresh(
          athleteProfileJson: athleteProfileJson,
          tablesJson: tablesJson,
          vaultPath: vaultPath);

  @override
  Future<EnginesHandle> constructEnginesFromState(
          {required String athleteProfileJson,
          required String tablesJson,
          required String vaultPath,
          required String viterbiStateJson}) =>
      rust.constructEnginesFromState(
          athleteProfileJson: athleteProfileJson,
          tablesJson: tablesJson,
          vaultPath: vaultPath,
          viterbiStateJson: viterbiStateJson);

  @override
  Future<String?> readProfileFromVault(
          {required String athleteId, required String vaultPath}) =>
      rust.readProfileFromVault(athleteId: athleteId, vaultPath: vaultPath);

  // Any facade member a screen touches that isn't forwarded above: FAIL LOUD
  // and name it, so the audit discovers the gap instead of faking a value.
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
      'RealHostBinding: unforwarded facade member ${invocation.memberName} — '
      'add a 1:1 forward for it');
}

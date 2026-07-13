// #3 readiness write-back — the Dart courier decision, pinned.
//
// The VALUE side (honest-absence skip, field extraction, rounding) is owned
// and unit-tested in the Rust shim (rust/src/api.rs: readiness_assessment_fields
// tests) — Dart must not re-prove it (Law 2). What Dart owns, this pins:
//   1. after a batch that advanced Viterbi's state, the engine state is
//      persisted AND the write-back is couriered exactly once, with the
//      latest processed date verbatim;
//   2. a batch with mutations but no resolvable date couriers NO write-back
//      (nothing to anchor — honest absence, not a guessed date);
//   3. a batch with zero mutations persists nothing and couriers nothing;
//   4. the write-back target is the lexical MAX ISO date, robust to
//      out-of-order ingest (maxIsoDate).

import 'package:flutter_test/flutter_test.dart';
import 'package:mivalta_flutter/rust_engine.dart';
import 'package:mivalta_flutter/services/health_ingest.dart';

// Fake seam rationale (established repo pattern — advisor_history_wire_test,
// benchmark_sync_test, benchmark_notify_test): the HANDLE fake may return null
// because couriers never introspect the opaque handle, they only pass it; the
// BINDING fake throws UnimplementedError on any unfaked method, so the moment
// the code path under test grows a new engine call, the test fails loud at the
// seam rather than silently stubbing to null.
class _FakeHandle implements EnginesHandle {
  @override
  Object? noSuchMethod(Invocation invocation) => null;
}

class _RecordingBinding implements RustEngineBinding {
  _RecordingBinding({this.writeBackResult = true});

  /// What writeReadinessAssessment reports: true = row written,
  /// false = the shim's honest-absence skip.
  final bool writeBackResult;
  final List<String> calls = [];
  final List<String> writeBackDates = [];

  @override
  Future<String> saveState(EnginesHandle handle) async {
    calls.add('saveState');
    return '{"state":"blob"}';
  }

  @override
  Future<void> writeViterbiState(EnginesHandle handle,
      {required String stateJson}) async {
    calls.add('writeViterbiState');
  }

  @override
  Future<bool> writeReadinessAssessment(EnginesHandle handle,
      {required String date}) async {
    calls.add('writeReadinessAssessment');
    writeBackDates.add(date);
    return writeBackResult;
  }

  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not faked');
}

void main() {
  HealthIngestService service(_RecordingBinding binding) =>
      HealthIngestService(binding: binding, handle: _FakeHandle());

  test('mutated batch persists state then couriers the write-back date verbatim',
      () async {
    final binding = _RecordingBinding();
    await service(binding).persistBatchState(
      mutated: 3,
      latestProcessedDate: '2026-07-11',
    );

    expect(
        binding.calls,
        ['saveState', 'writeViterbiState', 'writeReadinessAssessment'],
        reason: 'state persists first, write-back couriers after — once each');
    expect(binding.writeBackDates, ['2026-07-11'],
        reason: 'the date couriers verbatim, untransformed');
  });

  test('mutations without a resolvable date courier NO write-back', () async {
    final binding = _RecordingBinding();
    await service(binding).persistBatchState(
      mutated: 1,
      latestProcessedDate: null,
    );

    expect(binding.calls, ['saveState', 'writeViterbiState'],
        reason: 'no date → no write-back call; never a guessed date');
    expect(binding.writeBackDates, isEmpty);
  });

  test('zero mutations persist nothing and courier nothing', () async {
    final binding = _RecordingBinding();
    await service(binding).persistBatchState(
      mutated: 0,
      latestProcessedDate: '2026-07-11',
    );

    expect(binding.calls, isEmpty,
        reason: 'an unadvanced engine has nothing to persist or write back');
  });

  test('an honest-absence skip (shim returns false) is not an error', () async {
    // The shim reporting "nothing written" is a valid outcome (engine has no
    // readiness yet), never an exception — the courier completes normally and
    // the state persist still happened.
    final binding = _RecordingBinding(writeBackResult: false);
    await service(binding).persistBatchState(
      mutated: 2,
      latestProcessedDate: '2026-07-12',
    );

    expect(binding.calls,
        ['saveState', 'writeViterbiState', 'writeReadinessAssessment']);
    expect(binding.writeBackDates, ['2026-07-12']);
  });

  test('maxIsoDate picks the lexical max, robust to out-of-order ingest', () {
    String? latest;
    // Backfill order: newest day arrives in the middle of the batch.
    for (final d in ['2026-07-09', '2026-07-11', '2026-07-10']) {
      latest = HealthIngestService.maxIsoDate(latest, d);
    }
    expect(latest, '2026-07-11');
    // Seeding from null takes the candidate.
    expect(HealthIngestService.maxIsoDate(null, '2026-01-01'), '2026-01-01');
    // Equal dates keep the current (no churn).
    expect(HealthIngestService.maxIsoDate('2026-07-11', '2026-07-11'),
        '2026-07-11');
  });
}

// Widget tests for the V4 pause-learning privacy toggle on the Settings
// screen.
//
// The toggle SURFACES the existing engine control
// (ViterbiEngine::pause_learning / resume_learning / is_learning_paused). It is
// display-only: the switch mirrors the engine flag and never decides it. These
// tests pin the concrete behaviour against a recording fake binding (the same
// `implements RustEngineBinding` idiom as demo_seeder_test.dart):
//   - on load the toggle reads is_learning_paused for its initial state,
//   - tapping ON calls pause_learning, tapping OFF calls resume_learning,
//   - after each toggle the engine state is persisted (save_state →
//     writeViterbiState) so the choice survives a restart (continuity), and
//   - the switch reflects whatever is_learning_paused reports back (engine is
//     the source of truth).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mivalta_flutter/rust_engine.dart';
import 'package:mivalta_flutter/screens/settings_screen.dart';

class _FakeHandle implements EnginesHandle {
  @override
  Object? noSuchMethod(Invocation invocation) => null;
}

/// Records the pause-learning calls the Settings screen makes, and lets a test
/// seed the engine's reported pause state. Implements (not extends) the binding
/// — the private constructor blocks subclassing — and overrides only the
/// methods the toggle + screen load touch; everything else throws so an
/// accidental untested engine call is loud, not silent.
class _RecordingBinding implements RustEngineBinding {
  _RecordingBinding({bool initiallyPaused = false}) : _paused = initiallyPaused;

  /// The engine's reported pause flag — the source of truth the toggle mirrors.
  bool _paused;

  int pauseCalls = 0;
  int resumeCalls = 0;
  int isPausedCalls = 0;
  int saveStateCalls = 0;
  final List<String> persistedStates = [];

  @override
  Future<bool> isLearningPaused(EnginesHandle handle) async {
    isPausedCalls++;
    return _paused;
  }

  @override
  Future<void> pauseLearning(EnginesHandle handle) async {
    pauseCalls++;
    _paused = true; // the real engine flips its in-memory flag
  }

  @override
  Future<void> resumeLearning(EnginesHandle handle) async {
    resumeCalls++;
    _paused = false;
  }

  @override
  Future<String> saveState(EnginesHandle handle) async {
    saveStateCalls++;
    return '{"engine_state":true,"learning_paused":$_paused}';
  }

  @override
  Future<void> writeViterbiState(
    EnginesHandle handle, {
    required String stateJson,
  }) async {
    persistedStates.add(stateJson);
  }

  // The screen's _loadData also calls buildSourceOverview; it is optional
  // (wrapped in its own try/catch), so returning an empty overview keeps the
  // load path clean without exercising the data-sources section here.
  @override
  Future<String> buildSourceOverview(
    EnginesHandle handle, {
    required String sourcesJson,
  }) async =>
      '{"primary_sources":{}}';

  @override
  Object? noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not faked');
}

const String _kProfileJson = '{"athlete_id":"test-user","sport":"cycling"}';

Future<void> _pumpSettings(
  WidgetTester tester,
  _RecordingBinding binding,
) async {
  // _buildContent is a ListView; its children build lazily, so a section below
  // the default 800x600 test viewport (the personalization toggle is the 4th
  // section) is never built as an element and `find` returns 0. Give the test a
  // tall surface so every section renders (and is tappable without scrolling).
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: SettingsScreen(
        binding: binding,
        handle: _FakeHandle(),
        profileJson: _kProfileJson,
        onDataCleared: () {},
      ),
    ),
  );
  // Let _loadData settle (it awaits isLearningPaused + buildSourceOverview).
  await tester.pumpAndSettle();
}

void main() {
  group('Pause-learning toggle', () {
    testWidgets('reads is_learning_paused on load → OFF when engine not paused',
        (tester) async {
      final binding = _RecordingBinding(initiallyPaused: false);
      await _pumpSettings(tester, binding);

      // The screen asked the engine for the flag at least once on load.
      expect(binding.isPausedCalls, greaterThanOrEqualTo(1));

      final toggle = find.widgetWithText(SwitchListTile, 'Pause personalization');
      expect(toggle, findsOneWidget);
      expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
    });

    testWidgets('reads is_learning_paused on load → ON when engine paused',
        (tester) async {
      final binding = _RecordingBinding(initiallyPaused: true);
      await _pumpSettings(tester, binding);

      final toggle = find.widgetWithText(SwitchListTile, 'Pause personalization');
      expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
    });

    testWidgets('tap ON calls pause_learning, persists state, reflects engine',
        (tester) async {
      final binding = _RecordingBinding(initiallyPaused: false);
      await _pumpSettings(tester, binding);

      await tester.tap(
        find.widgetWithText(SwitchListTile, 'Pause personalization'),
      );
      await tester.pumpAndSettle();

      // The engine pause control was invoked, resume was not.
      expect(binding.pauseCalls, 1);
      expect(binding.resumeCalls, 0);

      // Continuity: the engine's OWN state was saved and persisted to the vault
      // exactly once so the choice survives a restart.
      expect(binding.saveStateCalls, 1);
      expect(binding.persistedStates, hasLength(1));
      expect(binding.persistedStates.single, contains('learning_paused":true'));

      // The switch now mirrors the engine's re-read flag.
      final toggle = find.widgetWithText(SwitchListTile, 'Pause personalization');
      expect(tester.widget<SwitchListTile>(toggle).value, isTrue);
    });

    testWidgets('second tap calls resume_learning and flips the switch back OFF',
        (tester) async {
      // Start paused so the first interaction is a RESUME (turning it off).
      final binding = _RecordingBinding(initiallyPaused: true);
      await _pumpSettings(tester, binding);

      // Tap OFF → resume.
      await tester.tap(
        find.widgetWithText(SwitchListTile, 'Pause personalization'),
      );
      await tester.pumpAndSettle();

      expect(binding.resumeCalls, 1);
      expect(binding.pauseCalls, 0);
      expect(binding.saveStateCalls, 1);
      expect(binding.persistedStates.single, contains('learning_paused":false'));

      final offToggle =
          find.widgetWithText(SwitchListTile, 'Pause personalization');
      expect(tester.widget<SwitchListTile>(offToggle).value, isFalse);

      // Tap ON again → pause. Proves both directions wire to the engine.
      await tester.tap(offToggle);
      await tester.pumpAndSettle();

      expect(binding.pauseCalls, 1);
      expect(binding.resumeCalls, 1);
      expect(binding.saveStateCalls, 2);
      expect(binding.persistedStates, hasLength(2));

      final onToggle =
          find.widgetWithText(SwitchListTile, 'Pause personalization');
      expect(tester.widget<SwitchListTile>(onToggle).value, isTrue);
    });
  });
}

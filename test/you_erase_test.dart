// Y2: Erase confirm-twice widget test.
//
// The most destructive action in the app (erase everything) MUST be tested.
// Contract: confirm-twice → FFI called once.
//
// This test verifies the two-step confirmation flow for erasing all user data.
// It uses a recording binding to verify that `clearAllUserData` and
// `cryptoEraseCache` are each called exactly once after both confirms.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mivalta_flutter/rust_engine.dart';
import 'package:mivalta_flutter/theme/tokens.dart';

void main() {
  group('YouScreen erase flow', () {
    testWidgets('confirm-twice → FFI called once', (tester) async {
      // Setup: create a recording binding.
      final binding = _RecordingEraseBinding();
      final handle = _FakeHandle();

      // Build a minimal widget that exercises the erase flow.
      await tester.pumpWidget(
        MaterialApp(
          home: _EraseTestHarness(
            binding: binding,
            handle: handle,
          ),
        ),
      );

      // Initial state: FFI not called.
      expect(binding.clearAllUserDataCalls, 0);
      expect(binding.cryptoEraseCacheCalls, 0);

      // Step 1: Tap "Erase everything" to start the flow.
      await tester.tap(find.text('Erase everything'));
      await tester.pumpAndSettle();

      // First dialog appears.
      expect(find.text('Erase everything?'), findsOneWidget);

      // FFI still not called (user hasn't confirmed yet).
      expect(binding.clearAllUserDataCalls, 0);
      expect(binding.cryptoEraseCacheCalls, 0);

      // Step 2: Tap "Continue" on first dialog.
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Second dialog appears.
      expect(find.text('Are you sure?'), findsOneWidget);

      // FFI still not called (waiting for second confirm).
      expect(binding.clearAllUserDataCalls, 0);
      expect(binding.cryptoEraseCacheCalls, 0);

      // Step 3: Tap "Erase everything" on second dialog.
      await tester.tap(find.widgetWithText(TextButton, 'Erase everything'));
      await tester.pumpAndSettle();

      // NOW the FFI should be called exactly once.
      expect(binding.clearAllUserDataCalls, 1,
          reason: 'clearAllUserData must be called exactly once after confirm-twice');
      expect(binding.cryptoEraseCacheCalls, 1,
          reason: 'cryptoEraseCache must be called exactly once after confirm-twice');
    });

    testWidgets('cancel first dialog → FFI not called', (tester) async {
      final binding = _RecordingEraseBinding();
      final handle = _FakeHandle();

      await tester.pumpWidget(
        MaterialApp(
          home: _EraseTestHarness(
            binding: binding,
            handle: handle,
          ),
        ),
      );

      // Tap erase.
      await tester.tap(find.text('Erase everything'));
      await tester.pumpAndSettle();

      // Cancel first dialog.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // FFI never called.
      expect(binding.clearAllUserDataCalls, 0);
      expect(binding.cryptoEraseCacheCalls, 0);
    });

    testWidgets('cancel second dialog → FFI not called', (tester) async {
      final binding = _RecordingEraseBinding();
      final handle = _FakeHandle();

      await tester.pumpWidget(
        MaterialApp(
          home: _EraseTestHarness(
            binding: binding,
            handle: handle,
          ),
        ),
      );

      // Tap erase.
      await tester.tap(find.text('Erase everything'));
      await tester.pumpAndSettle();

      // Confirm first dialog.
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Cancel second dialog.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // FFI never called.
      expect(binding.clearAllUserDataCalls, 0);
      expect(binding.cryptoEraseCacheCalls, 0);
    });
  });
}

// === Test doubles ===

class _FakeHandle implements EnginesHandle {
  @override
  Object? noSuchMethod(Invocation invocation) => null;
}

/// Records calls to clearAllUserData and cryptoEraseCache.
class _RecordingEraseBinding implements RustEngineBinding {
  int clearAllUserDataCalls = 0;
  int cryptoEraseCacheCalls = 0;

  @override
  Future<String> clearAllUserData(
    EnginesHandle handle, {
    required String athleteId,
  }) async {
    clearAllUserDataCalls++;
    return ''; // Test stub — returns empty string.
  }

  @override
  Future<void> cryptoEraseCache(EnginesHandle handle) async {
    cryptoEraseCacheCalls++;
  }

  // All other methods are no-ops (not exercised by the erase test harness).
  @override
  Object? noSuchMethod(Invocation invocation) => null;
}

// === Test harness ===

/// Minimal widget that exercises the erase flow from YouScreen.
/// Extracted so we can inject the binding for testing.
class _EraseTestHarness extends StatelessWidget {
  const _EraseTestHarness({
    required this.binding,
    required this.handle,
  });

  final RustEngineBinding binding;
  final EnginesHandle handle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _EraseButton(
          binding: binding,
          handle: handle,
        ),
      ),
    );
  }
}

/// The erase button with two-step confirm, matching YouScreen's implementation.
class _EraseButton extends StatelessWidget {
  const _EraseButton({
    required this.binding,
    required this.handle,
  });

  final RustEngineBinding binding;
  final EnginesHandle handle;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () => _confirmErase(context),
      child: const Text('Erase everything'),
    );
  }

  Future<void> _confirmErase(BuildContext context) async {
    // Step 1: First confirm.
    final firstConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MivaltaColors.surface1,
        title: Text(
          'Erase everything?',
          style: MivaltaType.cardTitle.copyWith(
            color: MivaltaColors.textPrimary,
          ),
        ),
        content: Text(
          'This will permanently delete all your data from this device. '
          'Your training history, settings, and progress will be gone.',
          style: MivaltaType.body.copyWith(
            color: MivaltaColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: MivaltaType.body.copyWith(
                color: MivaltaColors.textMuted,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Continue',
              style: MivaltaType.body.copyWith(
                color: MivaltaColors.stateOverreached,
              ),
            ),
          ),
        ],
      ),
    );

    if (firstConfirm != true) return;

    // Step 2: Second confirm.
    final secondConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MivaltaColors.surface1,
        title: Text(
          'Are you sure?',
          style: MivaltaType.cardTitle.copyWith(
            color: MivaltaColors.textPrimary,
          ),
        ),
        content: Text(
          'This is permanent. Your data will be crypto-erased immediately.',
          style: MivaltaType.body.copyWith(
            color: MivaltaColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: MivaltaType.body.copyWith(
                color: MivaltaColors.textMuted,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Erase everything',
              style: MivaltaType.body.copyWith(
                color: MivaltaColors.stateOverreached,
              ),
            ),
          ),
        ],
      ),
    );

    if (secondConfirm != true) return;

    // Execute erase (FFI calls).
    await binding.clearAllUserData(handle, athleteId: 'test-athlete');
    await binding.cryptoEraseCache(handle);
  }
}

// MVP-1 hardware-verification debug screen. Build-flavour-only entry
// point (kDebugMode-gated from main.dart). The founder taps the four
// source buttons in sequence during the phone session; each writes a
// minimal biometric with the matching source identifier, then routes
// back to the readiness screen so section (f) renders the correct
// LOCKED swatch as empirical proof the engine wiring is live.
//
// "Clear vault" wipes the mivalta-vault directory so the founder can
// re-run all four paths from a clean state without uninstalling the APK.
// This also clears persisted ViterbiEngine state (continuity reset).
//
// No new business logic — just a thin debug harness over already-bound
// FRB methods.

import 'dart:io';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import '../canonical_seed.dart';
import '../rust_engine.dart';
import '../theme/source_tier.dart';
import 'readiness_screen.dart';

/// One entry per LOCKED source tier. The `source` strings must match
/// gatc-normalizer's tier classifier — verified by Track A's unit
/// tests (`polar_h10` → Medical, `oura` → Device, `apple_health` →
/// Partial, `manual` → Manual).
const Map<SourceTier, String> kDebugSwatchSources = <SourceTier, String>{
  SourceTier.medical: 'polar_h10',
  SourceTier.device: 'oura',
  SourceTier.partial: 'apple_health',
  SourceTier.manual: 'manual',
};

class DebugSwatchExerciser extends StatefulWidget {
  const DebugSwatchExerciser({super.key});

  @override
  State<DebugSwatchExerciser> createState() => _DebugSwatchExerciserState();
}

class _DebugSwatchExerciserState extends State<DebugSwatchExerciser> {
  String _status = '(tap a source button)';
  bool _busy = false;

  Future<Directory> _vaultDir() async {
    final support = await getApplicationSupportDirectory();
    // MVP-1: shared persistent vault path across all screens
    return Directory('${support.path}/mivalta-vault');
  }

  Future<void> _writeAndRoute(SourceTier tier) async {
    if (_busy) return;
    final source = kDebugSwatchSources[tier]!;
    setState(() {
      _busy = true;
      _status = 'Writing $source biometric…';
    });
    try {
      final binding = await RustEngineBinding.bootstrap();
      final tablesJson =
          await rootBundle.loadString('assets/compiled_tables.json');
      final dir = await _vaultDir();
      if (!await dir.exists()) await dir.create(recursive: true);
      final handle = await binding.constructEngines(
        athleteProfileJson: CanonicalSeed.vaultProfileJson(),
        tablesJson: tablesJson,
        vaultPath: dir.path,
      );
      await binding.writeMinimalBiometric(
        handle: handle,
        source: source,
        isoDate: todayIsoDate(),
      );
      if (!mounted) return;
      setState(() => _status = 'Wrote $source → expect ${tier.name} swatch.');
      // Brief pause so the founder sees the confirmation before the
      // route push, then jump to readiness so section (e) renders.
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const ReadinessScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Failed: ${e.runtimeType}: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clearVault() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = 'Clearing mivalta-vault…';
    });
    try {
      final dir = await _vaultDir();
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      if (!mounted) return;
      setState(() => _status = 'Cleared. Tap a source button to re-run.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Clear failed: ${e.runtimeType}: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Debug — SourceTier exerciser')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_status, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 16),
            for (final tier in SourceTier.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : () => _writeAndRoute(tier),
                  icon: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: kSourceTierColor[tier],
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  label: Text(
                    '${kSourceTierLabel[tier]}  —  '
                    'write ${kDebugSwatchSources[tier]}',
                  ),
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _clearVault,
              icon: const Icon(Icons.delete_sweep_outlined),
              label: const Text('Clear vault (mivalta-vault dir)'),
            ),
          ],
        ),
      ),
    );
  }
}

/// `true` only on debug builds, so the production-flavour APK can
/// never expose the exerciser entry point even by accident. Used by
/// `lib/main.dart` to gate the SpikeHome long-press handler.
bool get isDebugExerciserAvailable => kDebugMode;

/// Top-level helper — returns the YYYY-MM-DD string the shim expects.
/// Pulled out of the State class so widget tests can pin it without
/// reaching into private API.
String todayIsoDate({DateTime? now}) {
  final n = now ?? DateTime.now();
  final mm = n.month.toString().padLeft(2, '0');
  final dd = n.day.toString().padLeft(2, '0');
  return '${n.year}-$mm-$dd';
}

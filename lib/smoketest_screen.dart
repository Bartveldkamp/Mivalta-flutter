// Day-3 real-data round-trip screen. Three Cards: canonical seed,
// rust-engine outputs (five FRB calls), V10.1 chat response. All
// rendered as-is. On error, the relevant Card shows the error inline
// with a red icon. No assertions, no fallbacks.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'package:path_provider/path_provider.dart';

import 'canonical_seed.dart';
import 'rust_engine.dart';

class _Results {
  String? readiness, fatigueState, zoneCap, workout, vault;
  String? engineError, llmReply, llmError;
}

class SmoketestScreen extends StatefulWidget {
  const SmoketestScreen({super.key});
  @override
  State<SmoketestScreen> createState() => _SmoketestScreenState();
}

class _SmoketestScreenState extends State<SmoketestScreen> {
  bool _running = false;
  _Results? _r;

  Future<void> _run() async {
    // Capture a local non-null snapshot of the result accumulator before
    // any await — across the multiple await points below, `_r` is
    // nullable on the State and could be reassigned. Operating on a
    // local `r` closes the reentrancy window the Day-3 review flagged.
    final r = _Results();
    setState(() {
      _running = true;
      _r = r;
    });

    final profileJson = CanonicalSeed.vaultProfileJson();
    try {
      final binding = await RustEngineBinding.bootstrap();
      final tablesJson =
          await rootBundle.loadString('assets/compiled_tables.json');
      final support = await getApplicationSupportDirectory();
      final vaultDir = Directory('${support.path}/day3-vault');
      if (!await vaultDir.exists()) await vaultDir.create(recursive: true);
      final handle = await binding.constructEngines(
        athleteProfileJson: profileJson,
        tablesJson: tablesJson,
        vaultPath: vaultDir.path,
      );
      r.readiness = await binding.readinessScore(handle);
      r.fatigueState = await binding.viterbiFatigueState(handle);
      r.zoneCap = await binding.zoneCapWithAdvisories(handle);
      r.workout = await binding.recommendWorkout(handle);
      r.vault = await binding.vaultSnapshot(handle);
    } catch (e) {
      r.engineError = '${e.runtimeType}: $e';
    }

    try {
      r.llmReply = await _runLlm();
    } catch (e) {
      r.llmError = '${e.runtimeType}: $e';
    }

    if (!mounted) return;
    setState(() => _running = false);
  }

  /// Reuses the Day-1 GGUF. We do NOT re-download here — the
  /// V10.1 spike screen owns that path; missing GGUF surfaces as a
  /// clear error in section C.
  Future<String> _runLlm() async {
    final support = await getApplicationSupportDirectory();
    final modelFile = File('${support.path}/josi-v10-1-q4_k_m.gguf');
    if (!await modelFile.exists()) {
      throw StateError(
        'V10.1 GGUF not present at ${modelFile.path}. '
        'Open the V10.1 spike screen first to download + verify.',
      );
    }
    final engine = await LlamaEngine.spawn(
      libraryPath: 'libllama.so',
      modelParams: ModelParams(path: modelFile.path),
      contextParams: const ContextParams(nCtx: 2048),
    );
    try {
      final session = await engine.createSession();
      try {
        final buf = StringBuffer();
        await for (final event in session.generate(
          prompt: 'Should I train today?', addSpecial: true, maxTokens: 256,
        )) {
          if (event is TokenEvent) buf.write(event.text);
          if (event is DoneEvent && event.trailingText.isNotEmpty) {
            buf.write(event.trailingText);
          }
        }
        return buf.toString();
      } finally { await session.dispose(); }
    } finally { await engine.dispose(); }
  }

  Widget _section(String title, List<Widget> body) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...body,
        ],
      ),
    ),
  );

  Widget _err(BuildContext context, String msg) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(Icons.error, color: Theme.of(context).colorScheme.error),
      const SizedBox(width: 8),
      Expanded(child: SelectableText(msg)),
    ],
  );

  Widget _kv(String label, String? body) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        SelectableText(body ?? '(missing)'),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final r = _r;
    final profileJson = CanonicalSeed.vaultProfileJson();
    return Scaffold(
      appBar: AppBar(title: const Text('Day 3 — real-data smoketest')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: ListView(children: [
          FilledButton.icon(
            onPressed: _running ? null : _run,
            icon: const Icon(Icons.play_arrow),
            label: Text(_running ? 'Running…' : 'Run smoketest'),
          ),
          const SizedBox(height: 12),
          _section('A. Seed (from android-client smoketest)', [
            SelectableText(profileJson),
            const SizedBox(height: 8),
            Text(
              'Source: mivalta-android-client SmoketestApp.kt + VaultProfileMapper.kt @ ${CanonicalSeed.androidClientPinnedSha}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ]),
          const SizedBox(height: 12),
          _section('B. Rust engine (real call, output as-is)',
            r == null
                ? const [Text('(tap Run smoketest)')]
                : r.engineError != null
                    ? [_err(context, r.engineError!)]
                    : [
                      _kv('readiness_score', r.readiness),
                      _kv('viterbi_fatigue_state', r.fatigueState),
                      _kv('zone_cap_with_advisories', r.zoneCap),
                      _kv('recommend_workout', r.workout),
                      _kv('vault_snapshot', r.vault),
                    ],
          ),
          const SizedBox(height: 12),
          _section('C. Josi V10.1 (real prompt, response as-is)', [
            const Text('Prompt: "Should I train today?"'),
            const SizedBox(height: 8),
            if (r == null)
              const Text('(tap Run smoketest)')
            else if (r.llmError != null)
              _err(context, r.llmError!)
            else
              SelectableText(r.llmReply ?? ''),
          ]),
        ]),
      ),
    );
  }
}

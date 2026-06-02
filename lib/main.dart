// MiValta MVP-1 entry point. Production app with engine-connected UI.
//
// Default home is ReadinessScreen — the three-zone PULL layout driven
// by the Rust engine via flutter_rust_bridge.
//
// The V10.1 LLM spike screen is now a kDebugMode-only route, accessed
// via long-press on the app title (same entry point as the SourceTier
// debug exerciser). The llama_cpp_dart dep is retained for the
// deferred grounded-Josi phase (PR-F).
//
// See docs/MVP1_BUILD_BRIEF.md for the current milestone scope.

import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'package:path_provider/path_provider.dart';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import 'hw_telemetry.dart';
import 'rust_engine.dart';
import 'screens/debug_swatch_exerciser.dart';
import 'screens/readiness_screen.dart';

const String _modelUrl =
    'http://144.76.62.249/models/josi-v10-1-q4_k_m.gguf';
const String _modelFile = 'josi-v10-1-q4_k_m.gguf';
const String _modelSha256 =
    '8bb9f19deb49990fb6e5a22028624786c850f4ae0eefde8f30d99463c40adfdb';
const int _expectedBytes = 1107408608;
const String _defaultPrompt = 'Should I train today?';

void main() {
  runApp(const MivaltaApp());
}

class MivaltaApp extends StatelessWidget {
  const MivaltaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MiValta',
      home: const ReadinessScreen(),
      routes: {
        // V10.1 LLM spike screen — kDebugMode-only, accessed via debug menu
        '/v10-spike': (_) => const V10SpikeScreen(),
      },
    );
  }
}

// =============================================================================
// V10.1 LLM SPIKE — kDebugMode-only (access via ReadinessScreen debug menu)
// =============================================================================
// Retained for the deferred grounded-Josi phase (PR-F). The model download
// and llama_cpp_dart binding are intact; the screen is just not the default
// route anymore.

enum _ModelStage { checking, downloading, verifying, ready, error }

/// V10.1 LLM spike screen (kDebugMode-only). Kept for the deferred
/// grounded-Josi phase (PR-F). Access from ReadinessScreen debug menu.
class V10SpikeScreen extends StatefulWidget {
  const V10SpikeScreen({super.key});

  @override
  State<V10SpikeScreen> createState() => _V10SpikeScreenState();
}

class _V10SpikeScreenState extends State<V10SpikeScreen> {
  final TextEditingController _controller =
      TextEditingController(text: _defaultPrompt);

  _ModelStage _stage = _ModelStage.checking;
  String _statusDetail = 'Locating model...';
  String _output = '';
  int? _ttftMs;
  int? _totalMs;
  bool _running = false;

  LlamaEngine? _engine;
  String? _modelPath;

  // Day-7 hardware-verification telemetry. Filled after each Run.
  int? _peakPssKb;
  String _deviceModel = '';
  String _osRelease = '';
  String _apkSha = '';

  // Day 2 rust-engine bridge state — independent of the V10.1 model
  // path. `_engineHello` is `null` while the bridge is still booting,
  // an error string if `RustLib.init()` failed, or the engine's
  // canonical smoke-test reply (`"hello"`) once the round-trip
  // succeeded.
  String? _engineHello;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrapModel());
    unawaited(_bootstrapEngineBridge());
    unawaited(_bootstrapTelemetry());
  }

  Future<void> _bootstrapTelemetry() async {
    final results = await Future.wait([
      HwTelemetry.deviceModel(),
      HwTelemetry.osRelease(),
      HwTelemetry.apkSha256(),
    ]);
    if (!mounted) return;
    setState(() {
      _deviceModel = results[0];
      _osRelease = results[1];
      _apkSha = results[2];
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    unawaited(_engine?.dispose());
    super.dispose();
  }

  Future<void> _bootstrapEngineBridge() async {
    try {
      final binding = await RustEngineBinding.bootstrap();
      final reply = await binding.hello();
      if (!mounted) return;
      setState(() => _engineHello = reply);
    } catch (e) {
      if (!mounted) return;
      setState(() => _engineHello = 'error: $e');
    }
  }

  Future<void> _bootstrapModel() async {
    try {
      final supportDir = await getApplicationSupportDirectory();
      final file = File('${supportDir.path}/$_modelFile');
      _modelPath = file.path;

      if (await file.exists() && await file.length() == _expectedBytes) {
        setState(() {
          _stage = _ModelStage.verifying;
          _statusDetail = 'Verifying SHA-256 of cached model...';
        });
        if (await _sha256Of(file) == _modelSha256) {
          setState(() {
            _stage = _ModelStage.ready;
            _statusDetail = 'Model verified at ${file.path}';
          });
          return;
        }
        // Cached file is the right size but wrong hash — delete and re-download.
        await file.delete();
      }

      setState(() {
        _stage = _ModelStage.downloading;
        _statusDetail =
            'Downloading V10.1 GGUF (~${(_expectedBytes / (1024 * 1024)).toStringAsFixed(0)} MB)...';
      });
      await _downloadModel(file);

      setState(() {
        _stage = _ModelStage.verifying;
        _statusDetail = 'Verifying SHA-256 of downloaded model...';
      });
      final actual = await _sha256Of(file);
      if (actual != _modelSha256) {
        // LOCKED: refuse to load a model whose hash does not match the
        // expected V10.1 artifact — see CLAUDE.md rule 6.
        await file.delete();
        setState(() {
          _stage = _ModelStage.error;
          _statusDetail =
              'SHA-256 mismatch. Expected $_modelSha256, got $actual';
        });
        return;
      }

      setState(() {
        _stage = _ModelStage.ready;
        _statusDetail = 'Model verified at ${file.path}';
      });
    } catch (e) {
      setState(() {
        _stage = _ModelStage.error;
        _statusDetail = 'Model bootstrap failed: $e';
      });
    }
  }

  Future<void> _downloadModel(File target) async {
    final req = http.Request('GET', Uri.parse(_modelUrl));
    final res = await http.Client().send(req);
    if (res.statusCode != 200) {
      throw HttpException('HTTP ${res.statusCode} from $_modelUrl');
    }
    final sink = target.openWrite();
    try {
      await res.stream.pipe(sink);
    } finally {
      await sink.close();
    }
  }

  Future<String> _sha256Of(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }

  Future<LlamaEngine> _ensureEngine() async {
    final cached = _engine;
    if (cached != null) return cached;
    final path = _modelPath;
    if (path == null) {
      throw StateError('Model path unset before engine bootstrap.');
    }
    // On Android the AAR's jniLibs are unpacked next to the app's
    // native libs, so basename resolution finds libllama.so.
    final engine = await LlamaEngine.spawn(
      libraryPath: 'libllama.so',
      modelParams: ModelParams(path: path),
      contextParams: const ContextParams(nCtx: 2048),
    );
    _engine = engine;
    return engine;
  }

  Future<void> _runOnce() async {
    if (_running || _stage != _ModelStage.ready) return;
    setState(() {
      _running = true;
      _output = '';
      _ttftMs = null;
      _totalMs = null;
    });
    setState(() => _peakPssKb = null);
    final stopwatch = Stopwatch()..start();
    try {
      final engine = await _ensureEngine();
      // Day-7: wrap the generate stream in HwTelemetry.peakPssDuring
      // so the platform channel polls PSS every 250ms across the run.
      final telemetry = await HwTelemetry.peakPssDuring(() async {
        final session = await engine.createSession();
        try {
          final buf = StringBuffer();
          await for (final event in session.generate(
            prompt: _controller.text,
            addSpecial: true,
            maxTokens: 256,
          )) {
            switch (event) {
              case TokenEvent():
                _ttftMs ??= stopwatch.elapsedMilliseconds;
                buf.write(event.text);
                setState(() => _output = buf.toString());
              case ShiftEvent():
                break;
              case DoneEvent():
                if (event.trailingText.isNotEmpty) {
                  buf.write(event.trailingText);
                }
                setState(() => _output = buf.toString());
            }
          }
          setState(() => _totalMs = stopwatch.elapsedMilliseconds);
          return null;
        } finally {
          await session.dispose();
        }
      });
      setState(() => _peakPssKb = telemetry.peakPssKb);
    } catch (e) {
      setState(() => _output = 'Generation failed: $e');
    } finally {
      stopwatch.stop();
      setState(() => _running = false);
    }
  }

  /// Six-line copyable telemetry block, formatted to paste verbatim
  /// into docs/spike/HARDWARE_VERIFICATION_RESULTS.md.
  String _telemetryBlock() {
    String ms(int? v) => v?.toString() ?? '—';
    String kb(int? v) => (v == null || v < 0) ? '—' : v.toString();
    final shaShort =
        _apkSha.length >= 12 ? _apkSha.substring(0, 12) : (_apkSha.isEmpty ? '—' : _apkSha);
    final deviceLine = (_deviceModel.isEmpty && _osRelease.isEmpty)
        ? 'Device: —'
        : 'Device: $_deviceModel / Android $_osRelease';
    return 'TTFT:   ${ms(_ttftMs)} ms\n'
        'Total:  ${ms(_totalMs)} ms\n'
        'Peak:   ${kb(_peakPssKb)} KB PSS\n'
        'Model:  josi-v10-1-q4_k_m.gguf\n'
        '$deviceLine\n'
        'Build:  $shaShort';
  }

  Future<void> _copyTelemetry() async {
    await Clipboard.setData(ClipboardData(text: _telemetryBlock()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Telemetry copied to clipboard'),
        duration: Duration(milliseconds: 800),
      ),
    );
  }

  void _openDebugExerciser() {
    if (!isDebugExerciserAvailable) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const DebugSwatchExerciser()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canRun = _stage == _ModelStage.ready && !_running;
    return Scaffold(
      appBar: AppBar(
        // Long-press the title to open the SourceTier debug exerciser.
        // kDebugMode-gated so production builds never expose the entry
        // point even if a tester finds it.
        title: GestureDetector(
          onLongPress: kDebugMode ? _openDebugExerciser : null,
          child: const Text('V10.1 LLM Debug (spike)'),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Day 2 status line — rendered above the V10.1 status so
            // the rust-engine bridge result is visible regardless of
            // model-download state.
            Text('Engine hello: ${_engineHello ?? '(loading)'}'),
            const SizedBox(height: 4),
            Text('Status: ${_stage.name} — $_statusDetail'),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Prompt',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: canRun ? _runOnce : null,
              child: Text(_running ? 'Running...' : 'Run'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text('TTFT: ${_ttftMs?.toString() ?? '-'} ms'),
                ),
                Expanded(
                  child: Text('Total: ${_totalMs?.toString() ?? '-'} ms'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Output:'),
            Expanded(
              child: SingleChildScrollView(
                child: SelectableText(
                  _output.isEmpty ? '(no output yet)' : _output,
                ),
              ),
            ),
            // Day-7 hardware-verification telemetry block. Tap to copy
            // — the formatted text is the verbatim shape the results
            // doc expects (TTFT / Total / Peak / Model / Device / Build).
            const SizedBox(height: 12),
            InkWell(
              onTap: _copyTelemetry,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SelectableText(
                        _telemetryBlock(),
                        style: const TextStyle(
                            fontFamily: 'monospace', fontSize: 12),
                      ),
                    ),
                    const Icon(Icons.copy, size: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

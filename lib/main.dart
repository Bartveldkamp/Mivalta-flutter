// V10.1 Flutter perf spike (Day 1).
//
// Single screen: TextField → Run button → streamed token output, with two
// latency labels (TTFT, Total) read from the llama_cpp_dart
// `GenerationEvent` stream. First launch downloads the V10.1 GGUF from
// the model host and verifies its sha256 before letting the engine load
// it. Network is locked to that one host via res/xml/network_security_config.xml.
//
// See docs/V10_1_FLUTTER_PERF_SPIKE.md for the why and the acceptance bar.

import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:llama_cpp_dart/llama_cpp_dart.dart';
import 'package:path_provider/path_provider.dart';

const String _modelUrl =
    'http://144.76.62.249/models/josi-v10-1-q4_k_m.gguf';
const String _modelFile = 'josi-v10-1-q4_k_m.gguf';
const String _modelSha256 =
    '8bb9f19deb49990fb6e5a22028624786c850f4ae0eefde8f30d99463c40adfdb';
const int _expectedBytes = 1107408608;
const String _defaultPrompt = 'Should I train today?';

void main() {
  runApp(const PerfSpikeApp());
}

class PerfSpikeApp extends StatelessWidget {
  const PerfSpikeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'MiValta V10.1 Spike',
      home: SpikeHome(),
    );
  }
}

enum _ModelStage { checking, downloading, verifying, ready, error }

class SpikeHome extends StatefulWidget {
  const SpikeHome({super.key});

  @override
  State<SpikeHome> createState() => _SpikeHomeState();
}

class _SpikeHomeState extends State<SpikeHome> {
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

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrapModel());
  }

  @override
  void dispose() {
    _controller.dispose();
    unawaited(_engine?.dispose());
    super.dispose();
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
    final stopwatch = Stopwatch()..start();
    try {
      final engine = await _ensureEngine();
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
      } finally {
        await session.dispose();
      }
    } catch (e) {
      setState(() => _output = 'Generation failed: $e');
    } finally {
      stopwatch.stop();
      setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canRun = _stage == _ModelStage.ready && !_running;
    return Scaffold(
      appBar: AppBar(title: const Text('MiValta V10.1 Spike')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
          ],
        ),
      ),
    );
  }
}

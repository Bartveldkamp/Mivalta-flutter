// D1-B — BLE heart-rate strap pairing + sensor check.
//
// The sanctioned "Done =" for the deferred BLE capture (NEXT_WORK item 1): a
// pairing / sensor-check screen that drives BleHrService.scan → startSession →
// stopSessionAndIngest, behind a runtime Bluetooth permission request. It is
// self-contained (bootstraps its own engine handle, the same pattern as
// session_reveal_screen) so it can be reached from the workout entry without
// threading binding/handle through the nav.
//
// Honest absence throughout: no permission → clear message, nothing captured;
// no strap found → "No strap found"; a session with zero readings ingests
// NOTHING (BleHrService.stopSessionAndIngest returns null) — never a fake HR.

import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:permission_handler/permission_handler.dart';

import '../rust_engine.dart';
import '../services/ble/ble_hr_service.dart';
import '../services/ble/ble_transport.dart';
import '../services/ble/flutter_blue_transport.dart';
import '../services/ingest_adapter.dart';
import '../services/profile_service.dart';
import '../theme/tokens.dart';

enum _PairPhase { permission, scanning, connected, done }

/// Builds the [BleHrService] the screen drives. In production this is null and
/// the screen self-bootstraps a real engine handle + [FlutterBlueTransport]
/// radio; tests inject a service over a fake transport + fake binding so the
/// outcome→copy mapping is exercised headless (no radio, no native FRB lib).
typedef BleServiceBuilder = Future<BleHrService?> Function();

class SensorCheckScreen extends StatefulWidget {
  const SensorCheckScreen({
    super.key,
    this.serviceBuilder,
    this.skipPermissionRequest = false,
    this.binding,
    this.handle,
  });

  /// Test seam: when non-null, used instead of self-bootstrapping the engine.
  final BleServiceBuilder? serviceBuilder;

  /// BS-017 test seam: injected engine binding. Null in prod → bootstrap().
  final RustEngineBinding? binding;

  /// BS-017 test seam: injected engine handle. Null in prod → construct below.
  final EnginesHandle? handle;

  /// Test seam: skip the runtime Bluetooth permission request (which needs a
  /// platform channel unavailable in a headless widget test). Production leaves
  /// this false so the real ask still fires at first pairing.
  final bool skipPermissionRequest;

  @override
  State<SensorCheckScreen> createState() => _SensorCheckScreenState();
}

class _SensorCheckScreenState extends State<SensorCheckScreen> {
  BleHrService? _service;
  StreamSubscription<BleDevice>? _scanSub;
  Timer? _readingPoll;

  _PairPhase _phase = _PairPhase.permission;
  final List<BleDevice> _found = [];
  String? _connectedName;
  int _readingCount = 0;
  String? _message;
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    _bootstrapAndRequest();
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _readingPoll?.cancel();
    // Fire-and-forget teardown — never leave a strap connected.
    _service?.abort();
    super.dispose();
  }

  /// Bootstrap the engine handle (for ingest) + request BLE permission.
  Future<void> _bootstrapAndRequest() async {
    try {
      // Test seam: skip the engine bootstrap when a service is injected.
      final builder = widget.serviceBuilder;
      if (builder != null) {
        _service = await builder();
        if (!mounted) return;
        await _requestAndScan();
        return;
      }
      final binding = widget.binding ?? await RustEngineBinding.bootstrap();
      final profileJson = await ProfileService.loadProfile();
      if (profileJson == null) {
        setState(() => _message = 'Finish setup before pairing a strap.');
        return;
      }
      final tablesJson = await rootBundle.loadString(
        'assets/compiled_tables.json',
      );
      final vaultPath = await ProfileService.getVaultPath();
      final hasState = await binding.hasPersistedState(
        athleteProfileJson: profileJson,
        vaultPath: vaultPath,
      );
      EnginesHandle handle;
      if (widget.handle != null) {
        handle = widget.handle!;
      } else if (hasState) {
        final stateJson = await binding.readPersistedState(
          athleteProfileJson: profileJson,
          vaultPath: vaultPath,
        );
        handle = stateJson != null
            ? await binding.constructEnginesFromState(
                athleteProfileJson: profileJson,
                tablesJson: tablesJson,
                vaultPath: vaultPath,
                viterbiStateJson: stateJson,
              )
            : await binding.constructEnginesFresh(
                athleteProfileJson: profileJson,
                tablesJson: tablesJson,
                vaultPath: vaultPath,
              );
      } else {
        handle = await binding.constructEnginesFresh(
          athleteProfileJson: profileJson,
          tablesJson: tablesJson,
          vaultPath: vaultPath,
        );
      }
      if (!mounted) return;
      _service = BleHrService(
        transport: FlutterBlueTransport(),
        adapter: IngestAdapter(binding: binding, handle: handle),
      );
      await _requestAndScan();
    } catch (e) {
      if (kDebugMode) debugPrint('sensor-check bootstrap failed: $e');
      if (mounted) {
        setState(() => _message = 'Could not start pairing. Try again.');
      }
    }
  }

  Future<void> _requestAndScan() async {
    if (widget.skipPermissionRequest) {
      _startScan();
      return;
    }
    // Runtime Bluetooth permission (Android 12+ scan/connect; iOS peripheral).
    final scan = await Permission.bluetoothScan.request();
    final connect = await Permission.bluetoothConnect.request();
    if (!scan.isGranted || !connect.isGranted) {
      if (mounted) {
        setState(() {
          _permissionDenied = true;
          _message = 'Bluetooth permission is needed to find your strap.';
        });
      }
      return;
    }
    _startScan();
  }

  void _startScan() {
    final service = _service;
    if (service == null) return;
    setState(() {
      _phase = _PairPhase.scanning;
      _found.clear();
      _message = null;
    });
    _scanSub?.cancel();
    _scanSub = service.scan().listen(
      (device) {
        if (!mounted) return;
        if (_found.every((d) => d.id != device.id)) {
          setState(() => _found.add(device));
        }
      },
      onError: (Object e) {
        if (mounted) setState(() => _message = 'Scan failed. Try again.');
      },
    );
  }

  Future<void> _connect(BleDevice device) async {
    final service = _service;
    if (service == null) return;
    // Stop receiving scan results (cleanup — not awaited, the same rule as
    // BleHrService.stopSessionAndIngest: awaiting a subscription cancel must
    // never gate the connect path).
    unawaited(_scanSub?.cancel());
    _scanSub = null;
    try {
      await service.startSession(device.id);
      if (!mounted) return;
      setState(() {
        _phase = _PairPhase.connected;
        _connectedName = device.name;
        _readingCount = 0;
      });
      // Poll the live reading count for the on-screen witness (display only).
      _readingPoll = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _readingCount = service.readingCount);
      });
    } catch (e) {
      if (mounted) setState(() => _message = 'Could not connect. Try again.');
    }
  }

  Future<void> _saveSession() async {
    final service = _service;
    if (service == null) return;
    _readingPoll?.cancel();
    final today = DateTime.now().toIso8601String().split('T').first;
    final result = await service.stopSessionAndIngest(date: today);
    if (!mounted) return;
    setState(() {
      _phase = _PairPhase.done;
      _message = result == null
          ? 'No heart-rate readings were captured.'
          : 'Session saved.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MivaltaColors.surfaceBackground,
      appBar: AppBar(
        backgroundColor: MivaltaColors.surfaceBackground,
        elevation: 0,
        title: const Text('Heart-rate strap'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(MivaltaSpace.x4),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_permissionDenied) {
      return _centered(
        _message ?? 'Bluetooth permission is needed to find your strap.',
        action: ('Open settings', openAppSettings),
      );
    }
    switch (_phase) {
      case _PairPhase.permission:
        return _centered(_message ?? 'Preparing…');
      case _PairPhase.scanning:
        return _buildScanList();
      case _PairPhase.connected:
        return _buildConnected();
      case _PairPhase.done:
        return _centered(
          _message ?? 'Done.',
          action: ('Done', () => Navigator.of(context).pop()),
        );
    }
  }

  Widget _buildScanList() {
    if (_found.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: MivaltaColors.stateProductive,
          ),
          const SizedBox(height: MivaltaSpace.x4),
          Text(
            'Searching for your heart-rate strap…',
            style: MivaltaType.small.copyWith(
              color: MivaltaColors.textSecondary,
            ),
          ),
        ],
      );
    }
    return ListView.separated(
      itemCount: _found.length,
      separatorBuilder: (_, _) => const SizedBox(height: MivaltaSpace.x2),
      itemBuilder: (_, i) {
        final d = _found[i];
        return ListTile(
          leading: const Icon(
            Icons.monitor_heart,
            color: MivaltaColors.stateProductive,
          ),
          title: Text(d.name.isEmpty ? 'Heart-rate strap' : d.name),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _connect(d),
        );
      },
    );
  }

  Widget _buildConnected() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _connectedName?.isNotEmpty == true
              ? 'Connected · $_connectedName'
              : 'Connected',
          textAlign: TextAlign.center,
          style: MivaltaType.small.copyWith(
            color: MivaltaColors.textSecondary,
          ),
        ),
        const SizedBox(height: MivaltaSpace.x3),
        Text(
          '$_readingCount',
          textAlign: TextAlign.center,
          style: MivaltaType.hero.copyWith(
            color: MivaltaColors.stateProductive,
          ),
        ),
        Text(
          'readings captured',
          textAlign: TextAlign.center,
          style: MivaltaType.small.copyWith(color: MivaltaColors.textMuted),
        ),
        const SizedBox(height: MivaltaSpace.x6),
        FilledButton(
          onPressed: _saveSession,
          child: const Text('Save session'),
        ),
        const SizedBox(height: MivaltaSpace.x2),
        TextButton(
          onPressed: () async {
            await _service?.abort();
            if (mounted) Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Widget _centered(String text, {(String, VoidCallback)? action}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: MivaltaType.small.copyWith(
              color: MivaltaColors.textSecondary,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: MivaltaSpace.x4),
            FilledButton(onPressed: action.$2, child: Text(action.$1)),
          ],
        ],
      ),
    );
  }
}

// Session Live Screen — BS-010
//
// Live display: near-black canvas, elapsed time (tabular), ONE big number (HR
// or pace), secondary row (distance, avg). Honest "—" for absent sensors.
// No zone ring this pass (G4 blocked).
// Controls: PAUSE (44px+), long-press END.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../services/session_recorder.dart';
import '../theme/tokens.dart';
import 'session_reveal_screen.dart';

/// Live session display — recorder + display only.
class SessionLiveScreen extends StatefulWidget {
  const SessionLiveScreen({super.key, required this.sport});

  final String sport;

  @override
  State<SessionLiveScreen> createState() => _SessionLiveScreenState();
}

class _SessionLiveScreenState extends State<SessionLiveScreen> {
  late final SessionRecorder _recorder;

  // Stream subscriptions.
  StreamSubscription<int>? _elapsedSub;
  StreamSubscription<LiveSensorData>? _sensorSub;
  StreamSubscription<SessionState>? _stateSub;

  // Current state.
  int _elapsed = 0;
  LiveSensorData _sensors = const LiveSensorData();
  SessionState _state = SessionState.idle;

  @override
  void initState() {
    super.initState();

    // Enable wakelock — screen stays on during session.
    WakelockPlus.enable();

    // Create and start recorder.
    _recorder = SessionRecorder(sport: widget.sport);

    _elapsedSub = _recorder.elapsedStream.listen((e) {
      setState(() => _elapsed = e);
    });

    _sensorSub = _recorder.sensorStream.listen((s) {
      setState(() => _sensors = s);
    });

    _stateSub = _recorder.stateStream.listen((s) {
      setState(() => _state = s);
    });

    // Start immediately.
    _recorder.start();
  }

  @override
  void dispose() {
    _elapsedSub?.cancel();
    _sensorSub?.cancel();
    _stateSub?.cancel();
    _recorder.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MivaltaColors.surfaceBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Recording indicator.
            _buildRecordingIndicator(),

            // Elapsed time (big, tabular).
            _buildElapsedTime(),

            // Honest-absence zone message.
            _buildZoneMessage(),

            const Spacer(),

            // Primary metric (HR if available, else pace).
            _buildPrimaryMetric(),

            const SizedBox(height: MivaltaSpace.x5),

            // Secondary metrics row.
            _buildSecondaryMetrics(),

            const Spacer(),

            // Controls (pause/resume, end).
            _buildControls(),

            const SizedBox(height: MivaltaSpace.x6),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingIndicator() {
    final isPaused = _state == SessionState.paused;
    return Padding(
      padding: const EdgeInsets.all(MivaltaSpace.x4),
      child: Row(
        children: [
          // Pulsing recording dot.
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isPaused
                  ? MivaltaColors.stateAccumulated
                  : MivaltaColors.stateProductive,
            ),
          ),
          const SizedBox(width: MivaltaSpace.x2),
          Text(
            isPaused ? 'PAUSED' : 'RECORDING',
            style: MivaltaType.label.copyWith(
              color: isPaused
                  ? MivaltaColors.stateAccumulated
                  : MivaltaColors.stateProductive,
              fontSize: 11,
            ),
          ),
          const Spacer(),
          // Sport label.
          Text(
            widget.sport.toUpperCase(),
            style: MivaltaType.label.copyWith(
              color: MivaltaColors.textMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildElapsedTime() {
    final hours = _elapsed ~/ 3600;
    final minutes = (_elapsed % 3600) ~/ 60;
    final seconds = _elapsed % 60;

    final timeStr = hours > 0
        ? '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}'
        : '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Center(
      child: Text(
        timeStr,
        style: MivaltaType.display.copyWith(
          color: MivaltaColors.textPrimary,
          fontSize: 56,
          fontFeatures: const [
            FontFeature.tabularFigures(),
            FontFeature.liningFigures(),
          ],
        ),
      ),
    );
  }

  Widget _buildZoneMessage() {
    // G4 blocked — show honest message.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MivaltaSpace.x2),
      child: Text(
        'zones after the ride — on this build',
        style: MivaltaType.small.copyWith(
          color: MivaltaColors.textMuted,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildPrimaryMetric() {
    // Primary: HR if available, else pace.
    final hasHr = _sensors.hasHeartRate;
    final hasGps = _sensors.hasGps;

    String value;
    String label;

    if (hasHr) {
      value = _sensors.heartRate.toString();
      label = 'BPM';
    } else if (hasGps && _sensors.pace != null) {
      value = LiveSensorData.formatPace(_sensors.pace);
      label = 'MIN/KM';
    } else {
      // Honest absence.
      value = '—';
      label = hasGps ? 'BPM' : 'WAITING';
    }

    return Column(
      children: [
        Text(
          value,
          style: MivaltaType.hero.copyWith(
            color: MivaltaColors.textPrimary,
            fontSize: 72,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: MivaltaSpace.x1),
        Text(
          label,
          style: MivaltaType.label.copyWith(
            color: MivaltaColors.textMuted,
            fontSize: 12,
          ),
        ),
        // Honest absence explanation.
        if (!hasHr && !hasGps)
          Padding(
            padding: const EdgeInsets.only(top: MivaltaSpace.x2),
            child: Text(
              'no sensor connected',
              style: MivaltaType.small.copyWith(
                color: MivaltaColors.textMuted.withValues(alpha: 0.6),
                fontSize: 11,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSecondaryMetrics() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MivaltaSpace.x4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _SecondaryMetric(
            value: _sensors.distance != null
                ? _sensors.distance!.toStringAsFixed(2)
                : '—',
            label: 'KM',
          ),
          _SecondaryMetric(
            value: _sensors.avgSpeed != null
                ? _sensors.avgSpeed!.toStringAsFixed(1)
                : '—',
            label: 'AVG KM/H',
          ),
          _SecondaryMetric(
            value: _sensors.avgHeartRate?.toString() ?? '—',
            label: 'AVG HR',
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    final isPaused = _state == SessionState.paused;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: MivaltaSpace.x4),
      child: Row(
        children: [
          // Pause/Resume button.
          Expanded(
            child: SizedBox(
              height: 56,
              child: OutlinedButton.icon(
                onPressed: isPaused ? _recorder.resume : _recorder.pause,
                icon: Icon(
                  isPaused ? Icons.play_arrow : Icons.pause,
                  size: 20,
                ),
                label: Text(isPaused ? 'Resume' : 'Pause'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: MivaltaColors.textPrimary,
                  side: const BorderSide(
                    color: MivaltaColors.cardBorder,
                    width: 1,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(MivaltaRadii.md),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: MivaltaSpace.x3),

          // End button (long-press).
          Expanded(
            child: SizedBox(
              height: 56,
              child: _EndButton(onEnd: _endSession),
            ),
          ),
        ],
      ),
    );
  }

  void _endSession() {
    // Stop recording and get completed session.
    final completed = _recorder.stop();

    // TODO: Persist to vault via write_raw_observation.
    // The reveal screen will show the session data and try to fetch
    // engine analysis once vault persistence is wired.

    // Haptic feedback.
    HapticFeedback.mediumImpact();

    // Navigate to reveal screen (BS-011).
    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(
        builder: (context) => SessionRevealScreen(session: completed),
      ),
    );
  }
}

/// Secondary metric display.
class _SecondaryMetric extends StatelessWidget {
  const _SecondaryMetric({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: MivaltaType.metric.copyWith(
            color: MivaltaColors.textPrimary,
            fontSize: 24,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: MivaltaType.label.copyWith(
            color: MivaltaColors.textMuted,
            fontSize: 9,
          ),
        ),
      ],
    );
  }
}

/// End button with long-press requirement.
class _EndButton extends StatefulWidget {
  const _EndButton({required this.onEnd});

  final VoidCallback onEnd;

  @override
  State<_EndButton> createState() => _EndButtonState();
}

class _EndButtonState extends State<_EndButton> {
  bool _pressing = false;
  double _progress = 0;
  Timer? _holdTimer;

  static const _holdDuration = Duration(milliseconds: 800);

  void _onLongPressStart(LongPressStartDetails details) {
    setState(() => _pressing = true);

    const tickDuration = Duration(milliseconds: 50);
    final totalTicks = _holdDuration.inMilliseconds ~/ tickDuration.inMilliseconds;
    var ticks = 0;

    _holdTimer = Timer.periodic(tickDuration, (timer) {
      ticks++;
      setState(() => _progress = ticks / totalTicks);

      if (ticks >= totalTicks) {
        timer.cancel();
        widget.onEnd();
      }
    });
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    _holdTimer?.cancel();
    setState(() {
      _pressing = false;
      _progress = 0;
    });
  }

  void _onLongPressCancel() {
    _holdTimer?.cancel();
    setState(() {
      _pressing = false;
      _progress = 0;
    });
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: _onLongPressStart,
      onLongPressEnd: _onLongPressEnd,
      onLongPressCancel: _onLongPressCancel,
      child: Container(
        decoration: BoxDecoration(
          color: MivaltaColors.stateOverreached.withValues(alpha: 0.14),
          border: Border.all(
            color: MivaltaColors.stateOverreached.withValues(alpha: 0.35),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(MivaltaRadii.md),
        ),
        child: Stack(
          children: [
            // Progress fill on long-press.
            if (_pressing)
              ClipRRect(
                borderRadius: BorderRadius.circular(MivaltaRadii.md - 1),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: _progress,
                    heightFactor: 1,
                    child: Container(
                      color: MivaltaColors.stateOverreached.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),
            // Button content.
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.stop,
                    size: 20,
                    color: MivaltaColors.stateOverreached,
                  ),
                  const SizedBox(width: MivaltaSpace.x2),
                  Text(
                    _pressing ? 'Hold...' : 'End',
                    style: MivaltaType.cardTitle.copyWith(
                      color: MivaltaColors.stateOverreached,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

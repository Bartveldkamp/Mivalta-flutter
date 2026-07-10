// Session Start Screen — BS-010
//
// Start sheet: sport picker + big START.
// No goal/route/playlist clutter.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'sensor_check_screen.dart';
import 'session_live_screen.dart';

/// Start workout sheet — sport picker + START button.
class SessionStartScreen extends StatefulWidget {
  const SessionStartScreen({super.key});

  @override
  State<SessionStartScreen> createState() => _SessionStartScreenState();
}

class _SessionStartScreenState extends State<SessionStartScreen> {
  String? _selectedSport;

  // Sports list — profile sports would come first in production.
  // For now, the three coached sports + "Other".
  static const _sports = [
    _SportOption(
      id: 'cycling',
      name: 'Cycling',
      subtitle: 'Road, MTB, indoor',
      icon: Icons.directions_bike,
    ),
    _SportOption(
      id: 'running',
      name: 'Running',
      subtitle: 'Road, trail',
      icon: Icons.directions_run,
    ),
    _SportOption(
      id: 'walking',
      name: 'Walking',
      subtitle: 'Indoor, outdoor',
      icon: Icons.directions_walk,
    ),
    _SportOption(
      id: 'other',
      name: 'Other',
      subtitle: 'Recorded for load',
      icon: Icons.fitness_center,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MivaltaColors.surfaceBackground,
      appBar: AppBar(
        backgroundColor: MivaltaColors.surfaceBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: MivaltaColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Start',
          style: MivaltaType.titleL.copyWith(color: MivaltaColors.textPrimary),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: MivaltaSpace.x4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: MivaltaSpace.x3),

              // Section label.
              Text(
                'ACTIVITY',
                style: MivaltaType.label.copyWith(
                  color: MivaltaColors.textMuted,
                ),
              ),
              const SizedBox(height: MivaltaSpace.x2),

              // Sport grid.
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: MivaltaSpace.x3,
                  crossAxisSpacing: MivaltaSpace.x3,
                  childAspectRatio: 1.4,
                  children: _sports.map((sport) {
                    final selected = _selectedSport == sport.id;
                    return _SportTile(
                      sport: sport,
                      selected: selected,
                      onTap: () => setState(() => _selectedSport = sport.id),
                    );
                  }).toList(),
                ),
              ),

              // Contextual pairing entry (Screen-Workout step 2): connect a
              // BLE heart-rate strap before starting. Runtime Bluetooth
              // permission is requested inside SensorCheckScreen, not here, so
              // the ask lands at the first real device pairing — not at launch.
              Padding(
                padding: const EdgeInsets.only(bottom: MivaltaSpace.x2),
                child: TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (context) => const SensorCheckScreen(),
                    ),
                  ),
                  icon: const Icon(
                    Icons.monitor_heart_outlined,
                    size: 20,
                    color: MivaltaColors.stateProductive,
                  ),
                  label: Text(
                    'Connect heart-rate strap',
                    style: MivaltaType.small.copyWith(
                      color: MivaltaColors.stateProductive,
                    ),
                  ),
                ),
              ),

              // kDebugMode stamp.
              if (kDebugMode)
                Padding(
                  padding: const EdgeInsets.only(bottom: MivaltaSpace.x2),
                  child: Center(
                    child: Text(
                      'DEBUG BUILD',
                      style: MivaltaType.label.copyWith(
                        color: MivaltaColors.textMuted.withValues(alpha: 0.5),
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),

              // START button.
              Padding(
                padding: const EdgeInsets.only(bottom: MivaltaSpace.x6),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _selectedSport != null ? _startSession : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedSport != null
                          ? MivaltaColors.stateProductive
                          : MivaltaColors.surface2,
                      foregroundColor: _selectedSport != null
                          ? MivaltaColors.surfaceBackground
                          : MivaltaColors.textMuted,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(MivaltaRadii.lg),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.play_arrow, size: 24),
                        const SizedBox(width: MivaltaSpace.x2),
                        Text(
                          'Start ${_selectedSport != null ? _sportName(_selectedSport!) : ''}',
                          style: MivaltaType.cardTitle.copyWith(
                            color: _selectedSport != null
                                ? MivaltaColors.surfaceBackground
                                : MivaltaColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _sportName(String id) {
    final sport = _sports.firstWhere((s) => s.id == id);
    return sport.name.toLowerCase();
  }

  void _startSession() {
    if (_selectedSport == null) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(
        builder: (context) => SessionLiveScreen(sport: _selectedSport!),
      ),
    );
  }
}

/// Sport option data.
class _SportOption {
  const _SportOption({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.icon,
  });

  final String id;
  final String name;
  final String subtitle;
  final IconData icon;
}

/// Sport selection tile.
class _SportTile extends StatelessWidget {
  const _SportTile({
    required this.sport,
    required this.selected,
    required this.onTap,
  });

  final _SportOption sport;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: selected
              ? MivaltaColors.stateProductive.withValues(alpha: 0.08)
              : MivaltaColors.cardSurface,
          border: Border.all(
            color: selected
                ? MivaltaColors.stateProductive.withValues(alpha: 0.5)
                : MivaltaColors.cardBorder,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(MivaltaRadii.md),
        ),
        padding: const EdgeInsets.all(MivaltaSpace.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              sport.icon,
              size: 24,
              color: MivaltaColors.stateProductive,
            ),
            const SizedBox(height: MivaltaSpace.x2),
            Text(
              sport.name,
              style: MivaltaType.cardTitle.copyWith(
                color: MivaltaColors.textPrimary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sport.subtitle,
              style: MivaltaType.small.copyWith(
                color: MivaltaColors.textMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

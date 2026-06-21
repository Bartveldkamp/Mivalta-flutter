// PR-G: Settings & Data Control screen.
//
// Makes MiValta's privacy promise tangible — the user can see, edit, export,
// and permanently erase their data. 100% on-device, no cloud, no harvesting.
// Engine decides; UI only displays and triggers.
//
// Four sections:
//   1. Profile — view + edit the anchors captured at onboarding
//   2. Data sources — render build_source_overview (locked SourceTier colors)
//   3. Export my data — local file only, never network
//   4. Delete everything — crypto-erase, irreversible
//
// Zero-fabrication / no-harvesting invariants:
//   - No network calls anywhere in this screen
//   - Export writes a local file only
//   - Delete is a real crypto-erase, not a soft flag

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../debug/demo_seeder.dart';
import '../rust_engine.dart';
import '../services/profile_service.dart';
import '../services/unit_prefs.dart';
import '../theme/source_tier.dart';
import '../theme/tokens.dart';

/// Settings screen for data control.
///
/// Receives engine binding and handle from parent.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.binding,
    required this.handle,
    required this.profileJson,
    required this.onDataCleared,
  });

  final RustEngineBinding binding;
  final EnginesHandle handle;
  final String profileJson;

  /// Callback when all data is cleared — parent should navigate to onboarding.
  final VoidCallback onDataCleared;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _sourceOverview;
  UnitSystem _unitSystem = UnitSystem.metric;
  final _unitPrefs = UnitPrefs();
  bool _loading = true;
  String? _error;

  /// The engine's V4 pause-learning flag, read at load time. `null` until the
  /// first read settles. The engine is the source of truth — this field only
  /// MIRRORS `ViterbiEngine::is_learning_paused()`; the toggle never decides.
  bool? _learningPaused;

  /// Guards the toggle while a pause/resume round-trip to the engine is in
  /// flight (prevents a double-tap issuing overlapping engine calls).
  bool _learningPauseBusy = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadUnitPrefs();
  }

  Future<void> _loadUnitPrefs() async {
    final system = await _unitPrefs.load();
    if (mounted) setState(() => _unitSystem = system);
  }

  void _onUnitSystemChanged(UnitSystem system) {
    setState(() => _unitSystem = system);
    _unitPrefs.save(system);
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      // Parse the profile JSON
      _profile = jsonDecode(widget.profileJson) as Map<String, dynamic>;

      // Build source overview from an empty sources list (engine will return
      // available sources based on what's been ingested)
      // NOTE: For now we pass an empty list; the engine's build_source_overview
      // returns the overview based on what data exists in the vault.
      try {
        final overviewJson = await widget.binding.buildSourceOverview(
          widget.handle,
          sourcesJson: '[]',
        );
        _sourceOverview = jsonDecode(overviewJson) as Map<String, dynamic>?;
      } catch (_) {
        // Source overview is optional — don't fail the whole screen
        _sourceOverview = null;
      }

      // Read the engine's current V4 pause-learning flag so the toggle opens
      // reflecting the real engine state (source of truth), not a Dart guess.
      // Optional — a failure here must not blank the whole screen, so it lands
      // as honest absence (toggle hidden) rather than an error.
      try {
        _learningPaused = await widget.binding.isLearningPaused(widget.handle);
      } catch (_) {
        _learningPaused = null;
      }

      _error = null;
    } catch (e) {
      _error = '$e';
    }
    if (mounted) setState(() => _loading = false);
  }

  /// Toggle the engine's V4 pause-learning flag. Display-only: this calls the
  /// engine control, persists the engine's OWN serialized state so the choice
  /// survives a restart (continuity contract — `learning_paused` is persisted
  /// across save_state/from_persisted_state in gatc-viterbi), then re-reads the
  /// engine flag and mirrors it. The toggle reflects the engine; it never
  /// decides the value itself.
  Future<void> _onPauseLearningChanged(bool pause) async {
    if (_learningPauseBusy) return;
    setState(() => _learningPauseBusy = true);
    try {
      if (pause) {
        await widget.binding.pauseLearning(widget.handle);
      } else {
        await widget.binding.resumeLearning(widget.handle);
      }

      // Continuity: the flag lives in the engine's serialized state, so it only
      // survives a restart once we persist that state to the vault. Mirror the
      // documented save_state → writeViterbiState pattern (no new persist path).
      final stateJson = await widget.binding.saveState(widget.handle);
      await widget.binding.writeViterbiState(widget.handle, stateJson: stateJson);

      // Re-read the engine flag — the engine is the source of truth.
      final actual = await widget.binding.isLearningPaused(widget.handle);
      if (mounted) setState(() => _learningPaused = actual);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not change personalization: $e'),
            backgroundColor: MivaltaColors.levelRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _learningPauseBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MivaltaColors.surfaceBackground,
      appBar: AppBar(
        backgroundColor: MivaltaColors.surface1,
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: MivaltaColors.primaryGreen),
            )
          : _error != null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MivaltaSpace.x4),
        child: Text(
          'Error: $_error',
          style: const TextStyle(color: MivaltaColors.levelRed),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildContent() {
    return ListView(
      padding: const EdgeInsets.all(MivaltaSpace.x4),
      children: [
        _buildPreferencesSection(),
        const SizedBox(height: MivaltaSpace.x5),
        _buildProfileSection(),
        const SizedBox(height: MivaltaSpace.x5),
        _buildPrivacyProofSection(),
        const SizedBox(height: MivaltaSpace.x5),
        _buildPersonalizationSection(),
        const SizedBox(height: MivaltaSpace.x5),
        _buildDataSourcesSection(),
        const SizedBox(height: MivaltaSpace.x5),
        _buildExportSection(),
        const SizedBox(height: MivaltaSpace.x5),
        _buildDeleteSection(),
        // DEBUG-ONLY: simulated-athlete seeder. Compiled out of release.
        if (kDebugMode) ...[
          const SizedBox(height: MivaltaSpace.x5),
          _buildDeveloperSection(),
        ],
        const SizedBox(height: MivaltaSpace.x6),
      ],
    );
  }

  // ===========================================================================
  // Preferences Section (§D: metric/imperial toggle)
  // ===========================================================================

  Widget _buildPreferencesSection() {
    return _SectionCard(
      title: 'Preferences',
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Units',
              style: TextStyle(color: MivaltaColors.textSecondary),
            ),
            SegmentedButton<UnitSystem>(
              segments: const [
                ButtonSegment(
                  value: UnitSystem.metric,
                  label: Text('Metric'),
                ),
                ButtonSegment(
                  value: UnitSystem.imperial,
                  label: Text('Imperial'),
                ),
              ],
              selected: {_unitSystem},
              onSelectionChanged: (selection) {
                if (selection.isNotEmpty) {
                  _onUnitSystemChanged(selection.first);
                }
              },
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return MivaltaColors.primaryGreen.withValues(alpha: 0.3);
                  }
                  return MivaltaColors.surface2;
                }),
                foregroundColor: WidgetStateProperty.all(MivaltaColors.textPrimary),
              ),
            ),
          ],
        ),
        const SizedBox(height: MivaltaSpace.x2),
        const Text(
          'Affects distance, pace, and speed display. Engine stays metric.',
          style: TextStyle(
            color: MivaltaColors.textMuted,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // Privacy Proof Section (§D: on-device proof)
  // ===========================================================================

  Widget _buildPrivacyProofSection() {
    return _SectionCard(
      title: 'Privacy & On-Device',
      children: [
        const Row(
          children: [
            Icon(Icons.shield, color: MivaltaColors.primaryGreen, size: 20),
            SizedBox(width: MivaltaSpace.x2),
            Expanded(
              child: Text(
                '100% on your device',
                style: TextStyle(
                  color: MivaltaColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: MivaltaSpace.x2),
        const Text(
          'Your health data never leaves your phone. MiValta has no cloud, '
          'no accounts, no analytics. The AI runs locally. Even your export '
          'stays on your device until you choose to share it.',
          style: TextStyle(
            color: MivaltaColors.textSecondary,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        const SizedBox(height: MivaltaSpace.x3),
        const Row(
          children: [
            Icon(Icons.lock, color: MivaltaColors.primaryGreen, size: 20),
            SizedBox(width: MivaltaSpace.x2),
            Expanded(
              child: Text(
                'Encrypted vault',
                style: TextStyle(
                  color: MivaltaColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: MivaltaSpace.x2),
        const Text(
          'All data is stored in an SQLCipher-encrypted database. '
          'When you delete everything, the encryption key is destroyed — '
          'your data becomes unrecoverable noise.',
          style: TextStyle(
            color: MivaltaColors.textSecondary,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // Personalization control (V4 pause-learning privacy toggle)
  // ===========================================================================
  //
  // Surfaces the EXISTING engine control `ViterbiEngine::pause_learning` /
  // `resume_learning` / `is_learning_paused`. The engine still computes
  // readiness while paused; only the on-device personal ADAPTATION (learned
  // baseline, ceiling intelligence, outcome tracking) stops. Display-only: the
  // switch mirrors the engine flag; it never decides it.

  Widget _buildPersonalizationSection() {
    // Honest absence: if the engine flag couldn't be read (e.g. host harness),
    // don't render a control whose state we can't trust.
    if (_learningPaused == null) return const SizedBox.shrink();

    return _SectionCard(
      title: 'Personalization',
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeThumbColor: MivaltaColors.primaryGreen,
          value: _learningPaused!,
          onChanged:
              _learningPauseBusy ? null : (v) => _onPauseLearningChanged(v),
          title: const Text(
            'Pause personalization',
            style: TextStyle(color: MivaltaColors.textPrimary),
          ),
          subtitle: const Text(
            'The engine still reads your readiness — it just stops learning '
            'your personal baseline on this device until you turn it back on.',
            style: TextStyle(color: MivaltaColors.textSecondary, fontSize: 13),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // DEBUG-ONLY: Developer — simulated athlete
  // ===========================================================================
  //
  // Replays a committed SYNTHETIC season through the REAL ingest path so the
  // app is demoable on a simulator that has no watch/Oura data. Every readiness
  // value stays engine-computed — only the biometric INPUT is synthetic. Gated
  // behind kDebugMode, so none of this exists in a release build.

  Widget _buildDeveloperSection() {
    return _SectionCard(
      title: 'Developer · Demo data',
      subtitle: 'Debug builds only — simulated athlete, real engine',
      children: [
        const Text(
          'Replays a synthetic biometric season through the real ingest '
          'pipeline. The engine computes every readiness state from it — '
          'nothing on screen is faked. Pull-to-refresh Today (or restart) to '
          'see the result. Reset via "Delete All My Data" above.',
          style: TextStyle(color: MivaltaColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: MivaltaSpace.x3),
        _ActionRow(
          icon: Icons.timeline,
          label: 'Seed ~10 days (mid-calibration)',
          description: 'Partial history — "still learning you" state',
          onTap: () => _seedDemo(10),
        ),
        const Divider(color: MivaltaColors.overlay),
        _ActionRow(
          icon: Icons.show_chart,
          label: 'Seed full season (~30 days)',
          description: 'Warmed-up: base → overload → illness → recovery',
          onTap: () => _seedDemo(1000),
        ),
      ],
    );
  }

  Future<void> _seedDemo(int days) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: MivaltaColors.primaryGreen),
      ),
    );
    try {
      final result = await DemoSeeder(
        binding: widget.binding,
        handle: widget.handle,
      ).seedSeason(days: days);
      if (mounted) {
        Navigator.of(context).pop(); // dismiss loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Seeded ${result.daysSeeded} simulated days — '
              'pull-to-refresh Today to see it.',
            ),
            backgroundColor: MivaltaColors.primaryGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // dismiss loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Seed failed: $e'),
            backgroundColor: MivaltaColors.levelRed,
          ),
        );
      }
    }
  }

  // ===========================================================================
  // Section 1: Profile
  // ===========================================================================

  Widget _buildProfileSection() {
    return _SectionCard(
      title: 'Your Profile',
      children: [
        _ProfileRow(label: 'Sport', value: _formatSport(_profile?['sport'])),
        _ProfileRow(label: 'Goal', value: _formatGoal(_profile?['goal_type'])),
        _ProfileRow(label: 'Level', value: _formatLevel(_profile?['level'])),
        _ProfileRow(label: 'Age', value: '${_profile?['age'] ?? '—'}'),
        _ProfileRow(
          label: 'Threshold HR',
          value: _formatOptionalInt(_profile?['threshold_hr'], suffix: ' bpm'),
        ),
        if (_profile?['sport'] == 'cycling')
          _ProfileRow(
            label: 'FTP',
            value: _formatOptionalInt(_profile?['ftp_watts'], suffix: ' W'),
          ),
        if (_profile?['sport'] == 'running')
          _ProfileRow(
            label: 'Threshold Pace',
            value: _formatPace(_profile?['threshold_pace_sec_km']),
          ),
        const SizedBox(height: MivaltaSpace.x3),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _editProfile,
            style: OutlinedButton.styleFrom(
              foregroundColor: MivaltaColors.primaryGreen,
              side: const BorderSide(color: MivaltaColors.primaryGreen),
            ),
            child: const Text('Edit Profile'),
          ),
        ),
      ],
    );
  }

  String _formatSport(String? sport) {
    switch (sport) {
      case 'cycling':
        return 'Cycling';
      case 'running':
        return 'Running';
      case 'walking':
        return 'Walking';
      case 'hiking':
        return 'Hiking';
      default:
        return sport ?? '—';
    }
  }

  String _formatGoal(String? goal) {
    switch (goal) {
      case 'general_fitness':
        return 'General Fitness';
      case 'endurance':
        return 'Build Endurance';
      case 'performance':
        return 'Performance';
      case 'weight_loss':
        return 'Weight Loss';
      default:
        return goal ?? '—';
    }
  }

  String _formatLevel(String? level) {
    switch (level) {
      case 'beginner':
        return 'Beginner';
      case 'intermediate':
        return 'Intermediate';
      case 'advanced':
        return 'Advanced';
      case 'elite':
        return 'Elite';
      default:
        return level ?? '—';
    }
  }

  String _formatOptionalInt(dynamic value, {String suffix = ''}) {
    if (value == null) return "I don't know";
    if (value is int) return '$value$suffix';
    if (value is num) return '${value.toInt()}$suffix';
    return "I don't know";
  }

  String _formatPace(dynamic secPerKm) {
    if (secPerKm == null) return "I don't know";
    final total = (secPerKm is num) ? secPerKm.toInt() : 0;
    if (total <= 0) return "I don't know";
    final min = total ~/ 60;
    final sec = total % 60;
    return '$min:${sec.toString().padLeft(2, '0')} /km';
  }

  Future<void> _editProfile() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _ProfileEditDialog(profile: _profile ?? {}),
    );

    if (result != null && mounted) {
      // Build updated profile JSON
      final updatedProfile = Map<String, dynamic>.from(_profile ?? {});
      updatedProfile.addAll(result);
      final updatedJson = jsonEncode(updatedProfile);

      try {
        // Update all engines with the new profile
        await widget.binding.updateProfile(
          widget.handle,
          athleteProfileJson: updatedJson,
        );

        // FL-12: persist to the SQLCipher vault (ProfileService.saveProfile ->
        // writeProfileToVault since PR-H — NOT plaintext). The engine rebind
        // above and this write are not a single transaction; if the write
        // throws, the engine is transiently ahead of the vault and self-heals
        // on next launch (engines are rebuilt from the vault profile).
        await ProfileService.saveProfile(updatedJson);

        if (mounted) setState(() => _profile = updatedProfile);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated'),
              backgroundColor: MivaltaColors.primaryGreen,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating profile: $e'),
              backgroundColor: MivaltaColors.levelRed,
            ),
          );
        }
      }
    }
  }

  // ===========================================================================
  // Section 2: Data Sources
  // ===========================================================================

  Widget _buildDataSourcesSection() {
    return _SectionCard(
      title: 'Data Sources',
      subtitle: 'Which source feeds each metric',
      children: [
        if (_sourceOverview == null)
          const Text(
            'No data sources connected yet.',
            style: TextStyle(color: MivaltaColors.textSecondary),
          )
        else ...[
          // PR-H: Fixed field access to match build_source_overview contract.
          // Output is {"primary_sources": {"hrv": "...", "sleep": "...", ...}}
          _DataSourceRow(
            metric: 'HRV',
            source: (_sourceOverview?['primary_sources'] as Map?)?['hrv'] as String?,
          ),
          _DataSourceRow(
            metric: 'Sleep',
            source: (_sourceOverview?['primary_sources'] as Map?)?['sleep'] as String?,
          ),
          _DataSourceRow(
            metric: 'Resting HR',
            source: (_sourceOverview?['primary_sources'] as Map?)?['resting_hr'] as String?,
          ),
          _DataSourceRow(
            metric: 'Activity',
            source: (_sourceOverview?['primary_sources'] as Map?)?['activity'] as String?,
          ),
        ],
      ],
    );
  }

  // ===========================================================================
  // Section 3: Export My Data
  // ===========================================================================

  Widget _buildExportSection() {
    return _SectionCard(
      title: 'Export My Data',
      subtitle: 'Download your data — stays on your device',
      children: [
        _ActionRow(
          icon: Icons.lock,
          label: 'Export Encrypted Backup',
          description: 'Full vault backup protected by your passphrase',
          onTap: _exportEncryptedVault,
        ),
        const Divider(color: MivaltaColors.overlay),
        _ActionRow(
          icon: Icons.table_chart,
          label: 'Export Biometrics CSV',
          description: 'Portable spreadsheet of your health data',
          onTap: _exportBiometricsCsv,
        ),
      ],
    );
  }

  Future<void> _exportEncryptedVault() async {
    // Show passphrase dialog
    final passphrase = await showDialog<String>(
      context: context,
      builder: (_) => const _PassphraseDialog(),
    );

    if (passphrase == null || passphrase.isEmpty || !mounted) return;

    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: MivaltaColors.primaryGreen),
        ),
      );

      final athleteId = _profile?['athlete_id'] as String? ?? 'unknown';
      final bytes = await widget.binding.exportEncryptedVault(
        widget.handle,
        athleteId: athleteId,
        passphrase: passphrase,
      );

      // Save to temp file and share
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final file = File('${tempDir.path}/mivalta-backup-$timestamp.mvb');
      await file.writeAsBytes(bytes);

      if (mounted) Navigator.of(context).pop(); // Dismiss loading

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'MiValta Backup',
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Dismiss loading if still showing
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: MivaltaColors.levelRed,
          ),
        );
      }
    }
  }

  Future<void> _exportBiometricsCsv() async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: MivaltaColors.primaryGreen),
        ),
      );

      final csv = await widget.binding.exportBiometricsCsv(
        widget.handle,
        days: 0, // All history
      );

      // Save to temp file and share
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final file = File('${tempDir.path}/mivalta-biometrics-$timestamp.csv');
      await file.writeAsString(csv);

      if (mounted) Navigator.of(context).pop(); // Dismiss loading

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'MiValta Biometrics',
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Dismiss loading if still showing
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: MivaltaColors.levelRed,
          ),
        );
      }
    }
  }

  // ===========================================================================
  // Section 4: Delete Everything
  // ===========================================================================

  Widget _buildDeleteSection() {
    return _SectionCard(
      title: 'Delete Everything',
      titleColor: MivaltaColors.levelRed,
      children: [
        const Text(
          'Permanently erase all your data from this device. '
          'This destroys your encryption key — your data becomes '
          'unrecoverable noise.',
          style: TextStyle(
            color: MivaltaColors.textSecondary,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: MivaltaSpace.x4),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _confirmDeleteEverything,
            style: ElevatedButton.styleFrom(
              backgroundColor: MivaltaColors.levelRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete All My Data'),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDeleteEverything() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: MivaltaColors.surface1,
        title: const Text(
          'Delete All Data?',
          style: TextStyle(color: MivaltaColors.levelRed),
        ),
        content: const Text(
          // LOCKED COPY — do not soften
          'This permanently erases all your data on this device. '
          'It cannot be undone.',
          style: TextStyle(color: MivaltaColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: MivaltaColors.levelRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete Everything'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: MivaltaColors.levelRed),
        ),
      );

      final athleteId = _profile?['athlete_id'] as String? ?? 'unknown';
      await widget.binding.clearAllUserData(
        widget.handle,
        athleteId: athleteId,
      );

      // Also delete the local profile file
      await ProfileService.deleteProfile();

      if (mounted) {
        Navigator.of(context).pop(); // Dismiss loading

        // Show success briefly then trigger callback
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All data erased'),
            backgroundColor: MivaltaColors.primaryGreen,
          ),
        );

        // Trigger callback to navigate back to onboarding
        widget.onDataCleared();
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Dismiss loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: MivaltaColors.levelRed,
          ),
        );
      }
    }
  }
}

// =============================================================================
// Reusable Widgets
// =============================================================================

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    this.subtitle,
    this.titleColor,
    required this.children,
  });

  final String title;
  final String? subtitle;
  final Color? titleColor;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: MivaltaColors.surface1,
        borderRadius: BorderRadius.circular(MivaltaRadii.md),
      ),
      padding: const EdgeInsets.all(MivaltaSpace.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: titleColor ?? MivaltaColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: MivaltaSpace.x1),
            Text(
              subtitle!,
              style: const TextStyle(
                color: MivaltaColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
          const SizedBox(height: MivaltaSpace.x3),
          ...children,
        ],
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MivaltaSpace.x1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: MivaltaColors.textSecondary),
          ),
          Text(
            value,
            style: const TextStyle(color: MivaltaColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _DataSourceRow extends StatelessWidget {
  const _DataSourceRow({required this.metric, this.source});

  final String metric;
  final String? source;

  @override
  Widget build(BuildContext context) {
    final tier = sourceTierFromEngine(source);
    final color = tier != null
        ? kSourceTierColor[tier] ?? MivaltaColors.textMuted
        : MivaltaColors.textMuted;
    final label = source ?? 'No data';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MivaltaSpace.x1),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              metric,
              style: const TextStyle(color: MivaltaColors.textSecondary),
            ),
          ),
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: MivaltaSpace.x2),
          Text(
            label,
            style: const TextStyle(color: MivaltaColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(MivaltaRadii.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: MivaltaSpace.x3),
        child: Row(
          children: [
            Icon(icon, color: MivaltaColors.primaryGreen, size: 24),
            const SizedBox(width: MivaltaSpace.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: MivaltaColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    description,
                    style: const TextStyle(
                      color: MivaltaColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: MivaltaColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Dialogs
// =============================================================================

class _PassphraseDialog extends StatefulWidget {
  const _PassphraseDialog();

  @override
  State<_PassphraseDialog> createState() => _PassphraseDialogState();
}

class _PassphraseDialogState extends State<_PassphraseDialog> {
  final _controller = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _controller.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _controller.text.isNotEmpty &&
      _controller.text == _confirmController.text &&
      _controller.text.length >= 8;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: MivaltaColors.surface1,
      title: const Text(
        'Set Backup Passphrase',
        style: TextStyle(color: MivaltaColors.textPrimary),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Choose a strong passphrase. Without it, your backup is unrecoverable. By design.',
            style: TextStyle(color: MivaltaColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: MivaltaSpace.x4),
          TextField(
            controller: _controller,
            obscureText: _obscure,
            style: const TextStyle(color: MivaltaColors.textPrimary),
            decoration: InputDecoration(
              labelText: 'Passphrase',
              labelStyle: const TextStyle(color: MivaltaColors.textSecondary),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility : Icons.visibility_off,
                  color: MivaltaColors.textMuted,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: MivaltaSpace.x2),
          TextField(
            controller: _confirmController,
            obscureText: _obscure,
            style: const TextStyle(color: MivaltaColors.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Confirm Passphrase',
              labelStyle: TextStyle(color: MivaltaColors.textSecondary),
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (_controller.text.isNotEmpty && _controller.text.length < 8)
            const Padding(
              padding: EdgeInsets.only(top: MivaltaSpace.x2),
              child: Text(
                'Passphrase must be at least 8 characters',
                style: TextStyle(color: MivaltaColors.levelRed, fontSize: 12),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isValid ? () => Navigator.of(context).pop(_controller.text) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: MivaltaColors.primaryGreen,
            foregroundColor: Colors.white,
          ),
          child: const Text('Export'),
        ),
      ],
    );
  }
}

class _ProfileEditDialog extends StatefulWidget {
  const _ProfileEditDialog({required this.profile});

  final Map<String, dynamic> profile;

  @override
  State<_ProfileEditDialog> createState() => _ProfileEditDialogState();
}

class _ProfileEditDialogState extends State<_ProfileEditDialog> {
  late TextEditingController _thresholdHrController;
  late TextEditingController _ftpController;
  late TextEditingController _paceMinController;
  late TextEditingController _paceSecController;

  bool _knowsThresholdHr = true;
  bool _knowsFtp = true;
  bool _knowsPace = true;

  @override
  void initState() {
    super.initState();
    final thr = widget.profile['threshold_hr'];
    final ftp = widget.profile['ftp_watts'];
    final pace = widget.profile['threshold_pace_sec_km'];

    _knowsThresholdHr = thr != null;
    _knowsFtp = ftp != null;
    _knowsPace = pace != null;

    _thresholdHrController = TextEditingController(
      text: thr != null ? '$thr' : '',
    );
    _ftpController = TextEditingController(
      text: ftp != null ? '$ftp' : '',
    );

    if (pace != null && pace is num) {
      final total = pace.toInt();
      _paceMinController = TextEditingController(text: '${total ~/ 60}');
      _paceSecController = TextEditingController(text: '${total % 60}');
    } else {
      _paceMinController = TextEditingController();
      _paceSecController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _thresholdHrController.dispose();
    _ftpController.dispose();
    _paceMinController.dispose();
    _paceSecController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sport = widget.profile['sport'] as String?;

    return AlertDialog(
      backgroundColor: MivaltaColors.surface1,
      title: const Text(
        'Edit Anchors',
        style: TextStyle(color: MivaltaColors.textPrimary),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Update your training anchors. "I don\'t know" is a valid choice.',
              style: TextStyle(color: MivaltaColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: MivaltaSpace.x4),

            // Threshold HR
            _buildAnchorField(
              label: 'Threshold Heart Rate',
              suffix: 'bpm',
              controller: _thresholdHrController,
              knows: _knowsThresholdHr,
              onKnowsChanged: (v) => setState(() => _knowsThresholdHr = v),
            ),

            // FTP (cycling only)
            if (sport == 'cycling') ...[
              const SizedBox(height: MivaltaSpace.x3),
              _buildAnchorField(
                label: 'FTP (Functional Threshold Power)',
                suffix: 'W',
                controller: _ftpController,
                knows: _knowsFtp,
                onKnowsChanged: (v) => setState(() => _knowsFtp = v),
              ),
            ],

            // Threshold Pace (running only)
            if (sport == 'running') ...[
              const SizedBox(height: MivaltaSpace.x3),
              _buildPaceField(),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: MivaltaColors.primaryGreen,
            foregroundColor: Colors.white,
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildAnchorField({
    required String label,
    required String suffix,
    required TextEditingController controller,
    required bool knows,
    required ValueChanged<bool> onKnowsChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: MivaltaColors.textSecondary)),
        const SizedBox(height: MivaltaSpace.x1),
        Row(
          children: [
            Checkbox(
              value: !knows,
              onChanged: (v) => onKnowsChanged(!(v ?? false)),
              activeColor: MivaltaColors.primaryGreen,
            ),
            const Text(
              "I don't know",
              style: TextStyle(color: MivaltaColors.textSecondary),
            ),
          ],
        ),
        if (knows)
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(color: MivaltaColors.textPrimary),
            decoration: InputDecoration(
              suffixText: suffix,
              suffixStyle: const TextStyle(color: MivaltaColors.textMuted),
            ),
          ),
      ],
    );
  }

  Widget _buildPaceField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Threshold Pace',
          style: TextStyle(color: MivaltaColors.textSecondary),
        ),
        const SizedBox(height: MivaltaSpace.x1),
        Row(
          children: [
            Checkbox(
              value: !_knowsPace,
              onChanged: (v) => setState(() => _knowsPace = !(v ?? false)),
              activeColor: MivaltaColors.primaryGreen,
            ),
            const Text(
              "I don't know",
              style: TextStyle(color: MivaltaColors.textSecondary),
            ),
          ],
        ),
        if (_knowsPace)
          Row(
            children: [
              SizedBox(
                width: 60,
                child: TextField(
                  controller: _paceMinController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(color: MivaltaColors.textPrimary),
                  decoration: const InputDecoration(
                    suffixText: 'min',
                    suffixStyle: TextStyle(color: MivaltaColors.textMuted),
                  ),
                ),
              ),
              const SizedBox(width: MivaltaSpace.x2),
              const Text(':', style: TextStyle(color: MivaltaColors.textPrimary)),
              const SizedBox(width: MivaltaSpace.x2),
              SizedBox(
                width: 60,
                child: TextField(
                  controller: _paceSecController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(color: MivaltaColors.textPrimary),
                  decoration: const InputDecoration(
                    suffixText: 'sec',
                    suffixStyle: TextStyle(color: MivaltaColors.textMuted),
                  ),
                ),
              ),
              const SizedBox(width: MivaltaSpace.x2),
              const Text('/km', style: TextStyle(color: MivaltaColors.textMuted)),
            ],
          ),
      ],
    );
  }

  void _save() {
    final result = <String, dynamic>{};

    // Threshold HR
    if (_knowsThresholdHr && _thresholdHrController.text.isNotEmpty) {
      result['threshold_hr'] = int.tryParse(_thresholdHrController.text);
    } else {
      result['threshold_hr'] = null;
    }

    // FTP
    if (widget.profile['sport'] == 'cycling') {
      if (_knowsFtp && _ftpController.text.isNotEmpty) {
        result['ftp_watts'] = int.tryParse(_ftpController.text);
      } else {
        result['ftp_watts'] = null;
      }
    }

    // Threshold Pace
    if (widget.profile['sport'] == 'running') {
      if (_knowsPace &&
          _paceMinController.text.isNotEmpty &&
          _paceSecController.text.isNotEmpty) {
        final min = int.tryParse(_paceMinController.text) ?? 0;
        final sec = int.tryParse(_paceSecController.text) ?? 0;
        result['threshold_pace_sec_km'] = min * 60 + sec;
      } else {
        result['threshold_pace_sec_km'] = null;
      }
    }

    Navigator.of(context).pop(result);
  }
}

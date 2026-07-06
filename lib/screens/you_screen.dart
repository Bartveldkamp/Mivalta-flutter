// You Screen — BS-013
//
// The "You" tab: profile summary, learning status, sources, sovereignty.
// One scroll, grouped cards. Engine DECIDES, Dart DISPLAYS.
// Every toggle reflects REAL state read at open — no optimistic UI lies.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/learning_status.dart';
import '../rust_engine.dart';
import '../services/morning_read_gate.dart' show CoachPresence, MorningReadGate;
import '../services/notification_service.dart';
import '../services/profile_service.dart';
import '../theme/source_tier.dart';
import '../theme/tokens.dart';

/// Detail preference — words-first or numbers-first display style.
enum DetailPreference { wordsFirst, numbersFirst }

/// You tab — profile, sources, sovereignty.
class YouScreen extends StatefulWidget {
  const YouScreen({super.key});

  @override
  State<YouScreen> createState() => _YouScreenState();
}

class _YouScreenState extends State<YouScreen> {
  RustEngineBinding? _binding;
  EnginesHandle? _handle;

  // Profile data (parsed from profile JSON).
  Map<String, dynamic>? _profile;

  // Learning status from engine.
  LearningStatus? _learningStatus;

  // Source overview from engine.
  List<Map<String, dynamic>> _sources = [];

  // Pause state.
  bool _isLearningPaused = false;

  // Coach presence and detail preference (local prefs, BS-012 reads presence).
  CoachPresence _coachPresence = CoachPresence.moderate;
  DetailPreference _detailPreference = DetailPreference.wordsFirst;

  // Engine hello (for debug).
  String? _engineHello;

  // Notification preview (kDebugMode only).
  Map<String, String>? _notificationPreview;

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initEngineAndLoadData();
  }

  Future<void> _initEngineAndLoadData() async {
    try {
      // Bootstrap FRB.
      final binding = await RustEngineBinding.bootstrap();
      _binding = binding;

      // Load profile.
      final profileJson = await ProfileService.loadProfile();
      if (profileJson == null) {
        setState(() {
          _loading = false;
          _error = 'No profile found';
        });
        return;
      }

      // Parse profile for display.
      _profile = jsonDecode(profileJson) as Map<String, dynamic>;

      // Load tables.
      final tablesJson =
          await rootBundle.loadString('assets/compiled_tables.json');
      final vaultPath = await ProfileService.getVaultPath();

      // Check for persisted state.
      final hasState = await binding.hasPersistedState(
        athleteProfileJson: profileJson,
        vaultPath: vaultPath,
      );

      EnginesHandle handle;
      if (hasState) {
        final stateJson = await binding.readPersistedState(
          athleteProfileJson: profileJson,
          vaultPath: vaultPath,
        );
        if (stateJson != null) {
          handle = await binding.constructEnginesFromState(
            athleteProfileJson: profileJson,
            tablesJson: tablesJson,
            vaultPath: vaultPath,
            viterbiStateJson: stateJson,
          );
        } else {
          handle = await binding.constructEnginesFresh(
            athleteProfileJson: profileJson,
            tablesJson: tablesJson,
            vaultPath: vaultPath,
          );
        }
      } else {
        handle = await binding.constructEnginesFresh(
          athleteProfileJson: profileJson,
          tablesJson: tablesJson,
          vaultPath: vaultPath,
        );
      }
      _handle = handle;

      // Load data from engine.
      await _loadEngineData(binding, handle);

      // Load local preferences (coach presence, detail preference).
      await _loadLocalPreferences();

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadEngineData(
      RustEngineBinding binding, EnginesHandle handle) async {
    // Learning status.
    try {
      final diagJson = await binding.personalizationDiagnostics(handle);
      final valJson = await binding.validationReport(handle);
      _learningStatus = LearningStatus.parse(
        diagnosticsJson: diagJson,
        validationJson: valJson,
      );
    } catch (_) {
      // Engine may not have enough data yet.
    }

    // Pause state.
    try {
      _isLearningPaused = await binding.isLearningPaused(handle);
    } catch (_) {
      // Default to false.
    }

    // Source overview.
    try {
      // Build sources JSON from HealthKit-style data.
      // For now, show honest absence until we have real source data.
      final sourcesJson = await binding.buildSourceOverview(
        handle,
        sourcesJson: '[]',
      );
      final decoded = jsonDecode(sourcesJson);
      if (decoded is List) {
        _sources = decoded.cast<Map<String, dynamic>>();
      }
    } catch (_) {
      // No sources yet.
    }

    // Engine hello (debug).
    if (kDebugMode) {
      try {
        _engineHello = await binding.hello();
      } catch (_) {
        // Ignore.
      }

      // Notification preview (BS-012 kDebugMode preview row).
      try {
        final prefs = await SharedPreferences.getInstance();
        final gate = MorningReadGate(prefs: prefs);

        // Gather engine outputs.
        String? fatigueStateJson;
        String? pendingAdvisoriesJson = '[]';
        String? stateAdvisoryJson;
        String? validationReportJson;

        try {
          fatigueStateJson = await binding.viterbiFatigueState(handle);
        } catch (_) {}
        try {
          pendingAdvisoriesJson = await binding.pendingAdvisories(handle);
        } catch (_) {}
        try {
          stateAdvisoryJson = await binding.stateAdvisory(handle);
        } catch (_) {}
        try {
          validationReportJson = await binding.validationReport(handle);
        } catch (_) {}

        final result = gate.evaluate(
          fatigueStateJson: fatigueStateJson,
          pendingAdvisoriesJson: pendingAdvisoriesJson,
          stateAdvisoryJson: stateAdvisoryJson,
          validationReportJson: validationReportJson,
        );

        _notificationPreview =
            NotificationService.instance.previewMorningRead(result: result);
      } catch (_) {
        // Ignore preview failures.
      }
    }
  }

  /// Load local preferences (coach presence, detail preference).
  Future<void> _loadLocalPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    // Coach presence: 'off', 'quiet', 'moderate' (default: moderate).
    final presenceStr = prefs.getString('coach_presence') ?? 'moderate';
    _coachPresence = CoachPresence.values.firstWhere(
      (e) => e.name == presenceStr,
      orElse: () => CoachPresence.moderate,
    );

    // Detail preference: 'wordsFirst', 'numbersFirst' (default: wordsFirst).
    final detailStr = prefs.getString('detail_preference') ?? 'wordsFirst';
    _detailPreference = DetailPreference.values.firstWhere(
      (e) => e.name == detailStr,
      orElse: () => DetailPreference.wordsFirst,
    );
  }

  /// Save coach presence preference.
  Future<void> _saveCoachPresence(CoachPresence value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('coach_presence', value.name);
    setState(() => _coachPresence = value);
  }

  /// Save detail preference.
  Future<void> _saveDetailPreference(DetailPreference value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('detail_preference', value.name);
    setState(() => _detailPreference = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MivaltaColors.surfaceBackground,
      body: SafeArea(
        child: _loading
            ? _buildLoading()
            : _error != null
                ? _buildError()
                : _buildContent(),
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(color: MivaltaColors.stateProductive),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MivaltaSpace.x4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: MivaltaColors.stateOverreached,
            ),
            const SizedBox(height: MivaltaSpace.x3),
            Text(
              'Unable to load profile',
              style: MivaltaType.cardTitle.copyWith(
                color: MivaltaColors.textPrimary,
              ),
            ),
            const SizedBox(height: MivaltaSpace.x2),
            Text(
              _error!,
              style: MivaltaType.small.copyWith(
                color: MivaltaColors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header.
          _buildHeader(),

          // Profile card.
          _buildProfileCard(),

          // Learning you card.
          _buildLearningCard(),

          // Sources card.
          _buildSourcesCard(),

          // Sovereignty card.
          _buildSovereigntyCard(),

          // How MiValta speaks card (Y1).
          _buildSpeakCard(),

          // Display settings card.
          _buildDisplayCard(),

          // Debug stamp (kDebugMode only).
          if (kDebugMode) _buildDebugStamp(),

          const SizedBox(height: MivaltaSpace.x6),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        MivaltaSpace.x4,
        MivaltaSpace.x4,
        MivaltaSpace.x4,
        MivaltaSpace.x2,
      ),
      child: Text(
        'You',
        style: MivaltaType.display.copyWith(
          color: MivaltaColors.textPrimary,
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    final sport = _profile?['sport'] as String? ?? 'Unknown';
    final level = _profile?['level'] as String? ?? 'Unknown';
    final goalType = _profile?['goal_type'] as String?;

    return _Card(
      title: 'Who you are',
      icon: Icons.person_outline,
      children: [
        _ProfileRow(
          label: 'Sport',
          value: _formatSport(sport),
        ),
        _ProfileRow(
          label: 'Level',
          value: _formatLevel(level),
        ),
        if (goalType != null)
          _ProfileRow(
            label: 'Goal',
            value: _formatGoal(goalType),
          ),
        const SizedBox(height: MivaltaSpace.x2),
        // Edit stub.
        _ActionRow(
          icon: Icons.edit_outlined,
          label: 'Edit profile',
          onTap: () {
            _showEditStub();
          },
        ),
      ],
    );
  }

  Widget _buildLearningCard() {
    final status = _learningStatus;

    return _Card(
      title: 'Learning you',
      icon: Icons.school_outlined,
      children: [
        if (status == null)
          Text(
            'No learning data yet',
            style: MivaltaType.body.copyWith(
              color: MivaltaColors.textMuted,
            ),
          )
        else ...[
          _ProfileRow(
            label: 'Observations',
            value: status.observationCount?.toString() ?? '—',
          ),
          _ProfileRow(
            label: 'Confidence',
            value: _formatBucket(status.confidenceBucket),
          ),
          _ProfileRow(
            label: 'Data sufficiency',
            value: _formatBucket(status.dataSufficiency),
          ),
          if (status.isValidated)
            _ProfileRow(
              label: 'Model score',
              value: '${(status.overallModelScore * 100).toStringAsFixed(0)}%',
            ),
        ],
      ],
    );
  }

  Widget _buildSourcesCard() {
    return _Card(
      title: 'Your sources',
      icon: Icons.devices_outlined,
      children: [
        if (_sources.isEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No sources connected',
                style: MivaltaType.body.copyWith(
                  color: MivaltaColors.textMuted,
                ),
              ),
              const SizedBox(height: MivaltaSpace.x3),
              _ActionRow(
                icon: Icons.add,
                label: 'Connect a source',
                onTap: () {
                  _showConnectSourcesStub();
                },
              ),
            ],
          )
        else
          Column(
            children: [
              for (final source in _sources) _buildSourceRow(source),
              const SizedBox(height: MivaltaSpace.x2),
              _ActionRow(
                icon: Icons.add,
                label: 'Add another source',
                onTap: () {
                  _showConnectSourcesStub();
                },
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildSourceRow(Map<String, dynamic> source) {
    final name = source['name'] as String? ?? 'Unknown source';
    final tier = source['tier'] as String? ?? 'partial';
    final lastSeen = source['last_seen'] as String?;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MivaltaSpace.x1),
      child: Row(
        children: [
          Icon(
            _tierIcon(tier),
            size: 18,
            color: _tierColor(tier),
          ),
          const SizedBox(width: MivaltaSpace.x2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: MivaltaType.body.copyWith(
                    color: MivaltaColors.textPrimary,
                  ),
                ),
                if (lastSeen != null)
                  Text(
                    'Last seen: $lastSeen',
                    style: MivaltaType.small.copyWith(
                      color: MivaltaColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
          ),
          _TierChip(tier: tier),
        ],
      ),
    );
  }

  Widget _buildSovereigntyCard() {
    return _Card(
      title: 'Your data, your device',
      icon: Icons.lock_outline,
      children: [
        // Promise banner.
        Container(
          padding: const EdgeInsets.all(MivaltaSpace.x3),
          decoration: BoxDecoration(
            color: MivaltaColors.stateProductive.withValues(alpha: 0.08),
            border: Border.all(
              color: MivaltaColors.stateProductive.withValues(alpha: 0.25),
            ),
            borderRadius: BorderRadius.circular(MivaltaRadii.md),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.lock,
                size: 18,
                color: MivaltaColors.stateProductive,
              ),
              const SizedBox(width: MivaltaSpace.x2),
              Expanded(
                child: Text(
                  'Computed on your phone. Your biometrics never leave this device.',
                  style: MivaltaType.small.copyWith(
                    color: MivaltaColors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: MivaltaSpace.x4),

        // Pause learning toggle.
        _ToggleRow(
          icon: Icons.pause_circle_outline,
          label: 'Pause learning',
          subtitle: 'Stop model updates — keep using the app',
          value: _isLearningPaused,
          onChanged: _togglePauseLearning,
        ),

        const SizedBox(height: MivaltaSpace.x3),

        // Export button.
        _ActionRow(
          icon: Icons.download_outlined,
          label: 'Export my data',
          subtitle: 'CSV file with your biometrics',
          onTap: _exportData,
        ),

        const SizedBox(height: MivaltaSpace.x3),

        // Erase button.
        _DangerActionRow(
          icon: Icons.delete_forever_outlined,
          label: 'Erase everything',
          subtitle: 'Destroys the key — data is gone, instantly',
          onTap: _confirmErase,
        ),
      ],
    );
  }

  /// How MiValta speaks card (Y1): coach presence dial + detail preference.
  Widget _buildSpeakCard() {
    return _Card(
      title: 'How MiValta speaks',
      icon: Icons.record_voice_over_outlined,
      children: [
        // Coach presence dial: Off / Quiet / Moderate.
        Text(
          'Coach presence',
          style: MivaltaType.label.copyWith(
            color: MivaltaColors.textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: MivaltaSpace.x2),
        _PresenceSelector(
          value: _coachPresence,
          onChanged: _saveCoachPresence,
        ),

        const SizedBox(height: MivaltaSpace.x4),

        // Detail preference: words-first / numbers-first.
        Text(
          'Detail preference',
          style: MivaltaType.label.copyWith(
            color: MivaltaColors.textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: MivaltaSpace.x2),
        _DetailPreferenceSelector(
          value: _detailPreference,
          onChanged: _saveDetailPreference,
        ),
      ],
    );
  }

  Widget _buildDisplayCard() {
    return _Card(
      title: 'Display',
      icon: Icons.tune_outlined,
      children: [
        _ActionRow(
          icon: Icons.text_fields,
          label: 'Text size',
          subtitle: 'System default',
          onTap: () {
            _showTextSizeStub();
          },
        ),
        const SizedBox(height: MivaltaSpace.x2),
        _ActionRow(
          icon: Icons.straighten,
          label: 'Units',
          subtitle: 'Metric',
          onTap: () {
            _showUnitsStub();
          },
        ),
      ],
    );
  }

  Widget _buildDebugStamp() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: MivaltaSpace.x4,
        vertical: MivaltaSpace.x3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DEBUG',
            style: MivaltaType.label.copyWith(
              color: MivaltaColors.textMuted,
              fontSize: 10,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: MivaltaSpace.x1),
          if (_engineHello != null)
            Text(
              _engineHello!,
              style: MivaltaType.small.copyWith(
                color: MivaltaColors.textMuted,
                fontFamily: 'monospace',
                fontSize: 11,
              ),
            ),
          // BS-012: Morning read notification preview.
          if (_notificationPreview != null) ...[
            const SizedBox(height: MivaltaSpace.x2),
            _buildNotificationPreview(),
          ],
        ],
      ),
    );
  }

  /// BS-012 kDebugMode preview row for morning read notification.
  Widget _buildNotificationPreview() {
    final preview = _notificationPreview;
    if (preview == null) return const SizedBox.shrink();

    final status = preview['status'] ?? 'unknown';
    final isSilent = status == 'silent';

    return Container(
      padding: const EdgeInsets.all(MivaltaSpace.x2),
      decoration: BoxDecoration(
        color: isSilent
            ? MivaltaColors.textMuted.withValues(alpha: 0.1)
            : MivaltaColors.stateProductive.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(MivaltaRadii.sm),
        border: Border.all(
          color: isSilent
              ? MivaltaColors.textMuted.withValues(alpha: 0.3)
              : MivaltaColors.stateProductive.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isSilent ? Icons.notifications_off : Icons.notifications_active,
                size: 14,
                color: isSilent
                    ? MivaltaColors.textMuted
                    : MivaltaColors.stateProductive,
              ),
              const SizedBox(width: MivaltaSpace.x1),
              Text(
                'Morning Read: ${isSilent ? 'SILENT' : 'SCHEDULED'}',
                style: MivaltaType.small.copyWith(
                  color: isSilent
                      ? MivaltaColors.textMuted
                      : MivaltaColors.stateProductive,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          if (isSilent && preview['reason'] != null) ...[
            const SizedBox(height: MivaltaSpace.x1),
            Text(
              'Reason: ${preview['reason']}',
              style: MivaltaType.small.copyWith(
                color: MivaltaColors.textMuted,
                fontFamily: 'monospace',
                fontSize: 10,
              ),
            ),
          ],
          if (!isSilent) ...[
            const SizedBox(height: MivaltaSpace.x1),
            Text(
              '${preview['title']} — ${preview['body']}',
              style: MivaltaType.small.copyWith(
                color: MivaltaColors.textPrimary,
                fontSize: 11,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (preview['scheduledTime'] != null) ...[
              const SizedBox(height: MivaltaSpace.x1),
              Text(
                'At: ${preview['scheduledTime']}',
                style: MivaltaType.small.copyWith(
                  color: MivaltaColors.textMuted,
                  fontFamily: 'monospace',
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  // === Actions ===

  Future<void> _togglePauseLearning(bool value) async {
    final binding = _binding;
    final handle = _handle;
    if (binding == null || handle == null) return;

    try {
      if (value) {
        await binding.pauseLearning(handle);
      } else {
        await binding.resumeLearning(handle);
      }
      // Re-read the actual state from engine.
      final actualState = await binding.isLearningPaused(handle);
      setState(() => _isLearningPaused = actualState);
    } catch (e) {
      // Show error.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  Future<void> _exportData() async {
    final binding = _binding;
    final handle = _handle;
    if (binding == null || handle == null) return;

    try {
      // Export last 90 days.
      final csv = await binding.exportBiometricsCsv(handle, days: 90);

      // Write to temp file and share via system share sheet.
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().toIso8601String().split('T').first;
      final file = File('${tempDir.path}/mivalta_export_$timestamp.csv');
      await file.writeAsString(csv);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'MiValta Export',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _confirmErase() async {
    // Two-step confirm per spec.
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
          'This will permanently delete all your data, including:\n\n'
          '• Your profile and settings\n'
          '• All biometric history\n'
          '• All workout data\n'
          '• The learning model\n\n'
          'This cannot be undone.',
          style: MivaltaType.body.copyWith(
            color: MivaltaColors.textSecondary,
            height: 1.5,
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
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (firstConfirm != true || !mounted) return;

    // Second confirm.
    final secondConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: MivaltaColors.surface1,
        title: Text(
          'Are you sure?',
          style: MivaltaType.cardTitle.copyWith(
            color: MivaltaColors.stateOverreached,
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
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (secondConfirm != true || !mounted) return;

    // Execute erase.
    await _executeErase();
  }

  Future<void> _executeErase() async {
    final binding = _binding;
    final handle = _handle;
    if (binding == null || handle == null) return;

    try {
      final athleteId = _profile?['athlete_id'] as String?;
      if (athleteId == null) {
        throw StateError('No athlete_id in profile');
      }

      // Clear all user data.
      await binding.clearAllUserData(handle, athleteId: athleteId);

      // Crypto erase cache.
      await binding.cryptoEraseCache(handle);

      // Delete profile files.
      await ProfileService.deleteProfile();

      // Navigate to onboarding (or splash).
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erase failed: $e')),
        );
      }
    }
  }

  // === Stubs ===

  void _showEditStub() {
    _showStubSheet(
      'Edit profile',
      'Re-running intake is not available yet.\n\n'
          'Future: edit sport, level, goals, and anchors.',
    );
  }

  void _showConnectSourcesStub() {
    _showStubSheet(
      'Connect sources',
      'Connect a wearable or health platform.\n\n'
          'Future: routes to the data-sources onboarding step.',
    );
  }

  void _showTextSizeStub() {
    _showStubSheet(
      'Text size',
      'System-respect + in-app bump.\n\n'
          'Future: slider for text scaling.',
    );
  }

  void _showUnitsStub() {
    _showStubSheet(
      'Units',
      'Metric / Imperial.\n\n'
          'Future: toggle for display units (engine stays SI).',
    );
  }

  void _showStubSheet(String title, String content) {
    showModalBottomSheet(
      context: context,
      backgroundColor: MivaltaColors.surface1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(MivaltaSpace.x4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: MivaltaType.cardTitle.copyWith(
                color: MivaltaColors.textPrimary,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: MivaltaSpace.x3),
            Text(
              content,
              style: MivaltaType.body.copyWith(
                color: MivaltaColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: MivaltaSpace.x4),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Got it',
                  style: MivaltaType.body.copyWith(
                    color: MivaltaColors.stateProductive,
                  ),
                ),
              ),
            ),
            const SizedBox(height: MivaltaSpace.x2),
          ],
        ),
      ),
    );
  }

  // === Formatters ===

  String _formatSport(String sport) {
    return sport[0].toUpperCase() + sport.substring(1);
  }

  String _formatLevel(String level) {
    return level[0].toUpperCase() + level.substring(1);
  }

  String _formatGoal(String goalType) {
    return goalType.replaceAll('_', ' ').split(' ').map((w) {
      if (w.isEmpty) return w;
      return w[0].toUpperCase() + w.substring(1);
    }).join(' ');
  }

  String _formatBucket(String? bucket) {
    if (bucket == null) return '—';
    return bucket[0].toUpperCase() + bucket.substring(1);
  }

  IconData _tierIcon(String tier) {
    switch (tier.toLowerCase()) {
      case 'medical':
        return Icons.local_hospital;
      case 'device':
        return Icons.watch;
      case 'partial':
        return Icons.smartphone;
      default:
        return Icons.edit;
    }
  }

  Color _tierColor(String tier) {
    switch (tier.toLowerCase()) {
      case 'medical':
        return kSourceTierColor[SourceTier.medical]!;
      case 'device':
        return kSourceTierColor[SourceTier.device]!;
      case 'partial':
        return kSourceTierColor[SourceTier.partial]!;
      default:
        return kSourceTierColor[SourceTier.manual]!;
    }
  }
}

// === Widgets ===

class _Card extends StatelessWidget {
  const _Card({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: MivaltaSpace.x4,
        vertical: MivaltaSpace.x2,
      ),
      padding: const EdgeInsets.all(MivaltaSpace.x4),
      decoration: BoxDecoration(
        color: MivaltaColors.surface1,
        border: Border.all(color: MivaltaColors.cardBorder),
        borderRadius: BorderRadius.circular(MivaltaRadii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: MivaltaColors.stateProductive,
              ),
              const SizedBox(width: MivaltaSpace.x2),
              Text(
                title,
                style: MivaltaType.cardTitle.copyWith(
                  color: MivaltaColors.textPrimary,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: MivaltaSpace.x3),
          ...children,
        ],
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: MivaltaType.body.copyWith(
              color: MivaltaColors.textMuted,
              fontSize: 13,
            ),
          ),
          Text(
            value,
            style: MivaltaType.body.copyWith(
              color: MivaltaColors.textPrimary,
              fontSize: 13,
            ),
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
    this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(MivaltaRadii.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: MivaltaColors.stateProductive,
            ),
            const SizedBox(width: MivaltaSpace.x2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: MivaltaType.body.copyWith(
                      color: MivaltaColors.textPrimary,
                      fontSize: 13,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: MivaltaType.small.copyWith(
                        color: MivaltaColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: MivaltaColors.textMuted.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _DangerActionRow extends StatelessWidget {
  const _DangerActionRow({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(MivaltaRadii.md),
      child: Container(
        padding: const EdgeInsets.all(MivaltaSpace.x3),
        decoration: BoxDecoration(
          color: MivaltaColors.stateOverreached.withValues(alpha: 0.08),
          border: Border.all(
            color: MivaltaColors.stateOverreached.withValues(alpha: 0.3),
          ),
          borderRadius: BorderRadius.circular(MivaltaRadii.md),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: MivaltaColors.stateOverreached,
            ),
            const SizedBox(width: MivaltaSpace.x2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: MivaltaType.body.copyWith(
                      color: MivaltaColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: MivaltaType.small.copyWith(
                        color: MivaltaColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: MivaltaColors.textMuted.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: MivaltaColors.stateProductive,
        ),
        const SizedBox(width: MivaltaSpace.x2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: MivaltaType.body.copyWith(
                  color: MivaltaColors.textPrimary,
                  fontSize: 13,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: MivaltaType.small.copyWith(
                    color: MivaltaColors.textMuted,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: MivaltaColors.stateProductive,
          activeTrackColor: MivaltaColors.stateProductive.withValues(alpha: 0.3),
          inactiveThumbColor: MivaltaColors.textMuted,
          inactiveTrackColor: MivaltaColors.textMuted.withValues(alpha: 0.3),
        ),
      ],
    );
  }
}

class _TierChip extends StatelessWidget {
  const _TierChip({required this.tier});

  final String tier;

  @override
  Widget build(BuildContext context) {
    final color = _tierColor(tier);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        tier.toUpperCase(),
        style: MivaltaType.label.copyWith(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Color _tierColor(String tier) {
    switch (tier.toLowerCase()) {
      case 'medical':
        return kSourceTierColor[SourceTier.medical]!;
      case 'device':
        return kSourceTierColor[SourceTier.device]!;
      case 'partial':
        return kSourceTierColor[SourceTier.partial]!;
      default:
        return kSourceTierColor[SourceTier.manual]!;
    }
  }
}

/// Coach presence selector: Off / Quiet / Moderate.
class _PresenceSelector extends StatelessWidget {
  const _PresenceSelector({
    required this.value,
    required this.onChanged,
  });

  final CoachPresence value;
  final ValueChanged<CoachPresence> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: CoachPresence.values.map((presence) {
        final selected = presence == value;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(presence),
            child: Container(
              margin: EdgeInsets.only(
                right: presence != CoachPresence.moderate ? MivaltaSpace.x2 : 0,
              ),
              padding: const EdgeInsets.symmetric(
                vertical: MivaltaSpace.x2,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? MivaltaColors.stateProductive.withValues(alpha: 0.15)
                    : MivaltaColors.surface1,
                border: Border.all(
                  color: selected
                      ? MivaltaColors.stateProductive
                      : MivaltaColors.cardBorder,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(MivaltaRadii.sm),
              ),
              child: Column(
                children: [
                  Text(
                    _presenceLabel(presence),
                    style: MivaltaType.label.copyWith(
                      color: selected
                          ? MivaltaColors.stateProductive
                          : MivaltaColors.textPrimary,
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _presenceSubtitle(presence),
                    style: MivaltaType.small.copyWith(
                      color: MivaltaColors.textMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _presenceLabel(CoachPresence presence) {
    switch (presence) {
      case CoachPresence.off:
        return 'Off';
      case CoachPresence.quiet:
        return 'Quiet';
      case CoachPresence.moderate:
        return 'Moderate';
    }
  }

  String _presenceSubtitle(CoachPresence presence) {
    switch (presence) {
      case CoachPresence.off:
        return 'No nudges';
      case CoachPresence.quiet:
        return 'Essential only';
      case CoachPresence.moderate:
        return 'When useful';
    }
  }
}

/// Detail preference selector: words-first / numbers-first.
class _DetailPreferenceSelector extends StatelessWidget {
  const _DetailPreferenceSelector({
    required this.value,
    required this.onChanged,
  });

  final DetailPreference value;
  final ValueChanged<DetailPreference> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: DetailPreference.values.map((pref) {
        final selected = pref == value;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(pref),
            child: Container(
              margin: EdgeInsets.only(
                right: pref == DetailPreference.wordsFirst ? MivaltaSpace.x2 : 0,
              ),
              padding: const EdgeInsets.symmetric(
                vertical: MivaltaSpace.x2,
                horizontal: MivaltaSpace.x2,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? MivaltaColors.stateProductive.withValues(alpha: 0.15)
                    : MivaltaColors.surface1,
                border: Border.all(
                  color: selected
                      ? MivaltaColors.stateProductive
                      : MivaltaColors.cardBorder,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(MivaltaRadii.sm),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    pref == DetailPreference.wordsFirst
                        ? Icons.text_format
                        : Icons.insights,
                    size: 16,
                    color: selected
                        ? MivaltaColors.stateProductive
                        : MivaltaColors.textMuted,
                  ),
                  const SizedBox(width: MivaltaSpace.x1),
                  Text(
                    _prefLabel(pref),
                    style: MivaltaType.label.copyWith(
                      color: selected
                          ? MivaltaColors.stateProductive
                          : MivaltaColors.textPrimary,
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _prefLabel(DetailPreference pref) {
    switch (pref) {
      case DetailPreference.wordsFirst:
        return 'Words first';
      case DetailPreference.numbersFirst:
        return 'Numbers first';
    }
  }
}

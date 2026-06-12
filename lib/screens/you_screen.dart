// You tab — settings + trends + privacy, regrouped (HOME_REDESIGN_BRIEF §3,
// founder directive 2026-06-12). An entry HUB, not a new surface: every tile
// pushes an EXISTING screen. The home app bar's settings/trends/debug actions
// migrated here so Today's app bar slims down.
//
// Display only: this screen renders no engine values, so it is identical
// across all four home states (no-data / low-confidence / normal / red).

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../rust_engine.dart';
import '../theme/tokens.dart';
import 'debug_swatch_exerciser.dart';
import 'explore_screen.dart';
import 'settings_screen.dart';

/// The You anchor: a hub of entries into the existing settings / trends /
/// privacy screens. [binding]/[handle] are null until the Today tab's engine
/// bootstrap completes (the shell shares the ONE engine instance); until then
/// engine-backed entries are no-ops — same guard pattern as the home's
/// `_open*` methods.
class YouScreen extends StatelessWidget {
  const YouScreen({
    super.key,
    required this.binding,
    required this.handle,
    required this.profileJson,
    required this.onDataCleared,
  });

  /// Shared engine binding/handle from the shell (null while bootstrapping).
  final RustEngineBinding? binding;
  final EnginesHandle? handle;

  /// Complete athlete profile JSON (engine-completed at onboarding).
  final String profileJson;

  /// Forwarded to [SettingsScreen] — parent navigates to onboarding after
  /// the delete-everything flow.
  final VoidCallback onDataCleared;

  void _openSettings(BuildContext context) {
    final b = binding;
    final h = handle;
    if (b == null || h == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(
          binding: b,
          handle: h,
          profileJson: profileJson,
          onDataCleared: onDataCleared,
        ),
      ),
    );
  }

  void _openExplore(BuildContext context) {
    final b = binding;
    final h = handle;
    if (b == null || h == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ExploreScreen(binding: b, handle: h),
      ),
    );
  }

  void _openDebugExerciser(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const DebugSwatchExerciser()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MivaltaColors.surfaceBackground,
      appBar: AppBar(
        backgroundColor: MivaltaColors.surfaceBackground,
        foregroundColor: MivaltaColors.textPrimary,
        title: const Text('You'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(MivaltaSpace.x4),
        children: [
          _YouEntry(
            icon: Icons.person_outline,
            title: 'Profile & settings',
            subtitle: 'Your details, goals, and units',
            onTap: () => _openSettings(context),
          ),
          const SizedBox(height: MivaltaSpace.x3),
          _YouEntry(
            icon: Icons.insights_outlined,
            title: 'Trends & history',
            subtitle: 'Biometrics, workouts, training load',
            onTap: () => _openExplore(context),
          ),
          const SizedBox(height: MivaltaSpace.x3),
          // Privacy & data lives inside settings today (export vault / delete
          // everything); this entry surfaces it as its own door (brief §3).
          _YouEntry(
            icon: Icons.lock_outline,
            title: 'Privacy & data',
            subtitle: 'Export your vault, delete everything',
            onTap: () => _openSettings(context),
          ),
          if (kDebugMode) ...[
            const SizedBox(height: MivaltaSpace.x3),
            _YouEntry(
              icon: Icons.bug_report_outlined,
              title: 'SourceTier exerciser',
              subtitle: 'Debug build only',
              onTap: () => _openDebugExerciser(context),
            ),
          ],
        ],
      ),
    );
  }
}

/// One hub entry row — tokens-only surface card with a chevron.
class _YouEntry extends StatelessWidget {
  const _YouEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: MivaltaColors.surface1,
      borderRadius: BorderRadius.circular(MivaltaRadii.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MivaltaRadii.md),
        child: Padding(
          padding: const EdgeInsets.all(MivaltaSpace.x4),
          child: Row(
            children: [
              Icon(icon, size: 22, color: MivaltaColors.textSecondary),
              const SizedBox(width: MivaltaSpace.x4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleSmall?.copyWith(
                        color: MivaltaColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: textTheme.bodySmall?.copyWith(
                        color: MivaltaColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: MivaltaColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

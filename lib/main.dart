// MiValta MVP-1 entry point. Production app with engine-connected UI.
//
// PR-F: First-launch detection. If no persisted profile exists, show
// onboarding wizard to collect the user's athlete profile. Otherwise
// load the saved profile and go straight to ReadinessScreen.
//
// The on-device conversational AI (model W) is in development. When it
// ships, it will be delivered via Play Asset Delivery — the app binary
// itself requires no network permission.
//
// See docs/MVP1_BUILD_BRIEF.md for the current milestone scope.

import 'dart:async';

import 'package:flutter/material.dart';

import 'rust_engine.dart';
import 'screens/onboarding_screen.dart';
import 'screens/readiness_screen.dart';
import 'services/profile_service.dart';
import 'theme/tokens.dart';

void main() {
  runApp(const MivaltaApp());
}

class MivaltaApp extends StatelessWidget {
  const MivaltaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MiValta',
      theme: mivaltaDarkTheme(),
      home: const _AppEntryPoint(),
    );
  }
}

/// PR-F: App entry point with first-launch detection.
///
/// Checks for a persisted profile on launch:
/// - If no profile exists → show onboarding wizard
/// - If profile exists → go straight to ReadinessScreen
class _AppEntryPoint extends StatefulWidget {
  const _AppEntryPoint();

  @override
  State<_AppEntryPoint> createState() => _AppEntryPointState();
}

class _AppEntryPointState extends State<_AppEntryPoint> {
  bool _loading = true;
  String? _profileJson;

  @override
  void initState() {
    super.initState();
    _checkForProfile();
  }

  Future<void> _checkForProfile() async {
    // Check if a persisted profile exists
    final profileJson = await ProfileService.loadProfile();

    if (!mounted) return;

    if (profileJson != null) {
      // Profile exists — go to ReadinessScreen
      setState(() {
        _profileJson = profileJson;
        _loading = false;
      });
    } else {
      // No profile — show onboarding
      setState(() => _loading = false);
      _showOnboarding();
    }
  }

  Future<void> _showOnboarding() async {
    final result = await Navigator.of(context).push<OnboardingResult>(
      MaterialPageRoute<OnboardingResult>(
        builder: (_) => const OnboardingScreen(),
        fullscreenDialog: true,
      ),
    );

    if (result != null && mounted) {
      // FL-16: the onboarding result is RAW inputs. The ENGINE completes them
      // into a full profile (goal_class, mesocycle, anchors) — the client
      // computes nothing — then we persist it and proceed. Completing + saving
      // here (where onboarding navigation lives) keeps the two together and
      // gives a clean retry path on failure.
      try {
        await RustEngineBinding.ensureRustInit();
        final profileJson =
            await RustEngineBinding.buildOnboardingProfile(result.inputsJson);
        await ProfileService.saveProfile(profileJson);
        if (mounted) setState(() => _profileJson = profileJson);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Setup could not be completed. Please try again.'),
          ),
        );
        // Inputs were not persisted; re-show onboarding so the user can retry.
        _showOnboarding();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: MivaltaColors.surfaceBackground,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'MiValta',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: MivaltaColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: MivaltaSpace.x4),
              const CircularProgressIndicator(
                color: MivaltaColors.primaryGreen,
              ),
            ],
          ),
        ),
      );
    }

    if (_profileJson == null) {
      // Still showing onboarding, show placeholder
      return Scaffold(
        backgroundColor: MivaltaColors.surfaceBackground,
        body: const Center(
          child: CircularProgressIndicator(
            color: MivaltaColors.primaryGreen,
          ),
        ),
      );
    }

    // Profile ready (loaded, or engine-completed from onboarding) — show home.
    return ReadinessScreen(profileJson: _profileJson);
  }
}

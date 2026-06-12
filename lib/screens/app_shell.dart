// App shell — three-anchor navigation (HOME_REDESIGN_BRIEF §3, founder
// directive 2026-06-12): Today / Plan / You on a Material 3 NavigationBar,
// state preserved per tab via IndexedStack. Existing detail screens keep
// their push routes (they sit ABOVE the shell on the root navigator).
//
// Engine ownership stays with the Today tab (ReadinessScreen) — ONE engine
// instance per app. The shell receives the binding/handle via
// [ReadinessScreen.onEngineReady] and shares them with the You tab; it
// computes nothing itself.

import 'package:flutter/material.dart';

import '../rust_engine.dart';
import '../theme/tokens.dart';
import 'plan_screen.dart';
import 'readiness_screen.dart';
import 'you_screen.dart';

/// The three-anchor shell. [profileJson] is the engine-completed athlete
/// profile (onboarding guarantees it before this is shown — main.dart).
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.profileJson});

  final String profileJson;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  // Shared with the You tab once the Today tab's bootstrap completes.
  RustEngineBinding? _binding;
  EnginesHandle? _handle;

  void _onEngineReady(RustEngineBinding binding, EnginesHandle handle) {
    if (!mounted) return;
    setState(() {
      _binding = binding;
      _handle = handle;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MivaltaColors.surfaceBackground,
      body: IndexedStack(
        index: _index,
        children: [
          ReadinessScreen(
            profileJson: widget.profileJson,
            onEngineReady: _onEngineReady,
          ),
          const PlanScreen(),
          YouScreen(
            binding: _binding,
            handle: _handle,
            profileJson: widget.profileJson,
            onDataCleared: () {
              // After data erasure, return to the app entry point (same
              // behavior as the pre-shell settings flow).
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: MivaltaColors.surface1,
        indicatorColor: MivaltaColors.surface2,
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.route_outlined),
            selectedIcon: Icon(Icons.route),
            label: 'Plan',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'You',
          ),
        ],
      ),
    );
  }
}

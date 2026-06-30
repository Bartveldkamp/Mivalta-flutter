// MiValta — blank shell entry point.
//
// UI/UX clean-out: all screens and widgets stripped. This minimal shell
// proves the app boots on intact plumbing (theme tokens, FRB bridge, services).
// The new Claude Design UI will be built onto this clean canvas.
//
// See docs/UI_CLEANOUT_PLAN.md for the clean-out scope.

import 'package:flutter/material.dart';

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
      home: const _BlankShell(),
    );
  }
}

/// Blank shell — minimal Scaffold proving the app boots on intact plumbing.
class _BlankShell extends StatelessWidget {
  const _BlankShell();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MivaltaColors.surfaceBackground,
      body: Center(
        child: Text(
          'MiValta',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: MivaltaColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}

// MiValta — production entry point.
//
// Fresh Today screen built from Claude Design specs. Engine DECIDES,
// Flutter DISPLAYS. See docs/UI_CLEANOUT_PLAN.md for the clean-out that
// preceded this fresh build.

import 'package:flutter/material.dart';

import 'screens/today_screen.dart';
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
      debugShowCheckedModeBanner: false,
      home: const TodayScreen(),
    );
  }
}

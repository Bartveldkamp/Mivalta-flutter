// Shared bottom navigation bar — W8 (DR-024).
//
// Extracted from the duplicated _buildBottomNav / _NavItem widgets that lived
// in Today and Journey screens. All three main tabs (Today, Journey, You) now
// use this single source-of-truth.

import 'package:flutter/material.dart';

import '../screens/journey_screen.dart';
import '../screens/today_screen.dart';
import '../screens/you_screen.dart';
import '../theme/tokens.dart';

/// The three main navigation tabs.
enum NavTab { today, journey, you }

/// Shared bottom navigation bar for the main app tabs.
///
/// Usage: pass the [activeTab] to highlight the current screen, and the widget
/// handles navigation via pushReplacement (full screen swap, no back stack).
class MivaltaBottomNav extends StatelessWidget {
  const MivaltaBottomNav({super.key, required this.activeTab});

  final NavTab activeTab;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: MivaltaColors.surfaceBackground,
        border: Border(
          top: BorderSide(
            color: MivaltaColors.textPrimary.withValues(alpha: 0.08),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.wb_sunny_outlined,
                activeIcon: Icons.wb_sunny,
                label: 'Today',
                isActive: activeTab == NavTab.today,
                onTap: activeTab == NavTab.today
                    ? null
                    : () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute<void>(
                              builder: (_) => const TodayScreen()),
                        ),
              ),
              _NavItem(
                icon: Icons.route_outlined,
                activeIcon: Icons.route,
                label: 'Journey',
                isActive: activeTab == NavTab.journey,
                onTap: activeTab == NavTab.journey
                    ? null
                    : () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute<void>(
                              builder: (_) => const JourneyScreen()),
                        ),
              ),
              _NavItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'You',
                isActive: activeTab == NavTab.you,
                onTap: activeTab == NavTab.you
                    ? null
                    : () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute<void>(
                              builder: (_) => const YouScreen()),
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom nav item — icon + label with active/inactive state styling.
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color =
        isActive ? MivaltaColors.stateProductive : MivaltaColors.textSecondary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: color,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

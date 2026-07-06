// W8 (DR-024): Widget tests for the shared bottom navigation bar.
//
// Verifies:
//   1. Correct structure (three tabs: Today, Journey, You)
//   2. Active state styling (productive green for active, textSecondary for inactive)
//   3. Navigation callbacks fire only for inactive tabs
//   4. Icon switching (outline → filled when active)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mivalta_flutter/widgets/mivalta_bottom_nav.dart';
import 'package:mivalta_flutter/theme/tokens.dart';

void main() {
  group('MivaltaBottomNav', () {
    testWidgets('renders three nav items: Today, Journey, You', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            bottomNavigationBar: MivaltaBottomNav(activeTab: NavTab.today),
          ),
        ),
      );

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Journey'), findsOneWidget);
      expect(find.text('You'), findsOneWidget);
    });

    testWidgets('Today tab shows active state when activeTab is today',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            bottomNavigationBar: MivaltaBottomNav(activeTab: NavTab.today),
          ),
        ),
      );

      // Active tab should show filled icon (wb_sunny, not wb_sunny_outlined)
      expect(find.byIcon(Icons.wb_sunny), findsOneWidget);
      expect(find.byIcon(Icons.wb_sunny_outlined), findsNothing);

      // Inactive tabs should show outlined icons
      expect(find.byIcon(Icons.route_outlined), findsOneWidget);
      expect(find.byIcon(Icons.person_outline), findsOneWidget);

      // Active text color should be stateProductive
      final todayText = tester.widget<Text>(find.text('Today'));
      expect(
        todayText.style?.color,
        equals(MivaltaColors.stateProductive),
        reason: 'Active tab text should be stateProductive',
      );

      // Inactive text color should be textSecondary
      final journeyText = tester.widget<Text>(find.text('Journey'));
      expect(
        journeyText.style?.color,
        equals(MivaltaColors.textSecondary),
        reason: 'Inactive tab text should be textSecondary',
      );
    });

    testWidgets('Journey tab shows active state when activeTab is journey',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            bottomNavigationBar: MivaltaBottomNav(activeTab: NavTab.journey),
          ),
        ),
      );

      // Active tab should show filled icon
      expect(find.byIcon(Icons.route), findsOneWidget);
      expect(find.byIcon(Icons.route_outlined), findsNothing);

      // Inactive tabs should show outlined icons
      expect(find.byIcon(Icons.wb_sunny_outlined), findsOneWidget);
      expect(find.byIcon(Icons.person_outline), findsOneWidget);

      // Active text color should be stateProductive
      final journeyText = tester.widget<Text>(find.text('Journey'));
      expect(
        journeyText.style?.color,
        equals(MivaltaColors.stateProductive),
        reason: 'Active tab text should be stateProductive',
      );
    });

    testWidgets('You tab shows active state when activeTab is you',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            bottomNavigationBar: MivaltaBottomNav(activeTab: NavTab.you),
          ),
        ),
      );

      // Active tab should show filled icon
      expect(find.byIcon(Icons.person), findsOneWidget);
      expect(find.byIcon(Icons.person_outline), findsNothing);

      // Inactive tabs should show outlined icons
      expect(find.byIcon(Icons.wb_sunny_outlined), findsOneWidget);
      expect(find.byIcon(Icons.route_outlined), findsOneWidget);

      // Active text color should be stateProductive
      final youText = tester.widget<Text>(find.text('You'));
      expect(
        youText.style?.color,
        equals(MivaltaColors.stateProductive),
        reason: 'Active tab text should be stateProductive',
      );
    });

    testWidgets('active tab does not navigate when tapped', (tester) async {
      // Track navigation attempts
      var navigationAttempted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: const Scaffold(
            bottomNavigationBar: MivaltaBottomNav(activeTab: NavTab.today),
          ),
          onGenerateRoute: (settings) {
            navigationAttempted = true;
            return null;
          },
        ),
      );

      // Tap on Today (active tab)
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();

      // No navigation should occur
      expect(
        navigationAttempted,
        isFalse,
        reason: 'Active tab should not trigger navigation',
      );
    });

    testWidgets('icon color matches text color', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            bottomNavigationBar: MivaltaBottomNav(activeTab: NavTab.today),
          ),
        ),
      );

      // Active icon should be stateProductive
      final activeIcon = tester.widget<Icon>(find.byIcon(Icons.wb_sunny));
      expect(
        activeIcon.color,
        equals(MivaltaColors.stateProductive),
        reason: 'Active icon should be stateProductive',
      );

      // Inactive icon should be textSecondary
      final inactiveIcon =
          tester.widget<Icon>(find.byIcon(Icons.route_outlined));
      expect(
        inactiveIcon.color,
        equals(MivaltaColors.textSecondary),
        reason: 'Inactive icon should be textSecondary',
      );
    });

    testWidgets('nav bar has correct background and border', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            bottomNavigationBar: MivaltaBottomNav(activeTab: NavTab.today),
          ),
        ),
      );

      // Find the Container with decoration
      final containers = tester.widgetList<Container>(find.byType(Container));
      final navContainer = containers.firstWhere(
        (c) => c.decoration is BoxDecoration,
        orElse: () => throw StateError('No decorated container found'),
      );

      final decoration = navContainer.decoration as BoxDecoration;
      expect(
        decoration.color,
        equals(MivaltaColors.surfaceBackground),
        reason: 'Nav bar background should be surfaceBackground',
      );
      expect(
        decoration.border,
        isNotNull,
        reason: 'Nav bar should have a border',
      );
    });

    testWidgets('active font weight is heavier than inactive', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            bottomNavigationBar: MivaltaBottomNav(activeTab: NavTab.today),
          ),
        ),
      );

      final todayText = tester.widget<Text>(find.text('Today'));
      final journeyText = tester.widget<Text>(find.text('Journey'));

      expect(
        todayText.style?.fontWeight,
        equals(FontWeight.w600),
        reason: 'Active tab should be w600',
      );
      expect(
        journeyText.style?.fontWeight,
        equals(FontWeight.w500),
        reason: 'Inactive tab should be w500',
      );
    });
  });
}

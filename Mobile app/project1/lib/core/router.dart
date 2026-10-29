import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/dashboard/dashboard_screen.dart';
import '../screens/energy_history/energy_history_screen.dart';
import '../screens/decisions/decisions_screen.dart';
import '../screens/appliances/appliances_screen.dart';
import '../screens/alerts/alerts_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/ai_chat/ai_chat_screen.dart';
import '../shared/widgets/bottom_nav.dart';

/// Named route keys
class AppRoutes {
  static const String dashboard     = '/';
  static const String energyHistory = '/energy-history';
  static const String decisions     = '/decisions';
  static const String appliances    = '/appliances';
  static const String alerts        = '/alerts';
  static const String aiChat        = '/ai-chat';
  static const String settings      = '/settings';
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.dashboard,
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: AppRoutes.dashboard,
          pageBuilder: (context, state) => _fade(const DashboardScreen()),
        ),
        GoRoute(
          path: AppRoutes.energyHistory,
          pageBuilder: (context, state) => _fade(const EnergyHistoryScreen()),
        ),
        GoRoute(
          path: AppRoutes.decisions,
          pageBuilder: (context, state) => _fade(const DecisionsScreen()),
        ),
        GoRoute(
          path: AppRoutes.appliances,
          pageBuilder: (context, state) => _fade(const AppliancesScreen()),
        ),
        GoRoute(
          path: AppRoutes.alerts,
          pageBuilder: (context, state) => _fade(const AlertsScreen()),
        ),
        GoRoute(
          path: AppRoutes.aiChat,
          pageBuilder: (context, state) => _fade(const AiChatScreen()),
        ),
        GoRoute(
          path: AppRoutes.settings,
          pageBuilder: (context, state) => _fade(const SettingsScreen()),
        ),
      ],
    ),
  ],
);

CustomTransitionPage _fade(Widget child) => CustomTransitionPage(
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
      transitionDuration: const Duration(milliseconds: 200),
    );

/// Shell that wraps every screen with the shared floating bottom nav.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1326),
      body: child,
      bottomNavigationBar: const HcposBottomNav(),
    );
  }
}

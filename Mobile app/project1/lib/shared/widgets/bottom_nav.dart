import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/router.dart';

/// Floating pill-shaped bottom navigation bar matching the Stitch design.
class HcposBottomNav extends StatelessWidget {
  const HcposBottomNav({super.key});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;

    return Container(
      color: Colors.transparent,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).padding.bottom + 16,
          top: 8,
        ),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerHighest.withOpacity(0.6),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.home_rounded,
                  route: AppRoutes.dashboard,
                  currentLocation: location,
                ),
                _NavItem(
                  icon: Icons.bar_chart_rounded,
                  route: AppRoutes.energyHistory,
                  currentLocation: location,
                ),
                _NavItem(
                  icon: Icons.psychology_rounded,
                  route: AppRoutes.decisions,
                  currentLocation: location,
                ),
                _NavItem(
                  icon: Icons.electrical_services_rounded,
                  route: AppRoutes.appliances,
                  currentLocation: location,
                ),
                _NavItem(
                  icon: Icons.auto_awesome_rounded,
                  route: AppRoutes.aiChat,
                  currentLocation: location,
                ),
                _NavItem(
                  icon: Icons.settings_rounded,
                  route: AppRoutes.settings,
                  currentLocation: location,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.route,
    required this.currentLocation,
  });

  final IconData icon;
  final String route;
  final String currentLocation;

  bool get isActive => currentLocation == route;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go(route),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 15,
                    spreadRadius: 0,
                  )
                ]
              : [],
        ),
        child: Icon(
          icon,
          size: 24,
          color: isActive ? AppColors.primary : AppColors.onSurfaceVariant,
        ),
      ),
    );
  }
}

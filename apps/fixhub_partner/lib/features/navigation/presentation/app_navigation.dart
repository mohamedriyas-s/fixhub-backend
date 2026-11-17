import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/theme/app_colors.dart';
import '../../jobs/presentation/job_provider.dart';

class AppNavigation extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const AppNavigation({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignedCount = ref.watch(assignedJobsCountProvider);

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (index) {
            navigationShell.goBranch(
              index,
              initialLocation: index == navigationShell.currentIndex,
            );
          },
          backgroundColor: AppColors.surface,
          elevation: 0,
          height: 65,
          indicatorColor: Colors.transparent,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            _NavigationDestination(
              icon: Icons.home_outlined,
              selectedIcon: Icons.home_rounded,
              label: 'Home',
              isSelected: navigationShell.currentIndex == 0,
            ),
            _NavigationDestination(
              icon: Icons.work_outline_rounded,
              selectedIcon: Icons.work_rounded,
              label: 'Jobs',
              isSelected: navigationShell.currentIndex == 1,
              badgeCount: assignedCount,
            ),
            _NavigationDestination(
              icon: Icons.account_balance_wallet_outlined,
              selectedIcon: Icons.account_balance_wallet_rounded,
              label: 'Earnings',
              isSelected: navigationShell.currentIndex == 2,
            ),
            _NavigationDestination(
              icon: Icons.person_outline_rounded,
              selectedIcon: Icons.person_rounded,
              label: 'Profile',
              isSelected: navigationShell.currentIndex == 3,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavigationDestination extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final int badgeCount;

  const _NavigationDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    Widget iconWidget = Icon(icon, color: AppColors.textSecondary, size: 24);
    Widget selectedIconWidget = Icon(selectedIcon, color: AppColors.primary, size: 24);

    if (badgeCount > 0) {
      final badgeLabel = Text(
        badgeCount > 99 ? '99+' : '$badgeCount',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          height: 1,
        ),
      );

      iconWidget = Badge(
        label: badgeLabel,
        backgroundColor: AppColors.error,
        child: iconWidget,
      );
      selectedIconWidget = Badge(
        label: badgeLabel,
        backgroundColor: AppColors.error,
        child: selectedIconWidget,
      );
    }

    return NavigationDestination(
      icon: iconWidget,
      selectedIcon: selectedIconWidget,
      label: label,
    );
  }
}

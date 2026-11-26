import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/theme/app_colors.dart';
import '../../jobs/presentation/job_provider.dart';

class AppNavigation extends ConsumerStatefulWidget {
  final StatefulNavigationShell navigationShell;

  const AppNavigation({super.key, required this.navigationShell});

  @override
  ConsumerState<AppNavigation> createState() => _AppNavigationState();
}

class _AppNavigationState extends ConsumerState<AppNavigation> {
  final List<int> _tabHistory = [0];

  void _onDestinationSelected(int index) {
    if (index != widget.navigationShell.currentIndex) {
      setState(() {
        _tabHistory.remove(index);
        _tabHistory.add(index);
      });
      widget.navigationShell.goBranch(index);
    } else {
      widget.navigationShell.goBranch(
        index,
        initialLocation: true,
      );
    }
  }

  void _handleBack() {
    if (_tabHistory.length > 1) {
      setState(() {
        _tabHistory.removeLast();
      });
      final prevIndex = _tabHistory.last;
      widget.navigationShell.goBranch(prevIndex);
    } else if (widget.navigationShell.currentIndex != 0) {
      setState(() {
        _tabHistory.clear();
        _tabHistory.add(0);
      });
      widget.navigationShell.goBranch(0);
    }
  }

  Future<bool> _onBackButtonPressed() async {
    // If a dialog, bottom sheet, or pushed route is on top of the shell, let it pop normally.
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) {
      return false;
    }
    if (widget.navigationShell.currentIndex != 0 || _tabHistory.length > 1) {
      _handleBack();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final assignedCount = ref.watch(assignedJobsCountProvider);
    final canPop = widget.navigationShell.currentIndex == 0 && _tabHistory.length <= 1;

    return BackButtonListener(
      onBackButtonPressed: _onBackButtonPressed,
      child: PopScope(
        canPop: canPop,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          _handleBack();
        },
        child: Scaffold(
        body: widget.navigationShell,
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.border, width: 1)),
          ),
          child: NavigationBar(
            selectedIndex: widget.navigationShell.currentIndex,
            onDestinationSelected: _onDestinationSelected,
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
                isSelected: widget.navigationShell.currentIndex == 0,
              ),
              _NavigationDestination(
                icon: Icons.work_outline_rounded,
                selectedIcon: Icons.work_rounded,
                label: 'Jobs',
                isSelected: widget.navigationShell.currentIndex == 1,
                badgeCount: assignedCount,
              ),
              _NavigationDestination(
                icon: Icons.account_balance_wallet_outlined,
                selectedIcon: Icons.account_balance_wallet_rounded,
                label: 'Earnings',
                isSelected: widget.navigationShell.currentIndex == 2,
              ),
              _NavigationDestination(
                icon: Icons.person_outline_rounded,
                selectedIcon: Icons.person_rounded,
                label: 'Profile',
                isSelected: widget.navigationShell.currentIndex == 3,
              ),
            ],
          ),
        ),
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/notifications/data/datasources/fcm_service.dart';

class ScaffoldWithNavBar extends ConsumerStatefulWidget {
  const ScaffoldWithNavBar({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<ScaffoldWithNavBar> createState() => _ScaffoldWithNavBarState();
}

class _ScaffoldWithNavBarState extends ConsumerState<ScaffoldWithNavBar> {
  final List<int> _tabHistory = [0];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Register FCM token and start listening for foreground messages
      // This happens safely after login because ScaffoldWithNavBar is only
      // rendered for authenticated routes.
      ref.read(fcmServiceProvider).registerAfterLogin();
      
      // Consume any pending deep-link from a notification tap
      final pendingRoute = FCMService.consumePendingRoute();
      if (pendingRoute != null) {
        context.push('/booking-detail/$pendingRoute');
      }
    });
  }

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
        bottomNavigationBar: NavigationBar(
          selectedIndex: widget.navigationShell.currentIndex,
          onDestinationSelected: _onDestinationSelected,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_today_outlined),
              selectedIcon: Icon(Icons.calendar_today_rounded),
              label: 'Bookings',
            ),
            NavigationDestination(
              icon: Icon(Icons.help_outline_rounded),
              selectedIcon: Icon(Icons.help_rounded),
              label: 'Support',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
      ),
    );
  }
}

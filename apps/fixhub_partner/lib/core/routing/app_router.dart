import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/otp_screen.dart';
import '../../features/auth/presentation/auth_provider.dart';
import '../../features/auth/domain/auth_state.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/jobs/presentation/my_jobs_screen.dart';
import '../../features/jobs/presentation/job_details_screen.dart';
import '../../features/jobs/presentation/job_offers_screen.dart';
import '../../features/jobs/presentation/enroute_screen.dart';
import '../../features/earnings/presentation/earnings_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/profile/presentation/edit_specializations_screen.dart';
import '../../features/profile/presentation/edit_service_areas_screen.dart';
import '../../features/onboarding/presentation/setup_wizard_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/settings/about_partner_screen.dart';
import '../../features/navigation/presentation/app_navigation.dart';

// ── Route Name Constants ──────────────────────────────────────────
class RouteNames {
  RouteNames._();
  static const splash = 'splash';
  static const login = 'login';
  static const otp = 'otp';
  static const setup = 'setup';
  static const dashboard = 'dashboard';
  static const jobs = 'jobs';
  static const earnings = 'earnings';
  static const profile = 'profile';
  static const jobDetails = 'job-details';
  static const jobEnRoute = 'job-enroute';
  static const offers = 'offers';
  static const notifications = 'notifications';
  static const settings = 'settings';
  static const about = 'about';
  static const editSpecializations = 'edit-specializations';
  static const editServiceAreas = 'edit-service-areas';
}

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
// Exported so FcmService can show SnackBars & navigate from push notifications
final GlobalKey<NavigatorState> appNavigatorKey = _rootNavigatorKey;
final GlobalKey<NavigatorState> _homeNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _jobsNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _earningsNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _profileNavigatorKey = GlobalKey<NavigatorState>();

// ── Router Notifier for Reactive Auth State ────────────────────────
class _PartnerRouterNotifier extends ChangeNotifier {
  _PartnerRouterNotifier(Ref ref) {
    ref.listen(authProvider, (_, __) => notifyListeners());
  }
}

// ── Router as Riverpod Provider ───────────────────────────────────
final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _PartnerRouterNotifier(ref);
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    debugLogDiagnostics: false,
    refreshListenable: notifier,
    // ── Auth redirect guard ────────────────────────────────────
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final location = state.matchedLocation;
      final isOnAuthPage = location == '/splash' ||
          location == '/login' ||
          location == '/otp';

      // If authenticated and on auth page, redirect to dashboard
      if (authState is AuthAuthenticated && isOnAuthPage && location != '/splash') {
        return '/dashboard';
      }

      // If unauthenticated and NOT on auth page, redirect to login
      if (authState is AuthUnauthenticated && !isOnAuthPage) {
        return '/login';
      }

      return null;
    },
    routes: [
      // ── Auth ───────────────────────────────────────────────────────
      GoRoute(
        path: '/splash',
        name: RouteNames.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        name: RouteNames.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/otp',
        name: RouteNames.otp,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final email = extra['email'] as String? ?? '';
          final devOtp = extra['devOtp'] as String?;
          return OtpScreen(email: email, devOtp: devOtp);
        },
      ),

      // ── First-time setup wizard ──────────────────────────────────
      GoRoute(
        path: '/setup',
        name: RouteNames.setup,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SetupWizardScreen(),
      ),

      // ── Navigation Shell ─────────────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppNavigation(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            navigatorKey: _homeNavigatorKey,
            routes: [
              GoRoute(
                path: '/dashboard',
                name: RouteNames.dashboard,
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _jobsNavigatorKey,
            routes: [
              GoRoute(
                path: '/jobs',
                name: RouteNames.jobs,
                builder: (context, state) => const MyJobsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _earningsNavigatorKey,
            routes: [
              GoRoute(
                path: '/earnings',
                name: RouteNames.earnings,
                builder: (context, state) => const EarningsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _profileNavigatorKey,
            routes: [
              GoRoute(
                path: '/profile',
                name: RouteNames.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // ── Nested / Global Routes ───────────────────────────────────
      GoRoute(
        path: '/job-details/:id',
        name: RouteNames.jobDetails,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return JobDetailsScreen(jobId: id);
        },
      ),
      GoRoute(
        path: '/job-enroute/:id',
        name: RouteNames.jobEnRoute,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return EnRouteScreen(jobId: id);
        },
      ),
      GoRoute(
        path: '/offers',
        name: RouteNames.offers,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const JobOffersScreen(),
      ),
      GoRoute(
        path: '/notifications',
        name: RouteNames.notifications,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/settings',
        name: RouteNames.settings,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/about',
        name: RouteNames.about,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AboutPartnerScreen(),
      ),
      GoRoute(
        path: '/edit-specializations',
        name: RouteNames.editSpecializations,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const EditSpecializationsScreen(),
      ),
      GoRoute(
        path: '/edit-service-areas',
        name: RouteNames.editServiceAreas,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const EditServiceAreasScreen(),
      ),
    ],
  );
});

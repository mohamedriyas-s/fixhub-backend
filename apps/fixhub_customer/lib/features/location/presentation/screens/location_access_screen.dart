import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_spacing.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/widgets/fixhub_button.dart';
import '../../../../core/widgets/fixhub_snackbar.dart';
import '../providers/location_provider.dart';

class LocationAccessScreen extends ConsumerStatefulWidget {
  const LocationAccessScreen({super.key});

  @override
  ConsumerState<LocationAccessScreen> createState() => _LocationAccessScreenState();
}

class _LocationAccessScreenState extends ConsumerState<LocationAccessScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(locationProvider.notifier).refreshPermission();
    }
  }

  @override
  Widget build(BuildContext context) {
    final locationState = ref.watch(locationProvider);

    ref.listen<LocationState>(locationProvider, (previous, next) {
      if (!(ModalRoute.of(context)?.isCurrent ?? false)) return;
      if (next.status == LocationStatus.valid) {
        context.go(RouteNames.home);
      } else if (next.status == LocationStatus.invalid) {
        context.go('/location/not-covered');
      } else if (next.status == LocationStatus.error && next.errorMessage != null) {
        FixHubSnackbar.error(context, next.errorMessage!);
        ref.read(locationProvider.notifier).clearError();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              
              Container(
                width: 200,
                height: 200,
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  size: 80,
                  color: AppColors.buttonPrimary,
                ),
              ),
              
              const SizedBox(height: AppSpacing.xxl),
              
              Text(
                'Enable Location',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: AppColors.textPrimary,
                    ),
              ),
              
              const SizedBox(height: AppSpacing.md),
              
              Text(
                'We need your location to show services near you',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              
              const Spacer(),
              
              FixHubButton(
                label: 'Enable Location',
                isLoading: locationState.status == LocationStatus.checking,
                onPressed: () {
                  ref.read(locationProvider.notifier).detectFromGPS();
                },
              ),
              
              const SizedBox(height: AppSpacing.md),
              
              TextButton(
                onPressed: () {
                  context.push(RouteNames.setLocation);
                },
                child: Text(
                  'Enter manually',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              
              const SizedBox(height: AppSpacing.bottomSafePadding),
            ],
          ),
        ),
      ),
    );
  }
}

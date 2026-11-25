import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_spacing.dart';
import '../../../../core/router/route_names.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../location/presentation/providers/location_provider.dart';
import '../../../notifications/presentation/providers/notification_provider.dart';

/// Greeting header showing "Hello, {name}" with location indicator,
/// gradient avatar, and notification bell.
class GreetingHeader extends ConsumerWidget {
  const GreetingHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final locationState = ref.watch(locationProvider);
    final userName = authState.user?.displayName ?? 'there';
    final firstLetter = userName.isNotEmpty ? userName[0].toUpperCase() : 'C';
    final locationDisplay = () {
      if (locationState.status != LocationStatus.valid ||
          locationState.currentPincode == null ||
          locationState.currentPincode!.isEmpty) {
        return 'Set Location';
      }
      final city = locationState.currentCity;
      if (city != null && city.trim().isNotEmpty) {
        if (city.contains(locationState.currentPincode!)) {
          return city;
        }
        return '$city, ${locationState.currentPincode}';
      }
      return 'Chennai, ${locationState.currentPincode}';
    }();

    // Time-based greeting
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting 👋',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                userName == 'there' ? 'Welcome back!' : userName,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              // Location selector
              GestureDetector(
                onTap: () => context.push(RouteNames.setLocation),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border, width: 0.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        size: 13,
                        color: AppColors.textPrimary,
                      ),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          locationDisplay,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Notification Bell
        GestureDetector(
          onTap: () => context.push(RouteNames.notifications),
          child: Stack(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border, width: 0.5),
                ),
                child: const Icon(
                  Icons.notifications_outlined,
                  color: AppColors.textPrimary,
                  size: 24,
                ),
              ),
              // Unread badge logic
              Consumer(
                builder: (context, ref, _) {
                  final notificationsAsync = ref.watch(notificationsProvider);
                  final unreadCount = notificationsAsync.maybeWhen(
                    data: (notifications) =>
                        notifications.where((n) => !n.isRead).length,
                    orElse: () => 0,
                  );

                  if (unreadCount <= 0) return const SizedBox.shrink();

                  return Positioned(
                    right: 2,
                    top: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.surface,
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          unreadCount > 99 ? '99+' : '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),

        // Gradient avatar
        GestureDetector(
      onTap: () => context.go(RouteNames.profile),
          child: Container(
            width: AppSpacing.avatarSize,
            height: AppSpacing.avatarSize,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2B2111), Color(0xFF6B5A3E)],
              ),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: Center(
              child: Text(
                firstLetter,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

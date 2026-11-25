import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_spacing.dart';
import '../../../../core/widgets/fixhub_app_bar.dart';
import '../../../../core/widgets/fixhub_error_state.dart';
import '../../../../core/widgets/fixhub_shimmer.dart';
import '../providers/notification_provider.dart';
import '../../data/models/notification_model.dart';

/// Notifications screen displaying a list of push notifications.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Refresh notifications on mount
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(notificationsProvider);
    });
  }

  Future<void> _markAllAsRead() async {
    await ref.read(notificationNotifierProvider.notifier).markAllAsRead();
  }

  Future<void> _confirmDeleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.elevatedSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete all notifications?'),
        content: const Text('This will permanently remove all your notifications.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete all'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(notificationNotifierProvider.notifier).deleteAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final notifierState = ref.watch(notificationNotifierProvider);
    final isUpdating = notifierState.isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: FixHubAppBar(
        title: 'Notifications',
        actions: [
          notificationsAsync.maybeWhen(
            data: (notifications) {
              if (notifications.isEmpty) return const SizedBox.shrink();
              final hasUnread = notifications.any((n) => !n.isRead);

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasUnread)
                    TextButton(
                      onPressed: isUpdating ? null : _markAllAsRead,
                      child: isUpdating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              'Mark all as read',
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: AppColors.buttonPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                    ),
                  TextButton(
                    onPressed: isUpdating ? null : _confirmDeleteAll,
                    child: Text(
                      'Delete all',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.buttonPrimary,
        onRefresh: () async {
          ref.invalidate(notificationsProvider);
          await ref.read(notificationsProvider.future);
        },
        child: notificationsAsync.when(
          data: (notifications) {
            if (notifications.isEmpty) {
              return _buildEmptyState(context);
            }

            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return _NotificationCard(notification: notification);
              },
            );
          },
          loading: () => Padding(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            child: FixHubShimmer.listPlaceholder(itemCount: 8),
          ),
          error: (error, stackTrace) {
            debugPrint('[NotificationsScreen] Error: $error\n$stackTrace');
            return FixHubErrorState(
              onRetry: () => ref.invalidate(notificationsProvider),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 64,
                color: AppColors.textDisabled,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'No notifications yet',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.textPrimary,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'We will notify you when there is an update regarding your bookings or account.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationCard extends ConsumerWidget {
  const _NotificationCard({required this.notification});

  final NotificationModel notification;

  void _handleTap(BuildContext context, WidgetRef ref) {
    // Mark as read if not already read
    if (!notification.isRead) {
      ref.read(notificationNotifierProvider.notifier).markAsRead(notification.id);
    }

    // Deep link handling (supports root bookingId or nested inside payload)
    final data = notification.data;
    final payload = data?['payload'] is Map ? (data!['payload'] as Map) : data;
    final bookingId = payload?['bookingId'] as String?;
    if (bookingId != null && bookingId.isNotEmpty) {
      context.push('/booking-detail/$bookingId');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (IconData icon, Color color, Color bgColor) = _getNotificationStyle(notification.type);

    return GestureDetector(
      onTap: () => _handleTap(context, ref),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: notification.isRead ? AppColors.surface : AppColors.elevatedSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: notification.isRead ? AppColors.border : AppColors.buttonPrimary.withOpacity(0.3),
            width: 0.5,
          ),
          boxShadow: notification.isRead
              ? []
              : [
                  BoxShadow(
                    color: AppColors.buttonPrimary.withOpacity(0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.bold,
                              ),
                        ),
                      ),
                      if (!notification.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(top: 6, left: AppSpacing.xs),
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                        ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () => ref
                            .read(notificationNotifierProvider.notifier)
                            .deleteNotification(notification.id),
                        borderRadius: BorderRadius.circular(16),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.body,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatTime(notification.createdAt),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.textDisabled,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  (IconData, Color, Color) _getNotificationStyle(String type) {
    switch (type.toUpperCase()) {
      case 'BOOKING_UPDATE':
      case 'BOOKING_CREATED':
      case 'BOOKING_CONFIRMED':
        return (Icons.calendar_today_rounded, const Color(0xFF2196F3), const Color(0xFFE3F2FD));
      case 'TECHNICIAN_ASSIGNED':
      case 'TECHNICIAN_EN_ROUTE':
        return (Icons.person_rounded, const Color(0xFF3F51B5), const Color(0xFFE8EAF6));
      case 'SERVICE_STARTED':
      case 'SERVICE_COMPLETED':
        return (Icons.build_circle_rounded, const Color(0xFF4CAF50), const Color(0xFFE8F5E9));
      case 'PAYMENT_SUCCESS':
      case 'PAYMENT_PENDING':
        return (Icons.payment_rounded, const Color(0xFF4CAF50), const Color(0xFFE8F5E9));
      case 'BOOKING_CANCELLED':
      case 'BOOKING_FAILED':
        return (Icons.cancel_rounded, AppColors.error, AppColors.error.withOpacity(0.1));
      case 'PRICE_REVISION':
        return (Icons.request_quote_rounded, const Color(0xFFF59E0B), const Color(0xFFFFF8E1));
      default:
        return (Icons.notifications_rounded, AppColors.textSecondary, AppColors.border);
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1 && now.day == time.day) {
      return DateFormat('hh:mm a').format(time);
    } else if (difference.inDays < 2 && now.day != time.day) {
      return 'Yesterday, ${DateFormat('hh:mm a').format(time)}';
    } else {
      return DateFormat('MMM d, yyyy · hh:mm a').format(time);
    }
  }
}

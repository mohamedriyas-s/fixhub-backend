import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/config/theme/app_colors.dart';
import '../../../core/config/theme/app_spacing.dart';
import '../../../core/config/theme/app_radius.dart';
import '../../../core/widgets/fp_skeleton.dart';
import '../../../core/widgets/fp_offline_banner.dart';
import '../data/notification_repository.dart';
import 'notification_provider.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  Future<void> _confirmDeleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
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
      await ref.read(notificationsProvider.notifier).deleteAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final notifications = notificationsAsync.value ?? const <AppNotification>[];
    final hasUnread = notifications.any((n) => !n.isRead);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: const Text(
          'Notifications',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          if (hasUnread)
            TextButton(
              onPressed: () =>
                  ref.read(notificationsProvider.notifier).markAllAsRead(),
              child: const Text('Mark all read'),
            ),
          if (notifications.isNotEmpty)
            TextButton(
              onPressed: _confirmDeleteAll,
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Delete all'),
            ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.read(notificationsProvider.notifier).load(),
        child: notificationsAsync.when(
          skipLoadingOnReload: true,
          skipLoadingOnRefresh: true,
          loading: () => ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            itemCount: 6,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, __) => const FpSkeleton(height: 72),
          ),
          error: (e, _) => notificationsAsync.hasValue
              ? _buildList(notificationsAsync.value!)
              : FpErrorState(
                  message: 'Could not load notifications',
                  onRetry: () => ref.read(notificationsProvider.notifier).load(),
                ),
          data: (notifications) => _buildList(notifications),
        ),
      ),
    );
  }

  Widget _buildList(List<AppNotification> notifications) {
    if (notifications.isEmpty) {
      return const FpEmptyState(
        title: 'All Caught Up!',
        subtitle: 'You have no notifications right now.',
        icon: Icons.notifications_none_rounded,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      itemCount: notifications.length,
      itemBuilder: (context, i) {
        final n = notifications[i];
        return _NotificationTile(notification: n);
      },
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  final AppNotification notification;

  const _NotificationTile({required this.notification});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        if (!notification.isRead) {
          ref.read(notificationsProvider.notifier).markAsRead(notification.id);
        }
        final data = notification.data;
        final bookingId = data?['bookingId'] ?? data?['payload']?['bookingId'];
        if (bookingId != null && bookingId.toString().isNotEmpty) {
          context.push('/job-details/$bookingId');
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          color: notification.isRead
              ? AppColors.surface
              : AppColors.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: notification.isRead
                ? AppColors.border
                : AppColors.primary.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _iconBg(notification.type),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(
                _icon(notification.type),
                size: 20,
                color: _iconColor(notification.type),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: notification.isRead
                          ? FontWeight.w400
                          : FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notification.body,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _timeAgo(notification.createdAt),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textDisabled,
                    ),
                  ),
                ],
              ),
            ),
            if (!notification.isRead)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6, left: 6),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            const SizedBox(width: 2),
            InkWell(
              onTap: () => ref
                  .read(notificationsProvider.notifier)
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
      ),
    );
  }

  IconData _icon(String type) => switch (type) {
    'BOOKING_UPDATE' || 'ASSIGNMENT' => Icons.work_outline_rounded,
    'PAYMENT_UPDATE' => Icons.account_balance_wallet_outlined,
    'REVIEW' => Icons.star_outline_rounded,
    _ => Icons.notifications_outlined,
  };

  Color _iconBg(String type) => switch (type) {
    'BOOKING_UPDATE' || 'ASSIGNMENT' => AppColors.primaryContainer,
    'PAYMENT_UPDATE' => AppColors.successLight,
    'REVIEW' => const Color(0xFFFFF8E0),
    _ => AppColors.surfaceVariant,
  };

  Color _iconColor(String type) => switch (type) {
    'BOOKING_UPDATE' || 'ASSIGNMENT' => AppColors.primary,
    'PAYMENT_UPDATE' => AppColors.success,
    'REVIEW' => const Color(0xFFD4A017),
    _ => AppColors.textSecondary,
  };

  String _timeAgo(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt.toLocal());
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('d MMM').format(dt.toLocal());
  }
}

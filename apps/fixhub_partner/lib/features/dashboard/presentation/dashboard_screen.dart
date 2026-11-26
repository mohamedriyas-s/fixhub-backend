import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/config/theme/app_colors.dart';
import '../../../core/config/theme/app_spacing.dart';
import '../../../core/config/theme/app_radius.dart';
import '../../../core/widgets/fp_card.dart';
import '../../../core/widgets/fp_status_chip.dart';
import '../../../core/widgets/fp_availability_toggle.dart';
import '../../../core/widgets/fp_skeleton.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../auth/domain/auth_state.dart';
import '../../profile/presentation/profile_provider.dart';
import '../../jobs/presentation/job_provider.dart';
import '../../jobs/domain/job_models.dart';
import '../../earnings/presentation/earnings_provider.dart';
import '../../notifications/presentation/notification_provider.dart';
import '../../../core/services/fcm_service.dart';
import '../../../core/services/location_tracker.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with WidgetsBindingObserver {
  bool _isTogglingAvailability = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initialize FCM and refresh data on mount
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(fcmServiceProvider).initialize();
      ref.read(notificationsProvider.notifier).load(silent: true);
      ref.invalidate(myJobsProvider(null));
      ref.invalidate(activeJobProvider);
      if (!ref.read(profileProvider).isLoading) {
        ref.read(profileProvider.notifier).load();
      }
    });

    // Periodic real-time poll for unread notifications and assigned jobs (every 8 seconds)
    _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted) {
        ref.read(notificationsProvider.notifier).load(silent: true);
        ref.invalidate(myJobsProvider(null));
        ref.invalidate(activeJobProvider);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      ref.read(notificationsProvider.notifier).load(silent: true);
      ref.invalidate(myJobsProvider(null));
      ref.invalidate(activeJobProvider);
      final profile = ref.read(profileProvider).value;
      if (profile?.isAvailable ?? false) {
        ref.read(locationTrackerProvider).start();
      }
      ref.read(profileProvider.notifier).load();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _toggleAvailability(bool value) async {
    setState(() => _isTogglingAvailability = true);
    try {
      await ref.read(profileProvider.notifier).toggleAvailability(value);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value
                  ? 'Could not go online. Are you verified?'
                  : 'Could not go offline.',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isTogglingAvailability = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final profileAsync = ref.watch(profileProvider);
    final currentJobAsync = ref.watch(activeJobProvider);
    final todayEarningsAsync = ref.watch(todayEarningsProvider);
    final unreadCount = ref.watch(unreadCountProvider);
    final assignedJobs = ref
            .watch(myJobsProvider(null))
            .value
            ?.items
            .where((j) => j.status == 'ASSIGNED')
            .toList() ??
        const <Job>[];

    final user = authState is AuthAuthenticated ? authState.user : null;
    final profile = profileAsync.value;

    final technicianName = (profile?.name != null && profile!.name!.trim().isNotEmpty)
        ? profile.name!.trim()
        : ((user?.name != null && user!.name!.trim().isNotEmpty)
            ? user.name!.trim()
            : 'Technician');

    final technicianPhone = (profile?.phone != null && profile!.phone!.trim().isNotEmpty)
        ? profile.phone!.trim()
        : (user != null && user.phone.trim().isNotEmpty
            ? user.phone.trim()
            : '');

    // Listen for newly assigned jobs and notify the technician immediately with an in-app banner
    ref.listen<int>(assignedJobsCountProvider, (previous, current) {
      if ((previous == null || previous == 0) && current > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.work_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '🔧 $current new job${current > 1 ? 's' : ''} assigned! Tap to view.',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1F1F1F),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'View',
              textColor: Colors.white,
              onPressed: () => context.go('/jobs'),
            ),
          ),
        );
      }
    });

    // Listen for newly received unread notifications and pop up a notification banner
    ref.listen<int>(unreadCountProvider, (previous, current) {
      if ((previous ?? 0) < current) {
        final notifs = ref.read(notificationsProvider).value;
        final latest = (notifs != null && notifs.isNotEmpty) ? notifs.first : null;
        if (latest != null && !latest.isRead) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    latest.title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white),
                  ),
                  if (latest.body.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        latest.body,
                        style: const TextStyle(fontSize: 13, color: Colors.white70),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
              backgroundColor: const Color(0xFF1F1F1F),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Open',
                textColor: Colors.white,
                onPressed: () => context.push('/notifications'),
              ),
            ),
          );
        }
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            ref.invalidate(activeJobProvider);
            ref.invalidate(todayEarningsProvider);
            await ref.read(profileProvider.notifier).load();
          },
          child: CustomScrollView(
            slivers: [
              // ── App Bar ──────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenPadding,
                    AppSpacing.base,
                    AppSpacing.screenPadding,
                    0,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              technicianName,
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (technicianPhone.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                technicianPhone,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      // Notifications
                      GestureDetector(
                        onTap: () => context.push('/notifications'),
                        child: Stack(
                          clipBehavior: Clip.none,
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
                            if (unreadCount > 0)
                              Positioned(
                                right: -2,
                                top: -2,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                                  decoration: BoxDecoration(
                                    color: AppColors.error,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppColors.surface, width: 1.5),
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
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // ── Availability Toggle ───────────────────────
                    FpAvailabilityToggle(
                      isAvailable: profile?.isAvailable ?? false,
                      isLoading: _isTogglingAvailability ||
                          (profileAsync.isLoading && !profileAsync.hasError),
                      onChanged: _toggleAvailability,
                    ),

                    if (assignedJobs.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.base),
                      _NewBookingBanner(
                        assignedJobs: assignedJobs,
                        onTap: () {
                          if (assignedJobs.length == 1) {
                            context.push('/job-details/${assignedJobs.first.id}');
                          } else {
                            context.go('/jobs');
                          }
                        },
                      ),
                    ],

                    const SizedBox(height: AppSpacing.xl),

                    // ── Today's Overview ──────────────────────────
                    Text(
                      'Today\'s Overview',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: todayEarningsAsync.when(
                            loading: () => const FpSkeleton(height: 96),
                            error: (_, __) => _StatCard(
                              label: 'Earnings',
                              value: '₹0',
                              icon: Icons.currency_rupee_rounded,
                              color: AppColors.success,
                            ),
                            data: (e) => _StatCard(
                              label: 'Earnings',
                              value: '₹${_fmt(e.totalEarnings)}',
                              icon: Icons.currency_rupee_rounded,
                              color: AppColors.success,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: todayEarningsAsync.when(
                            loading: () => const FpSkeleton(height: 96),
                            error: (_, __) => _StatCard(
                              label: 'Completed',
                              value: '0 jobs',
                              icon: Icons.check_circle_outline_rounded,
                              color: AppColors.primary,
                            ),
                            data: (e) => _StatCard(
                              label: 'Completed',
                              value:
                                  '${e.completedJobs} job${e.completedJobs == 1 ? '' : 's'}',
                              icon: Icons.check_circle_outline_rounded,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    // ── Current / Active Job ──────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Active Job',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        TextButton(
                          onPressed: () => context.go('/jobs'),
                          child: const Text('View All'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    currentJobAsync.when(
                      loading: () => const FpJobCardSkeleton(),
                      error: (e, _) => _NoActiveJobCard(
                        onRefresh: () => ref.invalidate(activeJobProvider),
                      ),
                      data: (job) => job == null
                          ? _NoActiveJobCard()
                          : _ActiveJobCard(job: job),
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    // ── Quick Actions ─────────────────────────────
                    Text(
                      'Quick Actions',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        _QuickAction(
                          icon: Icons.work_history_rounded,
                          label: 'My Jobs',
                          onTap: () => context.go('/jobs'),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        _QuickAction(
                          icon: Icons.account_balance_wallet_outlined,
                          label: 'Earnings',
                          onTap: () => context.go('/earnings'),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        _QuickAction(
                          icon: Icons.person_outline_rounded,
                          label: 'Profile',
                          onTap: () => context.push('/profile'),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        _QuickAction(
                          icon: Icons.support_agent_outlined,
                          label: 'Support',
                          onTap: () => context.push('/settings'),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.xxxl),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(double val) {
    if (val >= 1000) {
      return NumberFormat('#,##0', 'en_IN').format(val);
    }
    return val.toStringAsFixed(0);
  }
}

class _NewBookingBanner extends StatelessWidget {
  final List<Job> assignedJobs;
  final VoidCallback onTap;

  const _NewBookingBanner({
    required this.assignedJobs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final count = assignedJobs.length;
    final firstJob = assignedJobs.first;

    return FpCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count == 1
                      ? 'New Booking Assigned'
                      : '$count New Bookings Assigned',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  count == 1
                      ? '${firstJob.subService.name} · ${firstJob.scheduledSlot}'
                      : 'Tap to review and respond to pending bookings',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Text(
              'View',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return FpCard(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _ActiveJobCard extends StatelessWidget {
  final Job job;

  const _ActiveJobCard({required this.job});

  @override
  Widget build(BuildContext context) {
    return FpCard(
      onTap: () => context.push('/job-details/${job.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.bookingNumber,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      job.subService.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              FpStatusChip(status: FpStatusChip.fromString(job.status)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: AppSpacing.md),
          _InfoRow(
            icon: Icons.person_outline_rounded,
            text: job.customer.displayName,
          ),
          const SizedBox(height: AppSpacing.sm),
          _InfoRow(
            icon: Icons.location_on_outlined,
            text: job.address.fullAddress,
          ),
          const SizedBox(height: AppSpacing.sm),
          _InfoRow(
            icon: Icons.schedule_rounded,
            text: '${_formatDate(job.scheduledDate)} · ${job.scheduledSlot}',
          ),
          const SizedBox(height: AppSpacing.base),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '₹${job.totalAmount.toStringAsFixed(0)}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(
                height: 36,
                child: FilledButton(
                  onPressed: () => context.push('/job-details/${job.id}'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadius.button,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: const Text(
                    'Manage Job',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('EEE, d MMM').format(date);
  }
}

class _NoActiveJobCard extends StatelessWidget {
  final VoidCallback? onRefresh;

  const _NoActiveJobCard({this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return FpCard(
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.base),
          Container(
            padding: const EdgeInsets.all(AppSpacing.base),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.inbox_outlined,
              size: 32,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No Active Jobs',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'No active jobs at the moment. Go online to receive requests.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (onRefresh != null) ...[
            const SizedBox(height: AppSpacing.sm),
            TextButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Refresh'),
            ),
          ],
          const SizedBox(height: AppSpacing.base),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Icon(icon, size: 22, color: AppColors.primary),
              const SizedBox(height: AppSpacing.xs),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

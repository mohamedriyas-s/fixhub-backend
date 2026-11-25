import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_images.dart';
import '../../../../core/config/theme/app_radius.dart';
import '../../../../core/config/theme/app_spacing.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/widgets/fixhub_button.dart';
import '../../../../core/widgets/fixhub_card.dart';
import '../providers/booking_flow_provider.dart';

class BookingSuccessScreen extends ConsumerWidget {
  const BookingSuccessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flowState = ref.watch(bookingFlowProvider);
    final serviceName = flowState.selectedService?.name ?? 'your service';
    final bookingId = flowState.draftBookingId;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(
                    top: AppSpacing.xl,
                    bottom: AppSpacing.md,
                  ),
                  children: [
                    // Lottie animation / celebration icon
                    Center(
                      child: SizedBox(
                        width: 140,
                        height: 140,
                        child: Lottie.asset(
                          AppImages.bookingSuccessAnimation,
                          repeat: false,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_circle_rounded,
                              size: 56,
                              color: AppColors.success,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Success headline
                    Text(
                      'Booking Confirmed!',
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Your request for $serviceName has been confirmed. Auto-assignment is in progress.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // ── Stage 2: Add Issue Details Card ────────────────
                    if (bookingId != null) ...[
                      FixHubCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(AppSpacing.sm),
                                  decoration: BoxDecoration(
                                    color: AppColors.buttonPrimary.withValues(alpha: 0.08),
                                    borderRadius: AppRadius.smallRadius,
                                  ),
                                  child: const Icon(
                                    Icons.add_photo_alternate_outlined,
                                    size: 24,
                                    color: AppColors.buttonPrimary,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Add Issue Details',
                                        style: Theme.of(context).textTheme.titleMedium,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'Attach photos or video and describe the problem so your technician brings the right tools and replacement parts.',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.textSecondary,
                                    height: 1.4,
                                  ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            FixHubButton(
                              label: 'Add Photos & Details',
                              onPressed: () {
                                context.push(RouteNames.addIssueDetailsPath(bookingId));
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],

                    // Info Card
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.elevatedSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border, width: 0.5),
                      ),
                      child: const Column(
                        children: [
                          _InfoRow(
                            icon: Icons.flash_on_rounded,
                            iconColor: Color(0xFFF59E0B),
                            title: 'Instant Assignment',
                            value: 'Matching nearest expert technician',
                          ),
                          Divider(height: AppSpacing.xl),
                          _InfoRow(
                            icon: Icons.notifications_active_rounded,
                            iconColor: AppColors.info,
                            title: 'Status Updates',
                            value: 'You will receive push updates at every step',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom Navigation CTAs
              Padding(
                padding: const EdgeInsets.only(
                  top: AppSpacing.sm,
                  bottom: AppSpacing.bottomSafePadding,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FixHubButton.secondary(
                      label: 'View Booking Details',
                      onPressed: () {
                        final bId = bookingId;
                        ref.read(bookingFlowProvider.notifier).clearFlow();
                        if (bId != null) {
                          context.go('/booking-detail/$bId');
                        } else {
                          context.go(RouteNames.bookings);
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    TextButton(
                      onPressed: () {
                        ref.read(bookingFlowProvider.notifier).clearFlow();
                        context.go(RouteNames.home);
                      },
                      child: Text(
                        'Back to Home',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
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
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: iconColor),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

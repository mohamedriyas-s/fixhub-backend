import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_spacing.dart';
import '../../../../core/widgets/fixhub_app_bar.dart';
import '../../../../core/widgets/fixhub_card.dart';
import '../../../../core/widgets/fixhub_shimmer.dart';
import '../../../../core/widgets/fixhub_error_state.dart';
import '../../../../core/widgets/fixhub_status_chip.dart';
import '../providers/booking_provider.dart';
import '../providers/tracking_provider.dart';
import '../widgets/start_service_otp_card.dart';
import 'rate_service_screen.dart';

class BookingDetailScreen extends ConsumerWidget {
  const BookingDetailScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Listen to real-time status updates via tracking socket
    ref.watch(bookingTrackingProvider(bookingId));
    final bookingAsync = ref.watch(bookingDetailProvider(bookingId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const FixHubAppBar(title: 'Booking Details'),
      body: bookingAsync.when(
        data: (booking) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(bookingDetailProvider(bookingId));
              try {
                await ref.read(bookingDetailProvider(bookingId).future);
              } catch (_) {}
            },
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              children: [
              // Header Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Booking ID: #${booking.id.substring(0, 8).toUpperCase()}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  FixHubStatusChip(status: booking.statusType, label: booking.displayStatus),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              if (booking.startOtp != null &&
                  [
                    BookingStatusType.confirmed,
                    BookingStatusType.assigned,
                    BookingStatusType.enRoute,
                    BookingStatusType.arrived,
                  ].contains(booking.statusType)) ...[
                StartServiceOtpCard(
                  otp: booking.startOtp!,
                  isTechnicianArrived: booking.statusType == BookingStatusType.arrived,
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // Service Details
              FixHubCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Service Details',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    // Use actual service name when populated from backend
                    Text(
                      booking.subService?['name'] ?? 'Service',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          DateFormat('EEEE, MMM d, yyyy - hh:mm a').format(booking.scheduledDate),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Address
              if (booking.address != null) ...[
                FixHubCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Address',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        booking.address!.label,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        booking.address!.formattedAddress,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // Payment
              FixHubCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment Details',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Amount', style: Theme.of(context).textTheme.bodyLarge),
                        Text(
                          booking.formattedTotal,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Status', style: Theme.of(context).textTheme.bodyLarge),
                        Text(
                          booking.paymentStatus,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: booking.paymentStatus == 'PAID'
                                    ? AppColors.success
                                    : AppColors.warning,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Technician Details
              if (booking.technician != null) ...[
                FixHubCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Assigned Technician',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.person, color: AppColors.textPrimary),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  booking.technician!['user']?['name'] ?? 'Technician',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: AppSpacing.xxs),
                                Text(
                                  booking.technician!['user']?['phone'] ?? '',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.phone, color: AppColors.buttonPrimary),
                            onPressed: () async {
                              final phone = booking.technician!['user']?['phone'];
                              if (phone != null && phone.isNotEmpty) {
                                final uri = Uri.parse('tel:$phone');
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri);
                                } else {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Could not launch dialer')),
                                    );
                                  }
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              
              // Timeline
              if (booking.timeline.isNotEmpty) ...[
                FixHubCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Status History',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ...booking.timeline.map((event) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(top: 4, right: AppSpacing.sm),
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.buttonPrimary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      event.status,
                                      style: Theme.of(context).textTheme.titleMedium,
                                    ),
                                    Text(
                                      DateFormat('MMM d, hh:mm a').format(event.createdAt),
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],

              // ── "Searching for technician" banner (CONFIRMED, no technician yet) ──
              if (booking.statusType == BookingStatusType.confirmed &&
                  booking.technician == null) ...[
                const SizedBox(height: AppSpacing.md),
                _SearchingTechnicianBanner(bookingNumber: booking.bookingNumber),
              ],

              // ── "No technician found / auto-cancelled" banner (FAILED) ──
              if (booking.statusType == BookingStatusType.failed) ...[
                const SizedBox(height: AppSpacing.md),
                _NoTechnicianFoundBanner(
                  failureReason: booking.failureReason,
                  onContactSupport: () {
                    context.push('/support');
                  },
                ),
              ],

              
              // Action Buttons
              // Action Buttons
              if (booking.statusType != BookingStatusType.completed &&
                  booking.statusType != BookingStatusType.cancelled &&
                  booking.statusType != BookingStatusType.failed) ...[
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: AppColors.surface,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Cancel Booking'),
                          content: const Text('Are you sure you want to cancel this booking?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('No'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                ref.read(bookingActionProvider.notifier).cancelBooking(booking.id, 'User requested cancellation');
                              },
                              child: const Text('Yes, Cancel', style: TextStyle(color: AppColors.error)),
                            ),
                          ],
                        ),
                      );
                    },
                    child: const Text('Cancel Booking'),
                  ),
                ),
              ],
              // Price revision consent banner
              if (booking.status == 'PRICE_REVISION_PENDING') ...[ 
                const SizedBox(height: AppSpacing.lg),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.cardPadding),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB), // Amber tint
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.warning.withOpacity(0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info_rounded, color: AppColors.warning, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Price Revision Required',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.warning,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      if (booking.revisedAmount != null) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Base Service Price',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                            ),
                            Text(
                              '₹${booking.totalAmount.toStringAsFixed(0)}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Additional Charges',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.warning, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '+ ₹${(booking.additionalAmount ?? (booking.revisedAmount! - booking.totalAmount)).clamp(0, double.infinity).toStringAsFixed(0)}',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.warning,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                        const Divider(height: 12, color: AppColors.divider),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Amount',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              '₹${booking.revisedAmount!.toStringAsFixed(0)}',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                            ),
                          ],
                        ),
                      ],
                      if (booking.priceRevisionDescription?.isNotEmpty == true) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Work: ${booking.priceRevisionDescription}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                        ),
                      ],
                      if (booking.priceRevisionNote?.isNotEmpty == true) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Reason: "${booking.priceRevisionNote}"',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary, fontStyle: FontStyle.italic),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                await ref.read(bookingActionProvider.notifier).rejectRevision(booking.id);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Booking cancelled'), backgroundColor: AppColors.error),
                                  );
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.error,
                                side: const BorderSide(color: AppColors.error),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Decline'),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: () async {
                                await ref.read(bookingActionProvider.notifier).approveRevision(booking.id);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Price approved. Job continuing!'), backgroundColor: AppColors.success),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.buttonPrimary,
                                foregroundColor: AppColors.buttonPrimaryText,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Approve Price', style: TextStyle(fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              // Action Buttons
              const SizedBox(height: AppSpacing.lg),
              
              if ([BookingStatusType.assigned, BookingStatusType.enRoute].contains(booking.statusType))
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.buttonPrimary,
                      foregroundColor: AppColors.surface,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () {
                      context.pushNamed('bookingTracking', pathParameters: {'id': booking.id});
                    },
                    child: const Text('Track Technician'),
                  ),
                ),

              if ([BookingStatusType.arrived, BookingStatusType.inProgress].contains(booking.statusType))
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.buttonPrimary,
                      foregroundColor: AppColors.surface,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () {
                      context.pushNamed('bookingProgress', pathParameters: {'id': booking.id});
                    },
                    child: const Text('View Job Progress'),
                  ),
                ),

              if (booking.statusType == BookingStatusType.completed)
                if (booking.review != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.cardPadding),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          'You rated this service ${booking.review!['rating'] ?? ''}/5',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                        ),
                      ],
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.buttonPrimary,
                        foregroundColor: AppColors.surface,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => RateServiceScreen(
                              bookingId: booking.id,
                              serviceName: booking.subService?['name'] ?? 'Service',
                            ),
                          ),
                        ).then((submitted) {
                          if (submitted == true) {
                            ref.invalidate(bookingDetailProvider(bookingId));
                          }
                        });
                      },
                      child: const Text('Rate Service'),
                    ),
                  ),
              const SizedBox(height: AppSpacing.xxxl),
            ],
          ),
        );
      },
      loading: () => Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          children: [
            FixHubShimmer.card(height: 120),
            const SizedBox(height: AppSpacing.md),
            FixHubShimmer.card(height: 100),
            const SizedBox(height: AppSpacing.md),
            FixHubShimmer.card(height: 100),
          ],
        ),
      ),
        error: (error, _) => FixHubErrorState(
          onRetry: () => ref.invalidate(bookingDetailProvider(bookingId)),
        ),
      ),
    );
  }
}

// ── Searching for Technician Banner ──────────────────────────────────────────

class _SearchingTechnicianBanner extends StatefulWidget {
  const _SearchingTechnicianBanner({required this.bookingNumber});

  final String bookingNumber;

  @override
  State<_SearchingTechnicianBanner> createState() =>
      _SearchingTechnicianBannerState();
}

class _SearchingTechnicianBannerState extends State<_SearchingTechnicianBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FadeTransition(
                opacity: _pulseAnimation,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Color(0xFF3B82F6),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Finding Your Technician',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1D4ED8),
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Your booking is confirmed and payment received. We\'re matching you with the best available technician in your area. You\'ll receive a notification as soon as one is assigned.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF1E40AF),
                  height: 1.5,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF3B82F6)),
              const SizedBox(width: 4),
              Text(
                'Usually takes 10–30 minutes',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: const Color(0xFF3B82F6),
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── No Technician Found Banner ────────────────────────────────────────────────

class _NoTechnicianFoundBanner extends StatelessWidget {
  const _NoTechnicianFoundBanner({
    this.failureReason,
    required this.onContactSupport,
  });

  final String? failureReason;
  final VoidCallback onContactSupport;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cancel_rounded, color: AppColors.error, size: 22),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'We Couldn\'t Find a Technician',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.error,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'We\'re sincerely sorry for the inconvenience. Despite our best efforts, no technicians were available in your area for this booking.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_rounded, color: AppColors.success, size: 18),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'A full refund has been initiated and will reflect in 3–5 business days.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onContactSupport,
              icon: const Icon(Icons.headset_mic_rounded, size: 18),
              label: const Text('Contact Support'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

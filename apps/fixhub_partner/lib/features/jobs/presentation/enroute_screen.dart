import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config/theme/app_colors.dart';
import '../../../core/config/theme/app_spacing.dart';
import '../../../core/config/theme/app_radius.dart';
import '../../../core/widgets/fp_app_bar.dart';
import '../../../core/widgets/fp_button.dart';
import '../../../core/widgets/fp_card.dart';
import '../../../core/widgets/fp_skeleton.dart';
import '../../../core/widgets/fp_offline_banner.dart';
import '../domain/job_models.dart';
import 'enroute_provider.dart';
import 'job_provider.dart';

/// En-route screen shown when the technician is on the way to the customer.
///
/// Features:
/// - Live GPS tracking (pushes location to backend every 10s)
/// - WebSocket connection for real-time status updates from customer
/// - "Navigate" button launches Google Maps with turn-by-turn directions
/// - "Mark Arrived" CTA transitions to ARRIVED status
/// - Live status banner shows connection state
class EnRouteScreen extends ConsumerStatefulWidget {
  final String jobId;
  const EnRouteScreen({super.key, required this.jobId});

  @override
  ConsumerState<EnRouteScreen> createState() => _EnRouteScreenState();
}

class _EnRouteScreenState extends ConsumerState<EnRouteScreen> {
  bool _isMarkingArrived = false;

  Future<void> _navigateToCustomer(JobAddress address) async {
    final lat = address.latitude;
    final lng = address.longitude;
    final bool hasValidCoords =
        lat != null && lng != null && (lat != 0 || lng != 0);

    final uri = hasValidCoords
        ? Uri.parse('google.navigation:q=$lat,$lng&mode=d')
        : Uri.parse(
            'google.navigation:q=${Uri.encodeComponent(address.fullAddress)}&mode=d');
    final fallbackUri = hasValidCoords
        ? Uri.parse(
            'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving')
        : Uri.parse(
            'https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(address.fullAddress)}&travelmode=driving');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (await canLaunchUrl(fallbackUri)) {
      await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
    } else {
      _showSnackBar('Could not open Google Maps');
    }
  }

  Future<void> _markArrived() async {
    setState(() => _isMarkingArrived = true);
    try {
      final enRouteState = ref.read(enRouteProvider(widget.jobId));
      final lat = enRouteState.lastKnownPosition?.latitude;
      final lng = enRouteState.lastKnownPosition?.longitude;

      await ref.read(activeJobProvider.notifier).updateStatus(
            widget.jobId,
            'ARRIVED',
            latitude: lat,
            longitude: lng,
          );

      if (mounted) {
        // Stop en-route tracking
        ref.read(enRouteProvider(widget.jobId).notifier).stopTracking();
        _showSnackBar('Status updated to ARRIVED', isSuccess: true);
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Failed to update status. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isMarkingArrived = false);
    }
  }

  Future<void> _callCustomer(String? phone) async {
    if (phone == null || phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _showSnackBar(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess ? AppColors.success : AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final jobAsync = ref.watch(jobDetailsProvider(widget.jobId));
    final enRouteState = ref.watch(enRouteProvider(widget.jobId));

    // Listen for status changes via WebSocket
    ref.listen<EnRouteState>(enRouteProvider(widget.jobId), (previous, next) {
      if (next.currentStatus != null &&
          next.currentStatus != previous?.currentStatus) {
        // If status changed externally (e.g., customer cancelled), pop back
        if (next.currentStatus == 'CANCELLED' || next.currentStatus == 'FAILED') {
          _showSnackBar('Job was ${next.currentStatus?.toLowerCase() ?? 'cancelled'}');
          context.pop();
        }
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: FpSurfaceAppBar(title: 'En Route'),
      body: jobAsync.when(
        loading: () => const Center(child: FpPageLoader()),
        error: (e, _) => FpErrorState(
          message: 'Could not load job details',
          onRetry: () => ref.invalidate(jobDetailsProvider(widget.jobId)),
        ),
        data: (job) => Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Connection Status Banner ────────────────
                    _ConnectionBanner(
                      isSocketConnected: enRouteState.isSocketConnected,
                      isTrackingLocation: enRouteState.isTrackingLocation,
                      errorMessage: enRouteState.errorMessage,
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // ── Status Header ───────────────────────────
                    FpCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.info.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.navigation_rounded,
                                  color: AppColors.info,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'You are on the way',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Your location is being shared with the customer',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.base),

                    // ── Service Details ──────────────────────────
                    FpCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            job.subService.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          if (job.subService.categoryName != null)
                            Text(
                              job.subService.categoryName!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          const SizedBox(height: AppSpacing.md),
                          const Divider(color: AppColors.divider, height: 1),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _InfoChip(
                                icon: Icons.calendar_today_outlined,
                                label: job.scheduledSlot,
                              ),
                              Text(
                                '₹${job.totalAmount.toStringAsFixed(0)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.base),

                    // ── Customer Info ────────────────────────────
                    FpCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Customer',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textSecondary,
                                    ),
                              ),
                              IconButton(
                                onPressed: job.customer.phone?.isNotEmpty == true
                                    ? () => _callCustomer(job.customer.phone)
                                    : null,
                                icon: const Icon(
                                  Icons.call_rounded,
                                  size: 20,
                                  color: AppColors.primary,
                                ),
                                style: IconButton.styleFrom(
                                  backgroundColor: AppColors.primaryContainer,
                                  padding: const EdgeInsets.all(8),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: [
                              const Icon(Icons.person_outline_rounded,
                                  size: 16, color: AppColors.textSecondary),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                job.customer.displayName,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.base),

                    // ── Destination Address ─────────────────────
                    FpCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Destination',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.location_on_outlined,
                                  size: 18, color: AppColors.primary),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      job.address.fullAddress,
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (job.address.landmark != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Landmark: ${job.address.landmark}',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          // Navigate button — opens Google Maps
                          FpButton(
                            label: '🗺  Open in Google Maps',
                            variant: FpButtonVariant.secondary,
                            onPressed: () => _navigateToCustomer(job.address),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),

            // ── Bottom Action Bar ──────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                AppSpacing.md,
                AppSpacing.screenPadding,
                AppSpacing.bottomSafePad,
              ),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: FpButton(
                label: '📍 I Have Arrived',
                isLoading: _isMarkingArrived,
                onPressed: _markArrived,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Connection Status Banner ────────────────────────────────────
class _ConnectionBanner extends StatelessWidget {
  final bool isSocketConnected;
  final bool isTrackingLocation;
  final String? errorMessage;

  const _ConnectionBanner({
    required this.isSocketConnected,
    required this.isTrackingLocation,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (errorMessage != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.1),
          borderRadius: AppRadius.chip,
          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                errorMessage!,
                style: const TextStyle(fontSize: 12, color: AppColors.error),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: AppRadius.chip,
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            isSocketConnected ? Icons.wifi_rounded : Icons.wifi_off_rounded,
            size: 14,
            color: isSocketConnected ? AppColors.success : AppColors.warning,
          ),
          const SizedBox(width: 6),
          Text(
            isTrackingLocation ? 'Live tracking active' : 'Connecting...',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isSocketConnected ? AppColors.success : AppColors.warning,
            ),
          ),
          const Spacer(),
          if (isTrackingLocation)
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Info Chip ────────────────────────────────────────────────────
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

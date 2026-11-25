import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/config/theme/app_colors.dart';
import '../../../core/config/theme/app_spacing.dart';
import '../../../core/config/theme/app_radius.dart';
import '../../../core/widgets/fp_app_bar.dart';
import '../../../core/widgets/fp_button.dart';
import '../../../core/widgets/fp_card.dart';
import '../../../core/widgets/fp_skeleton.dart';
import '../../../core/widgets/fp_offline_banner.dart';
import '../../../core/widgets/fp_status_chip.dart';
import '../../../core/widgets/fp_swipe_slider.dart';
import '../domain/job_models.dart';
import 'final_amount_sheet.dart';
import 'final_otp_verification_view.dart';
import 'job_provider.dart';
import 'price_revision_sheet.dart';
import 'verify_otp_sheet.dart';

class JobDetailsScreen extends ConsumerWidget {
  final String jobId;

  const JobDetailsScreen({super.key, required this.jobId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobAsync = ref.watch(jobDetailsProvider(jobId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: FpSurfaceAppBar(title: 'Job Details'),
      body: jobAsync.when(
        loading: () => const Center(child: FpPageLoader()),
        error: (e, _) => FpErrorState(
          message: 'Could not load job details',
          onRetry: () => ref.invalidate(jobDetailsProvider(jobId)),
        ),
        data: (job) {
          if (job.isAwaitingVerification || job.isPendingCollection) {
            return FinalOtpVerificationView(job: job);
          }
          return _JobDetailsBody(
            key: ValueKey('${job.id}_${job.status}'),
            job: job,
          );
        },
      ),
    );
  }
}

class _JobDetailsBody extends ConsumerStatefulWidget {
  final Job job;

  const _JobDetailsBody({super.key, required this.job});

  @override
  ConsumerState<_JobDetailsBody> createState() => _JobDetailsBodyState();
}

class _JobDetailsBodyState extends ConsumerState<_JobDetailsBody> {
  bool _isUpdating = false;
  Timer? _statusPollTimer;

  @override
  void initState() {
    super.initState();
    _checkStatusPoll();
  }

  @override
  void didUpdateWidget(covariant _JobDetailsBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.job.status != widget.job.status) {
      _checkStatusPoll();
    }
  }

  @override
  void dispose() {
    _statusPollTimer?.cancel();
    super.dispose();
  }

  void _checkStatusPoll() {
    if (widget.job.status == 'PRICE_REVISION_PENDING') {
      _statusPollTimer ??= Timer.periodic(const Duration(seconds: 4), (_) {
        if (!mounted) return;
        ref.invalidate(jobDetailsProvider(widget.job.id));
        ref.invalidate(activeJobProvider);
      });
    } else {
      _statusPollTimer?.cancel();
      _statusPollTimer = null;
    }
  }

  Widget _buildDelayBadge(String severity, {String? elapsed}) {
    Color color;
    Color textColor;
    String label;

    switch (severity) {
      case 'WHITE':
        color = Colors.white;
        textColor = AppColors.textPrimary;
        label = elapsed != null ? 'Today ($elapsed)' : 'Today';
      case 'YELLOW':
        color = const Color(0xFFFEF3C7);
        textColor = const Color(0xFFD97706);
        label = elapsed != null ? '$elapsed delay' : '2-5d';
      case 'RED':
      default:
        color = const Color(0xFFFEE2E2);
        textColor = const Color(0xFFDC2626);
        label = elapsed != null ? '$elapsed delay' : '> 1w';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: severity == 'WHITE' ? AppColors.border : textColor.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: textColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  String get _nextStatus {
    return switch (widget.job.status) {
      'ASSIGNED' => 'ACCEPTED',
      'ACCEPTED' => 'EN_ROUTE',
      'EN_ROUTE' => 'ARRIVED',
      'ARRIVED' => 'IN_PROGRESS',
      'IN_PROGRESS' => 'COMPLETED',
      'PRICE_REVISION_PENDING' => '', // Cannot transition — waiting for customer
      _ => '',
    };
  }

  String get _nextStatusLabel {
    return switch (widget.job.status) {
      'ASSIGNED' => 'Accept Job',
      'ACCEPTED' => '🗺 Start En Route',
      'EN_ROUTE' => '📍 Mark Arrived',
      'ARRIVED' => '🔧 Start Work',
      'IN_PROGRESS' => '✅ Complete Job',
      'PRICE_REVISION_PENDING' => '⏳ Waiting for Customer...',
      _ => '',
    };
  }

  bool get _isPriceRevisionPending => widget.job.status == 'PRICE_REVISION_PENDING';

  Future<void> _updateStatus() async {
    final nextStatus = _nextStatus;
    if (nextStatus.isEmpty) return;

    if (nextStatus == 'IN_PROGRESS') {
      final verified = await showVerifyOtpSheet(context, widget.job);
      if (verified == true && mounted) {
        ref.invalidate(jobDetailsProvider(widget.job.id));
        try {
          await ref.read(jobDetailsProvider(widget.job.id).future);
        } catch (_) {}
      }
      return;
    }

    if (nextStatus == 'COMPLETED') {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Complete Job?'),
          content: const Text(
            'Mark this job as completed? This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(c, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
              child: const Text('Complete'),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
    }

    setState(() => _isUpdating = true);

    double? lat, lng;
    if (nextStatus == 'EN_ROUTE' || nextStatus == 'ARRIVED') {
      try {
        final perm = await Geolocator.checkPermission();
        if (perm == LocationPermission.whileInUse ||
            perm == LocationPermission.always) {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
            ),
          );
          lat = pos.latitude;
          lng = pos.longitude;
        }
      } catch (_) {}
    }

    try {
      await ref.read(activeJobProvider.notifier).updateStatus(
            widget.job.id,
            nextStatus,
            latitude: lat,
            longitude: lng,
          );
      if (mounted && nextStatus == 'COMPLETED') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Job completed successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      } else if (mounted && nextStatus == 'EN_ROUTE') {
        // Navigate to the en-route screen for live tracking + navigation
        context.push('/job-enroute/${widget.job.id}');
      } else if (mounted) {
        ref.invalidate(jobDetailsProvider(widget.job.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Status updated to ${nextStatus.replaceAll('_', ' ')}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update status. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _reportFailure() async {
    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Report Failure'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Describe why this job could not be completed:',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: reasonCtrl,
              maxLines: 3,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'e.g. Customer not available, missing spare parts...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, reasonCtrl.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty || !mounted) return;

    setState(() => _isUpdating = true);
    try {
      await ref.read(activeJobProvider.notifier).updateStatus(
            widget.job.id,
            'FAILED',
            note: reason,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job reported as failed.')),
        );
        context.pop();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to report. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _callCustomer() async {
    final phone = widget.job.customer.phone;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  Future<void> _openMaps() async {
    final lat = widget.job.address.latitude;
    final lng = widget.job.address.longitude;
    final Uri uri;
    if (lat != null && lng != null && (lat != 0 || lng != 0)) {
      uri = Uri.parse('https://maps.google.com/?q=$lat,$lng');
    } else {
      uri = Uri.parse(
          'https://maps.google.com/?q=${Uri.encodeComponent(widget.job.address.fullAddress)}');
    }
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final job = widget.job;
    final hasAction = _nextStatus.isNotEmpty;
    final isInProgress = job.status == 'IN_PROGRESS';
    final canFail = const ['ACCEPTED', 'EN_ROUTE', 'ARRIVED', 'IN_PROGRESS']
        .contains(job.status);
    final isPendingRevision = _isPriceRevisionPending;

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(jobDetailsProvider(widget.job.id));
              try {
                await ref.read(jobDetailsProvider(widget.job.id).future);
              } catch (_) {}
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                // ── Header ───────────────────────────────────────
                FpCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  job.bookingNumber,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(letterSpacing: 0.5),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  job.subService.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                if (job.subService.categoryName != null)
                                  Text(
                                    job.subService.categoryName!,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
                                  ),
                              ],
                            ),
                          ),
                          FpStatusChip(
                            status: FpStatusChip.fromString(job.status),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const Divider(color: AppColors.divider, height: 1),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          Text(
                            '₹${job.totalAmount.toStringAsFixed(0)}',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.base),

                // ── Price Revision Pending Banner ─────────────────
                if (isPendingRevision && job.revisedAmount != null) ...[
                  FpCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.hourglass_top_rounded,
                                color: AppColors.warning,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Additional Charge Approval Pending',
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Waiting for customer confirmation',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Base Service Price', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                                  Text('₹${job.totalAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Additional Charges', style: TextStyle(color: AppColors.warning, fontSize: 13, fontWeight: FontWeight.w500)),
                                  Text(
                                    '+ ₹${(job.additionalAmount ?? (job.revisedAmount! - job.totalAmount)).clamp(0, double.infinity).toStringAsFixed(0)}',
                                    style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.w700, fontSize: 13),
                                  ),
                                ],
                              ),
                              const Divider(height: 12, color: AppColors.divider),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Final Payable Amount', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                  Text('₹${job.revisedAmount!.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (job.priceRevisionDescription != null && job.priceRevisionDescription!.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Item/Work: ${job.priceRevisionDescription}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                        if (job.priceRevisionNote != null && job.priceRevisionNote!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Reason: ${job.priceRevisionNote}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.base),
                ],

                // ── Additional Charge Approved Banner ─────────────
                if (job.status == 'IN_PROGRESS' && job.customerConsentAt != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.successLight,
                      borderRadius: AppRadius.card,
                      border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: AppColors.success,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Additional Charge Approved ✅',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: AppColors.success,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Customer approved additional charges. Revised total is ₹${job.totalAmount.toStringAsFixed(0)}. You may proceed with the work.',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (job.delaySeverity != null) ...[
                          const SizedBox(height: AppSpacing.sm),
                          const Divider(height: 1),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: [
                              const Icon(
                                Icons.timer_outlined,
                                size: 14,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Delay tracking: ${job.delayElapsedText ?? "Active"}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const Spacer(),
                              _buildDelayBadge(job.delaySeverity!, elapsed: job.delayElapsedText),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.base),
                ],

                _Section(
                  title: 'Schedule',
                  child: Column(
                    children: [
                      _DetailRow(
                        icon: Icons.calendar_today_outlined,
                        label: 'Date',
                        value: DateFormat(
                          'EEEE, d MMMM yyyy',
                        ).format(job.scheduledDate),
                      ),
                      _DetailRow(
                        icon: Icons.access_time_rounded,
                        label: 'Time Slot',
                        value: job.scheduledSlot,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.base),

                // ── Customer ─────────────────────────────────────
                _Section(
                  title: 'Customer',
                  trailing: IconButton(
                    onPressed: _callCustomer,
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
                  child: Column(
                    children: [
                      _DetailRow(
                        icon: Icons.person_outline_rounded,
                        label: 'Name',
                        value: job.customer.displayName,
                      ),
                      _DetailRow(
                        icon: Icons.phone_outlined,
                        label: 'Phone',
                        value: job.customer.phone,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.base),

                // ── Address ──────────────────────────────────────
                _Section(
                  title: 'Service Location',
                  trailing: job.address.latitude != null
                      ? IconButton(
                          onPressed: _openMaps,
                          icon: const Icon(
                            Icons.directions_rounded,
                            size: 20,
                            color: AppColors.primary,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.primaryContainer,
                            padding: const EdgeInsets.all(8),
                          ),
                        )
                      : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DetailRow(
                        icon: Icons.location_on_outlined,
                        label: 'Address',
                        value: job.address.fullAddress,
                      ),
                      if (job.address.landmark != null)
                        _DetailRow(
                          icon: Icons.place_outlined,
                          label: 'Landmark',
                          value: job.address.landmark!,
                        ),
                    ],
                  ),
                ),

                // ── Customer Issue Details (Notes & Photos/Videos) ──
                if ((job.description != null && job.description!.trim().isNotEmpty) ||
                    job.media.where((m) => m.phase == 'BEFORE_SERVICE' || m.phase == null).isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.base),
                  _Section(
                    title: 'Customer Issue Details',
                    trailing: const Icon(
                      Icons.report_problem_outlined,
                      size: 20,
                      color: AppColors.primary,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (job.description != null && job.description!.trim().isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.xs,
                            ),
                            child: Text(
                              job.description!,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    height: 1.4,
                                  ),
                            ),
                          ),
                        ],
                        if (job.media.where((m) => m.phase == 'BEFORE_SERVICE' || m.phase == null).isNotEmpty) ...[
                          if (job.description != null && job.description!.trim().isNotEmpty)
                            const SizedBox(height: AppSpacing.sm),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: job.media
                                .where((m) => m.phase == 'BEFORE_SERVICE' || m.phase == null)
                                .map((m) => _MediaThumbReadOnly(media: m))
                                .toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                if (job.notes != null && job.notes!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.base),
                  _Section(
                    title: 'Assignment Note / Instructions',
                    trailing: const Icon(
                      Icons.assignment_outlined,
                      size: 20,
                      color: AppColors.primary,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xs,
                      ),
                      child: Text(
                        job.notes!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textPrimary,
                              height: 1.4,
                            ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: AppSpacing.base),

                // ── Timeline ─────────────────────────────────────
                if (job.timeline.isNotEmpty) ...[
                  _Section(
                    title: 'Timeline',
                    child: Column(
                      children: job.timeline
                          .map((e) => _TimelineRow(entry: e))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.base),
                ],

                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),

        // ── Action Bar ──────────────────────────────────────────
        if (hasAction || canFail || isPendingRevision)
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Additional charge button (only when IN_PROGRESS)
                if (isInProgress) ...[
                  FpButton(
                    label: '💰 Request Additional Charge',
                    variant: FpButtonVariant.secondary,
                    onPressed: () => showAdditionalChargeSheet(context, job),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],

                // Main CTA
                Row(
                  children: [
                    if (isInProgress)
                      Expanded(
                        child: FpSwipeSlider(
                          label: 'Slide to Complete Job',
                          isEnabled: !_isUpdating,
                          onComplete: () {
                            FinalAmountSheet.show(
                              context: context,
                              job: job,
                              onFinalized: () {
                                ref.invalidate(jobDetailsProvider(job.id));
                              },
                            );
                          },
                        ),
                      )
                    else if (hasAction)
                      Expanded(
                        child: FpButton(
                          label: _nextStatusLabel,
                          isLoading: _isUpdating,
                          onPressed: _updateStatus,
                        ),
                      )
                    else if (isPendingRevision)
                      Expanded(
                        child: FpButton(
                          label: _nextStatusLabel,
                          onPressed: null, // Disabled — waiting for customer
                        ),
                      ),

                    // Report Failure overflow
                    if (canFail) ...[
                      if (hasAction || isPendingRevision) const SizedBox(width: AppSpacing.sm),
                      Container(
                        height: AppSpacing.buttonHeight,
                        width: AppSpacing.buttonHeight,
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: AppRadius.button,
                        ),
                        child: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert_rounded,
                              color: AppColors.textSecondary),
                          onSelected: (v) {
                            if (v == 'fail') _reportFailure();
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'fail',
                              child: Row(
                                children: [
                                  Icon(Icons.cancel_outlined,
                                      color: AppColors.error, size: 18),
                                  SizedBox(width: 8),
                                  Text('Report Failure',
                                      style: TextStyle(
                                          color: AppColors.error)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const _Section({required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return FpCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final JobTimelineEntry entry;

  const _TimelineRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 4, right: 12),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.status.replaceAll('_', ' '),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                if (entry.note != null && entry.note!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2, bottom: 2),
                    child: Text(
                      entry.note!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                Text(
                  DateFormat('d MMM, h:mm a').format(entry.createdAt.toLocal()),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaThumbReadOnly extends StatelessWidget {
  const _MediaThumbReadOnly({required this.media});

  final JobMedia media;

  @override
  Widget build(BuildContext context) {
    final isVideo = media.type == 'VIDEO';
    final normalizedUrl = media.url.replaceAll(
      'fixhub-uploads.s3.ap-south-1.amazonaws.com',
      'spotfluencerbucket2.s3.ap-south-1.amazonaws.com',
    );

    return GestureDetector(
      onTap: () {
        final uri = Uri.parse(normalizedUrl);
        launchUrl(uri);
      },
      child: SizedBox(
        width: 80,
        height: 80,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: isVideo
                  ? Container(
                      color: AppColors.surfaceVariant,
                      child: const Center(
                        child: Icon(
                          Icons.videocam_rounded,
                          size: 32,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  : Image.network(
                      normalizedUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppColors.surfaceVariant,
                        child: const Icon(Icons.broken_image_rounded,
                            color: AppColors.textSecondary),
                      ),
                    ),
            ),
            // Video label chip
            if (isVideo)
              Positioned(
                bottom: 4,
                left: 4,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'VIDEO',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w700),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}


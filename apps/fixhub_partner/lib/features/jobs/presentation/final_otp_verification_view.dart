import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/theme/app_colors.dart';
import '../../../core/config/theme/app_radius.dart';
import '../../../core/config/theme/app_spacing.dart';
import '../../../core/widgets/fp_button.dart';
import '../../../core/widgets/fp_card.dart';
import '../domain/job_models.dart';
import 'job_provider.dart';

/// Sticky Completion Verification & OTP view for technician.
///
/// Displayed whenever a job is in [AWAITING_COMPLETION_VERIFICATION]
/// or [PENDING_COLLECTION].
class FinalOtpVerificationView extends ConsumerStatefulWidget {
  final Job job;

  const FinalOtpVerificationView({super.key, required this.job});

  @override
  ConsumerState<FinalOtpVerificationView> createState() =>
      _FinalOtpVerificationViewState();
}

class _FinalOtpVerificationViewState
    extends ConsumerState<FinalOtpVerificationView> {
  final _otpCtrl = TextEditingController();
  bool _isVerifying = false;
  bool _isRefreshing = false;
  String? _errorText;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _syncPolling();
  }

  @override
  void didUpdateWidget(covariant FinalOtpVerificationView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPolling();
  }

  void _syncPolling() {
    if (widget.job.isExtraChargePaid) {
      _pollTimer?.cancel();
      _pollTimer = null;
    } else if (_pollTimer == null) {
      _pollTimer = Timer.periodic(
        const Duration(seconds: 8),
        (_) => _refreshPaymentStatus(silent: true),
      );
    }
  }

  Future<void> _refreshPaymentStatus({bool silent = false}) async {
    if (!silent && mounted) setState(() => _isRefreshing = true);
    try {
      ref.invalidate(jobDetailsProvider(widget.job.id));
      ref.invalidate(activeJobProvider);
      await ref.read(jobDetailsProvider(widget.job.id).future);
    } catch (_) {
      // Ignore transient polling errors
    } finally {
      if (!silent && mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    final otp = _otpCtrl.text.trim();
    if (otp.isEmpty || otp.length != 4) {
      setState(() => _errorText = 'Please enter the 4-digit customer OTP');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorText = null;
    });

    try {
      await ref
          .read(activeJobProvider.notifier)
          .verifyCompletionOtp(widget.job.id, otp);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Job successfully completed! 🎉'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop(); // return to jobs list
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorText = 'Invalid OTP. Please check with customer and try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPaid = widget.job.isExtraChargePaid;
    final extraAmount = widget.job.finalAdditionalAmount ?? 0.0;
    final isOnline = widget.job.extraChargePaymentMethod == 'ONLINE';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Status Banner Card
          Container(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            decoration: BoxDecoration(
              color: isPaid
                  ? AppColors.success.withValues(alpha: 0.1)
                  : AppColors.warning.withValues(alpha: 0.1),
              borderRadius: AppRadius.card,
              border: Border.all(
                color: isPaid ? AppColors.success : AppColors.warning,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isPaid ? Icons.check_circle_rounded : Icons.pending_rounded,
                  color: isPaid ? AppColors.success : AppColors.warning,
                  size: 28,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPaid
                            ? 'Ready for Final OTP'
                            : 'Waiting for Customer Payment',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isPaid
                            ? 'Payment settled. Customer has their Completion OTP.'
                            : 'Waiting for customer to pay ₹${extraAmount.toStringAsFixed(0)} online.',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isPaid)
                  IconButton(
                    onPressed: _isRefreshing ? null : () => _refreshPaymentStatus(),
                    tooltip: 'Check Payment Status',
                    icon: _isRefreshing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded, color: AppColors.warning),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Bill Summary Card
          FpCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Final Bill Summary',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Base Service (Paid)', style: TextStyle(color: AppColors.textSecondary)),
                    Text('₹${(widget.job.subService.basePrice ?? widget.job.totalAmount).toStringAsFixed(0)}'),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Additional Charge (${widget.job.extraChargePaymentMethod ?? "ONLINE"})',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    Text(
                      '₹${extraAmount.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const Divider(height: AppSpacing.lg, color: AppColors.border),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Job Amount', style: TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                      '₹${((widget.job.subService.basePrice ?? widget.job.totalAmount) + extraAmount).toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Enter Completion OTP Section
          Text(
            'Enter Customer Completion OTP',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            isPaid
                ? 'Ask the customer for the 4-digit OTP from their app to close this booking.'
                : 'OTP will unlock on the customer\'s app once online payment is completed.',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),

          TextField(
            controller: _otpCtrl,
            keyboardType: TextInputType.number,
            maxLength: 4,
            enabled: isPaid,
            style: const TextStyle(fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              counterText: '',
              hintText: '• • • •',
              hintStyle: const TextStyle(letterSpacing: 4, color: AppColors.textDisabled),
              filled: true,
              fillColor: isPaid ? AppColors.surface : AppColors.surfaceVariant,
              errorText: _errorText,
              border: const OutlineInputBorder(
                borderRadius: AppRadius.input,
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: AppRadius.input,
                borderSide: BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          FpButton(
            label: '✅ Verify OTP & Complete Job',
            isLoading: _isVerifying,
            onPressed: isPaid && !_isVerifying ? _verifyOtp : null,
          ),

          if (!isPaid && isOnline) ...[
            const SizedBox(height: AppSpacing.md),
            FpButton(
              label: _isRefreshing ? 'Checking Payment...' : '↻ Refresh Payment Status',
              variant: FpButtonVariant.secondary,
              isLoading: _isRefreshing,
              onPressed: _isRefreshing ? null : () => _refreshPaymentStatus(),
            ),
          ],
        ],
      ),
    );
  }
}

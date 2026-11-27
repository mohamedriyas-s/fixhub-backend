import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_radius.dart';
import '../../../../core/config/theme/app_spacing.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/widgets/fixhub_button.dart';
import '../../../../core/widgets/fixhub_card.dart';
import '../../../../core/widgets/fixhub_snackbar.dart';
import '../../data/datasources/booking_remote_datasource.dart';
import '../../data/models/booking_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/booking_provider.dart';

/// Final Quotation and Gated Completion OTP Card for Customer.
///
/// Features:
/// - Itemized final quotation (Base price paid + Final additional charge).
/// - Online payment CTA through Razorpay checkout when extra charge is pending online.
/// - Locked OTP state until Razorpay payment succeeds (or cash confirmed).
/// - Graceful handling when customer cancels or presses back from Razorpay.
/// - Prominently displays 4-digit Completion OTP once verified.
class FinalQuotationOtpCard extends ConsumerStatefulWidget {
  final BookingModel booking;

  const FinalQuotationOtpCard({super.key, required this.booking});

  @override
  ConsumerState<FinalQuotationOtpCard> createState() =>
      _FinalQuotationOtpCardState();
}

class _FinalQuotationOtpCardState extends ConsumerState<FinalQuotationOtpCard> {
  late Razorpay _razorpay;
  bool _isProcessing = false;
  String? _pendingOrderId;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  double get _extraAmount => widget.booking.finalAdditionalAmount ?? 0.0;
  double get _baseAmount =>
      (widget.booking.totalAmount - _extraAmount).clamp(0.0, double.infinity);
  bool get _isPaid => widget.booking.isExtraChargePaid;
  bool get _isCash => widget.booking.extraChargePaymentMethod == 'CASH';

  Future<void> _startPayment() async {
    setState(() => _isProcessing = true);

    try {
      final dio = ref.read(dioProvider);
      final ds = BookingRemoteDataSource(dio);
      final orderData = await ds.createExtraChargeOrder(widget.booking.id);

      final keyId = (orderData['keyId'] as String?)?.isNotEmpty == true
          ? orderData['keyId'] as String
          : AppConfig.razorpayKeyId;
      final orderId = orderData['orderId'] as String?;
      final amount = orderData['amount'] as int?;

      if (orderId == null || amount == null) {
        throw Exception('Failed to generate payment order');
      }

      _pendingOrderId = orderId;

      final user = ref.read(authProvider).user;

      final options = {
        'key': keyId,
        'amount': amount,
        'currency': 'INR',
        'order_id': orderId,
        'name': 'FixHub',
        'description': 'Additional Work Charge - Booking #${widget.booking.bookingNumber}',
        'timeout': 300,
        'prefill': {
          'contact': user?.phone ?? '',
          'email': user?.email ?? '',
        },
        'theme': {
          'color': '#1F1F1F',
        },
      };

      _razorpay.open(options);
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        FixHubSnackbar.show(
          context: context,
          message: 'Unable to initiate payment: $e',
          type: SnackbarType.error,
        );
      }
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    try {
      final dio = ref.read(dioProvider);
      final ds = BookingRemoteDataSource(dio);
      await ds.verifyExtraChargePayment({
        'bookingId': widget.booking.id,
        'razorpayOrderId': response.orderId ?? _pendingOrderId,
        'razorpayPaymentId': response.paymentId,
        'razorpaySignature': response.signature,
      });

      if (mounted) {
        setState(() => _isProcessing = false);
        ref.invalidate(bookingDetailProvider(widget.booking.id));
        ref.invalidate(bookingsProvider);
        FixHubSnackbar.show(
          context: context,
          message: 'Payment completed successfully! Completion OTP unlocked.',
          type: SnackbarType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        FixHubSnackbar.show(
          context: context,
          message: 'Payment verification failed. Please contact support.',
          type: SnackbarType.error,
        );
      }
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (mounted) {
      setState(() => _isProcessing = false);
      // Graceful cancellation / navigation back: no error popup, OTP remains safely locked
      FixHubSnackbar.show(
        context: context,
        message: 'Payment not completed. You can retry whenever ready.',
        type: SnackbarType.info,
      );
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    if (mounted) {
      FixHubSnackbar.show(
        context: context,
        message: 'External wallet selected: ${response.walletName}',
        type: SnackbarType.info,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FixHubCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Final Bill & Verification',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _isPaid
                      ? AppColors.success.withValues(alpha: 0.1)
                      : AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _isPaid ? 'Payment Settled' : 'Payment Due',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _isPaid ? AppColors.success : AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'The technician has finished the work and submitted the final billing.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Quotation Breakdown Container
          Container(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadius.cardRadius,
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Base Service Scope',
                        style: TextStyle(color: AppColors.textSecondary)),
                    Text(
                      '₹${_baseAmount.toStringAsFixed(0)} (Paid)',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Additional Charge (${_isCash ? "Cash" : "Online"})',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    Text(
                      '₹${_extraAmount.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const Divider(height: AppSpacing.lg, color: AppColors.border),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Final Amount',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                      '₹${widget.booking.totalAmount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Pay Button or Locked State
          if (!_isPaid && _extraAmount > 0) ...[
            FixHubButton(
              label: 'Pay ₹${_extraAmount.toStringAsFixed(0)} Online',
              isLoading: _isProcessing,
              onPressed: _isProcessing ? null : _startPayment,
            ),
            const SizedBox(height: AppSpacing.md),

            // Locked OTP card
            Container(
              padding: const EdgeInsets.all(AppSpacing.cardPadding),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.cardRadius,
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.textDisabled.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_outline_rounded,
                      color: AppColors.textDisabled,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Completion OTP Locked',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Your 4-digit OTP will unlock as soon as you complete the payment above.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Unlocked Completion OTP card
          if (_isPaid) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.cardPadding),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.cardRadius,
                border: Border.all(color: AppColors.buttonPrimary, width: 1.5),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.verified_user_rounded,
                          color: AppColors.buttonPrimary, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'COMPLETION OTP',
                        style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.buttonPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    widget.booking.completionOtp ?? '••••',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 8,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Share this 4-digit OTP with the technician only after you are completely satisfied with the completed work.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}


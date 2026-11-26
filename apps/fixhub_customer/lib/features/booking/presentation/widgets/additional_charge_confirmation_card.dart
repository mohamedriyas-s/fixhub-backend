import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_radius.dart';
import '../../../../core/config/theme/app_spacing.dart';
import '../../../../core/widgets/fixhub_button.dart';
import '../../../../core/widgets/fixhub_card.dart';
import '../../../../core/widgets/fixhub_dialog.dart';
import '../../../../core/widgets/fixhub_snackbar.dart';
import '../../data/models/booking_model.dart';
import '../providers/booking_provider.dart';

/// HelpTab Additional Charge Confirmation Card
///
/// Follows HelpTab Design System (Soft Neutral Design).
/// Displays:
///   - Original base price (already paid)
///   - Additional charge requested by technician
///   - Work description & reason
///   - Total service amount & final payable amount
///   - CTAs: Approve Additional Charges / Reject Additional Charges
class AdditionalChargeConfirmationCard extends ConsumerStatefulWidget {
  const AdditionalChargeConfirmationCard({
    super.key,
    required this.booking,
    this.onActionCompleted,
  });

  final BookingModel booking;
  final VoidCallback? onActionCompleted;

  @override
  ConsumerState<AdditionalChargeConfirmationCard> createState() =>
      _AdditionalChargeConfirmationCardState();
}

class _AdditionalChargeConfirmationCardState
    extends ConsumerState<AdditionalChargeConfirmationCard> {
  bool _isApproving = false;
  bool _isRejecting = false;

  double get _basePrice => widget.booking.totalAmount;

  double get _additionalCharge {
    if (widget.booking.additionalAmount != null &&
        widget.booking.additionalAmount! > 0) {
      return widget.booking.additionalAmount!;
    }
    if (widget.booking.revisedAmount != null &&
        widget.booking.revisedAmount! > _basePrice) {
      return widget.booking.revisedAmount! - _basePrice;
    }
    return 0.0;
  }

  double get _totalAmount {
    return widget.booking.revisedAmount ?? (_basePrice + _additionalCharge);
  }

  // Customer already paid the initial base price, so final payable now is the additional charge.
  double get _payableAmount => _additionalCharge;

  Future<void> _handleApprove() async {
    setState(() => _isApproving = true);
    try {
      await ref
          .read(bookingActionProvider.notifier)
          .approveRevision(widget.booking.id);
      if (mounted) {
        FixHubSnackbar.show(
          context: context,
          message: 'Additional charges approved! Technician can now proceed.',
          type: SnackbarType.success,
        );
        widget.onActionCompleted?.call();
      }
    } catch (e) {
      if (mounted) {
        FixHubSnackbar.show(
          context: context,
          message: 'Failed to approve additional charges. Please try again.',
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isApproving = false);
      }
    }
  }

  Future<void> _handleReject() async {
    final confirmed = await FixHubDialog.showConfirm(
      context: context,
      title: 'Reject Additional Charges?',
      message:
          'The technician will be notified to proceed with only the original agreed service scope at ₹${_basePrice.toStringAsFixed(0)}. No additional work or charges will be applied.',
      confirmLabel: 'Reject Charges',
      cancelLabel: 'Keep Reviewing',
      isDangerous: true,
    );

    if (confirmed != true) return;

    setState(() => _isRejecting = true);
    try {
      await ref
          .read(bookingActionProvider.notifier)
          .rejectRevision(widget.booking.id);
      if (mounted) {
        FixHubSnackbar.show(
          context: context,
          message:
              'Additional charges declined. Technician will proceed with original scope.',
          type: SnackbarType.info,
        );
        widget.onActionCompleted?.call();
      }
    } catch (e) {
      if (mounted) {
        FixHubSnackbar.show(
          context: context,
          message: 'Failed to reject charges. Please try again.',
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRejecting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _isApproving || _isRejecting;

    return FixHubCard(
      color: AppColors.elevatedSurface,
      borderColor: AppColors.border,
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header ─────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.request_quote_outlined,
                  color: AppColors.warning,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Additional Charge Request',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Technician requested approval for additional work',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ── Work Description & Reason ───────────────────────────
          if (widget.booking.priceRevisionDescription?.isNotEmpty == true ||
              widget.booking.priceRevisionNote?.isNotEmpty == true) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm + 4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.small),
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.booking.priceRevisionDescription?.isNotEmpty ==
                      true) ...[
                    Text(
                      'Work: ${widget.booking.priceRevisionDescription}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                    ),
                  ],
                  if (widget.booking.priceRevisionNote?.isNotEmpty ==
                      true) ...[
                    if (widget.booking.priceRevisionDescription?.isNotEmpty ==
                        true)
                      const SizedBox(height: 4),
                    Text(
                      'Reason: "${widget.booking.priceRevisionNote}"',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.md),

          // ── Table Header ─────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'DESCRIPTION',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
              ),
              Text(
                'AMOUNT',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      letterSpacing: 0.5,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ── Base Service Price ──────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'Base Service Price',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Paid',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.success,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
              Text(
                '₹${_basePrice.toStringAsFixed(0)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ── Additional Charges ──────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Additional Charges',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              Text(
                '+ ₹${_additionalCharge.toStringAsFixed(0)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, color: AppColors.divider),
          ),

          // ── Total Service Amount ────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Amount',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
              ),
              Text(
                '₹${_totalAmount.toStringAsFixed(0)}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.sm),

          // ── Highlighted Payable Box ─────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + 2,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.small),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payable Now',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '₹${_totalAmount.toStringAsFixed(0)} total − ₹${_basePrice.toStringAsFixed(0)} paid upfront',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                    ),
                  ],
                ),
                Text(
                  '₹${_payableAmount.toStringAsFixed(0)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.buttonPrimary,
                      ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // ── Action Buttons ──────────────────────────────────────
          FixHubButton(
            label: 'Approve Additional Charges',
            isLoading: _isApproving,
            onPressed: isBusy ? null : _handleApprove,
          ),
          const SizedBox(height: AppSpacing.sm),
          FixHubButton.secondary(
            label: 'Reject Additional Charges',
            isLoading: _isRejecting,
            onPressed: isBusy ? null : _handleReject,
          ),
        ],
      ),
    );
  }
}

/// Helper to show the Additional Charge Confirmation inside a Material 3 bottom sheet.
void showAdditionalChargeConfirmationSheet(
  BuildContext context,
  BookingModel booking, {
  VoidCallback? onCompleted,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(sheetContext).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: AppRadius.bottomSheetRadius,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPadding,
              AppSpacing.sm,
              AppSpacing.screenPadding,
              AppSpacing.screenPadding,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.buttonSecondaryBorder,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                AdditionalChargeConfirmationCard(
                  booking: booking,
                  onActionCompleted: () {
                    Navigator.of(sheetContext).pop();
                    onCompleted?.call();
                  },
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

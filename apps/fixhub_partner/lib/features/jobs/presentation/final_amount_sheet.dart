import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/theme/app_colors.dart';
import '../../../core/config/theme/app_radius.dart';
import '../../../core/config/theme/app_spacing.dart';
import '../../../core/widgets/fp_button.dart';
import '../domain/job_models.dart';
import 'job_provider.dart';

/// Sheet shown when technician slides "Slide to Complete Job".
///
/// Features:
/// - Reference base price (already paid).
/// - Initial appealed estimate reference (if any).
/// - Editable final additional charge field.
/// - "Pay on Cash" button directly below the amount field.
/// - "Request Online Payment" button.
/// - Confirmation dialogs for both pathways.
class FinalAmountSheet extends ConsumerStatefulWidget {
  final Job job;
  final VoidCallback onFinalized;

  const FinalAmountSheet({
    super.key,
    required this.job,
    required this.onFinalized,
  });

  static Future<void> show({
    required BuildContext context,
    required Job job,
    required VoidCallback onFinalized,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.bottomSheet,
      ),
      builder: (_) => FinalAmountSheet(job: job, onFinalized: onFinalized),
    );
  }

  @override
  ConsumerState<FinalAmountSheet> createState() => _FinalAmountSheetState();
}

class _FinalAmountSheetState extends ConsumerState<FinalAmountSheet> {
  late final TextEditingController _amountCtrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Default to appealed amount if present, otherwise 0
    final defaultAmount = widget.job.appealedAmount ??
        widget.job.additionalAmount ??
        0.0;
    _amountCtrl = TextEditingController(
      text: defaultAmount > 0 ? defaultAmount.toStringAsFixed(0) : '0',
    );
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  double get _enteredAmount {
    return double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
  }

  double get _basePrice {
    return widget.job.subService.basePrice ?? widget.job.totalAmount;
  }

  Future<void> _confirmAndFinalize(String paymentMethod) async {
    final amount = _enteredAmount;
    final isCash = paymentMethod == 'CASH';

    final message = isCash
        ? 'Customer will pay ₹${amount.toStringAsFixed(0)} in cash directly to you. Are you sure ₹${amount.toStringAsFixed(0)} is the final amount?'
        : 'Customer will receive a quotation of ₹${amount.toStringAsFixed(0)} to pay online. Are you sure ₹${amount.toStringAsFixed(0)} is the final amount?';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.dialog),
        title: const Text('Confirm Final Amount'),
        content: Text(
          message,
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textOnPrimary,
              shape: const RoundedRectangleBorder(borderRadius: AppRadius.button),
            ),
            child: const Text('Yes, Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(activeJobProvider.notifier).finalizeAmount(
            id: widget.job.id,
            finalAdditionalAmount: amount,
            paymentMethod: paymentMethod,
          );

      if (mounted) {
        Navigator.pop(context); // close sheet
        widget.onFinalized();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to finalize amount: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final appealed = widget.job.appealedAmount ?? widget.job.additionalAmount;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.base,
        AppSpacing.screenPadding,
        AppSpacing.screenPadding + bottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.base),

          Text(
            'Finalize Bill & Completion',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Sense and adjust the final actual additional amount before completing work.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Price Summary Box
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: AppRadius.card,
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Base Service (Paid)', style: TextStyle(color: AppColors.textSecondary)),
                    Text('₹${_basePrice.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
                if (appealed != null && appealed > 0) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Initial Estimate Appeal', style: TextStyle(color: AppColors.textSecondary)),
                      Text('~ ₹${appealed.toStringAsFixed(0)}', style: const TextStyle(color: AppColors.info)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Final Amount Field
          Text(
            'Final Additional Amount (₹)',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              prefixText: '₹ ',
              hintText: '0',
              filled: true,
              fillColor: AppColors.surface,
              border: const OutlineInputBorder(
                borderRadius: AppRadius.input,
                borderSide: BorderSide(color: AppColors.border),
              ),
              enabledBorder: const OutlineInputBorder(
                borderRadius: AppRadius.input,
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: AppRadius.input,
                borderSide: BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Button 1: Pay on Cash (Directly beneath amount field)
          FpButton(
            label: '💵 Pay on Cash',
            variant: FpButtonVariant.secondary,
            isLoading: _isLoading,
            onPressed: _isLoading ? null : () => _confirmAndFinalize('CASH'),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Button 2: Request Online Payment
          FpButton(
            label: '💳 Request Online Payment',
            variant: FpButtonVariant.primary,
            isLoading: _isLoading,
            onPressed: _isLoading ? null : () => _confirmAndFinalize('ONLINE'),
          ),
        ],
      ),
    );
  }
}

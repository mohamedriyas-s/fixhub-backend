import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/theme/app_colors.dart';
import '../../../core/config/theme/app_spacing.dart';
import '../../../core/config/theme/app_radius.dart';
import '../../../core/widgets/fp_button.dart';
import '../domain/job_models.dart';
import 'job_provider.dart';

/// Bottom sheet for requesting additional charges while a job is IN_PROGRESS.
/// Calls PATCH /technicians/jobs/:id/additional-charge
void showAdditionalChargeSheet(BuildContext context, Job job) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AdditionalChargeSheet(job: job),
  );
}

/// Backwards-compatible alias
void showPriceRevisionSheet(BuildContext context, Job job) {
  showAdditionalChargeSheet(context, job);
}

class _AdditionalChargeSheet extends ConsumerStatefulWidget {
  final Job job;

  const _AdditionalChargeSheet({required this.job});

  @override
  ConsumerState<_AdditionalChargeSheet> createState() =>
      _AdditionalChargeSheetState();
}

class _AdditionalChargeSheetState
    extends ConsumerState<_AdditionalChargeSheet> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _reasonController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  double get _enteredAmount {
    return double.tryParse(_amountController.text.trim()) ?? 0.0;
  }

  bool get _canSubmit {
    return _enteredAmount > 0 && _enteredAmount <= 100000;
  }

  void _addQuickAmount(int delta) {
    final current = _enteredAmount;
    final next = (current + delta).clamp(0.0, 99999.0);
    _amountController.text = next.toStringAsFixed(0);
    setState(() {});
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final amount = _enteredAmount;
    final description = _descriptionController.text.trim();
    final reason = _reasonController.text.trim();

    if (amount <= 0) {
      setState(() => _error = 'Please enter a valid amount greater than ₹0');
      return;
    }
    if (amount > 100000) {
      setState(() => _error = 'Amount cannot exceed ₹100,000');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      await ref.read(activeJobProvider.notifier).requestAdditionalCharge(
            id: widget.job.id,
            amount: amount,
            description: description.isNotEmpty ? description : null,
            reason: reason.isNotEmpty ? reason : null,
          );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Additional charge request sent to customer for approval.',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _error = 'Failed to submit additional charge request. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseAmount = widget.job.totalAmount;
    final additionalAmount = _enteredAmount;
    final totalPayable = baseAmount + additionalAmount;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenPadding,
                    AppSpacing.lg,
                    AppSpacing.screenPadding,
                    AppSpacing.bottomSafePad,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB), // Amber tint
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              border: Border.all(
                                color: AppColors.warning.withValues(alpha: 0.3),
                              ),
                            ),
                            child: const Icon(
                              Icons.add_card_rounded,
                              color: AppColors.warning,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                                const SizedBox(height: 2),
                                Text(
                                  'Customer confirmation is required to proceed',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: AppSpacing.lg),

                      // Price Breakdown Summary Card
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.cardPadding),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAF8F5), // Design system warm off-white
                          borderRadius: AppRadius.card,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            _PriceSummaryRow(
                              label: 'Base Service Price',
                              value: '₹${baseAmount.toStringAsFixed(0)}',
                              valueColor: AppColors.textSecondary,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            _PriceSummaryRow(
                              label: 'Additional Charges',
                              value: additionalAmount > 0
                                  ? '+ ₹${additionalAmount.toStringAsFixed(0)}'
                                  : '₹0',
                              valueColor: additionalAmount > 0
                                  ? AppColors.warning
                                  : AppColors.textSecondary,
                              badge: additionalAmount > 0 ? 'Requested' : null,
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: AppSpacing.sm,
                              ),
                              child: Divider(
                                color: AppColors.divider,
                                height: 1,
                              ),
                            ),
                            _PriceSummaryRow(
                              label: 'Total Payable Amount',
                              value: '₹${totalPayable.toStringAsFixed(0)}',
                              valueColor: AppColors.textPrimary,
                              isTotal: true,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppSpacing.lg),

                      // 1. Amount input (Strictly numeric)
                      Text(
                        'Additional Charge Amount (₹) *',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      TextFormField(
                        controller: _amountController,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,2}'),
                          ),
                        ],
                        onChanged: (_) => setState(() {}),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Amount is required';
                          }
                          final parsed = double.tryParse(value.trim());
                          if (parsed == null || parsed <= 0) {
                            return 'Enter a valid positive number greater than ₹0';
                          }
                          if (parsed > 100000) {
                            return 'Amount cannot exceed ₹100,000';
                          }
                          return null;
                        },
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.currency_rupee_rounded),
                          hintText: 'e.g. 50',
                        ),
                      ),

                      const SizedBox(height: AppSpacing.sm),

                      // Quick chip suggestions
                      Wrap(
                        spacing: 8,
                        children: [100, 250, 500, 1000].map((val) {
                          return ActionChip(
                            label: Text('+₹$val'),
                            onPressed: () => _addQuickAmount(val),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            backgroundColor: AppColors.surface,
                            side: const BorderSide(color: AppColors.border),
                            labelStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: AppSpacing.md),

                      // 2. Description input (Optional, max 100 chars)
                      Text(
                        'Item / Service Description (Optional)',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      TextFormField(
                        controller: _descriptionController,
                        maxLength: 100,
                        onChanged: (_) => setState(() {}),
                        validator: (value) {
                          if (value != null && value.trim().length > 100) {
                            return 'Description cannot exceed 100 characters';
                          }
                          return null;
                        },
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.inventory_2_outlined),
                          hintText: 'e.g. Dual-run capacitor & copper connector',
                        ),
                      ),

                      const SizedBox(height: AppSpacing.sm),

                      // 3. Reason input (Optional, max 300 chars)
                      Text(
                        'Reason for Additional Charge (Optional)',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      TextFormField(
                        controller: _reasonController,
                        maxLines: 3,
                        maxLength: 300,
                        onChanged: (_) => setState(() {}),
                        validator: (value) {
                          if (value != null && value.trim().length > 300) {
                            return 'Reason cannot exceed 300 characters';
                          }
                          return null;
                        },
                        decoration: const InputDecoration(
                          hintText:
                              'e.g. Inspection revealed capacitor burned out from recent power fluctuation.',
                          alignLabelWithHint: true,
                        ),
                      ),

                      // Error message if any
                      if (_error != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.errorLight,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                color: AppColors.error,
                                size: 18,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.error,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: AppSpacing.lg),

                      // Bottom actions
                      Row(
                        children: [
                          Expanded(
                            child: FpButton(
                              label: 'Cancel',
                              variant: FpButtonVariant.secondary,
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            flex: 2,
                            child: FpButton(
                              label: 'Send for Approval',
                              isLoading: _isSubmitting,
                              onPressed: _canSubmit ? _submit : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PriceSummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final bool isTotal;
  final String? badge;

  const _PriceSummaryRow({
    required this.label,
    required this.value,
    required this.valueColor,
    this.isTotal = false,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isTotal ? AppColors.textPrimary : AppColors.textSecondary,
                fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
              ),
        ),
        Row(
          children: [
            if (badge != null) ...[
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.warning,
                  ),
                ),
              ),
            ],
            Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: isTotal ? FontWeight.w700 : FontWeight.w600,
                    color: valueColor,
                    fontSize: isTotal ? 16 : 14,
                  ),
            ),
          ],
        ),
      ],
    );
  }
}

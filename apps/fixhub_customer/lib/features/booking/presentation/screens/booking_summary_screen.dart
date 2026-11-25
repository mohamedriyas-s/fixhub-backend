import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_radius.dart';
import '../../../../core/config/theme/app_spacing.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/widgets/fixhub_app_bar.dart';
import '../../../../core/widgets/fixhub_button.dart';
import '../../../../core/widgets/fixhub_card.dart';
import '../../../../core/widgets/fixhub_snackbar.dart';
import '../../../../core/widgets/fixhub_text_field.dart';
import '../providers/booking_flow_provider.dart';
import '../providers/booking_provider.dart';

class BookingSummaryScreen extends ConsumerStatefulWidget {
  const BookingSummaryScreen({super.key});

  @override
  ConsumerState<BookingSummaryScreen> createState() =>
      _BookingSummaryScreenState();
}

class _BookingSummaryScreenState extends ConsumerState<BookingSummaryScreen> {
  bool _isSubmitting = false;

  Future<void> _proceedToPay(double total) async {
    setState(() => _isSubmitting = true);
    final repo = ref.read(bookingRepositoryProvider);
    try {
      // 1. Create draft booking (slot held until payment capture or checkout cancellation)
      await ref.read(bookingFlowProvider.notifier).createDraftBooking(repo);

      if (mounted) context.push(RouteNames.payment);
    } catch (e) {
      if (mounted) {
        final rawMsg = e
            .toString()
            .replaceAll(RegExp(r'^(Exception:\s*|DioException:\s*)'), '');
        FixHubSnackbar.error(context, rawMsg);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final flowState = ref.watch(bookingFlowProvider);
    final service = flowState.selectedService;
    final address = flowState.selectedAddress;
    final slot = flowState.selectedSlot;

    if (service == null || address == null || slot == null) {
      return const Scaffold(
        body: Center(child: Text('Missing booking details')),
      );
    }

    const platformFee = 49.0;
    final total = service.basePrice + platformFee;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const FixHubAppBar(title: 'Review Booking'),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              children: [
                // ── Service Details ──────────────────────────────
                FixHubCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Service Details',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: AppRadius.smallRadius,
                            ),
                            child: const Icon(Icons.build_rounded),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  service.name,
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                Text(
                                  service.formattedPrice,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (flowState.issueTags.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.md),
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: flowState.issueTags.map((tag) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: AppSpacing.xxs,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.buttonPrimary.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Text(
                                tag,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppColors.buttonPrimary),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // ── Scheduled Date & Slot ─────────────────────────
                FixHubCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scheduled For',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded,
                              color: AppColors.textSecondary, size: 20),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            DateFormat('EEEE, MMM d, yyyy').format(slot.date),
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded,
                              color: AppColors.textSecondary, size: 20),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            slot.formattedTime,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // ── Address ───────────────────────────────────────
                FixHubCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Address',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          GestureDetector(
                            onTap: () => context.pop(),
                            child: Text(
                              'Change',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(
                                    color: AppColors.buttonPrimary,
                                    decoration: TextDecoration.underline,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        address.label,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        address.formattedAddress,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // ── Contact Number ────────────────────────────────
                FixHubCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Contact Number',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Technician will call this number for navigation and arrival coordination.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      FixHubTextField(
                        hint: 'Enter mobile number for technician',
                        keyboardType: TextInputType.phone,
                        onChanged: (val) =>
                            ref.read(bookingFlowProvider.notifier).setContactNumber(val),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // ── Payment Summary ───────────────────────────────
                FixHubCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Payment Summary',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _PriceRow(label: 'Service Total', amount: service.basePrice),
                      const SizedBox(height: AppSpacing.sm),
                      const _PriceRow(label: 'Platform Fee', amount: platformFee),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                        child: Divider(),
                      ),
                      _PriceRow(
                        label: 'Total Amount',
                        amount: total,
                        isTotal: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Sticky Pay Button ───────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: FixHubButton(
                label: 'Proceed to Pay ₹${total.toStringAsFixed(0)}',
                isLoading: _isSubmitting,
                onPressed: () => _proceedToPay(total),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.label,
    required this.amount,
    this.isTotal = false,
  });

  final String label;
  final double amount;
  final bool isTotal;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: isTotal
              ? Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)
              : Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
        ),
        Text(
          '₹${amount.toStringAsFixed(0)}',
          style: isTotal
              ? Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)
              : Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

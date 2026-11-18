import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_spacing.dart';
import '../../../../core/widgets/fixhub_app_bar.dart';
import '../../../../core/widgets/fixhub_button.dart';
import '../../../../core/widgets/fixhub_card.dart';
import '../../../../core/router/route_names.dart';
import '../providers/booking_flow_provider.dart';
import '../providers/booking_provider.dart';
import '../../data/models/address_model.dart';
import '../../../profile/presentation/providers/address_provider.dart';
import '../../../../core/widgets/fixhub_empty_state.dart';
import '../../../../core/widgets/fixhub_error_state.dart';
import '../../../../core/widgets/fixhub_shimmer.dart';

class SelectAddressScreen extends ConsumerStatefulWidget {
  const SelectAddressScreen({super.key});

  @override
  ConsumerState<SelectAddressScreen> createState() => _SelectAddressScreenState();
}

class _SelectAddressScreenState extends ConsumerState<SelectAddressScreen> {
  AddressModel? _selectedAddress;
  bool _isChecking = false;

  Future<void> _handleContinue() async {
    if (_selectedAddress == null || _isChecking) return;

    final subServiceId = ref.read(bookingFlowProvider).selectedService?.id;
    if (subServiceId == null) {
      ref.read(bookingFlowProvider.notifier).setAddress(_selectedAddress!);
      context.push(RouteNames.selectSlot);
      return;
    }

    setState(() => _isChecking = true);

    final isAvailable = await ref
        .read(bookingRepositoryProvider)
        .checkTechniciansAvailable(subServiceId, _selectedAddress!.pincode);

    if (!mounted) return;
    setState(() => _isChecking = false);

    if (!isAvailable) {
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        backgroundColor: AppColors.elevatedSurface,
        builder: (ctx) => Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.engineering_outlined,
                  size: 32,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'No Technicians Available',
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Currently, there are no active technicians available for this service in your area (${_selectedAddress!.pincode}). Please try selecting a different address or check back later.',
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              FixHubButton(
                label: 'Select Different Address',
                onPressed: () => Navigator.pop(ctx),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      );
      return;
    }

    ref.read(bookingFlowProvider.notifier).setAddress(_selectedAddress!);
    context.push(RouteNames.selectSlot);
  }

  @override
  Widget build(BuildContext context) {
    final addressesAsync = ref.watch(addressesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const FixHubAppBar(title: 'Select Address'),
      body: addressesAsync.when(
        data: (addresses) {
          if (addresses.isEmpty) {
            return FixHubEmptyState(
              icon: Icons.location_on_outlined,
              title: 'No saved addresses',
              message: 'Add an address to proceed with your booking.',
              actionLabel: 'Add Address',
              onAction: () => context.push('/add-address'),
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.screenPadding),
                  itemCount: addresses.length + 1,
                  itemBuilder: (context, index) {
                    if (index == addresses.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.md),
                        child: FixHubButton.secondary(
                          label: 'Add New Address',
                          icon: Icons.add_rounded,
                          onPressed: () {
                            context.push('/add-address');
                          },
                        ),
                      );
                    }

                    final address = addresses[index];
                    final isSelected = _selectedAddress?.id == address.id;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: FixHubCard(
                        borderColor: isSelected ? AppColors.buttonPrimary : null,
                        onTap: () {
                          setState(() {
                            _selectedAddress = address;
                          });
                        },
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              address.label.toUpperCase() == 'HOME'
                                  ? Icons.home_rounded
                                  : Icons.work_rounded,
                              color: AppColors.textPrimary,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          address.label,
                                          style: Theme.of(context).textTheme.titleMedium,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (address.isDefault) ...[
                                        const SizedBox(width: AppSpacing.sm),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: AppSpacing.xs,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.surface,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'Default',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: AppColors.textSecondary,
                                                  fontSize: 10,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.xxs),
                                  Text(
                                    address.formattedAddress,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check_circle_rounded,
                                color: AppColors.success,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.screenPadding),
                  child: FixHubButton(
                    label: _isChecking ? 'Checking Availability...' : 'Continue to Time Slot',
                    isLoading: _isChecking,
                    onPressed: _selectedAddress != null && !_isChecking ? _handleContinue : null,
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            children: [
              FixHubShimmer.card(height: 80),
              const SizedBox(height: AppSpacing.sm),
              FixHubShimmer.card(height: 80),
            ],
          ),
        ),
        error: (err, stack) => Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: FixHubErrorState(
            message: 'Could not load your saved addresses. Please try again.',
            onRetry: () =>
                ref.read(addressesProvider.notifier).fetchAddresses(),
          ),
        ),
      ),
    );
  }
}

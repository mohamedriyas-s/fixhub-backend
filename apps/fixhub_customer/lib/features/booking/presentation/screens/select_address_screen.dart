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
import '../../../location/presentation/providers/location_provider.dart';
import '../../../../core/widgets/fixhub_empty_state.dart';
import '../../../../core/widgets/fixhub_error_state.dart';
import '../../../../core/widgets/fixhub_shimmer.dart';
import '../../../../core/widgets/fixhub_snackbar.dart';

class SelectAddressScreen extends ConsumerStatefulWidget {
  const SelectAddressScreen({super.key});

  @override
  ConsumerState<SelectAddressScreen> createState() => _SelectAddressScreenState();
}

class _SelectAddressScreenState extends ConsumerState<SelectAddressScreen> {
  AddressModel? _selectedAddress;
  bool _isChecking = false;

  Future<void> _setDefault(AddressModel address) async {
    if (address.isDefault) return;
    try {
      await ref.read(addressesProvider.notifier).setDefaultAddress(address.id);
      if (mounted) {
        FixHubSnackbar.success(context, '"${address.label}" set as default address');
      }
    } catch (e) {
      if (mounted) {
        FixHubSnackbar.error(context, 'Failed to set default address');
      }
    }
  }

  void _confirmDelete(AddressModel address) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Address?',
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        content: Text(
          'Are you sure you want to delete "${address.label}"? This action cannot be undone.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(addressesProvider.notifier).deleteAddress(address.id);
                if (mounted) {
                  if (_selectedAddress?.id == address.id) {
                    setState(() => _selectedAddress = null);
                  }
                  FixHubSnackbar.success(context, 'Address removed successfully');
                }
              } catch (e) {
                if (mounted) {
                  FixHubSnackbar.error(context, 'Failed to delete address');
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleContinue() async {
    if (_selectedAddress == null || _isChecking) return;

    final subServiceId = ref.read(bookingFlowProvider).selectedService?.id;
    if (subServiceId == null) {
      FixHubSnackbar.error(context, 'Please select a service first.');
      return;
    }

    setState(() => _isChecking = true);
    final pincode = _selectedAddress!.pincode.trim();

    // 1. Validate if this address pincode is within an active FixHub service area
    final serviceAreaCheck = await ref
        .read(locationRepositoryProvider)
        .validateServiceArea(pincode, lat: _selectedAddress!.latitude, lng: _selectedAddress!.longitude);

    if (!serviceAreaCheck.isServiceable) {
      if (!mounted) return;
      setState(() => _isChecking = false);
      _showUnserviceableAreaSheet(pincode);
      return;
    }

    // 2. Check if verified, active technicians are available for this service
    final isAvailable = await ref
        .read(bookingRepositoryProvider)
        .checkTechniciansAvailable(subServiceId, pincode);

    if (!mounted) return;
    setState(() => _isChecking = false);

    if (!isAvailable) {
      _showNoTechniciansSheet(pincode);
      return;
    }

    ref.read(bookingFlowProvider.notifier).setAddress(_selectedAddress!);
    context.push(RouteNames.selectSlot);
  }

  void _showUnserviceableAreaSheet(String pincode) {
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
                Icons.location_off_outlined,
                size: 32,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Area Not Serviceable',
              style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'FixHub does not currently serve pincode $pincode. Please select an address within our serviceable areas or add a new address.',
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
  }

  void _showNoTechniciansSheet(String pincode) {
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
              'Currently, there are no active technicians available for this service in your area ($pincode). Please try selecting a different address or check back later.',
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
  }

  @override
  Widget build(BuildContext context) {
    final addressesAsync = ref.watch(addressesProvider);

    // Auto-select initial address: either already selected, or default, or first
    addressesAsync.whenData((addresses) {
      if (_selectedAddress == null && addresses.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _selectedAddress == null) {
            final defaultAddr = addresses.firstWhere(
              (a) => a.isDefault,
              orElse: () => addresses.first,
            );
            setState(() {
              _selectedAddress = defaultAddr;
            });
          }
        });
      }
    });

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
                                            color: AppColors.buttonPrimary,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'Default',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                        ),
                                      ] else ...[
                                        const SizedBox(width: AppSpacing.sm),
                                        InkWell(
                                          onTap: () => _setDefault(address),
                                          borderRadius: BorderRadius.circular(4),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: AppSpacing.xs,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.surface,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: AppColors.border),
                                            ),
                                            child: Text(
                                              'Set Default',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color: AppColors.textSecondary,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                  ),
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
                                  if (address.landmark != null && address.landmark!.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      'Landmark: ${address.landmark}',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: AppColors.textDisabled,
                                            fontStyle: FontStyle.italic,
                                          ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Edit Address',
                                  icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
                                  onPressed: () {
                                    context.push('/add-address', extra: address);
                                  },
                                ),
                                IconButton(
                                  tooltip: 'Delete Address',
                                  icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                                  onPressed: () => _confirmDelete(address),
                                ),
                                if (isSelected)
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: AppColors.success,
                                  ),
                              ],
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

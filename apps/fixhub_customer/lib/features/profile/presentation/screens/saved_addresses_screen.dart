import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_spacing.dart';
import '../../../../core/widgets/fixhub_app_bar.dart';
import '../../../../core/widgets/fixhub_card.dart';
import '../../../../core/widgets/fixhub_shimmer.dart';
import '../../../../core/widgets/fixhub_error_state.dart';
import '../../../../core/widgets/fixhub_empty_state.dart';
import '../../../../core/widgets/fixhub_snackbar.dart';
import '../../../booking/data/models/address_model.dart';
import '../providers/address_provider.dart';

class SavedAddressesScreen extends ConsumerWidget {
  const SavedAddressesScreen({super.key});

  void _confirmDelete(BuildContext context, WidgetRef ref, AddressModel address) {
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
                if (context.mounted) {
                  FixHubSnackbar.success(context, 'Address removed successfully');
                }
              } catch (e) {
                if (context.mounted) {
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addressesAsync = ref.watch(addressesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const FixHubAppBar(title: 'Saved Addresses'),
      body: addressesAsync.when(
        data: (addresses) {
          if (addresses.isEmpty) {
            return FixHubEmptyState(
              icon: Icons.location_on_outlined,
              title: 'No saved addresses',
              message: 'Add a new address to book services.',
              actionLabel: 'Add Address',
              onAction: () {
                context.push('/add-address');
              },
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            itemCount: addresses.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              final address = addresses[index];
              return FixHubCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      address.label.toUpperCase() == 'HOME'
                          ? Icons.home_rounded
                          : address.label.toUpperCase() == 'WORK'
                              ? Icons.work_rounded
                              : Icons.location_on_rounded,
                      color: AppColors.buttonPrimary,
                      size: 26,
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
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
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
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Text(
                                    'Default',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: AppColors.textSecondary,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            address.formattedAddress,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                          icon: const Icon(Icons.edit_outlined, color: AppColors.textSecondary, size: 20),
                          onPressed: () {
                            context.push('/add-address', extra: address);
                          },
                        ),
                        IconButton(
                          tooltip: 'Delete Address',
                          icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                          onPressed: () => _confirmDelete(context, ref, address),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: FixHubShimmer.listPlaceholder(itemCount: 3),
        ),
        error: (error, _) => FixHubErrorState(
          onRetry: () => ref.invalidate(addressesProvider),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.push('/add-address');
        },
        backgroundColor: AppColors.buttonPrimary,
        child: const Icon(Icons.add, color: AppColors.surface),
      ),
    );
  }
}

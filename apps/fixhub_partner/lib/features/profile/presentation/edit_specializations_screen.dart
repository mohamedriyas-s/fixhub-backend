import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_spacing.dart';
import '../../../../core/config/theme/app_radius.dart';
import '../../../../core/widgets/fp_app_bar.dart';
import '../../../../core/widgets/fp_button.dart';
import '../../../../core/widgets/fp_skeleton.dart';
import '../../onboarding/presentation/onboarding_provider.dart';
import '../data/profile_repository.dart';
import 'profile_provider.dart';

class EditSpecializationsScreen extends ConsumerStatefulWidget {
  const EditSpecializationsScreen({super.key});

  @override
  ConsumerState<EditSpecializationsScreen> createState() =>
      _EditSpecializationsScreenState();
}

class _EditSpecializationsScreenState
    extends ConsumerState<EditSpecializationsScreen> {
  String? _selectedCategoryId;
  List<String> _selectedSubServiceIds = [];
  bool _isSaving = false;
  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _initSelections();
      _isInitialized = true;
    }
  }

  void _initSelections() {
    final profileState = ref.read(profileProvider);
    final specializations = profileState.value?.specializations;
    if (specializations != null) {
      final ids = specializations.map((s) {
        if (s is Map<String, dynamic>) {
          return s['subService']?['id'] as String? ?? '';
        }
        return '';
      }).where((id) => id.isNotEmpty).toList();
      _selectedSubServiceIds = List.from(ids);
    }
  }

  void _toggleSubService(String id) {
    setState(() {
      if (_selectedSubServiceIds.contains(id)) {
        _selectedSubServiceIds.remove(id);
      } else {
        _selectedSubServiceIds.add(id);
      }
    });
  }

  Future<void> _save() async {
    if (_selectedSubServiceIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one service'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref
          .read(profileRepositoryProvider)
          .updateSpecializations(_selectedSubServiceIds);
      await ref.read(profileProvider.notifier).load();
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Specializations updated successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update specializations. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(catalogCategoriesProvider);
    final servicesAsync =
        ref.watch(catalogServicesProvider(_selectedCategoryId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const FpSurfaceAppBar(title: 'Edit Specializations'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Categories horizontal list
          Container(
            width: double.infinity,
            color: AppColors.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screenPadding,
                    AppSpacing.lg,
                    AppSpacing.screenPadding,
                    AppSpacing.md,
                  ),
                  child: Text(
                    'Select a Category',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                SizedBox(
                  height: 48,
                  child: categoriesAsync.when(
                    loading: () => ListView.separated(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.screenPadding),
                      scrollDirection: Axis.horizontal,
                      itemCount: 4,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: AppSpacing.sm),
                      itemBuilder: (_, __) =>
                          const FpSkeleton(width: 100, height: 40),
                    ),
                    error: (_, __) => const Center(
                      child: Text('Could not load categories'),
                    ),
                    data: (categories) => ListView.separated(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.screenPadding),
                      scrollDirection: Axis.horizontal,
                      itemCount: categories.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: AppSpacing.sm),
                      itemBuilder: (context, i) {
                        final cat = categories[i];
                        return _CategoryChip(
                          label: cat.name,
                          isSelected: _selectedCategoryId == cat.id,
                          onTap: () {
                            setState(() {
                              _selectedCategoryId = cat.id;
                            });
                          },
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.base),
              ],
            ),
          ),

          // Services list
          Expanded(
            child: _selectedCategoryId == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.touch_app_rounded,
                          size: 48,
                          color: AppColors.textDisabled,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Select a category above',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                        ),
                      ],
                    ),
                  )
                : servicesAsync.when(
                    loading: () => ListView.separated(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.screenPadding,
                          vertical: AppSpacing.base),
                      itemCount: 6,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (_, __) =>
                          const FpSkeleton(height: 52),
                    ),
                    error: (_, __) => const Center(
                      child: Text('Could not load services'),
                    ),
                    data: (services) {
                      if (services.isEmpty) {
                        return const Center(
                          child: Text('No services in this category'),
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.screenPadding,
                            vertical: AppSpacing.base),
                        itemCount: services.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, i) {
                          final svc = services[i];
                          final isSelected =
                              _selectedSubServiceIds.contains(svc.id);
                          return _ServiceTile(
                            name: svc.name,
                            isSelected: isSelected,
                            onTap: () => _toggleSubService(svc.id),
                          );
                        },
                      );
                    },
                  ),
          ),

          // Selected count & Save Button
          Container(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPadding,
              AppSpacing.base,
              AppSpacing.screenPadding,
              AppSpacing.bottomSafePad,
            ),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_selectedSubServiceIds.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.base),
                    child: Text(
                      '${_selectedSubServiceIds.length} service${_selectedSubServiceIds.length == 1 ? '' : 's'} selected',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                FpButton(
                  label: 'Save Changes',
                  isLoading: _isSaving,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: AppRadius.pill,
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  final String name;
  final bool isSelected;
  final VoidCallback onTap;

  const _ServiceTile({
    required this.name,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color:
                          isSelected ? AppColors.primary : AppColors.textPrimary,
                    ),
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

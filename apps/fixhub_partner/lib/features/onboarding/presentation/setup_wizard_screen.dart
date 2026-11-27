import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/theme/app_colors.dart';
import '../../../core/config/theme/app_spacing.dart';
import '../../../core/config/theme/app_radius.dart';
import '../../../core/widgets/fp_button.dart';
import '../../../core/widgets/fp_card.dart';
import '../../../core/widgets/fp_skeleton.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../auth/domain/auth_state.dart';
import 'onboarding_provider.dart';

class SetupWizardScreen extends ConsumerWidget {
  const SetupWizardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(setupWizardProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header + Step Indicator ─────────────────────────
            _WizardHeader(currentStep: state.step),

            // ── Step Body ───────────────────────────────────────
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.04, 0),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: switch (state.step) {
                  0 => const _Step1BasicInfo(key: ValueKey(0)),
                  1 => const _Step2Specializations(key: ValueKey(1)),
                  2 => const _Step3ServiceAreas(key: ValueKey(2)),
                  _ => const SizedBox.shrink(),
                },
              ),
            ),

            // ── Bottom Navigation ────────────────────────────────
            _WizardFooter(state: state),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────

class _WizardHeader extends StatelessWidget {
  final int currentStep;

  const _WizardHeader({required this.currentStep});

  static const _stepLabels = ['Basic Info', 'Services', 'Coverage'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.xl,
        AppSpacing.screenPadding,
        AppSpacing.base,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.build_circle_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Complete Your Profile',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  Text(
                    'Step ${currentStep + 1} of 3 — ${_stepLabels[currentStep]}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.base),
          // Progress bar
          Row(
            children: List.generate(3, (i) {
              final done = i <= currentStep;
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                  height: 4,
                  decoration: BoxDecoration(
                    color: done ? AppColors.primary : AppColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Step 1 — Basic Info
// ─────────────────────────────────────────────────────────────────

class _Step1BasicInfo extends ConsumerStatefulWidget {
  const _Step1BasicInfo({super.key});

  @override
  ConsumerState<_Step1BasicInfo> createState() => _Step1BasicInfoState();
}

class _Step1BasicInfoState extends ConsumerState<_Step1BasicInfo> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;

  @override
  void initState() {
    super.initState();
    final s = ref.read(setupWizardProvider);
    final authState = ref.read(authProvider);
    String initialName = s.name ?? '';
    String initialPhone = s.phone ?? '';
    String initialEmail = s.email ?? '';
    if (initialName.isEmpty && authState is AuthAuthenticated && authState.user.name != null && authState.user.name!.isNotEmpty) {
      initialName = authState.user.name!;
      ref.read(setupWizardProvider.notifier).setName(initialName);
    }
    if (initialPhone.isEmpty && authState is AuthAuthenticated && authState.user.phone.isNotEmpty) {
      initialPhone = authState.user.phone;
      ref.read(setupWizardProvider.notifier).setPhone(initialPhone);
    }
    if (initialEmail.isEmpty && authState is AuthAuthenticated && authState.user.email != null && authState.user.email!.isNotEmpty) {
      initialEmail = authState.user.email!;
      ref.read(setupWizardProvider.notifier).setEmail(initialEmail);
    }
    _nameCtrl = TextEditingController(text: initialName);
    _phoneCtrl = TextEditingController(text: initialPhone);
    _emailCtrl = TextEditingController(text: initialEmail);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(setupWizardProvider);
    final hasNameError = s.error != null && (s.name == null || s.name!.trim().isEmpty);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.md),

          // Avatar placeholder
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border, width: 2),
              ),
              child: const Icon(
                Icons.person_outline_rounded,
                size: 36,
                color: AppColors.primary,
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          Text(
            'Tell us about yourself',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'This information will be shown to customers.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),

          const SizedBox(height: AppSpacing.xl),

          _FieldLabel(label: 'Full Name *'),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            onChanged: (v) => ref.read(setupWizardProvider.notifier).setName(v.trim()),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your full name' : null,
            decoration: InputDecoration(
              hintText: 'e.g. Ramesh Kumar',
              prefixIcon: const Icon(Icons.person_outline_rounded),
              errorText: hasNameError ? 'Please enter your full name' : null,
            ),
          ),

          const SizedBox(height: AppSpacing.base),

          _FieldLabel(label: 'Contact Phone Number *'),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            onChanged: (v) =>
                ref.read(setupWizardProvider.notifier).setPhone(v.trim()),
            decoration: const InputDecoration(
              hintText: 'e.g. +91 98765 43210',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),

          const SizedBox(height: AppSpacing.base),

          _FieldLabel(label: 'Email Address (optional)'),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            onChanged: (v) =>
                ref.read(setupWizardProvider.notifier).setEmail(v.trim()),
            decoration: const InputDecoration(
              hintText: 'e.g. ramesh@example.com',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          FpCard(
            backgroundColor: AppColors.infoLight,
            showBorder: false,
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: AppColors.info,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Your profile will be reviewed by our team before you can start receiving jobs.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.info,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Step 2 — Specializations
// ─────────────────────────────────────────────────────────────────

class _Step2Specializations extends ConsumerWidget {
  const _Step2Specializations({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(setupWizardProvider);
    final categoriesAsync = ref.watch(catalogCategoriesProvider);
    final servicesAsync = ref.watch(
        catalogServicesProvider(state.selectedCategoryId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            AppSpacing.base,
            AppSpacing.screenPadding,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What services do you offer?',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Select a category then pick the specific services you can do.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const SizedBox(height: AppSpacing.base),

              // Category chips
              categoriesAsync.when(
                loading: () => const SizedBox(
                  height: 40,
                  child: Center(child: LinearProgressIndicator()),
                ),
                error: (_, __) => const Text('Could not load categories'),
                data: (categories) => Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: categories
                      .map((cat) => _CategoryChip(
                            label: cat.name,
                            isSelected:
                                state.selectedCategoryId == cat.id,
                            onTap: () => ref
                                .read(setupWizardProvider.notifier)
                                .setCategory(cat.id),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: AppSpacing.base),
            ],
          ),
        ),

        // Services list
        Expanded(
          child: state.selectedCategoryId == null
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
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                )
              : servicesAsync.when(
                  loading: () => ListView.separated(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.screenPadding),
                    itemCount: 6,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (_, __) => const FpSkeleton(height: 52),
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
                          horizontal: AppSpacing.screenPadding),
                      itemCount: services.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, i) {
                        final svc = services[i];
                        final isSelected = state.selectedSubServiceIds
                            .contains(svc.id);
                        return _ServiceTile(
                          name: svc.name,
                          isSelected: isSelected,
                          onTap: () => ref
                              .read(setupWizardProvider.notifier)
                              .toggleSubService(svc.id),
                        );
                      },
                    );
                  },
                ),
        ),

        // Selected count
        if (state.selectedSubServiceIds.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding,
              vertical: AppSpacing.sm,
            ),
            color: AppColors.primaryContainer,
            child: Text(
              '${state.selectedSubServiceIds.length} service${state.selectedSubServiceIds.length == 1 ? '' : 's'} selected',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
      ],
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
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textSecondary,
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
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryContainer : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded,
                      size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                name,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Step 3 — Service Areas
// ─────────────────────────────────────────────────────────────────

/// For now we render a curated list of major Indian cities.
/// When the backend's service-area CRUD API is available, fetch from there.
class _Step3ServiceAreas extends ConsumerStatefulWidget {
  const _Step3ServiceAreas({super.key});

  @override
  ConsumerState<_Step3ServiceAreas> createState() => _Step3ServiceAreasState();
}

class _Step3ServiceAreasState extends ConsumerState<_Step3ServiceAreas> {
  final _nameController = TextEditingController();
  final _pincodeController = TextEditingController();
  bool _hasAutoAdded = false;

  @override
  void dispose() {
    _nameController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  void _addArea() {
    final name = _nameController.text.trim();
    final pincode = _pincodeController.text.trim();
    if (name.isNotEmpty && pincode.isNotEmpty) {
      ref.read(setupWizardProvider.notifier).addCustomArea(name, pincode);
      _nameController.clear();
      _pincodeController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(setupWizardProvider);
    final autoDetectAsync = ref.watch(locationAutoDetectProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            AppSpacing.base,
            AppSpacing.screenPadding,
            AppSpacing.base,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Where do you work?',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'We will auto-detect your location, and you can add more areas if needed.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
        ),

        // Auto-detect section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
          child: autoDetectAsync.when(
            loading: () => const Row(
              children: [
                SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 12),
                Text('Detecting your location...'),
              ],
            ),
            error: (err, _) => const Text('Could not detect location. Please add manually.', style: TextStyle(color: AppColors.error)),
            data: (detected) {
              if (detected == null) return const Text('Could not detect location. Please add manually.', style: TextStyle(color: AppColors.error));
              
              // Auto-add once on first load; if user deletes it, it stays deleted
              if (!_hasAutoAdded) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && !state.customAreas.any((a) => a['pincode'] == detected['pincode'])) {
                    ref.read(setupWizardProvider.notifier).addCustomArea(detected['name']!, detected['pincode']!);
                  }
                  setState(() => _hasAutoAdded = true);
                });
              }

              return Row(
                children: [
                  const Icon(Icons.my_location_rounded, color: AppColors.success, size: 20),
                  const SizedBox(width: 8),
                  Text('Detected: ${detected['name']} (${detected['pincode']})', 
                    style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w600)),
                ],
              );
            },
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        // Custom Areas List
        Expanded(
          child: state.customAreas.isEmpty
              ? const Center(child: Text('No areas added yet'))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                  itemCount: state.customAreas.length,
                  separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, i) {
                    final area = state.customAreas[i];
                    return Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${area['name']} - ${area['pincode']}',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: AppColors.error),
                            onPressed: () => ref.read(setupWizardProvider.notifier).removeCustomArea(area['pincode']!),
                          )
                        ],
                      ),
                    );
                  },
                ),
        ),

        // Add Manually Form
        Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add another area manually:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        hintText: 'City Name',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    flex: 1,
                    child: TextField(
                      controller: _pincodeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: 'Pincode',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  IconButton(
                    style: IconButton.styleFrom(backgroundColor: AppColors.primaryContainer),
                    icon: const Icon(Icons.add, color: AppColors.primary),
                    onPressed: _addArea,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Footer navigation
// ─────────────────────────────────────────────────────────────────

class _WizardFooter extends ConsumerWidget {
  final SetupWizardState state;

  const _WizardFooter({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLastStep = state.step == 2;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.md,
        AppSpacing.screenPadding,
        AppSpacing.bottomSafePad,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Error message
          if (state.error != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Text(
                state.error!,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.error,
                ),
              ),
            ),
          ],

          Row(
            children: [
              if (state.step > 0) ...[
                Expanded(
                  child: FpButton(
                    label: 'Back',
                    variant: FpButtonVariant.secondary,
                    onPressed: () =>
                        ref.read(setupWizardProvider.notifier).prevStep(),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                flex: 2,
                child: FpButton(
                  label: isLastStep ? 'Complete Setup' : 'Continue',
                  isLoading: state.isSubmitting,
                  trailing: isLastStep
                      ? null
                      : const Icon(Icons.arrow_forward_rounded,
                          size: 18, color: Colors.white),
                  onPressed: () async {
                    final notifier =
                        ref.read(setupWizardProvider.notifier);
                    if (!notifier.validateCurrentStep()) return;
                    if (isLastStep) {
                      try {
                        await notifier.submit();
                        if (context.mounted) {
                          context.go('/dashboard');
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                '🎉 Profile submitted! You\'ll be notified once verified.',
                              ),
                              duration: Duration(seconds: 4),
                            ),
                          );
                        }
                      } catch (_) {
                        // Error displayed in state.error
                      }
                    } else {
                      notifier.nextStep();
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  final String label;

  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
    );
  }
}

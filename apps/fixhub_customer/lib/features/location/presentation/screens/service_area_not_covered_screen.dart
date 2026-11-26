import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_spacing.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/widgets/fixhub_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/location_provider.dart';

class ServiceAreaNotCoveredScreen extends ConsumerStatefulWidget {
  const ServiceAreaNotCoveredScreen({super.key});

  @override
  ConsumerState<ServiceAreaNotCoveredScreen> createState() =>
      _ServiceAreaNotCoveredScreenState();
}

class _ServiceAreaNotCoveredScreenState
    extends ConsumerState<ServiceAreaNotCoveredScreen> {
  final Set<String> _notifiedPincodes = {};
  bool _isSubmitting = false;

  void _handleBack() {
    final locationNotifier = ref.read(locationProvider.notifier);
    final locationState = ref.read(locationProvider);
    locationNotifier.revertToLastValidLocation();

    if (locationState.hasValidLocation) {
      context.go(RouteNames.home);
    } else {
      context.go(RouteNames.locationAccess);
    }
  }

  void _showNotifyMeSheet(BuildContext context, String currentPincode) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _NotifyMeSheet(
        pincode: currentPincode,
        onSuccess: () {
          setState(() {
            _notifiedPincodes.add(currentPincode);
          });
        },
      ),
    );
  }

  Future<void> _handleNotifyMe(String currentPincode) async {
    final authState = ref.read(authProvider);
    final user = authState.user;
    final phone = (user?.phone ?? '').trim();

    // If phone number is not available, open the sheet so the user can enter details
    if (phone.isEmpty) {
      _showNotifyMeSheet(context, currentPincode);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final repository = ref.read(locationRepositoryProvider);
      final name = user?.name?.trim() ?? '';
      final email = user?.email?.trim() ?? '';

      await repository.requestCoverage(
        currentPincode,
        name,
        phone,
        email,
      );

      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _notifiedPincodes.add(currentPincode);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to submit request. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final locationState = ref.watch(locationProvider);
    final currentPincode = locationState.currentPincode ?? '';
    final isNotified = _notifiedPincodes.contains(currentPincode);
    final authState = ref.watch(authProvider);
    final phone = authState.user?.phone;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: _handleBack,
          ),
        ),
        body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding,
                vertical: AppSpacing.md,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - (AppSpacing.md * 2),
                ),
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(),
                      Container(
                        width: 140,
                        height: 140,
                        decoration: const BoxDecoration(
                          color: AppColors.surface,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isNotified
                              ? Icons.notifications_active_rounded
                              : Icons.sentiment_dissatisfied_rounded,
                          size: 64,
                          color: isNotified ? AppColors.textPrimary : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        isNotified ? "We'll notify you!" : "We're not here yet",
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (locationState.currentCity != null || currentPincode.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: AppSpacing.sm,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(AppSpacing.md),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.location_on,
                                color: AppColors.textPrimary,
                                size: 18,
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Flexible(
                                child: Text.rich(
                                  TextSpan(
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    children: [
                                      if (locationState.currentCity != null &&
                                          locationState.currentCity!.isNotEmpty) ...[
                                        if (locationState.currentCity!.contains(currentPincode))
                                          TextSpan(text: locationState.currentCity!)
                                        else ...[
                                          TextSpan(text: '${locationState.currentCity} - '),
                                          TextSpan(
                                            text: currentPincode,
                                            style: const TextStyle(
                                              color: AppColors.info,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ] else
                                        TextSpan(
                                          text: currentPincode,
                                          style: const TextStyle(
                                            color: AppColors.info,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                    ],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        isNotified
                            ? (phone != null && phone.isNotEmpty
                                ? "You're on the waitlist! We will notify you at $phone as soon as HelpTab launches in your area."
                                : "You're on the waitlist! We will notify you as soon as HelpTab launches in your area.")
                            : "Sorry, we don't provide services in your area right now.",
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                      ),
                      if (isNotified) ...[
                        const SizedBox(height: AppSpacing.md),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(AppSpacing.sm),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                size: 16,
                                color: AppColors.success,
                              ),
                              SizedBox(width: AppSpacing.xs),
                              Text(
                                'Waitlist confirmed',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (!isNotified) ...[
                        FixHubButton(
                          label: 'Notify me when live',
                          isLoading: _isSubmitting,
                          onPressed: currentPincode.isNotEmpty
                              ? () => _handleNotifyMe(currentPincode)
                              : null,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextButton(
                          onPressed: () {
                            context.go(RouteNames.setLocation);
                          },
                          child: Text(
                            'Change Location',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ] else ...[
                        FixHubButton(
                          label: 'Change Location',
                          onPressed: () {
                            context.go(RouteNames.setLocation);
                          },
                        ),
                      ],
                      const SizedBox(height: AppSpacing.bottomSafePadding),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
    );
  }
}

class _NotifyMeSheet extends ConsumerStatefulWidget {
  const _NotifyMeSheet({
    required this.pincode,
    required this.onSuccess,
  });

  final String pincode;
  final VoidCallback onSuccess;

  @override
  ConsumerState<_NotifyMeSheet> createState() => _NotifyMeSheetState();
}

class _NotifyMeSheetState extends ConsumerState<_NotifyMeSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final authState = ref.read(authProvider);
    final user = authState.user;
    _nameController = TextEditingController(text: user?.name ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final repository = ref.read(locationRepositoryProvider);
      await repository.requestCoverage(
        widget.pincode,
        _nameController.text.trim(),
        _phoneController.text.trim(),
        _emailController.text.trim(),
      );

      if (!mounted) return;
      Navigator.pop(context); // Close sheet
      widget.onSuccess();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to submit request. Please try again.'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.xl)),
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.screenPadding,
        right: AppSpacing.screenPadding,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.bottomSafePadding,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Get Notified',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Leave your details and we will reach out as soon as we launch in ${widget.pincode}.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: AppSpacing.xl),
            
            // Name Field
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Name',
                hintText: 'John Doe',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.sm),
                ),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            
            // Phone Field
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                hintText: '9876543210',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.sm),
                ),
              ),
              validator: (v) => v == null || v.isEmpty ? 'Phone is required' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            
            // Email Field
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email Address',
                hintText: 'john@example.com',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.sm),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Email is required';
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)) {
                  return 'Enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.xl),
            
            FixHubButton(
              label: 'Submit',
              isLoading: _isLoading,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}



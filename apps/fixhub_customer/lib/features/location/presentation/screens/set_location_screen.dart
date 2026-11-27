import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_spacing.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/widgets/fixhub_button.dart';
import '../../../../core/widgets/fixhub_snackbar.dart';
import '../providers/location_provider.dart';

class SetLocationScreen extends ConsumerStatefulWidget {
  const SetLocationScreen({super.key});

  @override
  ConsumerState<SetLocationScreen> createState() => _SetLocationScreenState();
}

class _SetLocationScreenState extends ConsumerState<SetLocationScreen> {
  final _pincodeController = TextEditingController();
  String? _suggestedLocation;
  bool _isLoadingSuggestion = false;

  @override
  void initState() {
    super.initState();
    _pincodeController.addListener(_onPincodeChanged);
  }

  @override
  void dispose() {
    _pincodeController.removeListener(_onPincodeChanged);
    _pincodeController.dispose();
    super.dispose();
  }

  void _onPincodeChanged() async {
    final text = _pincodeController.text.trim();
    if (text.length == 6 && RegExp(r'^\d{6}$').hasMatch(text)) {
      setState(() => _isLoadingSuggestion = true);
      try {
        final address = await ref.read(locationRepositoryProvider).getAddressFromPincode(text);
        if (mounted && _pincodeController.text.trim() == text) {
          setState(() {
            _suggestedLocation = address?['city'];
            _isLoadingSuggestion = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isLoadingSuggestion = false);
      }
    } else {
      if (_suggestedLocation != null || _isLoadingSuggestion) {
        setState(() {
          _suggestedLocation = null;
          _isLoadingSuggestion = false;
        });
      }
    }
  }

  void _handleBack() {
    if (context.canPop()) {
      context.pop();
    } else if (ref.read(locationProvider).hasValidLocation) {
      context.go(RouteNames.home);
    } else {
      context.go(RouteNames.locationAccess);
    }
  }

  void _validatePincode() {
    final pincode = _pincodeController.text.trim();
    if (pincode.length == 6 && RegExp(r'^\d{6}$').hasMatch(pincode)) {
      ref.read(locationProvider.notifier).validateManualPincode(pincode);
    } else {
      FixHubSnackbar.error(context, 'Please enter a valid 6-digit pincode');
    }
  }

  @override
  Widget build(BuildContext context) {
    final locationState = ref.watch(locationProvider);

    ref.listen<LocationState>(locationProvider, (previous, next) {
      if (!(ModalRoute.of(context)?.isCurrent ?? false)) return;
      if (next.status == LocationStatus.valid) {
        final hasHomeInStack = GoRouter.of(context)
            .routerDelegate
            .currentConfiguration
            .matches
            .any((m) => m.matchedLocation == RouteNames.home);
        if (hasHomeInStack && context.canPop()) {
          context.pop();
        } else {
          context.go(RouteNames.home);
        }
      } else if (next.status == LocationStatus.invalid) {
        context.go(RouteNames.serviceAreaNotCovered);
      } else if (next.status == LocationStatus.error && next.errorMessage != null) {
        FixHubSnackbar.error(context, next.errorMessage!);
        ref.read(locationProvider.notifier).clearError();
      }
    });

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
          title: const Text('Enter Pincode'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: _handleBack,
          ),
        ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Where do you need service?',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.elevatedSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_outlined, color: AppColors.textSecondary),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: TextField(
                        controller: _pincodeController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: const InputDecoration(
                          hintText: 'Enter 6-digit Pincode',
                          border: InputBorder.none,
                          counterText: '',
                        ),
                        onSubmitted: (_) => _validatePincode(),
                      ),
                    ),
                  ],
                ),
              ),
              if (_isLoadingSuggestion) ...[
                const SizedBox(height: AppSpacing.sm),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                  child: Row(
                    children: [
                      SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: AppSpacing.sm),
                      Text(
                        'Detecting area...',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ] else if (_suggestedLocation != null) ...[
                const SizedBox(height: AppSpacing.sm),
                GestureDetector(
                  onTap: _validatePincode,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.near_me_rounded, color: AppColors.buttonPrimary, size: 18),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            _suggestedLocation!,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textSecondary, size: 12),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              FixHubButton(
                label: 'Choose your location',
                isLoading: locationState.status == LocationStatus.checking,
                onPressed: _validatePincode,
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}

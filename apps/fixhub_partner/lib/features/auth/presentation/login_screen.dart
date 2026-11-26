import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/theme/app_colors.dart';
import '../../../core/config/theme/app_spacing.dart';
import '../../../core/config/theme/app_radius.dart';
import '../../../core/widgets/fp_button.dart';
import '../presentation/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late final TapGestureRecognizer _termsRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _termsRecognizer = TapGestureRecognizer()
      ..onTap = () => _showLegalSheet(
            title: 'Partner Terms & Code of Conduct',
            body:
                'FixHub Partners agree to maintain high professional standards, '
                'arrive on time for scheduled bookings, use genuine spare parts, '
                'and adhere to agreed pricing, customer approval, and safety protocols.',
          );
    _privacyRecognizer = TapGestureRecognizer()
      ..onTap = () => _showLegalSheet(
            title: 'Privacy Policy',
            body:
                'FixHub values your privacy and security. Your contact details, '
                'verification documents, and location data are collected exclusively '
                'during active shifts and assigned jobs to enable dispatch, '
                'navigation, and payout processing.',
          );
  }

  @override
  void dispose() {
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _showLegalSheet({required String title, required String body}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            AppSpacing.md,
            AppSpacing.screenPadding,
            AppSpacing.bottomSafePad,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                title,
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                body,
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
              ),
              const SizedBox(height: AppSpacing.xl),
              FpButton(
                label: 'Close',
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _formattedPhone {
    final raw = _phoneController.text.trim().replaceAll(RegExp(r'\s+'), '');
    if (raw.startsWith('+91')) return raw;
    if (raw.startsWith('91') && raw.length == 12) return '+$raw';
    return '+91$raw';
  }

  Future<void> _sendOtp() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await ref
          .read(authProvider.notifier)
          .sendOtp(_formattedPhone);
      if (!mounted) return;
      final devOtp = result['devOtp'] as String?;
      context.push('/otp', extra: {'phone': _formattedPhone, 'devOtp': devOtp});
    } catch (e) {
      setState(() => _errorMessage = _humanizeError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _humanizeError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('phone'))
      return 'Please enter a valid Indian phone number.';
    if (msg.contains('network') || msg.contains('internet')) {
      return 'No internet connection. Please try again.';
    }
    if (msg.contains('429') || msg.contains('too many')) {
      return 'Too many requests. Please wait a moment.';
    }
    return 'Something went wrong. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.xxl),

                // Logo
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.build_circle_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // Heading
                Text(
                  'Welcome Back! 👋',
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Log in to continue receiving jobs.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxxl),

                // Phone field label
                Text(
                  'Mobile Number',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                // Phone input
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 2,
                  ),
                  decoration: InputDecoration(
                    hintText: '98765 43210',
                    hintStyle: const TextStyle(
                      letterSpacing: 1,
                      color: AppColors.textDisabled,
                    ),
                    prefixIcon: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: const BoxDecoration(
                        border: Border(
                          right: BorderSide(color: AppColors.border),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('🇮🇳', style: TextStyle(fontSize: 18)),
                          SizedBox(width: 6),
                          Text(
                            '+91',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  validator: (v) {
                    final val = v?.trim() ?? '';
                    if (val.isEmpty) return 'Please enter your phone number';
                    if (val.length != 10)
                      return 'Enter a valid 10-digit number';
                    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(val)) {
                      return 'Enter a valid Indian mobile number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.base),

                // Error message
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.errorLight,
                      borderRadius: AppRadius.chip,
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          size: 16,
                          color: AppColors.error,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: AppSpacing.xl),

                // Send OTP button
                FpButton(
                  label: 'Send OTP',
                  isLoading: _isLoading,
                  onPressed: _sendOtp,
                ),

                const SizedBox(height: AppSpacing.xl),

                // Terms
                Center(
                  child: Text.rich(
                    TextSpan(
                      text: 'By continuing, you agree to our ',
                      style: Theme.of(context).textTheme.bodySmall,
                      children: [
                        TextSpan(
                          text: 'Terms',
                          recognizer: _termsRecognizer,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        const TextSpan(text: ' & '),
                        TextSpan(
                          text: 'Privacy Policy',
                          recognizer: _privacyRecognizer,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
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

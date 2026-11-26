import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_spacing.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/widgets/fixhub_button.dart';
import '../../../../core/widgets/fixhub_snackbar.dart';
import '../providers/auth_provider.dart';

/// Login screen — email address entry.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  bool _isValid = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _onEmailChanged(String value) {
    setState(() {
      _isValid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());
    });
  }

  Future<void> _sendOtp() async {
    if (!_isValid) return;

    final email = _emailController.text.trim();
    await ref.read(authProvider.notifier).sendOtp(email);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // Navigate to OTP screen when OTP is sent
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (previous?.status != AuthStatus.otpSent && next.status == AuthStatus.otpSent) {
        context.push(RouteNames.otp);
      } else if (next.status == AuthStatus.error && next.errorMessage != null) {
        FixHubSnackbar.error(context, next.errorMessage!);
        ref.read(authProvider.notifier).clearError();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.xxl),

              // Title
              Text(
                'Welcome',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: AppColors.textPrimary,
                      height: 1.2,
                    ),
              ),

              const SizedBox(height: AppSpacing.sm),

              Text(
                'Login or register to continue',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),

              const SizedBox(height: AppSpacing.xxl),

              TextField(
                controller: _emailController,
                onChanged: _onEmailChanged,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'Email address',
                  hintText: 'you@example.com',
                ),
              ),

              const Spacer(),

              FixHubButton(
                label: 'Continue',
                onPressed: _isValid ? _sendOtp : null,
                isLoading: authState.status == AuthStatus.loading,
              ),

              const SizedBox(height: AppSpacing.md),

              // Terms
              Text(
                'By continuing, you agree to our Terms & Conditions and Privacy Policy',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textDisabled,
                    ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppSpacing.bottomSafePadding),
            ],
          ),
        ),
      ),
    );
  }
}

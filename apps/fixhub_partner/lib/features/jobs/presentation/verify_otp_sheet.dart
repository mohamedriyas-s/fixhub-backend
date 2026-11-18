import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/theme/app_colors.dart';
import '../../../core/config/theme/app_radius.dart';
import '../../../core/config/theme/app_spacing.dart';
import '../../../core/widgets/fp_button.dart';
import '../domain/job_models.dart';
import 'job_provider.dart';

/// Shows the OTP verification sheet to start work for an ARRIVED job.
Future<bool?> showVerifyOtpSheet(BuildContext context, Job job) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _VerifyOtpSheet(job: job),
  );
}

class _VerifyOtpSheet extends ConsumerStatefulWidget {
  final Job job;

  const _VerifyOtpSheet({required this.job});

  @override
  ConsumerState<_VerifyOtpSheet> createState() => _VerifyOtpSheetState();
}

class _VerifyOtpSheetState extends ConsumerState<_VerifyOtpSheet> {
  final _otpController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _otpController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool get _canSubmit => _otpController.text.trim().length == 4 && !_isSubmitting;

  Future<void> _verifyAndStart() async {
    final otp = _otpController.text.trim();
    if (otp.length != 4) {
      setState(() => _error = 'Please enter all 4 digits of the customer OTP');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      await ref.read(activeJobProvider.notifier).updateStatus(
            widget.job.id,
            'IN_PROGRESS',
            otp: otp,
          );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ OTP verified! Service has started.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      String message = 'Incorrect OTP. Please ask the customer to check their app.';
      if (e is DioException && e.response?.data != null) {
        final data = e.response!.data;
        if (data is Map && data['message'] != null) {
          message = data['message'].toString();
        }
      }
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _error = message;
        });
      }
    }
  }

  Widget _buildDigitBox(int index) {
    final text = _otpController.text;
    final digit = index < text.length ? text[index] : '';
    final isCurrent = _focusNode.hasFocus && (index == text.length || (index == 3 && text.length == 4));

    return Container(
      width: 58,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: _error != null
              ? AppColors.error
              : (isCurrent ? AppColors.primary : AppColors.border),
          width: isCurrent || _error != null ? 1.5 : 1,
        ),
      ),
      child: Text(
        digit,
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: _error != null ? AppColors.error : AppColors.textPrimary,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                AppSpacing.lg,
                AppSpacing.screenPadding,
                AppSpacing.bottomSafePad,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: const Icon(
                          Icons.verified_user_rounded,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Verify Customer OTP',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Ask the customer for the 4-digit code',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // Hidden input field with custom styled visual boxes
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Visual digit boxes
                      GestureDetector(
                        onTap: () => _focusNode.requestFocus(),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(4, _buildDigitBox),
                        ),
                      ),

                      // Invisible real TextField to capture keyboard events
                      Opacity(
                        opacity: 0.0,
                        child: TextField(
                          controller: _otpController,
                          focusNode: _focusNode,
                          autofocus: true,
                          keyboardType: TextInputType.number,
                          maxLength: 4,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          onChanged: (val) {
                            setState(() {
                              _error = null;
                            });
                            if (val.length == 4) {
                              _verifyAndStart();
                            }
                          },
                        ),
                      ),
                    ],
                  ),

                  // Error message display
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.errorLight,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: AppColors.error,
                            size: 18,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                color: AppColors.error,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.xl),

                  // Actions
                  FpButton(
                    label: 'Verify & Start Work',
                    isLoading: _isSubmitting,
                    onPressed: _canSubmit ? _verifyAndStart : null,
                  ),

                  const SizedBox(height: AppSpacing.xs),

                  Center(
                    child: TextButton(
                      onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


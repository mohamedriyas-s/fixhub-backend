import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_radius.dart';
import '../../../../core/config/theme/app_spacing.dart';
import '../../../../core/widgets/fixhub_card.dart';
import '../../../../core/widgets/fixhub_snackbar.dart';

/// Prominent, clean OTP card displayed to the customer to start the service.
/// Adheres strictly to the HelpTab Soft Neutral Design System.
class StartServiceOtpCard extends StatelessWidget {
  const StartServiceOtpCard({
    super.key,
    required this.otp,
    this.isTechnicianArrived = false,
  });

  final String otp;
  final bool isTechnicianArrived;

  @override
  Widget build(BuildContext context) {
    final digits = otp.split('');

    return FixHubCard(
      color: isTechnicianArrived
          ? AppColors.surface
          : AppColors.elevatedSurface,
      borderColor: isTechnicianArrived
          ? AppColors.buttonPrimary
          : AppColors.border,
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isTechnicianArrived
                          ? AppColors.buttonPrimary.withValues(alpha: 0.08)
                          : AppColors.surface,
                      borderRadius: AppRadius.smallRadius,
                    ),
                    child: Icon(
                      isTechnicianArrived
                          ? Icons.pin_outlined
                          : Icons.lock_outline_rounded,
                      size: 20,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Start Service OTP',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: otp));
                  FixHubSnackbar.show(
                    context: context,
                    message: 'OTP copied to clipboard',
                    type: SnackbarType.success,
                  );
                },
                borderRadius: AppRadius.smallRadius,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.copy_rounded,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Copy',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // OTP Digits display
          Center(
            child: Wrap(
              spacing: 12,
              children: digits.map((digit) {
                return Container(
                  width: 52,
                  height: 60,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.elevatedSurface,
                    borderRadius: AppRadius.buttonRadius,
                    border: Border.all(
                      color: isTechnicianArrived
                          ? AppColors.buttonPrimary
                          : AppColors.border,
                      width: isTechnicianArrived ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    digit,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          letterSpacing: 0,
                        ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            isTechnicianArrived
                ? 'Your technician is at your location! Please share this 4-digit code to start the service.'
                : 'Share this 4-digit code with your technician upon arrival to begin work.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isTechnicianArrived
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontWeight: isTechnicianArrived ? FontWeight.w500 : FontWeight.normal,
                  height: 1.4,
                ),
          ),
        ],
      ),
    );
  }
}


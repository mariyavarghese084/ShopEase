import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';

/// A reusable full-width primary (orange) button used across the application.
///
/// Pass [icon] to show a trailing icon (e.g. an arrow on the welcome screen).
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.minimumWidth = double.infinity,
    this.height = 48,
  });

  final String label;
  final VoidCallback? onPressed;

  /// Optional trailing icon.
  final IconData? icon;

  /// When [isLoading] is `true` a [CircularProgressIndicator] replaces the
  /// label and the button is disabled.
  final bool isLoading;

  /// Defaults to full width; pass a finite value to constrain the button.
  final double minimumWidth;

  /// Sleek responsive button height. Defaults to 48.
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: minimumWidth,
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryOrange,
          disabledBackgroundColor: AppColors.primaryOrange.withAlpha(100),
          foregroundColor: AppColors.white,
          elevation: 2,
          shadowColor: AppColors.primaryOrange.withAlpha(80),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: AppColors.white,
                  strokeWidth: 2.2,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      color: AppColors.white,
                    ),
                  ),
                  if (icon != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Icon(icon, size: 18, color: AppColors.white),
                  ],
                ],
              ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';

/// Route guard that verifies administrator authentication and role.
///
/// Wraps any administrator route to ensure only users with `role == 'admin'`
/// in their verified Firestore customer profile can access the panel.
class AdminGuard extends StatelessWidget {
  final Widget child;

  const AdminGuard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final authController = context.watch<AuthController>();

    // ── 1. Loading State ─────────────────────────────────────────────────────
    if (authController.isLoading) {
      return const _AdminLoadingScreen();
    }

    // ── 2. Unauthenticated State ─────────────────────────────────────────────
    if (!authController.isAuthenticated) {
      return const _AdminAccessDeniedScreen(
        title: 'Authentication Required',
        subtitle:
            'You must sign in with an authorized ShopEase administrator account to access this portal.',
        icon: Icons.lock_outline_rounded,
        actionType: _AccessActionType.signIn,
      );
    }

    // ── 3. Profile Fetching in Progress ──────────────────────────────────────
    if (authController.customerProfile == null &&
        !authController.needsProfileCompletion) {
      return const _AdminLoadingScreen(
        message: 'Verifying administrative privileges...',
      );
    }

    // ── 4. Unauthorized (Non-Admin Customer) State ───────────────────────────
    if (!authController.isAdmin) {
      final userEmail = authController.currentUser?.email ?? 'Unknown User';
      return _AdminAccessDeniedScreen(
        title: 'Access Restricted',
        subtitle:
            'The signed-in account ($userEmail) does not possess administrator privileges.\n\nTo manage ShopEase, this user must have role: "admin" assigned in Cloud Firestore.',
        icon: Icons.gpp_bad_outlined,
        actionType: _AccessActionType.notAdmin,
      );
    }

    // ── 5. Authorized Admin ──────────────────────────────────────────────────
    return child;
  }
}

enum _AccessActionType { signIn, notAdmin }

/// Screen shown when the user does not have permission to view the admin panel.
class _AdminAccessDeniedScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final _AccessActionType actionType;

  const _AdminAccessDeniedScreen({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.actionType,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthController>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 520),
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.divider),
              boxShadow: [
                BoxShadow(
                  color: AppColors.mainText.withAlpha(15),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.luxuryWine.withAlpha(20),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 36, color: AppColors.luxuryWine),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.mainText,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: AppColors.secondaryText,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                if (actionType == _AccessActionType.signIn) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(
                          context,
                        ).pushReplacementNamed(AppRoutes.login);
                      },
                      icon: const Icon(Icons.login_rounded, size: 18),
                      label: const Text(
                        'Sign In as Administrator',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.luxuryWine,
                        foregroundColor: AppColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(
                          context,
                        ).pushReplacementNamed(AppRoutes.customerHome);
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.divider),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Back to Customer Store',
                        style: TextStyle(
                          color: AppColors.mainText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(
                          context,
                        ).pushReplacementNamed(AppRoutes.customerHome);
                      },
                      icon: const Icon(Icons.storefront_rounded, size: 18),
                      label: const Text(
                        'Continue to Customer Store',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.luxuryWine,
                        foregroundColor: AppColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await auth.signOut();
                        if (context.mounted) {
                          Navigator.of(
                            context,
                          ).pushReplacementNamed(AppRoutes.login);
                        }
                      },
                      icon: const Icon(
                        Icons.logout_rounded,
                        size: 18,
                        color: AppColors.luxuryWine,
                      ),
                      label: const Text(
                        'Sign In as Different Account',
                        style: TextStyle(
                          color: AppColors.luxuryWine,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.luxuryWine),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Loading screen shown while verifying admin status.
class _AdminLoadingScreen extends StatelessWidget {
  final String message;

  const _AdminLoadingScreen({
    this.message = 'Authenticating administrator access...',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.luxuryWine),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.secondaryText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

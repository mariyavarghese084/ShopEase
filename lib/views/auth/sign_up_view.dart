import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../widgets/widgets.dart';

/// Customer registration screen creating both Firebase Auth credentials
/// and a Firestore customer profile document at `customers/{uid}`.
class SignUpView extends StatefulWidget {
  const SignUpView({super.key});

  @override
  State<SignUpView> createState() => _SignUpViewState();
}

class _SignUpViewState extends State<SignUpView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp(AuthController controller) async {
    // ── Step 1: Sign Up button pressed ──────────────────────────────────────
    debugPrint('[ShopEase:SignUp] Step 1: Sign Up button pressed');

    if (!_formKey.currentState!.validate()) {
      debugPrint('[ShopEase:SignUp] Validation failed, aborting submission');
      return;
    }

    // ── Step 2: Form validation completed ───────────────────────────────────
    debugPrint('[ShopEase:SignUp] Step 2: Form validation completed successfully');

    final success = await controller.signUp(
      fullName: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    // ── Step 9: Authentication/profile state verified ───────────────────────
    if (success && controller.customerProfile != null) {
      debugPrint(
        '[ShopEase:SignUp] Step 9: Authentication & profile state verified '
        '(UID: ${controller.customerProfile!.uid}, Name: ${controller.customerProfile!.fullName})',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Account created successfully! Welcome to ShopEase.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      );

      // ── Step 10: Navigation to customer home completed ────────────────────
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.customerHome,
        (route) => false,
      );
      debugPrint('[ShopEase:SignUp] Step 10: Navigation to customer home completed');
    } else {
      debugPrint(
        '[ShopEase:SignUp] Registration did not complete fully. '
        'needsProfileCompletion: ${controller.needsProfileCompletion}, '
        'error: ${controller.errorMessage}',
      );
    }
  }

  Future<void> _handleRetryProfile(AuthController controller) async {
    debugPrint('[ShopEase:SignUp] User requested profile creation retry');
    final success = await controller.completeProfile(
      fullName: _nameController.text.trim(),
    );

    if (!mounted) return;

    if (success && controller.customerProfile != null) {
      debugPrint('[ShopEase:SignUp] Step 9: Profile verified on retry');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profile created! Welcome to ShopEase.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.customerHome,
        (route) => false,
      );
      debugPrint('[ShopEase:SignUp] Step 10: Navigation to customer home completed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.mainText),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Consumer<AuthController>(
                builder: (context, controller, _) {
                  return Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Header ──────────────────────────────────────────
                        const Text(
                          'Create Account',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppColors.mainText,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        const Text(
                          'Sign up to begin your curated shopping journey.',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.secondaryText,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        // ── Pending Profile Retry Card ───────────────────────
                        if (controller.needsProfileCompletion)
                          Container(
                            margin: const EdgeInsets.only(bottom: AppSpacing.md),
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3CD),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(color: const Color(0xFFFFEEBA)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: const [
                                    Icon(
                                      Icons.info_outline_rounded,
                                      color: Color(0xFF856404),
                                      size: 20,
                                    ),
                                    SizedBox(width: AppSpacing.sm),
                                    Text(
                                      'Account Created, Profile Setup Pending',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF856404),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                const Text(
                                  'Your Firebase Auth account is created. Tap below to finalize your customer profile in Firestore without re-registering.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF856404),
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primaryOrange,
                                      foregroundColor: AppColors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 10),
                                    ),
                                    onPressed: controller.isLoading
                                        ? null
                                        : () => _handleRetryProfile(controller),
                                    icon: const Icon(Icons.refresh_rounded, size: 16),
                                    label: const Text('Complete Profile Setup'),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // ── Error Banner ────────────────────────────────────
                        if (controller.errorMessage != null && !controller.needsProfileCompletion)
                          Container(
                            margin: const EdgeInsets.only(bottom: AppSpacing.md),
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: AppColors.error.withAlpha(20),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(color: AppColors.error),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  color: AppColors.error,
                                  size: 20,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    controller.errorMessage!,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.error,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // ── Form Card ───────────────────────────────────────
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          decoration: BoxDecoration(
                            color: AppColors.cardBackground,
                            borderRadius: BorderRadius.circular(AppRadius.xl),
                            border: Border.all(
                              color: AppColors.divider.withAlpha(160),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.mainText.withAlpha(10),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              AppTextField(
                                controller: _nameController,
                                label: 'Full Name',
                                hintText: 'Jane Doe',
                                prefixIcon: Icons.person_outline_rounded,
                                textInputAction: TextInputAction.next,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter your full name.';
                                  }
                                  if (value.trim().length < 2) {
                                    return 'Name must be at least 2 characters.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: AppSpacing.md),
                              AppTextField(
                                controller: _emailController,
                                label: 'Email Address',
                                hintText: 'name@example.com',
                                prefixIcon: Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter your email.';
                                  }
                                  if (!value.contains('@') || !value.contains('.')) {
                                    return 'Please enter a valid email address.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: AppSpacing.md),
                              AppTextField(
                                controller: _passwordController,
                                label: 'Password',
                                hintText: 'At least 6 characters',
                                prefixIcon: Icons.lock_outline_rounded,
                                isPassword: true,
                                textInputAction: TextInputAction.next,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a password.';
                                  }
                                  if (value.length < 6) {
                                    return 'Password must be at least 6 characters.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: AppSpacing.md),
                              AppTextField(
                                controller: _confirmPasswordController,
                                label: 'Confirm Password',
                                hintText: 'Re-enter your password',
                                prefixIcon: Icons.lock_reset_rounded,
                                isPassword: true,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _handleSignUp(controller),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please confirm your password.';
                                  }
                                  if (value != _passwordController.text) {
                                    return 'Passwords do not match.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              PrimaryButton(
                                label: 'Create Account',
                                isLoading: controller.isLoading,
                                onPressed: () => _handleSignUp(controller),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        // ── Link to Sign In ─────────────────────────────────
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text(
                              'Already have an account? ',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.secondaryText,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                controller.clearMessages();
                                Navigator.of(context).pop();
                              },
                              child: const Text(
                                'Sign In',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryOrange,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../core/utils/responsive_utils.dart';
import '../../widgets/primary_button.dart';

/// Temporary welcome / splash screen shown before authentication is wired up.
///
/// Displays the ShopEase brand, tagline, and a "Get Started" CTA button.
/// The layout is fully responsive – it centres itself on wide screens.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: ResponsiveUtils.maxContentWidth,
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: ResponsiveUtils.responsive(
                          context,
                          mobile: AppSpacing.xl,
                          tablet: AppSpacing.xxxl,
                          desktop: 120,
                        ),
                        vertical: AppSpacing.lg,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // ── Top decorative area ───────────────────────────────────
                          FadeTransition(
                            opacity: _fadeIn,
                            child: SlideTransition(
                              position: _slideUp,
                              child: _HeroIllustration(),
                            ),
                          ),

                          const SizedBox(height: AppSpacing.md),

                          // ── Brand & CTA ───────────────────────────────────────────
                          FadeTransition(
                            opacity: _fadeIn,
                            child: SlideTransition(
                              position: _slideUp,
                              child: _BrandSection(onGetStarted: _handleGetStarted),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _handleGetStarted() {
    final auth = context.read<AuthController>();
    if (auth.isAuthenticated) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.customerHome);
    } else {
      Navigator.of(context).pushNamed(AppRoutes.login);
    }
  }
}

// ── Private widgets ─────────────────────────────────────────────────────────

/// The decorative illustration area at the top of the welcome screen.
class _HeroIllustration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer soft circle
          Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.beigeAccent.withAlpha(30),
            ),
          ),
          // Inner coloured circle
          Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.primaryOrange.withAlpha(25),
                  AppColors.beigeAccent.withAlpha(40),
                ],
              ),
            ),
          ),
          // Fashion bag icon
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.cardBackground,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryOrange.withAlpha(40),
                  blurRadius: 40,
                  spreadRadius: 5,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: const Icon(
              Icons.shopping_bag_outlined,
              size: 80,
              color: AppColors.primaryOrange,
            ),
          ),

          // Floating product tag – top right
          Positioned(
            top: 30,
            right: 20,
            child: _FloatingChip(
              icon: Icons.star_rounded,
              label: 'New Arrivals',
              color: AppColors.primaryOrange,
            ),
          ),

          // Floating product tag – bottom left
          Positioned(
            bottom: 30,
            left: 20,
            child: _FloatingChip(
              icon: Icons.local_offer_rounded,
              label: 'Best Deals',
              color: AppColors.beigeAccent,
            ),
          ),
        ],
      ),
    );
  }
}

/// A small floating badge used in the hero illustration.
class _FloatingChip extends StatelessWidget {
  const _FloatingChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppRadius.full),
        boxShadow: [
          BoxShadow(
            color: AppColors.mainText.withAlpha(18),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.mainText,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

/// Brand title, subtitle, and CTA section.
class _BrandSection extends StatelessWidget {
  const _BrandSection({required this.onGetStarted});

  final VoidCallback onGetStarted;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // App name
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Shop',
                style: tt.headlineLarge?.copyWith(
                  color: AppColors.mainText,
                  fontSize: 40,
                ),
              ),
              TextSpan(
                text: 'Ease',
                style: tt.headlineLarge?.copyWith(
                  color: AppColors.primaryOrange,
                  fontSize: 40,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        // Tagline
        Text(
          AppStrings.tagline,
          textAlign: TextAlign.center,
          style: tt.titleMedium?.copyWith(
            color: AppColors.beigeAccent,
            fontStyle: FontStyle.italic,
            letterSpacing: 0.5,
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // Subtitle
        Text(
          'Discover curated fashion collections\ntailored to your personal style.',
          textAlign: TextAlign.center,
          style: tt.bodyMedium?.copyWith(
            color: AppColors.secondaryText,
            height: 1.6,
          ),
        ),

        const SizedBox(height: AppSpacing.xl),

        // CTA button
        PrimaryButton(
          label: AppStrings.getStarted,
          onPressed: onGetStarted,
          icon: Icons.arrow_forward_rounded,
        ),

        const SizedBox(height: AppSpacing.md),

        // Already have account text (placeholder)
        TextButton(
          onPressed: () {
            Navigator.of(context).pushNamed(AppRoutes.login);
          },
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'Already have an account? ',
                  style: tt.bodyMedium?.copyWith(color: AppColors.secondaryText),
                ),
                TextSpan(
                  text: 'Sign In',
                  style: tt.bodyMedium?.copyWith(
                    color: AppColors.primaryOrange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/cart_controller.dart';
import '../../controllers/home_controller.dart';
import '../../controllers/order_controller.dart';
import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../services/firebase_service.dart';

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );

    _scaleAnimation = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );

    _animController.forward();
    _checkSavedSessionAndNavigate();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animController.dispose();
    super.dispose();
  }

  /// Checks Firebase Auth session persistence and warms up Firestore caches.
  Future<void> _checkSavedSessionAndNavigate() async {
    final startTime = DateTime.now();

    String? authenticatedUid;

    try {
      if (FirebaseService.isInitialized) {
        // First check existing cached currentUser
        final current = FirebaseService.auth.currentUser;
        if (current != null) {
          authenticatedUid = current.uid;
        } else {
          final user = await FirebaseService.auth
              .authStateChanges()
              .first
              .timeout(
                const Duration(milliseconds: 1400),
                onTimeout: () => null,
              );
          authenticatedUid = user?.uid;
        }
      }
    } catch (e) {
      debugPrint('[ShopEase:Splash] Notice checking auth state: $e');
    }

    if (!mounted) return;

    // Ensure splash is visible for minimum aesthetic time (at least 1.1 seconds)
    final elapsed = DateTime.now().difference(startTime);
    final remainingWait = const Duration(milliseconds: 1100) - elapsed;
    if (remainingWait > Duration.zero) {
      final completer = Completer<void>();
      _timer = Timer(remainingWait, () {
        if (!completer.isCompleted) completer.complete();
      });
      await completer.future;
    }

    if (!mounted) return;

    if (authenticatedUid != null && authenticatedUid.isNotEmpty) {
      // Warm up user data and role verification from Firestore before landing
      try {
        final auth = context.read<AuthController>();
        final home = context.read<HomeController>();
        final cart = context.read<CartController>();
        final order = context.read<OrderController>();

        await Future.wait([
          auth.verifyAdminPrivilege(),
          home.syncFavoritesWithUser(authenticatedUid),
          cart.syncWithUser(authenticatedUid),
          order.loadUserOrders(authenticatedUid),
        ]).timeout(const Duration(seconds: 2), onTimeout: () => []);
      } catch (e) {
        debugPrint('[ShopEase:Splash] Notice pre-fetching user data: $e');
      }

      if (!mounted) return;
      final auth = context.read<AuthController>();
      Navigator.of(context).pushReplacementNamed(auth.postLoginRoute);
    } else {
      // Guest or logged-out customer goes to welcome onboarding screen
      Navigator.of(context).pushReplacementNamed(AppRoutes.welcome);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1E1114), Color(0xFF13090B)],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 3),

                    // Luxury Glowing Brand Crest
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.luxuryWine.withAlpha(45),
                        border: Border.all(
                          color: AppColors.champagneGold.withAlpha(120),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.luxuryWine.withAlpha(90),
                            blurRadius: 28,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.auto_awesome,
                          color: AppColors.champagneGold,
                          size: 38,
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    // Brand Title
                    const Text(
                      'AÈRA',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        color: AppColors.white,
                        letterSpacing: 8.0,
                      ),
                    ),

                    const SizedBox(height: 6),

                    // Luxury Subtitle
                    Text(
                      'HAUTE BEAUTÉ • LUXURY COSMETICS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.champagneGold.withAlpha(220),
                        letterSpacing: 3.5,
                      ),
                    ),

                    const Spacer(flex: 2),

                    // Elegant Minimalist Loading Indicator
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.champagneGold.withAlpha(190),
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.md),

                    Text(
                      'ShopEase Luxury Experience',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.white.withAlpha(110),
                        letterSpacing: 1.2,
                      ),
                    ),

                    const Spacer(flex: 1),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

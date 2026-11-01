import 'package:flutter/material.dart';
import '../routes/app_routes.dart';
import '../../models/product_model.dart';
import '../../views/admin/admin_guard.dart';
import '../../views/admin/customers/admin_customers_view.dart';
import '../../views/admin/dashboard/admin_dashboard_view.dart';
import '../../views/admin/notifications/admin_notifications_view.dart';
import '../../views/admin/orders/admin_orders_view.dart';
import '../../views/admin/products/admin_products_view.dart';
import '../../views/auth/forgot_password_view.dart';
import '../../views/auth/sign_in_view.dart';
import '../../views/auth/sign_up_view.dart';
import '../../views/customer/cart/cart_view.dart';
import '../../views/customer/catalog/catalog_view.dart';
import '../../views/customer/checkout/checkout_view.dart';
import '../../views/customer/home/customer_home_view.dart';
import '../../views/customer/notifications/customer_notification_center_view.dart';
import '../../views/customer/orders/order_tracking_view.dart';
import '../../views/customer/product_detail/product_detail_view.dart';
import '../../views/splash/splash_view.dart';
import '../../views/welcome/welcome_screen.dart';

/// Generates [Route] objects from named route strings.
class AppRouter {
  AppRouter._();

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.splash:
        return _fade(const SplashView());

      case AppRoutes.welcome:
        return _fade(const WelcomeScreen());

      case AppRoutes.login:
        return _fade(const SignInView());

      case AppRoutes.register:
        return _fade(const SignUpView());

      case AppRoutes.forgotPassword:
        return _fade(const ForgotPasswordView());

      case AppRoutes.customerHome:
        return _fade(const CustomerHomeView());

      case AppRoutes.products:
        return _fade(const CatalogView(showBackButton: true));

      case AppRoutes.cart:
        return _fade(const CartView(showBackButton: true));

      case AppRoutes.checkout:
        return _fade(const CheckoutView());

      case AppRoutes.orders:
      case AppRoutes.orderDetail:
        return _fade(const OrderTrackingView());

      case AppRoutes.customerNotifications:
        return _fade(const CustomerNotificationCenterView());

      case AppRoutes.productDetail:
        if (settings.arguments is ProductModel) {
          return _fade(ProductDetailView(
            product: settings.arguments as ProductModel,
          ));
        }
        return _fade(const CustomerHomeView());

      // ── Admin Routes (Protected by AdminGuard) ─────────────────────────────
      case AppRoutes.adminDashboard:
        return _fade(const AdminGuard(child: AdminDashboardView()));

      case AppRoutes.adminProducts:
        return _fade(const AdminGuard(child: AdminProductsView()));

      case AppRoutes.adminOrders:
        return _fade(const AdminGuard(child: AdminOrdersView()));

      case AppRoutes.adminCustomers:
        return _fade(const AdminGuard(child: AdminCustomersView()));

      case AppRoutes.adminNotifications:
        return _fade(const AdminGuard(child: AdminNotificationsView()));

      default:
        return _fade(_NotFoundScreen(routeName: settings.name ?? 'unknown'));
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  static PageRouteBuilder<dynamic> _fade(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      transitionDuration: const Duration(milliseconds: 250),
    );
  }
}

/// Fallback screen rendered when an unknown route is requested.
class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen({required this.routeName});

  final String routeName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          'Route not found: $routeName',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

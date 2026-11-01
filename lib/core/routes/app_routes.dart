/// Named route constants used across the application.
///
/// Centralising route names here prevents magic strings from being
/// scattered throughout the codebase and makes refactoring safe.
class AppRoutes {
  AppRoutes._();

  // ── Splash / onboarding ───────────────────────────────────────────────────
  static const String splash = '/';
  static const String welcome = '/welcome';

  // ── Auth (not yet implemented) ────────────────────────────────────────────
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';

  // ── Customer ──────────────────────────────────────────────────────────────
  static const String customerHome = '/customer/home';
  static const String products = '/customer/products';
  static const String productDetail = '/customer/products/detail';
  static const String cart = '/customer/cart';
  static const String checkout = '/customer/checkout';
  static const String orders = '/customer/orders';
  static const String orderDetail = '/customer/orders/detail';
  static const String profile = '/customer/profile';
  static const String customerNotifications = '/customer/notifications';

  // ── Admin (not yet implemented) ───────────────────────────────────────────
  static const String adminDashboard = '/admin/dashboard';
  static const String adminProducts = '/admin/products';
  static const String adminOrders = '/admin/orders';
  static const String adminCustomers = '/admin/customers';
  static const String adminNotifications = '/admin/notifications';
}

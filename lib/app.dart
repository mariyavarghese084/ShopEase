import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'controllers/admin_customer_controller.dart';
import 'controllers/admin_notification_controller.dart';
import 'controllers/admin_order_controller.dart';
import 'controllers/admin_product_controller.dart';
import 'controllers/auth_controller.dart';
import 'controllers/cart_controller.dart';
import 'controllers/home_controller.dart';
import 'controllers/notification_controller.dart';
import 'controllers/order_controller.dart';
import 'controllers/profile_controller.dart';
import 'core/routes/app_router.dart';
import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'repositories/auth_repository.dart';
import 'repositories/cart_repository.dart';
import 'repositories/customer_repository.dart';
import 'repositories/favorites_repository.dart';
import 'repositories/notification_repository.dart';
import 'repositories/order_repository.dart';
import 'repositories/product_repository.dart';
import 'services/analytics_service.dart';
import 'services/in_app_messaging_service.dart';
import 'services/notification_service.dart';
import 'services/product_image_storage_service.dart';
import 'services/push_dispatch_service.dart';

/// Root widget of the ShopEase application.
///
/// Configures [MultiProvider] with authentication, customer profile,
/// product catalog, favorites, cart, and order controllers.
class ShopEaseApp extends StatelessWidget {
  const ShopEaseApp({super.key});

  /// Global navigator key allowing background/tap notifications to navigate reliably.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  // ── Providers ──────────────────────────────────────────────────────────────
  static final List<SingleChildWidget> _providers = [
    // Repositories & Services
    Provider<AuthRepository>(create: (_) => FirebaseAuthRepository()),
    Provider<CustomerRepository>(create: (_) => FirestoreCustomerRepository()),
    Provider<ProductRepository>(create: (_) => FirestoreProductRepository()),
    Provider<FavoritesRepository>(
      create: (_) => FirestoreFavoritesRepository(),
    ),
    Provider<CartRepository>(create: (_) => FirestoreCartRepository()),
    Provider<OrderRepository>(create: (_) => FirestoreOrderRepository()),
    Provider<ProductImageStorageService>(
      create: (_) => FirebaseProductImageStorageService(),
    ),
    Provider<NotificationService>(create: (_) => FirebaseNotificationService()),
    Provider<NotificationRepository>(
      create: (_) => FirestoreNotificationRepository(),
    ),
    Provider<PushDispatchService>(create: (_) => BackendPushDispatchService()),

    // Controllers
    ChangeNotifierProvider<AuthController>(
      create: (context) => AuthController(
        authRepository: context.read<AuthRepository>(),
        customerRepository: context.read<CustomerRepository>(),
      ),
    ),
    ChangeNotifierProvider<ProfileController>(
      create: (context) => ProfileController(
        customerRepository: context.read<CustomerRepository>(),
      ),
    ),
    ChangeNotifierProvider<NotificationController>(
      create: (context) => NotificationController(
        service: context.read<NotificationService>(),
        repository: context.read<NotificationRepository>(),
      ),
    ),
    ChangeNotifierProvider<AdminNotificationController>(
      create: (context) => AdminNotificationController(
        notificationRepository: context.read<NotificationRepository>(),
        pushDispatchService: context.read<PushDispatchService>(),
        customerRepository: context.read<CustomerRepository>(),
        productRepository: context.read<ProductRepository>(),
        authController: context.read<AuthController>(),
      ),
    ),
    ChangeNotifierProvider<CartController>(
      create: (context) => CartController(
        cartRepository: context.read<CartRepository>(),
        productRepository: context.read<ProductRepository>(),
      ),
    ),
    ChangeNotifierProvider<OrderController>(
      create: (context) => OrderController(
        orderRepository: context.read<OrderRepository>(),
        pushDispatchService: context.read<PushDispatchService>(),
        notificationRepository: context.read<NotificationRepository>(),
      ),
    ),
    ChangeNotifierProvider<HomeController>(
      create: (context) => HomeController(
        productRepository: context.read<ProductRepository>(),
        favoritesRepository: context.read<FavoritesRepository>(),
      ),
    ),
    ChangeNotifierProvider<AdminProductController>(
      create: (context) => AdminProductController(
        productRepository: context.read<ProductRepository>(),
      ),
    ),
    ChangeNotifierProvider<AdminOrderController>(
      create: (context) => AdminOrderController(
        orderRepository: context.read<OrderRepository>(),
        authController: context.read<AuthController>(),
        pushDispatchService: context.read<PushDispatchService>(),
        notificationRepository: context.read<NotificationRepository>(),
      ),
    ),
    ChangeNotifierProvider<AdminCustomerController>(
      create: (context) => AdminCustomerController(
        customerRepository: context.read<CustomerRepository>(),
        orderRepository: context.read<OrderRepository>(),
        authController: context.read<AuthController>(),
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: _providers,
      child: const _AppAuthSyncWrapper(child: _ShopEaseMaterialApp()),
    );
  }
}

class _ShopEaseMaterialApp extends StatelessWidget {
  const _ShopEaseMaterialApp();

  @override
  Widget build(BuildContext context) {
    final observer = AnalyticsService.observer;

    return MaterialApp(
      title: 'ShopEase',
      navigatorKey: ShopEaseApp.navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRouter.generateRoute,
      navigatorObservers: [?observer],
    );
  }
}

/// Automatically syncs customer private data (favorites, cart, orders, device notifications)
/// when the user signs in, restores session, or signs out.
class _AppAuthSyncWrapper extends StatefulWidget {
  final Widget child;

  const _AppAuthSyncWrapper({required this.child});

  @override
  State<_AppAuthSyncWrapper> createState() => _AppAuthSyncWrapperState();
}

class _AppAuthSyncWrapperState extends State<_AppAuthSyncWrapper> {
  String? _lastSyncedUid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthController>();
      context.read<NotificationController>().initialize(
        currentUid: auth.currentUser?.uid,
        onNavigate: (event) {
          final target = event.targetRoute;
          if (target != null && target.isNotEmpty) {
            ShopEaseApp.navigatorKey.currentState?.pushNamed(target);
          }
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.currentUser;
    final currentUid = user?.uid;
    final isAdmin = auth.isAdmin;
    final role = auth.customerProfile?.role ?? (isAdmin ? 'admin' : 'customer');

    if (currentUid != _lastSyncedUid) {
      _lastSyncedUid = currentUid;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        // Immediately purge in-memory state on any user identity transition to prevent cross-account leakage
        context.read<HomeController>().clearUserData();
        context.read<CartController>().clearUserData();
        context.read<OrderController>().clearUserData();

        // Sync notifications with authenticated identity
        context.read<NotificationController>().syncUser(currentUid);

        // Sync analytics and in-app messaging context
        AnalyticsService.setUserId(currentUid);
        if (user != null) {
          AnalyticsService.setUserProperty(name: 'role', value: role);
          if (isAdmin) {
            InAppMessagingService.setMessagesSuppressed(true);
          } else {
            InAppMessagingService.setMessagesSuppressed(false);
          }
        } else {
          AnalyticsService.setUserProperty(name: 'role', value: 'guest');
          InAppMessagingService.setMessagesSuppressed(false);
        }

        if (currentUid != null) {
          context.read<HomeController>().syncFavoritesWithUser(currentUid);
          context.read<CartController>().syncWithUser(currentUid);
          context.read<OrderController>().loadUserOrders(currentUid);
        } else {
          context.read<CartController>().syncWithUser(null);
        }
      });
    }

    return widget.child;
  }
}

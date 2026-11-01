import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shopease/app.dart';
import 'package:shopease/controllers/admin_customer_controller.dart';
import 'package:shopease/controllers/admin_notification_controller.dart';
import 'package:shopease/controllers/admin_order_controller.dart';
import 'package:shopease/controllers/admin_product_controller.dart';
import 'package:shopease/controllers/auth_controller.dart';
import 'package:shopease/controllers/cart_controller.dart';
import 'package:shopease/controllers/home_controller.dart';
import 'package:shopease/controllers/notification_controller.dart';
import 'package:shopease/controllers/order_controller.dart';
import 'package:shopease/controllers/profile_controller.dart';
import 'package:shopease/models/category_model.dart';
import 'package:shopease/models/customer_model.dart';
import 'package:shopease/models/notification_model.dart';
import 'package:shopease/models/order_model.dart';
import 'package:shopease/models/product_model.dart';
import 'package:shopease/repositories/auth_repository.dart';
import 'package:shopease/repositories/cart_repository.dart';
import 'package:shopease/repositories/customer_repository.dart';
import 'package:shopease/repositories/favorites_repository.dart';
import 'package:shopease/repositories/notification_repository.dart';
import 'package:shopease/repositories/order_repository.dart';
import 'package:shopease/repositories/product_repository.dart';
import 'package:shopease/services/notification_service.dart';
import 'package:shopease/services/product_image_storage_service.dart';
import 'package:shopease/services/push_dispatch_service.dart';
import 'package:shopease/views/admin/notifications/admin_notifications_view.dart';

class _FakeAuthRepo extends Fake implements AuthRepository {
  @override
  Stream<User?> get authStateChanges => const Stream.empty();
  @override
  User? get currentUser => null;
}

class _FakeCustomerRepo extends Fake implements CustomerRepository {
  @override
  Future<CustomerModel?> getCustomerProfile(String uid) async => null;
  @override
  Future<List<CustomerModel>> getAllCustomers() async => [];
}

class _FakeNotificationService extends Fake implements NotificationService {
  @override
  Stream<AppNotificationModel> get onForegroundMessage => const Stream.empty();
  @override
  Stream<NotificationTapEvent> get onNotificationTap => const Stream.empty();
  @override
  Stream<String> get onTokenRefresh => const Stream.empty();
  @override
  NotificationPermissionStatus get permissionStatus =>
      NotificationPermissionStatus.granted;
  @override
  Future<void> initialize({String? webVapidKey}) async {}
  @override
  Future<NotificationPermissionStatus> requestPermission() async =>
      NotificationPermissionStatus.granted;
  @override
  Future<String?> getToken({String? webVapidKey}) async => 'test_token';
  @override
  Future<String> getOrCreateDeviceId() async => 'test_device';
  @override
  Future<NotificationTapEvent?> getInitialNotification() async => null;
  @override
  Future<void> showLocalNotification(AppNotificationModel notification) async {}
}

class _FakeProductRepo extends Fake implements ProductRepository {
  @override
  Future<List<ProductModel>> getProducts({
    String? categoryId,
    String? searchQuery,
  }) async => [];
  @override
  Future<List<ProductModel>> getFeaturedProducts() async => [];
  @override
  Future<List<CategoryModel>> getCategories() async => [];
  @override
  Future<ProductModel?> getProductById(String id) async => null;
}

class _FakeOrderRepo extends Fake implements OrderRepository {
  @override
  Future<List<OrderModel>> getAllOrders() async => [];
  @override
  Future<List<OrderModel>> getOrders(String uid) async => [];
}

class _FakeFavoritesRepo extends Fake implements FavoritesRepository {
  @override
  Future<Set<String>> getFavorites(String uid) async => {};
  @override
  Future<void> addFavorite(String uid, String productId, {Map<String, dynamic>? extraData}) async {}
  @override
  Future<void> removeFavorite(String uid, String productId) async {}
}

class _FakeCartRepo extends Fake implements CartRepository {
  @override
  Future<List<CartItem>> getCartItems(
    String uid,
    ProductRepository productRepo,
  ) async => [];
  @override
  Future<void> saveCartItem(String uid, CartItem item) async {}
  @override
  Future<void> removeCartItem(String uid, String cartKey) async {}
  @override
  Future<void> clearCart(String uid) async {}
}

class _FakeImageStorageService extends Fake
    implements ProductImageStorageService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Provider Dependency Hierarchy Verification', () {
    testWidgets(
      'AdminNotificationsView resolves AuthController and AdminNotificationController from root MultiProvider',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 800));

        final authRepo = _FakeAuthRepo();
        final customerRepo = _FakeCustomerRepo();
        final productRepo = _FakeProductRepo();
        final notifRepo = InMemoryNotificationRepository();
        final pushService = InMemoryPushDispatchService();
        final orderRepo = _FakeOrderRepo();
        final notifService = _FakeNotificationService();
        final favoritesRepo = _FakeFavoritesRepo();
        final cartRepo = _FakeCartRepo();
        final imageStorage = _FakeImageStorageService();

        final authCtrl = AuthController(
          authRepository: authRepo,
          customerRepository: customerRepo,
        );
        authCtrl.setCustomerProfileForTesting(
          CustomerModel(
            uid: 'admin_test_1',
            email: 'admin@shopease.com',
            fullName: 'ShopEase Admin',
            role: 'admin',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        // Construct identical MultiProvider hierarchy as lib/app.dart
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              // Repositories
              Provider<AuthRepository>.value(value: authRepo),
              Provider<CustomerRepository>.value(value: customerRepo),
              Provider<ProductRepository>.value(value: productRepo),
              Provider<FavoritesRepository>.value(value: favoritesRepo),
              Provider<CartRepository>.value(value: cartRepo),
              Provider<OrderRepository>.value(value: orderRepo),
              Provider<ProductImageStorageService>.value(value: imageStorage),
              Provider<NotificationService>.value(value: notifService),
              Provider<NotificationRepository>.value(value: notifRepo),
              Provider<PushDispatchService>.value(value: pushService),

              // Controllers in updated valid hierarchy order:
              ChangeNotifierProvider<AuthController>.value(value: authCtrl),
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
                  notificationRepository: context
                      .read<NotificationRepository>(),
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
                  notificationRepository: context
                      .read<NotificationRepository>(),
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
                  notificationRepository: context
                      .read<NotificationRepository>(),
                ),
              ),
              ChangeNotifierProvider<AdminCustomerController>(
                create: (context) => AdminCustomerController(
                  customerRepository: context.read<CustomerRepository>(),
                  orderRepository: context.read<OrderRepository>(),
                  authController: context.read<AuthController>(),
                ),
              ),
            ],
            child: const MaterialApp(home: AdminNotificationsView()),
          ),
        );

        await tester.pumpAndSettle();

        // Verify AdminNotificationsView rendered with zero ProviderNotFoundException
        expect(find.text('Notification Management'), findsOneWidget);
        expect(find.text('Total Campaigns'), findsOneWidget);
        expect(find.text('Send Notification'), findsOneWidget);
      },
    );

    testWidgets('Full ShopEaseApp root structure mounts cleanly', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));

      await tester.pumpWidget(const ShopEaseApp());
      // Initial frame
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(ShopEaseApp), findsOneWidget);
    });
  });
}

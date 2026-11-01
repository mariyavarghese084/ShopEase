import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shopease/controllers/admin_product_controller.dart';
import 'package:shopease/controllers/auth_controller.dart';
import 'package:shopease/controllers/cart_controller.dart';
import 'package:shopease/controllers/order_controller.dart';
import 'package:shopease/controllers/profile_controller.dart';
import 'package:shopease/models/category_model.dart';
import 'package:shopease/models/customer_model.dart';
import 'package:shopease/models/order_model.dart';
import 'package:shopease/models/product_model.dart';
import 'package:shopease/repositories/auth_repository.dart';
import 'package:shopease/repositories/customer_repository.dart';
import 'package:shopease/repositories/order_repository.dart';
import 'package:shopease/repositories/product_repository.dart';
import 'package:shopease/views/customer/notifications/customer_notification_center_view.dart';
import 'package:shopease/views/customer/orders/order_tracking_view.dart';
import 'package:shopease/views/customer/profile/profile_view.dart';
import 'package:shopease/widgets/product_card.dart';

// ── Mock Repositories ────────────────────────────────────────────────────────

class MockProductRepo implements ProductRepository {
  List<ProductModel> products;

  MockProductRepo(this.products);

  @override
  Future<List<ProductModel>> getProducts({String? categoryId, String? searchQuery}) async {
    return products;
  }

  @override
  Future<List<ProductModel>> getFeaturedProducts() async {
    return products.where((p) => p.isFeatured && p.isInStock).toList();
  }

  @override
  Future<ProductModel?> getProductById(String id) async {
    try {
      return products.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<CategoryModel>> getCategories() async => [];

  @override
  Future<void> addProduct(ProductModel product) async {
    products.add(product);
  }

  @override
  Future<void> updateProduct(ProductModel product) async {
    final idx = products.indexWhere((p) => p.id == product.id);
    if (idx != -1) {
      products[idx] = product;
    } else {
      products.add(product);
    }
  }

  @override
  Future<void> deleteProduct(String id) async {
    products.removeWhere((p) => p.id == id);
  }

  @override
  Stream<List<ProductModel>> watchProducts({String? categoryId}) {
    return Stream.value(products);
  }
}

class MockAuthRepo extends Fake implements AuthRepository {
  @override
  Stream<User?> get authStateChanges => const Stream.empty();

  @override
  User? get currentUser => null;

  @override
  Future<void> signOut() async {}
}

class MockCustomerRepo implements CustomerRepository {
  CustomerModel? customer;

  MockCustomerRepo({this.customer});

  @override
  Future<CustomerModel?> getCustomerProfile(String uid) async => customer;

  @override
  Stream<CustomerModel?> watchCustomerProfile(String uid) =>
      Stream.value(customer);

  @override
  Future<void> createCustomerProfile(CustomerModel profile) async {
    customer = profile;
  }

  @override
  Future<void> updateCustomerProfile(CustomerModel profile) async {
    customer = profile;
  }

  @override
  Future<List<CustomerModel>> getAllCustomers() async =>
      customer != null ? [customer!] : [];
}

class MockOrderRepo implements OrderRepository {
  List<OrderModel> orders;

  MockOrderRepo([List<OrderModel>? initialOrders])
      : orders = initialOrders ?? [];

  @override
  Future<List<OrderModel>> getOrders(String uid) async => orders;

  @override
  Future<List<OrderModel>> getAllOrders() async => orders;

  @override
  Future<void> createOrder(String uid, OrderModel order) async {
    orders.add(order);
  }

  @override
  Future<void> updateOrderStatus(
    String uid,
    String orderId,
    OrderProgressStatus status, {
    String? adminId,
    String? note,
  }) async {
    final idx = orders.indexWhere((o) => o.id == orderId);
    if (idx != -1) {
      orders[idx] = orders[idx].copyWith(status: status);
    }
  }

  @override
  Future<String?> findCustomerUidForOrder(String orderId) async {
    for (final o in orders) {
      if (o.id == orderId) return o.customerId;
    }
    return null;
  }
}

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. Notification Center Responsive Layout (Overflow Fix)', () {
    testWidgets('Header renders on narrow Android screen (320px) without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: CustomerNotificationCenterView(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Notification Center'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('2. Customer Profile Enhancements', () {
    testWidgets('Displays customer profile details, metrics, and edit dialog',
        (tester) async {
      final customer = CustomerModel(
        uid: 'user_123',
        fullName: 'Elena Rostova',
        email: 'elena@aera.com',
        phoneNumber: '+91 98765 43210',
        address: 'Villa 42, Palm Boulevard, Mumbai',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );

      final authRepo = MockAuthRepo();
      final custRepo = MockCustomerRepo(customer: customer);
      final orderRepo = MockOrderRepo([
        OrderModel(
          id: 'ord_1',
          items: const [],
          subtotal: 1000,
          discount: 0,
          shippingFee: 0,
          total: 1000,
          status: OrderProgressStatus.placed,
          shippingName: 'Elena Rostova',
          shippingPhone: '+91 98765 43210',
          shippingAddress: 'Villa 42, Palm Boulevard',
          shippingCity: 'Mumbai',
          shippingPostalCode: '400001',
          paymentMethod: 'Credit Card',
          trackingNumber: 'AERA-TRK-001',
          courierName: 'BlueDart Express',
          estimatedDelivery: '3-5 Business Days',
          createdAt: DateTime.now(),
        ),
      ]);

      final authController = AuthController(
        authRepository: authRepo,
        customerRepository: custRepo,
      );
      authController.setCustomerProfileForTesting(customer);

      final orderController = OrderController(orderRepository: orderRepo);
      final profileController = ProfileController(customerRepository: custRepo);
      await profileController.loadProfile(customer.uid);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthController>.value(value: authController),
            ChangeNotifierProvider<OrderController>.value(value: orderController),
            ChangeNotifierProvider<ProfileController>.value(value: profileController),
          ],
          child: const MaterialApp(
            home: ProfileView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify name, email, phone, and address are visible
      expect(find.text('Elena Rostova'), findsWidgets);
      expect(find.text('elena@aera.com'), findsWidgets);
      expect(find.text('+91 98765 43210'), findsWidgets);
      expect(find.text('Villa 42, Palm Boulevard, Mumbai'), findsWidgets);

      // Verify Total Orders tile
      expect(find.text('Total Orders'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);

      // Open Edit Profile dialog
      final editButton = find.text('Edit Profile');
      expect(editButton, findsOneWidget);
      await tester.tap(editButton);
      await tester.pumpAndSettle();

      expect(find.text('Edit Customer Profile'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('Shows logout confirmation dialog and handles cancellation',
        (tester) async {
      final customer = CustomerModel(
        uid: 'user_123',
        fullName: 'Elena Rostova',
        email: 'elena@aera.com',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );

      final authRepo = MockAuthRepo();
      final custRepo = MockCustomerRepo(customer: customer);
      final orderRepo = MockOrderRepo();

      final authController = AuthController(
        authRepository: authRepo,
        customerRepository: custRepo,
      );
      authController.setCustomerProfileForTesting(customer);

      final orderController = OrderController(orderRepository: orderRepo);
      final profileController = ProfileController(customerRepository: custRepo);
      await profileController.loadProfile(customer.uid);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthController>.value(value: authController),
            ChangeNotifierProvider<OrderController>.value(value: orderController),
            ChangeNotifierProvider<ProfileController>.value(value: profileController),
          ],
          child: const MaterialApp(
            home: ProfileView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final signOutTile = find.text('Sign Out');
      await tester.scrollUntilVisible(signOutTile, 100);
      expect(signOutTile, findsOneWidget);
      await tester.tap(signOutTile);
      await tester.pumpAndSettle();

      expect(
        find.text('Are you sure you want to sign out of your AÈRA account?'),
        findsOneWidget,
      );

      // Tap cancel
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(
        find.text('Are you sure you want to sign out of your AÈRA account?'),
        findsNothing,
      );
    });
  });

  group('3. Customer Order Tracking (Read-Only)', () {
    testWidgets('Does not contain "Simulate Next Step" button; has "Refresh" button',
        (tester) async {
      final order = OrderModel(
        id: 'ord_100',
        items: const [],
        subtotal: 2500,
        discount: 0,
        shippingFee: 0,
        total: 2500,
        status: OrderProgressStatus.processing,
        shippingName: 'Elena Rostova',
        shippingPhone: '+91 98765 43210',
        shippingAddress: 'Villa 42, Palm Boulevard',
        shippingCity: 'Mumbai',
        shippingPostalCode: '400001',
        paymentMethod: 'Credit Card',
        trackingNumber: 'AERA-TRK-100',
        courierName: 'BlueDart Express',
        estimatedDelivery: '3-5 Business Days',
        createdAt: DateTime.now(),
      );

      final orderRepo = MockOrderRepo([order]);
      final orderController = OrderController(orderRepository: orderRepo);

      await tester.pumpWidget(
        ChangeNotifierProvider<OrderController>.value(
          value: orderController,
          child: MaterialApp(
            home: OrderTrackingView(order: order),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure "Simulate Next Step" button is completely absent
      expect(find.text('Simulate Next Step'), findsNothing);
      expect(find.text('Advance Order Status'), findsNothing);

      // Ensure "Refresh" button is present in the AppBar
      expect(find.text('Refresh'), findsOneWidget);
    });
  });

  group('4. Stock Status Synchronization & Out-of-Stock Validation', () {
    test('ProductModel.isInStock calculates correctly based on stock and availability',
        () {
      const inStockProduct = ProductModel(
        id: 'p1',
        name: 'Soft Pinch Blush',
        description: 'Blush',
        price: 1850,
        categoryId: 'blush',
        categoryName: 'Blush',
        stockQuantity: 10,
        isAvailable: true,
      );
      expect(inStockProduct.isInStock, isTrue);

      final zeroStockProduct = inStockProduct.copyWith(stockQuantity: 0);
      expect(zeroStockProduct.isInStock, isFalse);

      final unavailableProduct = inStockProduct.copyWith(isAvailable: false);
      expect(unavailableProduct.isInStock, isFalse);

      final zeroStockUnavailable =
          inStockProduct.copyWith(stockQuantity: 0, isAvailable: false);
      expect(zeroStockUnavailable.isInStock, isFalse);
    });

    test('AdminProductController updates stock and marks unavailable when stock = 0',
        () async {
      final initialProduct = const ProductModel(
        id: 'p1',
        name: 'Soft Pinch Blush',
        description: 'Blush',
        price: 1850,
        categoryId: 'blush',
        categoryName: 'Blush',
        stockQuantity: 10,
        isAvailable: true,
      );

      final repo = MockProductRepo([initialProduct]);
      final controller = AdminProductController(productRepository: repo);
      await controller.loadProducts();

      expect(controller.products.first.isInStock, isTrue);

      // Admin sets stock to 0
      final success =
          await controller.updateStockQuantity(controller.products.first, 0);
      expect(success, isTrue);

      final updated = controller.products.first;
      expect(updated.stockQuantity, equals(0));
      expect(updated.isAvailable, isFalse);
      expect(updated.isInStock, isFalse);
    });

    test('CartController rejects adding out-of-stock items and detects them',
        () {
      final inStockProduct = const ProductModel(
        id: 'p1',
        name: 'Soft Pinch Blush',
        description: 'Blush',
        price: 1850,
        categoryId: 'blush',
        categoryName: 'Blush',
        stockQuantity: 5,
        isAvailable: true,
      );
      final outOfStockProduct = const ProductModel(
        id: 'p2',
        name: 'Lip Souffle Matte',
        description: 'Lip Cream',
        price: 1200,
        categoryId: 'lips',
        categoryName: 'Lips',
        stockQuantity: 0,
        isAvailable: false,
      );

      final cart = CartController();

      // Adding out of stock product must fail
      final addedOut = cart.addItem(outOfStockProduct);
      expect(addedOut, isFalse);
      expect(cart.isEmpty, isTrue);

      // Adding in-stock product succeeds
      final addedIn = cart.addItem(inStockProduct);
      expect(addedIn, isTrue);
      expect(cart.itemCount, equals(1));
      expect(cart.hasOutOfStockItems, isFalse);

      // Syncing with catalog where p1 became out of stock
      cart.syncProductAvailability([
        inStockProduct.copyWith(stockQuantity: 0, isAvailable: false),
      ]);
      expect(cart.hasOutOfStockItems, isTrue);
      expect(cart.outOfStockItems.length, equals(1));
    });

    testWidgets('ProductCard displays "Out of Stock" badge and disables quick add',
        (tester) async {
      final outOfStockProduct = const ProductModel(
        id: 'p_out',
        name: 'Velvet Lip Tint',
        description: 'Lip Tint',
        price: 999,
        categoryId: 'lips',
        categoryName: 'Lips',
        stockQuantity: 0,
        isAvailable: false,
      );

      bool quickAddCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 180,
              height: 260,
              child: ProductCard(
                product: outOfStockProduct,
                onAddToCart: () {
                  quickAddCalled = true;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify "Out of Stock" badge
      expect(find.text('Out of Stock'), findsOneWidget);

      // Tap on quick add icon
      final iconFinder = find.byIcon(Icons.remove_shopping_cart_outlined);
      expect(iconFinder, findsOneWidget);
      await tester.tap(iconFinder);
      await tester.pumpAndSettle();

      // Callback should NOT be invoked
      expect(quickAddCalled, isFalse);
    });
  });
}

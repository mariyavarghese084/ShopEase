import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopease/app.dart';
import 'package:shopease/controllers/admin_customer_controller.dart';
import 'package:shopease/controllers/admin_order_controller.dart';
import 'package:shopease/controllers/admin_product_controller.dart';
import 'package:shopease/controllers/auth_controller.dart';
import 'package:shopease/controllers/cart_controller.dart';
import 'package:shopease/controllers/home_controller.dart';
import 'package:shopease/controllers/order_controller.dart';
import 'package:shopease/controllers/profile_controller.dart';
import 'package:shopease/core/constants/app_constants.dart';
import 'package:shopease/core/routes/app_routes.dart';
import 'package:shopease/models/customer_model.dart';
import 'package:shopease/models/order_model.dart';
import 'package:shopease/models/product_model.dart';
import 'package:shopease/repositories/auth_repository.dart';
import 'package:shopease/repositories/cart_repository.dart';
import 'package:shopease/repositories/customer_repository.dart';
import 'package:shopease/repositories/favorites_repository.dart';
import 'package:shopease/repositories/order_repository.dart';
import 'package:shopease/repositories/product_repository.dart';
import 'package:shopease/views/admin/admin_guard.dart';
import 'package:shopease/views/admin/customers/admin_customers_view.dart';
import 'package:shopease/views/admin/dashboard/admin_dashboard_view.dart';
import 'package:shopease/views/admin/orders/admin_orders_view.dart';
import 'package:shopease/views/admin/orders/order_details_dialog.dart';
import 'package:shopease/views/admin/products/admin_products_view.dart';
import 'package:shopease/views/auth/sign_in_view.dart';
import 'package:shopease/views/customer/home/customer_home_view.dart';
import 'package:shopease/views/customer/orders/order_tracking_view.dart';
import 'package:shopease/views/welcome/welcome_screen.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Splash screen renders luxury branding as initial route', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ShopEaseApp());
    await tester.pump();

    // Verify luxury splash branding
    expect(find.text('AÈRA'), findsOneWidget);
    expect(find.text('HAUTE BEAUTÉ • LUXURY COSMETICS'), findsOneWidget);
    expect(find.text('ShopEase Luxury Experience'), findsOneWidget);

    // Let the splash timer complete and settle transitions
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pumpAndSettle();
  });

  testWidgets('Welcome screen renders without errors', (
    WidgetTester tester,
  ) async {
    final authRepo = FirebaseAuthRepository();
    final customerRepo = FirestoreCustomerRepository();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthController>(
            create: (_) => AuthController(
              authRepository: authRepo,
              customerRepository: customerRepo,
            ),
          ),
        ],
        child: const MaterialApp(home: WelcomeScreen()),
      ),
    );
    await tester.pump();

    // Verify "Get Started" CTA button and branding
    expect(find.text(AppStrings.getStarted), findsOneWidget);
    expect(find.text('ShopEase', findRichText: true), findsWidgets);
    expect(find.text(AppStrings.tagline), findsOneWidget);
  });

  testWidgets(
    'CustomerHomeView renders with providers and luxury AÈRA branding',
    (WidgetTester tester) async {
      final productRepo = InMemoryProductRepository();
      final authRepo = FirebaseAuthRepository();
      final customerRepo = FirestoreCustomerRepository();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<ProductRepository>.value(value: productRepo),
            Provider<AuthRepository>.value(value: authRepo),
            Provider<CustomerRepository>.value(value: customerRepo),
            ChangeNotifierProvider<HomeController>(
              create: (_) => HomeController(productRepository: productRepo),
            ),
            ChangeNotifierProvider<CartController>(
              create: (_) => CartController(),
            ),
            ChangeNotifierProvider<OrderController>(
              create: (_) => OrderController(seedSample: true),
            ),
            ChangeNotifierProvider<AuthController>(
              create: (_) => AuthController(
                authRepository: authRepo,
                customerRepository: customerRepo,
              ),
            ),
            ChangeNotifierProvider<CartController>(
              create: (_) => CartController(),
            ),
            ChangeNotifierProvider<OrderController>(
              create: (_) => OrderController(),
            ),
            ChangeNotifierProvider<AuthController>(
              create: (_) => AuthController(
                authRepository: authRepo,
                customerRepository: customerRepo,
              ),
            ),
            ChangeNotifierProvider<ProfileController>(
              create: (_) =>
                  ProfileController(customerRepository: customerRepo),
            ),
          ],
          child: const MaterialApp(home: CustomerHomeView()),
        ),
      );

      // Initial pump and async data resolution
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify core UI components matching reference image
      expect(find.text('AÈRA'), findsOneWidget);
      expect(find.text('Luxury Cosmetics'), findsOneWidget);
      expect(find.text('100% Authentic'), findsOneWidget);
      expect(find.text('Order History & Tracking'), findsOneWidget);
      expect(find.text('ORDER NOW'), findsOneWidget);
    },
  );

  testWidgets('SignInView renders email and password fields', (
    WidgetTester tester,
  ) async {
    final authRepo = FirebaseAuthRepository();
    final customerRepo = FirestoreCustomerRepository();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthController>(
            create: (_) => AuthController(
              authRepository: authRepo,
              customerRepository: customerRepo,
            ),
          ),
        ],
        child: const MaterialApp(home: SignInView()),
      ),
    );

    await tester.pump();

    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Sign In'), findsWidgets);
  });

  testWidgets('OrderTrackingView renders live progress stepper and details', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<OrderController>(
            create: (_) => OrderController(seedSample: true),
          ),
          ChangeNotifierProvider<HomeController>(
            create: (_) =>
                HomeController(productRepository: InMemoryProductRepository()),
          ),
        ],
        child: const MaterialApp(home: OrderTrackingView()),
      ),
    );

    await tester.pump();

    expect(find.text('Order Tracking'), findsOneWidget);
    expect(find.text('Estimated Delivery'), findsOneWidget);
    expect(find.text('Order Confirmed'), findsOneWidget);
    expect(find.text('Delivery Details'), findsOneWidget);
  });

  test(
    'HomeController search filters by name, brand, and category with whitespace trimming',
    () async {
      final productRepo = InMemoryProductRepository();
      final controller = HomeController(productRepository: productRepo);

      // Initial load
      await Future.delayed(const Duration(milliseconds: 150));
      expect(controller.displayedProducts.length, 10);

      // Search by brand: "Luxe Cosmetics"
      await controller.setSearchQuery('  luxe cosmetics  ');
      expect(controller.displayedProducts.length, 2);
      expect(controller.displayedProducts.first.brand, 'Luxe Cosmetics');

      // Search by name case-insensitive: "soft pinch"
      await controller.setSearchQuery('SOFT PINCH');
      expect(controller.displayedProducts.length, 1);
      expect(
        controller.displayedProducts.first.name,
        'Soft Pinch Liquid Blush',
      );

      // Search by category name: "skincare"
      await controller.setSearchQuery('skincare');
      expect(controller.displayedProducts.length, 1);
      expect(controller.displayedProducts.first.id, 'p10');

      // Clear search restores full list
      controller.clearSearch();
      await Future.delayed(const Duration(milliseconds: 100));
      expect(controller.displayedProducts.length, 10);
      expect(controller.allProducts.length, 10);
    },
  );

  test('OrderModel and OrderItemModel serialization works correctly', () {
    final item = OrderItemModel(
      productId: 'p1',
      productName: 'Yara Rose',
      subtitle: 'EAU DE PARFUM',
      size: '100 ml',
      price: 42.0,
      quantity: 2,
    );

    final itemMap = item.toMap();
    final reconstructedItem = OrderItemModel.fromMap(itemMap);
    expect(reconstructedItem.productId, 'p1');
    expect(reconstructedItem.quantity, 2);
    expect(reconstructedItem.totalPrice, 84.0);

    final now = DateTime.now();
    final order = OrderModel(
      id: 'ORD-123456',
      customerId: 'test-uid-1',
      items: [reconstructedItem],
      subtotal: 84.0,
      discount: 10.0,
      shippingFee: 0.0,
      total: 74.0,
      status: OrderProgressStatus.processing,
      shippingName: 'John Doe',
      shippingPhone: '+1234567890',
      shippingAddress: '123 Test St',
      shippingCity: 'City',
      shippingPostalCode: '1000',
      paymentMethod: 'Credit Card',
      trackingNumber: 'TRK-123',
      courierName: 'Courier',
      estimatedDelivery: 'Tomorrow',
      createdAt: now,
    );

    final orderMap = order.toMap();
    final reconstructedOrder = OrderModel.fromMap(orderMap, id: 'ORD-123456');
    expect(reconstructedOrder.id, 'ORD-123456');
    expect(reconstructedOrder.customerId, 'test-uid-1');
    expect(reconstructedOrder.items.length, 1);
    expect(reconstructedOrder.total, 74.0);
    expect(reconstructedOrder.status, OrderProgressStatus.processing);
  });

  test(
    'CartController calculations and order placement totals are accurate',
    () async {
      final cart = CartController();
      final productRepo = InMemoryProductRepository();
      final product = (await productRepo.getProductById('p1'))!;

      cart.addItem(product, quantity: 2);
      expect(cart.itemCount, 2);
      expect(cart.subtotal, 3700.0);

      // Apply 20% discount code
      final applied = cart.applyPromoCode('AERA20');
      expect(applied, isTrue);
      expect(cart.discountAmount, closeTo(740.0, 0.01));
      expect(cart.totalPrice, closeTo(2960.0, 0.01));

      // Place order
      final orderController = OrderController();
      final orderItems = cart.items
          .map(
            (i) => OrderItemModel.fromProduct(
              i.product,
              quantity: i.quantity,
              size: i.selectedSize,
            ),
          )
          .toList();

      final order = await orderController.placeOrder(
        items: orderItems,
        subtotal: cart.subtotal,
        discount: cart.discountAmount,
        shippingFee: 0.0,
        total: cart.totalPrice,
        shippingName: 'Test Buyer',
        shippingPhone: '123',
        shippingAddress: 'Address',
        shippingCity: 'City',
        shippingPostalCode: '1000',
        paymentMethod: 'Card',
        uid: 'user-abc',
      );

      expect(order.id.startsWith('ORD-'), isTrue);
      expect(order.customerId, 'user-abc');
      expect(order.total, closeTo(2960.0, 0.01));
      expect(orderController.orders.first.id, order.id);
    },
  );

  // ── Admin Panel Stage 1 Tests ──────────────────────────────────────────────

  test('CustomerModel.isAdmin evaluates role correctly', () {
    final now = DateTime.now();
    final adminUser = CustomerModel(
      uid: 'admin-1',
      fullName: 'Super Admin',
      email: 'admin@shopease.com',
      role: 'admin',
      createdAt: now,
      updatedAt: now,
    );
    final adminWithSpaces = CustomerModel(
      uid: 'admin-2',
      fullName: 'Admin Spaced',
      email: 'admin2@shopease.com',
      role: '  Admin  ',
      createdAt: now,
      updatedAt: now,
    );
    final adminUppercase = CustomerModel(
      uid: 'admin-3',
      fullName: 'Admin Upper',
      email: 'admin3@shopease.com',
      role: 'ADMIN',
      createdAt: now,
      updatedAt: now,
    );
    final regularCustomer = CustomerModel(
      uid: 'customer-1',
      fullName: 'Jane Doe',
      email: 'jane@example.com',
      role: 'customer',
      createdAt: now,
      updatedAt: now,
    );
    final unknownRole = CustomerModel(
      uid: 'customer-2',
      fullName: 'Unknown Role',
      email: 'unknown@example.com',
      role: 'moderator',
      createdAt: now,
      updatedAt: now,
    );

    expect(adminUser.isAdmin, isTrue);
    expect(adminWithSpaces.isAdmin, isTrue);
    expect(adminUppercase.isAdmin, isTrue);
    expect(regularCustomer.isAdmin, isFalse);
    expect(unknownRole.isAdmin, isFalse);
  });

  test(
    'CustomerModel.fromMap parses role safely with trimming and lowercasing',
    () {
      final parsedAdmin = CustomerModel.fromMap({
        'uid': 'adm-1',
        'fullName': 'Admin User',
        'email': 'adm@test.com',
        'role': '  Admin ',
        'createdAt': '2026-10-29T00:00:00.000Z',
        'updatedAt': '2026-10-29T00:00:00.000Z',
      });
      expect(parsedAdmin.role, 'admin');
      expect(parsedAdmin.isAdmin, isTrue);

      final parsedMissingRole = CustomerModel.fromMap({
        'uid': 'cust-1',
        'fullName': 'No Role User',
        'email': 'norole@test.com',
      });
      expect(parsedMissingRole.role, 'customer');
      expect(parsedMissingRole.isAdmin, isFalse);
    },
  );

  test(
    'AuthController.postLoginRoute returns adminDashboard for admin and customerHome for non-admin',
    () {
      final adminAuth = _TestAuthController(isAdmin: true);
      final customerAuth = _TestAuthController(isAdmin: false);
      final missingProfileAuth = _TestAuthController(
        isAdmin: false,
        profile: null,
      );

      expect(adminAuth.postLoginRoute, AppRoutes.adminDashboard);
      expect(customerAuth.postLoginRoute, AppRoutes.customerHome);
      expect(missingProfileAuth.postLoginRoute, AppRoutes.customerHome);
    },
  );

  testWidgets(
    'SignInView navigates to adminDashboard upon verified administrator login',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final now = DateTime.now();
      final adminProfile = CustomerModel(
        uid: 'admin-999',
        fullName: 'Elena Vance',
        email: 'admin@shopease.com',
        role: 'admin',
        createdAt: now,
        updatedAt: now,
      );
      final mockAuth = _TestAuthController(
        isAuthenticated: true,
        isAdmin: true,
        profile: adminProfile,
        signInSuccess: true,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthController>.value(value: mockAuth),
          ],
          child: MaterialApp(
            initialRoute: AppRoutes.login,
            routes: {
              AppRoutes.login: (_) => const SignInView(),
              AppRoutes.adminDashboard: (_) =>
                  const Scaffold(body: Text('Admin Dashboard Landed')),
              AppRoutes.customerHome: (_) =>
                  const Scaffold(body: Text('Customer Home Landed')),
            },
          ),
        ),
      );
      await tester.pump();

      // Fill valid credentials
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'admin@shopease.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.pump();

      // Tap Sign In button
      await tester.tap(find.text('Sign In').first);
      await tester.pumpAndSettle();

      expect(find.text('Admin Dashboard Landed'), findsOneWidget);
      expect(find.text('Customer Home Landed'), findsNothing);
    },
  );

  testWidgets(
    'SignInView navigates to customerHome upon regular customer login',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final now = DateTime.now();
      final customerProfile = CustomerModel(
        uid: 'cust-101',
        fullName: 'Regular Shopper',
        email: 'shopper@example.com',
        role: 'customer',
        createdAt: now,
        updatedAt: now,
      );
      final mockAuth = _TestAuthController(
        isAuthenticated: true,
        isAdmin: false,
        profile: customerProfile,
        signInSuccess: true,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthController>.value(value: mockAuth),
          ],
          child: MaterialApp(
            initialRoute: AppRoutes.login,
            routes: {
              AppRoutes.login: (_) => const SignInView(),
              AppRoutes.adminDashboard: (_) =>
                  const Scaffold(body: Text('Admin Dashboard Landed')),
              AppRoutes.customerHome: (_) =>
                  const Scaffold(body: Text('Customer Home Landed')),
            },
          ),
        ),
      );
      await tester.pump();

      // Fill valid credentials
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'shopper@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.pump();

      // Tap Sign In button
      await tester.tap(find.text('Sign In').first);
      await tester.pumpAndSettle();

      expect(find.text('Customer Home Landed'), findsOneWidget);
      expect(find.text('Admin Dashboard Landed'), findsNothing);
    },
  );

  testWidgets(
    'SignInView prompts for profile completion and does not grant admin access when profile missing',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockAuth = _TestAuthController(
        isAuthenticated: true,
        isAdmin: false,
        profile: null,
        needsProfileCompletion: true,
        signInSuccess: true,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthController>.value(value: mockAuth),
          ],
          child: MaterialApp(
            initialRoute: AppRoutes.login,
            routes: {
              AppRoutes.login: (_) => const SignInView(),
              AppRoutes.adminDashboard: (_) =>
                  const Scaffold(body: Text('Admin Dashboard Landed')),
              AppRoutes.customerHome: (_) =>
                  const Scaffold(body: Text('Customer Home Landed')),
            },
          ),
        ),
      );
      await tester.pump();

      // Fill valid credentials
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'user@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'password123');
      await tester.pump();

      // Tap Sign In button
      await tester.tap(find.text('Sign In').first);
      await tester.pump();

      // Verify profile completion dialog opens instead of navigating to admin
      expect(find.text('Complete Your Profile'), findsOneWidget);
      expect(find.text('Admin Dashboard Landed'), findsNothing);
    },
  );

  testWidgets(
    'AdminGuard blocks unauthenticated users with Authentication Required screen',
    (WidgetTester tester) async {
      final mockAuth = _TestAuthController(isAuthenticated: false);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthController>.value(value: mockAuth),
          ],
          child: const MaterialApp(
            home: AdminGuard(child: AdminDashboardView()),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Authentication Required'), findsOneWidget);
      expect(find.text('Sign In as Administrator'), findsOneWidget);
      expect(find.text('Back to Customer Store'), findsOneWidget);
    },
  );

  testWidgets(
    'AdminGuard blocks unauthorized customer accounts with Access Restricted screen',
    (WidgetTester tester) async {
      final now = DateTime.now();
      final customerProfile = CustomerModel(
        uid: 'customer-123',
        fullName: 'Regular Customer',
        email: 'customer@example.com',
        role: 'customer',
        createdAt: now,
        updatedAt: now,
      );
      final mockAuth = _TestAuthController(
        isAuthenticated: true,
        isAdmin: false,
        profile: customerProfile,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthController>.value(value: mockAuth),
          ],
          child: const MaterialApp(
            home: AdminGuard(child: AdminDashboardView()),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Access Restricted'), findsOneWidget);
      expect(
        find.textContaining('does not possess administrator privileges'),
        findsOneWidget,
      );
      expect(find.text('Continue to Customer Store'), findsOneWidget);
    },
  );

  testWidgets(
    'AdminGuard allows authorized admin and renders AdminDashboardView shell',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final now = DateTime.now();
      final adminProfile = CustomerModel(
        uid: 'admin-999',
        fullName: 'Elena Vance',
        email: 'elena.vance@shopease.com',
        role: 'admin',
        createdAt: now,
        updatedAt: now,
      );
      final mockAuth = _TestAuthController(
        isAuthenticated: true,
        isAdmin: true,
        profile: adminProfile,
      );

      final productRepo = InMemoryProductRepository();
      final orderRepo = InMemoryOrderRepository(seedSampleData: true);
      final customerRepo = InMemoryCustomerRepository([adminProfile]);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<ProductRepository>.value(value: productRepo),
            Provider<OrderRepository>.value(value: orderRepo),
            Provider<CustomerRepository>.value(value: customerRepo),
            ChangeNotifierProvider<AuthController>.value(value: mockAuth),
            ChangeNotifierProvider<AdminProductController>(
              create: (_) => AdminProductController(productRepository: productRepo),
            ),
            ChangeNotifierProvider<AdminOrderController>(
              create: (_) => AdminOrderController(
                orderRepository: orderRepo,
                authController: mockAuth,
              ),
            ),
            ChangeNotifierProvider<AdminCustomerController>(
              create: (_) => AdminCustomerController(
                customerRepository: customerRepo,
                orderRepository: orderRepo,
                authController: mockAuth,
              ),
            ),
          ],
          child: const MaterialApp(
            home: AdminGuard(child: AdminDashboardView()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify Admin Header
      expect(find.text('Business Analytics Dashboard'), findsWidgets);
      expect(find.text('ADMIN'), findsOneWidget);

      // Verify Welcome Shell and AÈRA Luxury Analytics
      expect(find.text('Welcome back, Elena Vance'), findsOneWidget);
      expect(find.text('AÈRA LUXURY DASHBOARD'), findsOneWidget);
      expect(find.text('Total Revenue'), findsOneWidget);
      expect(find.text('Total Orders'), findsOneWidget);

      // Verify Sidebar Navigation
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Products'), findsOneWidget);
      expect(find.text('Orders'), findsOneWidget);
      expect(find.text('Customers'), findsOneWidget);
    },
  );

  testWidgets(
    'Admin Stage 2 Products view and Stage 3/4 placeholders render cleanly',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final now = DateTime.now();
      final adminProfile = CustomerModel(
        uid: 'admin-999',
        fullName: 'Elena Vance',
        email: 'elena.vance@shopease.com',
        role: 'admin',
        createdAt: now,
        updatedAt: now,
      );
      final mockAuth = _TestAuthController(
        isAuthenticated: true,
        isAdmin: true,
        profile: adminProfile,
      );
      final productRepo = InMemoryProductRepository();

      // Test Stage 2 Admin Products screen
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<ProductRepository>.value(value: productRepo),
            ChangeNotifierProvider<AuthController>.value(value: mockAuth),
            ChangeNotifierProvider<AdminProductController>(
              create: (_) =>
                  AdminProductController(productRepository: productRepo),
            ),
          ],
          child: const MaterialApp(home: AdminProductsView()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Product Catalog & Inventory'), findsOneWidget);
      expect(find.text('Add Product'), findsOneWidget);
      expect(find.text('Total Items'), findsOneWidget);

      // Test Stage 3 Admin Orders screen
      final orderRepo = InMemoryOrderRepository(seedSampleData: true);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<OrderRepository>.value(value: orderRepo),
            ChangeNotifierProvider<AuthController>.value(value: mockAuth),
            ChangeNotifierProvider<AdminOrderController>(
              create: (_) => AdminOrderController(
                orderRepository: orderRepo,
                authController: mockAuth,
              ),
            ),
          ],
          child: const MaterialApp(home: AdminOrdersView()),
        ),
      );
      await tester.pump();
      expect(find.text('Orders & Fulfillment Center'), findsOneWidget);
      expect(find.textContaining('Total Orders'), findsWidgets);

      // Test Customers screen
      final customerRepo = InMemoryCustomerRepository([
        CustomerModel(
          uid: 'cust-demo',
          fullName: 'Demo Customer',
          email: 'demo@shopease.com',
          role: 'customer',
          createdAt: now,
          updatedAt: now,
        ),
      ]);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthController>.value(value: mockAuth),
            ChangeNotifierProvider<AdminCustomerController>(
              create: (_) => AdminCustomerController(
                customerRepository: customerRepo,
                orderRepository: orderRepo,
                authController: mockAuth,
              ),
            ),
          ],
          child: const MaterialApp(home: AdminCustomersView()),
        ),
      );
      await tester.pump();
      expect(find.text('Customer Accounts Directory'), findsOneWidget);
      expect(find.text('Demo Customer'), findsOneWidget);
    },
  );

  // ── Multi-Customer Account Isolation Tests ─────────────────────────────────

  test(
    'Test 1: Customer A adds items to cart -> Customer B signs in -> Customer B sees empty cart',
    () async {
      final cartRepo = _InMemoryCartRepository();
      final prodRepo = InMemoryProductRepository();
      final p1 = (await prodRepo.getProductById('p1'))!;

      final cartController = CartController(
        cartRepository: cartRepo,
        productRepository: prodRepo,
      );

      // Customer A signs in and adds product p1
      await cartController.syncWithUser('customer-A');
      cartController.addItem(p1, quantity: 2);
      expect(cartController.itemCount, 2);
      expect(cartController.items.first.product.id, 'p1');

      // Customer B signs in with clean session
      cartController.clearUserData();
      await cartController.syncWithUser('customer-B');
      expect(cartController.isEmpty, isTrue);
      expect(cartController.itemCount, 0);
    },
  );

  test(
    'Test 2: Customer A marks product as favourite -> Customer B signs in -> Customer B sees no favourites',
    () async {
      final favRepo = _InMemoryFavoritesRepository();
      final prodRepo = InMemoryProductRepository();
      final homeController = HomeController(
        productRepository: prodRepo,
        favoritesRepository: favRepo,
      );

      // Customer A signs in and adds favorite 'p2'
      await homeController.syncFavoritesWithUser('customer-A');
      expect(homeController.isFavorite('p2'), isFalse);
      homeController.toggleFavorite('p2');
      expect(homeController.isFavorite('p2'), isTrue);

      // Customer B signs in
      homeController.clearUserData();
      await homeController.syncFavoritesWithUser('customer-B');
      expect(homeController.isFavorite('p2'), isFalse);
      expect(homeController.isFavorite('p1'), isFalse);
      expect(homeController.isFavorite('p4'), isFalse);
    },
  );

  test(
    'Test 3: Customer A cart persists independently and restores after sign out and sign in',
    () async {
      final cartRepo = _InMemoryCartRepository();
      final prodRepo = InMemoryProductRepository();
      final p1 = (await prodRepo.getProductById('p1'))!;
      final p3 = (await prodRepo.getProductById('p3'))!;

      final cartController = CartController(
        cartRepository: cartRepo,
        productRepository: prodRepo,
      );

      // Customer A adds p1
      await cartController.syncWithUser('customer-A');
      cartController.addItem(p1, quantity: 1);
      expect(cartController.itemCount, 1);

      // Customer A signs out
      cartController.clearUserData();
      expect(cartController.isEmpty, isTrue);

      // Customer B signs in, adds p3
      await cartController.syncWithUser('customer-B');
      expect(cartController.isEmpty, isTrue);
      cartController.addItem(p3, quantity: 3);
      expect(cartController.itemCount, 3);
      expect(cartController.items.first.product.id, 'p3');

      // Customer B signs out
      cartController.clearUserData();
      expect(cartController.isEmpty, isTrue);

      // Customer A signs back in -> p1 is restored
      await cartController.syncWithUser('customer-A');
      expect(cartController.itemCount, 1);
      expect(cartController.items.first.product.id, 'p1');
    },
  );

  test(
    'Test 4: Switching between accounts clears in-memory state and does not leak stale data',
    () async {
      final cartRepo = _InMemoryCartRepository();
      final prodRepo = InMemoryProductRepository();
      final favRepo = _InMemoryFavoritesRepository();
      final orderRepo = _InMemoryOrderRepository();

      final p1 = (await prodRepo.getProductById('p1'))!;

      final cart = CartController(
        cartRepository: cartRepo,
        productRepository: prodRepo,
      );
      final home = HomeController(
        productRepository: prodRepo,
        favoritesRepository: favRepo,
      );
      final order = OrderController(orderRepository: orderRepo);

      // Customer A logs in and has data
      await cart.syncWithUser('customer-A');
      await home.syncFavoritesWithUser('customer-A');
      await order.loadUserOrders('customer-A');

      cart.addItem(p1, quantity: 2);
      home.toggleFavorite('p1');
      await order.placeOrder(
        items: [OrderItemModel.fromProduct(p1, quantity: 2)],
        subtotal: 3700.0,
        discount: 0.0,
        shippingFee: 0.0,
        total: 3700.0,
        shippingName: 'User A',
        shippingPhone: '1111111111',
        shippingAddress: 'Address A',
        shippingCity: 'City A',
        shippingPostalCode: '1000',
        paymentMethod: 'Card',
        uid: 'customer-A',
      );

      expect(cart.isEmpty, isFalse);
      expect(home.isFavorite('p1'), isTrue);
      expect(order.orders.length, 1);

      // Switch to Customer B: clearUserData must reset all state
      cart.clearUserData();
      home.clearUserData();
      order.clearUserData();

      expect(cart.isEmpty, isTrue);
      expect(home.isFavorite('p1'), isFalse);
      expect(order.orders.isEmpty, isTrue);
      expect(order.currentTrackingOrder, isNull);

      // Customer B syncs
      await cart.syncWithUser('customer-B');
      await home.syncFavoritesWithUser('customer-B');
      await order.loadUserOrders('customer-B');

      expect(cart.isEmpty, isTrue);
      expect(home.isFavorite('p1'), isFalse);
      expect(order.orders.isEmpty, isTrue);
    },
  );

  test(
    'Test 5: Checkout creates an order associated with the authenticated user UID',
    () async {
      final orderRepo = _InMemoryOrderRepository();
      final orderController = OrderController(orderRepository: orderRepo);
      final prodRepo = InMemoryProductRepository();
      final p2 = (await prodRepo.getProductById('p2'))!;

      await orderController.loadUserOrders('customer-authenticated-123');
      expect(orderController.orders.isEmpty, isTrue);

      final order = await orderController.placeOrder(
        items: [OrderItemModel.fromProduct(p2, quantity: 1)],
        subtotal: 2150.0,
        discount: 0.0,
        shippingFee: 0.0,
        total: 2150.0,
        shippingName: 'Authenticated User',
        shippingPhone: '+91 9999999999',
        shippingAddress: '789 Luxury Way',
        shippingCity: 'Bengaluru',
        shippingPostalCode: '560001',
        paymentMethod: 'Credit Card',
        uid: 'customer-authenticated-123',
      );

      expect(order.customerId, 'customer-authenticated-123');
      expect(
        orderController.orders.first.customerId,
        'customer-authenticated-123',
      );

      // Verify in repository under user's UID
      final savedOrders = await orderRepo.getOrders(
        'customer-authenticated-123',
      );
      expect(savedOrders.length, 1);
      expect(savedOrders.first.id, order.id);
      expect(savedOrders.first.customerId, 'customer-authenticated-123');

      // Verify another user cannot see this order
      final otherUserOrders = await orderRepo.getOrders('customer-other-456');
      expect(otherUserOrders.isEmpty, isTrue);
    },
  );

  test(
    'Test 6: Placing an order clears only the purchasing customer cart, leaving others intact',
    () async {
      final cartRepo = _InMemoryCartRepository();
      final orderRepo = _InMemoryOrderRepository();
      final prodRepo = InMemoryProductRepository();

      final p1 = (await prodRepo.getProductById('p1'))!;
      final p2 = (await prodRepo.getProductById('p2'))!;

      final cartA = CartController(
        cartRepository: cartRepo,
        productRepository: prodRepo,
      );
      final cartB = CartController(
        cartRepository: cartRepo,
        productRepository: prodRepo,
      );
      final orderController = OrderController(orderRepository: orderRepo);

      // Customer A adds p1
      await cartA.syncWithUser('customer-A');
      cartA.addItem(p1, quantity: 1);
      expect(cartA.itemCount, 1);

      // Customer B adds p2
      await cartB.syncWithUser('customer-B');
      cartB.addItem(p2, quantity: 2);
      expect(cartB.itemCount, 2);

      // Customer A places order and clears their cart
      final orderA = await orderController.placeOrder(
        items: cartA.items
            .map(
              (i) =>
                  OrderItemModel.fromProduct(i.product, quantity: i.quantity),
            )
            .toList(),
        subtotal: cartA.subtotal,
        discount: cartA.discountAmount,
        shippingFee: 0.0,
        total: cartA.totalPrice,
        shippingName: 'Customer A',
        shippingPhone: '111',
        shippingAddress: 'Street A',
        shippingCity: 'City A',
        shippingPostalCode: '1000',
        paymentMethod: 'Card',
        uid: 'customer-A',
      );
      cartA.clearCart();

      expect(cartA.isEmpty, isTrue);
      expect(orderA.customerId, 'customer-A');

      // Verify Customer B's cart in memory and in repo remains intact
      expect(cartB.itemCount, 2);
      expect(cartB.items.first.product.id, 'p2');

      final savedItemsB = await cartRepo.getCartItems('customer-B', prodRepo);
      expect(savedItemsB.length, 1);
      expect(savedItemsB.first.product.id, 'p2');
      expect(savedItemsB.first.quantity, 2);

      // Verify Customer A's cart in repo is empty
      final savedItemsA = await cartRepo.getCartItems('customer-A', prodRepo);
      expect(savedItemsA.isEmpty, isTrue);
    },
  );

  // ── Stage 2: Admin Product Management Tests ───────────────────────────────

  test(
    'Stage 2: Product creation validates required fields and non-negative price/stock',
    () async {
      final productRepo = InMemoryProductRepository();
      final adminController = AdminProductController(
        productRepository: productRepo,
      );
      await adminController.loadProducts();

      final initialCount = adminController.totalProductCount;

      // 1. Empty name should fail validation
      final emptyNameProduct = ProductModel(
        id: 'test-p1',
        name: '   ',
        description: 'Valid description',
        price: 1500.0,
        stockQuantity: 10,
        categoryId: 'blush',
        categoryName: 'Blush & Cheeks',
      );
      final failEmptyName = await adminController.saveProduct(emptyNameProduct);
      expect(failEmptyName, isFalse);
      expect(
        adminController.errorMessage,
        contains('Product name is required'),
      );

      // 2. Zero or negative price should fail validation
      final negativePriceProduct = ProductModel(
        id: 'test-p2',
        name: 'Luxury Foundation',
        description: 'Valid description',
        price: -50.0,
        stockQuantity: 10,
        categoryId: 'face',
        categoryName: 'Face & Glow',
      );
      final failNegativePrice = await adminController.saveProduct(
        negativePriceProduct,
      );
      expect(failNegativePrice, isFalse);
      expect(
        adminController.errorMessage,
        contains('Price must be a positive number'),
      );

      // 3. Negative stock should fail validation
      final negativeStockProduct = ProductModel(
        id: 'test-p3',
        name: 'Velvet Lipstick',
        description: 'Valid description',
        price: 1200.0,
        stockQuantity: -5,
        categoryId: 'lips',
        categoryName: 'Lips',
      );
      final failNegativeStock = await adminController.saveProduct(
        negativeStockProduct,
      );
      expect(failNegativeStock, isFalse);
      expect(
        adminController.errorMessage,
        contains('Stock quantity cannot be negative'),
      );

      // 4. Valid product creation succeeds
      final validProduct = ProductModel(
        id: 'test-valid-1',
        name: 'Luminous Glow Serum',
        brand: 'AÈRA',
        description:
            'Hydrating radiant skin serum with hyaluronic acid and niacinamide.',
        price: 2450.0,
        originalPrice: 2800.0,
        stockQuantity: 15,
        categoryId: 'skincare',
        categoryName: 'Skincare',
        isFeatured: true,
        isAvailable: true,
        imageUrl: 'Assest/The Viral Blush Beauty Lovers Are Obsessed With.jpeg',
      );
      final success = await adminController.saveProduct(validProduct);
      expect(success, isTrue);
      expect(adminController.totalProductCount, initialCount + 1);
      expect(adminController.products.first.id, 'test-valid-1');
      expect(adminController.successMessage, contains('Luminous Glow Serum'));
    },
  );

  test(
    'Stage 2: Product editing updates attributes while preserving existing unedited fields',
    () async {
      final productRepo = InMemoryProductRepository();
      final adminController = AdminProductController(
        productRepository: productRepo,
      );
      await adminController.loadProducts();

      final original = (await productRepo.getProductById('p1'))!;
      expect(original.name, 'Soft Pinch Liquid Blush');
      expect(original.rating, 4.9);
      expect(original.reviewCount, 384);
      expect(original.visualIcon, Icons.favorite_rounded);

      // Edit price, stock, and description
      final updated = original.copyWith(
        price: 1999.0,
        stockQuantity: 42,
        description: 'Updated formula with ultra-fine botanical pearls.',
      );

      final success = await adminController.saveProduct(
        updated,
        isEditing: true,
      );
      expect(success, isTrue);

      final saved = (await productRepo.getProductById('p1'))!;
      expect(saved.price, 1999.0);
      expect(saved.stockQuantity, 42);
      expect(
        saved.description,
        'Updated formula with ultra-fine botanical pearls.',
      );
      // Preserved unedited fields
      expect(saved.rating, 4.9);
      expect(saved.reviewCount, 384);
      expect(saved.visualIcon, Icons.favorite_rounded);
      expect(saved.categoryId, original.categoryId);
    },
  );

  test(
    'Stage 2: Product deletion removes product and handles failures cleanly',
    () async {
      final productRepo = InMemoryProductRepository();
      final adminController = AdminProductController(
        productRepository: productRepo,
      );
      await adminController.loadProducts();

      final initialCount = adminController.totalProductCount;
      expect(adminController.products.any((p) => p.id == 'p2'), isTrue);

      // Delete product p2
      final success = await adminController.deleteProduct('p2');
      expect(success, isTrue);
      expect(adminController.totalProductCount, initialCount - 1);
      expect(adminController.products.any((p) => p.id == 'p2'), isFalse);
      expect(await productRepo.getProductById('p2'), isNull);
    },
  );

  test(
    'Stage 2: Search and category/stock filtering correctly filter catalog items',
    () async {
      final productRepo = InMemoryProductRepository();
      final adminController = AdminProductController(
        productRepository: productRepo,
      );
      await adminController.loadProducts();

      expect(adminController.filteredProducts.length, 10);

      // 1. Search by product name
      adminController.setSearchQuery('Soft Pinch');
      expect(adminController.filteredProducts.length, 1);
      expect(
        adminController.filteredProducts.first.name,
        'Soft Pinch Liquid Blush',
      );

      // Clear search
      adminController.setSearchQuery('');
      expect(adminController.filteredProducts.length, 10);

      // 2. Filter by category
      adminController.selectCategory('lips');
      for (final p in adminController.filteredProducts) {
        expect(p.categoryId, 'lips');
      }
      expect(adminController.filteredProducts.isNotEmpty, isTrue);

      // Reset category
      adminController.selectCategory('all');
      expect(adminController.filteredProducts.length, 10);

      // 3. Filter by stock status
      adminController.setStockFilter('in_stock');
      for (final p in adminController.filteredProducts) {
        expect(p.isAvailable && p.stockQuantity > 0, isTrue);
      }
    },
  );

  test(
    'Stage 2: Stock adjustments and availability toggles update product inventory and active status',
    () async {
      final productRepo = InMemoryProductRepository();
      final adminController = AdminProductController(
        productRepository: productRepo,
      );
      await adminController.loadProducts();

      final target = (await productRepo.getProductById('p1'))!;
      expect(target.isAvailable, isTrue);

      // Toggle availability (deactivate/archive)
      await adminController.toggleAvailability(target);
      var updated = (await productRepo.getProductById('p1'))!;
      expect(updated.isAvailable, isFalse);

      // Toggle back
      await adminController.toggleAvailability(updated);
      updated = (await productRepo.getProductById('p1'))!;
      expect(updated.isAvailable, isTrue);

      // Update stock quantity
      await adminController.updateStockQuantity(updated, 75);
      updated = (await productRepo.getProductById('p1'))!;
      expect(updated.stockQuantity, 75);

      // Reject negative stock adjustment
      final rejectNegative = await adminController.updateStockQuantity(
        updated,
        -10,
      );
      expect(rejectNegative, isFalse);
      expect(
        adminController.errorMessage,
        contains('Stock cannot be negative'),
      );
    },
  );

  testWidgets(
    'Stage 2: AdminGuard prevents unauthorized non-admin customers from accessing AdminProductsView',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final now = DateTime.now();
      final customerProfile = CustomerModel(
        uid: 'customer-unauth-1',
        fullName: 'Regular Customer',
        email: 'customer@shopease.com',
        role: 'customer',
        createdAt: now,
        updatedAt: now,
      );
      final mockCustomerAuth = _TestAuthController(
        isAuthenticated: true,
        isAdmin: false,
        profile: customerProfile,
      );
      final productRepo = InMemoryProductRepository();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<ProductRepository>.value(value: productRepo),
            ChangeNotifierProvider<AuthController>.value(
              value: mockCustomerAuth,
            ),
            ChangeNotifierProvider<AdminProductController>(
              create: (_) =>
                  AdminProductController(productRepository: productRepo),
            ),
          ],
          child: const MaterialApp(
            home: AdminGuard(child: AdminProductsView()),
          ),
        ),
      );
      await tester.pump();

      // Verify AdminGuard displays Access Restricted screen to standard customer
      expect(find.text('Access Restricted'), findsOneWidget);
      expect(find.text('Product Catalog & Inventory'), findsNothing);
    },
  );

  // ── Stage 3: Admin Order Management & Fulfillment Tests ────────────────────

  test(
    'Stage 3: Loading and displaying cross-customer orders with KPIs',
    () async {
      final orderRepo = InMemoryOrderRepository(seedSampleData: true);
      final mockAdmin = _TestAuthController(isAdmin: true);
      final controller = AdminOrderController(
        orderRepository: orderRepo,
        authController: mockAdmin,
      );

      await controller.loadOrders();

      expect(controller.totalOrdersCount, 3);
      expect(controller.allOrders.length, 3);
      expect(controller.totalRevenue, 15100.0); // 4800 + 6250 + 4050
      expect(controller.pendingFulfillmentCount, 1); // order1 (placed)
      expect(controller.inTransitCount, 1); // order2 (shipped)
      expect(controller.deliveredCount, 1); // order3 (delivered)
    },
  );

  test('Stage 3: Searching and filtering cross-customer orders', () async {
    final orderRepo = InMemoryOrderRepository(seedSampleData: true);
    final mockAdmin = _TestAuthController(isAdmin: true);
    final controller = AdminOrderController(
      orderRepository: orderRepo,
      authController: mockAdmin,
    );
    await controller.loadOrders();

    // 1. Search by customer name
    controller.setSearchQuery('Priya');
    expect(controller.filteredOrders.length, 1);
    expect(controller.filteredOrders.first.shippingName, 'Priya Patel');

    // 2. Search by order ID
    controller.setSearchQuery('ORD-719401');
    expect(controller.filteredOrders.length, 1);
    expect(controller.filteredOrders.first.id, 'ORD-719401');

    // 3. Clear search and filter by status
    controller.setSearchQuery('');
    controller.setStatusFilter(OrderProgressStatus.delivered);
    expect(controller.filteredOrders.length, 1);
    expect(controller.filteredOrders.first.shippingCity, 'Kolkata');

    // 4. Filter by payment status
    controller.setStatusFilter(null);
    controller.setPaymentStatusFilter('Paid');
    expect(controller.filteredOrders.length, 3);

    // 5. Reset filters
    controller.clearFilters();
    expect(controller.filteredOrders.length, 3);
  });

  test(
    'Stage 3: Preserving historical item snapshots and pricing integrity',
    () async {
      final orderRepo = InMemoryOrderRepository(seedSampleData: true);
      final orders = await orderRepo.getAllOrders();
      final order = orders.firstWhere((o) => o.id == 'ORD-719401');

      expect(order.items.length, 1);
      final item = order.items.first;
      expect(item.productName, 'Rare Beauty Soft Pinch Liquid Blush');
      expect(item.price, 2400.0);
      expect(item.quantity, 2);
      expect(item.totalPrice, 4800.0);
      expect(order.total, 4800.0);
    },
  );

  test(
    'Stage 3: Valid and invalid status transitions with audit tracking',
    () async {
      final now = DateTime.now();
      final adminUser = CustomerModel(
        uid: 'admin-auditor',
        fullName: 'Auditor Admin',
        email: 'auditor@shopease.com',
        role: 'admin',
        createdAt: now,
        updatedAt: now,
      );
      final orderRepo = InMemoryOrderRepository(seedSampleData: true);
      final mockAdmin = _TestAuthController(isAdmin: true, profile: adminUser);
      final controller = AdminOrderController(
        orderRepository: orderRepo,
        authController: mockAdmin,
      );
      await controller.loadOrders();

      final order = controller.allOrders.firstWhere(
        (o) => o.id == 'ORD-719401',
      );
      expect(order.status, OrderProgressStatus.placed);

      // 1. Invalid forward transition: placed -> delivered is not allowed directly
      final invalidJump = await controller.updateOrderStatus(
        order,
        OrderProgressStatus.delivered,
      );
      expect(invalidJump, isFalse);
      expect(controller.errorMessage, contains('Cannot transition'));

      // 2. Valid transition: placed -> processing
      final step1 = await controller.updateOrderStatus(
        order,
        OrderProgressStatus.processing,
        note: 'Items picked and sent for luxury wrapping',
      );
      expect(step1, isTrue);

      final updated = controller.allOrders.firstWhere(
        (o) => o.id == 'ORD-719401',
      );
      expect(updated.status, OrderProgressStatus.processing);
      expect(updated.updatedBy, 'admin-auditor');
      expect(updated.statusHistory.length, 1);
      expect(
        updated.statusHistory.first.note,
        'Items picked and sent for luxury wrapping',
      );

      // 3. Consequential cancellation before delivery: processing -> cancelled
      final cancel = await controller.updateOrderStatus(
        updated,
        OrderProgressStatus.cancelled,
        note: 'Customer requested order cancellation',
      );
      expect(cancel, isTrue);

      final cancelledOrder = controller.allOrders.firstWhere(
        (o) => o.id == 'ORD-719401',
      );
      expect(cancelledOrder.status, OrderProgressStatus.cancelled);
      expect(
        cancelledOrder.cancelReason,
        'Customer requested order cancellation',
      );

      // 4. Terminal state: cancelled orders cannot transition
      final resumeAttempt = await controller.updateOrderStatus(
        cancelledOrder,
        OrderProgressStatus.processing,
      );
      expect(resumeAttempt, isFalse);
    },
  );

  test(
    'Stage 3: Customer isolation vs Admin cross-customer order visibility',
    () async {
      final orderRepo = InMemoryOrderRepository(seedSampleData: true);

      // Customer Aarav Sharma reads only their own order
      final sharmaOrders = await orderRepo.getOrders('cust-sharma');
      expect(sharmaOrders.length, 1);
      expect(sharmaOrders.first.shippingName, 'Aarav Sharma');

      // Customer Priya Patel reads only their own order
      final priyaOrders = await orderRepo.getOrders('cust-priya');
      expect(priyaOrders.length, 1);
      expect(priyaOrders.first.shippingName, 'Priya Patel');

      // Admin reads all orders across all customers
      final adminOrders = await orderRepo.getAllOrders();
      expect(adminOrders.length, 3);
    },
  );

  test(
    'Stage 3: Customer order tracking reflects fulfillment status changes',
    () async {
      final orderRepo = InMemoryOrderRepository(seedSampleData: true);
      final customerOrderController = OrderController(
        orderRepository: orderRepo,
      );

      // Customer loads their orders
      await customerOrderController.loadUserOrders('cust-sharma');
      expect(customerOrderController.orders.length, 1);
      expect(
        customerOrderController.currentTrackingOrder?.status,
        OrderProgressStatus.placed,
      );

      // Admin updates status in repository to processing
      await orderRepo.updateOrderStatus(
        'cust-sharma',
        'ORD-719401',
        OrderProgressStatus.processing,
        adminId: 'admin-99',
        note: 'Package packed',
      );

      // Customer refreshes orders
      await customerOrderController.refreshOrders();
      expect(
        customerOrderController.currentTrackingOrder?.status,
        OrderProgressStatus.processing,
      );
    },
  );

  testWidgets(
    'Stage 3: AdminGuard prevents unauthorized non-admin customers from accessing AdminOrdersView',
    (WidgetTester tester) async {
      final now = DateTime.now();
      final customerProfile = CustomerModel(
        uid: 'customer-user-2',
        fullName: 'Regular Customer',
        email: 'customer@example.com',
        role: 'customer',
        createdAt: now,
        updatedAt: now,
      );
      final mockCustomerAuth = _TestAuthController(
        isAuthenticated: true,
        isAdmin: false,
        profile: customerProfile,
      );
      final orderRepo = InMemoryOrderRepository(seedSampleData: true);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<OrderRepository>.value(value: orderRepo),
            ChangeNotifierProvider<AuthController>.value(
              value: mockCustomerAuth,
            ),
            ChangeNotifierProvider<AdminOrderController>(
              create: (_) => AdminOrderController(
                orderRepository: orderRepo,
                authController: mockCustomerAuth,
              ),
            ),
          ],
          child: const MaterialApp(home: AdminGuard(child: AdminOrdersView())),
        ),
      );
      await tester.pump();

      // Verify access is blocked
      expect(find.text('Access Restricted'), findsOneWidget);
      expect(find.text('Orders & Fulfillment Center'), findsNothing);
    },
  );

  testWidgets(
    'Stage 3: AdminOrdersView renders desktop table and opens OrderDetailsDialog',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final now = DateTime.now();
      final adminProfile = CustomerModel(
        uid: 'admin-master',
        fullName: 'Head Administrator',
        email: 'admin@shopease.com',
        role: 'admin',
        createdAt: now,
        updatedAt: now,
      );
      final mockAdmin = _TestAuthController(
        isAuthenticated: true,
        isAdmin: true,
        profile: adminProfile,
      );
      final orderRepo = InMemoryOrderRepository(seedSampleData: true);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<OrderRepository>.value(value: orderRepo),
            ChangeNotifierProvider<AuthController>.value(value: mockAdmin),
            ChangeNotifierProvider<AdminOrderController>(
              create: (_) => AdminOrderController(
                orderRepository: orderRepo,
                authController: mockAdmin,
              ),
            ),
          ],
          child: const MaterialApp(home: AdminOrdersView()),
        ),
      );
      await tester.pump();

      // Verify Orders view header, KPIs and table rendered
      expect(find.text('Orders & Fulfillment Center'), findsOneWidget);
      expect(find.text('Total Orders'), findsOneWidget);
      expect(find.text('Total Revenue'), findsOneWidget);
      expect(find.text('Aarav Sharma'), findsOneWidget);

      // Pump OrderDetailsDialog to verify full order inspection and fulfillment actions
      final sampleOrder = (await orderRepo.getAllOrders()).first;
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<OrderRepository>.value(value: orderRepo),
            ChangeNotifierProvider<AuthController>.value(value: mockAdmin),
            ChangeNotifierProvider<AdminOrderController>(
              create: (_) => AdminOrderController(
                orderRepository: orderRepo,
                authController: mockAdmin,
              ),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(body: OrderDetailsDialog(order: sampleOrder)),
          ),
        ),
      );
      await tester.pump();

      // Verify OrderDetailsDialog displays complete snapshot, customer info, audit history, and cancellation action
      expect(find.text('Purchased Items Snapshot'), findsOneWidget);
      expect(find.text('Customer & Shipping'), findsOneWidget);
      expect(find.text('Audit Trail & Fulfillment History'), findsOneWidget);
      expect(find.text('Cancel Order'), findsOneWidget);
      expect(find.text('Rare Beauty Soft Pinch Liquid Blush'), findsOneWidget);
    },
  );
}

class _InMemoryCartRepository implements CartRepository {
  final Map<String, Map<String, CartItem>> _userCarts = {};

  @override
  Future<List<CartItem>> getCartItems(
    String uid,
    ProductRepository productRepo,
  ) async {
    return _userCarts[uid]?.values.toList() ?? [];
  }

  @override
  Future<void> saveCartItem(String uid, CartItem item) async {
    _userCarts.putIfAbsent(uid, () => {})[item.cartKey] = item;
  }

  @override
  Future<void> removeCartItem(String uid, String cartKey) async {
    _userCarts[uid]?.remove(cartKey);
  }

  @override
  Future<void> clearCart(String uid) async {
    _userCarts[uid]?.clear();
  }
}

class _InMemoryFavoritesRepository implements FavoritesRepository {
  final Map<String, Set<String>> _userFavorites = {};

  @override
  Future<Set<String>> getFavorites(String uid) async {
    return Set<String>.from(_userFavorites[uid] ?? {});
  }

  @override
  Future<void> addFavorite(
    String uid,
    String productId, {
    Map<String, dynamic>? extraData,
  }) async {
    _userFavorites.putIfAbsent(uid, () => {}).add(productId);
  }

  @override
  Future<void> removeFavorite(String uid, String productId) async {
    _userFavorites[uid]?.remove(productId);
  }
}

class _InMemoryOrderRepository implements OrderRepository {
  final Map<String, List<OrderModel>> _userOrders = {};

  @override
  Future<void> createOrder(String uid, OrderModel order) async {
    _userOrders.putIfAbsent(uid, () => []).insert(0, order);
  }

  @override
  Future<List<OrderModel>> getOrders(String uid) async {
    return List<OrderModel>.from(_userOrders[uid] ?? []);
  }

  @override
  Future<List<OrderModel>> getAllOrders() async {
    final all = <OrderModel>[];
    for (final list in _userOrders.values) {
      all.addAll(list);
    }
    all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return all;
  }

  @override
  Future<void> updateOrderStatus(
    String uid,
    String orderId,
    OrderProgressStatus status, {
    String? adminId,
    String? note,
  }) async {
    final entry = OrderStatusHistoryEntry(
      status: status,
      timestamp: DateTime.now(),
      note: note,
      updatedBy: adminId,
    );
    final list = _userOrders[uid];
    if (list != null) {
      final index = list.indexWhere((o) => o.id == orderId);
      if (index != -1) {
        final o = list[index];
        final history = List<OrderStatusHistoryEntry>.from(o.statusHistory)
          ..add(entry);
        list[index] = o.copyWith(
          status: status,
          updatedAt: DateTime.now(),
          updatedBy: adminId,
          statusHistory: history,
        );
      }
    }
  }

  @override
  Future<String?> findCustomerUidForOrder(String orderId) async {
    for (final entry in _userOrders.entries) {
      if (entry.value.any((o) => o.id == orderId)) {
        return entry.key;
      }
    }
    return null;
  }
}

/// Helper test implementation of [AuthController] to test role states deterministically.
class _TestAuthController extends AuthController {
  final bool _testIsAuthenticated;
  final bool _testIsAdmin;
  final CustomerModel? _testProfile;
  final bool _testNeedsProfileCompletion;
  final bool _testSignInSuccess;

  _TestAuthController({
    bool isAuthenticated = false,
    bool isAdmin = false,
    CustomerModel? profile,
    bool needsProfileCompletion = false,
    bool signInSuccess = true,
  }) : _testIsAuthenticated = isAuthenticated,
       _testIsAdmin = isAdmin,
       _testProfile = profile,
       _testNeedsProfileCompletion = needsProfileCompletion,
       _testSignInSuccess = signInSuccess;

  @override
  bool get isAuthenticated => _testIsAuthenticated;

  @override
  bool get isAdmin => _testIsAdmin;

  @override
  CustomerModel? get customerProfile => _testProfile;

  @override
  bool get needsProfileCompletion => _testNeedsProfileCompletion;

  @override
  String get postLoginRoute =>
      isAdmin ? AppRoutes.adminDashboard : AppRoutes.customerHome;

  @override
  Future<bool> signIn({required String email, required String password}) async {
    return _testSignInSuccess;
  }
}

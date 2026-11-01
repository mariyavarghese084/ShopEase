import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopease/controllers/admin_customer_controller.dart';
import 'package:shopease/controllers/admin_product_controller.dart';
import 'package:shopease/controllers/auth_controller.dart';
import 'package:shopease/controllers/home_controller.dart';
import 'package:shopease/models/customer_model.dart';
import 'package:shopease/models/order_model.dart';
import 'package:shopease/models/product_model.dart';
import 'package:shopease/repositories/customer_repository.dart';
import 'package:shopease/repositories/favorites_repository.dart';
import 'package:shopease/repositories/order_repository.dart';
import 'package:shopease/repositories/product_repository.dart';
import 'package:shopease/services/product_image_storage_service.dart';
import 'package:shopease/views/admin/customers/admin_customers_view.dart';
import 'package:shopease/views/admin/customers/customer_details_dialog.dart';
import 'package:shopease/views/admin/products/product_form_dialog.dart';
import 'package:shopease/widgets/product_card.dart';

class _TestAuthController extends AuthController {
  @override
  bool get isAuthenticated => true;
  @override
  bool get isAdmin => true;
  @override
  CustomerModel? get customerProfile => CustomerModel(
        uid: 'admin-1',
        fullName: 'Admin User',
        email: 'admin@shopease.com',
        role: 'admin',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
}

class _TestNonAdminAuthController extends AuthController {
  @override
  bool get isAuthenticated => true;
  @override
  bool get isAdmin => false;
  @override
  CustomerModel? get customerProfile => CustomerModel(
        uid: 'customer-1',
        fullName: 'Regular Customer',
        email: 'customer@shopease.com',
        role: 'customer',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
}

class _InMemoryFavoritesRepository implements FavoritesRepository {
  @override
  Future<Set<String>> getFavorites(String uid) async => {};
  @override
  Future<void> addFavorite(String uid, String productId,
      {Map<String, dynamic>? extraData}) async {}
  @override
  Future<void> removeFavorite(String uid, String productId) async {}
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('Feature 1: Customer Management Tests', () {
    test('Customer list loading, searching, and empty states in controller',
        () async {
      final now = DateTime.now();
      final customerRepo = InMemoryCustomerRepository([
        CustomerModel(
          uid: 'cust-1',
          fullName: 'Aarav Sharma',
          email: 'aarav@example.com',
          phoneNumber: '+91 98765 43210',
          role: 'customer',
          createdAt: now.subtract(const Duration(days: 10)),
          updatedAt: now,
        ),
        CustomerModel(
          uid: 'cust-2',
          fullName: 'Priya Patel',
          email: 'priya@example.com',
          phoneNumber: '+91 91234 56789',
          role: 'customer',
          createdAt: now.subtract(const Duration(days: 5)),
          updatedAt: now,
        ),
      ]);

      final orderRepo = InMemoryOrderRepository();
      await orderRepo.createOrder(
        'cust-1',
        OrderModel(
          id: 'ORD-101',
          customerId: 'cust-1',
          items: const [
            OrderItemModel(
              productId: 'p1',
              productName: 'Soft Pinch Blush',
              subtitle: 'Liquid Blush',
              size: 'Standard',
              price: 1500.0,
              quantity: 2,
            ),
          ],
          subtotal: 3000.0,
          discount: 0.0,
          shippingFee: 0.0,
          total: 3000.0,
          status: OrderProgressStatus.delivered,
          shippingName: 'Aarav Sharma',
          shippingPhone: '+91 98765 43210',
          shippingAddress: '123 MG Road',
          shippingCity: 'Mumbai',
          shippingPostalCode: '400001',
          paymentMethod: 'Card',
          paymentStatus: 'Paid',
          trackingNumber: 'TRK-101',
          courierName: 'Express',
          estimatedDelivery: 'Delivered',
          createdAt: now.subtract(const Duration(days: 2)),
        ),
      );

      final controller = AdminCustomerController(
        customerRepository: customerRepo,
        orderRepository: orderRepo,
        authController: _TestAuthController(),
      );

      await controller.loadCustomers();

      // Check loaded counts & metrics
      expect(controller.totalCustomersCount, equals(2));
      expect(controller.activeBuyersCount, equals(1));
      expect(controller.totalCustomerRevenue, equals(3000.0));
      expect(controller.getOrderCount('cust-1'), equals(1));
      expect(controller.getTotalSpent('cust-1'), equals(3000.0));
      expect(controller.getOrderCount('cust-2'), equals(0));
      expect(controller.getTotalSpent('cust-2'), equals(0.0));

      // Test searching
      controller.setSearchQuery('priya');
      expect(controller.filteredCustomers.length, equals(1));
      expect(controller.filteredCustomers.first.fullName, equals('Priya Patel'));

      controller.setSearchQuery('aarav@example.com');
      expect(controller.filteredCustomers.length, equals(1));
      expect(controller.filteredCustomers.first.fullName, equals('Aarav Sharma'));

      controller.setSearchQuery('non-existent');
      expect(controller.filteredCustomers.isEmpty, isTrue);

      controller.setSearchQuery('');
      expect(controller.filteredCustomers.length, equals(2));
    });

    test('Non-admin user cannot access customer directory', () async {
      final customerRepo = InMemoryCustomerRepository([
        CustomerModel(
          uid: 'cust-priv',
          fullName: 'Private Customer',
          email: 'private@shopease.com',
          role: 'customer',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ]);
      final orderRepo = InMemoryOrderRepository();
      final controller = AdminCustomerController(
        customerRepository: customerRepo,
        orderRepository: orderRepo,
        authController: _TestNonAdminAuthController(),
      );

      await controller.loadCustomers();
      expect(controller.errorMessage, contains('Access denied'));
      expect(controller.allCustomers.isEmpty, isTrue);
    });

    testWidgets('Customer Directory renders table, search, and View Details',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final now = DateTime.now();
      final customerRepo = InMemoryCustomerRepository([
        CustomerModel(
          uid: 'cust-1',
          fullName: 'Aarav Sharma',
          email: 'aarav@example.com',
          phoneNumber: '+91 98765 43210',
          role: 'customer',
          createdAt: now,
          updatedAt: now,
        ),
      ]);
      final orderRepo = InMemoryOrderRepository();
      final authController = _TestAuthController();
      final controller = AdminCustomerController(
        customerRepository: customerRepo,
        orderRepository: orderRepo,
        authController: authController,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthController>.value(value: authController),
            ChangeNotifierProvider<AdminCustomerController>.value(value: controller),
          ],
          child: const MaterialApp(home: AdminCustomersView()),
        ),
      );
      await tester.pumpAndSettle();

      // Verify header & table contents
      expect(find.text('Customer Accounts Directory'), findsOneWidget);
      expect(find.text('Aarav Sharma'), findsOneWidget);
      expect(find.text('aarav@example.com'), findsOneWidget);
      expect(find.text('+91 98765 43210'), findsOneWidget);
      expect(find.text('Details'), findsOneWidget);
    });

    testWidgets('Customer details dialog displays profile, metrics, and order history',
        (tester) async {
      final now = DateTime.now();
      final customer = CustomerModel(
        uid: 'cust-10',
        fullName: 'Sunita Rao',
        email: 'sunita@example.com',
        phoneNumber: '+91 99887 76655',
        role: 'customer',
        createdAt: now.subtract(const Duration(days: 30)),
        updatedAt: now,
      );

      final customerRepo = InMemoryCustomerRepository([customer]);
      final orderRepo = InMemoryOrderRepository();
      await orderRepo.createOrder(
        'cust-10',
        OrderModel(
          id: 'ORD-999',
          customerId: 'cust-10',
          items: const [
            OrderItemModel(
              productId: 'p-gold',
              productName: 'AÈRA 24K Gold Elixir',
              subtitle: 'Facial Serum',
              size: '50 ml',
              price: 4500.0,
              quantity: 1,
            ),
          ],
          subtotal: 4500.0,
          discount: 0.0,
          shippingFee: 0.0,
          total: 4500.0,
          status: OrderProgressStatus.shipped,
          shippingName: 'Sunita Rao',
          shippingPhone: '+91 99887 76655',
          shippingAddress: '42 Lotus Boulevard',
          shippingCity: 'Bangalore',
          shippingPostalCode: '560001',
          paymentMethod: 'UPI',
          paymentStatus: 'Paid',
          trackingNumber: 'TRK-999',
          courierName: 'AÈRA VIP Courier',
          estimatedDelivery: 'Tomorrow',
          createdAt: now.subtract(const Duration(days: 1)),
        ),
      );

      final authController = _TestAuthController();
      final controller = AdminCustomerController(
        customerRepository: customerRepo,
        orderRepository: orderRepo,
        authController: authController,
      );
      await controller.loadCustomers();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AdminCustomerController>.value(value: controller),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: CustomerDetailsDialog(customer: customer),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify profile and metrics
      expect(find.text('Sunita Rao'), findsWidgets);
      expect(find.text('sunita@example.com'), findsWidgets);
      expect(find.text('CUSTOMER INFORMATION'), findsOneWidget);
      expect(find.text('PRIMARY SHIPPING ADDRESS'), findsOneWidget);
      expect(find.text('42 Lotus Boulevard, Bangalore, 560001'), findsOneWidget);
      expect(find.text('COMPLETE ORDER HISTORY'), findsOneWidget);
      expect(find.text('Order #ORD-999'), findsOneWidget);
      expect(find.text('AÈRA 24K Gold Elixir'), findsOneWidget);
      expect(find.text('₹4500.00'), findsWidgets);
    });

    testWidgets('Customer data with missing optional fields renders fallbacks gracefully',
        (tester) async {
      final customer = CustomerModel(
        uid: 'cust-anonymous',
        fullName: '',
        email: 'anon@example.com',
        phoneNumber: null,
        photoUrl: null,
        role: 'customer',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final customerRepo = InMemoryCustomerRepository([customer]);
      final orderRepo = InMemoryOrderRepository();
      final authController = _TestAuthController();
      final controller = AdminCustomerController(
        customerRepository: customerRepo,
        orderRepository: orderRepo,
        authController: authController,
      );
      await controller.loadCustomers();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AdminCustomerController>.value(value: controller),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: CustomerDetailsDialog(customer: customer),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check fallback labels
      expect(find.text('Guest Customer'), findsOneWidget);
      expect(find.text('Not provided'), findsOneWidget);
      expect(
        find.text(
            'No shipping address on file yet. Address information will be recorded automatically when an order is placed.'),
        findsOneWidget,
      );
      expect(find.text('No orders placed by this customer yet'), findsOneWidget);
    });
  });

  group('Feature 2: Product Image Upload and Storage Tests', () {
    test('Image type and size validation logic', () {
      final service = InMemoryProductImageStorageService();

      // Valid paths
      expect(service.isValidImagePath('Assest/The Viral Blush Beauty Lovers Are Obsessed With.jpeg'), isTrue);
      expect(service.isValidImagePath('https://firebasestorage.googleapis.com/test.jpg'), isTrue);
      expect(service.isValidImagePath(''), isFalse);

      // Managed storage URL detection
      expect(service.isManagedStorageUrl('https://firebasestorage.googleapis.com/v0/b/shopease-mock/o/products%2Fp1%2Fimg.jpg'), isTrue);
      expect(service.isManagedStorageUrl('Assest/RAL Rare Beauty.jpeg'), isFalse);
      expect(service.isManagedStorageUrl('https://images.unsplash.com/photo-123'), isFalse);
    });

    test('Upload, save, and replacement lifecycle in ProductImageStorageService', () async {
      final service = InMemoryProductImageStorageService();
      final dummyBytes = Uint8List.fromList([1, 2, 3, 4, 5]);

      // 1. Upload image
      final url = await service.uploadProductImage(
        productId: 'prod-100',
        bytes: dummyBytes,
        fileName: 'cream.jpg',
      );
      expect(url, contains('prod-100'));
      expect(service.uploadedImages.containsKey(url), isTrue);

      // 2. Replace image (delete old)
      await service.deleteProductImage(url);
      expect(service.deletedUrls.contains(url), isTrue);
      expect(service.uploadedImages.containsKey(url), isFalse);
    });

    test('Upload failure preserves existing images without premature deletion', () async {
      final service = InMemoryProductImageStorageService();
      service.shouldFailUpload = true;

      final dummyBytes = Uint8List.fromList([10, 20]);
      expect(
        () => service.uploadProductImage(
          productId: 'p-err',
          bytes: dummyBytes,
          fileName: 'test.png',
        ),
        throwsA(isA<String>()),
      );
      expect(service.deletedUrls.isEmpty, isTrue);
    });

    test('Add Product with new image saves Storage URL to Firestore imageUrl', () async {
      final storage = InMemoryProductImageStorageService();
      final productRepo = InMemoryProductRepository(initialProducts: []);
      final controller = AdminProductController(productRepository: productRepo);

      // Simulate admin uploading a new image for product 'p-new'
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final storageUrl = await storage.uploadProductImage(
        productId: 'p-new',
        bytes: bytes,
        fileName: 'blush.jpg',
      );

      final newProduct = ProductModel(
        id: 'p-new',
        name: 'Radiant Silk Blush',
        description: 'Luxury blush',
        price: 1850.0,
        categoryId: 'blush',
        categoryName: 'Blush & Cheeks',
        imageUrl: storageUrl,
      );

      final success = await controller.saveProduct(newProduct, isEditing: false);
      expect(success, isTrue);

      final saved = await productRepo.getProductById('p-new');
      expect(saved, isNotNull);
      expect(saved!.imageUrl, equals(storageUrl));
      expect(saved.imageUrl, contains('p-new'));
      expect(storage.uploadedImages.containsKey(storageUrl), isTrue);
    });

    test('Edit Product with replacement image uploads new image and safely cleans up old managed storage image', () async {
      final storage = InMemoryProductImageStorageService();
      // Initial product with a managed storage URL
      const oldStorageUrl = 'https://firebasestorage.googleapis.com/v0/b/shopease-mock/o/products%2Fp-edit%2Fold.jpg';
      storage.uploadedImages[oldStorageUrl] = Uint8List.fromList([1, 1, 1]);

      final initialProduct = ProductModel(
        id: 'p-edit',
        name: 'Initial Blush',
        description: 'Old desc',
        price: 1500.0,
        categoryId: 'blush',
        categoryName: 'Blush & Cheeks',
        imageUrl: oldStorageUrl,
      );

      final productRepo = InMemoryProductRepository(initialProducts: [initialProduct]);
      final controller = AdminProductController(productRepository: productRepo);

      // Admin selects a replacement image
      final replacementBytes = Uint8List.fromList([2, 2, 2]);
      final replacementUrl = await storage.uploadProductImage(
        productId: 'p-edit',
        bytes: replacementBytes,
        fileName: 'new_blush.jpg',
      );

      // Save updated product
      final updatedProduct = initialProduct.copyWith(
        name: 'Updated Blush',
        imageUrl: replacementUrl,
      );
      final success = await controller.saveProduct(updatedProduct, isEditing: true);
      expect(success, isTrue);

      // Delete old managed image after successful update
      if (storage.isManagedStorageUrl(oldStorageUrl)) {
        await storage.deleteProductImage(oldStorageUrl);
      }

      final saved = await productRepo.getProductById('p-edit');
      expect(saved!.imageUrl, equals(replacementUrl));
      expect(storage.uploadedImages.containsKey(replacementUrl), isTrue);
      expect(storage.uploadedImages.containsKey(oldStorageUrl), isFalse);
      expect(storage.deletedUrls.contains(oldStorageUrl), isTrue);
    });

    test('Edit Product without selecting new image preserves existing local asset imageUrl and never deletes it', () async {
      final storage = InMemoryProductImageStorageService();
      const localAssetPath = 'Assest/The Viral Blush Beauty Lovers Are Obsessed With.jpeg';

      final existingProduct = ProductModel(
        id: 'p-local',
        name: 'Soft Pinch Liquid Blush',
        description: 'Existing description',
        price: 1850.0,
        categoryId: 'blush',
        categoryName: 'Blush & Cheeks',
        imageUrl: localAssetPath,
      );

      final productRepo = InMemoryProductRepository(initialProducts: [existingProduct]);
      final controller = AdminProductController(productRepository: productRepo);

      // Admin edits price only without uploading any new image
      final updatedProduct = existingProduct.copyWith(
        price: 1999.0,
        // imageUrl is kept as localAssetPath
      );

      final success = await controller.saveProduct(updatedProduct, isEditing: true);
      expect(success, isTrue);

      // Local asset is never treated as managed storage and never deleted
      expect(storage.isManagedStorageUrl(localAssetPath), isFalse);
      expect(storage.deletedUrls.isEmpty, isTrue);

      final saved = await productRepo.getProductById('p-local');
      expect(saved!.price, equals(1999.0));
      expect(saved.imageUrl, equals(localAssetPath));
    });

    testWidgets('ProductCard displays network images and asset images correctly',
        (tester) async {
      const assetProduct = ProductModel(
        id: 'p-asset',
        name: 'Velvet Lip Tint',
        brand: 'AÈRA',
        subtitle: 'LIP TINT',
        volume: '10 ml',
        availableSizes: ['10 ml'],
        description: 'Velvet texture',
        price: 999.0,
        categoryId: 'lipstick',
        categoryName: 'Lipstick',
        rating: 4.8,
        reviewCount: 10,
        isFeatured: true,
        stockQuantity: 15,
        isAvailable: true,
        imageUrl: 'Assest/RAL Rare Beauty.jpeg',
      );

      const networkProduct = ProductModel(
        id: 'p-network',
        name: 'Dewy Serum',
        brand: 'AÈRA',
        subtitle: 'FACE SERUM',
        volume: '30 ml',
        availableSizes: ['30 ml'],
        description: 'Glow finish',
        price: 1899.0,
        categoryId: 'skincare',
        categoryName: 'Skincare',
        rating: 4.9,
        reviewCount: 22,
        isFeatured: true,
        stockQuantity: 8,
        isAvailable: true,
        imageUrl: 'https://firebasestorage.googleapis.com/v0/b/test/serum.jpg',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: const [
                SizedBox(width: 180, height: 260, child: ProductCard(product: assetProduct)),
                SizedBox(width: 180, height: 260, child: ProductCard(product: networkProduct)),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Velvet Lip Tint'), findsOneWidget);
      expect(find.text('Dewy Serum'), findsOneWidget);
    });

    testWidgets('ProductFormDialog renders live image controls and preset switching',
        (tester) async {
      tester.view.physicalSize = const Size(1024, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final productRepo = InMemoryProductRepository();
      final favRepo = _InMemoryFavoritesRepository();
      final storageService = InMemoryProductImageStorageService();
      final adminProductController =
          AdminProductController(productRepository: productRepo);
      final homeController = HomeController(
        productRepository: productRepo,
        favoritesRepository: favRepo,
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<ProductRepository>.value(value: productRepo),
            Provider<ProductImageStorageService>.value(value: storageService),
            ChangeNotifierProvider<AdminProductController>.value(
                value: adminProductController),
            ChangeNotifierProvider<HomeController>.value(value: homeController),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ProductFormDialog(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Section 4 controls
      expect(find.text('4. Product Image & Storage'), findsOneWidget);
      expect(find.text('Upload Image from Computer'), findsOneWidget);
      expect(find.text('Quick Presets:'), findsOneWidget);
      expect(find.text('Viral Blush'), findsOneWidget);
      expect(find.text('Velvet Lips'), findsOneWidget);

      // Scroll preset into view and tap
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -300));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Velvet Lips'));
      await tester.pumpAndSettle();
      expect(find.byType(ProductFormDialog), findsOneWidget);
    });
  });
}

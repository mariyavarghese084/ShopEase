import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shopease/controllers/admin_product_controller.dart';
import 'package:shopease/controllers/auth_controller.dart';
import 'package:shopease/controllers/home_controller.dart';
import 'package:shopease/models/customer_model.dart';
import 'package:shopease/repositories/favorites_repository.dart';
import 'package:shopease/repositories/product_repository.dart';
import 'package:shopease/views/admin/products/admin_products_view.dart';

class _TestAuthController extends AuthController {
  @override
  bool get isAuthenticated => true;
  @override
  bool get isAdmin => true;
  @override
  CustomerModel? get customerProfile => CustomerModel(
    uid: 'admin-1',
    fullName: 'Admin',
    email: 'admin@shopease.com',
    role: 'admin',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

class _InMemoryFavoritesRepository implements FavoritesRepository {
  @override
  Future<Set<String>> getFavorites(String uid) async => {};
  @override
  Future<void> addFavorite(String uid, String productId, {Map<String, dynamic>? extraData}) async {}
  @override
  Future<void> removeFavorite(String uid, String productId) async {}
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> runAddProductTest(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;

    final productRepo = InMemoryProductRepository();
    final favRepo = _InMemoryFavoritesRepository();
    final authController = _TestAuthController();
    final adminProductController = AdminProductController(productRepository: productRepo);
    final homeController = HomeController(
      productRepository: productRepo,
      favoritesRepository: favRepo,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ProductRepository>.value(value: productRepo),
          ChangeNotifierProvider<AuthController>.value(value: authController),
          ChangeNotifierProvider<AdminProductController>.value(value: adminProductController),
          ChangeNotifierProvider<HomeController>.value(value: homeController),
        ],
        child: const MaterialApp(home: AdminProductsView()),
      ),
    );
    await tester.pumpAndSettle();

    // Find and tap the Add Product button
    final addButton = find.byIcon(Icons.add_rounded).first;
    expect(addButton, findsOneWidget);
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    // Verify dialog appeared
    expect(find.text('Add New Product'), findsOneWidget);

    // Sweep mouse across dialog
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    for (double y = 10; y < size.height; y += 20) {
      for (double x = 10; x < size.width; x += 20) {
        await gesture.moveTo(Offset(x, y));
      }
    }
    await gesture.removePointer();
  }

  testWidgets('Click Add Product button at 1024x768', (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    await runAddProductTest(tester, const Size(1024, 768));
  });

  testWidgets('Click Add Product button at 800x600', (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    await runAddProductTest(tester, const Size(800, 600));
  });

  testWidgets('Click Add Product button at 500x700', (tester) async {
    addTearDown(() => tester.view.resetPhysicalSize());
    await runAddProductTest(tester, const Size(500, 700));
  });
}

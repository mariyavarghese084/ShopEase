import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shopease/controllers/admin_notification_controller.dart';
import 'package:shopease/controllers/auth_controller.dart';
import 'package:shopease/models/customer_model.dart';
import 'package:shopease/models/product_model.dart';
import 'package:shopease/repositories/auth_repository.dart';
import 'package:shopease/repositories/customer_repository.dart';
import 'package:shopease/repositories/notification_repository.dart';
import 'package:shopease/repositories/product_repository.dart';
import 'package:shopease/services/push_dispatch_service.dart';
import 'package:shopease/views/admin/notifications/admin_notifications_view.dart';

class _MockAuthRepo extends Fake implements AuthRepository {
  @override
  Stream<User?> get authStateChanges => const Stream.empty();
  @override
  User? get currentUser => null;
}

class _MockCustomerRepo extends Fake implements CustomerRepository {
  @override
  Future<List<CustomerModel>> getAllCustomers() async => [];
  @override
  Future<CustomerModel?> getCustomerProfile(String uid) async => null;
  @override
  Stream<CustomerModel?> watchCustomerProfile(String uid) => Stream.value(null);
}

class _MockProductRepo extends Fake implements ProductRepository {
  @override
  Future<List<ProductModel>> getProducts({
    String? categoryId,
    String? searchQuery,
  }) async => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemoryNotificationRepository notificationRepo;
  late InMemoryPushDispatchService pushDispatchService;
  late _MockCustomerRepo customerRepo;
  late _MockProductRepo productRepo;
  late AuthController authController;
  late AdminNotificationController adminNotifController;

  setUp(() {
    notificationRepo = InMemoryNotificationRepository();
    pushDispatchService = InMemoryPushDispatchService();
    customerRepo = _MockCustomerRepo();
    productRepo = _MockProductRepo();

    authController = AuthController(
      authRepository: _MockAuthRepo(),
      customerRepository: customerRepo,
    );
    authController.setCustomerProfileForTesting(
      CustomerModel(
        uid: 'admin_test_1',
        email: 'admin@shopease.com',
        fullName: 'Admin Director',
        role: 'admin',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    adminNotifController = AdminNotificationController(
      notificationRepository: notificationRepo,
      pushDispatchService: pushDispatchService,
      customerRepository: customerRepo,
      productRepository: productRepo,
      authController: authController,
    );
  });

  Widget createWidgetForTesting() {
    return MaterialApp(
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthController>.value(value: authController),
          ChangeNotifierProvider<AdminNotificationController>.value(
            value: adminNotifController,
          ),
        ],
        child: const AdminNotificationsView(),
      ),
    );
  }

  group('AdminNotificationsView Responsive Layout & Infinite Width Fix Verification', () {
    testWidgets('Desktop Browser (1280x800): Bounded header, row button, mouse tracking', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));

      await tester.pumpWidget(createWidgetForTesting());
      await tester.pumpAndSettle();

      // Check header and button
      expect(find.text('Push Notifications & Announcements'), findsOneWidget);
      final sendBtn = find.widgetWithText(ElevatedButton, 'Send Notification');
      expect(sendBtn, findsOneWidget);

      // Verify finite button width
      final btnSize = tester.getSize(sendBtn);
      expect(btnSize.width.isFinite, isTrue);
      expect(btnSize.width, greaterThan(100));
      expect(btnSize.width, lessThan(300));

      // Simulate mouse pointer hover and movement across button (verifies mouse_tracker / hit-test integrity)
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      await gesture.moveTo(tester.getCenter(sendBtn));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('Tablet Screen (768x1024): Bounded header, Wrap KPI cards, no infinite width crash', (tester) async {
      await tester.binding.setSurfaceSize(const Size(768, 1024));

      await tester.pumpWidget(createWidgetForTesting());
      await tester.pumpAndSettle();

      expect(find.text('Push Notifications & Announcements'), findsOneWidget);
      final sendBtn = find.widgetWithText(ElevatedButton, 'Send Notification');
      expect(sendBtn, findsOneWidget);

      final btnSize = tester.getSize(sendBtn);
      expect(btnSize.width.isFinite, isTrue);
      expect(btnSize.width, greaterThan(100));

      // Tap button and verify dialog opens without BoxConstraints crash
      await tester.tap(sendBtn);
      await tester.pumpAndSettle();

      expect(find.text('Compose Push Notification'), findsOneWidget);

      final cancelBtn = find.widgetWithText(OutlinedButton, 'Cancel');
      expect(cancelBtn, findsOneWidget);
      final cancelBtnSize = tester.getSize(cancelBtn);
      expect(cancelBtnSize.width.isFinite, isTrue);

      final dispatchBtn =
          find.widgetWithText(ElevatedButton, 'Dispatch Notification');
      expect(dispatchBtn, findsOneWidget);
      final dispatchBtnSize = tester.getSize(dispatchBtn);
      expect(dispatchBtnSize.width.isFinite, isTrue);

      // Mouse tracking over the dialog buttons
      final dialogMouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await dialogMouse.addPointer(location: Offset.zero);
      await dialogMouse.moveTo(tester.getCenter(cancelBtn));
      await tester.pumpAndSettle();
      await dialogMouse.moveTo(tester.getCenter(dispatchBtn));
      await tester.pumpAndSettle();

      // Dismiss dialog
      await tester.tap(cancelBtn);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('Mobile Screen (375x667): Stacked header, bounded finite button, zero overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(375, 667));

      await tester.pumpWidget(createWidgetForTesting());
      await tester.pumpAndSettle();

      expect(find.text('Push Notifications & Announcements'), findsOneWidget);
      final sendBtn = find.widgetWithText(ElevatedButton, 'Send Notification');
      expect(sendBtn, findsOneWidget);

      final btnSize = tester.getSize(sendBtn);
      expect(btnSize.width.isFinite, isTrue);
      expect(btnSize.width, greaterThan(100));
      expect(btnSize.width, lessThanOrEqualTo(375));

      expect(tester.takeException(), isNull);
    });

    testWidgets('Narrow Screen (320x568): Header renders cleanly without RenderFlex overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));

      await tester.pumpWidget(createWidgetForTesting());
      await tester.pumpAndSettle();

      expect(find.text('Push Notifications & Announcements'), findsOneWidget);
      final sendBtn = find.widgetWithText(ElevatedButton, 'Send Notification');
      expect(sendBtn, findsOneWidget);

      final btnSize = tester.getSize(sendBtn);
      expect(btnSize.width.isFinite, isTrue);

      expect(tester.takeException(), isNull);
    });
  });
}

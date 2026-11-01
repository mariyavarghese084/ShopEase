import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shopease/controllers/admin_notification_controller.dart';
import 'package:shopease/controllers/admin_order_controller.dart';
import 'package:shopease/controllers/auth_controller.dart';
import 'package:shopease/controllers/order_controller.dart';
import 'package:shopease/models/customer_model.dart';
import 'package:shopease/models/order_model.dart';
import 'package:shopease/repositories/auth_repository.dart';
import 'package:shopease/repositories/customer_repository.dart';
import 'package:shopease/repositories/notification_repository.dart';
import 'package:shopease/repositories/order_repository.dart';
import 'package:shopease/repositories/product_repository.dart';
import 'package:shopease/services/push_dispatch_service.dart';
import 'package:shopease/views/admin/notifications/admin_notifications_view.dart';
import 'package:shopease/views/customer/notifications/customer_notification_center_view.dart';

// ── Mock Repositories ────────────────────────────────────────────────────────
class MockCustomerRepository implements CustomerRepository {
  final List<CustomerModel> customers = [
    CustomerModel(
      uid: 'cust_1',
      email: 'jane@example.com',
      fullName: 'Jane Doe',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    CustomerModel(
      uid: 'cust_2',
      email: 'john@example.com',
      fullName: 'John Smith',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  @override
  Future<List<CustomerModel>> getAllCustomers() async => customers;

  @override
  Future<void> createCustomerProfile(CustomerModel customer) async {}

  @override
  Future<CustomerModel?> getCustomerProfile(String uid) async =>
      customers.firstWhere((c) => c.uid == uid, orElse: () => customers.first);

  @override
  Stream<CustomerModel?> watchCustomerProfile(String uid) => Stream.value(null);

  @override
  Future<void> updateCustomerProfile(CustomerModel customer) async {}
}

class MockOrderRepository implements OrderRepository {
  final List<OrderModel> orders = [];

  @override
  Future<void> createOrder(String uid, OrderModel order) async {
    orders.add(order);
  }

  @override
  Future<List<OrderModel>> getOrders(String uid) async =>
      orders.where((o) => o.customerId == uid).toList();

  @override
  Future<List<OrderModel>> getAllOrders() async => orders;

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

class MockAuthRepository extends Fake implements AuthRepository {
  @override
  Stream<User?> get authStateChanges => const Stream.empty();

  @override
  User? get currentUser => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemoryNotificationRepository notificationRepo;
  late InMemoryPushDispatchService pushDispatchService;
  late MockCustomerRepository customerRepo;
  late InMemoryProductRepository productRepo;
  late MockOrderRepository orderRepo;

  setUp(() {
    notificationRepo = InMemoryNotificationRepository();
    pushDispatchService = InMemoryPushDispatchService();
    customerRepo = MockCustomerRepository();
    productRepo = InMemoryProductRepository();
    orderRepo = MockOrderRepository();
  });

  group('Stage 4: Admin Notification Controller & Push Dispatch Tests', () {
    test('Non-admin user cannot send notification campaigns', () async {
      final authController = AuthController(
        authRepository: MockAuthRepository(),
        customerRepository: customerRepo,
      );
      authController.setCustomerProfileForTesting(
        CustomerModel(
          uid: 'cust_normal',
          email: 'customer@shopease.com',
          fullName: 'Normal Customer',
          role: 'customer',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final adminNotifCtrl = AdminNotificationController(
        notificationRepository: notificationRepo,
        pushDispatchService: pushDispatchService,
        customerRepository: customerRepo,
        productRepository: productRepo,
        authController: authController,
      );

      final success = await adminNotifCtrl.sendNotification(
        title: 'Flash Sale',
        message: '50% off all fragrances this weekend!',
        type: 'promotion',
        audience: 'all',
      );

      expect(success, isFalse);
      expect(adminNotifCtrl.errorMessage, contains('Administrator role required'));
      expect(adminNotifCtrl.campaigns, isEmpty);
    });

    test('Admin successfully composes and dispatches broadcast announcement', () async {
      final authController = AuthController(
        authRepository: MockAuthRepository(),
        customerRepository: customerRepo,
      );

      authController.setCustomerProfileForTesting(
        CustomerModel(
          uid: 'admin_123',
          email: 'admin@shopease.com',
          fullName: 'Executive Admin',
          role: 'admin',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final adminNotifCtrl = AdminNotificationController(
        notificationRepository: notificationRepo,
        pushDispatchService: pushDispatchService,
        customerRepository: customerRepo,
        productRepository: productRepo,
        authController: authController,
      );

      await adminNotifCtrl.loadDashboardData();

      final success = await adminNotifCtrl.sendNotification(
        title: 'AÈRA Luxury Gala',
        message: 'Exclusive invitation for our holiday perfume collection.',
        type: 'festival',
        audience: 'all',
      );

      expect(success, isTrue);
      expect(adminNotifCtrl.campaigns.length, 1);
      expect(adminNotifCtrl.totalNotifications, 1);
      expect(adminNotifCtrl.sentNotifications, 1);
      expect(adminNotifCtrl.campaigns.first.title, 'AÈRA Luxury Gala');
      expect(adminNotifCtrl.campaigns.first.type, 'festival');

      // Verify push dispatch was logged with trusted backend service
      expect(pushDispatchService.dispatchedRequests.length, 1);
      expect(
        pushDispatchService.dispatchedRequests.first['audience'],
        'all',
      );
    });

    test('Admin sends targeted notification to specific customer and verifies customer inbox', () async {
      final authController = AuthController(
        authRepository: MockAuthRepository(),
        customerRepository: customerRepo,
      );

      authController.setCustomerProfileForTesting(
        CustomerModel(
          uid: 'admin_123',
          email: 'admin@shopease.com',
          fullName: 'Executive Admin',
          role: 'admin',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final adminNotifCtrl = AdminNotificationController(
        notificationRepository: notificationRepo,
        pushDispatchService: pushDispatchService,
        customerRepository: customerRepo,
        productRepository: productRepo,
        authController: authController,
      );

      final success = await adminNotifCtrl.sendNotification(
        title: 'VIP Consultation Confirmed',
        message: 'Your fragrance styling session has been scheduled.',
        type: 'general',
        audience: 'customer',
        selectedCustomerId: 'cust_1',
        selectedCustomerName: 'Jane Doe',
      );

      expect(success, isTrue);
      expect(adminNotifCtrl.campaigns.first.recipientName, 'Jane Doe');

      // Verify that customer Jane Doe receives it in her notifications feed
      final stream = notificationRepo.notificationsStream('cust_1');
      final inbox = await stream.first;
      expect(inbox.length, 1);
      expect(inbox.first.title, 'VIP Consultation Confirmed');
    });

    test('Admin deletes a notification campaign', () async {
      final authController = AuthController(
        authRepository: MockAuthRepository(),
        customerRepository: customerRepo,
      );

      authController.setCustomerProfileForTesting(
        CustomerModel(
          uid: 'admin_123',
          email: 'admin@shopease.com',
          fullName: 'Executive Admin',
          role: 'admin',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final adminNotifCtrl = AdminNotificationController(
        notificationRepository: notificationRepo,
        pushDispatchService: pushDispatchService,
        customerRepository: customerRepo,
        productRepository: productRepo,
        authController: authController,
      );

      await adminNotifCtrl.sendNotification(
        title: 'Temporary Flash Notice',
        message: 'Discounts valid for 1 hour only.',
        type: 'promotion',
        audience: 'all',
      );

      expect(adminNotifCtrl.campaigns.length, 1);
      final campaignId = adminNotifCtrl.campaigns.first.id;

      final deleted = await adminNotifCtrl.deleteNotification(campaignId);
      expect(deleted, isTrue);
      expect(adminNotifCtrl.campaigns, isEmpty);
    });
  });

  group('Stage 4: Order Flow Push Notification Integration', () {
    test('Placing an order queues customer confirmation and admin alert', () async {
      final orderCtrl = OrderController(
        orderRepository: orderRepo,
        pushDispatchService: pushDispatchService,
        notificationRepository: notificationRepo,
      );

      final order = await orderCtrl.placeOrder(
        items: [
          const OrderItemModel(
            productId: 'p1',
            productName: 'Yara Rose Perfume',
            subtitle: 'Luxury Fragrance',
            size: '100ml',
            price: 99.0,
            quantity: 1,
          ),
        ],
        subtotal: 99.0,
        discount: 0.0,
        shippingFee: 0.0,
        total: 99.0,
        shippingName: 'Jane Doe',
        shippingPhone: '+1234567890',
        shippingAddress: '123 Luxury Ave',
        shippingCity: 'Paris',
        shippingPostalCode: '75001',
        paymentMethod: 'Credit Card',
        uid: 'cust_1',
      );

      expect(order.id, isNotEmpty);

      // Verify customer in-app notification was stored
      final customerInbox = await notificationRepo.notificationsStream('cust_1').first;
      expect(customerInbox.length, 1);
      expect(customerInbox.first.title, contains(order.id));

      // Verify push dispatch was recorded for customer confirmation and admin alert
      final actions = pushDispatchService.dispatchedRequests.map((r) => r['action']).toList();
      expect(actions, contains('order_confirmation'));
      expect(actions, contains('admin_order_alert'));
    });

    test('Updating order status in admin controller dispatches status notification to customer', () async {
      final testOrder = OrderModel(
        id: 'ORD-999',
        customerId: 'cust_1',
        items: [],
        subtotal: 150.0,
        discount: 0.0,
        shippingFee: 0.0,
        total: 150.0,
        status: OrderProgressStatus.placed,
        shippingName: 'Jane Doe',
        shippingPhone: '+1234567890',
        shippingAddress: '123 Luxury Ave',
        shippingCity: 'Paris',
        shippingPostalCode: '75001',
        paymentMethod: 'Credit Card',
        paymentStatus: 'Paid',
        trackingNumber: 'TRK-999',
        courierName: 'AÈRA Express',
        estimatedDelivery: 'Tomorrow',
        createdAt: DateTime.now(),
      );

      await orderRepo.createOrder('cust_1', testOrder);

      final authController = AuthController(
        authRepository: MockAuthRepository(),
        customerRepository: customerRepo,
      );
      authController.setCustomerProfileForTesting(
        CustomerModel(
          uid: 'admin_123',
          email: 'admin@shopease.com',
          fullName: 'Admin User',
          role: 'admin',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final adminOrderCtrl = AdminOrderController(
        orderRepository: orderRepo,
        authController: authController,
        pushDispatchService: pushDispatchService,
        notificationRepository: notificationRepo,
      );

      await adminOrderCtrl.loadOrders();

      // Transition order from placed to processing
      final success = await adminOrderCtrl.updateOrderStatus(
        testOrder,
        OrderProgressStatus.processing,
        note: 'Order processing and ready for packing',
      );

      expect(success, isTrue);

      // Verify customer received status update notification
      final customerInbox = await notificationRepo.notificationsStream('cust_1').first;
      expect(customerInbox.any((n) => n.title.contains('ORD-999')), isTrue);

      // Verify push update was dispatched
      final actions = pushDispatchService.dispatchedRequests.map((r) => r['action']).toList();
      expect(
        actions.any((a) =>
            a == 'status_update' || a == 'customer_order_status_update'),
        isTrue,
      );
    });
  });

  group('Stage 4: UI Rendering Tests', () {
    testWidgets('AdminNotificationsView renders KPI cards and header', (tester) async {
      final authController = AuthController(
        authRepository: MockAuthRepository(),
        customerRepository: customerRepo,
      );
      authController.setCustomerProfileForTesting(
        CustomerModel(
          uid: 'admin_123',
          email: 'admin@shopease.com',
          fullName: 'Admin User',
          role: 'admin',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final adminNotifCtrl = AdminNotificationController(
        notificationRepository: notificationRepo,
        pushDispatchService: pushDispatchService,
        customerRepository: customerRepo,
        productRepository: productRepo,
        authController: authController,
      );

      await tester.binding.setSurfaceSize(const Size(1200, 800));

      await tester.pumpWidget(
        MaterialApp(
          home: MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthController>.value(value: authController),
              ChangeNotifierProvider<AdminNotificationController>.value(value: adminNotifCtrl),
            ],
            child: const AdminNotificationsView(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Notification Management'), findsOneWidget);
      expect(find.text('Total Campaigns'), findsOneWidget);
      expect(find.text('Sent Notifications'), findsOneWidget);
      expect(find.text('Read Status'), findsOneWidget);
      expect(find.text('Unread Status'), findsOneWidget);
      expect(find.text('Send Notification'), findsOneWidget);
    });

    testWidgets('CustomerNotificationCenterView renders filter chips and empty state', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 600));

      await tester.pumpWidget(
        const MaterialApp(
          home: CustomerNotificationCenterView(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Notification Center'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Unread'), findsOneWidget);
      expect(find.text('Orders'), findsOneWidget);
      expect(find.text('Promotions'), findsOneWidget);
      expect(find.text('No Notifications'), findsOneWidget);
    });
  });
}

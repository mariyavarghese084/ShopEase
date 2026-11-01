import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopease/controllers/admin_order_controller.dart';
import 'package:shopease/controllers/auth_controller.dart';
import 'package:shopease/controllers/order_controller.dart';
import 'package:shopease/models/customer_model.dart';
import 'package:shopease/models/notification_model.dart';
import 'package:shopease/models/order_model.dart';
import 'package:shopease/repositories/auth_repository.dart';
import 'package:shopease/repositories/customer_repository.dart';
import 'package:shopease/repositories/notification_repository.dart';
import 'package:shopease/repositories/order_repository.dart';
import 'package:shopease/services/push_dispatch_service.dart';

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
}

class MockAuthRepository extends Fake implements AuthRepository {
  @override
  Stream<User?> get authStateChanges => const Stream.empty();

  @override
  User? get currentUser => null;
}

/// Simulated Backend Worker matching Cloud Function logic in functions/index.js.
class SimulatedBackendNotificationWorker {
  final NotificationRepository notificationRepository;
  final List<Map<String, dynamic>> processedDispatches = [];
  final List<String> deactivatedTokens = [];

  SimulatedBackendNotificationWorker({required this.notificationRepository});

  Future<Map<String, dynamic>> processRequest(Map<String, dynamic> request) async {
    // 1. Duplicate & Idempotency check
    if (request['status'] == 'processed' || request['status'] == 'processing') {
      return {'skipped': true, 'reason': 'already_processed'};
    }

    final action = request['action'];
    final customerUid = request['customerUid'] as String?;

    if (action == 'customer_order_confirmation' || action == 'order_confirmation') {
      if (customerUid == null) {
        return {'success': false, 'error': 'missing_customer_uid'};
      }

      // 2. Retrieve active registered FCM tokens
      final devices = await notificationRepository.getUserDevices(customerUid);
      final activeTokens = devices.where((d) => d.isActive).map((d) => d.token).toList();

      if (activeTokens.isEmpty) {
        final res = {
          'status': 'processed',
          'fcmResponse': 'no_active_tokens_registered',
          'totalTokens': 0,
          'customerUid': customerUid,
        };
        processedDispatches.add(res);
        return res;
      }

      // 3. Multicast push simulation
      final res = {
        'status': 'processed',
        'action': 'customer_order_confirmation',
        'customerUid': customerUid,
        'orderId': request['orderId'],
        'title': request['title'] ?? 'Order Confirmed',
        'body': request['body'] ?? 'Your order is confirmed.',
        'targetRoute': request['targetRoute'] ?? '/customer/orders',
        'totalTokens': activeTokens.length,
        'tokensDispatched': activeTokens,
        'successfulSendCount': activeTokens.length,
        'failedSendCount': 0,
        'successCount': activeTokens.length,
        'failureCount': 0,
      };
      processedDispatches.add(res);
      return res;
    }

    if (action == 'status_update' || action == 'order_status_update') {
      final devices = await notificationRepository.getUserDevices(customerUid!);
      final activeTokens = devices.where((d) => d.isActive).map((d) => d.token).toList();

      final res = {
        'status': 'processed',
        'action': 'order_status_update',
        'customerUid': customerUid,
        'orderId': request['orderId'],
        'title': request['title'],
        'body': request['body'],
        'totalTokens': activeTokens.length,
        'tokensDispatched': activeTokens,
      };
      processedDispatches.add(res);
      return res;
    }

    if (action == 'admin_order_alert' || action == 'admin_new_order_alert') {
      final res = {
        'status': 'processed',
        'action': 'admin_new_order_alert',
        'orderId': request['orderId'],
        'title': request['title'],
        'body': request['body'],
        'targetRoute': '/admin/orders',
      };
      processedDispatches.add(res);
      return res;
    }

    return {'success': false, 'error': 'unsupported_action'};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemoryNotificationRepository notificationRepo;
  late InMemoryPushDispatchService pushDispatchService;
  late MockCustomerRepository customerRepo;
  late MockOrderRepository orderRepo;

  setUp(() {
    notificationRepo = InMemoryNotificationRepository();
    pushDispatchService = InMemoryPushDispatchService();
    customerRepo = MockCustomerRepository();
    orderRepo = MockOrderRepository();
  });

  group('Stage 4.1: Order Push Notification Delivery Flow', () {
    test('Order creation creates in-app notification and self-contained push request', () async {
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
            subtitle: 'Luxury Eau de Parfum',
            size: '100ml',
            price: 120.0,
            quantity: 2,
          ),
        ],
        subtotal: 240.0,
        discount: 0.0,
        shippingFee: 0.0,
        total: 240.0,
        shippingName: 'Jane Doe',
        shippingPhone: '+1987654321',
        shippingAddress: '742 Evergreen Terrace',
        shippingCity: 'Paris',
        shippingPostalCode: '75008',
        paymentMethod: 'Credit Card',
        uid: 'cust_1',
      );

      expect(order.id, isNotEmpty);

      // 1. Verify in-app customer notification created
      final customerInbox = await notificationRepo.notificationsStream('cust_1').first;
      expect(customerInbox.length, 1);
      final inAppNotif = customerInbox.first;
      expect(inAppNotif.title, contains(order.id));
      expect(inAppNotif.targetRoute, '/customer/orders');
      expect(inAppNotif.targetId, order.id);

      // 2. Verify push dispatch request has complete self-contained payload
      final confirmationRequests = pushDispatchService.dispatchedRequests
          .where((r) => r['action'] == 'order_confirmation')
          .toList();
      expect(confirmationRequests.length, 1);

      final confReq = confirmationRequests.first;
      expect(confReq['customerUid'], 'cust_1');
      expect(confReq['orderId'], order.id);
      expect(confReq['title'], contains(order.id));
      expect(confReq['body'], contains('240.00'));
      expect(confReq['targetRoute'], '/customer/orders');
      expect(confReq['targetId'], order.id);

      // 3. Verify admin alert push request created
      final adminAlertRequests = pushDispatchService.dispatchedRequests
          .where((r) => r['action'] == 'admin_order_alert')
          .toList();
      expect(adminAlertRequests.length, 1);
      final adminReq = adminAlertRequests.first;
      expect(adminReq['orderId'], order.id);
      expect(adminReq['title'], contains(order.id));
      expect(adminReq['customerName'], 'Jane Doe');
      expect(adminReq['targetRoute'], '/admin/orders');
    });

    test('Order fulfillment status update dispatches rich status notification to customer', () async {
      final testOrder = OrderModel(
        id: 'ORD-888',
        customerId: 'cust_1',
        items: [],
        subtotal: 99.0,
        discount: 0.0,
        shippingFee: 0.0,
        total: 99.0,
        status: OrderProgressStatus.placed,
        shippingName: 'Jane Doe',
        shippingPhone: '+1987654321',
        shippingAddress: '742 Evergreen Terrace',
        shippingCity: 'Paris',
        shippingPostalCode: '75008',
        paymentMethod: 'Credit Card',
        trackingNumber: 'TRK-888',
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

      // Transition placed -> processing
      final success = await adminOrderCtrl.updateOrderStatus(
        testOrder,
        OrderProgressStatus.processing,
        note: 'Order processing in Paris boutique',
      );

      expect(success, isTrue);

      // Verify customer in-app notification
      final customerInbox = await notificationRepo.notificationsStream('cust_1').first;
      expect(customerInbox.any((n) => n.title.contains('ORD-888 Updated')), isTrue);

      // Verify status update push request
      final statusRequests = pushDispatchService.dispatchedRequests
          .where((r) => r['action'] == 'status_update')
          .toList();
      expect(statusRequests.length, 1);
      final req = statusRequests.first;
      expect(req['customerUid'], 'cust_1');
      expect(req['orderId'], 'ORD-888');
      expect(req['title'], contains('ORD-888 Updated'));
      expect(req['body'], contains('Processing'));
      expect(req['targetRoute'], '/customer/orders');
    });
  });

  group('Stage 4.1: Backend Worker Push Delivery & Device Token Processing', () {
    test('Worker retrieves active multi-device tokens and dispatches FCM message', () async {
      // 1. Register multiple devices for customer (e.g. Android phone + Web browser)
      final phoneDevice = DeviceRegistrationModel(
        deviceId: 'dev_android_phone',
        token: 'fcm_token_android_phone_123',
        platform: 'android',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isActive: true,
      );
      final webDevice = DeviceRegistrationModel(
        deviceId: 'dev_web_chrome',
        token: 'fcm_token_web_chrome_456',
        platform: 'web',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isActive: true,
      );

      await notificationRepo.saveDeviceToken(uid: 'cust_1', device: phoneDevice);
      await notificationRepo.saveDeviceToken(uid: 'cust_1', device: webDevice);

      // 2. Initialize simulated Cloud Functions backend worker
      final worker = SimulatedBackendNotificationWorker(
        notificationRepository: notificationRepo,
      );

      final requestPayload = {
        'requestId': 'req_conf_001',
        'action': 'customer_order_confirmation',
        'customerUid': 'cust_1',
        'orderId': 'ORD-777',
        'title': 'Order Confirmed: #ORD-777',
        'body': 'Your order has been placed successfully.',
        'targetRoute': '/customer/orders',
        'status': 'queued_for_backend',
      };

      final result = await worker.processRequest(requestPayload);

      expect(result['status'], 'processed');
      expect(result['totalTokens'], 2);
      expect(
        result['tokensDispatched'],
        containsAll(['fcm_token_android_phone_123', 'fcm_token_web_chrome_456']),
      );
      expect(worker.processedDispatches.length, 1);
    });

    test('Worker handles customer with zero registered devices gracefully without failing', () async {
      final worker = SimulatedBackendNotificationWorker(
        notificationRepository: notificationRepo,
      );

      final requestPayload = {
        'requestId': 'req_conf_002',
        'action': 'customer_order_confirmation',
        'customerUid': 'cust_no_devices',
        'orderId': 'ORD-555',
        'status': 'queued_for_backend',
      };

      final result = await worker.processRequest(requestPayload);

      expect(result['status'], 'processed');
      expect(result['totalTokens'], 0);
      expect(result['fcmResponse'], 'no_active_tokens_registered');
    });

    test('Worker ignores already processed requests to prevent duplicate delivery', () async {
      final worker = SimulatedBackendNotificationWorker(
        notificationRepository: notificationRepo,
      );

      final alreadyProcessedRequest = {
        'requestId': 'req_conf_003',
        'action': 'customer_order_confirmation',
        'customerUid': 'cust_1',
        'orderId': 'ORD-333',
        'status': 'processed',
      };

      final result = await worker.processRequest(alreadyProcessedRequest);

      expect(result['skipped'], true);
      expect(result['reason'], 'already_processed');
      expect(worker.processedDispatches, isEmpty);
    });
  });
}

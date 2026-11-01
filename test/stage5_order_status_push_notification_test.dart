import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopease/controllers/admin_order_controller.dart';
import 'package:shopease/controllers/auth_controller.dart';
import 'package:shopease/models/customer_model.dart';
import 'package:shopease/models/order_model.dart';
import 'package:shopease/repositories/auth_repository.dart';
import 'package:shopease/repositories/customer_repository.dart';
import 'package:shopease/repositories/notification_repository.dart';
import 'package:shopease/repositories/order_repository.dart';
import 'package:shopease/services/push_dispatch_service.dart';

class MockCustomerRepo implements CustomerRepository {
  final List<CustomerModel> customers = [
    CustomerModel(
      uid: 'cust_abc_123',
      email: 'aera.customer@example.com',
      fullName: 'Elena Rostova',
      role: 'customer',
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

class MockOrderRepo implements OrderRepository {
  final List<OrderModel> orders = [];
  bool shouldFailUpdate = false;
  int updateCallCount = 0;

  @override
  Future<void> createOrder(String uid, OrderModel order) async {
    orders.add(order);
  }

  @override
  Future<List<OrderModel>> getOrders(String uid) async =>
      orders.where((o) => o.customerId == uid).toList();

  @override
  Future<List<OrderModel>> getAllOrders() async => List.from(orders);

  @override
  Future<void> updateOrderStatus(
    String uid,
    String orderId,
    OrderProgressStatus status, {
    String? adminId,
    String? note,
  }) async {
    updateCallCount++;
    if (shouldFailUpdate) {
      throw Exception('Firestore write failure simulated for testing');
    }
    final idx = orders.indexWhere((o) => o.id == orderId);
    if (idx != -1) {
      final old = orders[idx];
      orders[idx] = old.copyWith(
        status: status,
        updatedAt: DateTime.now(),
        updatedBy: adminId,
      );
    }
  }

  @override
  Future<String?> findCustomerUidForOrder(String orderId) async {
    for (final o in orders) {
      if (o.id == orderId) {
        return (o.customerId != null && o.customerId!.isNotEmpty)
            ? o.customerId!
            : 'cust_abc_123';
      }
    }
    return null;
  }
}

class MockAuthRepo extends Fake implements AuthRepository {
  @override
  Stream<User?> get authStateChanges => const Stream.empty();
  @override
  User? get currentUser => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemoryNotificationRepository notificationRepo;
  late InMemoryPushDispatchService pushDispatchService;
  late MockCustomerRepo customerRepo;
  late MockOrderRepo orderRepo;
  late AuthController adminAuthController;
  late AuthController customerAuthController;

  setUp(() {
    notificationRepo = InMemoryNotificationRepository();
    pushDispatchService = InMemoryPushDispatchService();
    customerRepo = MockCustomerRepo();
    orderRepo = MockOrderRepo();

    adminAuthController = AuthController(
      authRepository: MockAuthRepo(),
      customerRepository: customerRepo,
    );
    adminAuthController.setCustomerProfileForTesting(
      CustomerModel(
        uid: 'admin_exec_01',
        email: 'admin@aera.com',
        fullName: 'Admin Director',
        role: 'admin',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    customerAuthController = AuthController(
      authRepository: MockAuthRepo(),
      customerRepository: customerRepo,
    );
    customerAuthController.setCustomerProfileForTesting(
      CustomerModel(
        uid: 'cust_abc_123',
        email: 'customer@aera.com',
        fullName: 'Elena Rostova',
        role: 'customer',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  });

  OrderModel buildTestOrder({
    required String id,
    required OrderProgressStatus status,
    String customerId = 'cust_abc_123',
  }) {
    return OrderModel(
      id: id,
      customerId: customerId,
      items: const [
        OrderItemModel(
          productId: 'p_velvet_rouge',
          productName: 'Velvet Rouge Lipstick',
          subtitle: 'Matte Finish',
          size: '3.5g',
          price: 48.0,
          quantity: 1,
        ),
      ],
      subtotal: 48.0,
      discount: 0.0,
      shippingFee: 0.0,
      total: 48.0,
      shippingName: 'Elena Rostova',
      shippingPhone: '+1234567890',
      shippingAddress: '100 Luxury Blvd',
      shippingCity: 'New York',
      shippingPostalCode: '10001',
      paymentMethod: 'Credit Card',
      paymentStatus: 'paid',
      trackingNumber: 'TRK-$id',
      courierName: 'DHL Express',
      estimatedDelivery: 'Tomorrow, 5 PM',
      status: status,
      createdAt: DateTime.now(),
    );
  }

  group('Automatic Push Notifications for Order Status Changes', () {
    test('Transition 1: Confirmed (placed) -> Processing dispatches exact message', () async {
      final order = buildTestOrder(id: 'ORD-101', status: OrderProgressStatus.placed);
      orderRepo.orders.add(order);

      final controller = AdminOrderController(
        orderRepository: orderRepo,
        authController: adminAuthController,
        pushDispatchService: pushDispatchService,
        notificationRepository: notificationRepo,
      );

      final success = await controller.updateOrderStatus(
        order,
        OrderProgressStatus.processing,
        note: 'Order moving to packaging',
      );

      expect(success, isTrue);

      // Verify Firestore status updated
      final updated = orderRepo.orders.firstWhere((o) => o.id == 'ORD-101');
      expect(updated.status, OrderProgressStatus.processing);

      // Verify Push Dispatch Request created in notification_requests
      final requests = pushDispatchService.dispatchedRequests
          .where((r) => r['action'] == 'customer_order_status_update')
          .toList();
      expect(requests.length, 1);

      final req = requests.first;
      expect(req['customerUid'], 'cust_abc_123');
      expect(req['orderId'], 'ORD-101');
      expect(req['body'], 'Your order is being prepared.');
      expect(req['targetRoute'], '/customer/orders');
      expect(req['targetId'], 'ORD-101');
      expect(req['status'], 'queued');

      // Verify customer in-app notification
      final inApp = await notificationRepo.notificationsStream('cust_abc_123').first;
      expect(inApp.length, 1);
      expect(inApp.first.body, 'Your order is being prepared.');
      expect(inApp.first.targetRoute, '/customer/orders');
    });

    test('Transition 2: Processing -> Shipped dispatches exact message', () async {
      final order = buildTestOrder(id: 'ORD-102', status: OrderProgressStatus.processing);
      orderRepo.orders.add(order);

      final controller = AdminOrderController(
        orderRepository: orderRepo,
        authController: adminAuthController,
        pushDispatchService: pushDispatchService,
        notificationRepository: notificationRepo,
      );

      final success = await controller.updateOrderStatus(
        order,
        OrderProgressStatus.shipped,
      );

      expect(success, isTrue);

      final requests = pushDispatchService.dispatchedRequests
          .where((r) => r['action'] == 'customer_order_status_update')
          .toList();
      expect(requests.length, 1);
      expect(requests.first['body'], 'Your order has been shipped!');
    });

    test('Transition 3: Shipped -> Out for Delivery dispatches exact message', () async {
      final order = buildTestOrder(id: 'ORD-103', status: OrderProgressStatus.shipped);
      orderRepo.orders.add(order);

      final controller = AdminOrderController(
        orderRepository: orderRepo,
        authController: adminAuthController,
        pushDispatchService: pushDispatchService,
        notificationRepository: notificationRepo,
      );

      final success = await controller.updateOrderStatus(
        order,
        OrderProgressStatus.outForDelivery,
      );

      expect(success, isTrue);

      final requests = pushDispatchService.dispatchedRequests
          .where((r) => r['action'] == 'customer_order_status_update')
          .toList();
      expect(requests.length, 1);
      expect(requests.first['body'], 'Your order is out for delivery.');
    });

    test('Transition 4: Out for Delivery -> Delivered dispatches exact message', () async {
      final order = buildTestOrder(id: 'ORD-104', status: OrderProgressStatus.outForDelivery);
      orderRepo.orders.add(order);

      final controller = AdminOrderController(
        orderRepository: orderRepo,
        authController: adminAuthController,
        pushDispatchService: pushDispatchService,
        notificationRepository: notificationRepo,
      );

      final success = await controller.updateOrderStatus(
        order,
        OrderProgressStatus.delivered,
      );

      expect(success, isTrue);

      final requests = pushDispatchService.dispatchedRequests
          .where((r) => r['action'] == 'customer_order_status_update')
          .toList();
      expect(requests.length, 1);
      expect(
        requests.first['body'],
        'Your order has been delivered. Thank you for shopping with AÈRA!',
      );
    });

    test('Unchanged status does not create push or in-app notification', () async {
      final order = buildTestOrder(id: 'ORD-105', status: OrderProgressStatus.processing);
      orderRepo.orders.add(order);

      final controller = AdminOrderController(
        orderRepository: orderRepo,
        authController: adminAuthController,
        pushDispatchService: pushDispatchService,
        notificationRepository: notificationRepo,
      );

      final success = await controller.updateOrderStatus(
        order,
        OrderProgressStatus.processing, // Same status
      );

      expect(success, isTrue);
      expect(orderRepo.updateCallCount, 0);
      expect(pushDispatchService.dispatchedRequests, isEmpty);

      final inApp = await notificationRepo.notificationsStream('cust_abc_123').first;
      expect(inApp, isEmpty);
    });

    test('Failed Firestore status update does not create push notification', () async {
      final order = buildTestOrder(id: 'ORD-106', status: OrderProgressStatus.placed);
      orderRepo.orders.add(order);
      orderRepo.shouldFailUpdate = true; // Simulate Firestore failure

      final controller = AdminOrderController(
        orderRepository: orderRepo,
        authController: adminAuthController,
        pushDispatchService: pushDispatchService,
        notificationRepository: notificationRepo,
      );

      final success = await controller.updateOrderStatus(
        order,
        OrderProgressStatus.processing,
      );

      expect(success, isFalse);
      expect(controller.errorMessage, contains('Firestore write failure simulated'));
      expect(pushDispatchService.dispatchedRequests, isEmpty);

      final inApp = await notificationRepo.notificationsStream('cust_abc_123').first;
      expect(inApp, isEmpty);
    });

    test('Non-admin caller cannot update status or trigger notifications', () async {
      final order = buildTestOrder(id: 'ORD-107', status: OrderProgressStatus.placed);
      orderRepo.orders.add(order);

      final controller = AdminOrderController(
        orderRepository: orderRepo,
        authController: customerAuthController, // Non-admin!
        pushDispatchService: pushDispatchService,
        notificationRepository: notificationRepo,
      );

      final success = await controller.updateOrderStatus(
        order,
        OrderProgressStatus.processing,
      );

      expect(success, isFalse);
      expect(controller.errorMessage, contains('Only administrators can update order status'));
      expect(orderRepo.updateCallCount, 0);
      expect(pushDispatchService.dispatchedRequests, isEmpty);
    });

    test('Falls back to findCustomerUidForOrder when customerId on order is missing', () async {
      final order = buildTestOrder(
        id: 'ORD-108',
        status: OrderProgressStatus.placed,
        customerId: '', // Empty customerId
      );
      orderRepo.orders.add(order);

      final controller = AdminOrderController(
        orderRepository: orderRepo,
        authController: adminAuthController,
        pushDispatchService: pushDispatchService,
        notificationRepository: notificationRepo,
      );

      final success = await controller.updateOrderStatus(
        order,
        OrderProgressStatus.processing,
      );

      expect(success, isTrue);

      final requests = pushDispatchService.dispatchedRequests
          .where((r) => r['action'] == 'customer_order_status_update')
          .toList();
      expect(requests.length, 1);
      expect(requests.first['customerUid'], 'cust_abc_123');
    });
  });
}

import 'dart:math';
import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../models/order_model.dart';
import '../repositories/notification_repository.dart';
import '../repositories/order_repository.dart';
import '../services/analytics_service.dart';
import '../services/firebase_service.dart';
import '../services/push_dispatch_service.dart';

/// Manages customer order history, checkout placements, and live order tracking.
class OrderController extends ChangeNotifier {
  final OrderRepository? _orderRepository;
  final PushDispatchService? _pushDispatchService;
  final NotificationRepository? _notificationRepository;
  final List<OrderModel> _orders = [];
  OrderModel? _currentTrackingOrder;
  String? _currentUserId;
  bool _isLoading = false;
  bool _isPlacingOrder = false;
  int _orderSyncSession = 0;

  OrderController({
    OrderRepository? orderRepository,
    PushDispatchService? pushDispatchService,
    NotificationRepository? notificationRepository,
    bool seedSample = false,
  })  : _orderRepository = orderRepository,
        _pushDispatchService = pushDispatchService,
        _notificationRepository = notificationRepository {
    if (seedSample) {
      _seedInitialSampleOrder();
    }
  }

  // ── Getters ────────────────────────────────────────────────────────────────
  List<OrderModel> get orders => List.unmodifiable(_orders);
  OrderModel? get currentTrackingOrder => _currentTrackingOrder;
  bool get hasOrders => _orders.isNotEmpty;
  bool get isLoading => _isLoading;
  bool get isPlacingOrder => _isPlacingOrder;

  /// Effective UID of the authenticated customer, falling back to Firebase Auth.
  String? get currentUserId {
    if (_currentUserId != null && _currentUserId!.isNotEmpty) {
      return _currentUserId;
    }
    if (FirebaseService.isInitialized && FirebaseService.auth.currentUser != null) {
      return FirebaseService.auth.currentUser!.uid;
    }
    return null;
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  /// Synchronizes and loads all orders placed by the authenticated customer.
  Future<void> loadUserOrders(String? uid) async {
    final sessionId = ++_orderSyncSession;
    _currentUserId = uid;
    _orders.clear();
    _currentTrackingOrder = null;
    final effectiveUid = currentUserId;
    final repo = _orderRepository;

    if (effectiveUid == null || repo == null) {
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final remoteOrders = await repo.getOrders(effectiveUid);
      if (sessionId != _orderSyncSession) return;
      _orders.clear();
      _orders.addAll(remoteOrders);
      if (_orders.isNotEmpty) {
        _currentTrackingOrder = _orders.first;
      }
    } catch (e) {
      debugPrint('[ShopEase:OrderController] Error loading customer orders: $e');
    } finally {
      if (sessionId == _orderSyncSession) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Reloads user orders from Firestore to reflect any status changes made by administrators.
  Future<void> refreshOrders() async {
    final uid = currentUserId;
    if (uid != null) {
      await loadUserOrders(uid);
    }
  }

  /// Places a new order from checkout and persists it to Cloud Firestore.
  ///
  /// Prevents duplicate order creation and returns the created order.
  Future<OrderModel> placeOrder({
    required List<OrderItemModel> items,
    required double subtotal,
    required double discount,
    required double shippingFee,
    required double total,
    required String shippingName,
    required String shippingPhone,
    required String shippingAddress,
    required String shippingCity,
    required String shippingPostalCode,
    required String paymentMethod,
    String? uid,
  }) async {
    if (_isPlacingOrder) {
      throw 'An order is already being processed. Please wait.';
    }

    _isPlacingOrder = true;
    notifyListeners();

    try {
      final customerUid = uid ?? currentUserId;
      final randomDigits = (100000 + Random().nextInt(900000)).toString();
      final trackingCode = 'TRK-AL-$randomDigits';
      final orderId = 'ORD-$randomDigits';

      final newOrder = OrderModel(
        id: orderId,
        customerId: customerUid,
        items: List.from(items),
        subtotal: subtotal,
        discount: discount,
        shippingFee: shippingFee,
        total: total,
        status: OrderProgressStatus.processing,
        shippingName: shippingName,
        shippingPhone: shippingPhone,
        shippingAddress: shippingAddress,
        shippingCity: shippingCity,
        shippingPostalCode: shippingPostalCode,
        paymentMethod: paymentMethod,
        paymentStatus: paymentMethod.toLowerCase().contains('cash') ? 'Pending' : 'Paid',
        trackingNumber: trackingCode,
        courierName: 'AÈRA Express Courier',
        estimatedDelivery: 'Tomorrow, by 6:00 PM',
        createdAt: DateTime.now(),
      );

      // Persist to Cloud Firestore if customer is authenticated
      final repo = _orderRepository;
      if (customerUid != null && repo != null) {
        await repo.createOrder(customerUid, newOrder);
      }

      _orders.insert(0, newOrder);
      _currentTrackingOrder = newOrder;
      notifyListeners();

      debugPrint(
        '[ShopEase:Order] Order created successfully: id=${newOrder.id}, '
        'total=\$${newOrder.total.toStringAsFixed(2)}, items=${newOrder.items.length}, customerUid=$customerUid',
      );

      // Log purchase event to Analytics to power conversion & in-app campaigns
      AnalyticsService.logPurchase(
        orderId: newOrder.id,
        value: newOrder.total,
        itemCount: newOrder.items.length,
      );

      // Customer order confirmation notification
      if (customerUid != null) {
        final orderNotif = AppNotificationModel(
          id: 'notif_order_${newOrder.id}',
          title: 'Order Confirmed: #${newOrder.id}',
          body: 'Thank you for your order of \$${newOrder.total.toStringAsFixed(2)}. Your items are being prepared.',
          type: 'order',
          receivedAt: DateTime.now(),
          targetRoute: '/customer/orders',
          targetId: newOrder.id,
        );
        _notificationRepository?.saveInAppNotification(
          uid: customerUid,
          notification: orderNotif,
        );
        debugPrint(
          '[ShopEase:Notification] In-app notification created: id=${orderNotif.id}, '
          'recipient=$customerUid, title="${orderNotif.title}", targetRoute=${orderNotif.targetRoute}',
        );
        _pushDispatchService?.dispatchCustomerOrderConfirmation(
          customerUid: customerUid,
          order: newOrder,
        );
      }

      // Admin new order push alert
      _pushDispatchService?.dispatchAdminNewOrderAlert(order: newOrder);

      return newOrder;
    } finally {
      _isPlacingOrder = false;
      notifyListeners();
    }
  }

  /// Sets the currently inspected order for the tracking view.
  void selectTrackingOrder(OrderModel order) {
    _currentTrackingOrder = order;
    notifyListeners();
  }

  /// Selects order by ID.
  void selectTrackingOrderById(String orderId) {
    try {
      _currentTrackingOrder = _orders.firstWhere((o) => o.id == orderId);
      notifyListeners();
    } catch (_) {}
  }

  /// Advances the status of the current order for interactive simulation.
  void advanceOrderStatus(String orderId) {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index == -1) return;

    final currentOrder = _orders[index];
    final currentStatusIndex = currentOrder.status.stepIndex;

    if (currentStatusIndex < OrderProgressStatus.values.length - 1) {
      final nextStatus = OrderProgressStatus.values[currentStatusIndex + 1];
      final updated = OrderModel(
        id: currentOrder.id,
        customerId: currentOrder.customerId,
        items: currentOrder.items,
        subtotal: currentOrder.subtotal,
        discount: currentOrder.discount,
        shippingFee: currentOrder.shippingFee,
        total: currentOrder.total,
        status: nextStatus,
        shippingName: currentOrder.shippingName,
        shippingPhone: currentOrder.shippingPhone,
        shippingAddress: currentOrder.shippingAddress,
        shippingCity: currentOrder.shippingCity,
        shippingPostalCode: currentOrder.shippingPostalCode,
        paymentMethod: currentOrder.paymentMethod,
        trackingNumber: currentOrder.trackingNumber,
        courierName: currentOrder.courierName,
        estimatedDelivery: currentOrder.estimatedDelivery,
        createdAt: currentOrder.createdAt,
      );

      _orders[index] = updated;
      if (_currentTrackingOrder?.id == orderId) {
        _currentTrackingOrder = updated;
      }
      notifyListeners();

      // Persist updated status to Firestore
      final uid = currentOrder.customerId ?? _currentUserId;
      final repo = _orderRepository;
      if (uid != null && repo != null) {
        repo.updateOrderStatus(uid, orderId, nextStatus);
      }
    }
  }

  /// Clears customer-specific orders on account sign out or user transition.
  void clearUserData() {
    _orderSyncSession++;
    _currentUserId = null;
    _orders.clear();
    _currentTrackingOrder = null;
    _isLoading = false;
    notifyListeners();
  }

  /// Pre-seeds a sample active order so the tracking screen is immediately demonstrative.
  void _seedInitialSampleOrder() {
    final sampleOrder = OrderModel(
      id: 'ORD-849204',
      items: const [
        OrderItemModel(
          productId: 'p1',
          productName: 'Rare Beauty Soft Pinch Liquid Blush',
          subtitle: 'LIQUID BLUSH',
          size: 'Standard',
          price: 2400.00,
          quantity: 1,
          visualColor: Color(0xFFE898A8),
          visualIcon: Icons.auto_awesome,
        ),
        OrderItemModel(
          productId: 'p2',
          productName: 'Huda Beauty Liquid Matte Lipstick',
          subtitle: 'VELVET MATTE LIPSTICK',
          size: 'Standard',
          price: 2150.00,
          quantity: 1,
          visualColor: Color(0xFFC75B7A),
          visualIcon: Icons.favorite_rounded,
        ),
        OrderItemModel(
          productId: 'p4',
          productName: 'Charlotte Tilbury Hollywood Filter',
          subtitle: 'COMPLEXION BOOSTER',
          size: 'Standard',
          price: 4400.00,
          quantity: 1,
          visualColor: Color(0xFFD4AF37),
          visualIcon: Icons.star_rounded,
        ),
      ],
      subtotal: 8950.00,
      discount: 0.00,
      shippingFee: 0.00,
      total: 8950.00,
      status: OrderProgressStatus.shipped,
      shippingName: 'Aarav Sharma',
      shippingPhone: '+91 98765 43210',
      shippingAddress: '104, Royal Palms Residency, M.G. Road',
      shippingCity: 'Mumbai',
      shippingPostalCode: '400001',
      paymentMethod: 'Credit Card (•••• 4242)',
      trackingNumber: 'TRK-IN-992482',
      courierName: 'AÈRA Express Logistics',
      estimatedDelivery: 'Tomorrow, by 5:30 PM',
      createdAt: DateTime.now().subtract(const Duration(hours: 6)),
    );

    _orders.add(sampleOrder);
    _currentTrackingOrder = sampleOrder;
  }
}

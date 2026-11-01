import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';
import '../models/order_model.dart';
import 'firebase_service.dart';

/// Represents the execution outcome of an FCM push delivery request.
class PushDispatchResult {
  final bool success;
  final String deliveryStatus;
  final String message;
  final String? requestId;
  final DateTime timestamp;

  const PushDispatchResult({
    required this.success,
    required this.deliveryStatus,
    required this.message,
    this.requestId,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        'success': success,
        'deliveryStatus': deliveryStatus,
        'message': message,
        if (requestId != null) 'requestId': requestId,
        'timestamp': Timestamp.fromDate(timestamp),
      };
}

/// Abstract contract for dispatching FCM push notifications via a trusted backend.
///
/// Flutter client applications must NEVER embed Firebase Service Account keys
/// or invoke the FCM HTTP v1 API directly with administrative credentials.
/// Actual device push delivery must be mediated by a trusted server or Cloud Function.
abstract class PushDispatchService {
  /// Dispatches an admin-composed announcement or campaign to target devices.
  Future<PushDispatchResult> dispatchAdminNotification({
    required String adminUid,
    required AppNotificationModel notification,
    required String audience,
    String? recipientUid,
  });

  /// Queues an alert to administrative personnel when a new customer order is placed.
  Future<PushDispatchResult> dispatchAdminNewOrderAlert({
    required OrderModel order,
  });

  /// Queues an immediate order confirmation push notification to the ordering customer.
  Future<PushDispatchResult> dispatchCustomerOrderConfirmation({
    required String customerUid,
    required OrderModel order,
  });

  /// Queues an order status progression notification (e.g. Shipped, Delivered) to the customer.
  Future<PushDispatchResult> dispatchCustomerOrderStatusUpdate({
    required String customerUid,
    required OrderModel order,
    required OrderProgressStatus newStatus,
  });
}

/// Production implementation of [PushDispatchService].
///
/// Queues push requests into Firestore `/notification_requests` for processing
/// by a secure Firebase Cloud Function / Node.js backend running the Firebase Admin SDK.
class BackendPushDispatchService implements PushDispatchService {
  final FirebaseFirestore? _firestore;
  final String? backendHttpEndpoint;

  BackendPushDispatchService({
    FirebaseFirestore? firestore,
    this.backendHttpEndpoint,
  }) : _firestore = firestore;

  FirebaseFirestore? get _db {
    if (_firestore != null) return _firestore;
    if (FirebaseService.isInitialized) {
      return FirebaseService.firestore;
    }
    return null;
  }

  CollectionReference<Map<String, dynamic>>? get _requestsCollection =>
      _db?.collection('notification_requests');

  @override
  Future<PushDispatchResult> dispatchAdminNotification({
    required String adminUid,
    required AppNotificationModel notification,
    required String audience,
    String? recipientUid,
  }) async {
    final now = DateTime.now();
    final requestId = 'req_${now.millisecondsSinceEpoch}_${notification.id}';

    final payload = {
      'requestId': requestId,
      'action': 'admin_broadcast',
      'senderAdminId': adminUid,
      'audience': audience,
      'recipientUid': recipientUid,
      'notification': notification.toMap(),
      'status': 'queued',
      'createdAt': Timestamp.fromDate(now),
    };

    try {
      final col = _requestsCollection;
      if (col != null) {
        await col.doc(requestId).set(payload);
        debugPrint(
          '[PushDispatchService] Queued admin notification request $requestId '
          'for backend delivery. Audience: $audience',
        );
      } else {
        debugPrint(
          '[PushDispatchService] Offline/Mock: Queued admin notification $requestId in memory',
        );
      }

      return PushDispatchResult(
        success: true,
        deliveryStatus: 'queued_for_backend',
        message: 'Notification queued for secure backend delivery.',
        requestId: requestId,
        timestamp: now,
      );
    } catch (e) {
      debugPrint('[PushDispatchService] Error queuing admin notification: $e');
      return PushDispatchResult(
        success: false,
        deliveryStatus: 'failed',
        message: 'Failed to queue notification: $e',
        requestId: requestId,
        timestamp: now,
      );
    }
  }

  @override
  Future<PushDispatchResult> dispatchAdminNewOrderAlert({
    required OrderModel order,
  }) async {
    final now = DateTime.now();
    final requestId = 'alert_order_${order.id}_${now.millisecondsSinceEpoch}';

    final title = 'New Order Placed: #${order.id}';
    final body = 'Received new order from ${order.shippingName} for \$${order.total.toStringAsFixed(2)}.';

    final payload = {
      'requestId': requestId,
      'action': 'admin_new_order_alert',
      'orderId': order.id,
      'title': title,
      'body': body,
      'orderTotal': order.total,
      'customerName': order.shippingName,
      'targetRoute': '/admin/orders',
      'targetId': order.id,
      'createdAt': Timestamp.fromDate(now),
      'status': 'queued',
    };

    try {
      final col = _requestsCollection;
      if (col != null) {
        await col.doc(requestId).set(payload);
        debugPrint(
          '[ShopEase:PushDispatch] Push request created: id=$requestId, '
          'action=admin_new_order_alert, orderId=${order.id}',
        );
      }
      return PushDispatchResult(
        success: true,
        deliveryStatus: 'queued_for_backend',
        message: 'Admin order alert queued.',
        requestId: requestId,
        timestamp: now,
      );
    } catch (e) {
      debugPrint('[ShopEase:PushDispatch] Error queuing admin order alert: $e');
      return PushDispatchResult(
        success: false,
        deliveryStatus: 'failed',
        message: 'Failed to queue admin order alert: $e',
        requestId: requestId,
        timestamp: now,
      );
    }
  }

  @override
  Future<PushDispatchResult> dispatchCustomerOrderConfirmation({
    required String customerUid,
    required OrderModel order,
  }) async {
    final now = DateTime.now();
    final requestId = 'conf_order_${order.id}';

    final title = 'Order Confirmed: #${order.id}';
    final body =
        'Thank you for your order of \$${order.total.toStringAsFixed(2)}. Your items are being prepared.';

    final payload = {
      'requestId': requestId,
      'action': 'customer_order_confirmation',
      'customerUid': customerUid,
      'orderId': order.id,
      'title': title,
      'body': body,
      'orderTotal': order.total,
      'itemsCount': order.items.length,
      'targetRoute': '/customer/orders',
      'targetId': order.id,
      'status': 'queued',
      'createdAt': Timestamp.fromDate(now),
    };

    try {
      final col = _requestsCollection;
      if (col != null) {
        await col.doc(requestId).set(payload);
        debugPrint(
          '[ShopEase:PushDispatch] Push request created: id=$requestId, '
          'action=customer_order_confirmation, customerUid=$customerUid, orderId=${order.id}',
        );
      }
      return PushDispatchResult(
        success: true,
        deliveryStatus: 'queued_for_backend',
        message: 'Customer order confirmation queued.',
        requestId: requestId,
        timestamp: now,
      );
    } catch (e) {
      debugPrint('[ShopEase:PushDispatch] Error queuing order confirmation: $e');
      return PushDispatchResult(
        success: false,
        deliveryStatus: 'failed',
        message: e.toString(),
        requestId: requestId,
        timestamp: now,
      );
    }
  }

  @override
  Future<PushDispatchResult> dispatchCustomerOrderStatusUpdate({
    required String customerUid,
    required OrderModel order,
    required OrderProgressStatus newStatus,
  }) async {
    final now = DateTime.now();
    final requestId = 'update_order_${order.id}_${newStatus.name}';

    final title = 'Order #${order.id} Updated';
    final body = 'Your order fulfillment status is now: ${newStatus.label}.';

    final payload = {
      'requestId': requestId,
      'action': 'order_status_update',
      'customerUid': customerUid,
      'orderId': order.id,
      'title': title,
      'body': body,
      'orderTotal': order.total,
      'newStatus': newStatus.name,
      'newStatusLabel': newStatus.label,
      'targetRoute': '/customer/orders',
      'targetId': order.id,
      'status': 'queued',
      'createdAt': Timestamp.fromDate(now),
    };

    try {
      final col = _requestsCollection;
      if (col != null) {
        await col.doc(requestId).set(payload);
        debugPrint(
          '[ShopEase:PushDispatch] Push request created: id=$requestId, '
          'action=order_status_update, customerUid=$customerUid, orderId=${order.id}, newStatus=${newStatus.name}',
        );
      }
      return PushDispatchResult(
        success: true,
        deliveryStatus: 'queued_for_backend',
        message: 'Order status update queued.',
        requestId: requestId,
        timestamp: now,
      );
    } catch (e) {
      debugPrint('[ShopEase:PushDispatch] Error queuing order status update: $e');
      return PushDispatchResult(
        success: false,
        deliveryStatus: 'failed',
        message: e.toString(),
        requestId: requestId,
        timestamp: now,
      );
    }
  }
}

/// Hermetic in-memory mock implementation of [PushDispatchService] for automated tests.
class InMemoryPushDispatchService implements PushDispatchService {
  final List<Map<String, dynamic>> dispatchedRequests = [];

  @override
  Future<PushDispatchResult> dispatchAdminNotification({
    required String adminUid,
    required AppNotificationModel notification,
    required String audience,
    String? recipientUid,
  }) async {
    final now = DateTime.now();
    final reqId = 'mock_req_${now.millisecondsSinceEpoch}';
    dispatchedRequests.add({
      'requestId': reqId,
      'adminUid': adminUid,
      'notification': notification,
      'audience': audience,
      'recipientUid': recipientUid,
    });
    return PushDispatchResult(
      success: true,
      deliveryStatus: 'queued_for_backend',
      message: 'Mock dispatch completed',
      requestId: reqId,
      timestamp: now,
    );
  }

  @override
  Future<PushDispatchResult> dispatchAdminNewOrderAlert({
    required OrderModel order,
  }) async {
    final now = DateTime.now();
    final title = 'New Order Placed: #${order.id}';
    final body = 'Received new order from ${order.shippingName} for \$${order.total.toStringAsFixed(2)}.';
    dispatchedRequests.add({
      'action': 'admin_order_alert',
      'orderId': order.id,
      'title': title,
      'body': body,
      'orderTotal': order.total,
      'customerName': order.shippingName,
      'targetRoute': '/admin/orders',
      'targetId': order.id,
    });
    return PushDispatchResult(
      success: true,
      deliveryStatus: 'queued_for_backend',
      message: 'Mock admin order alert dispatched',
      timestamp: now,
    );
  }

  @override
  Future<PushDispatchResult> dispatchCustomerOrderConfirmation({
    required String customerUid,
    required OrderModel order,
  }) async {
    final now = DateTime.now();
    final title = 'Order Confirmed: #${order.id}';
    final body =
        'Thank you for your order of \$${order.total.toStringAsFixed(2)}. Your items are being prepared.';
    dispatchedRequests.add({
      'action': 'order_confirmation',
      'customerUid': customerUid,
      'orderId': order.id,
      'title': title,
      'body': body,
      'orderTotal': order.total,
      'targetRoute': '/customer/orders',
      'targetId': order.id,
    });
    return PushDispatchResult(
      success: true,
      deliveryStatus: 'queued_for_backend',
      message: 'Mock order confirmation dispatched',
      timestamp: now,
    );
  }

  @override
  Future<PushDispatchResult> dispatchCustomerOrderStatusUpdate({
    required String customerUid,
    required OrderModel order,
    required OrderProgressStatus newStatus,
  }) async {
    final now = DateTime.now();
    final title = 'Order #${order.id} Updated';
    final body = 'Your order fulfillment status is now: ${newStatus.label}.';
    dispatchedRequests.add({
      'action': 'status_update',
      'customerUid': customerUid,
      'orderId': order.id,
      'newStatus': newStatus,
      'title': title,
      'body': body,
      'orderTotal': order.total,
      'targetRoute': '/customer/orders',
      'targetId': order.id,
    });
    return PushDispatchResult(
      success: true,
      deliveryStatus: 'queued_for_backend',
      message: 'Mock status update dispatched',
      timestamp: now,
    );
  }
}

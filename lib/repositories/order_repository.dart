import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/order_model.dart';
import '../services/firebase_service.dart';

/// Contract defining customer order data operations in Firestore and Admin Fulfillment Center.
abstract class OrderRepository {
  /// Places and saves a new order for the customer identified by [uid].
  Future<void> createOrder(String uid, OrderModel order);

  /// Retrieves orders placed by the customer identified by [uid].
  Future<List<OrderModel>> getOrders(String uid);

  /// Retrieves all orders across all customers (admin fulfillment view).
  Future<List<OrderModel>> getAllOrders();

  /// Updates fulfillment status of an order with optional admin attribution and audit note.
  Future<void> updateOrderStatus(
    String uid,
    String orderId,
    OrderProgressStatus status, {
    String? adminId,
    String? note,
  });
}

/// In-memory implementation of [OrderRepository] for unit/widget testing and offline environments.
class InMemoryOrderRepository implements OrderRepository {
  final Map<String, List<OrderModel>> _userOrders = {};

  InMemoryOrderRepository({bool seedSampleData = false}) {
    if (seedSampleData) {
      _seedSampleOrders();
    }
  }

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

    // If uid is provided, update that list directly
    if (uid.isNotEmpty && _userOrders.containsKey(uid)) {
      final list = _userOrders[uid]!;
      final index = list.indexWhere((o) => o.id == orderId);
      if (index != -1) {
        final existing = list[index];
        final history = List<OrderStatusHistoryEntry>.from(existing.statusHistory)..add(entry);
        list[index] = existing.copyWith(
          status: status,
          updatedAt: DateTime.now(),
          updatedBy: adminId,
          statusHistory: history,
        );
        return;
      }
    }

    // Otherwise search across all customer lists
    for (final list in _userOrders.values) {
      final index = list.indexWhere((o) => o.id == orderId);
      if (index != -1) {
        final existing = list[index];
        final history = List<OrderStatusHistoryEntry>.from(existing.statusHistory)..add(entry);
        list[index] = existing.copyWith(
          status: status,
          updatedAt: DateTime.now(),
          updatedBy: adminId,
          statusHistory: history,
        );
        return;
      }
    }
  }

  void _seedSampleOrders() {
    final now = DateTime.now();

    final order1 = OrderModel(
      id: 'ORD-719401',
      customerId: 'cust-sharma',
      items: const [
        OrderItemModel(
          productId: 'p1',
          productName: 'Rare Beauty Soft Pinch Liquid Blush',
          subtitle: 'LIQUID BLUSH',
          size: 'Standard',
          price: 2400.0,
          quantity: 2,
        ),
      ],
      subtotal: 4800.0,
      discount: 0.0,
      shippingFee: 0.0,
      total: 4800.0,
      status: OrderProgressStatus.placed,
      shippingName: 'Aarav Sharma',
      shippingPhone: '+91 98765 43210',
      shippingAddress: '104, Royal Palms Residency, M.G. Road',
      shippingCity: 'Mumbai',
      shippingPostalCode: '400001',
      paymentMethod: 'Credit Card (•••• 4242)',
      paymentStatus: 'Paid',
      trackingNumber: 'TRK-AL-719401',
      courierName: 'AÈRA Express Courier',
      estimatedDelivery: 'Tomorrow, by 6:00 PM',
      createdAt: now.subtract(const Duration(hours: 3)),
    );

    final order2 = OrderModel(
      id: 'ORD-849204',
      customerId: 'cust-priya',
      items: const [
        OrderItemModel(
          productId: 'p2',
          productName: 'Huda Beauty Liquid Matte Lipstick',
          subtitle: 'VELVET MATTE LIPSTICK',
          size: 'Standard',
          price: 2150.0,
          quantity: 1,
        ),
        OrderItemModel(
          productId: 'p4',
          productName: 'Charlotte Tilbury Hollywood Filter',
          subtitle: 'COMPLEXION BOOSTER',
          size: 'Standard',
          price: 4400.0,
          quantity: 1,
        ),
      ],
      subtotal: 6550.0,
      discount: 300.0,
      shippingFee: 0.0,
      total: 6250.0,
      status: OrderProgressStatus.shipped,
      shippingName: 'Priya Patel',
      shippingPhone: '+91 91234 56789',
      shippingAddress: '42, Sunset Boulevard, Koramangala',
      shippingCity: 'Bengaluru',
      shippingPostalCode: '560034',
      paymentMethod: 'Apple / Google Pay',
      paymentStatus: 'Paid',
      trackingNumber: 'TRK-AL-849204',
      courierName: 'AÈRA Express Courier',
      estimatedDelivery: 'In 2 days',
      createdAt: now.subtract(const Duration(days: 1, hours: 4)),
    );

    final order3 = OrderModel(
      id: 'ORD-912834',
      customerId: 'cust-verma',
      items: const [
        OrderItemModel(
          productId: 'p3',
          productName: 'Dior Addict Lip Glow Oil',
          subtitle: 'NOURISHING GLOSS',
          size: '6 ml',
          price: 3900.0,
          quantity: 1,
        ),
      ],
      subtotal: 3900.0,
      discount: 0.0,
      shippingFee: 150.0,
      total: 4050.0,
      status: OrderProgressStatus.delivered,
      shippingName: 'Rohan Verma',
      shippingPhone: '+91 99887 76655',
      shippingAddress: 'Flat 5B, Skyview Heights, Park Street',
      shippingCity: 'Kolkata',
      shippingPostalCode: '700016',
      paymentMethod: 'Cash on Delivery',
      paymentStatus: 'Paid',
      trackingNumber: 'TRK-AL-912834',
      courierName: 'AÈRA Express Courier',
      estimatedDelivery: 'Delivered',
      createdAt: now.subtract(const Duration(days: 3)),
    );

    _userOrders['cust-sharma'] = [order1];
    _userOrders['cust-priya'] = [order2];
    _userOrders['cust-verma'] = [order3];
  }
}

/// Cloud Firestore implementation of [OrderRepository].
///
/// Stores and retrieves customer orders at `/customers/{uid}/orders/{orderId}`,
/// and queries across all customers using Firestore collection group `orders`.
class FirestoreOrderRepository implements OrderRepository {
  final FirebaseFirestore? _injectedFirestore;
  final InMemoryOrderRepository _fallbackRepo;
  static const Duration _timeout = Duration(seconds: 10);

  FirestoreOrderRepository({
    FirebaseFirestore? firestore,
    InMemoryOrderRepository? fallbackRepo,
  })  : _injectedFirestore = firestore,
        _fallbackRepo = fallbackRepo ?? InMemoryOrderRepository(seedSampleData: true);

  FirebaseFirestore? get _firestore {
    if (_injectedFirestore != null) return _injectedFirestore;
    if (FirebaseService.isInitialized) {
      return FirebaseService.firestore;
    }
    return null;
  }

  CollectionReference<Map<String, dynamic>> _userOrders(FirebaseFirestore db, String uid) =>
      db.collection('customers').doc(uid).collection('orders');

  @override
  Future<void> createOrder(String uid, OrderModel order) async {
    final db = _firestore;
    // Always mirror to fallback repository
    await _fallbackRepo.createOrder(uid, order);

    if (db == null) return;
    try {
      final orderData = order.toMap();
      orderData['createdAt'] = FieldValue.serverTimestamp();
      await _userOrders(db, uid).doc(order.id).set(orderData).timeout(_timeout);
      debugPrint('[ShopEase:OrderRepo] Order ${order.id} saved to Firestore successfully.');
    } on FirebaseException catch (e) {
      debugPrint('[ShopEase:OrderRepo] FirebaseException saving order: ${e.code} - ${e.message}');
      throw 'Failed to save order to Cloud Firestore (${e.code}): ${e.message ?? e.code}';
    } catch (e) {
      debugPrint('[ShopEase:OrderRepo] Unexpected error saving order: $e');
      throw 'An unexpected error occurred while saving your order: $e';
    }
  }

  @override
  Future<List<OrderModel>> getOrders(String uid) async {
    final db = _firestore;
    if (db == null) {
      return _fallbackRepo.getOrders(uid);
    }
    try {
      final snapshot = await _userOrders(db, uid).get().timeout(_timeout);
      if (snapshot.docs.isEmpty) {
        return _fallbackRepo.getOrders(uid);
      }
      final orders = snapshot.docs
          .map((doc) => OrderModel.fromMap(doc.data(), id: doc.id))
          .toList();

      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return orders;
    } on FirebaseException catch (e) {
      debugPrint('[ShopEase:OrderRepo] Firebase error fetching orders: ${e.code} - ${e.message}');
      return _fallbackRepo.getOrders(uid);
    } catch (e) {
      debugPrint('[ShopEase:OrderRepo] Error fetching orders: $e');
      return _fallbackRepo.getOrders(uid);
    }
  }

  @override
  Future<List<OrderModel>> getAllOrders() async {
    final db = _firestore;
    if (db == null) {
      return _fallbackRepo.getAllOrders();
    }
    try {
      // Query collectionGroup 'orders' across all customer subcollections
      final snapshot = await db.collectionGroup('orders').get().timeout(_timeout);
      if (snapshot.docs.isEmpty) {
        return _fallbackRepo.getAllOrders();
      }

      final orders = snapshot.docs
          .map((doc) => OrderModel.fromMap(doc.data(), id: doc.id))
          .toList();

      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return orders;
    } on FirebaseException catch (e) {
      debugPrint('[ShopEase:OrderRepo] Firebase error fetching all orders: ${e.code} - ${e.message}');
      return _fallbackRepo.getAllOrders();
    } catch (e) {
      debugPrint('[ShopEase:OrderRepo] Error fetching all orders: $e');
      return _fallbackRepo.getAllOrders();
    }
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

    // Keep fallback in sync
    await _fallbackRepo.updateOrderStatus(
      uid,
      orderId,
      status,
      adminId: adminId,
      note: note,
    );

    final db = _firestore;
    if (db == null) return;

    try {
      final updateData = <String, dynamic>{
        'status': status.name,
        'updatedAt': FieldValue.serverTimestamp(),
        'statusHistory': FieldValue.arrayUnion([entry.toMap()]),
      };
      if (adminId != null) {
        updateData['updatedBy'] = adminId;
      }

      if (uid.isNotEmpty) {
        await _userOrders(db, uid).doc(orderId).update(updateData).timeout(_timeout);
      } else {
        // Query collection group if customer UID is not directly provided
        final query = await db
            .collectionGroup('orders')
            .where('id', isEqualTo: orderId)
            .limit(1)
            .get()
            .timeout(_timeout);
        if (query.docs.isNotEmpty) {
          await query.docs.first.reference.update(updateData).timeout(_timeout);
        }
      }
    } on FirebaseException catch (e) {
      debugPrint('[ShopEase:OrderRepo] Error updating order status: ${e.code} - ${e.message}');
      throw 'Failed to update order status in Cloud Firestore (${e.code}): ${e.message ?? e.code}';
    } catch (e) {
      debugPrint('[ShopEase:OrderRepo] Error updating status: $e');
      throw 'An unexpected error occurred while updating the order status: $e';
    }
  }
}

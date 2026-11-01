import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../controllers/cart_controller.dart';
import '../models/product_model.dart';
import '../services/firebase_service.dart';
import 'product_repository.dart';

/// Contract defining customer cart data operations in Firestore.
abstract class CartRepository {
  Future<List<CartItem>> getCartItems(String uid, ProductRepository productRepo);
  Future<void> saveCartItem(String uid, CartItem item);
  Future<void> removeCartItem(String uid, String cartKey);
  Future<void> clearCart(String uid);
}

/// Cloud Firestore implementation of [CartRepository].
///
/// Stores and syncs customer cart items at `/customers/{uid}/cart/{cartKey}`.
class FirestoreCartRepository implements CartRepository {
  final FirebaseFirestore? _injectedFirestore;
  static const Duration _timeout = Duration(seconds: 10);

  FirestoreCartRepository({FirebaseFirestore? firestore})
      : _injectedFirestore = firestore;

  FirebaseFirestore get _firestore {
    if (_injectedFirestore != null) return _injectedFirestore;
    if (!FirebaseService.isInitialized) {
      throw 'Firebase is not initialized yet.';
    }
    return FirebaseService.firestore;
  }

  CollectionReference<Map<String, dynamic>> _userCart(String uid) =>
      _firestore.collection('customers').doc(uid).collection('cart');

  @override
  Future<List<CartItem>> getCartItems(
    String uid,
    ProductRepository productRepo,
  ) async {
    if (_injectedFirestore == null && !FirebaseService.isInitialized) {
      return [];
    }
    try {
      final snapshot = await _userCart(uid).get().timeout(_timeout);
      final List<CartItem> items = [];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final productId = data['productId'] as String?;
        if (productId == null || productId.isEmpty) continue;

        final size = data['selectedSize'] as String? ?? 'Standard';
        final quantity = (data['quantity'] as num?)?.toInt() ?? 1;

        var product = await productRepo.getProductById(productId);
        product ??= ProductModel(
          id: productId,
          name: data['productName'] as String? ?? 'Cosmetic Product',
          brand: data['brand'] as String? ?? 'ShopEase',
          subtitle: 'LUXURY COSMETICS',
          volume: size,
          description: 'Luxury cosmetic item',
          price: (data['unitPrice'] as num?)?.toDouble() ?? 999.0,
          imageUrl: data['imageUrl'] as String?,
          categoryId: 'all',
          categoryName: 'Cosmetics',
        );

        items.add(
          CartItem(
            product: product,
            selectedSize: size,
            quantity: quantity,
          ),
        );
      }

      return items;
    } on FirebaseException catch (e) {
      debugPrint('[ShopEase:CartRepo] Firebase error reading cart: ${e.code} - ${e.message}');
      return [];
    } catch (e) {
      debugPrint('[ShopEase:CartRepo] Error reading cart items: $e');
      return [];
    }
  }

  @override
  Future<void> saveCartItem(String uid, CartItem item) async {
    if (_injectedFirestore == null && !FirebaseService.isInitialized) return;
    try {
      await _userCart(uid).doc(item.cartKey).set({
        'cartKey': item.cartKey,
        'productId': item.product.id,
        'productName': item.product.name,
        'brand': item.product.brand,
        'selectedSize': item.selectedSize,
        'quantity': item.quantity,
        'unitPrice': item.product.price,
        'totalPrice': item.totalPrice,
        'imageUrl': item.product.imageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(_timeout);
    } on FirebaseException catch (e) {
      debugPrint('[ShopEase:CartRepo] Error saving cart item: ${e.code} - ${e.message}');
    } catch (e) {
      debugPrint('[ShopEase:CartRepo] Error saving cart item: $e');
    }
  }

  @override
  Future<void> removeCartItem(String uid, String cartKey) async {
    if (_injectedFirestore == null && !FirebaseService.isInitialized) return;
    try {
      await _userCart(uid).doc(cartKey).delete().timeout(_timeout);
    } on FirebaseException catch (e) {
      debugPrint('[ShopEase:CartRepo] Error removing cart item: ${e.code} - ${e.message}');
    } catch (e) {
      debugPrint('[ShopEase:CartRepo] Error removing cart item: $e');
    }
  }

  @override
  Future<void> clearCart(String uid) async {
    if (_injectedFirestore == null && !FirebaseService.isInitialized) return;
    try {
      final snapshot = await _userCart(uid).get().timeout(_timeout);
      if (snapshot.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit().timeout(_timeout);
    } on FirebaseException catch (e) {
      debugPrint('[ShopEase:CartRepo] Error clearing cart: ${e.code} - ${e.message}');
    } catch (e) {
      debugPrint('[ShopEase:CartRepo] Error clearing cart: $e');
    }
  }
}


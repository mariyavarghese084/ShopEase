import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product_model.dart';
import '../repositories/cart_repository.dart';
import '../repositories/product_repository.dart';
import '../services/analytics_service.dart';
import '../services/firebase_service.dart';

/// Item in the customer's luxury shopping cart.
class CartItem {
  final ProductModel product;
  final String selectedSize;
  int quantity;

  CartItem({
    required this.product,
    this.selectedSize = 'Standard',
    this.quantity = 1,
  });

  /// Key uniquely identifying a product variant by ID and selected size.
  String get cartKey => '${product.id}_$selectedSize';

  double get unitPrice => product.price;
  double get totalPrice => unitPrice * quantity;

  Map<String, dynamic> toMap() {
    return {
      'cartKey': cartKey,
      'productId': product.id,
      'productName': product.name,
      'brand': product.brand,
      'price': product.price,
      'imageUrl': product.imageUrl,
      'selectedSize': selectedSize,
      'quantity': quantity,
    };
  }
}

/// Manages shopping cart state, discounts, local storage, and Firestore synchronization.
class CartController extends ChangeNotifier {
  final CartRepository? _cartRepository;
  final ProductRepository? _productRepository;
  final Map<String, CartItem> _items = {};

  String? _currentUserId;
  String? _appliedPromoCode;
  double _discountRate = 0.0; // e.g. 0.20 for 20% off
  String? _promoError;
  bool _isLoading = false;
  int _syncSessionId = 0;

  CartController({
    CartRepository? cartRepository,
    ProductRepository? productRepository,
  })  : _cartRepository = cartRepository,
        _productRepository = productRepository {
    if (FirebaseService.isInitialized && FirebaseService.auth.currentUser != null) {
      _currentUserId = FirebaseService.auth.currentUser!.uid;
    }
    _loadFromLocalCache(_currentUserId);
  }

  // ── Storage Key Partitioning ───────────────────────────────────────────────
  String _cartStorageKey([String? uid]) {
    final effectiveUid = uid ?? currentUserId;
    if (effectiveUid != null && effectiveUid.isNotEmpty) {
      return 'shopease_customer_cart_user_$effectiveUid';
    }
    return 'shopease_customer_cart_guest';
  }

  // ── Getters ────────────────────────────────────────────────────────────────
  List<CartItem> get items => _items.values.toList();
  Map<String, CartItem> get itemMap => Map.unmodifiable(_items);
  bool get isEmpty => _items.isEmpty;
  int get itemCount => _items.values.fold(0, (sum, i) => sum + i.quantity);
  bool get isLoading => _isLoading;

  double get subtotal =>
      _items.values.fold(0.0, (sum, item) => sum + item.totalPrice);

  double get discountAmount => subtotal * _discountRate;

  /// Free express shipping for all orders
  double get shippingCost => 0.00;

  double get totalPrice {
    final net = subtotal - discountAmount + shippingCost;
    return net > 0 ? net : 0.0;
  }

  String? get appliedPromoCode => _appliedPromoCode;
  double get discountRate => _discountRate;
  int get discountPercentage => (_discountRate * 100).round();
  String? get promoError => _promoError;

  /// True if any item currently in the cart is out of stock.
  bool get hasOutOfStockItems => _items.values.any((i) => !i.product.isInStock);

  /// Items in the cart that are currently out of stock.
  List<CartItem> get outOfStockItems =>
      _items.values.where((i) => !i.product.isInStock).toList();

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

  /// Loads cached cart from persistent device storage for a specific customer or guest.
  Future<void> _loadFromLocalCache([String? uid]) async {
    try {
      final key = _cartStorageKey(uid);
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(key);
      if (cachedJson != null && cachedJson.isNotEmpty && _items.isEmpty) {
        final List<dynamic> decoded = jsonDecode(cachedJson);
        for (final entry in decoded) {
          final map = entry as Map<String, dynamic>;
          final pid = map['productId'] as String? ?? '';
          final size = map['selectedSize'] as String? ?? 'Standard';
          final qty = (map['quantity'] as num?)?.toInt() ?? 1;

          ProductModel? product;
          final repo = _productRepository;
          if (repo != null) {
            product = await repo.getProductById(pid);
          }

          product ??= ProductModel(
            id: pid,
            name: map['productName'] as String? ?? 'Cosmetic Product',
            brand: map['brand'] as String? ?? 'ShopEase',
            subtitle: 'LUXURY COSMETICS',
            volume: size,
            description: 'Luxury cosmetic item',
            price: (map['price'] as num?)?.toDouble() ?? 999.0,
            imageUrl: map['imageUrl'] as String?,
            categoryId: 'all',
            categoryName: 'Cosmetics',
          );

          final item = CartItem(
            product: product,
            selectedSize: size,
            quantity: qty,
          );
          _items[item.cartKey] = item;
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[ShopEase:Cart] Local cache read error: $e');
    }
  }

  /// Writes the active cart to persistent device storage under the user's isolated key.
  Future<void> _saveToLocalCache([String? uid]) async {
    try {
      final key = _cartStorageKey(uid);
      final prefs = await SharedPreferences.getInstance();
      final list = _items.values.map((i) => i.toMap()).toList();
      await prefs.setString(key, jsonEncode(list));
    } catch (e) {
      debugPrint('[ShopEase:Cart] Local cache write error: $e');
    }
  }

  /// Clears in-memory cart, resets discounts, and detaches customer UID.
  void clearUserData() {
    _syncSessionId++;
    _currentUserId = null;
    _items.clear();
    _appliedPromoCode = null;
    _discountRate = 0.0;
    _promoError = null;
    _isLoading = false;
    notifyListeners();
  }

  /// Synchronizes cart items with Cloud Firestore for the signed-in user.
  Future<void> syncWithUser(String? uid) async {
    final sessionId = ++_syncSessionId;
    _currentUserId = uid;
    _items.clear();
    _appliedPromoCode = null;
    _discountRate = 0.0;
    _promoError = null;
    _isLoading = true;
    notifyListeners();

    // First load this user's specific local cache (or guest cache if null)
    await _loadFromLocalCache(uid);

    if (sessionId != _syncSessionId) return;

    final effectiveUid = currentUserId;
    final repo = _cartRepository;
    final prodRepo = _productRepository;

    if (effectiveUid == null || repo == null || prodRepo == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      final remoteItems = await repo.getCartItems(effectiveUid, prodRepo);
      if (sessionId != _syncSessionId) return;

      if (remoteItems.isNotEmpty) {
        _items.clear();
        for (final item in remoteItems) {
          _items[item.cartKey] = item;
        }
        await _saveToLocalCache(effectiveUid);
      }
    } catch (e) {
      debugPrint('[ShopEase:Cart] Notice syncing cart with Firestore: $e');
    } finally {
      if (sessionId == _syncSessionId) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// Adds a product to the cart with specified size and quantity and persists to storage and Firestore.
  /// Returns false if the product is out of stock.
  bool addItem(ProductModel product, {int quantity = 1, String? size}) {
    if (!product.isInStock) {
      debugPrint('[ShopEase:Cart] Cannot add out-of-stock product "${product.name}" to cart.');
      return false;
    }

    final chosenSize = size ?? product.volume;
    final key = '${product.id}_$chosenSize';

    if (_items.containsKey(key)) {
      _items[key]!.quantity += quantity;
    } else {
      _items[key] = CartItem(
        product: product,
        selectedSize: chosenSize,
        quantity: quantity,
      );
    }
    notifyListeners();
    _saveToLocalCache(_currentUserId);

    final uid = currentUserId;
    final repo = _cartRepository;
    if (uid != null && repo != null) {
      repo.saveCartItem(uid, _items[key]!);
    }

    // Record add_to_cart event for analytics & in-app messaging campaign targeting
    AnalyticsService.logAddToCart(
      itemId: product.id,
      itemName: product.name,
      itemCategory: product.categoryName,
      price: product.price,
      quantity: quantity,
    );
    return true;
  }

  /// Synchronizes cart items with updated product stock and availability from the catalog.
  void syncProductAvailability(List<ProductModel> currentProducts) {
    bool changed = false;
    final productMap = {for (final p in currentProducts) p.id: p};
    for (final key in _items.keys) {
      final item = _items[key]!;
      if (productMap.containsKey(item.product.id)) {
        final freshProduct = productMap[item.product.id]!;
        if (freshProduct.isAvailable != item.product.isAvailable ||
            freshProduct.stockQuantity != item.product.stockQuantity) {
          _items[key] = CartItem(
            product: freshProduct,
            selectedSize: item.selectedSize,
            quantity: item.quantity,
          );
          changed = true;
        }
      }
    }
    if (changed) {
      notifyListeners();
      _saveToLocalCache(_currentUserId);
    }
  }

  /// Removes an item from the cart and deletes from storage and Firestore.
  void removeItem(String cartKey) {
    _items.remove(cartKey);
    notifyListeners();
    _saveToLocalCache(_currentUserId);

    final uid = currentUserId;
    final repo = _cartRepository;
    if (uid != null && repo != null) {
      repo.removeCartItem(uid, cartKey);
    }
  }

  /// Updates quantity of an item.
  void updateQuantity(String cartKey, int quantity) {
    if (!_items.containsKey(cartKey)) return;
    if (quantity <= 0) {
      removeItem(cartKey);
    } else {
      _items[cartKey]!.quantity = quantity;
      notifyListeners();
      _saveToLocalCache(_currentUserId);

      final uid = currentUserId;
      final repo = _cartRepository;
      if (uid != null && repo != null) {
        repo.saveCartItem(uid, _items[cartKey]!);
      }
    }
  }

  /// Applies a promo code.
  /// Supported valid codes: 'AERA20', 'LUXE20', 'BEAUTY10', 'INDIA10'.
  bool applyPromoCode(String code) {
    final cleanCode = code.trim().toUpperCase();
    _promoError = null;

    if (cleanCode == 'AERA20' || cleanCode == 'LUXE20') {
      _appliedPromoCode = cleanCode;
      _discountRate = 0.20; // 20% discount
      notifyListeners();
      return true;
    } else if (cleanCode == 'SALE10' || cleanCode == 'BEAUTY10' || cleanCode == 'INDIA10') {
      _appliedPromoCode = cleanCode;
      _discountRate = 0.10; // 10% discount
      notifyListeners();
      return true;
    } else {
      _promoError = 'Invalid or expired promo code.';
      notifyListeners();
      return false;
    }
  }

  /// Clears active promo code.
  void removePromoCode() {
    _appliedPromoCode = null;
    _discountRate = 0.0;
    _promoError = null;
    notifyListeners();
  }

  /// Clears all cart items from local state, storage, and Cloud Firestore.
  void clearCart() {
    _items.clear();
    _appliedPromoCode = null;
    _discountRate = 0.0;
    _promoError = null;
    notifyListeners();
    _saveToLocalCache(_currentUserId);

    final repo = _cartRepository;
    final uid = currentUserId;
    if (uid != null && repo != null) {
      repo.clearCart(uid);
    }
  }
}

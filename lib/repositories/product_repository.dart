import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/category_model.dart';
import '../models/product_model.dart';
import '../services/firebase_service.dart';

/// Abstract contract for product and category data retrieval and administrative management.
abstract class ProductRepository {
  Future<List<CategoryModel>> getCategories();
  Future<List<ProductModel>> getFeaturedProducts();
  Future<List<ProductModel>> getProducts({String? categoryId, String? searchQuery});
  Future<ProductModel?> getProductById(String id);
  Future<void> addProduct(ProductModel product);
  Future<void> updateProduct(ProductModel product);
  Future<void> deleteProduct(String id);
  Stream<List<ProductModel>> watchProducts({String? categoryId});
}

/// In-memory implementation of [ProductRepository] for luxury cosmetics & beauty products.
class InMemoryProductRepository implements ProductRepository {
  final List<ProductModel> _products;
  final List<CategoryModel> _categories;
  final StreamController<List<ProductModel>> _productsStreamController =
      StreamController<List<ProductModel>>.broadcast();

  InMemoryProductRepository({
    List<ProductModel>? initialProducts,
    List<CategoryModel>? initialCategories,
  })  : _products = initialProducts != null
            ? List<ProductModel>.from(initialProducts)
            : List<ProductModel>.from(_sampleProducts),
        _categories = initialCategories != null
            ? List<CategoryModel>.from(initialCategories)
            : List<CategoryModel>.from(_sampleCategories);

  static const List<CategoryModel> _sampleCategories = [
    CategoryModel(
      id: 'all',
      name: 'All',
      icon: Icons.auto_awesome,
      itemCount: 42,
    ),
    CategoryModel(
      id: 'blush',
      name: 'Blush & Cheeks',
      icon: Icons.favorite_outline,
      itemCount: 12,
    ),
    CategoryModel(
      id: 'lips',
      name: 'Lips',
      icon: Icons.face_retouching_natural_outlined,
      itemCount: 14,
    ),
    CategoryModel(
      id: 'face',
      name: 'Face & Glow',
      icon: Icons.wb_sunny_outlined,
      itemCount: 16,
    ),
    CategoryModel(
      id: 'eyes',
      name: 'Eyes',
      icon: Icons.remove_red_eye_outlined,
      itemCount: 8,
    ),
    CategoryModel(
      id: 'skincare',
      name: 'Skincare',
      icon: Icons.spa_outlined,
      itemCount: 10,
    ),
  ];

  static const List<ProductModel> _sampleProducts = [
    ProductModel(
      id: 'p1',
      name: 'Soft Pinch Liquid Blush',
      brand: 'Rare Beauty',
      subtitle: 'DEWY LIQUID BLUSH',
      volume: '7.5 ml',
      availableSizes: ['7.5 ml (Full)', '3.2 ml (Mini)'],
      description:
          'A weightless, long-lasting liquid blush that blends effortlessly for a natural, healthy flush. Infused with rich color pigments that stay vibrant all day long.',
      price: 1850.00,
      originalPrice: 2100.00,
      categoryId: 'blush',
      categoryName: 'Blush & Cheeks',
      rating: 4.9,
      reviewCount: 384,
      isFeatured: true,
      stockQuantity: 25,
      tag: 'Bestseller',
      topNote: 'Lotus & Gardenia Botanical Extract',
      heartNote: 'White Water Lily Complex',
      baseNote: 'Dewy Luminous Radiant Finish',
      visualIcon: Icons.favorite_rounded,
      visualColor: Color(0xFFE898A8),
      secondaryColor: Color(0xFFF7D6DC),
      imageUrl: 'Assest/The Viral Blush Beauty Lovers Are Obsessed With.jpeg',
    ),
    ProductModel(
      id: 'p2',
      name: 'Warm Terracotta Mineral Powder',
      brand: 'AÈRA Beauty',
      subtitle: 'BAKED BRONZING POWDER',
      volume: '9 g',
      availableSizes: ['9 g (Standard)', '4.5 g (Travel)'],
      description:
          'A silky baked bronzing mineral powder that imparts sun-warmed dimension and a soft-focus velvet matte finish to warm and contour skin tones.',
      price: 1499.00,
      categoryId: 'face',
      categoryName: 'Face & Glow',
      rating: 4.8,
      reviewCount: 215,
      isFeatured: true,
      stockQuantity: 18,
      tag: 'Popular',
      topNote: 'Ultra-Fine Micronized Minerals',
      heartNote: 'Vitamin E & Jojoba Seed Oil',
      baseNote: 'Warm Velvet Matte Soft-Focus',
      visualIcon: Icons.wb_sunny_outlined,
      visualColor: Color(0xFF3E2F28),
      secondaryColor: Color(0xFF6E5649),
      imageUrl: 'Assest/614037730488778069.jpeg',
    ),
    ProductModel(
      id: 'p3',
      name: 'Positive Light Liquid Luminizer',
      brand: 'Rare Beauty',
      subtitle: 'SILKY LIQUID HIGHLIGHTER',
      volume: '15 ml',
      availableSizes: ['15 ml (Full)', '8 ml (Mini)'],
      description:
          'A silky, second-skin liquid highlighter that creates a lasting, soft-focus radiance while nourishing skin with botanical extracts.',
      price: 2400.00,
      categoryId: 'face',
      categoryName: 'Face & Glow',
      rating: 4.9,
      reviewCount: 290,
      isFeatured: true,
      stockQuantity: 15,
      tag: 'Trending',
      topNote: 'Light-Reflecting Pearl Pigments',
      heartNote: 'Botanical Lotus & Gardenia Blend',
      baseNote: 'Non-Greasy Weightless Glow',
      visualIcon: Icons.auto_awesome,
      visualColor: Color(0xFFC8A87D),
      secondaryColor: Color(0xFFF4ECE1),
      imageUrl: 'Assest/RAL Rare Beauty.jpeg',
    ),
    ProductModel(
      id: 'p4',
      name: 'Beachy Glow Multi-Stick',
      brand: 'AÈRA Beauty',
      subtitle: 'CREAM BLUSH & LIP TINT',
      volume: '8 g',
      availableSizes: ['8 g (Standard)', '4 g (Pocket)'],
      description:
          'An ultra-hydrating, multi-use cream tint for cheeks and lips. Glides effortlessly to impart a fresh dewy tint and instant glow.',
      price: 1299.00,
      categoryId: 'blush',
      categoryName: 'Blush & Cheeks',
      rating: 4.8,
      reviewCount: 195,
      isFeatured: true,
      stockQuantity: 22,
      tag: 'Featured',
      topNote: 'Hydrating Shea Butter',
      heartNote: 'Sweet Almond & Camellia Oil',
      baseNote: 'Dewy Fresh Water-Resistant Tint',
      visualIcon: Icons.local_florist_rounded,
      visualColor: Color(0xFF5B326B),
      secondaryColor: Color(0xFF8B539E),
      imageUrl: 'Assest/Beachy Blush in a Flash.jpeg',
    ),
    ProductModel(
      id: 'p5',
      name: 'Velvet Petal Matte Lipstick',
      brand: 'Luxe Cosmetics',
      subtitle: 'HYDRATING MATTE LIPSTICK',
      volume: '3.8 g',
      availableSizes: ['3.8 g (Full Size)'],
      description:
          'A plush, buttery matte lipstick that wraps lips in rich, comfortable pigmentation with zero drying or feathering throughout the day.',
      price: 1650.00,
      originalPrice: 1950.00,
      categoryId: 'lips',
      categoryName: 'Lips',
      rating: 5.0,
      reviewCount: 240,
      isFeatured: true,
      stockQuantity: 12,
      tag: 'Sale',
      topNote: 'Hyaluronic Acid Spheres',
      heartNote: 'Rosehip & Argan Nourishing Oils',
      baseNote: '12-Hour Cushion Matte Comfort',
      visualIcon: Icons.face_retouching_natural_outlined,
      visualColor: Color(0xFFC27D38),
      secondaryColor: Color(0xFFE8B67B),
      imageUrl: 'Assest/Dreamy lipstick vibes 🌸 AI commercial photography for beauty brands.jpeg',
    ),
    ProductModel(
      id: 'p6',
      name: 'Luxe Velvet Eye Palette',
      brand: 'AÈRA Beauty',
      subtitle: '12-PAN EYESHADOW PALETTE',
      volume: '14 g',
      availableSizes: ['14 g (12 Shades)'],
      description:
          'A curated 12-pan eye palette offering intensely pigmented velvet mattes, buttery satins, and dazzling multidimensional toppers.',
      price: 2899.00,
      categoryId: 'eyes',
      categoryName: 'Eyes',
      rating: 4.9,
      reviewCount: 310,
      isFeatured: true,
      stockQuantity: 30,
      tag: 'Bestseller',
      topNote: 'Triple-Milled Velvet Powders',
      heartNote: 'High-Impact Chromatic Pearls',
      baseNote: 'Crease-Resistant All-Day Hold',
      visualIcon: Icons.remove_red_eye_outlined,
      visualColor: Color(0xFF8A4652),
      secondaryColor: Color(0xFFC97C89),
      imageUrl: 'Assest/1101693127585736227.jpeg',
    ),
    ProductModel(
      id: 'p7',
      name: 'Luxury Beauty Glamour Set',
      brand: 'ShopEase Exclusive',
      subtitle: '5-PIECE COMPLETE MAKEUP SET',
      volume: 'Complete Set',
      availableSizes: ['5-Piece Full Kit'],
      description:
          'The ultimate luxury beauty collection containing liquid blush, velvet lipstick, luminizer highlighter, eye pencil, and cosmetic blending sponge.',
      price: 4499.00,
      originalPrice: 5500.00,
      categoryId: 'face',
      categoryName: 'Face & Glow',
      rating: 5.0,
      reviewCount: 112,
      isFeatured: true,
      stockQuantity: 8,
      tag: 'Limited',
      topNote: 'Full-Face Beauty Essentials',
      heartNote: 'Clean Cruelty-Free Formulations',
      baseNote: 'Luxury Gift Box Packaging',
      visualIcon: Icons.card_giftcard_rounded,
      visualColor: Color(0xFFC8A87D),
      secondaryColor: Color(0xFF8A4652),
      imageUrl: 'Assest/Psd cosmetics beauty products and makeup social media post and discount sale banner design template _ Premium PSD.jpeg',
    ),
    ProductModel(
      id: 'p8',
      name: 'Hydra-Plump Peptide Lip Oil',
      brand: 'AÈRA Beauty',
      subtitle: 'NOURISHING HIGH-SHINE LIP OIL',
      volume: '6.5 ml',
      availableSizes: ['6.5 ml (Standard)'],
      description:
          'A glass-shine lip treatment packed with botanical peptides and vitamin E. Delivers juicy plumpness and deep moisture without any stickiness.',
      price: 999.00,
      categoryId: 'lips',
      categoryName: 'Lips',
      rating: 4.7,
      reviewCount: 142,
      isFeatured: false,
      stockQuantity: 16,
      tag: 'New',
      topNote: 'Multi-Peptide Plumping Complex',
      heartNote: 'Organic Jojoba & Coconut Oil',
      baseNote: 'Cushion Non-Sticky Glass Shine',
      visualIcon: Icons.spa_rounded,
      visualColor: Color(0xFFD49B6A),
      secondaryColor: Color(0xFFF3DEC8),
      imageUrl: 'Assest/1125759238142635105.jpeg',
    ),
    ProductModel(
      id: 'p9',
      name: 'Flawless Filter Foundation',
      brand: 'Luxe Cosmetics',
      subtitle: 'LONGWEAR LUMINOUS FOUNDATION',
      volume: '30 ml',
      availableSizes: ['30 ml (Full)', '15 ml (Travel)'],
      description:
          'A breathable, buildable medium-to-full coverage foundation that seamlessly blurs pores and evens tone with a natural luminous finish.',
      price: 2750.00,
      originalPrice: 3200.00,
      categoryId: 'face',
      categoryName: 'Face & Glow',
      rating: 4.9,
      reviewCount: 164,
      isFeatured: true,
      stockQuantity: 14,
      tag: 'Popular',
      topNote: 'Hyaluronic Acid & Niacinamide',
      heartNote: 'Pore-Blurring Silica Micro-Spheres',
      baseNote: 'Sweat-Resistant 16-Hour Wear',
      visualIcon: Icons.wb_sunny_outlined,
      visualColor: Color(0xFF2C2224),
      secondaryColor: Color(0xFF4A3B32),
      imageUrl: 'Assest/454863631129179235.jpeg',
    ),
    ProductModel(
      id: 'p10',
      name: 'Botanical Glow Herbal Serum',
      brand: 'AÈRA Skincare',
      subtitle: 'ANTIOXIDANT HYDRATING ELIXIR',
      volume: '50 ml',
      availableSizes: ['50 ml (Full)', '25 ml (Travel)'],
      description:
          'A soothing antioxidant face elixir infused with organic green tea, centella asiatica, and pure squalane to deeply repair and replenish skin barriers.',
      price: 2199.00,
      categoryId: 'skincare',
      categoryName: 'Skincare',
      rating: 4.8,
      reviewCount: 118,
      isFeatured: false,
      stockQuantity: 20,
      tag: 'New',
      topNote: 'Organic Centella & Green Tea',
      heartNote: '100% Plant-Derived Squalane',
      baseNote: 'Barrier-Strengthening Ceramides',
      visualIcon: Icons.eco_rounded,
      visualColor: Color(0xFF386641),
      secondaryColor: Color(0xFF6A994E),
      imageUrl: 'Assest/「インテリアグリーン」をセンスよく飾る7つのアイデア.jpeg',
    ),
  ];

  @override
  Future<List<CategoryModel>> getCategories() async {
    await Future.delayed(const Duration(milliseconds: 50));
    return List<CategoryModel>.unmodifiable(_categories);
  }

  @override
  Future<List<ProductModel>> getFeaturedProducts() async {
    await Future.delayed(const Duration(milliseconds: 50));
    return _products.where((p) => p.isFeatured && p.isAvailable).toList();
  }

  @override
  Future<List<ProductModel>> getProducts({
    String? categoryId,
    String? searchQuery,
  }) async {
    await Future.delayed(const Duration(milliseconds: 50));
    var results = List<ProductModel>.from(_products);

    if (categoryId != null && categoryId.isNotEmpty && categoryId != 'all') {
      results = results.where((p) => p.categoryId == categoryId).toList();
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final query = searchQuery.toLowerCase().trim();
      results = results
          .where((p) =>
              p.name.toLowerCase().contains(query) ||
              p.brand.toLowerCase().contains(query) ||
              p.categoryName.toLowerCase().contains(query) ||
              p.description.toLowerCase().contains(query) ||
              p.subtitle.toLowerCase().contains(query))
          .toList();
    }

    return results;
  }

  @override
  Future<ProductModel?> getProductById(String id) async {
    await Future.delayed(const Duration(milliseconds: 50));
    try {
      return _products.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  void _notifyProductsChanged() {
    if (!_productsStreamController.isClosed) {
      _productsStreamController.add(List.unmodifiable(_products));
    }
  }

  @override
  Stream<List<ProductModel>> watchProducts({String? categoryId}) async* {
    yield _filterByCategory(List<ProductModel>.from(_products), categoryId);
    yield* _productsStreamController.stream.map(
      (list) => _filterByCategory(List<ProductModel>.from(list), categoryId),
    );
  }

  List<ProductModel> _filterByCategory(
    List<ProductModel> list,
    String? categoryId,
  ) {
    if (categoryId != null && categoryId.isNotEmpty && categoryId != 'all') {
      return list.where((p) => p.categoryId == categoryId).toList();
    }
    return list;
  }

  @override
  Future<void> addProduct(ProductModel product) async {
    await Future.delayed(const Duration(milliseconds: 50));
    _products.removeWhere((p) => p.id == product.id);
    _products.insert(0, product);
    _notifyProductsChanged();
  }

  @override
  Future<void> updateProduct(ProductModel product) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final index = _products.indexWhere((p) => p.id == product.id);
    if (index != -1) {
      _products[index] = product;
    } else {
      _products.insert(0, product);
    }
    _notifyProductsChanged();
  }

  @override
  Future<void> deleteProduct(String id) async {
    await Future.delayed(const Duration(milliseconds: 50));
    _products.removeWhere((p) => p.id == id);
    _notifyProductsChanged();
  }
}

/// Cloud Firestore implementation of [ProductRepository].
///
/// Stores and retrieves products at `/products/{productId}` and categories at `/categories/{categoryId}`.
/// Gracefully falls back to [InMemoryProductRepository] when Firebase is uninitialized or when the remote collection is empty.
class FirestoreProductRepository implements ProductRepository {
  final FirebaseFirestore? _injectedFirestore;
  final InMemoryProductRepository _inMemoryFallback;
  static const Duration _timeout = Duration(seconds: 10);

  FirestoreProductRepository({
    FirebaseFirestore? firestore,
    InMemoryProductRepository? fallback,
  })  : _injectedFirestore = firestore,
        _inMemoryFallback = fallback ?? InMemoryProductRepository();

  FirebaseFirestore get _firestore {
    if (_injectedFirestore != null) return _injectedFirestore;
    if (!FirebaseService.isInitialized) {
      throw 'Firebase is not initialized yet.';
    }
    return FirebaseService.firestore;
  }

  CollectionReference<Map<String, dynamic>> get _productsRef =>
      _firestore.collection('products');

  CollectionReference<Map<String, dynamic>> get _categoriesRef =>
      _firestore.collection('categories');

  @override
  Future<List<CategoryModel>> getCategories() async {
    if (_injectedFirestore == null && !FirebaseService.isInitialized) {
      return _inMemoryFallback.getCategories();
    }
    try {
      final snap = await _categoriesRef.get().timeout(_timeout);
      if (snap.docs.isEmpty) {
        return _inMemoryFallback.getCategories();
      }
      return snap.docs.map((d) => CategoryModel.fromMap(d.data())).toList();
    } catch (e) {
      debugPrint('[ShopEase:ProductRepo] Notice fetching remote categories: $e');
      return _inMemoryFallback.getCategories();
    }
  }

  @override
  Future<List<ProductModel>> getFeaturedProducts() async {
    final all = await getProducts();
    return all.where((p) => p.isFeatured && p.isAvailable).toList();
  }

  @override
  Future<List<ProductModel>> getProducts({
    String? categoryId,
    String? searchQuery,
  }) async {
    if (_injectedFirestore == null && !FirebaseService.isInitialized) {
      return _inMemoryFallback.getProducts(
        categoryId: categoryId,
        searchQuery: searchQuery,
      );
    }
    try {
      final snap = await _productsRef.get().timeout(_timeout);
      if (snap.docs.isEmpty) {
        return _inMemoryFallback.getProducts(
          categoryId: categoryId,
          searchQuery: searchQuery,
        );
      }

      var products = snap.docs.map((doc) {
        final data = doc.data();
        data.putIfAbsent('id', () => doc.id);
        return ProductModel.fromMap(data);
      }).toList();

      if (categoryId != null && categoryId.isNotEmpty && categoryId != 'all') {
        products = products.where((p) => p.categoryId == categoryId).toList();
      }

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final query = searchQuery.toLowerCase().trim();
        products = products
            .where((p) =>
                p.name.toLowerCase().contains(query) ||
                p.brand.toLowerCase().contains(query) ||
                p.categoryName.toLowerCase().contains(query) ||
                p.description.toLowerCase().contains(query) ||
                p.subtitle.toLowerCase().contains(query))
            .toList();
      }

      return products;
    } catch (e) {
      debugPrint('[ShopEase:ProductRepo] Notice fetching remote products: $e');
      return _inMemoryFallback.getProducts(
        categoryId: categoryId,
        searchQuery: searchQuery,
      );
    }
  }

  @override
  Future<ProductModel?> getProductById(String id) async {
    if (_injectedFirestore == null && !FirebaseService.isInitialized) {
      return _inMemoryFallback.getProductById(id);
    }
    try {
      final doc = await _productsRef.doc(id).get().timeout(_timeout);
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        data.putIfAbsent('id', () => doc.id);
        return ProductModel.fromMap(data);
      }
      return _inMemoryFallback.getProductById(id);
    } catch (e) {
      debugPrint('[ShopEase:ProductRepo] Notice fetching remote product by id: $e');
      return _inMemoryFallback.getProductById(id);
    }
  }

  @override
  Future<void> addProduct(ProductModel product) async {
    // Keep local fallback in sync
    await _inMemoryFallback.addProduct(product);

    if (_injectedFirestore == null && !FirebaseService.isInitialized) {
      return;
    }

    try {
      final data = product.toMap();
      await _productsRef.doc(product.id).set(data).timeout(_timeout);
    } on FirebaseException catch (e) {
      debugPrint('[ShopEase:ProductRepo] FirebaseException adding product: ${e.code} - ${e.message}');
      throw 'Failed to save product to Cloud Firestore: ${e.message ?? e.code}';
    } catch (e) {
      debugPrint('[ShopEase:ProductRepo] Unexpected error adding product: $e');
      throw 'An error occurred while saving the product: $e';
    }
  }

  @override
  Future<void> updateProduct(ProductModel product) async {
    await _inMemoryFallback.updateProduct(product);

    if (_injectedFirestore == null && !FirebaseService.isInitialized) {
      return;
    }

    try {
      final data = product.toMap();
      await _productsRef
          .doc(product.id)
          .set(data, SetOptions(merge: true))
          .timeout(_timeout);
    } on FirebaseException catch (e) {
      debugPrint('[ShopEase:ProductRepo] FirebaseException updating product: ${e.code} - ${e.message}');
      throw 'Failed to update product in Cloud Firestore: ${e.message ?? e.code}';
    } catch (e) {
      debugPrint('[ShopEase:ProductRepo] Unexpected error updating product: $e');
      throw 'An error occurred while updating the product: $e';
    }
  }

  @override
  Stream<List<ProductModel>> watchProducts({String? categoryId}) {
    if (_injectedFirestore == null && !FirebaseService.isInitialized) {
      return _inMemoryFallback.watchProducts(categoryId: categoryId);
    }
    return _productsRef.snapshots().asyncMap((snap) async {
      if (snap.docs.isEmpty) {
        return _inMemoryFallback.getProducts(categoryId: categoryId);
      }
      var products = snap.docs.map((doc) {
        final data = doc.data();
        data.putIfAbsent('id', () => doc.id);
        return ProductModel.fromMap(data);
      }).toList();

      if (categoryId != null && categoryId.isNotEmpty && categoryId != 'all') {
        products = products.where((p) => p.categoryId == categoryId).toList();
      }
      return products;
    }).handleError((e) {
      debugPrint('[ShopEase:ProductRepo] Error watching remote products: $e');
      return _inMemoryFallback.watchProducts(categoryId: categoryId);
    });
  }

  @override
  Future<void> deleteProduct(String id) async {
    await _inMemoryFallback.deleteProduct(id);

    if (_injectedFirestore == null && !FirebaseService.isInitialized) {
      return;
    }

    try {
      await _productsRef.doc(id).delete().timeout(_timeout);
    } on FirebaseException catch (e) {
      debugPrint('[ShopEase:ProductRepo] FirebaseException deleting product: ${e.code} - ${e.message}');
      throw 'Failed to delete product from Cloud Firestore: ${e.message ?? e.code}';
    } catch (e) {
      debugPrint('[ShopEase:ProductRepo] Unexpected error deleting product: $e');
      throw 'An error occurred while deleting the product: $e';
    }
  }
}

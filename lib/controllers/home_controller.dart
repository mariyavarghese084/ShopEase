import 'dart:async';
import 'package:flutter/material.dart';
import '../models/category_model.dart';
import '../models/product_model.dart';
import '../repositories/favorites_repository.dart';
import '../repositories/product_repository.dart';
import '../services/firebase_service.dart';

/// Manages customer shopping home screen state using ChangeNotifier.
///
/// Coordinates product fetching, category filtering, search queries,
/// favorites, and navigation index.
class HomeController extends ChangeNotifier {
  final ProductRepository _productRepository;
  final FavoritesRepository? _favoritesRepository;
  StreamSubscription<List<ProductModel>>? _productsSubscription;

  HomeController({
    ProductRepository? productRepository,
    FavoritesRepository? favoritesRepository,
  })  : _productRepository = productRepository ?? InMemoryProductRepository(),
        _favoritesRepository = favoritesRepository {
    loadHomeData();
  }

  // ── State Variables ────────────────────────────────────────────────────────
  List<CategoryModel> _categories = [];
  List<ProductModel> _featuredProducts = [];
  List<ProductModel> _allProducts = [];
  List<ProductModel> _displayedProducts = [];
  String _selectedCategoryId = 'all';
  String _searchQuery = '';
  bool _isLoading = true;
  String? _errorMessage;
  int _bottomNavIndex = 0;
  final Set<String> _favoriteIds = {};
  String? _currentUserId;
  int _favSyncSession = 0;
  int _cartBadgeCount = 0;

  // ── Getters ────────────────────────────────────────────────────────────────
  List<CategoryModel> get categories => List.unmodifiable(_categories);
  List<ProductModel> get featuredProducts =>
      List.unmodifiable(_featuredProducts);
  List<ProductModel> get allProducts => List.unmodifiable(_allProducts);
  List<ProductModel> get displayedProducts =>
      List.unmodifiable(_displayedProducts);
  String get selectedCategoryId => _selectedCategoryId;
  String get searchQuery => _searchQuery;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get bottomNavIndex => _bottomNavIndex;
  int get cartBadgeCount => _cartBadgeCount;

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

  bool isFavorite(String productId) => _favoriteIds.contains(productId);

  /// Retrieves a product by ID from the cached catalog.
  ProductModel? getProductById(String id) {
    try {
      return _allProducts.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  /// Fetches initial categories, featured items, and category-filtered products.
  Future<void> loadHomeData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _productRepository.getCategories(),
        _productRepository.getFeaturedProducts(),
        _productRepository.getProducts(categoryId: 'all'),
        _productRepository.getProducts(
          categoryId: _selectedCategoryId,
          searchQuery: _searchQuery.trim(),
        ),
      ]);

      _categories = results[0] as List<CategoryModel>;
      _featuredProducts = results[1] as List<ProductModel>;
      _allProducts = results[2] as List<ProductModel>;
      _displayedProducts = results[3] as List<ProductModel>;
      _listenToProductUpdates();
    } catch (e) {
      _errorMessage = 'Failed to load store data. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _listenToProductUpdates() {
    _productsSubscription?.cancel();
    _productsSubscription = _productRepository.watchProducts().listen(
      (products) {
        _allProducts = products;
        _featuredProducts =
            _allProducts.where((p) => p.isFeatured && p.isAvailable).toList();
        _applyFilters();
        notifyListeners();
      },
      onError: (e) {
        debugPrint('[ShopEase:HomeController] Error in product stream: $e');
      },
    );
  }

  void _applyFilters() {
    var list = List<ProductModel>.from(_allProducts);
    if (_selectedCategoryId.isNotEmpty && _selectedCategoryId != 'all') {
      list = list.where((p) => p.categoryId == _selectedCategoryId).toList();
    }
    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.toLowerCase().trim();
      list = list
          .where((p) =>
              p.name.toLowerCase().contains(query) ||
              p.brand.toLowerCase().contains(query) ||
              p.categoryName.toLowerCase().contains(query) ||
              p.description.toLowerCase().contains(query) ||
              p.subtitle.toLowerCase().contains(query))
          .toList();
    }
    _displayedProducts = list;
  }

  /// Filters products by category.
  Future<void> selectCategory(String categoryId) async {
    if (_selectedCategoryId == categoryId && _errorMessage == null) return;

    _selectedCategoryId = categoryId;
    _applyFilters();
    notifyListeners();
  }

  /// Updates search query and filters products in real-time.
  Future<void> setSearchQuery(String query) async {
    if (_searchQuery == query) return;
    _searchQuery = query;
    _applyFilters();
    notifyListeners();
  }

  /// Clears active search.
  void clearSearch() {
    if (_searchQuery.isEmpty) return;
    setSearchQuery('');
  }

  /// Syncs favorites with Firestore for an authenticated customer.
  Future<void> syncFavoritesWithUser(String? uid) async {
    final sessionId = ++_favSyncSession;
    _currentUserId = uid;
    _favoriteIds.clear();
    notifyListeners();

    final effectiveUid = currentUserId;
    final repo = _favoritesRepository;
    if (effectiveUid == null || repo == null) {
      return;
    }

    try {
      final remoteFavorites = await repo.getFavorites(effectiveUid);
      if (sessionId != _favSyncSession) return;
      if (remoteFavorites.isNotEmpty) {
        _favoriteIds.clear();
        _favoriteIds.addAll(remoteFavorites);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[ShopEase:Home] Notice loading customer favorites: $e');
    }
  }

  /// Toggles favorite state of a product and persists to Firestore.
  void toggleFavorite(String productId) {
    final isFav = _favoriteIds.contains(productId);
    final repo = _favoritesRepository;
    final uid = currentUserId;

    if (isFav) {
      _favoriteIds.remove(productId);
      if (uid != null && repo != null) {
        repo.removeFavorite(uid, productId);
      }
    } else {
      _favoriteIds.add(productId);
      if (uid != null && repo != null) {
        final product = getProductById(productId);
        repo.addFavorite(
          uid,
          productId,
          extraData: product != null
              ? {
                  'productName': product.name,
                  'brand': product.brand,
                  'price': product.price,
                  'imageUrl': product.imageUrl,
                }
              : null,
        );
      }
    }
    notifyListeners();
  }

  /// Clears customer-specific favorites on sign out or account switch.
  void clearUserData() {
    _favSyncSession++;
    _currentUserId = null;
    _favoriteIds.clear();
    notifyListeners();
  }

  /// Increments or updates the cart badge.
  void addToCartPreview(String productId) {
    _cartBadgeCount++;
    notifyListeners();
  }

  /// Updates current navigation bar tab index.
  void setBottomNavIndex(int index) {
    if (_bottomNavIndex == index) return;
    _bottomNavIndex = index;
    notifyListeners();
  }

  /// Refreshes all data.
  Future<void> refresh() => loadHomeData();

  @override
  void dispose() {
    _productsSubscription?.cancel();
    super.dispose();
  }
}

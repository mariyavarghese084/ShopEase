import 'package:flutter/material.dart';
import '../models/category_model.dart';
import '../models/product_model.dart';
import '../repositories/product_repository.dart';

/// Manages administrative product catalog state, search, filtering, and CRUD operations.
class AdminProductController extends ChangeNotifier {
  final ProductRepository _productRepository;

  List<ProductModel> _products = [];
  List<CategoryModel> _categories = [];
  String _searchQuery = '';
  String _selectedCategoryId = 'all';
  String _stockFilter = 'all'; // 'all', 'in_stock', 'low_stock', 'out_of_stock', 'inactive'

  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;

  AdminProductController({required ProductRepository productRepository})
      : _productRepository = productRepository {
    loadProducts();
  }

  // ── Getters ────────────────────────────────────────────────────────────────
  List<ProductModel> get products => List.unmodifiable(_products);
  List<CategoryModel> get categories => List.unmodifiable(_categories);
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  String get searchQuery => _searchQuery;
  String get selectedCategoryId => _selectedCategoryId;
  String get stockFilter => _stockFilter;

  // ── Inventory Metrics ──────────────────────────────────────────────────────
  int get totalProductCount => _products.length;
  int get inStockCount =>
      _products.where((p) => p.isAvailable && p.stockQuantity > 0).length;
  int get lowStockCount => _products
      .where((p) => p.isAvailable && p.stockQuantity > 0 && p.stockQuantity <= 5)
      .length;
  int get outOfStockCount =>
      _products.where((p) => !p.isAvailable || p.stockQuantity <= 0).length;
  double get totalInventoryValue =>
      _products.fold(0.0, (sum, p) => sum + (p.price * p.stockQuantity));

  /// Filtered list based on search text, category, and inventory status.
  List<ProductModel> get filteredProducts {
    var list = List<ProductModel>.from(_products);

    // 1. Category Filter
    if (_selectedCategoryId.isNotEmpty && _selectedCategoryId != 'all') {
      list = list.where((p) => p.categoryId == _selectedCategoryId).toList();
    }

    // 2. Stock / Status Filter
    if (_stockFilter == 'in_stock') {
      list = list.where((p) => p.isAvailable && p.stockQuantity > 0).toList();
    } else if (_stockFilter == 'low_stock') {
      list = list
          .where((p) => p.isAvailable && p.stockQuantity > 0 && p.stockQuantity <= 5)
          .toList();
    } else if (_stockFilter == 'out_of_stock') {
      list = list.where((p) => p.isAvailable && p.stockQuantity <= 0).toList();
    } else if (_stockFilter == 'inactive') {
      list = list.where((p) => !p.isAvailable).toList();
    }

    // 3. Search Query
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list
          .where((p) =>
              p.name.toLowerCase().contains(q) ||
              p.brand.toLowerCase().contains(q) ||
              p.categoryName.toLowerCase().contains(q) ||
              p.description.toLowerCase().contains(q) ||
              p.subtitle.toLowerCase().contains(q))
          .toList();
    }

    return list;
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  /// Fetches products and categories from the active repository.
  Future<void> loadProducts() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _productRepository.getCategories(),
        _productRepository.getProducts(),
      ]);

      _categories = results[0] as List<CategoryModel>;
      _products = results[1] as List<ProductModel>;
    } catch (e) {
      _errorMessage = 'Failed to load catalog: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sets the real-time search query.
  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    notifyListeners();
  }

  /// Selects the active category filter.
  void selectCategory(String categoryId) {
    if (_selectedCategoryId == categoryId) return;
    _selectedCategoryId = categoryId;
    notifyListeners();
  }

  /// Selects the active inventory/stock filter.
  void setStockFilter(String filter) {
    if (_stockFilter == filter) return;
    _stockFilter = filter;
    notifyListeners();
  }

  /// Validates and saves a product (create or update) to the repository and Firestore.
  Future<bool> saveProduct(ProductModel product, {bool isEditing = false}) async {
    if (_isSaving) return false;

    // Validation
    final nameTrimmed = product.name.trim();
    if (nameTrimmed.isEmpty) {
      _errorMessage = 'Product name is required.';
      notifyListeners();
      return false;
    }

    if (product.price <= 0) {
      _errorMessage = 'Price must be a positive number greater than ₹0.';
      notifyListeners();
      return false;
    }

    if (product.originalPrice != null && product.originalPrice! < 0) {
      _errorMessage = 'Original price cannot be negative.';
      notifyListeners();
      return false;
    }

    if (product.stockQuantity < 0) {
      _errorMessage = 'Stock quantity cannot be negative.';
      notifyListeners();
      return false;
    }

    if (product.categoryId.trim().isEmpty) {
      _errorMessage = 'Please assign a category to the product.';
      notifyListeners();
      return false;
    }

    _isSaving = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      if (isEditing) {
        await _productRepository.updateProduct(product);
        final index = _products.indexWhere((p) => p.id == product.id);
        if (index != -1) {
          _products[index] = product;
        } else {
          _products.insert(0, product);
        }
        _successMessage = 'Product "${product.name}" updated successfully.';
      } else {
        await _productRepository.addProduct(product);
        _products.removeWhere((p) => p.id == product.id);
        _products.insert(0, product);
        _successMessage = 'Product "${product.name}" added to catalog.';
      }
      return true;
    } catch (e) {
      _errorMessage = 'Failed to save product: $e';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Deletes a product from the catalog.
  Future<bool> deleteProduct(String productId) async {
    if (_isSaving) return false;

    _isSaving = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      await _productRepository.deleteProduct(productId);
      _products.removeWhere((p) => p.id == productId);
      _successMessage = 'Product successfully removed from catalog.';
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete product: $e';
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Toggles product availability / archived state.
  Future<bool> toggleAvailability(ProductModel product) async {
    final updated = product.copyWith(isAvailable: !product.isAvailable);
    return await saveProduct(updated, isEditing: true);
  }

  /// Quickly updates stock quantity for inventory tracking.
  Future<bool> updateStockQuantity(ProductModel product, int newStock) async {
    if (newStock < 0) {
      _errorMessage = 'Stock cannot be negative.';
      notifyListeners();
      return false;
    }
    final updated = product.copyWith(
      stockQuantity: newStock,
      isAvailable: newStock > 0 ? true : product.isAvailable,
    );
    return await saveProduct(updated, isEditing: true);
  }

  /// Clears active feedback messages.
  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }
}


import 'package:flutter/material.dart';
import '../models/customer_model.dart';
import '../models/order_model.dart';
import '../repositories/customer_repository.dart';
import '../repositories/order_repository.dart';
import 'auth_controller.dart';

/// Manages customer directory data, order totals, and search for administrators.
class AdminCustomerController extends ChangeNotifier {
  final CustomerRepository _customerRepository;
  final OrderRepository _orderRepository;
  final AuthController? _authController;

  final List<CustomerModel> _allCustomers = [];
  final List<OrderModel> _allOrders = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';
  CustomerModel? _selectedCustomer;

  AdminCustomerController({
    required CustomerRepository customerRepository,
    required OrderRepository orderRepository,
    AuthController? authController,
  })  : _customerRepository = customerRepository,
        _orderRepository = orderRepository,
        _authController = authController {
    loadCustomers();
  }

  // ── Getters ────────────────────────────────────────────────────────────────
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  CustomerModel? get selectedCustomer => _selectedCustomer;
  List<CustomerModel> get allCustomers => List.unmodifiable(_allCustomers);

  /// Filtered customers matching the search query (by full name or email).
  List<CustomerModel> get filteredCustomers {
    if (_searchQuery.trim().isEmpty) {
      return List.unmodifiable(_allCustomers);
    }
    final query = _searchQuery.trim().toLowerCase();
    return _allCustomers.where((customer) {
      final nameMatch = customer.fullName.toLowerCase().contains(query);
      final emailMatch = customer.email.toLowerCase().contains(query);
      final phoneMatch = (customer.phoneNumber ?? '').toLowerCase().contains(query);
      return nameMatch || emailMatch || phoneMatch;
    }).toList();
  }

  // ── Customer Metric Helpers ────────────────────────────────────────────────

  /// Retrieves all orders associated with a specific customer [uid].
  List<OrderModel> getCustomerOrders(String uid) {
    final list = _allOrders.where((o) => o.customerId == uid).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Returns total number of orders placed by customer [uid].
  int getOrderCount(String uid) {
    return _allOrders.where((o) => o.customerId == uid).length;
  }

  /// Calculates total monetary expenditure for customer [uid] excluding cancelled orders.
  double getTotalSpent(String uid) {
    return _allOrders
        .where((o) => o.customerId == uid && o.status != OrderProgressStatus.cancelled)
        .fold(0.0, (sum, o) => sum + o.total);
  }

  /// Retrieves the latest known shipping address from the customer's placed orders.
  String? getLatestShippingAddress(String uid) {
    final orders = getCustomerOrders(uid);
    if (orders.isNotEmpty) {
      final latest = orders.first;
      final parts = <String>[
        latest.shippingAddress,
        latest.shippingCity,
        latest.shippingPostalCode,
      ].where((s) => s.trim().isNotEmpty).toList();
      if (parts.isNotEmpty) {
        return parts.join(', ');
      }
    }
    return null;
  }

  // ── KPI Summary ────────────────────────────────────────────────────────────

  int get totalCustomersCount => _allCustomers.length;

  int get activeBuyersCount =>
      _allCustomers.where((c) => getOrderCount(c.uid) > 0).length;

  double get totalCustomerRevenue => _allOrders
      .where((o) => o.status != OrderProgressStatus.cancelled)
      .fold(0.0, (sum, o) => sum + o.total);

  int get newCustomersThisMonth {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    return _allCustomers
        .where((c) => c.createdAt.isAfter(firstDayOfMonth))
        .length;
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void selectCustomer(CustomerModel? customer) {
    _selectedCustomer = customer;
    notifyListeners();
  }

  /// Loads real customer documents and cross-customer orders.
  Future<void> loadCustomers() async {
    // Check administrative authorization if authController is provided
    final auth = _authController;
    if (auth != null && auth.isAuthenticated && !auth.isAdmin) {
      _errorMessage = 'Access denied. Administrator privileges required.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final customersFuture = _customerRepository.getAllCustomers();
      final ordersFuture = _orderRepository.getAllOrders();

      final results = await Future.wait([customersFuture, ordersFuture]);

      _allCustomers.clear();
      _allCustomers.addAll(results[0] as List<CustomerModel>);

      _allOrders.clear();
      _allOrders.addAll(results[1] as List<OrderModel>);

      debugPrint('[ShopEase:AdminCustomer] Loaded ${_allCustomers.length} customers and ${_allOrders.length} orders');
    } catch (e) {
      debugPrint('[ShopEase:AdminCustomer] Error loading customers: $e');
      _errorMessage = 'Failed to load customer directory: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

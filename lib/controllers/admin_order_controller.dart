import 'package:flutter/material.dart';
import '../models/notification_model.dart';
import '../models/order_model.dart';
import '../repositories/notification_repository.dart';
import '../repositories/order_repository.dart';
import '../services/push_dispatch_service.dart';
import 'auth_controller.dart';

/// Manages cross-customer order lists, status transitions, search, and KPIs for administrators.
class AdminOrderController extends ChangeNotifier {
  final OrderRepository _orderRepository;
  final AuthController? _authController;
  final PushDispatchService? _pushDispatchService;
  final NotificationRepository? _notificationRepository;

  final List<OrderModel> _allOrders = [];
  bool _isLoading = false;
  bool _isUpdating = false;
  String? _errorMessage;
  OrderModel? _selectedOrder;

  // Filter & Search states
  String _searchQuery = '';
  OrderProgressStatus? _statusFilter;
  String _paymentStatusFilter = 'All';
  String _dateFilter = 'All'; // 'All', 'Today', 'Last 7 Days', 'Last 30 Days'
  String _sortBy = 'newest'; // 'newest', 'oldest', 'highest_amount', 'lowest_amount'

  AdminOrderController({
    required OrderRepository orderRepository,
    AuthController? authController,
    PushDispatchService? pushDispatchService,
    NotificationRepository? notificationRepository,
  })  : _orderRepository = orderRepository,
        _authController = authController,
        _pushDispatchService = pushDispatchService,
        _notificationRepository = notificationRepository {
    loadOrders();
  }

  // ── Getters ────────────────────────────────────────────────────────────────
  bool get isLoading => _isLoading;
  bool get isUpdating => _isUpdating;
  String? get errorMessage => _errorMessage;
  OrderModel? get selectedOrder => _selectedOrder;

  String get searchQuery => _searchQuery;
  OrderProgressStatus? get statusFilter => _statusFilter;
  String get paymentStatusFilter => _paymentStatusFilter;
  String get dateFilter => _dateFilter;
  String get sortBy => _sortBy;

  List<OrderModel> get allOrders => List.unmodifiable(_allOrders);

  /// Returns filtered and sorted orders matching all active filter criteria.
  List<OrderModel> get filteredOrders {
    var result = List<OrderModel>.from(_allOrders);

    // 1. Search Query filter (ID, shipping name, phone, city)
    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.trim().toLowerCase();
      result = result.where((order) {
        final idMatch = order.id.toLowerCase().contains(query);
        final nameMatch = order.shippingName.toLowerCase().contains(query);
        final phoneMatch = order.shippingPhone.toLowerCase().contains(query);
        final cityMatch = order.shippingCity.toLowerCase().contains(query);
        final custMatch = (order.customerId ?? '').toLowerCase().contains(query);
        final trackingMatch = order.trackingNumber.toLowerCase().contains(query);
        return idMatch || nameMatch || phoneMatch || cityMatch || custMatch || trackingMatch;
      }).toList();
    }

    // 2. Fulfillment Status filter
    if (_statusFilter != null) {
      result = result.where((order) => order.status == _statusFilter).toList();
    }

    // 3. Payment Status filter
    if (_paymentStatusFilter != 'All') {
      result = result.where((order) {
        return order.paymentStatus.toLowerCase() == _paymentStatusFilter.toLowerCase();
      }).toList();
    }

    // 4. Date filter
    if (_dateFilter != 'All') {
      final now = DateTime.now();
      DateTime cutoff;
      if (_dateFilter == 'Today') {
        cutoff = DateTime(now.year, now.month, now.day);
      } else if (_dateFilter == 'Last 7 Days') {
        cutoff = now.subtract(const Duration(days: 7));
      } else if (_dateFilter == 'Last 30 Days') {
        cutoff = now.subtract(const Duration(days: 30));
      } else {
        cutoff = DateTime(1970);
      }
      result = result.where((order) => order.createdAt.isAfter(cutoff)).toList();
    }

    // 5. Sorting
    switch (_sortBy) {
      case 'oldest':
        result.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case 'highest_amount':
        result.sort((a, b) => b.total.compareTo(a.total));
        break;
      case 'lowest_amount':
        result.sort((a, b) => a.total.compareTo(b.total));
        break;
      case 'newest':
      default:
        result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }

    return result;
  }

  // ── Metrics & KPIs ─────────────────────────────────────────────────────────
  int get totalOrdersCount => _allOrders.length;

  double get totalRevenue => _allOrders
      .where((o) => o.status != OrderProgressStatus.cancelled)
      .fold(0.0, (sum, o) => sum + o.total);

  int get pendingFulfillmentCount => _allOrders
      .where((o) =>
          o.status == OrderProgressStatus.placed ||
          o.status == OrderProgressStatus.processing)
      .length;

  int get inTransitCount => _allOrders
      .where((o) =>
          o.status == OrderProgressStatus.shipped ||
          o.status == OrderProgressStatus.outForDelivery)
      .length;

  int get deliveredCount => _allOrders
      .where((o) => o.status == OrderProgressStatus.delivered)
      .length;

  int get cancelledCount => _allOrders
      .where((o) => o.status == OrderProgressStatus.cancelled)
      .length;

  // ── Actions ────────────────────────────────────────────────────────────────

  /// Fetches all customer orders across Cloud Firestore.
  Future<void> loadOrders() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final orders = await _orderRepository.getAllOrders();
      _allOrders.clear();
      _allOrders.addAll(orders);

      if (_selectedOrder != null) {
        final match = _allOrders.where((o) => o.id == _selectedOrder!.id);
        _selectedOrder = match.isNotEmpty ? match.first : null;
      }
    } catch (e) {
      _errorMessage = 'Failed to load orders: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setStatusFilter(OrderProgressStatus? status) {
    _statusFilter = status;
    notifyListeners();
  }

  void setPaymentStatusFilter(String status) {
    _paymentStatusFilter = status;
    notifyListeners();
  }

  void setDateFilter(String range) {
    _dateFilter = range;
    notifyListeners();
  }

  void setSortBy(String sort) {
    _sortBy = sort;
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _statusFilter = null;
    _paymentStatusFilter = 'All';
    _dateFilter = 'All';
    _sortBy = 'newest';
    notifyListeners();
  }

  void selectOrder(OrderModel? order) {
    _selectedOrder = order;
    notifyListeners();
  }

  /// Updates the status of [order] to [newStatus] with workflow validation and audit logging.
  Future<bool> updateOrderStatus(
    OrderModel order,
    OrderProgressStatus newStatus, {
    String? note,
  }) async {
    // 1. Workflow validation
    if (!OrderModel.canTransition(order.status, newStatus)) {
      _errorMessage =
          'Cannot transition order from "${order.status.label}" to "${newStatus.label}".';
      notifyListeners();
      return false;
    }

    _isUpdating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final adminUid = _authController?.customerProfile?.uid ??
          _authController?.currentUser?.uid ??
          'admin';
      final uid = order.customerId ?? '';

      await _orderRepository.updateOrderStatus(
        uid,
        order.id,
        newStatus,
        adminId: adminUid,
        note: note,
      );

      final historyEntry = OrderStatusHistoryEntry(
        status: newStatus,
        timestamp: DateTime.now(),
        note: note,
        updatedBy: adminUid,
      );

      final updated = order.copyWith(
        status: newStatus,
        updatedAt: DateTime.now(),
        updatedBy: adminUid,
        statusHistory: List<OrderStatusHistoryEntry>.from(order.statusHistory)
          ..add(historyEntry),
        cancelReason: newStatus == OrderProgressStatus.cancelled
            ? (note ?? 'Cancelled by Admin')
            : order.cancelReason,
      );

      // Update in local cache
      final index = _allOrders.indexWhere((o) => o.id == order.id);
      if (index != -1) {
        _allOrders[index] = updated;
      }
      if (_selectedOrder?.id == order.id) {
        _selectedOrder = updated;
      }

      debugPrint(
        '[ShopEase:Order] Order status transitioned: id=${order.id}, '
        'oldStatus=${order.status.name}, newStatus=${newStatus.name}, updatedBy=$adminUid',
      );

      // Notify customer of fulfillment status update
      if (uid.isNotEmpty) {
        final statusNotif = AppNotificationModel(
          id: 'notif_status_${order.id}_${newStatus.name}_${DateTime.now().millisecondsSinceEpoch}',
          title: 'Order #${order.id} Updated',
          body: 'Your order fulfillment status is now: ${newStatus.label}.',
          type: 'order',
          receivedAt: DateTime.now(),
          targetRoute: '/customer/orders',
          targetId: order.id,
        );
        _notificationRepository?.saveInAppNotification(
          uid: uid,
          notification: statusNotif,
        );
        debugPrint(
          '[ShopEase:Notification] In-app notification created: id=${statusNotif.id}, '
          'recipient=$uid, title="${statusNotif.title}", newStatus=${newStatus.name}',
        );
        _pushDispatchService?.dispatchCustomerOrderStatusUpdate(
          customerUid: uid,
          order: updated,
          newStatus: newStatus,
        );
      }

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to update order status: $e';
      notifyListeners();
      return false;
    } finally {
      _isUpdating = false;
      notifyListeners();
    }
  }
}

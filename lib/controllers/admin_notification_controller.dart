import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/customer_model.dart';
import '../models/notification_model.dart';
import '../models/product_model.dart';
import '../repositories/customer_repository.dart';
import '../repositories/notification_repository.dart';
import '../repositories/product_repository.dart';
import '../services/push_dispatch_service.dart';
import 'auth_controller.dart';

/// Presentation controller managing administrative push campaigns, broadcast history,
/// audience targeting, and real-time notification analytics.
class AdminNotificationController extends ChangeNotifier {
  final NotificationRepository _notificationRepository;
  final PushDispatchService _pushDispatchService;
  final CustomerRepository _customerRepository;
  final ProductRepository _productRepository;
  final AuthController _authController;

  List<AppNotificationModel> _campaigns = [];
  List<CustomerModel> _availableCustomers = [];
  List<ProductModel> _availableProducts = [];
  StreamSubscription<List<AppNotificationModel>>? _campaignSubscription;

  bool _isLoading = false;
  bool _isSending = false;
  String? _errorMessage;
  String? _successMessage;

  AdminNotificationController({
    required NotificationRepository notificationRepository,
    required PushDispatchService pushDispatchService,
    required CustomerRepository customerRepository,
    required ProductRepository productRepository,
    required AuthController authController,
  })  : _notificationRepository = notificationRepository,
        _pushDispatchService = pushDispatchService,
        _customerRepository = customerRepository,
        _productRepository = productRepository,
        _authController = authController {
    loadDashboardData();
  }

  // ── Getters ────────────────────────────────────────────────────────────────
  List<AppNotificationModel> get campaigns => List.unmodifiable(_campaigns);
  List<CustomerModel> get availableCustomers => List.unmodifiable(_availableCustomers);
  List<ProductModel> get availableProducts => List.unmodifiable(_availableProducts);

  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  int get totalNotifications => _campaigns.length;
  int get sentNotifications =>
      _campaigns.where((c) => c.deliveryStatus != 'failed').length;
  int get readNotifications =>
      _campaigns.fold(0, (sum, c) => sum + (c.isRead ? 1 : c.readCount));
  int get unreadNotifications {
    final unread = totalNotifications - readNotifications;
    return unread > 0 ? unread : 0;
  }

  // ── Dashboard Data Loading ─────────────────────────────────────────────────
  Future<void> loadDashboardData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Listen to admin notifications stream
      await _campaignSubscription?.cancel();
      _campaignSubscription = _notificationRepository
          .adminNotificationsStream(limit: 100)
          .listen((items) {
        _campaigns = List<AppNotificationModel>.from(items);
        notifyListeners();
      });

      // 2. Preload selectable customers and products for targeting
      final customers = await _customerRepository.getAllCustomers();
      final products = await _productRepository.getProducts();

      _availableCustomers = customers;
      _availableProducts = products;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to load notifications dashboard: $e';
      notifyListeners();
    }
  }

  // ── Send Notification ──────────────────────────────────────────────────────
  Future<bool> sendNotification({
    required String title,
    required String message,
    required String type,
    required String audience,
    String? selectedCustomerId,
    String? selectedCustomerName,
    String? imageUrl,
    String? targetRoute,
    String? targetId,
  }) async {
    // 1. Verify administrator privileges
    if (!_authController.isAdmin) {
      _errorMessage = 'Permission denied: Administrator role required.';
      notifyListeners();
      return false;
    }

    final adminUid = _authController.currentUser?.uid ?? 'admin_uid';

    // 2. Validate input fields
    if (title.trim().length < 3) {
      _errorMessage = 'Title must be at least 3 characters.';
      notifyListeners();
      return false;
    }
    if (message.trim().length < 5) {
      _errorMessage = 'Message must be at least 5 characters.';
      notifyListeners();
      return false;
    }
    if (audience == 'customer' &&
        (selectedCustomerId == null || selectedCustomerId.isEmpty)) {
      _errorMessage = 'Please select a customer recipient.';
      notifyListeners();
      return false;
    }

    _isSending = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final now = DateTime.now();
      final notificationId = 'notif_${now.millisecondsSinceEpoch}';

      final notification = AppNotificationModel(
        id: notificationId,
        title: title.trim(),
        body: message.trim(),
        type: type,
        receivedAt: now,
        isRead: false,
        audience: audience,
        recipientId: audience == 'customer' ? selectedCustomerId : null,
        recipientName: audience == 'customer' ? selectedCustomerName : 'All Customers',
        imageUrl: imageUrl?.trim().isNotEmpty == true ? imageUrl!.trim() : null,
        targetRoute: targetRoute?.trim().isNotEmpty == true ? targetRoute!.trim() : null,
        targetId: targetId?.trim().isNotEmpty == true ? targetId!.trim() : null,
        senderAdminId: adminUid,
        deliveryStatus: 'sent',
        totalRecipients: audience == 'all' ? _availableCustomers.length : 1,
      );

      // 3. Persist to Firestore notifications collections
      await _notificationRepository.sendAdminNotification(notification);

      // 4. Request FCM push delivery through the trusted backend
      await _pushDispatchService.dispatchAdminNotification(
        adminUid: adminUid,
        notification: notification,
        audience: audience,
        recipientUid: selectedCustomerId,
      );

      _successMessage = audience == 'all'
          ? 'Broadcast announcement dispatched to all customers!'
          : 'Direct notification dispatched to $selectedCustomerName!';
      _isSending = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isSending = false;
      _errorMessage = 'Failed to dispatch notification: $e';
      notifyListeners();
      return false;
    }
  }

  // ── Delete Campaign ────────────────────────────────────────────────────────
  Future<bool> deleteNotification(String notificationId) async {
    if (!_authController.isAdmin) {
      _errorMessage = 'Permission denied.';
      notifyListeners();
      return false;
    }

    try {
      await _notificationRepository.deleteAdminNotification(notificationId);
      _campaigns.removeWhere((c) => c.id == notificationId);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Failed to delete notification: $e';
      notifyListeners();
      return false;
    }
  }

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _campaignSubscription?.cancel();
    super.dispose();
  }
}


import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';
import '../repositories/notification_repository.dart';
import '../services/notification_service.dart';

/// Presentation controller coordinating device registration, permissions,
/// message streams, and notification inbox.
class NotificationController extends ChangeNotifier {
  final NotificationService _service;
  final NotificationRepository _repository;

  NotificationPermissionStatus _permissionStatus =
      NotificationPermissionStatus.notDetermined;
  String? _fcmToken;
  String? _deviceId;
  String? _currentUid;
  bool _isLoading = false;
  String? _errorMessage;

  List<AppNotificationModel> _notifications = [];
  StreamSubscription<List<AppNotificationModel>>? _inboxSubscription;
  StreamSubscription<AppNotificationModel>? _foregroundSubscription;
  StreamSubscription<NotificationTapEvent>? _tapSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;

  void Function(NotificationTapEvent event)? _onNavigate;

  NotificationController({
    required NotificationService service,
    required NotificationRepository repository,
  })  : _service = service,
        _repository = repository;

  // ── Getters ────────────────────────────────────────────────────────────────
  NotificationPermissionStatus get permissionStatus => _permissionStatus;
  String? get fcmToken => _fcmToken;
  String? get deviceId => _deviceId;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<AppNotificationModel> get notifications => List.unmodifiable(_notifications);

  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  bool get hasUnread => unreadCount > 0;
  bool get isPermissionGranted =>
      _permissionStatus == NotificationPermissionStatus.granted;

  // ── Lifecycle & Initialization ─────────────────────────────────────────────
  Future<void> initialize({
    String? currentUid,
    void Function(NotificationTapEvent event)? onNavigate,
  }) async {
    _onNavigate = onNavigate;
    _currentUid = currentUid;
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Initialize Messaging service
      await _service.initialize();
      _permissionStatus = _service.permissionStatus;
      _deviceId = await _service.getOrCreateDeviceId();

      // 2. Set up event stream listeners
      _setupStreamListeners();

      // 3. Check for app launch via cold start notification
      final initialNotification = await _service.getInitialNotification();
      if (initialNotification != null) {
        _handleTapEvent(initialNotification);
      }

      // 4. Sync with user if authenticated
      if (currentUid != null) {
        await _registerDeviceForUser(currentUid);
        _listenToUserInbox(currentUid);
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Synchronizes device registration when user session transitions (login / logout).
  Future<void> syncUser(String? newUid) async {
    if (_currentUid == newUid) return;

    final oldUid = _currentUid;
    _currentUid = newUid;

    // 1. Clean up old user's device token and inbox stream
    if (oldUid != null && _deviceId != null) {
      await _repository.deactivateDeviceToken(
        uid: oldUid,
        deviceId: _deviceId!,
      );
    }
    await _inboxSubscription?.cancel();
    _inboxSubscription = null;
    _notifications = [];
    notifyListeners();

    // 2. Register new authenticated user's device and ensure notification permission is requested after login
    if (newUid != null) {
      if (_permissionStatus == NotificationPermissionStatus.notDetermined) {
        debugPrint('[ShopEase:FCM] Requesting notification permission post-login for user: $newUid');
        await requestPermission();
      } else {
        await _registerDeviceForUser(newUid);
      }
      _listenToUserInbox(newUid);
    }
  }

  /// Requests notification permission explicitly (e.g. from UI toggle).
  Future<NotificationPermissionStatus> requestPermission() async {
    _isLoading = true;
    notifyListeners();

    try {
      final status = await _service.requestPermission();
      _permissionStatus = status;

      if (status == NotificationPermissionStatus.granted && _currentUid != null) {
        await _registerDeviceForUser(_currentUid!);
      }

      _isLoading = false;
      notifyListeners();
      return status;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return _permissionStatus;
    }
  }

  // ── Device Registration in Firestore ───────────────────────────────────────
  Future<void> _registerDeviceForUser(String uid) async {
    try {
      _deviceId ??= await _service.getOrCreateDeviceId();
      _fcmToken = await _service.getToken();

      if (_fcmToken != null && _fcmToken!.isNotEmpty && _deviceId != null) {
        final platformName = kIsWeb ? 'web' : defaultTargetPlatform.name;
        final device = DeviceRegistrationModel(
          deviceId: _deviceId!,
          token: _fcmToken!,
          platform: platformName,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          isActive: true,
        );

        await _repository.saveDeviceToken(uid: uid, device: device);
        debugPrint(
          '[ShopEase:FCM] Registering device token in Firestore: uid=$uid, '
          'path=customers/$uid/devices/$_deviceId, platform=$platformName',
        );
        debugPrint('[ShopEase:FCM] Full device token: $_fcmToken');
      }
    } catch (e) {
      debugPrint('[ShopEase:FCM] Error registering device token: $e');
    }
  }

  // ── Inbox & Notification Operations ────────────────────────────────────────
  void _listenToUserInbox(String uid) {
    _inboxSubscription?.cancel();
    _inboxSubscription = _repository.notificationsStream(uid).listen((items) {
      _notifications = List<AppNotificationModel>.from(items);
      notifyListeners();
    });
  }

  void _setupStreamListeners() {
    // 1. Foreground Message Arrival
    _foregroundSubscription?.cancel();
    _foregroundSubscription = _service.onForegroundMessage.listen((notification) {
      _notifications = List<AppNotificationModel>.from(_notifications)
        ..insert(0, notification);
      if (_currentUid != null) {
        _repository.saveInAppNotification(
          uid: _currentUid!,
          notification: notification,
        );
      }
      notifyListeners();
    });

    // 2. Notification Tap Navigation
    _tapSubscription?.cancel();
    _tapSubscription = _service.onNotificationTap.listen((event) {
      _handleTapEvent(event);
    });

    // 3. Token Rotation
    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = _service.onTokenRefresh.listen((newToken) {
      _fcmToken = newToken;
      if (_currentUid != null) {
        _registerDeviceForUser(_currentUid!);
      }
      notifyListeners();
    });
  }

  void _handleTapEvent(NotificationTapEvent event) {
    debugPrint('[NotificationController] Handling tap event: targetRoute=${event.targetRoute}');
    if (_onNavigate != null) {
      _onNavigate!(event);
    }
  }

  Future<void> markAsRead(String notificationId) async {
    final list = List<AppNotificationModel>.from(_notifications);
    final idx = list.indexWhere((n) => n.id == notificationId);
    if (idx != -1) {
      list[idx] = list[idx].copyWith(isRead: true);
      _notifications = list;
      notifyListeners();
    }
    if (_currentUid != null) {
      await _repository.markNotificationAsRead(
        uid: _currentUid!,
        notificationId: notificationId,
      );
    }
  }

  Future<void> markAllAsRead() async {
    final list = List<AppNotificationModel>.from(_notifications);
    for (int i = 0; i < list.length; i++) {
      list[i] = list[i].copyWith(isRead: true);
    }
    _notifications = list;
    notifyListeners();

    if (_currentUid != null) {
      for (final n in _notifications) {
        await _repository.markNotificationAsRead(
          uid: _currentUid!,
          notificationId: n.id,
        );
      }
    }
  }

  Future<void> clearAll() async {
    _notifications = [];
    notifyListeners();

    if (_currentUid != null) {
      await _repository.clearAllNotifications(_currentUid!);
    }
  }

  /// Removes an individual notification from in-memory feed.
  Future<void> deleteNotification(String notificationId) async {
    _notifications = List<AppNotificationModel>.from(_notifications)
      ..removeWhere((n) => n.id == notificationId);
    notifyListeners();
  }

  /// Diagnostic helper to add simulated notification for in-app testing.
  Future<void> addLocalNotification(AppNotificationModel notification) async {
    _notifications = List<AppNotificationModel>.from(_notifications)
      ..insert(0, notification);
    notifyListeners();
    if (_currentUid != null) {
      await _repository.saveInAppNotification(
        uid: _currentUid!,
        notification: notification,
      );
    }
  }

  @override
  void dispose() {
    _inboxSubscription?.cancel();
    _foregroundSubscription?.cancel();
    _tapSubscription?.cancel();
    _tokenRefreshSubscription?.cancel();
    super.dispose();
  }
}


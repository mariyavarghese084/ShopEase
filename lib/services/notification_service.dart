import 'dart:async';
import 'package:firebase_core/firebase_core.dart' hide FirebaseService;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification_model.dart';
import 'firebase_service.dart';

/// Top-level background message handler required by Firebase Cloud Messaging.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (e) {
    debugPrint('[ShopEase:FCM] Background Firebase init notice: $e');
  }
  debugPrint(
    '[ShopEase:FCM] Received background message: id=${message.messageId}, '
    'title=${message.notification?.title}, '
    'body=${message.notification?.body}, '
    'data=${message.data}',
  );
}

/// Public Web Push VAPID key configuration for Web (Edge / Chrome).
///
/// Obtain this public key from:
/// Firebase Console > Project Settings > Cloud Messaging > Web configuration > Web Push certificates.
class WebPushConfig {
  /// Replace this placeholder with the actual Web Push certificate key pair from Firebase Console.
  /// If null or empty, web token generation will log an instructional notice for browser push subscription.
  static const String? vapidPublicKey = null;
}

/// Represents the status of user notification authorization.
enum NotificationPermissionStatus {
  notDetermined,
  granted,
  denied,
  permanentlyDenied,
  provisional,
  notSupported,
}

/// Payload emitted when a user taps an incoming or background notification.
class NotificationTapEvent {
  final String? title;
  final String? body;
  final Map<String, dynamic> data;
  final String? targetRoute;
  final String? targetId;

  const NotificationTapEvent({
    this.title,
    this.body,
    this.data = const {},
    this.targetRoute,
    this.targetId,
  });

  factory NotificationTapEvent.fromRemoteMessage(RemoteMessage message) {
    final data = message.data;
    return NotificationTapEvent(
      title: message.notification?.title ?? data['title'] as String?,
      body: message.notification?.body ?? data['body'] as String?,
      data: data,
      targetRoute: data['targetRoute'] as String? ?? data['route'] as String?,
      targetId: data['targetId'] as String? ?? data['id'] as String?,
    );
  }

  factory NotificationTapEvent.fromMap(Map<String, dynamic> map) {
    return NotificationTapEvent(
      title: map['title'] as String?,
      body: map['body'] as String?,
      data: map,
      targetRoute: map['targetRoute'] as String? ?? map['route'] as String?,
      targetId: map['targetId'] as String? ?? map['id'] as String?,
    );
  }
}

/// Abstract contract for device notification initialization, permission, and event streaming.
abstract class NotificationService {
  /// Stream of foreground incoming messages.
  Stream<AppNotificationModel> get onForegroundMessage;

  /// Stream of notification tap events for navigation.
  Stream<NotificationTapEvent> get onNotificationTap;

  /// Stream of FCM token rotation events.
  Stream<String> get onTokenRefresh;

  /// Current cached permission status.
  NotificationPermissionStatus get permissionStatus;

  /// Initializes messaging SDK, local notification plugins, and foreground channels.
  Future<void> initialize({String? webVapidKey});

  /// Requests notification permission from the host OS / browser.
  Future<NotificationPermissionStatus> requestPermission();

  /// Retrieves the current or newly minted FCM registration token.
  Future<String?> getToken({String? webVapidKey});

  /// Retrieves or generates a persistent device UUID for tracking multiple devices per user.
  Future<String> getOrCreateDeviceId();

  /// Checks and delivers any initial notification that launched the application from terminated state.
  Future<NotificationTapEvent?> getInitialNotification();

  /// Displays an immediate local notification (used for foreground presentation on Android).
  Future<void> showLocalNotification(AppNotificationModel notification);
}

/// Production Firebase Cloud Messaging implementation of [NotificationService].
class FirebaseNotificationService implements NotificationService {
  static const String _deviceIdPrefKey = 'shopease_device_unique_id';
  static const String _channelId = 'shopease_high_importance';
  static const String _channelName = 'ShopEase High Importance Alerts';
  static const String _channelDesc =
      'Important order tracking alerts, status updates, and promotions';

  final FirebaseMessaging? _injectedMessaging;
  final FlutterLocalNotificationsPlugin? _injectedLocalNotifications;

  final StreamController<AppNotificationModel> _foregroundMessageController =
      StreamController<AppNotificationModel>.broadcast();
  final StreamController<NotificationTapEvent> _notificationTapController =
      StreamController<NotificationTapEvent>.broadcast();
  final StreamController<String> _tokenRefreshController =
      StreamController<String>.broadcast();

  NotificationPermissionStatus _permissionStatus =
      NotificationPermissionStatus.notDetermined;
  bool _isInitialized = false;
  String? _webVapidKey;

  FirebaseNotificationService({
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
  })  : _injectedMessaging = messaging,
        _injectedLocalNotifications = localNotifications;

  FirebaseMessaging? get _messaging {
    if (_injectedMessaging != null) return _injectedMessaging;
    if (!FirebaseService.isInitialized) return null;
    return FirebaseMessaging.instance;
  }

  FlutterLocalNotificationsPlugin get _localNotifications =>
      _injectedLocalNotifications ?? FlutterLocalNotificationsPlugin();

  @override
  Stream<AppNotificationModel> get onForegroundMessage =>
      _foregroundMessageController.stream;

  @override
  Stream<NotificationTapEvent> get onNotificationTap =>
      _notificationTapController.stream;

  @override
  Stream<String> get onTokenRefresh => _tokenRefreshController.stream;

  @override
  NotificationPermissionStatus get permissionStatus => _permissionStatus;

  @override
  Future<void> initialize({String? webVapidKey}) async {
    if (_isInitialized) return;
    _webVapidKey = webVapidKey ?? WebPushConfig.vapidPublicKey;

    try {
      final messaging = _messaging;
      if (messaging == null) {
        debugPrint('[NotificationService] Offline/Mock: Firebase messaging not initialized');
        _isInitialized = true;
        return;
      }

      // 1. Initialize local notifications for Android / iOS
      if (!kIsWeb) {
        FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

        const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
        const darwinInit = DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        );
        const initSettings = InitializationSettings(
          android: androidInit,
          iOS: darwinInit,
          macOS: darwinInit,
        );

        await _localNotifications.initialize(
          initSettings,
          onDidReceiveNotificationResponse: (response) {
            final payload = response.payload;
            if (payload != null && payload.isNotEmpty) {
              _notificationTapController.add(
                NotificationTapEvent(
                  targetRoute: payload,
                  data: {'payload': payload},
                ),
              );
            }
          },
        );

        // Create high-importance Android channel with Importance.max for heads-up alerts
        final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        if (androidPlugin != null) {
          await androidPlugin.createNotificationChannel(
            const AndroidNotificationChannel(
              _channelId,
              _channelName,
              description: _channelDesc,
              importance: Importance.max,
              playSound: true,
              enableVibration: true,
              showBadge: true,
            ),
          );
        }

        // Set foreground notification presentation options
        await messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      // 2. Query initial permission settings without prompting
      final settings = await messaging.getNotificationSettings();
      _permissionStatus = _mapAuthorizationStatus(settings.authorizationStatus);

      // 3. Listen to Foreground Messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint(
          '[ShopEase:FCM] Incoming message received: id=${message.messageId}, '
          'title=${message.notification?.title}, data=${message.data}',
        );
        final model = _convertRemoteMessageToModel(message);
        _foregroundMessageController.add(model);

        // Display local banner on mobile devices
        if (!kIsWeb) {
          showLocalNotification(model);
        }
      });

      // 4. Listen to onMessageOpenedApp (App in background, user taps notification banner)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('[NotificationService] onMessageOpenedApp: ${message.messageId}');
        _notificationTapController.add(
          NotificationTapEvent.fromRemoteMessage(message),
        );
      });

      // 5. Listen to Token Rotation
      // ignore: deprecated_member_use
      messaging.onTokenRefresh.listen((token) {
        debugPrint('[NotificationService] onTokenRefresh: $token');
        _tokenRefreshController.add(token);
      });

      _isInitialized = true;
      debugPrint('[NotificationService] Initialized successfully. Status: $_permissionStatus');
    } catch (e) {
      debugPrint('[NotificationService] Notice during initialization: $e');
      _isInitialized = true;
    }
  }

  @override
  Future<NotificationPermissionStatus> requestPermission() async {
    final messaging = _messaging;
    if (messaging == null) {
      _permissionStatus = NotificationPermissionStatus.granted;
      return _permissionStatus;
    }

    try {
      final settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      _permissionStatus = _mapAuthorizationStatus(settings.authorizationStatus);

      // On Android 13+ (API 33+), ensure local notification permission is explicitly prompted
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        if (androidPlugin != null) {
          final granted = await androidPlugin.requestNotificationsPermission();
          debugPrint('[NotificationService] Android POST_NOTIFICATIONS resolution: $granted');
          if (granted == false) {
            _permissionStatus = NotificationPermissionStatus.denied;
          } else if (granted == true) {
            _permissionStatus = NotificationPermissionStatus.granted;
          }
        }
      }

      debugPrint('[NotificationService] User permission resolution: $_permissionStatus');
      return _permissionStatus;
    } catch (e) {
      debugPrint('[NotificationService] Error requesting permission: $e');
      _permissionStatus = NotificationPermissionStatus.denied;
      return _permissionStatus;
    }
  }

  @override
  Future<String?> getToken({String? webVapidKey}) async {
    final messaging = _messaging;
    if (messaging == null) {
      return 'mock_token_${DateTime.now().millisecondsSinceEpoch}';
    }

    try {
      final key = webVapidKey ?? _webVapidKey ?? WebPushConfig.vapidPublicKey;
      final validKey = (key != null && key.trim().isNotEmpty) ? key.trim() : null;

      if (kIsWeb && validKey == null) {
        debugPrint(
          '[ShopEase:WebPush] Note: Web Push VAPID key is currently unset. '
          'To generate web push tokens in Microsoft Edge / Chrome, provide the public VAPID key in '
          'WebPushConfig.vapidPublicKey (obtainable from Firebase Console > Project Settings > Cloud Messaging > Web configuration).'
        );
      }

      // ignore: deprecated_member_use
      final token = await messaging.getToken(
        vapidKey: kIsWeb ? validKey : null,
      );
      final tokenPreview = token != null
          ? (token.length > 12 ? '${token.substring(0, 12)}...' : token)
          : 'null';
      debugPrint('[ShopEase:FCM] FCM token retrieved: token=$tokenPreview');
      if (token != null) {
        debugPrint('[ShopEase:FCM] Full device token: $token');
      }
      return token;
    } catch (e) {
      debugPrint('[ShopEase:FCM] Error retrieving FCM token: $e');
      return null;
    }
  }

  @override
  Future<String> getOrCreateDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var id = prefs.getString(_deviceIdPrefKey);
      if (id == null || id.isEmpty) {
        final platformName = kIsWeb ? 'web' : defaultTargetPlatform.name;
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final randomPart = (timestamp % 100000).toString().padLeft(5, '0');
        id = 'dev_${platformName}_${timestamp}_$randomPart';
        await prefs.setString(_deviceIdPrefKey, id);
      }
      return id;
    } catch (_) {
      return 'dev_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  @override
  Future<NotificationTapEvent?> getInitialNotification() async {
    final messaging = _messaging;
    if (messaging == null) return null;

    try {
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('[NotificationService] Terminated app launched via notification: ${initialMessage.messageId}');
        return NotificationTapEvent.fromRemoteMessage(initialMessage);
      }
    } catch (e) {
      debugPrint('[NotificationService] Notice reading initial notification: $e');
    }
    return null;
  }

  @override
  Future<void> showLocalNotification(AppNotificationModel notification) async {
    if (kIsWeb) return;

    try {
      final androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
        visibility: NotificationVisibility.public,
        channelShowBadge: true,
        ticker: 'ShopEase',
        styleInformation: BigTextStyleInformation(
          notification.body,
          contentTitle: notification.title,
        ),
      );
      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      final details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
        macOS: darwinDetails,
      );

      final id = notification.id.hashCode & 0x7fffffff;
      await _localNotifications.show(
        id,
        notification.title,
        notification.body,
        details,
        payload: notification.targetRoute ?? notification.data['route'] as String?,
      );
      debugPrint('[ShopEase:FCM] Displayed local foreground notification: id=${notification.id}');
    } catch (e) {
      debugPrint('[ShopEase:FCM] Error showing local notification: $e');
    }
  }

  AppNotificationModel _convertRemoteMessageToModel(RemoteMessage message) {
    final title = message.notification?.title ??
        message.data['title'] as String? ??
        'ShopEase Announcement';
    final body = message.notification?.body ??
        message.data['body'] as String? ??
        '';

    return AppNotificationModel(
      id: message.messageId ?? 'msg_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      body: body,
      data: message.data,
      type: message.data['type'] as String? ?? 'system',
      receivedAt: message.sentTime ?? DateTime.now(),
      targetRoute: message.data['targetRoute'] as String? ??
          message.data['route'] as String?,
      targetId: message.data['targetId'] as String? ??
          message.data['id'] as String?,
    );
  }

  NotificationPermissionStatus _mapAuthorizationStatus(
    AuthorizationStatus status,
  ) {
    switch (status) {
      case AuthorizationStatus.authorized:
        return NotificationPermissionStatus.granted;
      case AuthorizationStatus.denied:
        return NotificationPermissionStatus.denied;
      case AuthorizationStatus.deniedPermanently:
        return NotificationPermissionStatus.permanentlyDenied;
      case AuthorizationStatus.notDetermined:
        return NotificationPermissionStatus.notDetermined;
      case AuthorizationStatus.provisional:
        return NotificationPermissionStatus.provisional;
    }
  }
}

/// In-memory implementation of [NotificationService] for unit and widget testing.
class InMemoryNotificationService implements NotificationService {
  final StreamController<AppNotificationModel> _foregroundController =
      StreamController<AppNotificationModel>.broadcast();
  final StreamController<NotificationTapEvent> _tapController =
      StreamController<NotificationTapEvent>.broadcast();
  final StreamController<String> _tokenController =
      StreamController<String>.broadcast();

  NotificationPermissionStatus _permissionStatus =
      NotificationPermissionStatus.notDetermined;
  String mockDeviceId = 'mock_device_unit_test';
  String mockToken = 'mock_fcm_token_12345';
  NotificationTapEvent? initialEvent;

  @override
  Stream<AppNotificationModel> get onForegroundMessage =>
      _foregroundController.stream;

  @override
  Stream<NotificationTapEvent> get onNotificationTap => _tapController.stream;

  @override
  Stream<String> get onTokenRefresh => _tokenController.stream;

  @override
  NotificationPermissionStatus get permissionStatus => _permissionStatus;

  @override
  Future<void> initialize({String? webVapidKey}) async {}

  @override
  Future<NotificationPermissionStatus> requestPermission() async {
    _permissionStatus = NotificationPermissionStatus.granted;
    return _permissionStatus;
  }

  @override
  Future<String?> getToken({String? webVapidKey}) async {
    return mockToken;
  }

  @override
  Future<String> getOrCreateDeviceId() async {
    return mockDeviceId;
  }

  @override
  Future<NotificationTapEvent?> getInitialNotification() async {
    return initialEvent;
  }

  @override
  Future<void> showLocalNotification(AppNotificationModel notification) async {}

  // Test helpers:
  void emitForegroundMessage(AppNotificationModel message) {
    _foregroundController.add(message);
  }

  void emitNotificationTap(NotificationTapEvent event) {
    _tapController.add(event);
  }

  void emitTokenRefresh(String token) {
    mockToken = token;
    _tokenController.add(token);
  }

  void setPermissionStatus(NotificationPermissionStatus status) {
    _permissionStatus = status;
  }
}


import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopease/controllers/notification_controller.dart';
import 'package:shopease/models/notification_model.dart';
import 'package:shopease/repositories/notification_repository.dart';
import 'package:shopease/services/notification_service.dart';

/// Test mock implementation of [NotificationService] simulating real Android FCM behavior.
class AndroidFCMTestNotificationService implements NotificationService {
  NotificationPermissionStatus _status = NotificationPermissionStatus.notDetermined;
  String _simulatedToken =
      'cXvmw_l2SuaDr9RhS11gxJ:APA91bGyTJxRFBzkHTHmyVdjvR2MtsWHu8J6QELEeUlbM9SajTw2ktt3M5q8SMTtG5wU0fKcAU_4-ob4DEkWXZM1XuYwZI83g42QuO0mLp_5mSfvavvoZcI';
  int requestPermissionCallCount = 0;
  bool channelCreated = false;
  AppNotificationModel? lastLocalNotificationShown;

  final StreamController<AppNotificationModel> _foregroundController =
      StreamController<AppNotificationModel>.broadcast();
  final StreamController<NotificationTapEvent> _tapController =
      StreamController<NotificationTapEvent>.broadcast();
  final StreamController<String> _tokenRefreshController =
      StreamController<String>.broadcast();

  @override
  Stream<AppNotificationModel> get onForegroundMessage => _foregroundController.stream;

  @override
  Stream<NotificationTapEvent> get onNotificationTap => _tapController.stream;

  @override
  Stream<String> get onTokenRefresh => _tokenRefreshController.stream;

  @override
  NotificationPermissionStatus get permissionStatus => _status;

  @override
  Future<void> initialize({String? webVapidKey}) async {
    channelCreated = true;
  }

  @override
  Future<NotificationPermissionStatus> requestPermission() async {
    requestPermissionCallCount++;
    _status = NotificationPermissionStatus.granted;
    return _status;
  }

  @override
  Future<String?> getToken({String? webVapidKey}) async {
    debugPrint('[ShopEase:FCM] Full device token: $_simulatedToken');
    return _simulatedToken;
  }

  @override
  Future<String> getOrCreateDeviceId() async {
    return 'dev_android_emulator_pixel3a';
  }

  @override
  Future<NotificationTapEvent?> getInitialNotification() async {
    return const NotificationTapEvent(
      title: 'Welcome to ShopEase',
      body: 'Check out the new summer collection',
      data: {'targetRoute': '/customer/home'},
      targetRoute: '/customer/home',
    );
  }

  @override
  Future<void> showLocalNotification(AppNotificationModel notification) async {
    lastLocalNotificationShown = notification;
    debugPrint(
      '[ShopEase:FCM] Displayed local foreground notification: id=${notification.id}, title=${notification.title}',
    );
  }

  void simulateForegroundMessage(AppNotificationModel notification) {
    _foregroundController.add(notification);
    showLocalNotification(notification);
  }

  void simulateTokenRotation(String newToken) {
    _simulatedToken = newToken;
    _tokenRefreshController.add(newToken);
  }

  void simulateTap(NotificationTapEvent event) {
    _tapController.add(event);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ShopEase Android Firebase Cloud Messaging Verification', () {
    late AndroidFCMTestNotificationService testService;
    late InMemoryNotificationRepository testRepo;
    late NotificationController controller;

    setUp(() {
      testService = AndroidFCMTestNotificationService();
      testRepo = InMemoryNotificationRepository();
      controller = NotificationController(
        service: testService,
        repository: testRepo,
      );
    });

    tearDown(() {
      controller.dispose();
    });

    test('1. Android notification channel initialization and cold-start handling', () async {
      NotificationTapEvent? capturedTap;
      await controller.initialize(
        onNavigate: (event) {
          capturedTap = event;
        },
      );

      expect(testService.channelCreated, true);
      expect(capturedTap, isNotNull);
      expect(capturedTap?.targetRoute, '/customer/home');
    });

    test('2. Automatic notification permission request upon user login', () async {
      await controller.initialize();
      expect(testService.requestPermissionCallCount, 0);
      expect(controller.permissionStatus, NotificationPermissionStatus.notDetermined);

      // Authenticate / login user
      await controller.syncUser('customer_uid_999');

      expect(testService.requestPermissionCallCount, 1);
      expect(controller.permissionStatus, NotificationPermissionStatus.granted);
      expect(controller.isPermissionGranted, true);
    });

    test('3. Real FCM Token generation and Firestore device registration under customers/{uid}/devices', () async {
      await controller.initialize();
      await controller.syncUser('customer_uid_999');

      final devices = await testRepo.getUserDevices('customer_uid_999');
      expect(devices.length, 1);
      final dev = devices.first;
      expect(dev.deviceId, 'dev_android_emulator_pixel3a');
      expect(dev.token, testService._simulatedToken);
      expect(dev.isActive, true);
      expect(controller.fcmToken, testService._simulatedToken);
    });

    test('4. Support multiple devices per user without overwriting', () async {
      await controller.initialize();
      await controller.syncUser('customer_uid_999');

      // Register a second device for same customer
      final secondDevice = DeviceRegistrationModel(
        deviceId: 'dev_android_tablet_galaxy',
        token: 'token_galaxy_tab_fcm_777',
        platform: 'android',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isActive: true,
      );
      await testRepo.saveDeviceToken(uid: 'customer_uid_999', device: secondDevice);

      final userDevices = await testRepo.getUserDevices('customer_uid_999');
      expect(userDevices.length, 2);
      expect(userDevices.map((d) => d.deviceId), containsAll(['dev_android_emulator_pixel3a', 'dev_android_tablet_galaxy']));
    });

    test('5. Token refresh listener updates Firestore token', () async {
      await controller.initialize();
      await controller.syncUser('customer_uid_999');

      const rotatedToken = 'new_rotated_fcm_token_abcdef_99999';
      testService.simulateTokenRotation(rotatedToken);

      // Allow microtasks to propagate
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(controller.fcmToken, rotatedToken);
      final userDevices = await testRepo.getUserDevices('customer_uid_999');
      expect(userDevices.first.token, rotatedToken);
    });

    test('6. Foreground notifications display via flutter_local_notifications and update inbox', () async {
      await controller.initialize();
      await controller.syncUser('customer_uid_999');

      final testNotification = AppNotificationModel(
        id: 'msg_fcm_1001',
        title: 'Order Dispatched',
        body: 'Your package is on the way!',
        data: {'orderId': 'ORD-9876', 'route': '/customer/orders'},
        type: 'order',
        receivedAt: DateTime.now(),
      );

      testService.simulateForegroundMessage(testNotification);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(controller.notifications.length, 1);
      expect(controller.notifications.first.id, 'msg_fcm_1001');
      expect(testService.lastLocalNotificationShown?.title, 'Order Dispatched');
      expect(controller.unreadCount, 1);
    });

    test('7. Background message handler top-level function runs safely', () async {
      final remoteMessage = RemoteMessage(
        messageId: 'bg_msg_555',
        notification: const RemoteNotification(
          title: 'Special Flash Sale',
          body: '50% off all perfumes today',
        ),
        data: {'route': '/customer/products'},
      );

      // Verify that firebaseMessagingBackgroundHandler executes without error
      await expectLater(
        firebaseMessagingBackgroundHandler(remoteMessage),
        completes,
      );
    });

    test('8. User tap on notification routes navigation event', () async {
      NotificationTapEvent? receivedTap;
      await controller.initialize(
        onNavigate: (event) {
          receivedTap = event;
        },
      );

      const tapEvent = NotificationTapEvent(
        title: 'Order Delivered',
        body: 'Your order #ORD-123 has been delivered',
        targetRoute: '/customer/orders/ORD-123',
      );
      testService.simulateTap(tapEvent);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(receivedTap, isNotNull);
      expect(receivedTap?.targetRoute, '/customer/orders/ORD-123');
    });

    test('9. User logout deactivates device token in Firestore', () async {
      await controller.initialize();
      await controller.syncUser('customer_uid_999');

      var devices = await testRepo.getUserDevices('customer_uid_999');
      expect(devices.first.isActive, true);

      // Logout
      await controller.syncUser(null);

      devices = await testRepo.getUserDevices('customer_uid_999');
      expect(devices.first.isActive, false);
      expect(controller.notifications, isEmpty);
    });
  });
}


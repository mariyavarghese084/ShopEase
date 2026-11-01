import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shopease/controllers/notification_controller.dart';
import 'package:shopease/models/notification_model.dart';
import 'package:shopease/repositories/notification_repository.dart';
import 'package:shopease/services/notification_service.dart';
import 'package:shopease/widgets/notification_bell_button.dart';
import 'package:shopease/widgets/notification_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Notification Models & Serialization', () {
    test('DeviceRegistrationModel serializes and deserializes correctly', () {
      final now = DateTime.now();
      final model = DeviceRegistrationModel(
        deviceId: 'dev_web_123',
        token: 'token_abc_xyz',
        platform: 'web',
        createdAt: now,
        updatedAt: now,
        isActive: true,
        deviceModel: 'Chrome on Windows',
      );

      final map = model.toMap();
      expect(map['token'], 'token_abc_xyz');
      expect(map['platform'], 'web');
      expect(map['isActive'], true);
      expect(map['deviceModel'], 'Chrome on Windows');

      final fromMap = DeviceRegistrationModel.fromMap('dev_web_123', map);
      expect(fromMap.deviceId, 'dev_web_123');
      expect(fromMap.token, 'token_abc_xyz');
      expect(fromMap.platform, 'web');
      expect(fromMap.isActive, true);
    });

    test('AppNotificationModel serializes and deserializes correctly', () {
      final now = DateTime.now();
      final notification = AppNotificationModel(
        id: 'msg_999',
        title: 'Order Confirmed',
        body: 'Your Yara Rose perfume order has been placed.',
        data: {'orderId': 'ord_1', 'route': '/customer/orders/detail'},
        type: 'order',
        receivedAt: now,
        isRead: false,
        targetRoute: '/customer/orders/detail',
        targetId: 'ord_1',
      );

      final map = notification.toMap();
      expect(map['id'], 'msg_999');
      expect(map['title'], 'Order Confirmed');
      expect(map['type'], 'order');
      expect(map['isRead'], false);

      final reconstructed = AppNotificationModel.fromMap(map, 'msg_999');
      expect(reconstructed.id, 'msg_999');
      expect(reconstructed.title, 'Order Confirmed');
      expect(reconstructed.targetRoute, '/customer/orders/detail');
      expect(reconstructed.targetId, 'ord_1');
    });
  });

  group('Notification Repository & Multi-Device Storage', () {
    late InMemoryNotificationRepository repo;

    setUp(() {
      repo = InMemoryNotificationRepository();
    });

    test('Supports multiple devices for the same user', () async {
      const uid = 'customer_user_1';

      final dev1 = DeviceRegistrationModel(
        deviceId: 'dev_phone_1',
        token: 'token_phone_1',
        platform: 'android',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isActive: true,
      );

      final dev2 = DeviceRegistrationModel(
        deviceId: 'dev_laptop_2',
        token: 'token_laptop_2',
        platform: 'web',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isActive: true,
      );

      await repo.saveDeviceToken(uid: uid, device: dev1);
      await repo.saveDeviceToken(uid: uid, device: dev2);

      final userDevices = await repo.getUserDevices(uid);
      expect(userDevices.length, 2);
      expect(userDevices.any((d) => d.deviceId == 'dev_phone_1'), true);
      expect(userDevices.any((d) => d.deviceId == 'dev_laptop_2'), true);
    });

    test('Deactivates device token without deleting history', () async {
      const uid = 'customer_user_1';
      final dev = DeviceRegistrationModel(
        deviceId: 'dev_tablet_1',
        token: 'token_tab_1',
        platform: 'android',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isActive: true,
      );

      await repo.saveDeviceToken(uid: uid, device: dev);
      var devices = await repo.getUserDevices(uid);
      expect(devices.first.isActive, true);

      await repo.deactivateDeviceToken(uid: uid, deviceId: 'dev_tablet_1');
      devices = await repo.getUserDevices(uid);
      expect(devices.first.isActive, false);
    });

    test('Manages notification feed, read status, and clearAll', () async {
      const uid = 'customer_user_1';
      final notif = AppNotificationModel(
        id: 'n_1',
        title: 'Flash Sale',
        body: '30% off luxury perfumes',
        receivedAt: DateTime.now(),
      );

      await repo.saveInAppNotification(uid: uid, notification: notif);

      final streamValues = <List<AppNotificationModel>>[];
      final sub = repo.notificationsStream(uid).listen(streamValues.add);

      await pumpEventQueue();
      expect(streamValues.isNotEmpty, true);
      expect(streamValues.last.first.id, 'n_1');
      expect(streamValues.last.first.isRead, false);

      await repo.markNotificationAsRead(uid: uid, notificationId: 'n_1');
      await pumpEventQueue();
      expect(streamValues.last.first.isRead, true);

      await repo.clearAllNotifications(uid);
      await pumpEventQueue();
      expect(streamValues.last.isEmpty, true);

      await sub.cancel();
    });
  });

  group('NotificationController Presentation & Synchronization', () {
    late InMemoryNotificationService service;
    late InMemoryNotificationRepository repo;
    late NotificationController controller;

    setUp(() {
      service = InMemoryNotificationService();
      repo = InMemoryNotificationRepository();
      controller = NotificationController(
        service: service,
        repository: repo,
      );
    });

    tearDown(() {
      controller.dispose();
    });

    test('Initializes correctly and requests permission', () async {
      await controller.initialize(currentUid: 'user_123');

      expect(controller.deviceId, service.mockDeviceId);
      expect(controller.isPermissionGranted, false);

      final status = await controller.requestPermission();
      expect(status, NotificationPermissionStatus.granted);
      expect(controller.isPermissionGranted, true);

      // Verify device was registered in repository
      final devices = await repo.getUserDevices('user_123');
      expect(devices.isNotEmpty, true);
      expect(devices.first.deviceId, service.mockDeviceId);
      expect(devices.first.token, service.mockToken);
      expect(devices.first.isActive, true);
    });

    test('syncUser deactivates device on logout and registers on login', () async {
      await controller.initialize(currentUid: 'user_A');
      await controller.requestPermission();

      var devicesA = await repo.getUserDevices('user_A');
      expect(devicesA.first.isActive, true);

      // User logs out
      await controller.syncUser(null);
      devicesA = await repo.getUserDevices('user_A');
      expect(devicesA.first.isActive, false);

      // User B logs in on the same device
      await controller.syncUser('user_B');
      final devicesB = await repo.getUserDevices('user_B');
      expect(devicesB.first.isActive, true);
      expect(devicesB.first.deviceId, service.mockDeviceId);
    });

    test('Receives foreground message and tracks unread count', () async {
      await controller.initialize(currentUid: 'user_123');

      expect(controller.unreadCount, 0);
      expect(controller.hasUnread, false);

      service.emitForegroundMessage(
        AppNotificationModel(
          id: 'incoming_1',
          title: 'Order Shipped',
          body: 'Your package is on the way',
          receivedAt: DateTime.now(),
        ),
      );

      await pumpEventQueue();

      expect(controller.notifications.length, 1);
      expect(controller.unreadCount, 1);
      expect(controller.hasUnread, true);

      await controller.markAsRead('incoming_1');
      expect(controller.unreadCount, 0);
      expect(controller.hasUnread, false);
    });

    test('Handles notification tap event and delivers callback', () async {
      NotificationTapEvent? capturedEvent;

      await controller.initialize(
        currentUid: 'user_123',
        onNavigate: (event) {
          capturedEvent = event;
        },
      );

      service.emitNotificationTap(
        const NotificationTapEvent(
          title: 'Discount Alert',
          body: 'Tap to view',
          targetRoute: '/customer/catalog',
        ),
      );

      await pumpEventQueue();

      expect(capturedEvent, isNotNull);
      expect(capturedEvent!.targetRoute, '/customer/catalog');
    });

    test('Handles token rotation dynamically', () async {
      await controller.initialize(currentUid: 'user_123');
      await controller.requestPermission();

      service.emitTokenRefresh('rotated_token_99999');
      await pumpEventQueue();

      expect(controller.fcmToken, 'rotated_token_99999');
      final devices = await repo.getUserDevices('user_123');
      expect(devices.first.token, 'rotated_token_99999');
    });
  });

  group('UI NotificationBellButton & NotificationSheet', () {
    late InMemoryNotificationService service;
    late InMemoryNotificationRepository repo;
    late NotificationController controller;

    setUp(() {
      service = InMemoryNotificationService();
      repo = InMemoryNotificationRepository();
      controller = NotificationController(
        service: service,
        repository: repo,
      );
    });

    tearDown(() {
      controller.dispose();
    });

    testWidgets('NotificationBellButton displays unread badge and responds to tap',
        (tester) async {
      await controller.initialize(currentUid: 'user_123');

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<NotificationController>.value(
            value: controller,
            child: const Scaffold(
              appBar: PreferredSize(
                preferredSize: Size.fromHeight(60),
                child: Row(
                  children: [
                    NotificationBellButton(),
                  ],
                ),
              ),
              body: Center(child: Text('Content')),
            ),
          ),
        ),
      );

      // Initially 0 unread, no badge text
      expect(find.byType(NotificationBellButton), findsOneWidget);
      expect(find.text('1'), findsNothing);

      // Add a notification
      await controller.addLocalNotification(
        AppNotificationModel(
          id: 'test_n1',
          title: 'Welcome',
          body: 'Thanks for downloading ShopEase',
          receivedAt: DateTime.now(),
        ),
      );
      await tester.pumpAndSettle();

      // Badge '1' is now visible
      expect(find.text('1'), findsOneWidget);

      // Tap the bell to open the NotificationSheet
      await tester.tap(find.byType(NotificationBellButton));
      await tester.pumpAndSettle();

      // NotificationSheet is opened
      expect(find.byType(NotificationSheet), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Welcome'), findsOneWidget);
      expect(find.text('Thanks for downloading ShopEase'), findsOneWidget);
    });
  });
}


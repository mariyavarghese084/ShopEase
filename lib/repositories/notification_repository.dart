import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';
import '../services/firebase_service.dart';

/// Abstract contract for managing user device tokens and notification inbox in Firestore.
abstract class NotificationRepository {
  /// Saves or updates a device registration entry under `users/{uid}/devices/{deviceId}`.
  Future<void> saveDeviceToken({
    required String uid,
    required DeviceRegistrationModel device,
  });

  /// Deactivates a device registration entry without deleting it.
  Future<void> deactivateDeviceToken({
    required String uid,
    required String deviceId,
  });

  /// Permanently removes a device registration entry.
  Future<void> removeDeviceToken({
    required String uid,
    required String deviceId,
  });

  /// Retrieves all devices currently registered for a specific user.
  Future<List<DeviceRegistrationModel>> getUserDevices(String uid);

  /// Streams the authenticated user's notification feed in real-time.
  Stream<List<AppNotificationModel>> notificationsStream(String uid);

  /// Stores an incoming notification in the user's notification history.
  Future<void> saveInAppNotification({
    required String uid,
    required AppNotificationModel notification,
  });

  /// Marks a specific notification as read.
  Future<void> markNotificationAsRead({
    required String uid,
    required String notificationId,
  });

  /// Clears all stored notifications for the given user.
  Future<void> clearAllNotifications(String uid);

  /// Records an administrative notification campaign in the root `notifications` collection.
  Future<void> sendAdminNotification(AppNotificationModel notification);

  /// Streams administrative campaigns ordered by date with query limit.
  Stream<List<AppNotificationModel>> adminNotificationsStream({int limit = 50});

  /// Deletes an administrative notification campaign.
  Future<void> deleteAdminNotification(String notificationId);
}

/// Cloud Firestore implementation of [NotificationRepository].
class FirestoreNotificationRepository implements NotificationRepository {
  final FirebaseFirestore? _firestore;

  FirestoreNotificationRepository({FirebaseFirestore? firestore})
      : _firestore = firestore;

  FirebaseFirestore? get _db {
    if (_firestore != null) return _firestore;
    if (FirebaseService.isInitialized) {
      return FirebaseService.firestore;
    }
    return null;
  }

  CollectionReference<Map<String, dynamic>>? _devicesRef(String uid) {
    final db = _db;
    if (db == null) return null;
    return db.collection('customers').doc(uid).collection('devices');
  }

  CollectionReference<Map<String, dynamic>>? _legacyDevicesRef(String uid) {
    final db = _db;
    if (db == null) return null;
    return db.collection('users').doc(uid).collection('devices');
  }

  CollectionReference<Map<String, dynamic>>? _notificationsRef(String uid) {
    final db = _db;
    if (db == null) return null;
    return db.collection('customers').doc(uid).collection('notifications');
  }

  CollectionReference<Map<String, dynamic>>? _legacyNotificationsRef(String uid) {
    final db = _db;
    if (db == null) return null;
    return db.collection('users').doc(uid).collection('notifications');
  }

  @override
  Future<void> saveDeviceToken({
    required String uid,
    required DeviceRegistrationModel device,
  }) async {
    final ref = _devicesRef(uid);
    if (ref == null) {
      debugPrint('[NotificationRepo] Offline/Mock: skipping Firestore device write');
      return;
    }

    try {
      await ref.doc(device.deviceId).set(
            device.toMap(),
            SetOptions(merge: true),
          );
      debugPrint(
        '[ShopEase:FCM] Successfully saved device token in Firestore at customers/$uid/devices/${device.deviceId}',
      );

      // Dual-write to users/{uid}/devices for backwards compatibility
      final legacyRef = _legacyDevicesRef(uid);
      if (legacyRef != null) {
        await legacyRef.doc(device.deviceId).set(
              device.toMap(),
              SetOptions(merge: true),
            );
      }
    } catch (e) {
      debugPrint('[ShopEase:FCM] Error saving device token: $e');
    }
  }

  @override
  Future<void> deactivateDeviceToken({
    required String uid,
    required String deviceId,
  }) async {
    final ref = _devicesRef(uid);
    if (ref == null) return;

    try {
      final updateData = {
        'isActive': false,
        'updatedAt': Timestamp.now(),
      };
      await ref.doc(deviceId).update(updateData);
      final legacyRef = _legacyDevicesRef(uid);
      if (legacyRef != null) {
        await legacyRef.doc(deviceId).update(updateData);
      }
      debugPrint('[NotificationRepo] Deactivated device $deviceId for user $uid');
    } catch (e) {
      debugPrint('[NotificationRepo] Notice: could not deactivate device $deviceId: $e');
    }
  }

  @override
  Future<void> removeDeviceToken({
    required String uid,
    required String deviceId,
  }) async {
    final ref = _devicesRef(uid);
    if (ref == null) return;

    try {
      await ref.doc(deviceId).delete();
      final legacyRef = _legacyDevicesRef(uid);
      if (legacyRef != null) {
        await legacyRef.doc(deviceId).delete();
      }
      debugPrint('[NotificationRepo] Removed device $deviceId for user $uid');
    } catch (e) {
      debugPrint('[NotificationRepo] Error removing device: $e');
    }
  }

  @override
  Future<List<DeviceRegistrationModel>> getUserDevices(String uid) async {
    final ref = _devicesRef(uid);
    if (ref == null) return [];

    try {
      final snap = await ref.get();
      if (snap.docs.isNotEmpty) {
        return snap.docs
            .map((doc) => DeviceRegistrationModel.fromMap(doc.id, doc.data()))
            .toList();
      }
      final legacyRef = _legacyDevicesRef(uid);
      if (legacyRef != null) {
        final legacySnap = await legacyRef.get();
        return legacySnap.docs
            .map((doc) => DeviceRegistrationModel.fromMap(doc.id, doc.data()))
            .toList();
      }
      return [];
    } catch (e) {
      debugPrint('[NotificationRepo] Error fetching devices: $e');
      return [];
    }
  }

  @override
  Stream<List<AppNotificationModel>> notificationsStream(String uid) {
    final ref = _notificationsRef(uid);
    if (ref == null) {
      return Stream.value([]);
    }

    return ref
        .orderBy('receivedAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => AppNotificationModel.fromMap(doc.data(), doc.id))
          .toList();
    }).handleError((error) {
      debugPrint('[NotificationRepo] Stream error: $error');
      return <AppNotificationModel>[];
    });
  }

  @override
  Future<void> saveInAppNotification({
    required String uid,
    required AppNotificationModel notification,
  }) async {
    final ref = _notificationsRef(uid);
    if (ref == null) return;

    try {
      await ref.doc(notification.id).set(
            notification.toMap(),
            SetOptions(merge: true),
          );
      final legacyRef = _legacyNotificationsRef(uid);
      if (legacyRef != null) {
        await legacyRef.doc(notification.id).set(
              notification.toMap(),
              SetOptions(merge: true),
            );
      }
    } catch (e) {
      debugPrint('[NotificationRepo] Error saving notification: $e');
    }
  }

  @override
  Future<void> markNotificationAsRead({
    required String uid,
    required String notificationId,
  }) async {
    final ref = _notificationsRef(uid);
    if (ref == null) return;

    try {
      await ref.doc(notificationId).update({'isRead': true});
      final legacyRef = _legacyNotificationsRef(uid);
      if (legacyRef != null) {
        await legacyRef.doc(notificationId).update({'isRead': true});
      }
    } catch (e) {
      debugPrint('[NotificationRepo] Error marking notification as read: $e');
    }
  }

  @override
  Future<void> clearAllNotifications(String uid) async {
    final ref = _notificationsRef(uid);
    if (ref == null) return;

    try {
      final snapshot = await ref.get();
      final batch = ref.firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      final legacyRef = _legacyNotificationsRef(uid);
      if (legacyRef != null) {
        final legacySnapshot = await legacyRef.get();
        final legacyBatch = legacyRef.firestore.batch();
        for (final doc in legacySnapshot.docs) {
          legacyBatch.delete(doc.reference);
        }
        await legacyBatch.commit();
      }
    } catch (e) {
      debugPrint('[NotificationRepo] Error clearing notifications: $e');
    }
  }

  CollectionReference<Map<String, dynamic>>? get _adminCampaignsRef {
    final db = _db;
    if (db == null) return null;
    return db.collection('notifications');
  }

  @override
  Future<void> sendAdminNotification(AppNotificationModel notification) async {
    final ref = _adminCampaignsRef;
    if (ref == null) {
      debugPrint('[NotificationRepo] Mock: skipping Firestore admin notification save');
      return;
    }
    try {
      await ref.doc(notification.id).set(
            notification.toMap(),
            SetOptions(merge: true),
          );
      // If direct customer audience, also insert directly into the target customer's notifications inbox
      if (notification.audience == 'customer' && notification.recipientId != null) {
        await saveInAppNotification(
          uid: notification.recipientId!,
          notification: notification,
        );
      }
      debugPrint('[NotificationRepo] Stored admin notification: ${notification.id}');
    } catch (e) {
      debugPrint('[NotificationRepo] Error storing admin notification: $e');
    }
  }

  @override
  Stream<List<AppNotificationModel>> adminNotificationsStream({int limit = 50}) {
    final ref = _adminCampaignsRef;
    if (ref == null) {
      return Stream.value(<AppNotificationModel>[]);
    }
    return ref
        .orderBy('receivedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => AppNotificationModel.fromMap(doc.data(), doc.id))
              .toList();
        })
        .handleError((error) {
          debugPrint('[NotificationRepo] Admin notifications stream error: $error');
          return <AppNotificationModel>[];
        });
  }

  @override
  Future<void> deleteAdminNotification(String notificationId) async {
    final ref = _adminCampaignsRef;
    if (ref == null) return;
    try {
      await ref.doc(notificationId).delete();
      debugPrint('[NotificationRepo] Deleted admin notification: $notificationId');
    } catch (e) {
      debugPrint('[NotificationRepo] Error deleting admin notification: $e');
    }
  }
}

/// In-memory implementation of [NotificationRepository] for fast, hermetic unit tests.
class InMemoryNotificationRepository implements NotificationRepository {
  final Map<String, Map<String, DeviceRegistrationModel>> _userDevices = {};
  final Map<String, List<AppNotificationModel>> _userNotifications = {};
  final Map<String, StreamController<List<AppNotificationModel>>> _controllers = {};

  StreamController<List<AppNotificationModel>> _getController(String uid) {
    return _controllers.putIfAbsent(
      uid,
      () => StreamController<List<AppNotificationModel>>.broadcast(),
    );
  }

  void _notify(String uid) {
    if (_controllers.containsKey(uid) && !_controllers[uid]!.isClosed) {
      _controllers[uid]!.add(List.of(_userNotifications[uid] ?? []));
    }
  }

  @override
  Future<void> saveDeviceToken({
    required String uid,
    required DeviceRegistrationModel device,
  }) async {
    _userDevices.putIfAbsent(uid, () => {})[device.deviceId] = device;
  }

  @override
  Future<void> deactivateDeviceToken({
    required String uid,
    required String deviceId,
  }) async {
    final userMap = _userDevices[uid];
    if (userMap != null && userMap.containsKey(deviceId)) {
      final existing = userMap[deviceId]!;
      userMap[deviceId] = existing.copyWith(
        isActive: false,
        updatedAt: DateTime.now(),
      );
    }
  }

  @override
  Future<void> removeDeviceToken({
    required String uid,
    required String deviceId,
  }) async {
    _userDevices[uid]?.remove(deviceId);
  }

  @override
  Future<List<DeviceRegistrationModel>> getUserDevices(String uid) async {
    return _userDevices[uid]?.values.toList() ?? [];
  }

  @override
  Stream<List<AppNotificationModel>> notificationsStream(String uid) async* {
    yield List.of(_userNotifications[uid] ?? []);
    yield* _getController(uid).stream;
  }

  @override
  Future<void> saveInAppNotification({
    required String uid,
    required AppNotificationModel notification,
  }) async {
    final list = _userNotifications.putIfAbsent(uid, () => []);
    list.removeWhere((n) => n.id == notification.id);
    list.insert(0, notification);
    _notify(uid);
  }

  @override
  Future<void> markNotificationAsRead({
    required String uid,
    required String notificationId,
  }) async {
    final list = _userNotifications[uid];
    if (list != null) {
      final idx = list.indexWhere((n) => n.id == notificationId);
      if (idx != -1) {
        list[idx] = list[idx].copyWith(isRead: true);
        _notify(uid);
      }
    }
  }

  @override
  Future<void> clearAllNotifications(String uid) async {
    _userNotifications[uid]?.clear();
    _notify(uid);
  }

  final List<AppNotificationModel> _adminNotifications = [];
  final StreamController<List<AppNotificationModel>> _adminStreamController =
      StreamController<List<AppNotificationModel>>.broadcast();

  @override
  Future<void> sendAdminNotification(AppNotificationModel notification) async {
    _adminNotifications.removeWhere((n) => n.id == notification.id);
    _adminNotifications.insert(0, notification);
    _adminStreamController.add(List.of(_adminNotifications));

    // Also dispatch to recipient customer if targeted
    if (notification.audience == 'customer' && notification.recipientId != null) {
      await saveInAppNotification(
        uid: notification.recipientId!,
        notification: notification,
      );
    }
  }

  @override
  Stream<List<AppNotificationModel>> adminNotificationsStream({int limit = 50}) async* {
    yield List.of(_adminNotifications.take(limit));
    yield* _adminStreamController.stream.map((list) => list.take(limit).toList());
  }

  @override
  Future<void> deleteAdminNotification(String notificationId) async {
    _adminNotifications.removeWhere((n) => n.id == notificationId);
    _adminStreamController.add(List.of(_adminNotifications));
  }
}


import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a registered device token entry stored under `users/{uid}/devices/{deviceId}`.
class DeviceRegistrationModel {
  final String deviceId;
  final String token;
  final String platform;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;
  final String? deviceModel;

  const DeviceRegistrationModel({
    required this.deviceId,
    required this.token,
    required this.platform,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
    this.deviceModel,
  });

  Map<String, dynamic> toMap() {
    return {
      'token': token,
      'platform': platform,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'isActive': isActive,
      if (deviceModel != null) 'deviceModel': deviceModel,
    };
  }

  factory DeviceRegistrationModel.fromMap(
    String deviceId,
    Map<String, dynamic> map,
  ) {
    return DeviceRegistrationModel(
      deviceId: deviceId,
      token: map['token'] as String? ?? '',
      platform: map['platform'] as String? ?? 'unknown',
      createdAt: _parseDateTime(map['createdAt']),
      updatedAt: _parseDateTime(map['updatedAt']),
      isActive: map['isActive'] as bool? ?? true,
      deviceModel: map['deviceModel'] as String?,
    );
  }

  DeviceRegistrationModel copyWith({
    String? deviceId,
    String? token,
    String? platform,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    String? deviceModel,
  }) {
    return DeviceRegistrationModel(
      deviceId: deviceId ?? this.deviceId,
      token: token ?? this.token,
      platform: platform ?? this.platform,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      deviceModel: deviceModel ?? this.deviceModel,
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return DateTime.now();
  }
}

/// Represents an in-app or push notification displayed in the notification center.
class AppNotificationModel {
  final String id;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final String type;
  final DateTime receivedAt;
  final bool isRead;
  final String? targetRoute;
  final String? targetId;
  final String? imageUrl;
  final String? audience;
  final String? recipientId;
  final String? recipientName;
  final String? senderAdminId;
  final String deliveryStatus;
  final int readCount;
  final int totalRecipients;

  const AppNotificationModel({
    required this.id,
    required this.title,
    required this.body,
    this.data = const {},
    this.type = 'system',
    required this.receivedAt,
    this.isRead = false,
    this.targetRoute,
    this.targetId,
    this.imageUrl,
    this.audience = 'all',
    this.recipientId,
    this.recipientName,
    this.senderAdminId,
    this.deliveryStatus = 'sent',
    this.readCount = 0,
    this.totalRecipients = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'data': data,
      'type': type,
      'receivedAt': Timestamp.fromDate(receivedAt),
      'isRead': isRead,
      if (targetRoute != null) 'targetRoute': targetRoute,
      if (targetId != null) 'targetId': targetId,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (audience != null) 'audience': audience,
      if (recipientId != null) 'recipientId': recipientId,
      if (recipientName != null) 'recipientName': recipientName,
      if (senderAdminId != null) 'senderAdminId': senderAdminId,
      'deliveryStatus': deliveryStatus,
      'readCount': readCount,
      'totalRecipients': totalRecipients,
    };
  }

  factory AppNotificationModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    final id = docId ?? map['id'] as String? ?? '';
    final rawData = map['data'];
    final dataMap = rawData is Map
        ? rawData.map((k, v) => MapEntry(k.toString(), v))
        : <String, dynamic>{};

    return AppNotificationModel(
      id: id,
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? map['message'] as String? ?? '',
      data: dataMap,
      type: map['type'] as String? ?? 'system',
      receivedAt: DeviceRegistrationModel._parseDateTime(map['receivedAt'] ?? map['createdAt']),
      isRead: map['isRead'] as bool? ?? false,
      targetRoute: map['targetRoute'] as String?,
      targetId: map['targetId'] as String?,
      imageUrl: map['imageUrl'] as String?,
      audience: map['audience'] as String? ?? 'all',
      recipientId: map['recipientId'] as String?,
      recipientName: map['recipientName'] as String?,
      senderAdminId: map['senderAdminId'] as String?,
      deliveryStatus: map['deliveryStatus'] as String? ?? 'sent',
      readCount: (map['readCount'] as num?)?.toInt() ?? 0,
      totalRecipients: (map['totalRecipients'] as num?)?.toInt() ?? 0,
    );
  }

  AppNotificationModel copyWith({
    String? id,
    String? title,
    String? body,
    Map<String, dynamic>? data,
    String? type,
    DateTime? receivedAt,
    bool? isRead,
    String? targetRoute,
    String? targetId,
    String? imageUrl,
    String? audience,
    String? recipientId,
    String? recipientName,
    String? senderAdminId,
    String? deliveryStatus,
    int? readCount,
    int? totalRecipients,
  }) {
    return AppNotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      data: data ?? this.data,
      type: type ?? this.type,
      receivedAt: receivedAt ?? this.receivedAt,
      isRead: isRead ?? this.isRead,
      targetRoute: targetRoute ?? this.targetRoute,
      targetId: targetId ?? this.targetId,
      imageUrl: imageUrl ?? this.imageUrl,
      audience: audience ?? this.audience,
      recipientId: recipientId ?? this.recipientId,
      recipientName: recipientName ?? this.recipientName,
      senderAdminId: senderAdminId ?? this.senderAdminId,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      readCount: readCount ?? this.readCount,
      totalRecipients: totalRecipients ?? this.totalRecipients,
    );
  }
}


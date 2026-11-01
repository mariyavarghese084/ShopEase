import 'package:flutter/material.dart';
import 'product_model.dart';

/// Progress steps of an e-commerce order.
enum OrderProgressStatus {
  placed,
  processing,
  shipped,
  outForDelivery,
  delivered,
  cancelled,
}

extension OrderProgressStatusExtension on OrderProgressStatus {
  String get label {
    switch (this) {
      case OrderProgressStatus.placed:
        return 'Order Placed';
      case OrderProgressStatus.processing:
        return 'Processing';
      case OrderProgressStatus.shipped:
        return 'Dispatched';
      case OrderProgressStatus.outForDelivery:
        return 'Out for Delivery';
      case OrderProgressStatus.delivered:
        return 'Delivered';
      case OrderProgressStatus.cancelled:
        return 'Cancelled';
    }
  }

  String get description {
    switch (this) {
      case OrderProgressStatus.placed:
        return 'Your order has been registered and confirmed successfully.';
      case OrderProgressStatus.processing:
        return 'Items are being carefully prepared in our premium packaging.';
      case OrderProgressStatus.shipped:
        return 'Your parcel has been handed over to our express courier service.';
      case OrderProgressStatus.outForDelivery:
        return 'The courier is on the way to your delivery address.';
      case OrderProgressStatus.delivered:
        return 'Parcel delivered. We hope you enjoy your luxury cosmetics!';
      case OrderProgressStatus.cancelled:
        return 'This order has been cancelled and will not be processed further.';
    }
  }

  IconData get icon {
    switch (this) {
      case OrderProgressStatus.placed:
        return Icons.receipt_long_rounded;
      case OrderProgressStatus.processing:
        return Icons.inventory_2_rounded;
      case OrderProgressStatus.shipped:
        return Icons.local_shipping_rounded;
      case OrderProgressStatus.outForDelivery:
        return Icons.directions_bike_rounded;
      case OrderProgressStatus.delivered:
        return Icons.check_circle_rounded;
      case OrderProgressStatus.cancelled:
        return Icons.cancel_outlined;
    }
  }

  int get stepIndex {
    switch (this) {
      case OrderProgressStatus.placed:
        return 0;
      case OrderProgressStatus.processing:
        return 1;
      case OrderProgressStatus.shipped:
        return 2;
      case OrderProgressStatus.outForDelivery:
        return 3;
      case OrderProgressStatus.delivered:
        return 4;
      case OrderProgressStatus.cancelled:
        return -1;
    }
  }
}

/// Records a historical fulfillment status update for audit trail.
class OrderStatusHistoryEntry {
  final OrderProgressStatus status;
  final DateTime timestamp;
  final String? note;
  final String? updatedBy;

  const OrderStatusHistoryEntry({
    required this.status,
    required this.timestamp,
    this.note,
    this.updatedBy,
  });

  Map<String, dynamic> toMap() => {
        'status': status.name,
        'timestamp': timestamp.toIso8601String(),
        if (note != null) 'note': note,
        if (updatedBy != null) 'updatedBy': updatedBy,
      };

  factory OrderStatusHistoryEntry.fromMap(Map<String, dynamic> map) {
    OrderProgressStatus parseStatus(String? name) {
      for (final s in OrderProgressStatus.values) {
        if (s.name == name) return s;
      }
      return OrderProgressStatus.placed;
    }

    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is DateTime) return value;
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      try {
        return (value as dynamic).toDate() as DateTime;
      } catch (_) {
        return DateTime.now();
      }
    }

    return OrderStatusHistoryEntry(
      status: parseStatus(map['status'] as String?),
      timestamp: parseDate(map['timestamp']),
      note: map['note'] as String?,
      updatedBy: map['updatedBy'] as String?,
    );
  }
}

/// A line item within an order snapshot.
class OrderItemModel {
  final String productId;
  final String productName;
  final String subtitle;
  final String size;
  final double price;
  final int quantity;
  final Color visualColor;
  final IconData visualIcon;

  const OrderItemModel({
    required this.productId,
    required this.productName,
    required this.subtitle,
    required this.size,
    required this.price,
    required this.quantity,
    this.visualColor = const Color(0xFF8A4652),
    this.visualIcon = Icons.auto_awesome,
  });

  double get totalPrice => price * quantity;

  factory OrderItemModel.fromProduct(
    ProductModel product, {
    int quantity = 1,
    String? size,
  }) {
    return OrderItemModel(
      productId: product.id,
      productName: product.name,
      subtitle: product.subtitle,
      size: size ?? product.volume,
      price: product.price,
      quantity: quantity,
      visualColor: product.visualColor,
      visualIcon: product.visualIcon,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'subtitle': subtitle,
      'size': size,
      'price': price,
      'quantity': quantity,
      'visualColor': visualColor.toARGB32(),
      'visualIcon': visualIcon.codePoint,
    };
  }

  static IconData _parseOrderItemIcon(int? code) {
    if (code == null) return Icons.auto_awesome;
    if (code == Icons.spa_outlined.codePoint) return Icons.spa_outlined;
    if (code == Icons.local_florist_outlined.codePoint) {
      return Icons.local_florist_outlined;
    }
    if (code == Icons.eco_outlined.codePoint) return Icons.eco_outlined;
    if (code == Icons.diamond_outlined.codePoint) return Icons.diamond_outlined;
    if (code == Icons.star_rounded.codePoint) return Icons.star_rounded;
    if (code == Icons.shopping_bag_outlined.codePoint) {
      return Icons.shopping_bag_outlined;
    }
    return Icons.auto_awesome;
  }

  factory OrderItemModel.fromMap(Map<String, dynamic> map) {
    return OrderItemModel(
      productId: map['productId'] as String? ?? '',
      productName: map['productName'] as String? ?? '',
      subtitle: map['subtitle'] as String? ?? '',
      size: map['size'] as String? ?? '100 ml',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      visualColor: map['visualColor'] != null
          ? Color((map['visualColor'] as num).toInt())
          : const Color(0xFF8A4652),
      visualIcon: _parseOrderItemIcon((map['visualIcon'] as num?)?.toInt()),
    );
  }
}

/// Full customer order model with tracking metadata and fulfillment history.
class OrderModel {
  final String id;
  final String? customerId;
  final List<OrderItemModel> items;
  final double subtotal;
  final double discount;
  final double shippingFee;
  final double total;
  final OrderProgressStatus status;
  final String shippingName;
  final String shippingPhone;
  final String shippingAddress;
  final String shippingCity;
  final String shippingPostalCode;
  final String paymentMethod;
  final String paymentStatus;
  final String trackingNumber;
  final String courierName;
  final String estimatedDelivery;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? updatedBy;
  final List<OrderStatusHistoryEntry> statusHistory;
  final String? cancelReason;

  const OrderModel({
    required this.id,
    this.customerId,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.shippingFee,
    required this.total,
    required this.status,
    required this.shippingName,
    required this.shippingPhone,
    required this.shippingAddress,
    required this.shippingCity,
    required this.shippingPostalCode,
    required this.paymentMethod,
    this.paymentStatus = 'Paid',
    required this.trackingNumber,
    required this.courierName,
    required this.estimatedDelivery,
    required this.createdAt,
    this.updatedAt,
    this.updatedBy,
    this.statusHistory = const [],
    this.cancelReason,
  });

  int get totalItemCount => items.fold(0, (sum, item) => sum + item.quantity);

  /// Validates whether a proposed status transition is permitted by workflow.
  static bool canTransition(OrderProgressStatus current, OrderProgressStatus next) {
    if (current == next) return false;
    if (current == OrderProgressStatus.delivered ||
        current == OrderProgressStatus.cancelled) {
      return false; // Terminal states cannot be changed
    }
    if (next == OrderProgressStatus.cancelled) {
      return true; // Can cancel anytime before final delivery
    }
    switch (current) {
      case OrderProgressStatus.placed:
        return next == OrderProgressStatus.processing;
      case OrderProgressStatus.processing:
        return next == OrderProgressStatus.shipped;
      case OrderProgressStatus.shipped:
        return next == OrderProgressStatus.outForDelivery;
      case OrderProgressStatus.outForDelivery:
        return next == OrderProgressStatus.delivered;
      default:
        return false;
    }
  }

  /// Lists all valid next statuses from the current status.
  static List<OrderProgressStatus> availableTransitions(OrderProgressStatus current) {
    switch (current) {
      case OrderProgressStatus.placed:
        return [OrderProgressStatus.processing, OrderProgressStatus.cancelled];
      case OrderProgressStatus.processing:
        return [OrderProgressStatus.shipped, OrderProgressStatus.cancelled];
      case OrderProgressStatus.shipped:
        return [OrderProgressStatus.outForDelivery, OrderProgressStatus.cancelled];
      case OrderProgressStatus.outForDelivery:
        return [OrderProgressStatus.delivered, OrderProgressStatus.cancelled];
      case OrderProgressStatus.delivered:
      case OrderProgressStatus.cancelled:
        return [];
    }
  }

  OrderModel copyWith({
    String? id,
    String? customerId,
    List<OrderItemModel>? items,
    double? subtotal,
    double? discount,
    double? shippingFee,
    double? total,
    OrderProgressStatus? status,
    String? shippingName,
    String? shippingPhone,
    String? shippingAddress,
    String? shippingCity,
    String? shippingPostalCode,
    String? paymentMethod,
    String? paymentStatus,
    String? trackingNumber,
    String? courierName,
    String? estimatedDelivery,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? updatedBy,
    List<OrderStatusHistoryEntry>? statusHistory,
    String? cancelReason,
  }) {
    return OrderModel(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      shippingFee: shippingFee ?? this.shippingFee,
      total: total ?? this.total,
      status: status ?? this.status,
      shippingName: shippingName ?? this.shippingName,
      shippingPhone: shippingPhone ?? this.shippingPhone,
      shippingAddress: shippingAddress ?? this.shippingAddress,
      shippingCity: shippingCity ?? this.shippingCity,
      shippingPostalCode: shippingPostalCode ?? this.shippingPostalCode,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      trackingNumber: trackingNumber ?? this.trackingNumber,
      courierName: courierName ?? this.courierName,
      estimatedDelivery: estimatedDelivery ?? this.estimatedDelivery,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
      statusHistory: statusHistory ?? this.statusHistory,
      cancelReason: cancelReason ?? this.cancelReason,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      if (customerId != null) 'customerId': customerId,
      'items': items.map((i) => i.toMap()).toList(),
      'subtotal': subtotal,
      'discount': discount,
      'shippingFee': shippingFee,
      'total': total,
      'status': status.name,
      'shippingName': shippingName,
      'shippingPhone': shippingPhone,
      'shippingAddress': shippingAddress,
      'shippingCity': shippingCity,
      'shippingPostalCode': shippingPostalCode,
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      'trackingNumber': trackingNumber,
      'courierName': courierName,
      'estimatedDelivery': estimatedDelivery,
      'createdAt': createdAt.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      if (updatedBy != null) 'updatedBy': updatedBy,
      if (statusHistory.isNotEmpty)
        'statusHistory': statusHistory.map((h) => h.toMap()).toList(),
      if (cancelReason != null) 'cancelReason': cancelReason,
    };
  }

  factory OrderModel.fromMap(Map<String, dynamic> map, {String? id}) {
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is DateTime) return value;
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      try {
        return (value as dynamic).toDate() as DateTime;
      } catch (_) {
        return DateTime.now();
      }
    }

    OrderProgressStatus parseStatus(String? name) {
      for (final s in OrderProgressStatus.values) {
        if (s.name == name) return s;
      }
      return OrderProgressStatus.processing;
    }

    final rawItems = map['items'] as List<dynamic>? ?? [];
    final parsedItems = rawItems
        .map((i) => OrderItemModel.fromMap(Map<String, dynamic>.from(i as Map)))
        .toList();

    final rawPaymentStatus = map['paymentStatus'] as String?;
    final defaultPaymentStatus =
        (map['paymentMethod'] as String? ?? '').toLowerCase().contains('cash')
            ? 'Pending'
            : 'Paid';
    final paymentStatus = rawPaymentStatus ?? defaultPaymentStatus;

    final rawHistory = map['statusHistory'] as List<dynamic>? ?? [];
    final statusHistory = rawHistory
        .map((h) =>
            OrderStatusHistoryEntry.fromMap(Map<String, dynamic>.from(h as Map)))
        .toList();

    return OrderModel(
      id: id ?? (map['id'] as String? ?? ''),
      customerId: map['customerId'] as String?,
      items: parsedItems,
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      discount: (map['discount'] as num?)?.toDouble() ?? 0.0,
      shippingFee: (map['shippingFee'] as num?)?.toDouble() ?? 0.0,
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
      status: parseStatus(map['status'] as String?),
      shippingName: map['shippingName'] as String? ?? '',
      shippingPhone: map['shippingPhone'] as String? ?? '',
      shippingAddress: map['shippingAddress'] as String? ?? '',
      shippingCity: map['shippingCity'] as String? ?? '',
      shippingPostalCode: map['shippingPostalCode'] as String? ?? '',
      paymentMethod: map['paymentMethod'] as String? ?? '',
      paymentStatus: paymentStatus,
      trackingNumber: map['trackingNumber'] as String? ?? '',
      courierName: map['courierName'] as String? ?? 'AÈRA Express Courier',
      estimatedDelivery: map['estimatedDelivery'] as String? ?? 'In 1-2 days',
      createdAt: parseDate(map['createdAt']),
      updatedAt: map['updatedAt'] != null ? parseDate(map['updatedAt']) : null,
      updatedBy: map['updatedBy'] as String?,
      statusHistory: statusHistory,
      cancelReason: map['cancelReason'] as String?,
    );
  }
}

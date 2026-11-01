import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a customer profile document stored in Firestore at `customers/{uid}`.
class CustomerModel {
  final String uid;
  final String fullName;
  final String email;
  final String? phoneNumber;
  final String? photoUrl;
  final String? address;
  final String role;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CustomerModel({
    required this.uid,
    required this.fullName,
    required this.email,
    this.phoneNumber,
    this.photoUrl,
    this.address,
    this.role = 'customer',
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isAdmin => role.trim().toLowerCase() == 'admin';

  CustomerModel copyWith({
    String? uid,
    String? fullName,
    String? email,
    String? phoneNumber,
    String? photoUrl,
    String? address,
    String? role,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CustomerModel(
      uid: uid ?? this.uid,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoUrl: photoUrl ?? this.photoUrl,
      address: address ?? this.address,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'fullName': fullName,
      'email': email,
      if (phoneNumber != null) 'phoneNumber': phoneNumber,
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (address != null) 'address': address,
      'role': role,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory CustomerModel.fromMap(Map<String, dynamic> map, {String? uid}) {
    DateTime parseDateTime(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      } else if (value is String) {
        return DateTime.tryParse(value) ?? DateTime.now();
      } else if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      return DateTime.now();
    }

    return CustomerModel(
      uid: uid ?? (map['uid'] as String? ?? ''),
      fullName: map['fullName'] as String? ?? '',
      email: map['email'] as String? ?? '',
      phoneNumber: map['phoneNumber'] as String?,
      photoUrl: map['photoUrl'] as String?,
      address: map['address'] as String?,
      role: (map['role'] as String?)?.trim().toLowerCase() ?? 'customer',
      createdAt: parseDateTime(map['createdAt']),
      updatedAt: parseDateTime(map['updatedAt']),
    );
  }

  factory CustomerModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data() ?? {};
    return CustomerModel.fromMap(data, uid: snapshot.id);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CustomerModel && other.uid == uid;
  }

  @override
  int get hashCode => uid.hashCode;
}

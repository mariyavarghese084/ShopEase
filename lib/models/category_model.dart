import 'package:flutter/material.dart';

/// Represents a product category in ShopEase.
class CategoryModel {
  final String id;
  final String name;
  final IconData icon;
  final int? itemCount;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.icon,
    this.itemCount,
  });

  CategoryModel copyWith({
    String? id,
    String? name,
    IconData? icon,
    int? itemCount,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      itemCount: itemCount ?? this.itemCount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'iconCode': icon.codePoint,
      if (itemCount != null) 'itemCount': itemCount,
    };
  }

  static IconData _parseCategoryIcon(int? code) {
    if (code == null) return Icons.category_outlined;
    if (code == Icons.auto_awesome.codePoint) return Icons.auto_awesome;
    if (code == Icons.local_florist_outlined.codePoint) return Icons.local_florist_outlined;
    if (code == Icons.spa_outlined.codePoint) return Icons.spa_outlined;
    if (code == Icons.eco_outlined.codePoint) return Icons.eco_outlined;
    if (code == Icons.diamond_outlined.codePoint) return Icons.diamond_outlined;
    return Icons.category_outlined;
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      icon: _parseCategoryIcon(map['iconCode'] as int?),
      itemCount: map['itemCount'] as int?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CategoryModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

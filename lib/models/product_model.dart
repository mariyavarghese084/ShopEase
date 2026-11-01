import 'package:flutter/material.dart';

/// Represents a fashion merchandise item in ShopEase.
class ProductModel {
  final String id;
  final String name;
  final String brand;
  final String description;
  final double price;
  final double? originalPrice;
  final String categoryId;
  final String categoryName;
  final double rating;
  final int reviewCount;
  final bool isFeatured;
  final int stockQuantity;
  final bool isAvailable;
  final String? tag;
  final IconData visualIcon;
  final Color visualColor;
  final Color? secondaryColor;
  final String subtitle;
  final String volume;
  final List<String> availableSizes;
  final String? topNote;
  final String? heartNote;
  final String? baseNote;
  final String? imageUrl;

  const ProductModel({
    required this.id,
    required this.name,
    this.brand = 'AÈRA',
    required this.description,
    required this.price,
    this.originalPrice,
    required this.categoryId,
    required this.categoryName,
    this.rating = 4.5,
    this.reviewCount = 0,
    this.isFeatured = false,
    this.stockQuantity = 10,
    this.isAvailable = true,
    this.tag,
    this.visualIcon = Icons.auto_awesome,
    this.visualColor = const Color(0xFF8A4652),
    this.secondaryColor,
    this.subtitle = 'LUXURY COSMETICS',
    this.volume = 'Full Size',
    this.availableSizes = const ['Standard', 'Deluxe'],
    this.topNote,
    this.heartNote,
    this.baseNote,
    this.imageUrl,
  });

  /// Compatibility alias for the local or remote image asset path.
  String? get imageAssetPath => imageUrl;

  /// Returns true if this product has a discount.
  bool get hasDiscount => originalPrice != null && originalPrice! > price;

  /// Calculates percentage saved if a discount is present.
  int get discountPercentage {
    if (!hasDiscount || originalPrice == 0) return 0;
    return (((originalPrice! - price) / originalPrice!) * 100).round();
  }

  ProductModel copyWith({
    String? id,
    String? name,
    String? brand,
    String? description,
    double? price,
    double? originalPrice,
    String? categoryId,
    String? categoryName,
    double? rating,
    int? reviewCount,
    bool? isFeatured,
    int? stockQuantity,
    bool? isAvailable,
    String? tag,
    IconData? visualIcon,
    Color? visualColor,
    Color? secondaryColor,
    String? subtitle,
    String? volume,
    List<String>? availableSizes,
    String? topNote,
    String? heartNote,
    String? baseNote,
    String? imageUrl,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      description: description ?? this.description,
      price: price ?? this.price,
      originalPrice: originalPrice ?? this.originalPrice,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      isFeatured: isFeatured ?? this.isFeatured,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      isAvailable: isAvailable ?? this.isAvailable,
      tag: tag ?? this.tag,
      visualIcon: visualIcon ?? this.visualIcon,
      visualColor: visualColor ?? this.visualColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      subtitle: subtitle ?? this.subtitle,
      volume: volume ?? this.volume,
      availableSizes: availableSizes ?? this.availableSizes,
      topNote: topNote ?? this.topNote,
      heartNote: heartNote ?? this.heartNote,
      baseNote: baseNote ?? this.baseNote,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'brand': brand,
      'description': description,
      'price': price,
      'originalPrice': originalPrice,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'rating': rating,
      'reviewCount': reviewCount,
      'isFeatured': isFeatured,
      'stockQuantity': stockQuantity,
      'isAvailable': isAvailable,
      'tag': tag,
      'imageUrl': imageUrl,
      'subtitle': subtitle,
      'volume': volume,
      'availableSizes': availableSizes,
    };
  }

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    return ProductModel(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      brand: map['brand'] as String? ?? 'AÈRA',
      description: map['description'] as String? ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      originalPrice: (map['originalPrice'] as num?)?.toDouble(),
      categoryId: map['categoryId'] as String? ?? '',
      categoryName: map['categoryName'] as String? ?? '',
      rating: (map['rating'] as num?)?.toDouble() ?? 4.5,
      reviewCount: (map['reviewCount'] as num?)?.toInt() ?? 0,
      isFeatured: map['isFeatured'] as bool? ?? false,
      stockQuantity: (map['stockQuantity'] as num?)?.toInt() ?? 10,
      isAvailable: map['isAvailable'] as bool? ?? true,
      tag: map['tag'] as String?,
      imageUrl: map['imageUrl'] as String?,
      subtitle: map['subtitle'] as String? ?? 'LUXURY COSMETICS',
      volume: map['volume'] as String? ?? 'Full Size',
      availableSizes: (map['availableSizes'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const ['Standard', 'Deluxe'],
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProductModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

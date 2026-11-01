import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../models/product_model.dart';

/// Reusable luxury fragrance product card inspired by the AÈRA reference UI.
class ProductCard extends StatelessWidget {
  final ProductModel product;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onAddToCart;
  final VoidCallback? onTap;
  final String? heroTag;

  const ProductCard({
    super.key,
    required this.product,
    this.isFavorite = false,
    this.onFavoriteToggle,
    this.onAddToCart,
    this.onTap,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider.withAlpha(140), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2C2224).withAlpha(10),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top Image Container & Badges ──────────────────────────────
              Expanded(
                flex: 11,
                child: Stack(
                  children: [
              // Ambient luxury backdrop with floral / soft gradient
                    Container(
                      width: double.infinity,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            (product.secondaryColor ?? product.visualColor).withAlpha(35),
                            AppColors.background,
                          ],
                        ),
                      ),
                      child: Center(
                        child: Hero(
                          tag: heroTag ?? 'product_img_${product.id}',
                          child: product.imageUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: product.imageUrl!.startsWith('http://') ||
                                          product.imageUrl!.startsWith('https://')
                                      ? Image.network(
                                          product.imageUrl!,
                                          width: 90,
                                          height: 90,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) =>
                                              _buildIconFallback(product),
                                        )
                                      : Image.asset(
                                          product.imageUrl!,
                                          width: 90,
                                          height: 90,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) =>
                                              _buildIconFallback(product),
                                        ),
                                )
                              : _buildIconFallback(product),
                        ),
                      ),
                    ),

                    // Tag Badge (Bestseller / Sale / New / Limited)
                    if (product.tag != null)
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: product.tag == 'Sale'
                                ? const Color(0xFFC8A87D)
                                : AppColors.luxuryWine,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.luxuryWine.withAlpha(40),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            product.hasDiscount
                                ? '-${product.discountPercentage}%'
                                : (product.tag ?? ''),
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppColors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),

                    // Favorite Button
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Material(
                        color: Colors.transparent,
                        child: IconButton(
                          iconSize: 20,
                          splashRadius: 20,
                          icon: Icon(
                            isFavorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_outline_rounded,
                            color: isFavorite
                                ? AppColors.luxuryWine
                                : AppColors.secondaryText.withAlpha(180),
                          ),
                          onPressed: onFavoriteToggle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Product Details Section ───────────────────────────────────
              Expanded(
                flex: 9,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Brand / Subtitle & Rating
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  product.brand.isNotEmpty
                                      ? '${product.brand.toUpperCase()} • ${product.subtitle}'
                                      : product.subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.champagneGold,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    size: 12,
                                    color: Color(0xFFFFB300),
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    product.rating.toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.mainText,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),

                          // Product Name
                          Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.mainText,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),

                      // Price & Quick Add Button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '₹${product.price.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.luxuryWine,
                                ),
                              ),
                              if (product.hasDiscount)
                                Text(
                                  '₹${product.originalPrice!.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    decoration: TextDecoration.lineThrough,
                                    color: AppColors.secondaryText,
                                  ),
                                ),
                            ],
                          ),

                          // Circular Quick Add to cart button
                          Material(
                            color: AppColors.luxuryWine,
                            shape: const CircleBorder(),
                            elevation: 1,
                            shadowColor: AppColors.luxuryWine.withAlpha(80),
                            child: InkWell(
                              onTap: onAddToCart,
                              customBorder: const CircleBorder(),
                              child: const Padding(
                                padding: EdgeInsets.all(6),
                                child: Icon(
                                  Icons.shopping_bag_outlined,
                                  size: 14,
                                  color: AppColors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Fallback icon+gradient display shown when [product.imageUrl] is null
  /// or when the asset image fails to load.
  static Widget _buildIconFallback(ProductModel product) {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            product.visualColor.withAlpha(80),
            product.visualColor,
          ],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: product.visualColor.withAlpha(60),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            product.visualIcon,
            size: 38,
            color: AppColors.white,
          ),
          Positioned(
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.white.withAlpha(50),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                product.volume,
                style: const TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: AppColors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

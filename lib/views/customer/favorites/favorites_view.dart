import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../controllers/cart_controller.dart';
import '../../../controllers/home_controller.dart';
import '../../../core/constants/app_constants.dart';
import '../../../widgets/luxury_ui_components.dart';
import '../../../widgets/product_card.dart';
import '../product_detail/product_detail_view.dart';

/// Favorites / Wishlist screen inspired by the AÈRA reference UI screen ('Të Preferuarat').
class FavoritesView extends StatefulWidget {
  final bool showBackButton;

  const FavoritesView({super.key, this.showBackButton = false});

  @override
  State<FavoritesView> createState() => _FavoritesViewState();
}

class _FavoritesViewState extends State<FavoritesView> {
  String _selectedCategoryFilter = 'all';

  @override
  Widget build(BuildContext context) {
    return Consumer2<HomeController, CartController>(
      builder: (context, home, cart, _) {
        final sourceList =
            home.allProducts.isNotEmpty ? home.allProducts : home.displayedProducts;
        final allFavoritedProducts = sourceList
            .where((p) => home.isFavorite(p.id))
            .toList();

        final filteredFavorites = _selectedCategoryFilter == 'all'
            ? allFavoritedProducts
            : allFavoritedProducts
                .where((p) => p.categoryId == _selectedCategoryFilter)
                .toList();

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.background,
            elevation: 0,
            leading: widget.showBackButton
                ? IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                : null,
            title: const Text(
              'Favorites',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.mainText,
                letterSpacing: -0.3,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Tap the heart icon to remove a cosmetic from favorites.'),
                      backgroundColor: AppColors.luxuryWine,
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                child: const Text(
                  'Edit',
                  style: TextStyle(
                    color: AppColors.luxuryWine,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              // ── Filter Pills ──────────────────────────────────────────────
              SizedBox(
                height: 44,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildFilterChip(
                      label: 'All (${allFavoritedProducts.length})',
                      categoryId: 'all',
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: 'Women',
                      categoryId: 'women',
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: 'Men',
                      categoryId: 'men',
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: 'Unisex',
                      categoryId: 'unisex',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.sm),

              // ── Product Grid ──────────────────────────────────────────────
              Expanded(
                child: filteredFavorites.isEmpty
                    ? _buildEmptyFavorites(context, home)
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.maxWidth;
                          final int crossAxisCount = width < 600 ? 2 : (width < 960 ? 3 : 4);

                          return GridView.builder(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            physics: const BouncingScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              childAspectRatio: 0.70,
                              crossAxisSpacing: AppSpacing.md,
                              mainAxisSpacing: AppSpacing.md,
                            ),
                            itemCount: filteredFavorites.length,
                            itemBuilder: (context, index) {
                              final product = filteredFavorites[index];

                              return StaggeredSlideFade(
                                index: index,
                                child: ProductCard(
                                  product: product,
                                  heroTag: 'fav_grid_${product.id}',
                                  isFavorite: true,
                                  onFavoriteToggle: () {
                                    home.toggleFavorite(product.id);
                                  },
                                  onAddToCart: () {
                                    cart.addItem(product);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Added to bag: ${product.name}'),
                                        backgroundColor: AppColors.luxuryWine,
                                        duration: const Duration(seconds: 1),
                                      ),
                                    );
                                  },
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            ProductDetailView(
                                              product: product,
                                              heroTag: 'fav_grid_${product.id}',
                                            ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip({required String label, required String categoryId}) {
    final isSelected = _selectedCategoryFilter == categoryId;

    return FilterChip(
      selected: isSelected,
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? AppColors.white : AppColors.mainText,
      ),
      selectedColor: AppColors.luxuryWine,
      backgroundColor: AppColors.cardBackground,
      showCheckmark: false,
      side: BorderSide(
        color: isSelected ? AppColors.luxuryWine : AppColors.divider,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      onSelected: (_) {
        setState(() => _selectedCategoryFilter = categoryId);
      },
    );
  }

  Widget _buildEmptyFavorites(BuildContext context, HomeController home) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.luxuryWine.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.favorite_outline_rounded,
                size: 48,
                color: AppColors.luxuryWine,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'No favorite cosmetics yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.mainText,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Tap the heart icon on any cosmetic you love to quickly find it here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.secondaryText),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: () {
                home.setBottomNavIndex(1); // Collections
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.luxuryWine,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Discover Collections'),
            ),
          ],
        ),
      ),
    );
  }
}

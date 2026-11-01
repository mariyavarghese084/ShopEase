import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../controllers/cart_controller.dart';
import '../../../controllers/home_controller.dart';
import '../../../core/constants/app_constants.dart';
import '../../../widgets/product_card.dart';
import '../product_detail/product_detail_view.dart';

/// Collections & Product Catalog view inspired by the AÈRA reference UI.
class CatalogView extends StatefulWidget {
  final bool showBackButton;

  const CatalogView({super.key, this.showBackButton = false});

  @override
  State<CatalogView> createState() => _CatalogViewState();
}

class _CatalogViewState extends State<CatalogView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<HomeController, CartController>(
      builder: (context, home, cart, _) {
        final products = home.displayedProducts;

        if (_searchController.text != home.searchQuery &&
            !_searchController.value.isComposingRangeValid) {
          _searchController.value = TextEditingValue(
            text: home.searchQuery,
            selection: TextSelection.collapsed(offset: home.searchQuery.length),
          );
        }

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
              'Collections',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.mainText,
                letterSpacing: -0.3,
              ),
            ),
            actions: [
              IconButton(
                onPressed: () {
                  // If in tabbed home, navigate to cart tab or push route
                  home.setBottomNavIndex(2);
                },
                icon: Badge(
                  backgroundColor: AppColors.luxuryWine,
                  label: Text('${cart.itemCount}'),
                  isLabelVisible: cart.itemCount > 0,
                  child: const Icon(
                    Icons.shopping_bag_outlined,
                    color: AppColors.mainText,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
          ),
          body: Column(
            children: [
              // ── Search Field with Filter Icon ─────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.divider),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.mainText.withAlpha(8),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) => home.setSearchQuery(val),
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.mainText,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search cosmetics, collections...',
                            hintStyle: const TextStyle(
                              fontSize: 13,
                              color: AppColors.secondaryText,
                            ),
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              color: AppColors.luxuryWine,
                              size: 20,
                            ),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      _searchController.clear();
                                      home.clearSearch();
                                      setState(() {});
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    // Filter icon button
                    Material(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          _showFilterBottomSheet(context, home);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.divider),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.tune_rounded,
                            color: AppColors.luxuryWine,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xs),

              // ── Category Filter Pills ─────────────────────────────────────
              SizedBox(
                height: 44,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  scrollDirection: Axis.horizontal,
                  itemCount: home.categories.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final cat = home.categories[index];
                    final isSelected = home.selectedCategoryId == cat.id;

                    return FilterChip(
                      selected: isSelected,
                      label: Text(cat.name),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? AppColors.white : AppColors.mainText,
                      ),
                      selectedColor: AppColors.luxuryWine,
                      backgroundColor: AppColors.cardBackground,
                      checkmarkColor: AppColors.white,
                      showCheckmark: false,
                      side: BorderSide(
                        color: isSelected ? AppColors.luxuryWine : AppColors.divider,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      onSelected: (_) {
                        home.selectCategory(cat.id);
                      },
                    );
                  },
                ),
              ),

              const SizedBox(height: AppSpacing.sm),

              // ── Product Grid ──────────────────────────────────────────────
              Expanded(
                child: home.isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.luxuryWine),
                      )
                    : products.isEmpty
                        ? _buildEmptyState(home)
                        : GridView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm,
                            ),
                            physics: const BouncingScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.65,
                              crossAxisSpacing: AppSpacing.md,
                              mainAxisSpacing: AppSpacing.md,
                            ),
                            itemCount: products.length,
                            itemBuilder: (context, index) {
                              final product = products[index];

                              return ProductCard(
                                product: product,
                                heroTag: 'catalog_grid_${product.id}',
                                isFavorite: home.isFavorite(product.id),
                                onFavoriteToggle: () {
                                  home.toggleFavorite(product.id);
                                },
                                onAddToCart: () {
                                  cart.addItem(product, quantity: 1);
                                  ScaffoldMessenger.of(context).clearSnackBars();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          const Icon(
                                            Icons.check_circle_rounded,
                                            color: AppColors.white,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Added to bag: "${product.name}"',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                        ],
                                      ),
                                      backgroundColor: AppColors.luxuryWine,
                                      behavior: SnackBarBehavior.floating,
                                      duration: const Duration(milliseconds: 1400),
                                      action: SnackBarAction(
                                        label: 'CLOSE',
                                        textColor: AppColors.champagneGold,
                                        onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(AppRadius.md),
                                      ),
                                    ),
                                  );
                                },
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ProductDetailView(
                                        product: product,
                                        heroTag: 'catalog_grid_${product.id}',
                                      ),
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

  Widget _buildEmptyState(HomeController home) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 56,
              color: AppColors.secondaryText,
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'No cosmetics found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.mainText,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Try searching with a different name or clear your filters.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.secondaryText),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: () {
                _searchController.clear();
                home.clearSearch();
                home.selectCategory('all');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.luxuryWine,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('View All Collections'),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterBottomSheet(BuildContext context, HomeController home) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Filter Collections',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.mainText,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: home.categories.map((c) {
                  final isSelected = home.selectedCategoryId == c.id;
                  return ChoiceChip(
                    label: Text(c.name),
                    selected: isSelected,
                    onSelected: (_) {
                      home.selectCategory(c.id);
                      Navigator.of(context).pop();
                    },
                    selectedColor: AppColors.luxuryWine,
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.white : AppColors.mainText,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        );
      },
    );
  }
}

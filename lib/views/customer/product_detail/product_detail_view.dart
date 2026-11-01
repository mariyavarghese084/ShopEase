import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../controllers/cart_controller.dart';
import '../../../controllers/home_controller.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/routes/app_routes.dart';
import '../../../models/product_model.dart';
import '../../../services/analytics_service.dart';

/// Detailed view for a luxury fragrance item.
///
/// Closely matches the AÈRA reference UI:
/// - Hero perfume showcase with ambient luxury glow
/// - Formula highlights (Key Actives, Nourishing Base, Finish & Wear)
/// - Size selector (50 ml, 100 ml)
/// - Quantity selector
/// - Sticky bottom bar with 'Shto në Shportë' (Add to Cart)
class ProductDetailView extends StatefulWidget {
  final ProductModel product;
  final String? heroTag;

  const ProductDetailView({
    super.key,
    required this.product,
    this.heroTag,
  });

  @override
  State<ProductDetailView> createState() => _ProductDetailViewState();
}

class _ProductDetailViewState extends State<ProductDetailView> {
  late String _selectedSize;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    _selectedSize = widget.product.availableSizes.isNotEmpty
        ? widget.product.availableSizes.first
        : widget.product.volume;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      AnalyticsService.logViewItem(
        itemId: widget.product.id,
        itemName: widget.product.name,
        itemCategory: widget.product.categoryName,
        price: widget.product.price,
      );
    });
  }

  void _incrementQuantity() {
    setState(() => _quantity++);
  }

  void _decrementQuantity() {
    if (_quantity > 1) {
      setState(() => _quantity--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final homeController = context.watch<HomeController>();
    final cartController = context.watch<CartController>();
    final isFav = homeController.isFavorite(product.id);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Navigation Bar ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back button
                  _buildCircleButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => Navigator.of(context).pop(),
                  ),

                  // Actions: Favorite + Share
                  Row(
                    children: [
                      _buildCircleButton(
                        icon: isFav
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        iconColor: isFav
                            ? AppColors.luxuryWine
                            : AppColors.mainText,
                        onTap: () => homeController.toggleFavorite(product.id),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _buildCircleButton(
                        icon: Icons.share_outlined,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Share "${product.name}" with friends!',
                              ),
                              backgroundColor: AppColors.luxuryWine,
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Scrollable Body ─────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Hero Image / Bottle presentation
                    Center(
                      child: Hero(
                        tag: widget.heroTag ?? 'product_img_${product.id}',
                        child: Container(
                          width: 220,
                          height: 250,
                          margin: const EdgeInsets.symmetric(
                            vertical: AppSpacing.md,
                          ),
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              colors: [
                                (product.secondaryColor ?? product.visualColor)
                                    .withAlpha(50),
                                AppColors.background,
                              ],
                              radius: 0.85,
                            ),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Decorative outer gold ring
                              Container(
                                width: 170,
                                height: 170,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.champagneGold.withAlpha(
                                      60,
                                    ),
                                    width: 1.5,
                                  ),
                                ),
                              ),

                              // Luxury perfume bottle visual card
                              if (product.imageUrl != null)
                                Container(
                                  width: 170,
                                  height: 210,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (product.secondaryColor ?? product.visualColor)
                                            .withAlpha(80),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(24),
                                    child: product.imageUrl!.startsWith('http://') ||
                                            product.imageUrl!.startsWith('https://')
                                        ? Image.network(
                                            product.imageUrl!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) =>
                                                _buildBottleFallback(product),
                                          )
                                        : Image.asset(
                                            product.imageUrl!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) =>
                                                _buildBottleFallback(product),
                                          ),
                                  ),
                                )
                              else
                                _buildBottleFallback(product),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // 2. Title, Subtitle, Price & Volume
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.name,
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.mainText,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                product.brand.isNotEmpty
                                    ? '${product.brand.toUpperCase()} • ${product.subtitle}'
                                    : product.subtitle,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.champagneGold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₹${product.price.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: AppColors.luxuryWine,
                              ),
                            ),
                            Text(
                              _selectedSize,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // 3. Description
                    Text(
                      product.description,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.secondaryText,
                        height: 1.6,
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // 4. Formula Highlights & Ingredients
                    const Text(
                      'Formula Highlights & Ingredients',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.mainText,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Row(
                        children: [
                          _buildNoteCard(
                            title: 'Key Actives',
                            value: product.topNote ?? 'Botanical Extract',
                            icon: Icons.local_florist_rounded,
                            iconColor: const Color(0xFFE898A8),
                          ),
                          _buildNoteDivider(),
                          _buildNoteCard(
                            title: 'Nourishing Base',
                            value: product.heartNote ?? 'Hyaluronic Acid',
                            icon: Icons.eco_rounded,
                            iconColor: const Color(0xFFC8A87D),
                          ),
                          _buildNoteDivider(),
                          _buildNoteCard(
                            title: 'Finish & Wear',
                            value: product.baseNote ?? 'Dewy Radiant Glow',
                            icon: Icons.auto_awesome,
                            iconColor: AppColors.luxuryWine,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // 5. Size Selection ("Madhësia")
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Size',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.mainText,
                          ),
                        ),
                        Row(
                          children: product.availableSizes.map((size) {
                            final isSelected = _selectedSize == size;
                            return Padding(
                              padding: const EdgeInsets.only(
                                left: AppSpacing.sm,
                              ),
                              child: ChoiceChip(
                                label: Text(size),
                                selected: isSelected,
                                onSelected: (val) {
                                  if (val) setState(() => _selectedSize = size);
                                },
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? AppColors.white
                                      : AppColors.mainText,
                                ),
                                selectedColor: AppColors.luxuryWine,
                                backgroundColor: AppColors.cardBackground,
                                side: BorderSide(
                                  color: isSelected
                                      ? AppColors.luxuryWine
                                      : AppColors.divider,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // 6. Quantity Stepper ("Sasia")
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Quantity',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.mainText,
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.cardBackground,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                iconSize: 18,
                                splashRadius: 18,
                                icon: const Icon(Icons.remove),
                                onPressed: _decrementQuantity,
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                ),
                                child: Text(
                                  '$_quantity',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.mainText,
                                  ),
                                ),
                              ),
                              IconButton(
                                iconSize: 18,
                                splashRadius: 18,
                                icon: const Icon(Icons.add),
                                onPressed: _incrementQuantity,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ),

            // ── Sticky Bottom Bar: Add to Cart Button ───────────────────────
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.mainText.withAlpha(12),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    // Quick cart button indicator
                    Material(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        onTap: () {
                          // Jump to cart
                          Navigator.of(context).pushNamed(AppRoutes.cart);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Badge(
                            backgroundColor: AppColors.luxuryWine,
                            label: Text('${cartController.itemCount}'),
                            isLabelVisible: cartController.itemCount > 0,
                            child: const Icon(
                              Icons.shopping_bag_outlined,
                              color: AppColors.mainText,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),

                    // Large "Shto në Shportë" button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          cartController.addItem(
                            product,
                            quantity: _quantity,
                            size: _selectedSize,
                          );

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
                                      'Added to bag: $_quantity x ${product.name} ($_selectedSize)',
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
                                label: 'VIEW BAG',
                                textColor: AppColors.champagneGold,
                                onPressed: () {
                                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                  Navigator.of(context).pushNamed(AppRoutes.cart);
                                },
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.shopping_bag_outlined, size: 20),
                        label: const Text(
                          'Add to Bag',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.luxuryWine,
                          foregroundColor: AppColors.white,
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 2,
                          shadowColor: AppColors.luxuryWine.withAlpha(80),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onTap,
    Color iconColor = AppColors.mainText,
  }) {
    return Material(
      color: AppColors.cardBackground,
      shape: const CircleBorder(),
      elevation: 1,
      shadowColor: AppColors.divider,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 18, color: iconColor),
        ),
      ),
    );
  }

  Widget _buildNoteCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.champagneGold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.mainText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteDivider() {
    return Container(
      width: 1,
      height: 36,
      color: AppColors.divider,
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _buildBottleFallback(ProductModel product) {
    return Container(
      width: 130,
      height: 180,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            product.visualColor.withAlpha(200),
            product.visualColor,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: product.visualColor.withAlpha(90),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Bottle Cap
          Positioned(
            top: 8,
            child: Container(
              width: 50,
              height: 18,
              decoration: BoxDecoration(
                color: AppColors.champagneGold,
                borderRadius: BorderRadius.circular(6),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),

          // Main Bottle Center Crest
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 14),
              Icon(
                product.visualIcon,
                size: 42,
                color: AppColors.white,
              ),
              const SizedBox(height: 8),
              Text(
                product.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.white,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                product.brand.isNotEmpty ? product.brand : 'Lattafa / AÈRA',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w400,
                  color: AppColors.white.withAlpha(180),
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

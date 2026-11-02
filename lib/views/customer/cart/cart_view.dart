import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../controllers/cart_controller.dart';
import '../../../controllers/home_controller.dart';
import '../../../core/constants/app_constants.dart';
import '../../../widgets/luxury_ui_components.dart';
import '../checkout/checkout_view.dart';

/// Shopping Bag view inspired by the AÈRA reference UI screen ('Shporta').
class CartView extends StatefulWidget {
  final bool showBackButton;

  const CartView({super.key, this.showBackButton = false});

  @override
  State<CartView> createState() => _CartViewState();
}

class _CartViewState extends State<CartView> {
  final TextEditingController _promoController = TextEditingController();

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final homeController = context.watch<HomeController>();
    return Consumer<CartController>(
      builder: (context, cart, _) {
        if (homeController.allProducts.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            cart.syncProductAvailability(homeController.allProducts);
          });
        }
        final items = cart.items;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.background,
            elevation: 0,
            leading: widget.showBackButton
                ? IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                : null,
            title: const Text(
              'Shopping Bag',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.mainText,
                letterSpacing: -0.3,
              ),
            ),
            actions: [
              if (items.isNotEmpty)
                TextButton(
                  onPressed: () {
                    _showClearConfirmationDialog(context, cart);
                  },
                  child: const Text(
                    'Clear',
                    style: TextStyle(
                      color: AppColors.secondaryText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          body: items.isEmpty
              ? _buildEmptyCart(context)
              : _buildCartBody(context, cart),
        );
      },
    );
  }

  Widget _buildEmptyCart(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.8, end: 1.0),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutBack,
              builder: (context, scale, child) => Transform.scale(
                scale: scale,
                child: child,
              ),
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.luxuryWine.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shopping_bag_outlined,
                  size: 56,
                  color: AppColors.luxuryWine,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'Your shopping bag is empty',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.mainText,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Discover our exclusive luxury Cosmetics collection and add your favorites.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.secondaryText,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton.icon(
              onPressed: () {
                final homeController = context.read<HomeController>();
                homeController.setBottomNavIndex(1); // Collections tab
              },
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text('Explore Collections'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.luxuryWine,
                foregroundColor: AppColors.white,
                minimumSize: const Size(220, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartBody(BuildContext context, CartController cart) {
    return Column(
      children: [
        // ── Cart Items List ─────────────────────────────────────────────────
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            physics: const BouncingScrollPhysics(),
            itemCount: cart.items.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final item = cart.items[index];
              final product = item.product;

              return StaggeredSlideFade(
                index: index,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.sm + 2),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.divider.withAlpha(160)),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.mainText.withAlpha(8),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Perfume visual container
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            product.visualColor.withAlpha(40),
                            product.visualColor.withAlpha(120),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: product.imageUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Builder(
                                builder: (context) {
                                  final imgUrl = product.imageUrl!
                                      .replaceAll(r'\', '/')
                                      .trim();
                                  if (imgUrl.startsWith('http://') ||
                                      imgUrl.startsWith('https://')) {
                                    return Image.network(
                                      imgUrl,
                                      width: 68,
                                      height: 68,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              Icon(
                                        product.visualIcon,
                                        color: AppColors.white,
                                        size: 32,
                                      ),
                                    );
                                  }
                                  return Image.asset(
                                    imgUrl,
                                    width: 68,
                                    height: 68,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            Icon(
                                      product.visualIcon,
                                      color: AppColors.white,
                                      size: 32,
                                    ),
                                  );
                                },
                              ),
                            )
                          : Icon(
                              product.visualIcon,
                              color: AppColors.white,
                              size: 32,
                            ),
                    ),
                    const SizedBox(width: AppSpacing.md),

                    // Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.mainText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.selectedSize,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.secondaryText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₹${product.price.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.luxuryWine,
                            ),
                          ),
                          if (!product.isInStock) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFC62828).withAlpha(20),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: const Color(0xFFC62828).withAlpha(60),
                                ),
                              ),
                              child: const Text(
                                'Out of stock',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFC62828),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Quantity Stepper + Trash button
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Row(
                            children: [
                              InkWell(
                                onTap: () {
                                  cart.updateQuantity(
                                    item.cartKey,
                                    item.quantity - 1,
                                  );
                                },
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  child: Icon(Icons.remove, size: 14),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  transitionBuilder: (child, animation) =>
                                      ScaleTransition(scale: animation, child: child),
                                  child: Text(
                                    '${item.quantity}',
                                    key: ValueKey<int>(item.quantity),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () {
                                  cart.updateQuantity(
                                    item.cartKey,
                                    item.quantity + 1,
                                  );
                                },
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  child: Icon(Icons.add, size: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        IconButton(
                          iconSize: 18,
                          splashRadius: 18,
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: AppColors.secondaryText,
                          ),
                          onPressed: () {
                            cart.removeItem(item.cartKey);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              );
            },
          ),
        ),

        // ── Promo Code + Summary + Checkout Footer ──────────────────────────
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Promo Code Section ("Promo Code")
                const Text(
                  'Promo Code',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mainText,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: TextField(
                          controller: _promoController,
                          textCapitalization: TextCapitalization.characters,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.1,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Enter code (e.g. AERA20)...',
                            hintStyle: TextStyle(
                              fontSize: 12,
                              color: AppColors.secondaryText,
                              letterSpacing: 0,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    ElevatedButton(
                      onPressed: () {
                        if (_promoController.text.trim().isEmpty) return;
                        final success = cart.applyPromoCode(
                          _promoController.text,
                        );
                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Promo code "${cart.appliedPromoCode}" applied! ${cart.discountPercentage}% off.',
                              ),
                              backgroundColor: AppColors.luxuryWine,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                cart.promoError ?? 'Invalid promo code',
                              ),
                              backgroundColor: AppColors.error,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.luxuryWine,
                        foregroundColor: AppColors.white,
                        minimumSize: const Size(80, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text('Apply'),
                    ),
                  ],
                ),

                if (cart.appliedPromoCode != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.luxuryWineLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_circle,
                              size: 12,
                              color: AppColors.luxuryWine,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${cart.appliedPromoCode} (-${cart.discountPercentage}%)',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.luxuryWine,
                              ),
                            ),
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () {
                                cart.removePromoCode();
                                _promoController.clear();
                              },
                              child: const Icon(
                                Icons.close,
                                size: 14,
                                color: AppColors.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: AppSpacing.md),
                const Divider(),
                const SizedBox(height: AppSpacing.xs),

                // Order Breakdown
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Subtotal',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    LuxuryAnimatedCounter(
                      value: cart.subtotal,
                      prefix: '₹',
                      decimalPlaces: 2,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.mainText,
                      ),
                    ),
                  ],
                ),
                if (cart.discountAmount > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Promo Discount',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.luxuryWine,
                        ),
                      ),
                      Text(
                        '-₹${cart.discountAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.luxuryWine,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 4),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Standard Delivery',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    Text(
                      'Free',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.mainText,
                      ),
                    ),
                    LuxuryAnimatedCounter(
                      value: cart.totalPrice,
                      prefix: '₹',
                      decimalPlaces: 2,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.luxuryWine,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.md),

                if (cart.hasOutOfStockItems) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC62828).withAlpha(15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFC62828).withAlpha(60),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: Color(0xFFC62828),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Some items in your bag are out of stock. Please remove them to proceed.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFFC62828),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Proceed to Checkout Button
                ElevatedButton.icon(
                  onPressed: cart.hasOutOfStockItems
                      ? null
                      : () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const CheckoutView(),
                            ),
                          );
                        },
                  icon: const Icon(Icons.lock_outline_rounded, size: 18),
                  label: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Proceed to Checkout',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.luxuryWine,
                    foregroundColor: AppColors.white,
                    disabledBackgroundColor: AppColors.divider.withAlpha(160),
                    disabledForegroundColor: AppColors.secondaryText,
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                    shadowColor: AppColors.luxuryWine.withAlpha(80),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showClearConfirmationDialog(BuildContext context, CartController cart) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Clear Shopping Bag?'),
        content: const Text(
          'Are you sure you want to remove all items from your bag?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              cart.clearCart();
              Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              minimumSize: const Size(90, 40),
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

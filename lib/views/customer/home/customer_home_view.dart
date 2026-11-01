import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../controllers/auth_controller.dart';
import '../../../controllers/cart_controller.dart';
import '../../../controllers/home_controller.dart';
import '../../../controllers/order_controller.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../services/analytics_service.dart';
import '../../../services/in_app_messaging_service.dart';
import '../../../widgets/widgets.dart';
import '../cart/cart_view.dart';
import '../catalog/catalog_view.dart';
import '../favorites/favorites_view.dart';
import '../product_detail/product_detail_view.dart';
import '../profile/profile_view.dart';

/// Customer shopping home screen for ShopEase (AÈRA Luxury Fragrances).
class CustomerHomeView extends StatefulWidget {
  const CustomerHomeView({super.key});

  @override
  State<CustomerHomeView> createState() => _CustomerHomeViewState();
}

class _CustomerHomeViewState extends State<CustomerHomeView> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AnalyticsService.logScreenView(screenName: 'CustomerHome');
      // Ensure in-app messages are active for customer viewing
      InAppMessagingService.setMessagesSuppressed(false);
      // Trigger evaluation for campaigns targeting 'on_foreground' or 'beauty_sale'
      InAppMessagingService.triggerBeautySaleCampaign();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<HomeController, CartController>(
      builder: (context, controller, cart, child) {
        final isMobile = ResponsiveUtils.isMobile(context);
        final cartCount = cart.itemCount;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Row(
              children: [
                // ── Desktop Navigation Rail (for wide screens) ───────────────
                if (!isMobile)
                  NavigationRail(
                    backgroundColor: AppColors.cardBackground,
                    selectedIndex: controller.bottomNavIndex,
                    onDestinationSelected: (index) {
                      controller.setBottomNavIndex(index);
                    },
                    labelType: NavigationRailLabelType.selected,
                    selectedIconTheme: const IconThemeData(
                      color: AppColors.luxuryWine,
                    ),
                    selectedLabelTextStyle: const TextStyle(
                      color: AppColors.luxuryWine,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    unselectedIconTheme: const IconThemeData(
                      color: AppColors.secondaryText,
                    ),
                    leading: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: AppColors.luxuryWine.withAlpha(20),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          color: AppColors.luxuryWine,
                          size: 26,
                        ),
                      ),
                    ),
                    destinations: [
                      const NavigationRailDestination(
                        icon: Icon(Icons.home_outlined),
                        selectedIcon: Icon(Icons.home_rounded),
                        label: Text('Home'),
                      ),
                      const NavigationRailDestination(
                        icon: Icon(Icons.grid_view_outlined),
                        selectedIcon: Icon(Icons.grid_view_rounded),
                        label: Text('Collections'),
                      ),
                      NavigationRailDestination(
                        icon: Badge(
                          label: Text('$cartCount'),
                          backgroundColor: AppColors.luxuryWine,
                          isLabelVisible: cartCount > 0,
                          child: const Icon(Icons.shopping_bag_outlined),
                        ),
                        selectedIcon: Badge(
                          label: Text('$cartCount'),
                          backgroundColor: AppColors.luxuryWine,
                          isLabelVisible: cartCount > 0,
                          child: const Icon(Icons.shopping_bag_rounded),
                        ),
                        label: const Text('Cart'),
                      ),
                      const NavigationRailDestination(
                        icon: Icon(Icons.favorite_outline_rounded),
                        selectedIcon: Icon(Icons.favorite_rounded),
                        label: Text('Favorites'),
                      ),
                      const NavigationRailDestination(
                        icon: Icon(Icons.person_outline_rounded),
                        selectedIcon: Icon(Icons.person_rounded),
                        label: Text('Profile'),
                      ),
                    ],
                    trailing: context.watch<AuthController>().isAdmin
                        ? Padding(
                            padding: const EdgeInsets.only(top: 24),
                            child: IconButton(
                              tooltip: 'Return to Admin Dashboard',
                              icon: const Icon(
                                Icons.admin_panel_settings_rounded,
                                color: AppColors.luxuryWine,
                                size: 24,
                              ),
                              onPressed: () => Navigator.of(
                                context,
                              ).pushReplacementNamed(AppRoutes.adminDashboard),
                            ),
                          )
                        : null,
                  ),

                // ── Main Content Area ───────────────────────────────────────
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: ResponsiveUtils.maxContentWidth,
                      ),
                      child: _buildCurrentTab(controller),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Mobile Bottom Navigation Bar (5 Luxury Tabs) ─────────────────
          bottomNavigationBar: isMobile
              ? Container(
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
                  child: BottomNavigationBar(
                    currentIndex: controller.bottomNavIndex,
                    onTap: (index) => controller.setBottomNavIndex(index),
                    backgroundColor: AppColors.cardBackground,
                    selectedItemColor: AppColors.luxuryWine,
                    unselectedItemColor: AppColors.secondaryText,
                    type: BottomNavigationBarType.fixed,
                    elevation: 0,
                    selectedFontSize: 11,
                    unselectedFontSize: 11,
                    items: [
                      const BottomNavigationBarItem(
                        icon: Icon(Icons.home_outlined),
                        activeIcon: Icon(Icons.home_rounded),
                        label: 'Home',
                      ),
                      const BottomNavigationBarItem(
                        icon: Icon(Icons.grid_view_outlined),
                        activeIcon: Icon(Icons.grid_view_rounded),
                        label: 'Collections',
                      ),
                      BottomNavigationBarItem(
                        icon: Badge(
                          label: Text('$cartCount'),
                          backgroundColor: AppColors.luxuryWine,
                          isLabelVisible: cartCount > 0,
                          child: const Icon(Icons.shopping_bag_outlined),
                        ),
                        activeIcon: Badge(
                          label: Text('$cartCount'),
                          backgroundColor: AppColors.luxuryWine,
                          isLabelVisible: cartCount > 0,
                          child: const Icon(Icons.shopping_bag_rounded),
                        ),
                        label: 'Cart',
                      ),
                      const BottomNavigationBarItem(
                        icon: Icon(Icons.favorite_border_rounded),
                        activeIcon: Icon(Icons.favorite_rounded),
                        label: 'Favorites',
                      ),
                      const BottomNavigationBarItem(
                        icon: Icon(Icons.person_outline_rounded),
                        activeIcon: Icon(Icons.person_rounded),
                        label: 'Profile',
                      ),
                    ],
                  ),
                )
              : null,
        );
      },
    );
  }

  /// Selects the view for the active navigation tab using IndexedStack.
  Widget _buildCurrentTab(HomeController controller) {
    return IndexedStack(
      index: controller.bottomNavIndex,
      children: [
        _buildHomeTab(controller),
        const CatalogView(showBackButton: false),
        const CartView(showBackButton: false),
        const FavoritesView(showBackButton: false),
        const ProfileView(),
      ],
    );
  }

  /// The primary shopping home view matching AÈRA luxury fragrance store.
  Widget _buildHomeTab(HomeController controller) {
    final cart = context.watch<CartController>();

    return RefreshIndicator(
      color: AppColors.luxuryWine,
      onRefresh: controller.refresh,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          // ── 1. Top Header with Luxury Logo & Cart Action ──────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.xs,
              ),
              child: _buildHeader(controller, cart),
            ),
          ),

          // ── Search Field (Displayed when search is active or filtered) ────
          if (controller.searchQuery.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                child: _buildSearchBar(controller),
              ),
            ),

          // ── 2. Promotional Hero Banner ("Luxury Fragrances") ──────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: _buildPromoBanner(controller),
            ),
          ),

          // ── 3. Quick Trust Feature Badges ─────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: _buildTrustBadges(),
            ),
          ),

          // ── Order History Quick Action Card ───────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                0,
              ),
              child: _buildOrderHistoryQuickCard(context),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),

          // ── 4. Koleksione (Categories) Section ────────────────────────────
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Collections',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.mainText,
                        ),
                      ),
                      TextButton(
                        onPressed: () => controller.setBottomNavIndex(1),
                        child: const Row(
                          children: [
                            Text(
                              'View all',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.luxuryWine,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 12,
                              color: AppColors.luxuryWine,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                _buildCategoriesList(controller),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),

          // ── 5. Best Sellers Header ───────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Best Sellers',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.mainText,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.luxuryWine.withAlpha(20),
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Text(
                          '${controller.displayedProducts.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.luxuryWine,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (controller.selectedCategoryId != 'all')
                    TextButton.icon(
                      icon: const Icon(Icons.clear_rounded, size: 16),
                      label: const Text('All'),
                      onPressed: () => controller.selectCategory('all'),
                    ),
                ],
              ),
            ),
          ),

          // ── 6. Responsive Best Sellers Grid ───────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.all(AppSpacing.md),
            sliver: _buildProductsGrid(controller, cart),
          ),

          // Bottom padding
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
        ],
      ),
    );
  }

  /// Top header with AÈRA branding and cart icon with live badge.
  Widget _buildHeader(HomeController controller, CartController cart) {
    final auth = context.watch<AuthController>();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Brand Title
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.luxuryWine,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: AppColors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Text(
              'AÈRA',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.mainText,
                letterSpacing: 3.0,
              ),
            ),
          ],
        ),

        // Search, Notifications & Cart icon + Admin return button (if admin)
        Row(
          children: [
            if (auth.isAdmin)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: InkWell(
                  onTap: () {
                    Navigator.of(
                      context,
                    ).pushReplacementNamed(AppRoutes.adminDashboard);
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.luxuryWine,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.luxuryWine.withAlpha(50),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.admin_panel_settings_rounded,
                          size: 14,
                          color: AppColors.champagneGold,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Admin',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.search_rounded, size: 22),
              tooltip: 'Search',
              onPressed: () {
                controller.setBottomNavIndex(
                  1,
                ); // Jump to Collections / Search tab
              },
            ),
            IconButton(
              icon: const Icon(Icons.receipt_long_rounded, size: 22),
              tooltip: 'Order History',
              onPressed: () {
                Navigator.of(context).pushNamed(AppRoutes.orderDetail);
              },
            ),
            const NotificationBellButton(size: 22),
          ],
        ),
      ],
    );
  }

  /// Elegant luxury search field matching the ShopEase aesthetic.
  Widget _buildSearchBar(HomeController controller) {
    if (_searchController.text != controller.searchQuery &&
        !_searchController.value.isComposingRangeValid) {
      _searchController.value = TextEditingValue(
        text: controller.searchQuery,
        selection: TextSelection.collapsed(
          offset: controller.searchQuery.length,
        ),
      );
    }

    return Container(
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
        onChanged: (val) => controller.setSearchQuery(val),
        style: const TextStyle(fontSize: 14, color: AppColors.mainText),
        decoration: InputDecoration(
          hintText: 'Search Cosmetics, brands, collections...',
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
                    controller.clearSearch();
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
    );
  }

  /// Promotional Hero Banner matching the top-left screen in the reference UI.
  Widget _buildPromoBanner(HomeController controller) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEBD4D7), Color(0xFFFBF4F2)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.luxuryWine.withAlpha(25),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background ambient circular glow
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.softRose.withAlpha(50),
              ),
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Luxury Cosmetics',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.mainText,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Reveal Your Natural\nBeauty',
                        style: TextStyle(
                          fontSize: 18,
                          fontStyle: FontStyle.italic,
                          color: AppColors.luxuryWine,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'BEAUTY IN EVERY DETAIL',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppColors.champagneGold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      ElevatedButton(
                        onPressed: () {
                          // Open top perfume product detail (Yara Rose)
                          if (controller.displayedProducts.isNotEmpty) {
                            final topProduct =
                                controller.displayedProducts.first;
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ProductDetailView(
                                  product: topProduct,
                                  heroTag: 'home_banner_${topProduct.id}',
                                ),
                              ),
                            );
                          } else {
                            controller.setBottomNavIndex(1);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.luxuryWine,
                          foregroundColor: AppColors.white,
                          minimumSize: const Size(125, 40),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                          shadowColor: AppColors.luxuryWine.withAlpha(80),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'ORDER NOW',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_forward_rounded, size: 14),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Right perfume hero illustration
                Expanded(
                  flex: 4,
                  child: Center(
                    child: Container(
                      width: 88,
                      height: 120,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFFE898A8), Color(0xFF8A4652)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.luxuryWine.withAlpha(60),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(
                          'Assest/The Viral Blush Beauty Lovers Are Obsessed With.jpeg',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _buildPromoBottleFallback(),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromoBottleFallback() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 32,
          height: 12,
          decoration: BoxDecoration(
            color: AppColors.champagneGold,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 8),
        const Icon(Icons.auto_awesome, color: AppColors.white, size: 28),
        const SizedBox(height: 4),
        const Text(
          'AÈRA',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: AppColors.white,
            letterSpacing: 1.5,
          ),
        ),
        Text(
          'Cosmetics',
          style: TextStyle(fontSize: 7, color: AppColors.white.withAlpha(180)),
        ),
      ],
    );
  }

  /// 3 Trust feature badges: 100% Authentic, Free Express Shipping, Premium Packaging.
  Widget _buildTrustBadges() {
    return Row(
      children: [
        _buildBadgeItem(icon: Icons.diamond_outlined, title: '100% Authentic'),
        const SizedBox(width: AppSpacing.sm),
        _buildBadgeItem(
          icon: Icons.local_shipping_outlined,
          title: 'Free Express Shipping',
        ),
        const SizedBox(width: AppSpacing.sm),
        _buildBadgeItem(
          icon: Icons.card_giftcard_outlined,
          title: 'Premium Packaging',
        ),
      ],
    );
  }

  Widget _buildBadgeItem({required IconData icon, required String title}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider.withAlpha(150)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: AppColors.luxuryWine),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.mainText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Quick-access luxury card on the home page to inspect order history & tracking.
  Widget _buildOrderHistoryQuickCard(BuildContext context) {
    return Consumer<OrderController>(
      builder: (context, orderController, _) {
        final orderCount = orderController.orders.length;

        return Material(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          elevation: 1,
          shadowColor: AppColors.divider,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.of(context).pushNamed(AppRoutes.orderDetail);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.luxuryWine.withAlpha(45),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.luxuryWine.withAlpha(25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: AppColors.luxuryWine,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            const Text(
                              'Order History & Tracking',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.mainText,
                              ),
                            ),
                            if (orderCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.luxuryWine,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$orderCount',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          orderController.hasOrders
                              ? 'Tap to view live tracking & previous receipts'
                              : 'No orders yet. Place an order to track live delivery.',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.secondaryText,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 13,
                    color: AppColors.luxuryWine,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Horizontally scrollable category list.
  Widget _buildCategoriesList(HomeController controller) {
    if (controller.categories.isEmpty) {
      return const SizedBox(
        height: 48,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.luxuryWine,
          ),
        ),
      );
    }

    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        scrollDirection: Axis.horizontal,
        itemCount: controller.categories.length,
        separatorBuilder: (context, index) =>
            const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final cat = controller.categories[index];
          final isSelected = controller.selectedCategoryId == cat.id;

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
            showCheckmark: false,
            side: BorderSide(
              color: isSelected ? AppColors.luxuryWine : AppColors.divider,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            onSelected: (_) => controller.selectCategory(cat.id),
          );
        },
      ),
    );
  }

  /// Responsive product grid.
  Widget _buildProductsGrid(HomeController controller, CartController cart) {
    if (controller.isLoading) {
      return const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.xxl),
            child: CircularProgressIndicator(color: AppColors.luxuryWine),
          ),
        ),
      );
    }

    if (controller.displayedProducts.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          alignment: Alignment.center,
          child: Column(
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
                  fontSize: 16,
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
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(
                onPressed: () {
                  _searchController.clear();
                  controller.clearSearch();
                  controller.selectCategory('all');
                },
                child: const Text('Show All Collections'),
              ),
            ],
          ),
        ),
      );
    }

    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.crossAxisExtent;
        final int crossAxisCount = width < 600 ? 2 : (width < 960 ? 3 : 4);

        return SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
            childAspectRatio: 0.65,
          ),
          delegate: SliverChildBuilderDelegate((context, index) {
            final product = controller.displayedProducts[index];

            return StaggeredSlideFade(
              index: index,
              child: ProductCard(
                product: product,
                heroTag: 'home_grid_${product.id}',
                isFavorite: controller.isFavorite(product.id),
                onFavoriteToggle: () => controller.toggleFavorite(product.id),
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
                      onPressed: () =>
                          ScaffoldMessenger.of(context).hideCurrentSnackBar(),
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
                      heroTag: 'home_grid_${product.id}',
                    ),
                  ),
                );
              },
            ),
          );
          }, childCount: controller.displayedProducts.length),
        );
      },
    );
  }
}

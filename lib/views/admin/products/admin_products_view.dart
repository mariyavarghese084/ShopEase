import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../controllers/admin_product_controller.dart';
import '../../../controllers/home_controller.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/routes/app_routes.dart';
import '../../../models/product_model.dart';
import '../admin_scaffold.dart';
import 'product_form_dialog.dart';

class AdminProductsView extends StatefulWidget {
  const AdminProductsView({super.key});

  @override
  State<AdminProductsView> createState() => _AdminProductsViewState();
}

class _AdminProductsViewState extends State<AdminProductsView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AdminProductController>();

    return AdminScaffold(
      title: 'Product Management',
      currentRoute: AppRoutes.adminProducts,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;

          return RefreshIndicator(
            onRefresh: () async {
              await controller.loadProducts();
            },
            color: AppColors.luxuryWine,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 1. Top Bar: Title & Primary Action ────────────────────
                  _buildHeaderActions(context, isWide),
                  const SizedBox(height: AppSpacing.md),

                  // ── 2. Inventory KPI Summary Metrics ──────────────────────
                  _buildMetricsRow(controller, isWide),
                  const SizedBox(height: AppSpacing.lg),

                  // ── 3. Filters & Real-time Search ─────────────────────────
                  _buildFilterBar(controller, isWide),
                  const SizedBox(height: AppSpacing.md),

                  // ── 4. Main Products Content (Table / Cards) ──────────────
                  if (controller.isLoading && controller.products.isEmpty)
                    _buildLoadingState()
                  else if (controller.errorMessage != null &&
                      controller.products.isEmpty)
                    _buildErrorState(controller)
                  else if (controller.filteredProducts.isEmpty)
                    _buildEmptyState(controller)
                  else
                    isWide
                        ? _buildProductDataTable(context, controller)
                        : _buildProductCardsGrid(context, controller),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── 1. Header Actions ──────────────────────────────────────────────────────
  Widget _buildHeaderActions(BuildContext context, bool isWide) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 12,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 260),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Product Catalog & Inventory',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.mainText,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Manage beauty merchandise specifications, pricing, stock levels, and store visibility.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.secondaryText.withAlpha(220),
                ),
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: ElevatedButton.icon(
              onPressed: () => _openAddProductDialog(context),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: Text(isWide ? 'Add Product' : 'Add'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.luxuryWine,
                foregroundColor: AppColors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? 20 : 14,
                  vertical: 14,
                ),
                minimumSize: const Size(0, 0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── 2. Inventory Metrics Banner ────────────────────────────────────────────
  Widget _buildMetricsRow(AdminProductController controller, bool isWide) {
    final cards = [
      _buildMetricCard(
        title: 'Total Items',
        value: '${controller.totalProductCount}',
        icon: Icons.inventory_2_outlined,
        color: AppColors.luxuryWine,
      ),
      _buildMetricCard(
        title: 'In Stock',
        value: '${controller.inStockCount}',
        icon: Icons.check_circle_outline_rounded,
        color: const Color(0xFF2E7D32),
      ),
      _buildMetricCard(
        title: 'Low Stock (≤5)',
        value: '${controller.lowStockCount}',
        icon: Icons.warning_amber_rounded,
        color: const Color(0xFFE65100),
      ),
      _buildMetricCard(
        title: 'Out of Stock',
        value: '${controller.outOfStockCount}',
        icon: Icons.cancel_outlined,
        color: AppColors.error,
      ),
    ];

    if (isWide) {
      return Row(
        children: cards
            .map(
              (c) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: c,
                ),
              ),
            )
            .toList(),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: cards
            .map(
              (c) => SizedBox(
                width: 170,
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: c,
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: AppColors.mainText.withAlpha(8),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.mainText,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondaryText,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 3. Filters & Real-time Search ──────────────────────────────────────────
  Widget _buildFilterBar(AdminProductController controller, bool isWide) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Search field
              Expanded(
                flex: 4,
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => controller.setSearchQuery(val),
                  decoration: InputDecoration(
                    hintText:
                        'Search products by name, brand, or description...',
                    hintStyle: const TextStyle(
                      fontSize: 13,
                      color: AppColors.secondaryText,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: AppColors.champagneGold,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              controller.setSearchQuery('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.luxuryWine,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Category dropdown
              if (isWide) ...[
                Expanded(
                  flex: 3,
                  child: _buildCategoryFilterDropdown(controller),
                ),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: _buildStockFilterDropdown(controller)),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Reload Catalog',
                  onPressed: () => controller.loadProducts(),
                  icon: const Icon(Icons.refresh_rounded),
                  color: AppColors.luxuryWine,
                ),
              ],
            ],
          ),

          // Responsive secondary row for smaller screens
          if (!isWide) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildCategoryFilterDropdown(controller)),
                const SizedBox(width: 8),
                Expanded(child: _buildStockFilterDropdown(controller)),
                IconButton(
                  tooltip: 'Reload',
                  onPressed: () => controller.loadProducts(),
                  icon: const Icon(Icons.refresh_rounded),
                  color: AppColors.luxuryWine,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryFilterDropdown(AdminProductController controller) {
    final categories = controller.categories;

    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: controller.selectedCategoryId,
      decoration: InputDecoration(
        labelText: 'Category Filter',
        labelStyle: const TextStyle(
          fontSize: 12,
          color: AppColors.secondaryText,
        ),
        filled: true,
        fillColor: AppColors.background,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
      ),
      items: [
        const DropdownMenuItem(value: 'all', child: Text('All Categories')),
        ...categories
            .where((c) => c.id != 'all')
            .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
      ],
      onChanged: (val) {
        if (val != null) controller.selectCategory(val);
      },
    );
  }

  Widget _buildStockFilterDropdown(AdminProductController controller) {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: controller.stockFilter,
      decoration: InputDecoration(
        labelText: 'Availability',
        labelStyle: const TextStyle(
          fontSize: 12,
          color: AppColors.secondaryText,
        ),
        filled: true,
        fillColor: AppColors.background,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
      ),
      items: const [
        DropdownMenuItem(value: 'all', child: Text('All Stock')),
        DropdownMenuItem(value: 'in_stock', child: Text('In Stock')),
        DropdownMenuItem(value: 'low_stock', child: Text('Low Stock (≤5)')),
        DropdownMenuItem(value: 'out_of_stock', child: Text('Out of Stock')),
        DropdownMenuItem(value: 'inactive', child: Text('Archived / Inactive')),
      ],
      onChanged: (val) {
        if (val != null) controller.setStockFilter(val);
      },
    );
  }

  // ── 4. Wide Web Data Table View ────────────────────────────────────────────
  Widget _buildProductDataTable(
    BuildContext context,
    AdminProductController controller,
  ) {
    final products = controller.filteredProducts;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 860),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(
                AppColors.luxuryWine.withAlpha(12),
              ),
              dataRowMinHeight: 68,
              dataRowMaxHeight: 76,
              columnSpacing: 24,
              horizontalMargin: 20,
              columns: const [
                DataColumn(
                  label: Text(
                    'Product Details',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Category',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Price',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Stock Level',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Active Status',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Actions',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
              ],
              rows: products.map((product) {
                return DataRow(
                  cells: [
                    // Product Details (Image + Name + Brand)
                    DataCell(
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.divider),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: _buildThumbnailImage(product.imageUrl),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                product.name,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.mainText,
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    product.brand,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.champagneGold,
                                    ),
                                  ),
                                  if (product.tag != null) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.luxuryWine.withAlpha(
                                          20,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        product.tag!,
                                        style: const TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.luxuryWine,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Category
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Text(
                          product.categoryName,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.mainText,
                          ),
                        ),
                      ),
                    ),

                    // Price
                    DataCell(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '₹${product.price.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.mainText,
                            ),
                          ),
                          if (product.hasDiscount)
                            Text(
                              '₹${product.originalPrice!.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 11,
                                decoration: TextDecoration.lineThrough,
                                color: AppColors.secondaryText,
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Stock Quantity
                    DataCell(
                      InkWell(
                        onTap: () =>
                            _openStockAdjustmentDialog(context, product),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: product.stockQuantity <= 0
                                      ? AppColors.error.withAlpha(20)
                                      : product.stockQuantity <= 5
                                      ? const Color(0xFFE65100).withAlpha(20)
                                      : const Color(0xFF2E7D32).withAlpha(20),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${product.stockQuantity} units',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: product.stockQuantity <= 0
                                        ? AppColors.error
                                        : product.stockQuantity <= 5
                                        ? const Color(0xFFE65100)
                                        : const Color(0xFF2E7D32),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.edit_outlined,
                                size: 14,
                                color: AppColors.secondaryText,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Active Switch
                    DataCell(
                      Switch(
                        value: product.isAvailable,
                        activeThumbColor: AppColors.luxuryWine,
                        onChanged: (val) {
                          controller.toggleAvailability(product);
                        },
                      ),
                    ),

                    // Action Buttons
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Edit Product',
                            icon: const Icon(
                              Icons.edit_note_rounded,
                              color: AppColors.luxuryWine,
                              size: 22,
                            ),
                            onPressed: () =>
                                _openEditProductDialog(context, product),
                          ),
                          IconButton(
                            tooltip: 'Delete / Archive',
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: AppColors.error,
                              size: 20,
                            ),
                            onPressed: () =>
                                _openDeleteConfirmationDialog(context, product),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  // ── 5. Compact Card Grid View ──────────────────────────────────────────────
  Widget _buildProductCardsGrid(
    BuildContext context,
    AdminProductController controller,
  ) {
    final products = controller.filteredProducts;

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: products.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final product = products[index];

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _buildThumbnailImage(product.imageUrl),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.mainText,
                      ),
                    ),
                    Text(
                      '${product.brand} • ${product.categoryName}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '₹${product.price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.mainText,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: product.stockQuantity <= 0
                                ? AppColors.error.withAlpha(20)
                                : const Color(0xFF2E7D32).withAlpha(20),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Stock: ${product.stockQuantity}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: product.stockQuantity <= 0
                                  ? AppColors.error
                                  : const Color(0xFF2E7D32),
                            ),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              product.isAvailable ? 'Active' : 'Hidden',
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.secondaryText,
                              ),
                            ),
                            Transform.scale(
                              scale: 0.8,
                              child: Switch(
                                value: product.isAvailable,
                                activeThumbColor: AppColors.luxuryWine,
                                onChanged: (val) {
                                  controller.toggleAvailability(product);
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      alignment: WrapAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () =>
                              _openStockAdjustmentDialog(context, product),
                          icon: const Icon(
                            Icons.inventory_2_outlined,
                            size: 13,
                          ),
                          label: const Text(
                            'Stock',
                            style: TextStyle(fontSize: 11),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            minimumSize: const Size(0, 30),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () =>
                              _openEditProductDialog(context, product),
                          icon: const Icon(Icons.edit_outlined, size: 13),
                          label: const Text(
                            'Edit',
                            style: TextStyle(fontSize: 11),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.luxuryWine,
                            side: const BorderSide(color: AppColors.luxuryWine),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            minimumSize: const Size(0, 30),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () =>
                              _openDeleteConfirmationDialog(context, product),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 13,
                          ),
                          label: const Text(
                            'Delete',
                            style: TextStyle(fontSize: 11),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            minimumSize: const Size(0, 30),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThumbnailImage(String? url) {
    if (url == null || url.trim().isEmpty) {
      return const Center(
        child: Icon(Icons.spa_outlined, color: AppColors.secondaryText),
      );
    }

    if (url.startsWith('http://') || url.startsWith('https://')) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Icon(
            Icons.broken_image_outlined,
            color: AppColors.secondaryText,
          ),
        ),
      );
    }

    return Image.asset(
      url,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => const Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: AppColors.secondaryText,
        ),
      ),
    );
  }

  // ── States ─────────────────────────────────────────────────────────────────
  Widget _buildLoadingState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(48.0),
        child: Column(
          children: [
            CircularProgressIndicator(color: AppColors.luxuryWine),
            SizedBox(height: 16),
            Text(
              'Synchronizing luxury catalog with Cloud Firestore...',
              style: TextStyle(color: AppColors.secondaryText, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(AdminProductController controller) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        constraints: const BoxConstraints(maxWidth: 480),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 48,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            const Text(
              'Unable to Load Products',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.mainText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              controller.errorMessage ?? 'An unexpected error occurred.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.secondaryText,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => controller.loadProducts(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry Loading'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.luxuryWine,
                foregroundColor: AppColors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(AdminProductController controller) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(40),
        constraints: const BoxConstraints(maxWidth: 460),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 48,
              color: AppColors.secondaryText,
            ),
            const SizedBox(height: 16),
            const Text(
              'No Products Found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.mainText,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'No catalog items match your search or category filter. Try clearing filters or adding a new luxury merchandise item.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.secondaryText),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () {
                    _searchController.clear();
                    controller.setSearchQuery('');
                    controller.selectCategory('all');
                    controller.setStockFilter('all');
                  },
                  child: const Text('Reset Filters'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => _openAddProductDialog(context),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Product'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.luxuryWine,
                    foregroundColor: AppColors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Dialog Triggers ────────────────────────────────────────────────────────
  Future<void> _openAddProductDialog(BuildContext context) async {
    final homeController = context.read<HomeController>();
    final result = await ProductFormDialog.show(context);
    if (result == true && mounted) {
      homeController.loadHomeData();
    }
  }

  Future<void> _openEditProductDialog(
    BuildContext context,
    ProductModel product,
  ) async {
    final homeController = context.read<HomeController>();
    final result = await ProductFormDialog.show(context, product: product);
    if (result == true && mounted) {
      homeController.loadHomeData();
    }
  }

  Future<void> _openStockAdjustmentDialog(
    BuildContext context,
    ProductModel product,
  ) async {
    final stockController = TextEditingController(
      text: product.stockQuantity.toString(),
    );

    await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        scrollable: true,
        actionsOverflowButtonSpacing: 8,
        title: Text(
          'Adjust Inventory Stock for ${product.name}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the available units in physical warehouse inventory:',
              style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: stockController,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Stock Units',
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newStock = int.tryParse(stockController.text.trim());
              if (newStock == null || newStock < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid stock quantity (≥ 0).'),
                    backgroundColor: AppColors.error,
                  ),
                );
                return;
              }
              Navigator.of(dialogCtx).pop(true);
              final controller = context.read<AdminProductController>();
              await controller.updateStockQuantity(product, newStock);
              if (context.mounted) {
                context.read<HomeController>().loadHomeData();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.luxuryWine,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Update Stock'),
          ),
        ],
      ),
    );
  }

  Future<void> _openDeleteConfirmationDialog(
    BuildContext context,
    ProductModel product,
  ) async {
    final controller = context.read<AdminProductController>();
    final homeController = context.read<HomeController>();

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        scrollable: true,
        actionsOverflowButtonSpacing: 8,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_forever_rounded,
                color: AppColors.error,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Delete Product',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to remove "${product.name}" from the active merchandise catalog?',
              style: const TextStyle(fontSize: 14, color: AppColors.mainText),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: AppColors.champagneGold,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Historical placed orders and customer order receipts will NOT be altered.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              // Safe archive: set isAvailable to false
              final updated = product.copyWith(isAvailable: false);
              await controller.saveProduct(updated, isEditing: true);
              homeController.loadHomeData();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Product "${product.name}" safely archived.'),
                    backgroundColor: AppColors.champagneGold,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.luxuryWine,
              side: const BorderSide(color: AppColors.luxuryWine),
            ),
            child: const Text('Deactivate / Archive'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              final success = await controller.deleteProduct(product.id);
              if (success) {
                homeController.loadHomeData();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Product "${product.name}" permanently deleted.',
                      ),
                      backgroundColor: AppColors.success,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } else if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      controller.errorMessage ?? 'Failed to delete product.',
                    ),
                    backgroundColor: AppColors.error,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }
}

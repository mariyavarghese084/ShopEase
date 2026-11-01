import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../controllers/admin_order_controller.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/routes/app_routes.dart';
import '../../../models/order_model.dart';
import '../admin_scaffold.dart';
import 'order_details_dialog.dart';
import '../../../widgets/luxury_ui_components.dart';

/// Working Stage 3 Admin Orders Management & Fulfillment Center.
///
/// Features cross-customer Firestore-backed order listings, metrics KPIs,
/// search, multi-attribute filtering, responsive desktop data table / mobile cards,
/// and authorized fulfillment progression dialogs.
class AdminOrdersView extends StatefulWidget {
  const AdminOrdersView({super.key});

  @override
  State<AdminOrdersView> createState() => _AdminOrdersViewState();
}

class _AdminOrdersViewState extends State<AdminOrdersView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Orders Management',
      currentRoute: AppRoutes.adminOrders,
      body: Consumer<AdminOrderController>(
        builder: (context, controller, _) {
          return RefreshIndicator(
            color: AppColors.luxuryWine,
            onRefresh: () => controller.loadOrders(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 1. Top Header & KPI Summary ───────────────────────────
                  _buildHeader(context, controller),
                  const SizedBox(height: AppSpacing.lg),
                  _buildKpiMetricsRow(controller),
                  const SizedBox(height: AppSpacing.lg),

                  // ── 2. Search & Filtering Bar ─────────────────────────────
                  _buildSearchAndFilterBar(context, controller),
                  const SizedBox(height: AppSpacing.md),

                  // ── 3. Orders Content (Desktop Table vs Mobile Cards) ─────
                  if (controller.isLoading && controller.allOrders.isEmpty)
                    _buildLoadingState()
                  else if (controller.errorMessage != null &&
                      controller.allOrders.isEmpty)
                    _buildErrorState(controller)
                  else if (controller.filteredOrders.isEmpty)
                    _buildEmptyState(controller)
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isDesktop = constraints.maxWidth >= 900;
                        if (isDesktop) {
                          return _buildDesktopDataTable(context, controller);
                        }
                        return _buildMobileOrderList(context, controller);
                      },
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AdminOrderController controller) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final titleColumn = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Orders & Fulfillment Center',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.mainText,
                    letterSpacing: -0.5,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.luxuryWine.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${controller.allOrders.length} Total Orders',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.luxuryWine,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Inspect cross-customer orders, review immutable price snapshots, and advance fulfillment statuses.',
              style: TextStyle(fontSize: 13, color: AppColors.secondaryText),
            ),
          ],
        );

        final refreshBtn = Align(
          alignment: Alignment.center,
          child: LuxuryActionButton.refresh(
            onPressed: controller.isLoading
                ? null
                : () => controller.loadOrders(),
            isLoading: controller.isLoading,
            label: 'Refresh Orders',
          ),
        );

        return Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 12,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: constraints.maxWidth >= 600
                    ? constraints.maxWidth - 200
                    : constraints.maxWidth,
              ),
              child: titleColumn,
            ),
            refreshBtn,
          ],
        );
      },
    );
  }

  Widget _buildKpiMetricsRow(AdminOrderController controller) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth >= 1000
            ? 4
            : (constraints.maxWidth >= 550 ? 2 : 1);
        final cardWidth =
            ((constraints.maxWidth - ((crossCount - 1) * AppSpacing.md)) /
                    crossCount)
                .floorToDouble() -
            1;

        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            SizedBox(
              width: cardWidth,
              child: _buildMetricCard(
                title: 'Total Orders',
                value: '${controller.totalOrdersCount}',
                subtitle: 'Cross-customer volume',
                icon: Icons.receipt_long_rounded,
                accentColor: AppColors.luxuryWine,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildMetricCard(
                title: 'Total Revenue',
                value: '₹${controller.totalRevenue.toStringAsFixed(0)}',
                subtitle: 'Excludes cancelled orders',
                icon: Icons.payments_outlined,
                accentColor: const Color(0xFF2E7D32),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildMetricCard(
                title: 'Pending Fulfillment',
                value: '${controller.pendingFulfillmentCount}',
                subtitle: 'Placed & processing parcels',
                icon: Icons.inventory_2_outlined,
                accentColor: AppColors.champagneGold,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildMetricCard(
                title: 'Fulfilled & Delivered',
                value: '${controller.deliveredCount}',
                subtitle: '${controller.inTransitCount} currently in transit',
                icon: Icons.check_circle_outline_rounded,
                accentColor: Colors.blue.shade700,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
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
              color: accentColor.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accentColor, size: 24),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.mainText,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.secondaryText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterBar(
    BuildContext context,
    AdminOrderController controller,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          // Row 1: Search TextField
          TextField(
            controller: _searchController,
            onChanged: (val) => controller.setSearchQuery(val),
            decoration: InputDecoration(
              hintText:
                  'Search orders by ID, customer name, phone, city, or tracking code...',
              hintStyle: const TextStyle(
                fontSize: 13,
                color: AppColors.secondaryText,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppColors.champagneGold,
                size: 20,
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
          const SizedBox(height: AppSpacing.sm),

          // Row 2: Status, Payment, Date & Sort Dropdowns
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Fulfillment Status Filter
              SizedBox(
                width: 170,
                child: DropdownButtonFormField<OrderProgressStatus?>(
                  isExpanded: true,
                  initialValue: controller.statusFilter,
                  decoration: _buildDropdownDecoration('Status'),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text(
                        'All Statuses',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    ...OrderProgressStatus.values.map((s) {
                      return DropdownMenuItem(
                        value: s,
                        child: Text(
                          s.label,
                          style: const TextStyle(fontSize: 12),
                        ),
                      );
                    }),
                  ],
                  onChanged: (s) => controller.setStatusFilter(s),
                ),
              ),

              // Payment Status Filter
              SizedBox(
                width: 150,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: controller.paymentStatusFilter,
                  decoration: _buildDropdownDecoration('Payment'),
                  items: const [
                    DropdownMenuItem(
                      value: 'All',
                      child: Text(
                        'All Payments',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'Paid',
                      child: Text('Paid', style: TextStyle(fontSize: 12)),
                    ),
                    DropdownMenuItem(
                      value: 'Pending',
                      child: Text('Pending', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                  onChanged: (p) =>
                      controller.setPaymentStatusFilter(p ?? 'All'),
                ),
              ),

              // Date Range Filter
              SizedBox(
                width: 150,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: controller.dateFilter,
                  decoration: _buildDropdownDecoration('Date'),
                  items: const [
                    DropdownMenuItem(
                      value: 'All',
                      child: Text('All Dates', style: TextStyle(fontSize: 12)),
                    ),
                    DropdownMenuItem(
                      value: 'Today',
                      child: Text('Today', style: TextStyle(fontSize: 12)),
                    ),
                    DropdownMenuItem(
                      value: 'Last 7 Days',
                      child: Text(
                        'Last 7 Days',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'Last 30 Days',
                      child: Text(
                        'Last 30 Days',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                  onChanged: (d) => controller.setDateFilter(d ?? 'All'),
                ),
              ),

              // Sort dropdown
              SizedBox(
                width: 160,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: controller.sortBy,
                  decoration: _buildDropdownDecoration('Sort'),
                  items: const [
                    DropdownMenuItem(
                      value: 'newest',
                      child: Text(
                        'Newest First',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'oldest',
                      child: Text(
                        'Oldest First',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'highest_amount',
                      child: Text('Highest ₹', style: TextStyle(fontSize: 12)),
                    ),
                    DropdownMenuItem(
                      value: 'lowest_amount',
                      child: Text('Lowest ₹', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                  onChanged: (s) => controller.setSortBy(s ?? 'newest'),
                ),
              ),

              // Reset filters button
              TextButton.icon(
                onPressed: () {
                  _searchController.clear();
                  controller.clearFilters();
                },
                icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
                label: const Text('Reset', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.secondaryText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _buildDropdownDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      filled: true,
      fillColor: AppColors.background,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
    );
  }

  // ── Desktop Table ──────────────────────────────────────────────────────────
  Widget _buildDesktopDataTable(
    BuildContext context,
    AdminOrderController controller,
  ) {
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
            constraints: const BoxConstraints(minWidth: 880),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppColors.background),
              dataRowMinHeight: 64,
              dataRowMaxHeight: 74,
              horizontalMargin: 20,
              columnSpacing: 24,
              columns: const [
                DataColumn(
                  label: Text(
                    'ORDER ID & DATE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'CUSTOMER',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'ITEMS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'TOTAL',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'PAYMENT',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'STATUS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'ACTIONS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
              rows: controller.filteredOrders.map((order) {
                return DataRow(
                  cells: [
                    // Order ID & Date
                    DataCell(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            order.id,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: AppColors.mainText,
                            ),
                          ),
                          Text(
                            _formatDate(order.createdAt),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Customer Name & Location
                    DataCell(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            order.shippingName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppColors.mainText,
                            ),
                          ),
                          Text(
                            '${order.shippingCity} • ${order.shippingPhone}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Items summary
                    DataCell(
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${order.totalItemCount} items',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            order.items.isNotEmpty
                                ? order.items.first.productName
                                : '',
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

                    // Total Amount
                    DataCell(
                      Text(
                        '₹${order.total.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: AppColors.luxuryWine,
                        ),
                      ),
                    ),

                    // Payment status chip
                    DataCell(_buildPaymentChip(order.paymentStatus)),

                    // Fulfillment status badge
                    DataCell(_buildFulfillmentBadge(order.status)),

                    // Actions
                    DataCell(
                      Align(
                        alignment: Alignment.center,
                        child: LuxuryActionButton.inspect(
                          onPressed: () =>
                              OrderDetailsDialog.show(context, order),
                        ),
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

  // ── Mobile Cards List ──────────────────────────────────────────────────────
  Widget _buildMobileOrderList(
    BuildContext context,
    AdminOrderController controller,
  ) {
    return Column(
      children: controller.filteredOrders.map((order) {
        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(6),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      order.id,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.mainText,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildFulfillmentBadge(order.status),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Placed ${_formatDate(order.createdAt)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.secondaryText,
                ),
              ),
              const Divider(height: 16, color: AppColors.divider),
              Row(
                children: [
                  const Icon(
                    Icons.person_outline,
                    size: 14,
                    color: AppColors.secondaryText,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      order.shippingName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildPaymentChip(order.paymentStatus),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${order.shippingCity} • ${order.shippingPhone}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.secondaryText,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${order.totalItemCount} item(s) purchased',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryText,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '₹${order.total.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.luxuryWine,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: LuxuryActionButton.inspect(
                  label: 'View Order Details & Fulfillment',
                  onPressed: () => OrderDetailsDialog.show(context, order),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── Badges & Chips ─────────────────────────────────────────────────────────
  Widget _buildFulfillmentBadge(OrderProgressStatus status) {
    Color bg;
    Color fg;
    switch (status) {
      case OrderProgressStatus.placed:
        bg = AppColors.champagneGold.withAlpha(30);
        fg = AppColors.champagneGold;
        break;
      case OrderProgressStatus.processing:
        bg = Colors.blue.withAlpha(30);
        fg = Colors.blue.shade700;
        break;
      case OrderProgressStatus.shipped:
      case OrderProgressStatus.outForDelivery:
        bg = Colors.purple.withAlpha(30);
        fg = Colors.purple.shade700;
        break;
      case OrderProgressStatus.delivered:
        bg = const Color(0xFF2E7D32).withAlpha(30);
        fg = const Color(0xFF2E7D32);
        break;
      case OrderProgressStatus.cancelled:
        bg = AppColors.error.withAlpha(30);
        fg = AppColors.error;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 11, color: fg),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentChip(String status) {
    final s = status.toLowerCase();
    Color bg;
    Color fg;
    if (s.contains('paid')) {
      bg = const Color(0xFF2E7D32).withAlpha(30);
      fg = const Color(0xFF2E7D32);
    } else if (s.contains('pending')) {
      bg = Colors.amber.withAlpha(40);
      fg = Colors.amber.shade900;
    } else {
      bg = Colors.blue.withAlpha(30);
      fg = Colors.blue.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  // ── States ─────────────────────────────────────────────────────────────────
  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      alignment: Alignment.center,
      child: const Column(
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(AppColors.champagneGold),
          ),
          SizedBox(height: AppSpacing.md),
          Text(
            'Fetching cross-customer order stream...',
            style: TextStyle(fontSize: 13, color: AppColors.secondaryText),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(AdminOrderController controller) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 40, color: AppColors.error),
          const SizedBox(height: AppSpacing.sm),
          Text(
            controller.errorMessage ?? 'Error loading orders',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.error,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          ElevatedButton(
            onPressed: () => controller.loadOrders(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.luxuryWine,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(AdminOrderController controller) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.receipt_long_outlined,
            size: 54,
            color: AppColors.secondaryText,
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'No orders found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.mainText,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Try adjusting your search criteria or resetting the active filters.',
            style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(
            onPressed: () {
              _searchController.clear();
              controller.clearFilters();
            },
            child: const Text('Reset Filters'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final m = months[dt.month - 1];
    return '$m ${dt.day}, ${dt.year}';
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../controllers/admin_customer_controller.dart';
import '../../../controllers/admin_order_controller.dart';
import '../../../controllers/admin_product_controller.dart';
import '../../../controllers/auth_controller.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/routes/app_routes.dart';
import '../../../models/order_model.dart';
import '../../../models/product_model.dart';
import '../admin_scaffold.dart';
import '../orders/order_details_dialog.dart';

/// AÈRA Executive Business Analytics Dashboard.
///
/// Fully connected to live Cloud Firestore data via [AdminOrderController],
/// [AdminProductController], and [AdminCustomerController].
///
/// Features:
/// - Top KPI Metric Cards (Revenue, Orders, Customers, Catalog Products)
/// - Revenue Analytics with Timeframe Filtering & Interactive Visualizer
/// - Order Fulfillment Lifecycle Pipeline
/// - Real Best-Selling Products derived from Customer Order Line Items
/// - Real-time Recent Orders Table with Inspect Modal Dialog
/// - Real-time Inventory Health & Low-Stock Alerts
/// - Customer Growth & Lifetime Value Metrics
class AdminDashboardView extends StatefulWidget {
  const AdminDashboardView({super.key});

  @override
  State<AdminDashboardView> createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends State<AdminDashboardView> {
  String _revenueTimeframe =
      'Last 7 Days'; // 'Today', 'Last 7 Days', 'Last 30 Days', 'All Time'

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final orderCtrl = context.watch<AdminOrderController>();
    final productCtrl = context.watch<AdminProductController>();
    final customerCtrl = context.watch<AdminCustomerController>();

    final profile = auth.customerProfile;
    final displayName = profile?.fullName.isNotEmpty == true
        ? profile!.fullName
        : auth.currentUser?.displayName ?? 'Administrator';

    final isLoading =
        orderCtrl.isLoading || productCtrl.isLoading || customerCtrl.isLoading;

    return AdminScaffold(
      title: 'Business Analytics Dashboard',
      currentRoute: AppRoutes.adminDashboard,
      body: RefreshIndicator(
        color: AppColors.luxuryWine,
        onRefresh: () async {
          await Future.wait([
            orderCtrl.loadOrders(),
            productCtrl.loadProducts(),
            customerCtrl.loadCustomers(),
          ]);
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 1100;
            final isTablet =
                constraints.maxWidth >= 650 && constraints.maxWidth < 1100;
            final isCompact = constraints.maxWidth < 600;

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(isCompact ? 12 : AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 1. Executive Welcome & Refresh Header ─────────────────
                  _buildExecutiveBanner(displayName, isLoading, () async {
                    await Future.wait([
                      orderCtrl.loadOrders(),
                      productCtrl.loadProducts(),
                      customerCtrl.loadCustomers(),
                    ]);
                  }),
                  const SizedBox(height: AppSpacing.lg),

                  // ── 2. Top Primary KPI Metrics ────────────────────────────
                  _buildPrimaryKpis(
                    context,
                    orderCtrl,
                    productCtrl,
                    customerCtrl,
                    isDesktop,
                    isTablet,
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // ── 3. Revenue Analytics & Chart Section ──────────────────
                  _buildRevenueAnalytics(context, orderCtrl, isDesktop),
                  const SizedBox(height: AppSpacing.xl),

                  // ── 4. Order Lifecycle Pipeline ───────────────────────────
                  _buildOrderPipeline(context, orderCtrl, isDesktop),
                  const SizedBox(height: AppSpacing.xl),

                  // ── 5. Split Section: Best-Sellers & Inventory Health ─────
                  if (isDesktop)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: _buildBestSellersCard(orderCtrl, productCtrl),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          flex: 2,
                          child: _buildInventoryHealthCard(productCtrl),
                        ),
                      ],
                    )
                  else ...[
                    _buildBestSellersCard(orderCtrl, productCtrl),
                    const SizedBox(height: AppSpacing.lg),
                    _buildInventoryHealthCard(productCtrl),
                  ],
                  const SizedBox(height: AppSpacing.xl),

                  // ── 6. Split Section: Recent Orders & Customer Analytics ──
                  if (isDesktop)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: _buildRecentOrdersCard(context, orderCtrl),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          flex: 2,
                          child: _buildCustomerAnalyticsCard(
                            customerCtrl,
                            orderCtrl,
                          ),
                        ),
                      ],
                    )
                  else ...[
                    _buildRecentOrdersCard(context, orderCtrl),
                    const SizedBox(height: AppSpacing.lg),
                    _buildCustomerAnalyticsCard(customerCtrl, orderCtrl),
                  ],
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ── 1. Executive Banner ────────────────────────────────────────────────────
  Widget _buildExecutiveBanner(
    String adminName,
    bool isLoading,
    Future<void> Function() onRefresh,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 600;

        final textContent = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.champagneGold.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.champagneGold.withAlpha(120),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 12,
                        color: AppColors.champagneGold,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'AÈRA LUXURY DASHBOARD',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.champagneGold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'Real-time Firestore Analytics',
                  style: TextStyle(
                    fontSize: isCompact ? 11 : 12,
                    color: AppColors.white.withAlpha(160),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Welcome back, $adminName',
              style: TextStyle(
                fontSize: isCompact ? 20 : 24,
                fontWeight: FontWeight.w900,
                color: AppColors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Operational monitoring for luxury cosmetics catalog, customer orders, fulfillment pipelines, and financial growth.',
              style: TextStyle(
                fontSize: isCompact ? 12 : 13,
                height: 1.4,
                color: AppColors.white.withAlpha(200),
              ),
            ),
          ],
        );

        final refreshButton = Align(
          alignment: isCompact ? Alignment.centerLeft : Alignment.centerRight,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: OutlinedButton.icon(
              onPressed: isLoading ? null : () => onRefresh(),
              icon: isLoading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.champagneGold,
                      ),
                    )
                  : const Icon(Icons.refresh_rounded, size: 16),
              label: Text(isLoading ? 'Syncing...' : 'Sync Firestore'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.champagneGold,
                side: BorderSide(
                  color: AppColors.champagneGold.withAlpha(150),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                minimumSize: const Size(0, 0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        );

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(isCompact ? 14 : 24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2C151A), Color(0xFF1E0E12)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.luxuryWine.withAlpha(90)),
            boxShadow: [
              BoxShadow(
                color: AppColors.luxuryWine.withAlpha(40),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: isCompact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    textContent,
                    const SizedBox(height: 16),
                    refreshButton,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: textContent),
                    const SizedBox(width: 16),
                    refreshButton,
                  ],
                ),
        );
      },
    );
  }

  // ── 2. Top Primary KPI Cards ───────────────────────────────────────────────
  Widget _buildPrimaryKpis(
    BuildContext context,
    AdminOrderController orderCtrl,
    AdminProductController productCtrl,
    AdminCustomerController customerCtrl,
    bool isDesktop,
    bool isTablet,
  ) {
    final currency = AppStrings.currency;

    // Financial Calculation: valid non-cancelled orders
    final totalRevenue = orderCtrl.totalRevenue;
    final totalOrders = orderCtrl.totalOrdersCount;
    final totalCustomers = customerCtrl.totalCustomersCount;
    final totalProducts = productCtrl.totalProductCount;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 600;

        final cards = [
          _buildKpiCard(
            title: 'Total Revenue',
            value: '$currency${totalRevenue.toStringAsFixed(2)}',
            subtitle:
                'From ${totalOrders - orderCtrl.cancelledCount} fulfilled orders',
            icon: Icons.payments_outlined,
            accentColor: AppColors.luxuryWine,
            badgeText: 'Live Gross',
            isCompact: isCompact,
          ),
          _buildKpiCard(
            title: 'Total Orders',
            value: '$totalOrders',
            subtitle: '${orderCtrl.pendingFulfillmentCount} pending fulfillment',
            icon: Icons.receipt_long_outlined,
            accentColor: const Color(0xFF1976D2),
            badgeText: '${orderCtrl.deliveredCount} Delivered',
            isCompact: isCompact,
          ),
          _buildKpiCard(
            title: 'Total Customers',
            value: '$totalCustomers',
            subtitle: '${customerCtrl.activeBuyersCount} active purchasers',
            icon: Icons.people_outline_rounded,
            accentColor: const Color(0xFF2E7D32),
            badgeText: '${customerCtrl.newCustomersThisMonth} this month',
            isCompact: isCompact,
          ),
          _buildKpiCard(
            title: 'Catalog Products',
            value: '$totalProducts',
            subtitle: '${productCtrl.lowStockCount} low stock alerts',
            icon: Icons.inventory_2_outlined,
            accentColor: AppColors.champagneGold,
            badgeText: '${productCtrl.inStockCount} in stock',
            isCompact: isCompact,
          ),
        ];

        if (constraints.maxWidth >= 900) {
          return Row(
            children: cards
                .map(
                  (c) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: c,
                    ),
                  ),
                )
                .toList(),
          );
        }

        if (constraints.maxWidth >= 340) {
          final itemWidth = (constraints.maxWidth - 10) / 2;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: cards.map((c) => SizedBox(width: itemWidth, child: c)).toList(),
          );
        }

        return Column(
          children: cards
              .map(
                (c) =>
                    Padding(padding: const EdgeInsets.only(bottom: 10), child: c),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required String badgeText,
    bool isCompact = false,
  }) {
    return Container(
      padding: EdgeInsets.all(isCompact ? 12 : 20),
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
              Container(
                padding: EdgeInsets.all(isCompact ? 8 : 10),
                decoration: BoxDecoration(
                  color: accentColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accentColor, size: isCompact ? 18 : 20),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 6 : 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: AppColors.divider.withAlpha(60),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: isCompact ? 9 : 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.secondaryText,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isCompact ? 10 : 16),
          Text(
            title,
            style: TextStyle(
              fontSize: isCompact ? 11 : 12,
              fontWeight: FontWeight.w600,
              color: AppColors.secondaryText,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: isCompact ? 18 : 24,
                fontWeight: FontWeight.w900,
                color: AppColors.mainText,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: isCompact ? 10 : 11,
              color: AppColors.secondaryText,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ── 3. Revenue Analytics & Chart Section ───────────────────────────────────
  Widget _buildRevenueAnalytics(
    BuildContext context,
    AdminOrderController orderCtrl,
    bool isDesktop,
  ) {
    final currency = AppStrings.currency;
    final allOrders = orderCtrl.allOrders
        .where((o) => o.status != OrderProgressStatus.cancelled)
        .toList();

    // Time calculations
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = now.subtract(const Duration(days: 7));
    final monthStart = DateTime(now.year, now.month, 1);

    final dailyRevenue = allOrders
        .where((o) => o.createdAt.isAfter(todayStart))
        .fold(0.0, (sum, o) => sum + o.total);

    final weeklyRevenue = allOrders
        .where((o) => o.createdAt.isAfter(weekStart))
        .fold(0.0, (sum, o) => sum + o.total);

    final monthlyRevenue = allOrders
        .where((o) => o.createdAt.isAfter(monthStart))
        .fold(0.0, (sum, o) => sum + o.total);

    // Filtered data points for the visualizer
    DateTime filterCutoff;
    if (_revenueTimeframe == 'Today') {
      filterCutoff = todayStart;
    } else if (_revenueTimeframe == 'Last 7 Days') {
      filterCutoff = weekStart;
    } else if (_revenueTimeframe == 'Last 30 Days') {
      filterCutoff = now.subtract(const Duration(days: 30));
    } else {
      filterCutoff = DateTime(2000);
    }

    final filteredOrders = allOrders
        .where((o) => o.createdAt.isAfter(filterCutoff))
        .toList();
    final timeframeRevenue = filteredOrders.fold(
      0.0,
      (sum, o) => sum + o.total,
    );

    // Group revenue by date buckets for the bar visualizer
    final Map<String, double> dateBuckets = {};
    final daysToGenerate = _revenueTimeframe == 'Today'
        ? 1
        : (_revenueTimeframe == 'Last 7 Days' ? 7 : 14);

    for (int i = daysToGenerate - 1; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final label = '${date.day}/${date.month}';
      dateBuckets[label] = 0.0;
    }

    for (final order in filteredOrders) {
      final label = '${order.createdAt.day}/${order.createdAt.month}';
      if (dateBuckets.containsKey(label)) {
        dateBuckets[label] = (dateBuckets[label] ?? 0.0) + order.total;
      }
    }

    final maxVal = dateBuckets.values.isEmpty
        ? 1.0
        : (dateBuckets.values.reduce((a, b) => a > b ? a : b) == 0
              ? 1.0
              : dateBuckets.values.reduce((a, b) => a > b ? a : b));

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 600;

        return Container(
          padding: EdgeInsets.all(isCompact ? 14 : 24),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(20),
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
              // Header with Timeframe filter selector
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 12,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Revenue Analytics & Velocity',
                        style: TextStyle(
                          fontSize: isCompact ? 16 : 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.mainText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Gross merchandise volume computed exclusively from confirmed, non-cancelled orders.',
                        style: TextStyle(
                          fontSize: isCompact ? 11 : 12,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                  // Timeframe filter dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant.withAlpha(80),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _revenueTimeframe,
                        icon: const Icon(
                          Icons.calendar_today_outlined,
                          size: 14,
                          color: AppColors.luxuryWine,
                        ),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.luxuryWine,
                        ),
                        items: ['Today', 'Last 7 Days', 'Last 30 Days', 'All Time']
                            .map(
                              (tf) => DropdownMenuItem(value: tf, child: Text(tf)),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _revenueTimeframe = val);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Sub-KPI Metric Ribbon
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  _buildMiniMetric(
                    'Today Revenue',
                    '$currency${dailyRevenue.toStringAsFixed(2)}',
                    AppColors.luxuryWine,
                    isCompact: isCompact,
                  ),
                  _buildMiniMetric(
                    'Past 7 Days',
                    '$currency${weeklyRevenue.toStringAsFixed(2)}',
                    const Color(0xFF1976D2),
                    isCompact: isCompact,
                  ),
                  _buildMiniMetric(
                    'This Month',
                    '$currency${monthlyRevenue.toStringAsFixed(2)}',
                    const Color(0xFF2E7D32),
                    isCompact: isCompact,
                  ),
                  _buildMiniMetric(
                    'Selected Window',
                    '$currency${timeframeRevenue.toStringAsFixed(2)}',
                    AppColors.champagneGold,
                    isCompact: isCompact,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Custom Responsive Bar Chart Visualizer
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 10 : 16,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: AppColors.background.withAlpha(120),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.divider.withAlpha(80)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Daily Trend ($_revenueTimeframe)',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.mainText,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          'Peak: $currency${maxVal.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.secondaryText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 140,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: SizedBox(
                          width: (dateBuckets.length * (isCompact ? 42.0 : 54.0))
                              .clamp(constraints.maxWidth - 50, 1200.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: dateBuckets.entries.map((entry) {
                              final ratio = (entry.value / maxVal).clamp(0.08, 1.0);
                              final isSelected = entry.value > 0;

                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 3),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      if (entry.value > 0)
                                        FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            '$currency${entry.value.toStringAsFixed(0)}',
                                            style: const TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.luxuryWine,
                                            ),
                                          ),
                                        ),
                                      const SizedBox(height: 4),
                                      Flexible(
                                        child: Container(
                                          height: 100 * ratio,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: isSelected
                                                  ? [
                                                      AppColors.luxuryWine,
                                                      AppColors.champagneGold,
                                                    ]
                                                  : [
                                                      AppColors.divider,
                                                      AppColors.divider.withAlpha(120),
                                                    ],
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                            ),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          entry.key,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: isSelected
                                                ? AppColors.mainText
                                                : AppColors.secondaryText,
                                            fontWeight: isSelected
                                                ? FontWeight.w700
                                                : FontWeight.w400,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
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
      },
    );
  }

  Widget _buildMiniMetric(
    String label,
    String value,
    Color color, {
    bool isCompact = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 12 : 16,
        vertical: isCompact ? 8 : 12,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isCompact ? 10 : 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: isCompact ? 14 : 16,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ── 4. Order Lifecycle Pipeline ───────────────────────────────────────────
  Widget _buildOrderPipeline(
    BuildContext context,
    AdminOrderController orderCtrl,
    bool isDesktop,
  ) {
    final all = orderCtrl.allOrders;
    final total = all.isEmpty ? 1 : all.length;

    final placedCount = all
        .where((o) => o.status == OrderProgressStatus.placed)
        .length;
    final processingCount = all
        .where((o) => o.status == OrderProgressStatus.processing)
        .length;
    final shippedCount = all
        .where((o) => o.status == OrderProgressStatus.shipped)
        .length;
    final outForDeliveryCount = all
        .where((o) => o.status == OrderProgressStatus.outForDelivery)
        .length;
    final deliveredCount = all
        .where((o) => o.status == OrderProgressStatus.delivered)
        .length;
    final cancelledCount = all
        .where((o) => o.status == OrderProgressStatus.cancelled)
        .length;

    final steps = [
      _PipelineStep(
        'Placed',
        placedCount,
        total,
        const Color(0xFFE65100),
        Icons.shopping_cart_outlined,
      ),
      _PipelineStep(
        'Processing',
        processingCount,
        total,
        const Color(0xFF1976D2),
        Icons.hourglass_top_outlined,
      ),
      _PipelineStep(
        'Shipped',
        shippedCount,
        total,
        const Color(0xFF7B1FA2),
        Icons.local_shipping_outlined,
      ),
      _PipelineStep(
        'Out for Delivery',
        outForDeliveryCount,
        total,
        const Color(0xFF00897B),
        Icons.delivery_dining_outlined,
      ),
      _PipelineStep(
        'Delivered',
        deliveredCount,
        total,
        const Color(0xFF2E7D32),
        Icons.check_circle_outline,
      ),
      _PipelineStep(
        'Cancelled',
        cancelledCount,
        total,
        AppColors.error,
        Icons.cancel_outlined,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 600;

        return Container(
          padding: EdgeInsets.all(isCompact ? 14 : 24),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(20),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order Fulfillment Pipeline',
                          style: TextStyle(
                            fontSize: isCompact ? 16 : 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.mainText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Live order progression across active fulfillment stages',
                          style: TextStyle(
                            fontSize: isCompact ? 11 : 12,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Align(
                    alignment: Alignment.center,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 130),
                      child: TextButton.icon(
                        onPressed: () => Navigator.of(
                          context,
                        ).pushReplacementNamed(AppRoutes.adminOrders),
                        icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                        label: const Text('Manage Orders'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.luxuryWine,
                          minimumSize: const Size(0, 0),
                          textStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (constraints.maxWidth >= 900)
                Row(
                  children: steps
                      .map(
                        (s) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: _buildPipelineStepTile(s, isCompact: false),
                          ),
                        ),
                      )
                      .toList(),
                )
              else ...[
                Builder(
                  builder: (context) {
                    final itemWidth = constraints.maxWidth >= 500
                        ? (constraints.maxWidth - 20) / 3
                        : (constraints.maxWidth >= 320
                            ? (constraints.maxWidth - 10) / 2
                            : constraints.maxWidth);

                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: steps
                          .map(
                            (s) => SizedBox(
                              width: itemWidth,
                              child: _buildPipelineStepTile(s, isCompact: true),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildPipelineStepTile(_PipelineStep step, {bool isCompact = false}) {
    final pct = (step.count / step.totalOrders * 100).toStringAsFixed(0);

    return Container(
      padding: EdgeInsets.all(isCompact ? 10 : 14),
      decoration: BoxDecoration(
        color: step.color.withAlpha(12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: step.color.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(step.icon, color: step.color, size: isCompact ? 16 : 18),
              Text(
                '$pct%',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: step.color,
                ),
              ),
            ],
          ),
          SizedBox(height: isCompact ? 6 : 10),
          Text(
            '${step.count}',
            style: TextStyle(
              fontSize: isCompact ? 18 : 22,
              fontWeight: FontWeight.w900,
              color: step.color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            step.title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.mainText,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ── 5. Best-Selling Products Card ─────────────────────────────────────────
  Widget _buildBestSellersCard(
    AdminOrderController orderCtrl,
    AdminProductController productCtrl,
  ) {
    final currency = AppStrings.currency;

    // Aggregate items across non-cancelled orders
    final Map<String, _ProductSalesStats> salesMap = {};

    for (final order in orderCtrl.allOrders) {
      if (order.status == OrderProgressStatus.cancelled) continue;
      for (final item in order.items) {
        ProductModel? matchedProduct;
        try {
          matchedProduct = productCtrl.products.firstWhere((p) => p.id == item.productId);
        } catch (_) {}
        final prodImg = matchedProduct?.imageUrl ?? '';

        if (!salesMap.containsKey(item.productId)) {
          salesMap[item.productId] = _ProductSalesStats(
            productId: item.productId,
            name: item.productName,
            imageUrl: prodImg,
            unitsSold: 0,
            revenue: 0.0,
          );
        }
        final current = salesMap[item.productId]!;
        salesMap[item.productId] = _ProductSalesStats(
          productId: item.productId,
          name: item.productName,
          imageUrl: prodImg.isNotEmpty ? prodImg : current.imageUrl,
          unitsSold: current.unitsSold + item.quantity,
          revenue: current.revenue + (item.price * item.quantity),
        );
      }
    }

    // Sort by units sold
    final topList = salesMap.values.toList()
      ..sort((a, b) => b.unitsSold.compareTo(a.unitsSold));

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 600;

        return Container(
          padding: EdgeInsets.all(isCompact ? 14 : 24),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(20),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Best-Selling Products',
                          style: TextStyle(
                            fontSize: isCompact ? 16 : 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.mainText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ranked by real units purchased from fulfilled customer carts',
                          style: TextStyle(
                            fontSize: isCompact ? 11 : 12,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.champagneGold.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'TOP PERFORMERS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.luxuryWine,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (topList.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  alignment: Alignment.center,
                  child: const Column(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 36,
                        color: AppColors.secondaryText,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'No orders completed yet to calculate sales leaders.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: topList.length > 5 ? 5 : topList.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 16, color: AppColors.divider),
                  itemBuilder: (context, index) {
                    final item = topList[index];

                    return Row(
                      children: [
                        // Rank badge
                        Container(
                          width: 26,
                          height: 26,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: index == 0
                                ? AppColors.champagneGold
                                : (index == 1
                                      ? AppColors.softRose
                                      : AppColors.divider),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '#${index + 1}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: index < 2
                                  ? AppColors.white
                                  : AppColors.mainText,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Image thumbnail
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 40,
                            height: 40,
                            color: AppColors.surfaceVariant,
                            child: item.imageUrl.isNotEmpty
                                ? (item.imageUrl.startsWith('http')
                                      ? Image.network(
                                          item.imageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (ctx, err, stack) => const Icon(
                                            Icons.image_not_supported_outlined,
                                            size: 16,
                                            color: AppColors.secondaryText,
                                          ),
                                        )
                                      : Image.asset(
                                          item.imageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (ctx, err, stack) => const Icon(
                                            Icons.image_not_supported_outlined,
                                            size: 16,
                                            color: AppColors.secondaryText,
                                          ),
                                        ))
                                : const Icon(
                                    Icons.image_outlined,
                                    size: 16,
                                    color: AppColors.secondaryText,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Title
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.mainText,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${item.unitsSold} units sold',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.secondaryText,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Revenue
                        Text(
                          '$currency${item.revenue.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.luxuryWine,
                          ),
                        ),
                      ],
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  // ── 5b. Inventory Health Card ─────────────────────────────────────────────
  Widget _buildInventoryHealthCard(AdminProductController productCtrl) {
    final currency = AppStrings.currency;
    final products = productCtrl.products;

    final lowStockItems = products
        .where(
          (p) => p.isAvailable && p.stockQuantity <= 5 && p.stockQuantity > 0,
        )
        .toList();
    final outOfStockItems = products
        .where((p) => !p.isAvailable || p.stockQuantity <= 0)
        .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 600;

        return Container(
          padding: EdgeInsets.all(isCompact ? 14 : 24),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(20),
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
                      'Inventory Health',
                      style: TextStyle(
                        fontSize: isCompact ? 16 : 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.mainText,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Align(
                    alignment: Alignment.center,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 120),
                      child: TextButton(
                        onPressed: () => Navigator.of(
                          context,
                        ).pushReplacementNamed(AppRoutes.adminProducts),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.luxuryWine,
                          minimumSize: const Size(0, 0),
                          textStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        child: const Text('Catalog →'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Valuation: $currency${productCtrl.totalInventoryValue.toStringAsFixed(2)} in warehouse assets',
                style: TextStyle(
                  fontSize: isCompact ? 11 : 12,
                  color: AppColors.secondaryText,
                ),
              ),
              const SizedBox(height: 16),

              // Stat Pills
              Row(
                children: [
                  Expanded(
                    child: _buildHealthBadge(
                      label: 'In Stock',
                      count: productCtrl.inStockCount,
                      color: const Color(0xFF2E7D32),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildHealthBadge(
                      label: 'Low Stock',
                      count: productCtrl.lowStockCount,
                      color: const Color(0xFFE65100),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildHealthBadge(
                      label: 'Out of Stock',
                      count: productCtrl.outOfStockCount,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Alerts List
              const Text(
                'Critical Stock Alerts',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.mainText,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 8),
              if (lowStockItems.isEmpty && outOfStockItems.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  alignment: Alignment.center,
                  child: const Text(
                    '✅ All catalog items have healthy stock levels.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF2E7D32),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else ...[
                ...lowStockItems
                    .take(3)
                    .map((p) => _buildStockAlertRow(p, isOut: false)),
                ...outOfStockItems
                    .take(2)
                    .map((p) => _buildStockAlertRow(p, isOut: true)),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildHealthBadge({
    required String label,
    required int count,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStockAlertRow(ProductModel p, {required bool isOut}) {
    final color = isOut ? AppColors.error : const Color(0xFFE65100);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isOut ? Icons.error_outline_rounded : Icons.warning_amber_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              p.name,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.mainText,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isOut ? 'Out of Stock' : '${p.stockQuantity} left',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 6. Recent Orders Card ─────────────────────────────────────────────────
  Widget _buildRecentOrdersCard(
    BuildContext context,
    AdminOrderController orderCtrl,
  ) {
    final currency = AppStrings.currency;
    final recentOrders = orderCtrl.allOrders.take(6).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 600;

        return Container(
          padding: EdgeInsets.all(isCompact ? 14 : 24),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(20),
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recent Store Orders',
                          style: TextStyle(
                            fontSize: isCompact ? 16 : 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.mainText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Chronological feed of customer purchases with inspect dialog',
                          style: TextStyle(
                            fontSize: isCompact ? 11 : 12,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Align(
                    alignment: Alignment.center,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 120),
                      child: TextButton.icon(
                        onPressed: () => Navigator.of(
                          context,
                        ).pushReplacementNamed(AppRoutes.adminOrders),
                        icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                        label: const Text('View All'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.luxuryWine,
                          minimumSize: const Size(0, 0),
                          textStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (recentOrders.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  alignment: Alignment.center,
                  child: const Text(
                    'No orders placed in Firestore yet.',
                    style: TextStyle(fontSize: 13, color: AppColors.secondaryText),
                  ),
                )
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 550),
                    child: DataTable(
                      horizontalMargin: 8,
                      columnSpacing: 20,
                      headingRowHeight: 40,
                      dataRowMinHeight: 48,
                      dataRowMaxHeight: 56,
                      columns: const [
                        DataColumn(
                          label: Text(
                            'Order ID',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Customer',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Date',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Amount',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Status',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Action',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                      rows: recentOrders.map((order) {
                        final dateStr =
                            '${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year}';
                        final statusColor = _statusColor(order.status);

                        return DataRow(
                          cells: [
                            DataCell(
                              Text(
                                order.id.length > 8
                                    ? '#${order.id.substring(0, 8)}'
                                    : '#${order.id}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.luxuryWine,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                order.shippingName.isNotEmpty
                                    ? order.shippingName
                                    : 'Guest Customer',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                dateStr,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.secondaryText,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                '$currency${order.total.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withAlpha(20),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  order.status.label,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Align(
                                alignment: Alignment.center,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 100),
                                  child: OutlinedButton(
                                    onPressed: () =>
                                        OrderDetailsDialog.show(context, order),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.luxuryWine,
                                      side: const BorderSide(
                                        color: AppColors.luxuryWine,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      minimumSize: const Size(0, 0),
                                      textStyle: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                    child: const Text('Inspect'),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ── 6b. Customer Analytics Card ───────────────────────────────────────────
  Widget _buildCustomerAnalyticsCard(
    AdminCustomerController customerCtrl,
    AdminOrderController orderCtrl,
  ) {
    final currency = AppStrings.currency;
    final totalCustomers = customerCtrl.totalCustomersCount;
    final activeBuyers = customerCtrl.activeBuyersCount;
    final repeatBuyers = customerCtrl.allCustomers
        .where((c) => customerCtrl.getOrderCount(c.uid) > 1)
        .length;

    final nonCancelledOrders = orderCtrl.allOrders
        .where((o) => o.status != OrderProgressStatus.cancelled)
        .toList();
    final aov = nonCancelledOrders.isEmpty
        ? 0.0
        : (orderCtrl.totalRevenue / nonCancelledOrders.length);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 600;

        return Container(
          padding: EdgeInsets.all(isCompact ? 14 : 24),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(20),
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
                      'Customer Retention',
                      style: TextStyle(
                        fontSize: isCompact ? 16 : 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.mainText,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Align(
                    alignment: Alignment.center,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 130),
                      child: TextButton(
                        onPressed: () => Navigator.of(
                          context,
                        ).pushReplacementNamed(AppRoutes.adminCustomers),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.luxuryWine,
                          minimumSize: const Size(0, 0),
                          textStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        child: const Text('Directory →'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Audience cohort engagement and average order values',
                style: TextStyle(
                  fontSize: isCompact ? 11 : 12,
                  color: AppColors.secondaryText,
                ),
              ),
              const SizedBox(height: 20),

              _buildCustomerMetricRow(
                title: 'Average Order Value (AOV)',
                value: '$currency${aov.toStringAsFixed(2)}',
                subtitle: 'Across fulfilled baskets',
                icon: Icons.auto_graph_rounded,
                color: AppColors.luxuryWine,
                isCompact: isCompact,
              ),
              const Divider(height: 24, color: AppColors.divider),
              _buildCustomerMetricRow(
                title: 'Repeat Buyers Rate',
                value: totalCustomers > 0
                    ? '${((repeatBuyers / totalCustomers) * 100).toStringAsFixed(1)}%'
                    : '0%',
                subtitle: '$repeatBuyers customers placed 2+ orders',
                icon: Icons.repeat_rounded,
                color: const Color(0xFF1976D2),
                isCompact: isCompact,
              ),
              const Divider(height: 24, color: AppColors.divider),
              _buildCustomerMetricRow(
                title: 'Buyer Conversion Rate',
                value: totalCustomers > 0
                    ? '${((activeBuyers / totalCustomers) * 100).toStringAsFixed(1)}%'
                    : '0%',
                subtitle: '$activeBuyers of $totalCustomers purchased',
                icon: Icons.verified_user_outlined,
                color: const Color(0xFF2E7D32),
                isCompact: isCompact,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCustomerMetricRow({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    bool isCompact = false,
  }) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(isCompact ? 8 : 10),
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: isCompact ? 16 : 20),
        ),
        SizedBox(width: isCompact ? 10 : 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: isCompact ? 11 : 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.mainText,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: isCompact ? 10 : 11,
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: isCompact ? 14 : 16,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }

  Color _statusColor(OrderProgressStatus status) {
    switch (status) {
      case OrderProgressStatus.placed:
        return const Color(0xFFE65100);
      case OrderProgressStatus.processing:
        return const Color(0xFF1976D2);
      case OrderProgressStatus.shipped:
        return const Color(0xFF7B1FA2);
      case OrderProgressStatus.outForDelivery:
        return const Color(0xFF00897B);
      case OrderProgressStatus.delivered:
        return const Color(0xFF2E7D32);
      case OrderProgressStatus.cancelled:
        return AppColors.error;
    }
  }
}

class _PipelineStep {
  final String title;
  final int count;
  final int totalOrders;
  final Color color;
  final IconData icon;

  const _PipelineStep(
    this.title,
    this.count,
    this.totalOrders,
    this.color,
    this.icon,
  );
}

class _ProductSalesStats {
  final String productId;
  final String name;
  final String imageUrl;
  final int unitsSold;
  final double revenue;

  const _ProductSalesStats({
    required this.productId,
    required this.name,
    required this.imageUrl,
    required this.unitsSold,
    required this.revenue,
  });
}

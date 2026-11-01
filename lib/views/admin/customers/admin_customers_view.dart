import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../controllers/admin_customer_controller.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/routes/app_routes.dart';
import '../admin_scaffold.dart';
import 'customer_details_dialog.dart';
import '../../../widgets/luxury_ui_components.dart';

/// Full administrative customer directory and lifetime value management screen.
class AdminCustomersView extends StatefulWidget {
  const AdminCustomersView({super.key});

  @override
  State<AdminCustomersView> createState() => _AdminCustomersViewState();
}

class _AdminCustomersViewState extends State<AdminCustomersView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Customer Directory',
      currentRoute: AppRoutes.adminCustomers,
      body: Consumer<AdminCustomerController>(
        builder: (context, controller, _) {
          return RefreshIndicator(
            color: AppColors.luxuryWine,
            onRefresh: () => controller.loadCustomers(),
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
                  _buildSearchBar(context, controller),
                  const SizedBox(height: AppSpacing.md),

                  // ── 3. Content: Desktop Table vs Mobile Cards ─────────────
                  if (controller.isLoading && controller.allCustomers.isEmpty)
                    _buildLoadingState()
                  else if (controller.errorMessage != null &&
                      controller.allCustomers.isEmpty)
                    _buildErrorState(controller)
                  else if (controller.filteredCustomers.isEmpty)
                    _buildEmptyState(controller)
                  else
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isDesktop = constraints.maxWidth >= 850;
                        if (isDesktop) {
                          return _buildDesktopDataTable(context, controller);
                        }
                        return _buildMobileCustomerList(context, controller);
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

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, AdminCustomerController controller) {
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
                  'Customer Accounts Directory',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.mainText,
                    letterSpacing: -0.5,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.luxuryWine.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${controller.allCustomers.length} registered',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.luxuryWine,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Inspect registered customer profiles, lifetime spending, and order history from Firestore',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.secondaryText,
              ),
            ),
          ],
        );

        final actionButtons = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.center,
              child: LuxuryActionButton.refresh(
                onPressed: controller.isLoading ? null : () => controller.loadCustomers(),
                isLoading: controller.isLoading,
                label: 'Refresh',
              ),
            ),
          ],
        );

        if (constraints.maxWidth < 600) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleColumn,
              const SizedBox(height: 12),
              actionButtons,
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: titleColumn),
            actionButtons,
          ],
        );
      },
    );
  }

  // ── KPI Row ────────────────────────────────────────────────────────────────

  Widget _buildKpiMetricsRow(AdminCustomerController controller) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth >= 900
            ? (constraints.maxWidth - 48) / 4
            : (constraints.maxWidth >= 480 ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth);

        return Wrap(
          spacing: 16,
          runSpacing: 12,
          children: [
            _buildKpiCard(
              title: 'Total Customers',
              value: '${controller.totalCustomersCount}',
              subtitle: 'Registered accounts',
              icon: Icons.people_outline_rounded,
              iconColor: AppColors.luxuryWine,
              width: cardWidth,
            ),
            _buildKpiCard(
              title: 'Active Buyers',
              value: '${controller.activeBuyersCount}',
              subtitle: 'Have placed >= 1 order',
              icon: Icons.shopping_bag_outlined,
              iconColor: const Color(0xFF1976D2),
              width: cardWidth,
            ),
            _buildKpiCard(
              title: 'Total Revenue',
              value: '₹${controller.totalCustomerRevenue.toStringAsFixed(2)}',
              subtitle: 'Lifetime gross sales',
              icon: Icons.payments_outlined,
              iconColor: const Color(0xFF2E7D32),
              width: cardWidth,
            ),
            _buildKpiCard(
              title: 'New This Month',
              value: '${controller.newCustomersThisMonth}',
              subtitle: 'Current calendar month',
              icon: Icons.person_add_alt_1_outlined,
              iconColor: AppColors.champagneGold,
              width: cardWidth,
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required double width,
  }) {
    return Container(
      width: width,
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
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Search Bar ─────────────────────────────────────────────────────────────

  Widget _buildSearchBar(BuildContext context, AdminCustomerController controller) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => controller.setSearchQuery(val),
        decoration: InputDecoration(
          hintText: 'Search customers by name, email, or phone number...',
          hintStyle: const TextStyle(fontSize: 13, color: AppColors.secondaryText),
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.secondaryText),
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            borderSide: const BorderSide(color: AppColors.luxuryWine, width: 1.5),
          ),
        ),
      ),
    );
  }

  // ── Desktop Data Table ─────────────────────────────────────────────────────

  Widget _buildDesktopDataTable(BuildContext context, AdminCustomerController controller) {
    final customers = controller.filteredCustomers;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: AppColors.divider)),
            ),
            child: const Row(
              children: [
                Expanded(flex: 3, child: Text('CUSTOMER', style: _tableHeaderStyle)),
                Expanded(flex: 3, child: Text('EMAIL', style: _tableHeaderStyle)),
                Expanded(flex: 2, child: Text('PHONE', style: _tableHeaderStyle)),
                Expanded(flex: 2, child: Text('REGISTERED', style: _tableHeaderStyle)),
                Expanded(flex: 1, child: Text('ORDERS', style: _tableHeaderStyle, textAlign: TextAlign.center)),
                Expanded(flex: 2, child: Text('TOTAL SPENT', style: _tableHeaderStyle, textAlign: TextAlign.right)),
                SizedBox(width: 120, child: Text('ACTIONS', style: _tableHeaderStyle, textAlign: TextAlign.center)),
              ],
            ),
          ),

          // Table Rows
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: customers.length,
            separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.divider),
            itemBuilder: (context, index) {
              final customer = customers[index];
              final orderCount = controller.getOrderCount(customer.uid);
              final totalSpent = controller.getTotalSpent(customer.uid);

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  children: [
                    // Customer Name & Avatar
                    Expanded(
                      flex: 3,
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: AppColors.luxuryWine.withAlpha(25),
                            child: Text(
                              _getInitials(customer.fullName),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.luxuryWine,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  customer.fullName.isNotEmpty ? customer.fullName : 'Guest Account',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.mainText,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (customer.isAdmin)
                                  Container(
                                    margin: const EdgeInsets.only(top: 2),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppColors.luxuryWine.withAlpha(20),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'ADMIN',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.luxuryWine,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Email
                    Expanded(
                      flex: 3,
                      child: Text(
                        customer.email,
                        style: const TextStyle(fontSize: 12, color: AppColors.mainText),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // Phone
                    Expanded(
                      flex: 2,
                      child: Text(
                        customer.phoneNumber?.isNotEmpty == true
                            ? customer.phoneNumber!
                            : 'Not provided',
                        style: TextStyle(
                          fontSize: 12,
                          color: customer.phoneNumber?.isNotEmpty == true
                              ? AppColors.mainText
                              : AppColors.secondaryText,
                          fontStyle: customer.phoneNumber?.isNotEmpty == true
                              ? FontStyle.normal
                              : FontStyle.italic,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // Registered Date
                    Expanded(
                      flex: 2,
                      child: Text(
                        _formatDate(customer.createdAt),
                        style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
                      ),
                    ),

                    // Order Count
                    Expanded(
                      flex: 1,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: orderCount > 0
                                ? AppColors.luxuryWine.withAlpha(20)
                                : AppColors.secondaryText.withAlpha(20),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$orderCount',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: orderCount > 0 ? AppColors.luxuryWine : AppColors.secondaryText,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Total Spent
                    Expanded(
                      flex: 2,
                      child: Text(
                        '₹${totalSpent.toStringAsFixed(2)}',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.mainText,
                        ),
                      ),
                    ),

                    // Actions
                    SizedBox(
                      width: 120,
                      child: Center(
                        child: LuxuryActionButton.customerDetails(
                          onPressed: () => CustomerDetailsDialog.show(context, customer),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Mobile Customer List ───────────────────────────────────────────────────

  Widget _buildMobileCustomerList(BuildContext context, AdminCustomerController controller) {
    final customers = controller.filteredCustomers;

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: customers.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final customer = customers[index];
        final orderCount = controller.getOrderCount(customer.uid);
        final totalSpent = controller.getTotalSpent(customer.uid);

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
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.luxuryWine.withAlpha(25),
                    child: Text(
                      _getInitials(customer.fullName),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.luxuryWine,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                customer.fullName.isNotEmpty ? customer.fullName : 'Guest Account',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.mainText,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (customer.isAdmin) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.luxuryWine.withAlpha(20),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'ADMIN',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.luxuryWine,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          customer.email,
                          style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.divider),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ORDERS',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.secondaryText),
                      ),
                      Text(
                        '$orderCount orders',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.mainText),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'TOTAL SPENT',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.secondaryText),
                      ),
                      Text(
                        '₹${totalSpent.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.luxuryWine),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: LuxuryActionButton.customerDetails(
                  label: 'View Customer Details & History',
                  onPressed: () => CustomerDetailsDialog.show(context, customer),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── States ─────────────────────────────────────────────────────────────────

  Widget _buildLoadingState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: const Column(
        children: [
          CircularProgressIndicator(color: AppColors.luxuryWine),
          SizedBox(height: 16),
          Text(
            'Loading customer records...',
            style: TextStyle(fontSize: 13, color: AppColors.secondaryText),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(AdminCustomerController controller) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withAlpha(80)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          const Text(
            'Failed to Load Customer Directory',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.mainText),
          ),
          const SizedBox(height: 6),
          Text(
            controller.errorMessage ?? 'An error occurred while connecting to Firestore.',
            style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: ElevatedButton.icon(
                onPressed: () => controller.loadCustomers(),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.luxuryWine,
                  foregroundColor: AppColors.white,
                  minimumSize: const Size(0, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(AdminCustomerController controller) {
    final isSearching = controller.searchQuery.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          Icon(
            isSearching ? Icons.search_off_rounded : Icons.people_outline_rounded,
            size: 48,
            color: AppColors.secondaryText,
          ),
          const SizedBox(height: 12),
          Text(
            isSearching ? 'No Matching Customers Found' : 'No Customer Accounts Found',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.mainText),
          ),
          const SizedBox(height: 6),
          Text(
            isSearching
                ? 'No customer records match "${controller.searchQuery}". Try a different name, email, or clear your query.'
                : 'Customer profile documents created at /customers in Firestore will appear here.',
            style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
            textAlign: TextAlign.center,
          ),
          if (isSearching) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.center,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: OutlinedButton(
                  onPressed: () {
                    _searchController.clear();
                    controller.setSearchQuery('');
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    foregroundColor: AppColors.luxuryWine,
                  ),
                  child: const Text('Clear Search Filter'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static const TextStyle _tableHeaderStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w800,
    color: AppColors.secondaryText,
    letterSpacing: 0.8,
  );

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../controllers/admin_customer_controller.dart';
import '../../../core/constants/app_constants.dart';
import '../../../models/customer_model.dart';
import '../../../models/order_model.dart';

/// Modal dialog displaying verified customer profile details, lifetime metrics,
/// shipping address, and comprehensive order history.
class CustomerDetailsDialog extends StatelessWidget {
  final CustomerModel customer;

  const CustomerDetailsDialog({super.key, required this.customer});

  static Future<void> show(BuildContext context, CustomerModel customer) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => CustomerDetailsDialog(customer: customer),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AdminCustomerController>();
    final orders = controller.getCustomerOrders(customer.uid);
    final totalSpent = controller.getTotalSpent(customer.uid);
    final orderCount = controller.getOrderCount(customer.uid);
    final shippingAddress = controller.getLatestShippingAddress(customer.uid);
    final avgOrderValue = orderCount > 0 ? (totalSpent / orderCount) : 0.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 780,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(50),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Header ───────────────────────────────────────────────────────
            _buildDialogHeader(context),

            // ── Scrollable Body ──────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section 1: Customer Profile Overview
                    _buildProfileSection(context),
                    const SizedBox(height: AppSpacing.lg),

                    // Section 2: Lifetime Metrics
                    _buildMetricsSection(orderCount, totalSpent, avgOrderValue),
                    const SizedBox(height: AppSpacing.lg),

                    // Section 3: Shipping Address
                    _buildShippingSection(shippingAddress, orders),
                    const SizedBox(height: AppSpacing.lg),

                    // Section 4: Complete Order History
                    _buildOrderHistorySection(orders),
                  ],
                ),
              ),
            ),

            // ── Footer ───────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                    Align(
                      alignment: Alignment.center,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 120),
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded, size: 16),
                          label: const Text('Close'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.mainText,
                            side: const BorderSide(color: AppColors.divider),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            minimumSize: const Size(0, 0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
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
      ),
    );
  }

  // ── Sub-components ─────────────────────────────────────────────────────────

  Widget _buildDialogHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.luxuryWine,
            child: Text(
              _getInitials(customer.fullName),
              style: const TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      customer.fullName.isNotEmpty ? customer.fullName : 'Guest Customer',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.mainText,
                      ),
                    ),
                    _buildRoleBadge(customer.role),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  customer.email,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
            color: AppColors.secondaryText,
          ),
        ],
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    final isAdmin = role.trim().toLowerCase() == 'admin';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isAdmin ? AppColors.luxuryWine.withAlpha(25) : AppColors.champagneGold.withAlpha(40),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isAdmin ? AppColors.luxuryWine.withAlpha(80) : AppColors.champagneGold.withAlpha(120),
        ),
      ),
      child: Text(
        isAdmin ? 'ADMIN' : 'CUSTOMER',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: isAdmin ? AppColors.luxuryWine : const Color(0xFF8A6D3B),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildProfileSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CUSTOMER INFORMATION',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.luxuryWine,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 480;
              return Wrap(
                spacing: 24,
                runSpacing: 12,
                children: [
                  _buildInfoField(
                    label: 'Customer UID',
                    value: customer.uid,
                    trailing: InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: customer.uid));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Customer UID copied to clipboard'),
                            behavior: SnackBarBehavior.floating,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      child: const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(Icons.copy_rounded, size: 14, color: AppColors.secondaryText),
                      ),
                    ),
                    width: isWide ? 260 : null,
                  ),
                  _buildInfoField(
                    label: 'Email Address',
                    value: customer.email,
                    width: isWide ? 220 : null,
                  ),
                  _buildInfoField(
                    label: 'Phone Number',
                    value: customer.phoneNumber?.isNotEmpty == true
                        ? customer.phoneNumber!
                        : 'Not provided',
                    width: isWide ? 180 : null,
                  ),
                  _buildInfoField(
                    label: 'Registration Date',
                    value: _formatDate(customer.createdAt),
                    width: isWide ? 220 : null,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInfoField({
    required String label,
    required String value,
    Widget? trailing,
    double? width,
  }) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.secondaryText,
          ),
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.mainText,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ?trailing,
          ],
        ),
      ],
    );

    if (width != null) {
      return SizedBox(width: width, child: content);
    }
    return content;
  }

  Widget _buildMetricsSection(int orderCount, double totalSpent, double avgOrderValue) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth >= 600
            ? (constraints.maxWidth - 32) / 3
            : (constraints.maxWidth >= 380 ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth);

        return Wrap(
          spacing: 16,
          runSpacing: 12,
          children: [
            _buildMetricCard(
              title: 'Orders Placed',
              value: '$orderCount',
              icon: Icons.shopping_bag_outlined,
              iconColor: AppColors.luxuryWine,
              width: cardWidth,
            ),
            _buildMetricCard(
              title: 'Total Spent',
              value: '₹${totalSpent.toStringAsFixed(2)}',
              icon: Icons.payments_outlined,
              iconColor: const Color(0xFF2E7D32),
              width: cardWidth,
            ),
            _buildMetricCard(
              title: 'Average Order Value',
              value: '₹${avgOrderValue.toStringAsFixed(2)}',
              icon: Icons.trending_up_rounded,
              iconColor: AppColors.champagneGold,
              width: cardWidth,
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
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
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.mainText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShippingSection(String? address, List<OrderModel> orders) {
    final latestOrder = orders.isNotEmpty ? orders.first : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 16, color: AppColors.luxuryWine),
              const SizedBox(width: 6),
              const Text(
                'PRIMARY SHIPPING ADDRESS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.luxuryWine,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              if (latestOrder != null)
                Text(
                  'From order #${latestOrder.id}',
                  style: const TextStyle(fontSize: 11, color: AppColors.secondaryText),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (address != null && latestOrder != null) ...[
            Text(
              latestOrder.shippingName,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.mainText,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              address,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.mainText,
                height: 1.4,
              ),
            ),
            if (latestOrder.shippingPhone.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Contact: ${latestOrder.shippingPhone}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ] else ...[
            const Text(
              'No shipping address on file yet. Address information will be recorded automatically when an order is placed.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.secondaryText,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOrderHistorySection(List<OrderModel> orders) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'COMPLETE ORDER HISTORY',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.mainText,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.luxuryWine.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${orders.length}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.luxuryWine,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (orders.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
            ),
            child: const Column(
              children: [
                Icon(Icons.inventory_2_outlined, size: 36, color: AppColors.secondaryText),
                SizedBox(height: 8),
                Text(
                  'No orders placed by this customer yet',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
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
            itemCount: orders.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return _buildOrderItemCard(orders[index]);
            },
          ),
      ],
    );
  }

  Widget _buildOrderItemCard(OrderModel order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order Header
          Row(
            children: [
              Text(
                'Order #${order.id}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.mainText,
                ),
              ),
              const SizedBox(width: 8),
              _buildFulfillmentBadge(order.status),
              const SizedBox(width: 6),
              _buildPaymentBadge(order.paymentStatus),
              const Spacer(),
              Text(
                _formatDate(order.createdAt),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 12),

          // Items List
          ...order.items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: item.visualColor.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(item.visualIcon, size: 16, color: item.visualColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.productName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.mainText,
                          ),
                        ),
                        Text(
                          '${item.subtitle} • Size: ${item.size}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${item.quantity} × ₹${item.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '₹${item.totalPrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.mainText,
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 8),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 8),

          // Order Total Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Items: ${order.items.fold<int>(0, (sum, i) => sum + i.quantity)}',
                style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
              ),
              RichText(
                text: TextSpan(
                  text: 'Total: ',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.secondaryText,
                  ),
                  children: [
                    TextSpan(
                      text: '₹${order.total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: AppColors.luxuryWine,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFulfillmentBadge(OrderProgressStatus status) {
    Color bg;
    Color fg;
    switch (status) {
      case OrderProgressStatus.placed:
        bg = AppColors.champagneGold.withAlpha(30);
        fg = const Color(0xFF8A6D3B);
        break;
      case OrderProgressStatus.processing:
        bg = const Color(0xFF1976D2).withAlpha(25);
        fg = const Color(0xFF1976D2);
        break;
      case OrderProgressStatus.shipped:
        bg = const Color(0xFF7B1FA2).withAlpha(25);
        fg = const Color(0xFF7B1FA2);
        break;
      case OrderProgressStatus.outForDelivery:
        bg = const Color(0xFFE65100).withAlpha(25);
        fg = const Color(0xFFE65100);
        break;
      case OrderProgressStatus.delivered:
        bg = const Color(0xFF2E7D32).withAlpha(25);
        fg = const Color(0xFF2E7D32);
        break;
      case OrderProgressStatus.cancelled:
        bg = AppColors.error.withAlpha(25);
        fg = AppColors.error;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildPaymentBadge(String paymentStatus) {
    final isPaid = paymentStatus.toLowerCase() == 'paid';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isPaid ? const Color(0xFF2E7D32).withAlpha(20) : AppColors.error.withAlpha(20),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        paymentStatus,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isPaid ? const Color(0xFF2E7D32) : AppColors.error,
        ),
      ),
    );
  }

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

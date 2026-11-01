import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../controllers/home_controller.dart';
import '../../../controllers/order_controller.dart';
import '../../../core/constants/app_constants.dart';
import '../../../models/order_model.dart';
import '../../../core/routes/app_routes.dart';

/// Live Order Tracking Screen with visual timeline, courier details, and item recap.
class OrderTrackingView extends StatelessWidget {
  final OrderModel? order;

  const OrderTrackingView({super.key, this.order});

  @override
  Widget build(BuildContext context) {
    return Consumer<OrderController>(
      builder: (context, orderController, _) {
        final currentOrder = order ??
            orderController.currentTrackingOrder ??
            (orderController.hasOrders ? orderController.orders.first : null);

        if (currentOrder == null) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              backgroundColor: AppColors.background,
              title: const Text('Order Tracking'),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.receipt_long_outlined,
                      size: 64, color: AppColors.secondaryText),
                  const SizedBox(height: AppSpacing.md),
                  const Text(
                    'No active orders found',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.mainText,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ElevatedButton(
                    onPressed: () {
                      final home = context.read<HomeController>();
                      home.setBottomNavIndex(0);
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.luxuryWine,
                      foregroundColor: AppColors.white,
                    ),
                    child: const Text('Start Shopping'),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.background,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  final home = context.read<HomeController>();
                  home.setBottomNavIndex(0);
                  Navigator.of(context).pushReplacementNamed(AppRoutes.customerHome);
                }
              },
            ),
            title: const Text(
              'Order Tracking',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.mainText,
              ),
            ),
            actions: [
              if (orderController.orders.length > 1)
                IconButton(
                  icon: const Icon(Icons.history_rounded, color: AppColors.luxuryWine),
                  tooltip: 'Order History',
                  onPressed: () => _showOrderHistorySheet(context, orderController),
                ),
              IconButton(
                icon: const Icon(Icons.receipt_outlined, color: AppColors.luxuryWine),
                tooltip: 'Order Invoice',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Invoice for ${currentOrder.id} downloaded successfully!'),
                      backgroundColor: AppColors.luxuryWine,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ],
          ),
          body: RefreshIndicator(
            color: AppColors.luxuryWine,
            onRefresh: () => orderController.refreshOrders(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 1. Order Status Header Card ─────────────────────────────
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.luxuryWine, AppColors.luxuryWineDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.luxuryWine.withAlpha(80),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.white.withAlpha(30),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              currentOrder.id,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.white,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.champagneGold,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              currentOrder.status.label,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const Text(
                        'Estimated Delivery',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFE8D7D9),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        currentOrder.estimatedDelivery,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.white,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          const Icon(Icons.local_shipping_outlined,
                              size: 16, color: AppColors.champagneGold),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${currentOrder.courierName} • ${currentOrder.trackingNumber}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFFF0E4E6),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // ── 2. Interactive Status Advancement (Demo tool) ───────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Order Progress',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.mainText,
                      ),
                    ),
                    if (currentOrder.status != OrderProgressStatus.delivered &&
                        currentOrder.status != OrderProgressStatus.cancelled)
                      TextButton.icon(
                        icon: const Icon(Icons.fast_forward_rounded, size: 16),
                        label: const Text('Simulate Next Step'),
                        onPressed: () {
                          orderController.advanceOrderStatus(currentOrder.id);
                        },
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),

                // ── 3. Visual Timeline Stepper / Cancellation Notice ─────────
                if (currentOrder.status == OrderProgressStatus.cancelled)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.error.withAlpha(15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.error.withAlpha(60)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.cancel_rounded,
                            color: AppColors.error, size: 36),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Order Cancelled',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.error,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                currentOrder.cancelReason ??
                                    'This order has been cancelled by the fulfillment center.',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.secondaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Column(
                      children: [
                        _buildTimelineStep(
                          title: 'Order Confirmed',
                          subtitle:
                              'Your order has been verified and registered in our system.',
                          icon: Icons.check_circle_rounded,
                          isCompleted: currentOrder.status.stepIndex >= 0,
                          isActive:
                              currentOrder.status == OrderProgressStatus.placed,
                          isLast: false,
                        ),
                        _buildTimelineStep(
                          title: 'In Preparation & Luxury Packaging',
                          subtitle:
                              'Cosmetics are being carefully packaged in signature luxury boxing.',
                          icon: Icons.inventory_2_rounded,
                          isCompleted: currentOrder.status.stepIndex >= 1,
                          isActive: currentOrder.status ==
                              OrderProgressStatus.processing,
                          isLast: false,
                        ),
                        _buildTimelineStep(
                          title: 'Dispatched with Express Courier',
                          subtitle:
                              'Parcel in transit to your local distribution center.',
                          icon: Icons.local_shipping_rounded,
                          isCompleted: currentOrder.status.stepIndex >= 2,
                          isActive: currentOrder.status ==
                              OrderProgressStatus.shipped,
                          isLast: false,
                        ),
                        _buildTimelineStep(
                          title: 'Out for Delivery',
                          subtitle:
                              'Courier is on the way to your delivery address.',
                          icon: Icons.directions_bike_rounded,
                          isCompleted: currentOrder.status.stepIndex >= 3,
                          isActive: currentOrder.status ==
                              OrderProgressStatus.outForDelivery,
                          isLast: false,
                        ),
                        _buildTimelineStep(
                          title: 'Successfully Delivered',
                          subtitle:
                              'Package received. Enjoy your luxury beauty products!',
                          icon: Icons.celebration_rounded,
                          isCompleted: currentOrder.status.stepIndex >= 4,
                          isActive: currentOrder.status ==
                              OrderProgressStatus.delivered,
                          isLast: true,
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: AppSpacing.lg),

                // ── 4. Delivery Address & Contact Card ──────────────────────
                const Text(
                  'Delivery Details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
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
                  child: Column(
                    children: [
                      _buildDetailRow(
                        icon: Icons.person_outline,
                        label: 'Recipient',
                        value: currentOrder.shippingName,
                      ),
                      const Divider(height: 16),
                      _buildDetailRow(
                        icon: Icons.phone_outlined,
                        label: 'Phone',
                        value: currentOrder.shippingPhone,
                      ),
                      const Divider(height: 16),
                      _buildDetailRow(
                        icon: Icons.location_on_outlined,
                        label: 'Address',
                        value:
                            '${currentOrder.shippingAddress}, ${currentOrder.shippingCity} ${currentOrder.shippingPostalCode}',
                      ),
                      const Divider(height: 16),
                      _buildDetailRow(
                        icon: Icons.payment_outlined,
                        label: 'Payment',
                        value: currentOrder.paymentMethod,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // ── 5. Items in this Order ──────────────────────────────────
                const Text(
                  'Ordered Items',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
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
                  child: Column(
                    children: [
                      ...currentOrder.items.map((item) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: item.visualColor.withAlpha(30),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  item.visualIcon,
                                  color: item.visualColor,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.productName,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '${item.size} • Qty: ${item.quantity}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.secondaryText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '₹${item.totalPrice.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.luxuryWine,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Paid',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.bold)),
                          Text(
                            '₹${currentOrder.total.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.luxuryWine,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

                // ── 6. Bottom Actions ───────────────────────────────────────
                ElevatedButton.icon(
                  onPressed: () {
                    final home = context.read<HomeController>();
                    home.setBottomNavIndex(0);
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      AppRoutes.customerHome,
                      (route) => false,
                    );
                  },
                  icon: const Icon(Icons.shopping_bag_outlined),
                  label: const Text('Continue Shopping at ShopEase'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.luxuryWine,
                    foregroundColor: AppColors.white,
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        ),
      );
    },
    );
  }

  Widget _buildTimelineStep({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isCompleted,
    required bool isActive,
    required bool isLast,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stepper Icon + Line
        Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.luxuryWine
                    : isCompleted
                        ? const Color(0xFF2E7D32)
                        : AppColors.background,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isCompleted || isActive
                      ? Colors.transparent
                      : AppColors.divider,
                  width: 2,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: AppColors.luxuryWine.withAlpha(80),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                icon,
                size: 16,
                color: isCompleted || isActive
                    ? AppColors.white
                    : AppColors.secondaryText,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: isCompleted
                    ? const Color(0xFF2E7D32)
                    : AppColors.divider,
              ),
          ],
        ),
        const SizedBox(width: AppSpacing.md),

        // Text Info
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        isActive || isCompleted ? FontWeight.bold : FontWeight.w500,
                    color: isActive || isCompleted
                        ? AppColors.mainText
                        : AppColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.secondaryText,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.champagneGold),
        const SizedBox(width: AppSpacing.sm),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.secondaryText,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.mainText,
            ),
          ),
        ),
      ],
    );
  }

  void _showOrderHistorySheet(
    BuildContext context,
    OrderController orderController,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Your Orders History',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.mainText,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const Divider(),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: orderController.orders.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final o = orderController.orders[index];
                      final isSelected =
                          o.id == orderController.currentTrackingOrder?.id;

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              isSelected ? AppColors.luxuryWine : AppColors.background,
                          foregroundColor:
                              isSelected ? AppColors.white : AppColors.luxuryWine,
                          child: Icon(o.status.icon, size: 20),
                        ),
                        title: Text(
                          o.id,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          '${o.items.length} item(s) • ₹${o.total.toStringAsFixed(0)} • ${o.status.label}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle_rounded,
                                color: AppColors.luxuryWine, size: 20)
                            : const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                        onTap: () {
                          orderController.selectTrackingOrder(o);
                          Navigator.of(ctx).pop();
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

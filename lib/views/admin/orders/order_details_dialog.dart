import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../controllers/admin_order_controller.dart';
import '../../../core/constants/app_constants.dart';
import '../../../models/order_model.dart';

/// Comprehensive modal dialog for administrators to inspect order snapshots,
/// line items, customer details, and execute authorized fulfillment transitions.
class OrderDetailsDialog extends StatefulWidget {
  final OrderModel order;

  const OrderDetailsDialog({super.key, required this.order});

  static Future<void> show(BuildContext context, OrderModel order) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => OrderDetailsDialog(order: order),
    );
  }

  @override
  State<OrderDetailsDialog> createState() => _OrderDetailsDialogState();
}

class _OrderDetailsDialogState extends State<OrderDetailsDialog> {
  late OrderModel _currentOrder;
  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AdminOrderController>();
    // Synchronize if controller has fresher data for this order
    final fresh = controller.allOrders.where((o) => o.id == _currentOrder.id);
    if (fresh.isNotEmpty) {
      _currentOrder = fresh.first;
    }

    final isTerminal = _currentOrder.status == OrderProgressStatus.delivered ||
        _currentOrder.status == OrderProgressStatus.cancelled;

    final availableNextStatuses = OrderModel.availableTransitions(_currentOrder.status);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 760,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
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
            // ── Modal Header ───────────────────────────────────────────────
            _buildDialogHeader(context),
            const Divider(height: 1, color: AppColors.divider),

            // ── Scrollable Order Snapshot Body ─────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Error message banner if any
                    if (controller.errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        margin: const EdgeInsets.only(bottom: AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.error.withAlpha(20),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.error),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: AppColors.error, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                controller.errorMessage!,
                                style: const TextStyle(
                                  color: AppColors.error,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Top Status & Metadata Bar
                    _buildTopStatusBar(),
                    const SizedBox(height: AppSpacing.lg),

                    // Two-column Customer & Logistics Details
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isDesktop = constraints.maxWidth >= 600;
                        if (isDesktop) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _buildCustomerCard()),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(child: _buildLogisticsAndPaymentCard()),
                            ],
                          );
                        }
                        return Column(
                          children: [
                            _buildCustomerCard(),
                            const SizedBox(height: AppSpacing.md),
                            _buildLogisticsAndPaymentCard(),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // Line Items & Price Snapshot
                    _buildLineItemsSection(),

                    const SizedBox(height: AppSpacing.lg),

                    // Audit Trail & Status History
                    _buildAuditTrailSection(),
                  ],
                ),
              ),
            ),

            // ── Action Buttons Footer ──────────────────────────────────────
            const Divider(height: 1, color: AppColors.divider),
            _buildDialogFooter(context, controller, isTerminal, availableNextStatuses),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.champagneGold.withAlpha(30),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: AppColors.champagneGold,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    _currentOrder.id,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.mainText,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 14),
                    tooltip: 'Copy Order ID',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _currentOrder.id));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Order ID copied to clipboard'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
              ),
              Text(
                'Placed on ${_formatDateTime(_currentOrder.createdAt)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 22),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopStatusBar() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Fulfillment: ',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondaryText,
                ),
              ),
              _buildFulfillmentBadge(_currentOrder.status),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Payment: ',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondaryText,
                ),
              ),
              _buildPaymentStatusBadge(_currentOrder.paymentStatus),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Grand Total: ',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondaryText,
                ),
              ),
              Text(
                '₹${_currentOrder.total.toStringAsFixed(0)}',
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
    );
  }

  Widget _buildCustomerCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.person_outline, size: 18, color: AppColors.champagneGold),
              SizedBox(width: 8),
              Text(
                'Customer & Shipping',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.mainText,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildInfoRow('Name', _currentOrder.shippingName),
          _buildInfoRow('Phone', _currentOrder.shippingPhone),
          _buildInfoRow(
            'Address',
            '${_currentOrder.shippingAddress}, ${_currentOrder.shippingCity} - ${_currentOrder.shippingPostalCode}',
          ),
          if (_currentOrder.customerId != null)
            _buildInfoRow('Customer UID', _currentOrder.customerId!),
        ],
      ),
    );
  }

  Widget _buildLogisticsAndPaymentCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.local_shipping_outlined,
                  size: 18, color: AppColors.champagneGold),
              SizedBox(width: 8),
              Text(
                'Logistics & Payment',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.mainText,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildInfoRow('Courier', _currentOrder.courierName),
          _buildInfoRow('Tracking Code', _currentOrder.trackingNumber),
          _buildInfoRow('ETA', _currentOrder.estimatedDelivery),
          _buildInfoRow('Payment Method', _currentOrder.paymentMethod),
        ],
      ),
    );
  }

  Widget _buildLineItemsSection() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.inventory_2_outlined,
                      size: 18, color: AppColors.champagneGold),
                  SizedBox(width: 8),
                  Text(
                    'Purchased Items Snapshot',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.mainText,
                    ),
                  ),
                ],
              ),
              Text(
                '${_currentOrder.totalItemCount} item(s)',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.secondaryText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: AppSpacing.xs),

          // Items list
          ..._currentOrder.items.map((item) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: item.visualColor.withAlpha(30),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: item.visualColor.withAlpha(60),
                      ),
                    ),
                    child: Icon(
                      item.visualIcon,
                      size: 20,
                      color: item.visualColor,
                    ),
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${item.subtitle} • ${item.size}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '₹${item.price.toStringAsFixed(0)} × ${item.quantity}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '₹${item.totalPrice.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.mainText,
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: AppSpacing.sm),

          // Cost Breakdown
          _buildBreakdownRow('Subtotal', '₹${_currentOrder.subtotal.toStringAsFixed(0)}'),
          if (_currentOrder.discount > 0)
            _buildBreakdownRow(
              'Discount',
              '-₹${_currentOrder.discount.toStringAsFixed(0)}',
              isDiscount: true,
            ),
          _buildBreakdownRow(
            'Shipping',
            _currentOrder.shippingFee == 0
                ? 'FREE'
                : '₹${_currentOrder.shippingFee.toStringAsFixed(0)}',
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Final Total',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.mainText,
                ),
              ),
              Text(
                '₹${_currentOrder.total.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.luxuryWine,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAuditTrailSection() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.history_rounded, size: 18, color: AppColors.champagneGold),
              SizedBox(width: 8),
              Text(
                'Audit Trail & Fulfillment History',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.mainText,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Initial placement entry
          _buildAuditRow(
            status: OrderProgressStatus.placed,
            time: _currentOrder.createdAt,
            note: 'Order placed by customer via ${_currentOrder.paymentMethod}',
            updatedBy: _currentOrder.customerId ?? 'Customer',
          ),

          // Subsequent recorded history entries
          ..._currentOrder.statusHistory.map((h) {
            return _buildAuditRow(
              status: h.status,
              time: h.timestamp,
              note: h.note,
              updatedBy: h.updatedBy,
            );
          }),

          if (_currentOrder.status == OrderProgressStatus.cancelled &&
              _currentOrder.cancelReason != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.error.withAlpha(15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.error.withAlpha(50)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.error, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cancellation Reason: ${_currentOrder.cancelReason}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAuditRow({
    required OrderProgressStatus status,
    required DateTime time,
    String? note,
    String? updatedBy,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(status.icon, size: 14, color: AppColors.champagneGold),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      status.label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.mainText,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '• ${_formatDateTime(time)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
                if (note != null && note.isNotEmpty)
                  Text(
                    note,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.secondaryText,
                    ),
                  ),
                if (updatedBy != null && updatedBy.isNotEmpty)
                  Text(
                    'Attribution: $updatedBy',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.secondaryText.withAlpha(160),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogFooter(
    BuildContext context,
    AdminOrderController controller,
    bool isTerminal,
    List<OrderProgressStatus> availableNextStatuses,
  ) {
    if (isTerminal) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _currentOrder.status == OrderProgressStatus.delivered
                    ? const Color(0xFF2E7D32).withAlpha(20)
                    : AppColors.error.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _currentOrder.status == OrderProgressStatus.delivered
                        ? Icons.check_circle_rounded
                        : Icons.cancel_rounded,
                    size: 16,
                    color: _currentOrder.status == OrderProgressStatus.delivered
                        ? const Color(0xFF2E7D32)
                        : AppColors.error,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _currentOrder.status == OrderProgressStatus.delivered
                        ? 'Order Fulfilled & Closed'
                        : 'Order Cancelled (Terminal)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _currentOrder.status == OrderProgressStatus.delivered
                          ? const Color(0xFF2E7D32)
                          : AppColors.error,
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.center,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.luxuryWine,
                    foregroundColor: AppColors.white,
                    minimumSize: const Size(0, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final forwardStatuses =
        availableNextStatuses.where((s) => s != OrderProgressStatus.cancelled).toList();

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Consequential Cancel action (with confirmation)
          if (availableNextStatuses.contains(OrderProgressStatus.cancelled))
            Align(
              alignment: Alignment.center,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: OutlinedButton.icon(
                  onPressed: controller.isUpdating
                      ? null
                      : () => _showCancelConfirmation(context, controller),
                  icon: const Icon(Icons.cancel_outlined, size: 16),
                  label: const Text('Cancel Order'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    minimumSize: const Size(0, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ),

          // Forward fulfillment progression buttons
          ...forwardStatuses.map((next) {
            return Align(
              alignment: Alignment.center,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: ElevatedButton.icon(
                  onPressed: controller.isUpdating
                      ? null
                      : () async {
                          final success = await controller.updateOrderStatus(
                            _currentOrder,
                            next,
                            note: 'Fulfillment advanced to ${next.label}',
                          );
                          if (success && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Order ${_currentOrder.id} status updated to ${next.label}',
                                ),
                                backgroundColor: const Color(0xFF2E7D32),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                  icon: controller.isUpdating
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : Icon(next.icon, size: 16),
                  label: Text('Mark as ${next.label}'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.luxuryWine,
                    foregroundColor: AppColors.white,
                    minimumSize: const Size(0, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  void _showCancelConfirmation(
    BuildContext context,
    AdminOrderController controller,
  ) {
    _noteController.clear();
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.error),
              SizedBox(width: 8),
              Text(
                'Cancel Order?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to cancel order ${_currentOrder.id}? This action is consequential and cannot be reversed.',
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _noteController,
                decoration: InputDecoration(
                  labelText: 'Reason for cancellation (optional)',
                  hintText: 'e.g. Out of stock / Customer requested cancellation',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Keep Active'),
            ),
            Align(
              alignment: Alignment.center,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    final reason = _noteController.text.trim();
                    final success = await controller.updateOrderStatus(
                      _currentOrder,
                      OrderProgressStatus.cancelled,
                      note: reason.isNotEmpty ? reason : 'Cancelled by administrator',
                    );
                    if (success && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Order ${_currentOrder.id} has been cancelled.'),
                          backgroundColor: AppColors.error,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: AppColors.white,
                    minimumSize: const Size(0, 0),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  child: const Text('Confirm Cancellation'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.secondaryText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.mainText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(String label, String value, {bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.secondaryText,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDiscount ? const Color(0xFF2E7D32) : AppColors.mainText,
            ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 12, color: fg),
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

  Widget _buildPaymentStatusBadge(String status) {
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final m = months[dt.month - 1];
    final hr = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$m ${dt.day}, ${dt.year} at $hr:$min';
  }
}

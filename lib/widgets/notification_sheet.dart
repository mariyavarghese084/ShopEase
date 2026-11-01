import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/notification_controller.dart';
import '../core/constants/app_constants.dart';
import '../core/routes/app_routes.dart';
import '../models/notification_model.dart';

/// Luxury AÈRA notification sheet displaying real-time store updates,
/// order status progression, and store announcements.
class NotificationSheet extends StatelessWidget {
  const NotificationSheet({super.key});

  static Future<void> show(BuildContext context) {
    NotificationController? controller;
    try {
      controller = Provider.of<NotificationController>(context, listen: false);
    } catch (_) {
      controller = null;
    }

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        if (controller != null) {
          return ChangeNotifierProvider<NotificationController>.value(
            value: controller,
            child: const NotificationSheet(),
          );
        }
        return const NotificationSheet();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    NotificationController? controller;
    try {
      controller = context.watch<NotificationController>();
    } catch (_) {
      controller = null;
    }

    final notifications = controller?.notifications ?? const <AppNotificationModel>[];
    final isPermissionGranted = controller?.isPermissionGranted ?? true;
    final hasUnread = controller?.hasUnread ?? false;
    final unreadCount = controller?.unreadCount ?? 0;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.luxuryWine.withAlpha(20),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.notifications_active_outlined,
                        color: AppColors.luxuryWine,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Notifications',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.mainText,
                          ),
                        ),
                        Text(
                          hasUnread
                              ? '$unreadCount unread message(s)'
                              : 'All caught up',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (notifications.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () => controller?.markAllAsRead(),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.luxuryWine,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 0),
                        ),
                        child: const Text('Mark Read', style: TextStyle(fontSize: 12)),
                      ),
                      TextButton(
                        onPressed: () => controller?.clearAll(),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.secondaryText,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 0),
                        ),
                        child: const Text('Clear', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),

          // Permission banner if not yet authorized
          if (!isPermissionGranted)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.champagneGold.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.champagneGold.withAlpha(90),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.notifications_paused_outlined,
                    color: AppColors.champagneGold,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Enable Push Notifications',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.mainText,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Receive real-time order tracking and perfume restock alerts.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => controller?.requestPermission(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.luxuryWine,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      minimumSize: const Size(0, 32),
                      textStyle: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Enable'),
                  ),
                ],
              ),
            ),

          // Notifications list
          Expanded(
            child: notifications.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: notifications.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = notifications[index];
                      return _buildNotificationTile(context, item, controller);
                    },
                  ),
          ),

          // Open Full Notification Center footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushNamed(AppRoutes.customerNotifications);
                },
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('Open Notification Center'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.luxuryWine,
                  textStyle: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant.withAlpha(70),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 40,
                color: AppColors.secondaryText,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Notifications Yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.mainText,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Your parcel deliveries, price changes, and store announcements will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.secondaryText,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationTile(
    BuildContext context,
    AppNotificationModel item,
    NotificationController? controller,
  ) {
    final iconData = _iconForType(item.type);
    final iconColor = _colorForType(item.type);

    return InkWell(
      onTap: () {
        controller?.markAsRead(item.id);
        Navigator.of(context).pop();

        // Safe tap navigation without breaking routes
        if (item.targetRoute != null && item.targetRoute!.isNotEmpty) {
          Navigator.of(context).pushNamed(item.targetRoute!);
        } else if (item.type == 'order') {
          Navigator.of(context).pushNamed(AppRoutes.orderDetail);
        }
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: item.isRead
              ? AppColors.cardBackground
              : AppColors.luxuryWine.withAlpha(10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: item.isRead
                ? AppColors.divider
                : AppColors.luxuryWine.withAlpha(50),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(iconData, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: item.isRead
                                ? FontWeight.w600
                                : FontWeight.w800,
                            color: AppColors.mainText,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _formatTime(item.receivedAt),
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.body,
                    style: TextStyle(
                      fontSize: 12,
                      color: item.isRead
                          ? AppColors.secondaryText
                          : AppColors.mainText.withAlpha(220),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            if (!item.isRead) ...[
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 4),
                decoration: const BoxDecoration(
                  color: AppColors.luxuryWine,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type.toLowerCase()) {
      case 'order':
        return Icons.local_shipping_outlined;
      case 'promo':
        return Icons.local_offer_outlined;
      case 'account':
        return Icons.person_outline_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  Color _colorForType(String type) {
    switch (type.toLowerCase()) {
      case 'order':
        return const Color(0xFF1976D2);
      case 'promo':
        return AppColors.champagneGold;
      case 'account':
        return const Color(0xFF2E7D32);
      default:
        return AppColors.luxuryWine;
    }
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${time.day}/${time.month}';
  }
}


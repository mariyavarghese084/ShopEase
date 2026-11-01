import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../controllers/notification_controller.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/routes/app_routes.dart';
import '../../../models/notification_model.dart';

/// Full-page luxury customer notification center.
///
/// Features:
/// - Real-time notification feed with read/unread state tracking.
/// - Type filters (All, Unread, Orders, Promotions, Updates).
/// - Mark individual or all as read, clear history.
/// - Tap navigation to referenced products or order tracking.
/// - Responsive mobile, tablet, and desktop layout.
class CustomerNotificationCenterView extends StatefulWidget {
  const CustomerNotificationCenterView({super.key});

  @override
  State<CustomerNotificationCenterView> createState() =>
      _CustomerNotificationCenterViewState();
}

class _CustomerNotificationCenterViewState
    extends State<CustomerNotificationCenterView> {
  String _selectedFilter = 'All';

  final List<String> _filterTabs = [
    'All',
    'Unread',
    'Orders',
    'Promotions',
    'Announcements',
  ];

  @override
  Widget build(BuildContext context) {
    NotificationController? controller;
    try {
      controller = context.watch<NotificationController>();
    } catch (_) {
      controller = null;
    }

    final notifications = controller?.notifications ?? <AppNotificationModel>[];
    final unreadCount = controller?.unreadCount ?? 0;
    final isPermissionGranted = controller?.isPermissionGranted ?? true;

    final filtered = notifications.where((n) {
      if (_selectedFilter == 'Unread') return !n.isRead;
      if (_selectedFilter == 'Orders') return n.type == 'order';
      if (_selectedFilter == 'Promotions') {
        return n.type == 'promotion' || n.type == 'festival';
      }
      if (_selectedFilter == 'Announcements') {
        return n.type == 'general' || n.type == 'product' || n.type == 'update';
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          color: AppColors.mainText,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Row(
          children: [
            const Text(
              'Notification Center',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.mainText,
              ),
            ),
            if (unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.luxuryWine,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$unreadCount new',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (notifications.isNotEmpty) ...[
            TextButton(
              onPressed: () => controller?.markAllAsRead(),
              child: const Text(
                'Mark All Read',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.luxuryWine,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, size: 20),
              color: AppColors.secondaryText,
              tooltip: 'Clear All Notifications',
              onPressed: () => _confirmClearAll(context, controller),
            ),
            const SizedBox(width: 8),
          ],
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.divider),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            children: [
              // ── Permission Request Banner (if disabled) ─────────────────────
              if (!isPermissionGranted)
                _buildPermissionBanner(context, controller),

              // ── Filter Chips ────────────────────────────────────────────────
              _buildFilterChips(),

              // ── Notifications Feed ──────────────────────────────────────────
              Expanded(
                child: filtered.isEmpty
                    ? _buildEmptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          return _buildNotificationCard(
                            context,
                            item,
                            controller,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionBanner(
    BuildContext context,
    NotificationController? controller,
  ) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.champagneGold.withAlpha(25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.champagneGold.withAlpha(90)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.notifications_paused_outlined,
            color: AppColors.champagneGold,
            size: 24,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enable Push Alerts',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.mainText,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Stay updated on parcel deliveries and VIP fragrance drops.',
                  style: TextStyle(fontSize: 11, color: AppColors.secondaryText),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => controller?.requestPermission(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.luxuryWine,
              foregroundColor: AppColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              minimumSize: const Size(0, 32),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Enable', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _filterTabs.map((tab) {
            final isSelected = _selectedFilter == tab;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(tab),
                selected: isSelected,
                selectedColor: AppColors.luxuryWine.withAlpha(25),
                backgroundColor: AppColors.cardBackground,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? AppColors.luxuryWine : AppColors.secondaryText,
                ),
                side: BorderSide(
                  color: isSelected ? AppColors.luxuryWine : AppColors.divider,
                ),
                onSelected: (_) => setState(() => _selectedFilter = tab),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(
    BuildContext context,
    AppNotificationModel item,
    NotificationController? controller,
  ) {
    final typeColor = _colorForType(item.type);
    final typeIcon = _iconForType(item.type);

    return InkWell(
      onTap: () {
        controller?.markAsRead(item.id);
        _handleNavigation(context, item);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: item.isRead
              ? AppColors.cardBackground
              : AppColors.luxuryWine.withAlpha(8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: item.isRead
                ? AppColors.divider
                : AppColors.luxuryWine.withAlpha(60),
            width: item.isRead ? 1.0 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withAlpha(item.isRead ? 4 : 10),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: typeColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(typeIcon, color: typeColor, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: item.isRead
                                    ? FontWeight.w700
                                    : FontWeight.w900,
                                color: AppColors.mainText,
                              ),
                            ),
                          ),
                          if (!item.isRead) ...[
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.luxuryWine,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            _formatTimestamp(item.receivedAt),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.body,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.secondaryText,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (item.imageUrl != null && item.imageUrl!.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  item.imageUrl!,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ],
            if (item.targetRoute != null || item.type == 'order') ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    item.type == 'order' ? 'Track Order →' : 'View Details →',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.luxuryWine,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant.withAlpha(70),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 48,
                color: AppColors.secondaryText,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No Notifications',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.mainText,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Your parcel dispatch updates, flash promotions, and store announcements will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.secondaryText,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleNavigation(BuildContext context, AppNotificationModel item) {
    if (item.targetRoute != null && item.targetRoute!.isNotEmpty) {
      Navigator.of(context).pushNamed(item.targetRoute!);
    } else if (item.type == 'order') {
      Navigator.of(context).pushNamed(AppRoutes.orderDetail);
    }
  }

  void _confirmClearAll(
    BuildContext context,
    NotificationController? controller,
  ) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear All Notifications'),
        content: const Text(
          'Are you sure you want to clear your notification history?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              controller?.clearAll();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.luxuryWine,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  Color _colorForType(String type) {
    switch (type.toLowerCase()) {
      case 'promotion':
      case 'festival':
        return AppColors.champagneGold;
      case 'product':
        return AppColors.luxuryWine;
      case 'order':
        return AppColors.success;
      case 'update':
        return const Color(0xFF1976D2);
      default:
        return AppColors.luxuryWine;
    }
  }

  IconData _iconForType(String type) {
    switch (type.toLowerCase()) {
      case 'promotion':
        return Icons.local_offer_outlined;
      case 'festival':
        return Icons.celebration_outlined;
      case 'product':
        return Icons.auto_awesome_outlined;
      case 'order':
        return Icons.local_shipping_outlined;
      case 'update':
        return Icons.info_outline_rounded;
      default:
        return Icons.notifications_active_outlined;
    }
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

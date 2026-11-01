import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../controllers/admin_notification_controller.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/routes/app_routes.dart';
import '../../../models/notification_model.dart';
import '../admin_scaffold.dart';
import 'send_notification_dialog.dart';

/// Responsive administrative view for managing push notifications and in-app campaigns.
class AdminNotificationsView extends StatefulWidget {
  const AdminNotificationsView({super.key});

  @override
  State<AdminNotificationsView> createState() => _AdminNotificationsViewState();
}

class _AdminNotificationsViewState extends State<AdminNotificationsView> {
  String _searchQuery = '';
  String _selectedFilter = 'All';

  final List<String> _filters = [
    'All',
    'General',
    'Promotion',
    'Product',
    'Festival',
    'Update',
    'Order',
  ];

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AdminNotificationController>();
    final campaigns = controller.campaigns;
    final isLoading = controller.isLoading;

    final filtered = campaigns.where((c) {
      final matchesSearch = _searchQuery.isEmpty ||
          c.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.body.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (c.recipientName ?? '').toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesFilter = _selectedFilter == 'All' ||
          c.type.toLowerCase() == _selectedFilter.toLowerCase();

      return matchesSearch && matchesFilter;
    }).toList();

    return AdminScaffold(
      title: 'Notification Management',
      currentRoute: AppRoutes.adminNotifications,
      body: RefreshIndicator(
        color: AppColors.luxuryWine,
        onRefresh: () => controller.loadDashboardData(),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 1024;
            final isTablet = constraints.maxWidth >= 650 && constraints.maxWidth < 1024;
            final isMobile = constraints.maxWidth < 650;

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Action Bar / Header ─────────────────────────────────────
                  _buildHeader(context, isMobile, controller),
                  const SizedBox(height: 20),

                  // ── KPI Metrics Cards ───────────────────────────────────────
                  _buildKpiSection(controller, isDesktop, isTablet),
                  const SizedBox(height: 24),

                  // ── Search & Filter Bar ─────────────────────────────────────
                  _buildFilterBar(),
                  const SizedBox(height: 16),

                  // ── Campaign Activity Table / List ──────────────────────────
                  if (isLoading && campaigns.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(
                        child: CircularProgressIndicator(color: AppColors.luxuryWine),
                      ),
                    )
                  else if (filtered.isEmpty)
                    _buildEmptyState(context)
                  else
                    _buildCampaignList(filtered, controller, isMobile),
                  const SizedBox(height: 40),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    bool isMobile,
    AdminNotificationController controller,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Push Notifications & Announcements',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.mainText,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Broadcast messages, flash sales, and customer order alerts',
                style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
              ),
            ],
          ),
        ),
        ElevatedButton.icon(
          onPressed: () => SendNotificationDialog.show(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.luxuryWine,
            foregroundColor: AppColors.white,
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 20,
              vertical: 12,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text(
            isMobile ? 'Send' : 'Send Notification',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildKpiSection(
    AdminNotificationController controller,
    bool isDesktop,
    bool isTablet,
  ) {
    final total = controller.totalNotifications;
    final sent = controller.sentNotifications;
    final read = controller.readNotifications;
    final unread = controller.unreadNotifications;

    final kpis = [
      _KpiData(
        title: 'Total Campaigns',
        value: '$total',
        subtitle: 'All-time notifications',
        icon: Icons.campaign_rounded,
        color: AppColors.luxuryWine,
      ),
      _KpiData(
        title: 'Sent Notifications',
        value: '$sent',
        subtitle: 'Dispatched to audience',
        icon: Icons.mark_email_read_rounded,
        color: AppColors.success,
      ),
      _KpiData(
        title: 'Read Status',
        value: '$read',
        subtitle: 'Viewed by recipients',
        icon: Icons.drafts_outlined,
        color: AppColors.champagneGold,
      ),
      _KpiData(
        title: 'Unread Status',
        value: '$unread',
        subtitle: 'Pending customer view',
        icon: Icons.mark_email_unread_rounded,
        color: const Color(0xFF1976D2),
      ),
    ];

    if (isDesktop) {
      return Row(
        children: kpis.map((kpi) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: _buildKpiCard(kpi),
            ),
          );
        }).toList(),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: kpis.map((kpi) {
            final cardWidth = isTablet
                ? (constraints.maxWidth - 12) / 2
                : constraints.maxWidth;
            return SizedBox(
              width: cardWidth,
              child: _buildKpiCard(kpi),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildKpiCard(_KpiData data) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withAlpha(8),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: data.color.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(data.icon, color: data.color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  data.value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.mainText,
                  ),
                ),
                Text(
                  data.subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.secondaryText.withAlpha(180),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          onChanged: (val) => setState(() => _searchQuery = val),
          style: const TextStyle(fontSize: 13, color: AppColors.mainText),
          decoration: InputDecoration(
            hintText: 'Search notifications by title, body, or recipient...',
            hintStyle: const TextStyle(fontSize: 13, color: AppColors.secondaryText),
            prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.secondaryText),
            filled: true,
            fillColor: AppColors.cardBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.divider),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _filters.map((filter) {
              final isSelected = _selectedFilter == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(filter),
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
                  onSelected: (_) => setState(() => _selectedFilter = filter),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildCampaignList(
    List<AppNotificationModel> items,
    AdminNotificationController controller,
    bool isMobile,
  ) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = items[index];
        return _buildCampaignCard(context, item, controller, isMobile);
      },
    );
  }

  Widget _buildCampaignCard(
    BuildContext context,
    AppNotificationModel item,
    AdminNotificationController controller,
    bool isMobile,
  ) {
    final typeColor = _colorForType(item.type);
    final typeIcon = _iconForType(item.type);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withAlpha(6),
            blurRadius: 8,
            offset: const Offset(0, 2),
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
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: typeColor.withAlpha(25),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.type.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: typeColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant.withAlpha(80),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            item.audience == 'all'
                                ? 'All Customers (${item.totalRecipients})'
                                : (item.recipientName ?? 'Direct Customer'),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _formatDate(item.receivedAt),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.mainText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.body,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryText,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                color: AppColors.error.withAlpha(180),
                tooltip: 'Delete notification',
                onPressed: () => _confirmDelete(context, item.id, controller),
              ),
            ],
          ),
          if (item.targetRoute != null || item.imageUrl != null) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.divider),
            const SizedBox(height: 8),
            Row(
              children: [
                if (item.targetRoute != null) ...[
                  const Icon(Icons.touch_app_outlined, size: 14, color: AppColors.secondaryText),
                  const SizedBox(width: 4),
                  Text(
                    'Opens: ${item.targetRoute}${item.targetId != null ? " (${item.targetId})" : ""}',
                    style: const TextStyle(fontSize: 11, color: AppColors.secondaryText),
                  ),
                  const SizedBox(width: 14),
                ],
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.success.withAlpha(20),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 11, color: AppColors.success),
                      const SizedBox(width: 4),
                      Text(
                        item.deliveryStatus.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.luxuryWine.withAlpha(15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 48,
                color: AppColors.luxuryWine,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Notifications Found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.mainText,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Compose your first push notification or campaign announcement above.',
              style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => SendNotificationDialog.show(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.luxuryWine,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Compose Notification'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    String id,
    AdminNotificationController controller,
  ) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Notification'),
        content: const Text(
          'Are you sure you want to delete this notification record? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              controller.deleteNotification(id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Delete'),
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
        return Icons.receipt_long_outlined;
      case 'update':
        return Icons.system_update_alt_rounded;
      default:
        return Icons.campaign_rounded;
    }
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _KpiData {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _KpiData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

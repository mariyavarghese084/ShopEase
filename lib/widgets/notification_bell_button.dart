import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/notification_controller.dart';
import '../core/constants/app_constants.dart';
import 'notification_sheet.dart';

/// Reusable luxury notification bell button with dynamic unread badge.
class NotificationBellButton extends StatelessWidget {
  final Color? color;
  final double size;

  const NotificationBellButton({
    super.key,
    this.color,
    this.size = 22,
  });

  @override
  Widget build(BuildContext context) {
    NotificationController? controller;
    try {
      controller = context.watch<NotificationController>();
    } catch (_) {}

    final unread = controller?.unreadCount ?? 0;

    return IconButton(
      tooltip: unread > 0 ? '$unread Notifications' : 'Notifications',
      icon: Badge(
        isLabelVisible: unread > 0,
        backgroundColor: AppColors.luxuryWine,
        textColor: AppColors.white,
        label: Text(
          unread > 99 ? '99+' : '$unread',
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        child: Icon(
          unread > 0
              ? Icons.notifications_active_rounded
              : Icons.notifications_none_rounded,
          size: size,
          color: color ?? AppColors.mainText,
        ),
      ),
      onPressed: () => NotificationSheet.show(context),
    );
  }
}


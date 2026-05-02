import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../core/theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/notification_card.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _unreadOnly = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final notifications = _unreadOnly
            ? widget.controller.notifications
                  .where((item) => !item.read)
                  .toList()
            : widget.controller.notifications;

        return ListView(
          padding: EdgeInsets.zero,
          children: [
            AppHeader(
              title: 'الإشعارات',
              subtitle: 'تنبيهات الموافقات والتحصيل',
              trailing: IconButton(
                tooltip: 'تعيين الكل كمقروء',
                onPressed: widget.controller.markAllNotificationsRead,
                icon: const Icon(Icons.done_all, color: AppColors.white),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _ModeChip(
                    label: 'الكل',
                    selected: !_unreadOnly,
                    onTap: () => setState(() => _unreadOnly = false),
                  ),
                  const SizedBox(width: 8),
                  _ModeChip(
                    label: 'غير مقروء',
                    selected: _unreadOnly,
                    onTap: () => setState(() => _unreadOnly = true),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (notifications.isEmpty)
              const _EmptyNotifications()
            else
              ...notifications.map((notification) {
                return NotificationCard(
                  notification: notification,
                  onTap: () =>
                      widget.controller.markNotificationRead(notification.id),
                );
              }),
            const SizedBox(height: 90),
          ],
        );
      },
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.navy : AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.navy : AppColors.creamDark,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.white : AppColors.textBody,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 42),
      child: Column(
        children: [
          Icon(
            Icons.notifications_off_outlined,
            color: AppColors.textMuted,
            size: 50,
          ),
          SizedBox(height: 8),
          Text(
            'لا توجد إشعارات',
            style: TextStyle(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

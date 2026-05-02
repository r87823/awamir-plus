import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../core/permissions/access_control.dart';
import '../core/theme/app_theme.dart';
import '../models/app_models.dart';
import '../widgets/app_header.dart';
import '../core/utils/formatters.dart';
import '../widgets/order_card.dart';
import '../widgets/quick_action_card.dart';
import '../widgets/section_header.dart';
import '../widgets/stat_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    required this.onOpenFeature,
    required this.onLogout,
  });

  final AppController controller;
  final ValueChanged<AppFeature> onOpenFeature;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            AppHeader(
              title: 'مرحباً، ${controller.currentUser.fullName}',
              subtitle: controller.currentUser.branchName,
              notificationCount: controller.unreadNotifications,
              onNotificationTap: () => onOpenFeature(AppFeature.notifications),
            ),
            _UserInfoCard(controller: controller, onLogout: onLogout),
            Transform.translate(
              offset: const Offset(0, -6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.35,
                  children: _statsForRole(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.95,
                children: controller.homeFeatures.map((feature) {
                  final colors = _featureColors(feature);
                  return QuickActionCard(
                    icon: feature.icon,
                    label: feature.label,
                    iconBackground: colors.$1,
                    iconColor: colors.$2,
                    onTap: () => onOpenFeature(feature),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            if (controller.canAccess(AppFeature.branchOrders)) ...[
              SectionHeader(
                title: 'آخر الطلبات',
                actionLabel: 'عرض الكل',
                onAction: () => onOpenFeature(AppFeature.branchOrders),
              ),
              ...controller.orders
                  .take(3)
                  .map((order) => OrderCard(order: order, compact: true)),
            ] else ...[
              const SectionHeader(title: 'مهام الدور'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    boxShadow: AppShadows.soft,
                  ),
                  child: Text(
                    'تم تفعيل لوحة ${controller.currentUser.role.label} بالصلاحيات المناسبة.',
                    style: const TextStyle(
                      color: AppColors.textBody,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 90),
          ],
        );
      },
    );
  }

  (Color, Color) _featureColors(AppFeature feature) {
    switch (feature) {
      case AppFeature.createOrder:
      case AppFeature.branchApprovals:
      case AppFeature.settings:
        return (const Color(0xFFEDE7F6), const Color(0xFF5E35B1));
      case AppFeature.branchOrders:
      case AppFeature.receiveCashClosure:
      case AppFeature.deliveredOrders:
        return (const Color(0xFFE8F5E9), const Color(0xFF2E7D32));
      case AppFeature.dailyCashClosure:
      case AppFeature.payments:
      case AppFeature.paymentEntry:
        return (const Color(0xFFFFF8E1), AppColors.gold);
      case AppFeature.notifications:
      case AppFeature.cashDifferences:
        return (const Color(0xFFFFF3E0), const Color(0xFFE65100));
      case AppFeature.distribution:
      case AppFeature.drivers:
      case AppFeature.onTheWay:
      case AppFeature.assignedDeliveries:
        return (const Color(0xFFE3F2FD), const Color(0xFF1565C0));
      default:
        return (const Color(0xFFEDE7F6), AppColors.navy);
    }
  }

  List<Widget> _statsForRole() {
    switch (controller.currentUser.role) {
      case UserRole.branchEmployee:
      case UserRole.branchSupervisor:
      case UserRole.systemAdmin:
        return [
          StatCard(
            icon: Icons.assignment_outlined,
            value: '${controller.todayOrdersCount}',
            label: 'طلبات اليوم',
            iconBackground: const Color(0xFFEDE7F6),
            iconColor: const Color(0xFF5E35B1),
            onTap: controller.canAccess(AppFeature.branchOrders)
                ? () => onOpenFeature(AppFeature.branchOrders)
                : null,
          ),
          StatCard(
            icon: Icons.hourglass_bottom,
            value: '${controller.pendingOrdersCount}',
            label: 'بانتظار الموافقة',
            iconBackground: const Color(0xFFFFF3E0),
            iconColor: const Color(0xFFE65100),
            onTap: controller.canAccess(AppFeature.branchApprovals)
                ? () => onOpenFeature(AppFeature.branchApprovals)
                : controller.canAccess(AppFeature.branchOrders)
                ? () => onOpenFeature(AppFeature.branchOrders)
                : null,
          ),
          StatCard(
            icon: Icons.monetization_on_outlined,
            value: formatCurrency(4200, symbol: false),
            label: 'العربون المستلم',
            iconBackground: const Color(0xFFFFF8E1),
            iconColor: AppColors.gold,
            onTap: controller.canAccess(AppFeature.dailyCashClosure)
                ? () => onOpenFeature(AppFeature.dailyCashClosure)
                : null,
          ),
          StatCard(
            icon: Icons.local_shipping_outlined,
            value: '${controller.todayPickupCount}',
            label: 'للاستلام اليوم',
            iconBackground: const Color(0xFFE3F2FD),
            iconColor: const Color(0xFF1565C0),
            onTap: controller.canAccess(AppFeature.deliveredOrders)
                ? () => onOpenFeature(AppFeature.deliveredOrders)
                : null,
          ),
        ];
      case UserRole.distributionManager:
        return _roleStats([
          (Icons.route, '14', 'طلبات للتوزيع', AppFeature.distribution),
          (
            Icons.verified_outlined,
            '9',
            'طلبات معتمدة',
            AppFeature.approvedOrders,
          ),
          (
            Icons.local_shipping_outlined,
            '6',
            'سائقين متاحين',
            AppFeature.drivers,
          ),
          (
            Icons.notifications_none,
            '${controller.unreadNotifications}',
            'تنبيهات',
            AppFeature.notifications,
          ),
        ]);
      case UserRole.productionUser:
        return _roleStats([
          (
            Icons.precision_manufacturing,
            '11',
            'طلبات التصنيع',
            AppFeature.manufacturingOrders,
          ),
          (
            Icons.timelapse,
            '5',
            'قيد التنفيذ',
            AppFeature.productionInProgress,
          ),
          (
            Icons.inventory_2_outlined,
            '3',
            'جاهزة',
            AppFeature.readyForPickupDelivery,
          ),
          (
            Icons.check_circle_outline,
            '8',
            'منجزة اليوم',
            AppFeature.readyForPickupDelivery,
          ),
        ]);
      case UserRole.driver:
        return _roleStats([
          (
            Icons.assignment_ind_outlined,
            '6',
            'مسندة لي',
            AppFeature.assignedDeliveries,
          ),
          (Icons.near_me_outlined, '2', 'في الطريق', AppFeature.onTheWay),
          (Icons.done_all, '12', 'تم التسليم', AppFeature.deliveredOrders),
          (
            Icons.notifications_none,
            '${controller.unreadNotifications}',
            'تنبيهات',
            AppFeature.notifications,
          ),
        ]);
      case UserRole.cashier:
        return _roleStats([
          (
            Icons.account_balance_wallet_outlined,
            '8',
            'عهد الموظفين',
            AppFeature.employeeCashClosures,
          ),
          (
            Icons.check_circle_outline,
            '4',
            'بانتظار القبول',
            AppFeature.receiveCashClosure,
          ),
          (
            Icons.warning_amber_outlined,
            '1',
            'فروقات',
            AppFeature.cashDifferences,
          ),
          (
            Icons.payments_outlined,
            formatCurrency(controller.collectedDeposit, symbol: false),
            'إجمالي العهد',
            AppFeature.receiveCashClosure,
          ),
        ]);
      case UserRole.accountant:
        return _roleStats([
          (Icons.payments_outlined, '24', 'دفعات', AppFeature.payments),
          (Icons.receipt_long_outlined, '12', 'فواتير', AppFeature.invoices),
          (
            Icons.post_add_outlined,
            '7',
            'Payment Entry',
            AppFeature.paymentEntry,
          ),
          (
            Icons.account_balance_outlined,
            '3',
            'مراجعة مالية',
            AppFeature.payments,
          ),
        ]);
    }
  }

  List<Widget> _roleStats(List<(IconData, String, String, AppFeature)> stats) {
    const colors = [
      (Color(0xFFEDE7F6), Color(0xFF5E35B1)),
      (Color(0xFFE8F5E9), Color(0xFF2E7D32)),
      (Color(0xFFFFF3E0), Color(0xFFE65100)),
      (Color(0xFFE3F2FD), Color(0xFF1565C0)),
    ];

    return List.generate(stats.length, (index) {
      final stat = stats[index];
      final color = colors[index % colors.length];
      return StatCard(
        icon: stat.$1,
        value: stat.$2,
        label: stat.$3,
        iconBackground: color.$1,
        iconColor: color.$2,
        onTap: controller.canAccess(stat.$4)
            ? () => onOpenFeature(stat.$4)
            : null,
      );
    });
  }
}

class _UserInfoCard extends StatelessWidget {
  const _UserInfoCard({required this.controller, required this.onLogout});

  final AppController controller;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final user = controller.currentUser;
    return Transform.translate(
      offset: const Offset(0, -18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.12)),
            boxShadow: AppShadows.soft,
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.cream,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(Icons.badge_outlined, color: AppColors.navy),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${user.role.label} — ${user.branchName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'تسجيل خروج',
                onPressed: onLogout,
                icon: const Icon(Icons.logout, color: AppColors.red),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

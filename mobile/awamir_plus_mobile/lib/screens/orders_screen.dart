import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../core/permissions/access_control.dart';
import '../core/theme/app_theme.dart';
import '../models/app_models.dart';
import '../widgets/app_header.dart';
import '../widgets/order_card.dart';
import '../widgets/state_views.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({
    super.key,
    required this.controller,
    this.title = 'قائمة الطلبات',
    this.initialFilter,
  });

  final AppController controller;
  final String title;
  final OrderStatus? initialFilter;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  OrderStatus? _filter;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        if (!AccessControl.canViewBranchOrders(widget.controller.currentUser) &&
            !AccessControl.canApproveOrders(widget.controller.currentUser)) {
          return const AccessDeniedStateView();
        }

        final orders = _filter == null
            ? widget.controller.orders
            : widget.controller.orders
                  .where((order) => order.status == _filter)
                  .toList();
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            AppHeader(
              title: widget.title,
              subtitle: 'متابعة حالات طلبات الفرع',
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _FilterChip(
                    label: 'الكل',
                    count: widget.controller.orders.length,
                    selected: _filter == null,
                    onTap: () => setState(() => _filter = null),
                  ),
                  ...OrderStatus.values
                      .where((status) => status != OrderStatus.rejected)
                      .map((status) {
                        final count = widget.controller.orders
                            .where((order) => order.status == status)
                            .length;
                        return _FilterChip(
                          label: _shortLabel(status),
                          count: count,
                          selected: _filter == status,
                          onTap: () => setState(() => _filter = status),
                        );
                      }),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (orders.isEmpty)
              const _EmptyOrders()
            else
              ...orders.map((order) => OrderCard(order: order)),
            const SizedBox(height: 90),
          ],
        );
      },
    );
  }

  String _shortLabel(OrderStatus status) {
    switch (status) {
      case OrderStatus.draft:
        return 'مسودة';
      case OrderStatus.pendingSupervisorApproval:
        return 'موافقة';
      case OrderStatus.pending:
        return 'بانتظار';
      case OrderStatus.sentToDistribution:
        return 'للتوزيع';
      case OrderStatus.sentToProduction:
        return 'للتنفيذ';
      case OrderStatus.inProduction:
        return 'تنفيذ';
      case OrderStatus.productionCompleted:
        return 'مكتمل';
      case OrderStatus.readyForPickup:
        return 'استلام';
      case OrderStatus.readyForDelivery:
        return 'توصيل';
      case OrderStatus.assignedToDriver:
        return 'مسند';
      case OrderStatus.driverPickedUp:
        return 'استلمه';
      case OrderStatus.outForDelivery:
        return 'بالطريق';
      case OrderStatus.deliveryFailed:
        return 'تعذر';
      case OrderStatus.approved:
        return 'معتمد';
      case OrderStatus.returnedForEdit:
        return 'للتعديل';
      case OrderStatus.ready:
        return 'جاهز';
      case OrderStatus.delivered:
        return 'مسلّم';
      case OrderStatus.rejected:
        return 'مرفوض';
    }
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.navy : AppColors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.navy : AppColors.creamDark,
              width: 1.5,
            ),
          ),
          child: Text(
            '$label ($count)',
            style: TextStyle(
              color: selected ? AppColors.white : AppColors.textBody,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyOrders extends StatelessWidget {
  const _EmptyOrders();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Text(
          'لا توجد طلبات بهذا التصنيف',
          style: TextStyle(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

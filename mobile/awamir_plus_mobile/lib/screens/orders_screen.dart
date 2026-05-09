import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../core/permissions/access_control.dart';
import '../core/theme/app_theme.dart';
import '../models/app_models.dart';
import '../widgets/app_header.dart';
import '../widgets/order_card.dart';
import '../widgets/state_views.dart';
import 'edit_draft_order_screen.dart';
import 'order_detail_screen.dart';

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
              ...orders.map(_buildOrderCard),
            const SizedBox(height: 90),
          ],
        );
      },
    );
  }

  Widget _buildOrderCard(Order order) {
    final canSubmitDraft =
        order.status == OrderStatus.draft &&
        AccessControl.canCreateOrder(widget.controller.currentUser);
    final canEditDraft = canSubmitDraft;
    final isLoading = widget.controller.isActionLoading;
    return OrderCard(
      order: order,
      onTap: () => _openDetails(order),
      actions: [
        OutlinedButton(
          onPressed: () => _openDetails(order),
          child: const Text('التفاصيل'),
        ),
        if (canEditDraft)
          OutlinedButton(
            onPressed: isLoading ? null : () => _editDraft(order),
            child: const Text('تعديل'),
          ),
        if (canSubmitDraft)
          FilledButton(
            onPressed: isLoading ? null : () => _confirmSubmitDraft(order),
            child: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('إرسال'),
          ),
      ],
    );
  }

  void _openDetails(Order order) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => OrderDetailScreen(order: order)));
  }

  Future<void> _editDraft(Order order) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            EditDraftOrderScreen(controller: widget.controller, order: order),
      ),
    );
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _confirmSubmitDraft(Order order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إرسال المسودة'),
        content: Text('هل تريد إرسال الطلب ${order.id} للموافقة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('إرسال'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final result = await widget.controller.submitExistingDraftForApproval(
      order,
    );
    if (!mounted) return;
    final message = result == null
        ? widget.controller.actionErrorMessage ?? 'تعذر إرسال الطلب للموافقة'
        : 'تم إرسال الطلب للموافقة بنجاح';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
      case OrderStatus.cancelled:
        return 'ملغي';
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

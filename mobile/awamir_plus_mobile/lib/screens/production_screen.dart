import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../core/permissions/access_control.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../models/app_models.dart';
import '../widgets/app_header.dart';
import '../widgets/section_header.dart';
import '../widgets/state_views.dart';
import '../widgets/status_badge.dart';

class ProductionScreen extends StatelessWidget {
  const ProductionScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    if (!AccessControl.canViewProductionOrders(controller.currentUser)) {
      return const AccessDeniedStateView();
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final orders = controller.productionOrders;
        return RefreshIndicator(
          onRefresh: controller.loadProductionOrders,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              AppHeader(
                title: 'طلبات الإنتاج',
                subtitle:
                    AccessControl.hasPermission(
                      controller.currentUser,
                      AppPermission.systemFullAccess,
                    )
                    ? 'كل جهات التنفيذ'
                    : controller.currentUser.branchName,
                notificationCount: controller.unreadNotifications,
              ),
              const SizedBox(height: 14),
              const SectionHeader(title: 'طلبات جهة التنفيذ'),
              if (controller.isActionLoading && orders.isEmpty)
                const SizedBox(height: 280, child: LoadingStateView())
              else if (orders.isEmpty)
                const SizedBox(
                  height: 280,
                  child: EmptyStateView(
                    message: 'لا توجد طلبات إنتاج حالياً',
                    icon: Icons.precision_manufacturing_outlined,
                  ),
                )
              else
                ...orders.map(
                  (order) => _ProductionOrderCard(
                    order: order,
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ProductionOrderDetailScreen(
                            controller: controller,
                            order: order,
                          ),
                        ),
                      );
                      await controller.loadProductionOrders();
                    },
                  ),
                ),
              const SizedBox(height: 90),
            ],
          ),
        );
      },
    );
  }
}

class ProductionOrderDetailScreen extends StatefulWidget {
  const ProductionOrderDetailScreen({
    super.key,
    required this.controller,
    required this.order,
  });

  final AppController controller;
  final Order order;

  @override
  State<ProductionOrderDetailScreen> createState() =>
      _ProductionOrderDetailScreenState();
}

class _ProductionOrderDetailScreenState
    extends State<ProductionOrderDetailScreen> {
  late Order _order = widget.order;
  late List<DepartmentWorkOrder> _workOrders = List.of(
    widget.order.departmentWorkOrders,
  );
  late Future<List<OrderStatusLog>> _logsFuture = widget.controller
      .getOrderStatusLogs(_order.id);

  @override
  Widget build(BuildContext context) {
    if (!AccessControl.canUpdateProductionStatus(
      widget.controller.currentUser,
    )) {
      return const Scaffold(body: AccessDeniedStateView());
    }

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          AppHeader(
            title: _order.id,
            subtitle: _order.productionDepartmentName.isEmpty
                ? 'تفاصيل الإنتاج'
                : _order.productionDepartmentName,
            showBack: true,
            onBack: () => Navigator.maybePop(context),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Column(
              children: [
                _OrderHeader(order: _order),
                const SizedBox(height: 12),
                _InfoSection(
                  title: 'بيانات الطلب',
                  rows: [
                    ('العميل', _order.customer),
                    ('المنتجات', _order.productSummary),
                    ('جهة التنفيذ', _order.productionDepartmentName),
                    ('تاريخ الاستلام', _order.pickupDateText),
                    ('وقت الاستلام', _order.pickupTimeText),
                    ('طريقة التسليم', _order.fulfillmentType.label),
                    ('فرع / عنوان', _order.fulfillmentSummary),
                    ('تفاصيل الطلب', _order.details),
                    (
                      'حالة الدفع',
                      _order.remainingAmount <= 0
                          ? 'مسدد'
                          : 'متبقي ${formatCurrency(_order.remainingAmount)}',
                    ),
                  ],
                ),
                _ProductsSection(order: _order),
                _DepartmentWorkOrdersSection(
                  workOrders: _workOrders,
                  onStatus: _updateWorkOrderStatus,
                ),
                _AttachmentsSection(order: _order),
                _StatusLogSection(logsFuture: _logsFuture),
                _ProductionActions(order: _order, onStatus: _updateStatus),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStatus(OrderStatus status) async {
    final updated = await widget.controller.updateProductionStatus(
      orderId: _order.id,
      status: status,
    );
    if (!mounted) return;
    if (updated == null) {
      final error = widget.controller.actionErrorMessage;
      if (error != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
      }
      return;
    }

    setState(() {
      _order = updated;
      _logsFuture = widget.controller.getOrderStatusLogs(_order.id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم تحديث الحالة إلى ${status.label}')),
    );
  }

  Future<void> _updateWorkOrderStatus(
    DepartmentWorkOrder workOrder,
    DepartmentWorkOrderStatus status,
  ) async {
    final updated = await widget.controller.updateWorkOrderStatus(
      workOrderId: workOrder.id,
      status: status,
    );
    if (!mounted) return;
    if (updated == null) {
      final error = widget.controller.actionErrorMessage;
      if (error != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
      }
      return;
    }

    setState(() {
      final index = _workOrders.indexWhere((item) => item.id == updated.id);
      if (index == -1) {
        _workOrders = [updated, ..._workOrders];
      } else {
        _workOrders[index] = updated;
      }
      _logsFuture = widget.controller.getOrderStatusLogs(_order.id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم تحديث أمر العمل إلى ${status.label}')),
    );
  }
}

class _ProductionOrderCard extends StatelessWidget {
  const _ProductionOrderCard({required this.order, required this.onTap});

  final Order order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final quantity = order.lineItems.fold<int>(
      0,
      (total, line) => total + line.quantity,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: AppShadows.soft,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        order.id,
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    StatusBadge(status: order.status),
                  ],
                ),
                const SizedBox(height: 10),
                _CompactRow(label: 'العميل', value: order.customer),
                _CompactRow(label: 'المنتج', value: order.productSummary),
                _CompactRow(label: 'الكمية', value: quantity.toString()),
                _CompactRow(
                  label: 'مرفقات',
                  value: order.attachments.isEmpty ? 'لا توجد' : 'يوجد',
                ),
                _CompactRow(
                  label: 'الاستلام',
                  value:
                      '${order.pickupDateText}${order.pickupTimeText.isEmpty ? '' : ' — ${order.pickupTimeText}'}',
                ),
                _CompactRow(
                  label: 'التسليم',
                  value: order.fulfillmentType.label,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductionActions extends StatelessWidget {
  const _ProductionActions({required this.order, required this.onStatus});

  final Order order;
  final ValueChanged<OrderStatus> onStatus;

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[];
    if (order.status == OrderStatus.sentToProduction) {
      actions.add(
        ElevatedButton.icon(
          onPressed: () => onStatus(OrderStatus.inProduction),
          icon: const Icon(Icons.play_arrow),
          label: const Text('بدء التنفيذ'),
        ),
      );
    }
    if (order.status == OrderStatus.inProduction) {
      actions.add(
        ElevatedButton.icon(
          onPressed: () => onStatus(OrderStatus.productionCompleted),
          icon: const Icon(Icons.task_alt),
          label: const Text('مكتمل'),
        ),
      );
    }
    if (order.status == OrderStatus.productionCompleted) {
      actions.add(
        ElevatedButton.icon(
          onPressed: () => onStatus(
            order.fulfillmentType == FulfillmentType.branchPickup
                ? OrderStatus.readyForPickup
                : OrderStatus.readyForDelivery,
          ),
          icon: Icon(
            order.fulfillmentType == FulfillmentType.branchPickup
                ? Icons.storefront
                : Icons.delivery_dining,
          ),
          label: Text(
            order.fulfillmentType == FulfillmentType.branchPickup
                ? 'جاهز للاستلام'
                : 'جاهز للتوصيل',
          ),
        ),
      );
    }

    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }
    return _SectionShell(
      title: 'تحديث حالة الإنتاج',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: actions,
      ),
    );
  }
}

class _OrderHeader extends StatelessWidget {
  const _OrderHeader({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              order.customer,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          StatusBadge(status: order.status),
        ],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.title, required this.rows});

  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      title: title,
      child: Column(
        children: rows.map((row) {
          return _CompactRow(label: row.$1, value: row.$2);
        }).toList(),
      ),
    );
  }
}

class _ProductsSection extends StatelessWidget {
  const _ProductsSection({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      title: 'المنتجات',
      child: order.lineItems.isEmpty
          ? _CompactRow(label: 'المنتجات', value: order.productSummary)
          : Column(
              children: order.lineItems.map((line) {
                return _CompactRow(
                  label: '${line.product.name} × ${line.quantity}',
                  value: formatCurrency(line.subtotal),
                );
              }).toList(),
            ),
    );
  }
}

class _AttachmentsSection extends StatelessWidget {
  const _AttachmentsSection({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      title: 'المرفقات',
      child: order.attachments.isEmpty
          ? const Text(
              'لا توجد مرفقات',
              style: TextStyle(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700,
              ),
            )
          : Column(
              children: order.attachments.map((attachment) {
                return _CompactRow(
                  label: attachment.type.label,
                  value: attachment.name,
                );
              }).toList(),
            ),
    );
  }
}

class _DepartmentWorkOrdersSection extends StatelessWidget {
  const _DepartmentWorkOrdersSection({
    required this.workOrders,
    required this.onStatus,
  });

  final List<DepartmentWorkOrder> workOrders;
  final void Function(DepartmentWorkOrder, DepartmentWorkOrderStatus) onStatus;

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      title: 'أوامر عمل الأقسام',
      child: workOrders.isEmpty
          ? const Text(
              'لا توجد أوامر عمل أقسام لهذا الطلب',
              style: TextStyle(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700,
              ),
            )
          : Column(
              children: workOrders.map((workOrder) {
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.cream,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              workOrder.departmentName,
                              style: const TextStyle(
                                color: AppColors.navy,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          _WorkOrderStatusPill(status: workOrder.status),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _CompactRow(label: 'رقم الأمر', value: workOrder.id),
                      _CompactRow(
                        label: 'الأصناف',
                        value: workOrder.items.isEmpty
                            ? '-'
                            : workOrder.items
                                  .map(
                                    (item) => '${item.itemName} × ${item.qty}',
                                  )
                                  .join('، '),
                      ),
                      if (workOrder.delayReason.isNotEmpty)
                        _CompactRow(
                          label: 'سبب التأخير',
                          value: workOrder.delayReason,
                        ),
                      if (workOrder.rejectionReason.isNotEmpty)
                        _CompactRow(
                          label: 'سبب الرفض',
                          value: workOrder.rejectionReason,
                        ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _actionsFor(workOrder).map((action) {
                          return OutlinedButton.icon(
                            onPressed: () => onStatus(workOrder, action.status),
                            icon: Icon(action.icon, size: 18),
                            label: Text(action.label),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  List<_WorkOrderAction> _actionsFor(DepartmentWorkOrder workOrder) {
    switch (workOrder.status) {
      case DepartmentWorkOrderStatus.pending:
        return const [
          _WorkOrderAction(
            label: 'قبول',
            status: DepartmentWorkOrderStatus.accepted,
            icon: Icons.check_circle_outline,
          ),
        ];
      case DepartmentWorkOrderStatus.accepted:
        return const [
          _WorkOrderAction(
            label: 'بدء التنفيذ',
            status: DepartmentWorkOrderStatus.inProduction,
            icon: Icons.play_arrow,
          ),
        ];
      case DepartmentWorkOrderStatus.inProduction:
      case DepartmentWorkOrderStatus.delayed:
        return const [
          _WorkOrderAction(
            label: 'جاهز',
            status: DepartmentWorkOrderStatus.ready,
            icon: Icons.task_alt,
          ),
        ];
      case DepartmentWorkOrderStatus.ready:
      case DepartmentWorkOrderStatus.rejected:
      case DepartmentWorkOrderStatus.cancelled:
        return const [];
    }
  }
}

class _WorkOrderAction {
  const _WorkOrderAction({
    required this.label,
    required this.status,
    required this.icon,
  });

  final String label;
  final DepartmentWorkOrderStatus status;
  final IconData icon;
}

class _WorkOrderStatusPill extends StatelessWidget {
  const _WorkOrderStatusPill({required this.status});

  final DepartmentWorkOrderStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.goldLight,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: const TextStyle(
          color: AppColors.navy,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _StatusLogSection extends StatelessWidget {
  const _StatusLogSection({required this.logsFuture});

  final Future<List<OrderStatusLog>> logsFuture;

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      title: 'سجل الحالات',
      child: FutureBuilder<List<OrderStatusLog>>(
        future: logsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LinearProgressIndicator(color: AppColors.gold);
          }
          final logs = snapshot.data ?? const [];
          if (logs.isEmpty) {
            return const Text(
              'لا يوجد سجل حالات بعد',
              style: TextStyle(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700,
              ),
            );
          }
          return Column(
            children: logs.map((log) {
              return _CompactRow(
                label: log.newStatus.label,
                value:
                    '${log.changedByName} • ${formatDate(log.changedAt)} ${formatTime(TimeOfDay.fromDateTime(log.changedAt))}${log.notes.isEmpty ? '' : ' • ${log.notes}'}',
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _SectionShell extends StatelessWidget {
  const _SectionShell({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _CompactRow extends StatelessWidget {
  const _CompactRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value.trim().isEmpty ? '-' : value,
              style: const TextStyle(
                color: AppColors.navy,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

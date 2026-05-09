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

enum _DistributionFilter { distribution, readyDelivery, assignedDriver }

extension _DistributionFilterDetails on _DistributionFilter {
  String get label {
    switch (this) {
      case _DistributionFilter.distribution:
        return 'جاهز للتوزيع';
      case _DistributionFilter.readyDelivery:
        return 'جاهز للتوصيل';
      case _DistributionFilter.assignedDriver:
        return 'مسند للسائق';
    }
  }
}

class DistributionScreen extends StatefulWidget {
  const DistributionScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<DistributionScreen> createState() => _DistributionScreenState();
}

class _DistributionScreenState extends State<DistributionScreen> {
  _DistributionFilter _filter = _DistributionFilter.distribution;

  @override
  Widget build(BuildContext context) {
    if (!AccessControl.canViewDistribution(widget.controller.currentUser)) {
      return const AccessDeniedStateView();
    }

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final orders = widget.controller.distributionOrders
            .where(_matchesFilter)
            .toList();
        return RefreshIndicator(
          onRefresh: widget.controller.loadDistributionOrders,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              AppHeader(
                title: 'التوزيع',
                subtitle: 'تحويل الطلبات للتنفيذ وإسناد التوصيل للسائقين',
                notificationCount: widget.controller.unreadNotifications,
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _DistributionFilter.values.map((filter) {
                    final selected = _filter == filter;
                    final count = widget.controller.distributionOrders
                        .where((order) => _matchesFilterFor(order, filter))
                        .length;
                    return ChoiceChip(
                      label: Text('${filter.label} ($count)'),
                      selected: selected,
                      onSelected: (_) => setState(() => _filter = filter),
                      selectedColor: AppColors.goldLight,
                      labelStyle: TextStyle(
                        color: selected ? AppColors.navy : AppColors.textMuted,
                        fontWeight: FontWeight.w900,
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 14),
              if (_filter == _DistributionFilter.readyDelivery ||
                  _filter == _DistributionFilter.assignedDriver) ...[
                _DeliveryBatchesSection(
                  batches: widget.controller.deliveryBatches,
                  isLoading: widget.controller.isActionLoading,
                  onCreate: _createDeliveryBatches,
                  onAssign: _assignDeliveryBatch,
                ),
                const SizedBox(height: 6),
              ],
              SectionHeader(title: _filter.label),
              if (widget.controller.isActionLoading && orders.isEmpty)
                const SizedBox(height: 280, child: LoadingStateView())
              else if (orders.isEmpty)
                SizedBox(
                  height: 280,
                  child: EmptyStateView(
                    message: 'لا توجد طلبات في ${_filter.label}',
                    icon: Icons.local_shipping_outlined,
                  ),
                )
              else
                ...orders.map(
                  (order) => _DistributionOrderCard(
                    order: order,
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => DistributionOrderDetailScreen(
                            controller: widget.controller,
                            order: order,
                          ),
                        ),
                      );
                      await widget.controller.loadDistributionOrders();
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

  bool _matchesFilter(Order order) => _matchesFilterFor(order, _filter);

  bool _matchesFilterFor(Order order, _DistributionFilter filter) {
    switch (filter) {
      case _DistributionFilter.distribution:
        return order.status == OrderStatus.sentToDistribution;
      case _DistributionFilter.readyDelivery:
        return order.status == OrderStatus.readyForDelivery ||
            order.status == OrderStatus.deliveryFailed;
      case _DistributionFilter.assignedDriver:
        return order.status == OrderStatus.assignedToDriver ||
            order.status == OrderStatus.driverPickedUp ||
            order.status == OrderStatus.outForDelivery;
    }
  }

  Future<void> _createDeliveryBatches() async {
    final batches = await widget.controller.createDeliveryBatches();
    if (!mounted) return;
    if (batches == null) {
      final error = widget.controller.actionErrorMessage;
      if (error != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
      }
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          batches.isEmpty
              ? 'لا توجد طلبات جاهزة لإنشاء دفعات توصيل'
              : 'تم تجهيز ${batches.length} دفعة توصيل',
        ),
      ),
    );
  }

  Future<void> _assignDeliveryBatch(DeliveryBatch batch) async {
    final driver = await showDialog<DriverProfile>(
      context: context,
      builder: (_) => _DriverPickerDialog(
        driversFuture: widget.controller.getAvailableDrivers(
          branchId: batch.destinationBranch,
        ),
      ),
    );
    if (driver == null) return;
    if (!mounted) return;

    final updated = await widget.controller.assignDeliveryBatch(
      batchId: batch.id,
      driverId: driver.id,
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم إسناد دفعة التوصيل للسائق')),
    );
  }
}

class _DeliveryBatchesSection extends StatelessWidget {
  const _DeliveryBatchesSection({
    required this.batches,
    required this.isLoading,
    required this.onCreate,
    required this.onAssign,
  });

  final List<DeliveryBatch> batches;
  final bool isLoading;
  final VoidCallback onCreate;
  final ValueChanged<DeliveryBatch> onAssign;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: _SectionShell(
        title: 'دفعات التوصيل',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              onPressed: isLoading ? null : onCreate,
              icon: const Icon(Icons.playlist_add_check),
              label: const Text('تجهيز دفعات من الطلبات الجاهزة'),
            ),
            const SizedBox(height: 10),
            if (batches.isEmpty)
              const Text(
                'لا توجد دفعات توصيل مجهزة حالياً',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              )
            else
              ...batches.take(5).map((batch) {
                final canAssign =
                    batch.status == DeliveryBatchStatus.pending ||
                    batch.status == DeliveryBatchStatus.draft;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
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
                              batch.batchNumber,
                              style: const TextStyle(
                                color: AppColors.navy,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          _DeliveryBatchPill(status: batch.status),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _CompactRow(
                        label: 'الوجهة',
                        value: batch.destinationBranch,
                      ),
                      _CompactRow(
                        label: 'الطلبات',
                        value: batch.orders.length.toString(),
                      ),
                      _CompactRow(label: 'السائق', value: batch.driverName),
                      if (canAssign) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: ElevatedButton.icon(
                            onPressed: () => onAssign(batch),
                            icon: const Icon(Icons.assignment_ind_outlined),
                            label: const Text('إسناد الدفعة'),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _DeliveryBatchPill extends StatelessWidget {
  const _DeliveryBatchPill({required this.status});

  final DeliveryBatchStatus status;

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

class DistributionOrderDetailScreen extends StatefulWidget {
  const DistributionOrderDetailScreen({
    super.key,
    required this.controller,
    required this.order,
  });

  final AppController controller;
  final Order order;

  @override
  State<DistributionOrderDetailScreen> createState() =>
      _DistributionOrderDetailScreenState();
}

class _DistributionOrderDetailScreenState
    extends State<DistributionOrderDetailScreen> {
  late Order _order = widget.order;
  ProductionDepartment? _selectedDepartment;
  late Future<List<OrderStatusLog>> _logsFuture = widget.controller
      .getOrderStatusLogs(_order.id);

  @override
  void initState() {
    super.initState();
    _loadDefaultDepartment();
  }

  @override
  Widget build(BuildContext context) {
    if (!AccessControl.canAssignProductionDepartment(
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
            subtitle: 'تفاصيل التوزيع',
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
                    ('الجوال', _order.customerPhone),
                    ('القسم', _order.categoryName),
                    ('المنتجات', _order.productSummary),
                    ('الأولوية', _order.priority.label),
                    ('تاريخ الاستلام', _order.pickupDateText),
                    ('وقت الاستلام', _order.pickupTimeText),
                    ('طريقة التسليم', _order.fulfillmentType.label),
                    ('الفرع / العنوان', _order.fulfillmentSummary),
                    ('تفاصيل الطلب', _order.details),
                  ],
                ),
                _ProductsSection(order: _order),
                _InfoSection(
                  title: 'الدفع',
                  rows: [
                    ('الإجمالي', formatCurrency(_order.amount)),
                    ('العربون', formatCurrency(_order.depositAmount)),
                    ('المتبقي', formatCurrency(_order.remainingAmount)),
                    ('طريقة الدفع', _order.paymentMethod.label),
                  ],
                ),
                _AttachmentsSection(order: _order),
                _StatusLogSection(logsFuture: _logsFuture),
                if (_order.status == OrderStatus.sentToDistribution) ...[
                  _ProductionDepartmentSelector(
                    departments: widget.controller.productionDepartments,
                    selected: _selectedDepartment,
                    onChanged: (department) =>
                        setState(() => _selectedDepartment = department),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _assign,
                    icon: const Icon(Icons.precision_manufacturing_outlined),
                    label: const Text('تحويل للتنفيذ'),
                  ),
                ] else if (_order.status == OrderStatus.readyForDelivery ||
                    _order.status == OrderStatus.deliveryFailed) ...[
                  _DeliveryBatchActionSection(
                    order: _order,
                    onCreateBatch: _createDeliveryBatchForOrder,
                  ),
                ] else ...[
                  _SectionShell(
                    title: 'السائق',
                    child: _CompactRow(
                      label: 'السائق المسند',
                      value: _order.assignedDriverName,
                    ),
                  ),
                ],
                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadDefaultDepartment() async {
    final department = await widget.controller.getDefaultDepartmentForOrder(
      _order,
    );
    if (!mounted) return;
    setState(() => _selectedDepartment = department);
  }

  Future<void> _assign() async {
    final department = _selectedDepartment;
    if (department == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('يجب اختيار جهة تنفيذ')));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('تأكيد التحويل'),
          content: Text(
            'سيتم تحويل الطلب ${_order.id} إلى ${department.name}.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('تحويل'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    final updated = await widget.controller.assignProductionDepartment(
      orderId: _order.id,
      productionDepartmentId: department.id,
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
      const SnackBar(content: Text('تم تحويل الطلب للتنفيذ بنجاح')),
    );
  }

  Future<void> _createDeliveryBatchForOrder() async {
    final branchId = _order.pickupBranchId.isNotEmpty
        ? _order.pickupBranchId
        : _order.pickupBranch;
    final batches = await widget.controller.createDeliveryBatches(
      branchId: branchId.isEmpty ? null : branchId,
    );
    if (!mounted) return;
    if (batches == null) {
      final error = widget.controller.actionErrorMessage;
      if (error != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
      }
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          batches.isEmpty
              ? 'لا توجد طلبات جاهزة لإنشاء دفعة توصيل'
              : 'تم تجهيز دفعة التوصيل، يمكن إسنادها من قائمة دفعات التوصيل',
        ),
      ),
    );
  }
}

class _DistributionOrderCard extends StatelessWidget {
  const _DistributionOrderCard({required this.order, required this.onTap});

  final Order order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
                _CompactRow(label: 'الجوال', value: order.customerPhone),
                _CompactRow(label: 'المنتجات', value: order.productSummary),
                _CompactRow(label: 'القسم', value: order.categoryName),
                _CompactRow(
                  label: 'الاستلام',
                  value:
                      '${order.pickupDateText}${order.pickupTimeText.isEmpty ? '' : ' — ${order.pickupTimeText}'}',
                ),
                _CompactRow(
                  label: 'الطريقة',
                  value: order.fulfillmentType.label,
                ),
                _CompactRow(
                  label: 'فرع/عنوان',
                  value: order.fulfillmentSummary,
                ),
                _CompactRow(
                  label: 'الإجمالي',
                  value: formatCurrency(order.amount),
                ),
                _CompactRow(
                  label: 'العربون',
                  value: formatCurrency(order.depositAmount),
                ),
                _CompactRow(
                  label: 'المتبقي',
                  value: formatCurrency(order.remainingAmount),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeliveryBatchActionSection extends StatelessWidget {
  const _DeliveryBatchActionSection({
    required this.order,
    required this.onCreateBatch,
  });

  final Order order;
  final VoidCallback onCreateBatch;

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      title: 'إسناد التوصيل',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CompactRow(label: 'العنوان', value: order.fulfillmentSummary),
          _CompactRow(label: 'ملاحظات', value: order.deliveryDetails.notes),
          const SizedBox(height: 8),
          const Text(
            'مسار التوصيل الرسمي: جهّز دفعة توصيل للفرع ثم أسند الدفعة للسائق من قائمة دفعات التوصيل.',
            style: TextStyle(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w800,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: onCreateBatch,
            icon: const Icon(Icons.playlist_add_check),
            label: const Text('تجهيز دفعة توصيل'),
          ),
        ],
      ),
    );
  }
}

class _DriverPickerDialog extends StatelessWidget {
  const _DriverPickerDialog({required this.driversFuture});

  final Future<List<DriverProfile>> driversFuture;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('اختيار السائق'),
      content: SizedBox(
        width: double.maxFinite,
        child: FutureBuilder<List<DriverProfile>>(
          future: driversFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final drivers = snapshot.data ?? const [];
            if (drivers.isEmpty) {
              return const Text('لا يوجد سائقون متاحون حالياً');
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: drivers.map((driver) {
                return ListTile(
                  leading: const Icon(Icons.delivery_dining),
                  title: Text(driver.fullName),
                  subtitle: Text(
                    '${driver.phone.trim().isEmpty ? 'لا يوجد رقم جوال' : driver.phone} • ${driver.branchName} • ${driver.currentAssignedOrdersCount} طلبات',
                  ),
                  onTap: () => Navigator.pop(context, driver),
                );
              }).toList(),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
      ],
    );
  }
}

class _ProductionDepartmentSelector extends StatelessWidget {
  const _ProductionDepartmentSelector({
    required this.departments,
    required this.selected,
    required this.onChanged,
  });

  final List<ProductionDepartment> departments;
  final ProductionDepartment? selected;
  final ValueChanged<ProductionDepartment?> onChanged;

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      title: 'جهة التنفيذ',
      child: DropdownButtonFormField<ProductionDepartment>(
        key: ValueKey(selected?.id ?? 'no-production-department'),
        initialValue: selected,
        decoration: const InputDecoration(
          labelText: 'اختر جهة التنفيذ',
          prefixIcon: Icon(Icons.precision_manufacturing_outlined),
        ),
        items: departments.map((department) {
          return DropdownMenuItem(
            value: department,
            child: Text(department.name),
          );
        }).toList(),
        onChanged: onChanged,
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
      child: Column(
        children: [
          Row(
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
          const SizedBox(height: 12),
          Row(
            children: [
              _AmountBlock(label: 'الإجمالي', value: order.amount),
              _AmountBlock(label: 'العربون', value: order.depositAmount),
              _AmountBlock(label: 'المتبقي', value: order.remainingAmount),
            ],
          ),
        ],
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

class _AmountBlock extends StatelessWidget {
  const _AmountBlock({required this.label, required this.value});

  final String label;
  final num value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.goldLight,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            formatCurrency(value),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

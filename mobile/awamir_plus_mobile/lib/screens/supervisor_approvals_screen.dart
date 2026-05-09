import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../core/permissions/access_control.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../models/app_models.dart';
import '../widgets/app_header.dart';
import '../widgets/reason_input_dialog.dart';
import '../widgets/section_header.dart';
import '../widgets/state_views.dart';
import '../widgets/status_badge.dart';

class SupervisorApprovalsScreen extends StatelessWidget {
  const SupervisorApprovalsScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    if (!AccessControl.canApproveOrders(controller.currentUser)) {
      return const AccessDeniedStateView();
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final orders = controller.supervisorApprovals;
        return RefreshIndicator(
          onRefresh: controller.loadSupervisorApprovals,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              AppHeader(
                title: 'موافقات الفرع',
                subtitle:
                    AccessControl.hasPermission(
                      controller.currentUser,
                      AppPermission.systemFullAccess,
                    )
                    ? 'كل الطلبات بانتظار الموافقة'
                    : controller.currentUser.branchName,
                notificationCount: controller.unreadNotifications,
              ),
              const SizedBox(height: 14),
              SectionHeader(title: 'بانتظار موافقة المشرف'),
              if (controller.isActionLoading && orders.isEmpty)
                const SizedBox(height: 280, child: LoadingStateView())
              else if (orders.isEmpty)
                const SizedBox(
                  height: 280,
                  child: EmptyStateView(
                    message: 'لا توجد طلبات بانتظار الموافقة',
                    icon: Icons.verified_outlined,
                  ),
                )
              else
                ...orders.map(
                  (order) => _ApprovalOrderCard(
                    order: order,
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SupervisorOrderDetailScreen(
                            controller: controller,
                            order: order,
                          ),
                        ),
                      );
                      await controller.loadSupervisorApprovals();
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

class SupervisorOrderDetailScreen extends StatefulWidget {
  const SupervisorOrderDetailScreen({
    super.key,
    required this.controller,
    required this.order,
  });

  final AppController controller;
  final Order order;

  @override
  State<SupervisorOrderDetailScreen> createState() =>
      _SupervisorOrderDetailScreenState();
}

class _SupervisorOrderDetailScreenState
    extends State<SupervisorOrderDetailScreen> {
  late Order _order = widget.order;
  late Future<List<OrderStatusLog>> _logsFuture = widget.controller
      .getOrderStatusLogs(_order.id);

  bool get _canAct =>
      _order.status == OrderStatus.pendingSupervisorApproval &&
      AccessControl.canApproveOrders(widget.controller.currentUser);

  @override
  Widget build(BuildContext context) {
    if (!AccessControl.canApproveOrders(widget.controller.currentUser)) {
      return const Scaffold(body: AccessDeniedStateView());
    }

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          AppHeader(
            title: _order.id,
            subtitle: 'تفاصيل موافقة المشرف',
            showBack: true,
            onBack: () => Navigator.maybePop(context),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Column(
              children: [
                _SummaryHeader(order: _order),
                const SizedBox(height: 12),
                _InfoSection(
                  title: 'بيانات العميل',
                  rows: [
                    ('اسم العميل', _order.customer),
                    ('رقم الجوال', _order.customerPhone),
                    ('نوع العميل', _order.customerType.label),
                    if (_order.customerType == CustomerType.company)
                      ('اسم الشركة', _order.companyName),
                    if (_order.customerType == CustomerType.company)
                      ('الرقم الضريبي', _order.taxNumber),
                    if (_order.customerType == CustomerType.company)
                      ('عنوان الشركة', _order.companyAddress),
                    if (_order.customerType == CustomerType.company)
                      ('البريد الإلكتروني', _order.companyEmail),
                    if (_order.customerType == CustomerType.company)
                      ('مسؤول التواصل', _order.companyContactPerson),
                  ],
                ),
                _ProductsSection(order: _order),
                _InfoSection(
                  title: 'تفاصيل الطلب',
                  rows: [
                    ('تفاصيل الطلب', _order.details),
                    ('ملاحظات العميل', _order.customerNotes),
                    ('الأولوية', _order.priority.label),
                    ('تاريخ الاستلام', _order.pickupDateText),
                    ('وقت الاستلام', _order.pickupTimeText),
                  ],
                ),
                _InfoSection(
                  title: 'الاستلام أو التوصيل',
                  rows: [
                    ('الطريقة', _order.fulfillmentType.label),
                    (
                      _order.fulfillmentType == FulfillmentType.branchPickup
                          ? 'فرع الاستلام'
                          : 'عنوان التوصيل',
                      _order.fulfillmentSummary,
                    ),
                    if (_order.fulfillmentType ==
                        FulfillmentType.customerDelivery)
                      ('ملاحظات التوصيل', _order.deliveryDetails.notes),
                    if (_order.fulfillmentType ==
                        FulfillmentType.customerDelivery)
                      (
                        'رسوم التوصيل',
                        formatCurrency(_order.deliveryDetails.deliveryFee),
                      ),
                  ],
                ),
                _InfoSection(
                  title: 'الدفع',
                  rows: [
                    ('إجمالي الطلب', formatCurrency(_order.amount)),
                    ('العربون', formatCurrency(_order.depositAmount)),
                    ('المتبقي', formatCurrency(_order.remainingAmount)),
                    ('طريقة الدفع', _order.paymentMethod.label),
                  ],
                ),
                _AttachmentsSection(order: _order),
                _StatusLogSection(logsFuture: _logsFuture),
                const SizedBox(height: 12),
                if (_canAct) _ActionBar(onAction: _handleAction),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAction(_SupervisorAction action) async {
    switch (action) {
      case _SupervisorAction.approve:
        final confirmed = await _confirmApproval();
        if (!confirmed) return;
        final updated = await widget.controller.approveOrder(_order.id);
        if (!mounted) return;
        _handleResult(
          updated,
          successMessage: 'تمت الموافقة على الطلب وإرساله للتوزيع',
        );
      case _SupervisorAction.reject:
        final reason = await _textDialog(
          title: 'رفض الطلب',
          label: 'سبب الرفض',
          emptyMessage: 'سبب الرفض مطلوب',
          suggestions: const [
            'بيانات العميل غير مكتملة',
            'العربون غير كاف',
            'الوقت المطلوب غير متاح',
            'الصنف غير متوفر',
          ],
        );
        if (reason == null) return;
        final updated = await widget.controller.rejectOrder(_order.id, reason);
        if (!mounted) return;
        _handleResult(updated, successMessage: 'تم رفض الطلب');
      case _SupervisorAction.returnForEdit:
        final notes = await _textDialog(
          title: 'إرجاع للتعديل',
          label: 'ملاحظة التعديل',
          emptyMessage: 'ملاحظة التعديل مطلوبة',
          suggestions: const [
            'تعديل تاريخ أو وقت الاستلام',
            'تعديل المنتجات أو الكميات',
            'استكمال بيانات العميل',
            'توضيح تفاصيل الطلب',
          ],
        );
        if (notes == null) return;
        final updated = await widget.controller.returnOrderForEdit(
          _order.id,
          notes,
        );
        if (!mounted) return;
        _handleResult(updated, successMessage: 'تم إرجاع الطلب للتعديل');
    }
  }

  void _handleResult(Order? updated, {required String successMessage}) {
    final error = widget.controller.actionErrorMessage;
    if (updated == null) {
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(successMessage)));
  }

  Future<bool> _confirmApproval() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('تأكيد الموافقة'),
          content: Text('سيتم إرسال الطلب ${_order.id} إلى التوزيع.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('موافقة'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  Future<String?> _textDialog({
    required String title,
    required String label,
    required String emptyMessage,
    List<String> suggestions = const [],
  }) async {
    return showDialog<String>(
      context: context,
      builder: (_) => ReasonInputDialog(
        title: title,
        label: label,
        emptyMessage: emptyMessage,
        suggestions: suggestions,
      ),
    );
  }
}

class _ApprovalOrderCard extends StatelessWidget {
  const _ApprovalOrderCard({required this.order, required this.onTap});

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
                  label: order.fulfillmentType == FulfillmentType.branchPickup
                      ? 'الفرع'
                      : 'العنوان',
                  value: order.fulfillmentSummary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.order});

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
    final lines = order.lineItems;
    return _SectionShell(
      title: 'المنتجات',
      child: lines.isEmpty
          ? _CompactRow(label: 'المنتجات', value: order.productSummary)
          : Column(
              children: lines.map((line) {
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
            return const Padding(
              padding: EdgeInsets.all(12),
              child: LinearProgressIndicator(color: AppColors.gold),
            );
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
                    Text(
                      '${log.oldStatus.label} ← ${log.newStatus.label}',
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${log.changedByName} • ${formatDate(log.changedAt)} ${formatTime(TimeOfDay.fromDateTime(log.changedAt))}',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (log.notes.trim().isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        log.notes,
                        style: const TextStyle(
                          color: AppColors.textBody,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.onAction});

  final ValueChanged<_SupervisorAction> onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => onAction(_SupervisorAction.returnForEdit),
            icon: const Icon(Icons.reply_all),
            label: const Text('إرجاع'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => onAction(_SupervisorAction.reject),
            icon: const Icon(Icons.close),
            label: const Text('رفض'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => onAction(_SupervisorAction.approve),
            icon: const Icon(Icons.check),
            label: const Text('موافقة'),
          ),
        ),
      ],
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
            width: 106,
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

enum _SupervisorAction { approve, reject, returnForEdit }

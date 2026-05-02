import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../core/permissions/access_control.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../models/app_models.dart';
import '../widgets/app_header.dart';
import '../widgets/payment_method_selector.dart';
import '../widgets/section_header.dart';
import '../widgets/state_views.dart';
import '../widgets/status_badge.dart';

class PickupOrdersScreen extends StatelessWidget {
  const PickupOrdersScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    if (!AccessControl.canViewPickupOrders(controller.currentUser)) {
      return const AccessDeniedStateView();
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final orders = controller.branchPickupOrders;
        return RefreshIndicator(
          onRefresh: controller.loadPickupOrders,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              AppHeader(
                title: 'طلبات جاهزة للاستلام',
                subtitle: 'تحصيل المتبقي وتسليم طلبات الفرع للعملاء',
                notificationCount: controller.unreadNotifications,
              ),
              const SizedBox(height: 14),
              const SectionHeader(title: 'جاهز للاستلام من الفرع'),
              if (controller.isActionLoading && orders.isEmpty)
                const SizedBox(height: 260, child: LoadingStateView())
              else if (orders.isEmpty)
                const SizedBox(
                  height: 260,
                  child: EmptyStateView(
                    message: 'لا توجد طلبات جاهزة للاستلام في هذا الفرع',
                    icon: Icons.storefront_outlined,
                  ),
                )
              else
                ...orders.map(
                  (order) => _PickupOrderCard(
                    order: order,
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PickupOrderDetailScreen(
                            controller: controller,
                            order: order,
                          ),
                        ),
                      );
                      await controller.loadPickupOrders();
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

class PickupOrderDetailScreen extends StatefulWidget {
  const PickupOrderDetailScreen({
    super.key,
    required this.controller,
    required this.order,
  });

  final AppController controller;
  final Order order;

  @override
  State<PickupOrderDetailScreen> createState() =>
      _PickupOrderDetailScreenState();
}

class _PickupOrderDetailScreenState extends State<PickupOrderDetailScreen> {
  late Order _order = widget.order;

  @override
  Widget build(BuildContext context) {
    if (!AccessControl.canDeliverPickupOrder(widget.controller.currentUser)) {
      return const Scaffold(body: AccessDeniedStateView());
    }

    final canDeliver =
        _order.remainingAmount <= 0 ||
        AccessControl.canOverrideDeliveryWithoutFullPayment(
          widget.controller.currentUser,
        );

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          AppHeader(
            title: _order.id,
            subtitle: 'تفاصيل الاستلام من الفرع',
            showBack: true,
            onBack: () => Navigator.maybePop(context),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            child: Column(
              children: [
                _PickupSummary(order: _order),
                _InfoBox(
                  title: 'بيانات العميل والطلب',
                  rows: [
                    ('العميل', _order.customer),
                    ('الجوال', _order.customerPhone),
                    ('المنتجات', _order.productSummary),
                    ('فرع الاستلام', _order.pickupBranch),
                    ('تاريخ الاستلام', _order.pickupDateText),
                    ('وقت الاستلام', _order.pickupTimeText),
                    ('حالة الدفع', _paymentState(_order)),
                  ],
                ),
                _InfoBox(
                  title: 'الدفع',
                  rows: [
                    ('الإجمالي', formatCurrency(_order.amount)),
                    ('العربون', formatCurrency(_order.depositAmount)),
                    ('المتبقي', formatCurrency(_order.remainingAmount)),
                    ('طريقة العربون', _order.paymentMethod.label),
                  ],
                ),
                const SizedBox(height: 12),
                if (_order.remainingAmount > 0)
                  ElevatedButton.icon(
                    onPressed: _collectRemaining,
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text('تسجيل دفعة المتبقي'),
                  ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: canDeliver ? _deliver : null,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('تسليم للعميل'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _collectRemaining() async {
    final result = await showDialog<_PaymentInput>(
      context: context,
      builder: (_) => _PaymentDialog(remaining: _order.remainingAmount),
    );
    if (result == null) return;

    final updated = await widget.controller.collectRemainingPayment(
      orderId: _order.id,
      amount: result.amount,
      method: result.method,
      transactionReference: result.transactionReference,
      receiptPath: result.receiptPath,
    );
    if (!mounted) return;
    if (updated == null) {
      _showActionError();
      return;
    }
    setState(() => _order = updated);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('تم تسجيل دفعة المتبقي')));
  }

  Future<void> _deliver() async {
    final updated = await widget.controller.markPickupOrderDelivered(_order.id);
    if (!mounted) return;
    if (updated == null) {
      _showActionError();
      return;
    }
    setState(() => _order = updated);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('تم تسليم الطلب بنجاح')));
  }

  void _showActionError() {
    final error = widget.controller.actionErrorMessage;
    if (error == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  String _paymentState(Order order) {
    return order.remainingAmount <= 0 ? 'مدفوع بالكامل' : 'يوجد متبقي';
  }
}

class _PickupOrderCard extends StatelessWidget {
  const _PickupOrderCard({required this.order, required this.onTap});

  final Order order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
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
                _CompactRow(label: 'الفرع', value: order.pickupBranch),
                _CompactRow(
                  label: 'الموعد',
                  value:
                      '${order.pickupDateText}${order.pickupTimeText.isEmpty ? '' : ' • ${order.pickupTimeText}'}',
                ),
                _CompactRow(
                  label: 'الدفع',
                  value: order.remainingAmount <= 0
                      ? 'مدفوع بالكامل'
                      : 'متبقي ${formatCurrency(order.remainingAmount)}',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PickupSummary extends StatelessWidget {
  const _PickupSummary({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          Text(
            'المتبقي: ${formatCurrency(order.remainingAmount)}',
            style: const TextStyle(
              color: AppColors.goldLight,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentDialog extends StatefulWidget {
  const _PaymentDialog({required this.remaining});

  final num remaining;

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  final _receiptController = TextEditingController();
  PaymentMethod _method = PaymentMethod.cash;

  @override
  void initState() {
    super.initState();
    _amountController.text = widget.remaining.toString();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _receiptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final needsReference =
        _method == PaymentMethod.card || _method == PaymentMethod.transfer;
    return AlertDialog(
      title: const Text('تسجيل دفعة المتبقي'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'المبلغ'),
            ),
            const SizedBox(height: 12),
            PaymentMethodSelector(
              selectedMethod: _method,
              onChanged: (method) => setState(() => _method = method),
            ),
            if (needsReference) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _referenceController,
                decoration: const InputDecoration(labelText: 'رقم العملية'),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _receiptController,
              decoration: const InputDecoration(
                labelText: 'مسار صورة الإيصال (اختياري)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () {
            final amount = num.tryParse(_amountController.text.trim()) ?? 0;
            Navigator.pop(
              context,
              _PaymentInput(
                amount: amount,
                method: _method,
                transactionReference: _referenceController.text.trim(),
                receiptPath: _receiptController.text.trim(),
              ),
            );
          },
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}

class _PaymentInput {
  const _PaymentInput({
    required this.amount,
    required this.method,
    required this.transactionReference,
    required this.receiptPath,
  });

  final num amount;
  final PaymentMethod method;
  final String transactionReference;
  final String receiptPath;
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.title, required this.rows});

  final String title;
  final List<(String, String)> rows;

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
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          ...rows.map((row) => _CompactRow(label: row.$1, value: row.$2)),
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
            width: 96,
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

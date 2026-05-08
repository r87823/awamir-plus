import 'package:flutter/material.dart';

import '../controllers/app_controller.dart';
import '../core/permissions/access_control.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../models/app_models.dart';
import '../widgets/app_header.dart';
import '../widgets/delivery_proof_dialog.dart';
import '../widgets/payment_method_selector.dart';
import '../widgets/section_header.dart';
import '../widgets/state_views.dart';
import '../widgets/status_badge.dart';

class DriverOrdersScreen extends StatelessWidget {
  const DriverOrdersScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    if (!AccessControl.canViewDriverOrders(controller.currentUser)) {
      return const AccessDeniedStateView();
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final orders = controller.driverOrders;
        return RefreshIndicator(
          onRefresh: controller.loadDriverOrders,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              AppHeader(
                title: 'طلبات السائق',
                subtitle: 'استلام الطلبات وتحديث مسار التوصيل',
                notificationCount: controller.unreadNotifications,
              ),
              const SizedBox(height: 14),
              const SectionHeader(title: 'طلباتي المسندة'),
              if (controller.isActionLoading && orders.isEmpty)
                const SizedBox(height: 260, child: LoadingStateView())
              else if (orders.isEmpty)
                const SizedBox(
                  height: 260,
                  child: EmptyStateView(
                    message: 'لا توجد طلبات مسندة حالياً',
                    icon: Icons.delivery_dining_outlined,
                  ),
                )
              else
                ...orders.map(
                  (order) => _DriverOrderCard(
                    order: order,
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => DriverOrderDetailScreen(
                            controller: controller,
                            order: order,
                          ),
                        ),
                      );
                      await controller.loadDriverOrders();
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

class DriverOrderDetailScreen extends StatefulWidget {
  const DriverOrderDetailScreen({
    super.key,
    required this.controller,
    required this.order,
  });

  final AppController controller;
  final Order order;

  @override
  State<DriverOrderDetailScreen> createState() =>
      _DriverOrderDetailScreenState();
}

class _DriverOrderDetailScreenState extends State<DriverOrderDetailScreen> {
  late Order _order = widget.order;

  @override
  Widget build(BuildContext context) {
    if (!AccessControl.canUpdateDeliveryStatus(widget.controller.currentUser)) {
      return const Scaffold(body: AccessDeniedStateView());
    }

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          AppHeader(
            title: _order.id,
            subtitle: 'تفاصيل التوصيل',
            showBack: true,
            onBack: () => Navigator.maybePop(context),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            child: Column(
              children: [
                _DriverSummary(order: _order),
                _InfoBox(
                  title: 'بيانات التوصيل',
                  rows: [
                    ('العميل', _order.customer),
                    ('الجوال', _phoneText(_order.customerPhone)),
                    ('العنوان', _order.fulfillmentSummary),
                    ('رابط الموقع', _order.deliveryDetails.googleMapsUrl),
                    ('ملاحظات', _order.deliveryDetails.notes),
                    ('المتبقي', formatCurrency(_order.remainingAmount)),
                  ],
                ),
                _InfoBox(
                  title: 'المنتجات',
                  rows: [
                    ('المنتجات', _order.productSummary),
                    ('موعد الاستلام', _pickupText(_order)),
                    ('حالة التوصيل', _order.status.label),
                  ],
                ),
                const SizedBox(height: 12),
                ..._actions(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _actions() {
    final actions = <Widget>[];
    if (_order.remainingAmount > 0 &&
        AccessControl.canCollectDeliveryPayment(
          widget.controller.currentUser,
        )) {
      actions.add(
        ElevatedButton.icon(
          onPressed: _collectPayment,
          icon: const Icon(Icons.payments_outlined),
          label: const Text('تسجيل دفعة المتبقي'),
        ),
      );
      actions.add(const SizedBox(height: 8));
    }
    if (_order.status == OrderStatus.assignedToDriver) {
      actions.add(
        ElevatedButton.icon(
          onPressed: () => _update(OrderStatus.driverPickedUp),
          icon: const Icon(Icons.inventory_2_outlined),
          label: const Text('استلمت الطلب'),
        ),
      );
    }
    if (_order.status == OrderStatus.driverPickedUp) {
      actions.add(
        ElevatedButton.icon(
          onPressed: () => _update(OrderStatus.outForDelivery),
          icon: const Icon(Icons.route_outlined),
          label: const Text('في الطريق'),
        ),
      );
    }
    if (_order.status == OrderStatus.outForDelivery) {
      actions.addAll([
        ElevatedButton.icon(
          onPressed: _order.remainingAmount <= 0 ? _deliver : null,
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('تم التسليم'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _markFailed,
          icon: const Icon(Icons.report_problem_outlined),
          label: const Text('تعذر التسليم'),
        ),
      ]);
    }
    if (actions.isEmpty) {
      actions.add(
        const Text(
          'لا توجد إجراءات متاحة لهذه الحالة',
          style: TextStyle(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    return actions;
  }

  Future<void> _collectPayment() async {
    final input = await showDialog<_PaymentInput>(
      context: context,
      builder: (_) => _PaymentDialog(remaining: _order.remainingAmount),
    );
    if (input == null) return;
    final payment = await widget.controller.collectDeliveryPayment(
      orderId: _order.id,
      amount: input.amount,
      method: input.method,
      transactionReference: input.transactionReference,
      receiptPath: input.receiptPath,
    );
    if (!mounted) return;
    if (payment == null) {
      _showActionError();
      return;
    }
    final refreshed = widget.controller.driverOrders.firstWhere(
      (order) => order.id == _order.id,
      orElse: () => _order,
    );
    setState(() => _order = refreshed);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('تم تسجيل دفعة المتبقي')));
  }

  Future<void> _update(OrderStatus status) async {
    final updated = await widget.controller.updateDeliveryStatus(
      orderId: _order.id,
      status: status,
    );
    if (!mounted) return;
    if (updated == null) {
      _showActionError();
      return;
    }
    setState(() => _order = updated);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم تحديث الحالة إلى ${status.label}')),
    );
  }

  Future<void> _deliver() async {
    final proof = await showDialog<DeliveryProofInput>(
      context: context,
      builder: (_) => const DeliveryProofDialog(title: 'إثبات تسليم السائق'),
    );
    if (proof == null) return;
    await _updateWithProof(OrderStatus.delivered, proof);
  }

  Future<void> _updateWithProof(
    OrderStatus status,
    DeliveryProofInput proof,
  ) async {
    final updated = await widget.controller.updateDeliveryStatus(
      orderId: _order.id,
      status: status,
      proof: proof,
    );
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

  Future<void> _markFailed() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _TextInputDialog(
        title: 'تعذر التسليم',
        label: 'سبب تعذر التسليم',
        requiredInput: true,
      ),
    );
    if (reason == null) return;
    final updated = await widget.controller.markDeliveryFailed(
      orderId: _order.id,
      reason: reason,
    );
    if (!mounted) return;
    if (updated == null) {
      _showActionError();
      return;
    }
    setState(() => _order = updated);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('تم تسجيل تعذر التسليم')));
  }

  void _showActionError() {
    final error = widget.controller.actionErrorMessage;
    if (error == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }
}

class _DriverOrderCard extends StatelessWidget {
  const _DriverOrderCard({required this.order, required this.onTap});

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
                _CompactRow(
                  label: 'الجوال',
                  value: _phoneText(order.customerPhone),
                ),
                _CompactRow(label: 'العنوان', value: order.fulfillmentSummary),
                _CompactRow(label: 'المنتجات', value: order.productSummary),
                _CompactRow(
                  label: 'المتبقي',
                  value: formatCurrency(order.remainingAmount),
                ),
                _CompactRow(
                  label: 'ملاحظات',
                  value: order.deliveryDetails.notes,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (order.customerPhone.trim().isNotEmpty)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.call_outlined),
                          label: const Text('اتصال'),
                        ),
                      )
                    else
                      const Expanded(child: _NoPhoneIndicator()),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: order.deliveryDetails.googleMapsUrl.isEmpty
                            ? null
                            : () {},
                        icon: const Icon(Icons.location_on_outlined),
                        label: const Text('الموقع'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DriverSummary extends StatelessWidget {
  const _DriverSummary({required this.order});

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
          const SizedBox(height: 10),
          Text(
            order.assignedDriverName.isEmpty
                ? 'طلب توصيل'
                : 'السائق: ${order.assignedDriverName}',
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
            Navigator.pop(
              context,
              _PaymentInput(
                amount: num.tryParse(_amountController.text.trim()) ?? 0,
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

class _TextInputDialog extends StatefulWidget {
  const _TextInputDialog({
    required this.title,
    required this.label,
    required this.requiredInput,
  });

  final String title;
  final String label;
  final bool requiredInput;

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  final _controller = TextEditingController();
  String _error = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        maxLines: 3,
        decoration: InputDecoration(
          labelText: widget.label,
          errorText: _error.isEmpty ? null : _error,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () {
            final value = _controller.text.trim();
            if (widget.requiredInput && value.isEmpty) {
              setState(() => _error = 'هذا الحقل مطلوب');
              return;
            }
            Navigator.pop(context, value);
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
            width: 94,
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

String _pickupText(Order order) {
  return '${order.pickupDateText}${order.pickupTimeText.isEmpty ? '' : ' • ${order.pickupTimeText}'}';
}

String _phoneText(String value) {
  return value.trim().isEmpty ? 'لا يوجد رقم جوال' : value;
}

class _NoPhoneIndicator extends StatelessWidget {
  const _NoPhoneIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.creamDark),
      ),
      child: const Text(
        'لا يوجد رقم جوال',
        style: TextStyle(
          color: AppColors.textMuted,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

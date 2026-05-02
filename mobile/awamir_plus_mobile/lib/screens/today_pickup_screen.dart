import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../controllers/app_controller.dart';
import '../core/permissions/access_control.dart';
import '../core/theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../core/utils/formatters.dart';
import '../widgets/state_views.dart';

class TodayPickupScreen extends StatelessWidget {
  const TodayPickupScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (!AccessControl.canUpdateDelivery(controller.currentUser)) {
          return const AccessDeniedStateView();
        }

        return ListView(
          padding: EdgeInsets.zero,
          children: [
            const AppHeader(
              title: 'طلبات استلام اليوم',
              subtitle: 'تحصيل المتبقي قبل التسليم',
            ),
            const SizedBox(height: 14),
            if (controller.pickupOrders.isEmpty)
              const SizedBox(
                height: 260,
                child: EmptyStateView(
                  message: 'لا توجد طلبات استلام اليوم',
                  icon: Icons.local_shipping_outlined,
                ),
              )
            else
              ...controller.pickupOrders.map((order) {
                return _PickupCard(
                  order: order,
                  onPay: () => _collectPayment(context, order),
                  onDeliver: () async {
                    final delivered = await controller.deliverPickupOrder(
                      order.id,
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          delivered
                              ? 'تم التسليم بنجاح'
                              : 'لا يمكن التسليم قبل سداد كامل المبلغ',
                        ),
                      ),
                    );
                  },
                );
              }),
            const SizedBox(height: 90),
          ],
        );
      },
    );
  }

  Future<void> _collectPayment(
    BuildContext context,
    TodayPickupOrder order,
  ) async {
    final amount = await showDialog<num>(
      context: context,
      builder: (_) => _PaymentDialog(remaining: order.remaining),
    );
    if (amount == null || amount <= 0) return;
    await controller.collectPickupPayment(order.id, amount);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم استلام المبلغ')));
    }
  }
}

class _PickupCard extends StatelessWidget {
  const _PickupCard({
    required this.order,
    required this.onPay,
    required this.onDeliver,
  });

  final TodayPickupOrder order;
  final VoidCallback onPay;
  final VoidCallback onDeliver;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: order.delivered ? 0.68 : 1,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: AppColors.gold.withValues(
              alpha: order.delivered ? 0.08 : 0.16,
            ),
            width: 1.5,
          ),
          boxShadow: AppShadows.soft,
        ),
        child: Column(
          children: [
            _CardRow(label: order.customer, value: order.date, strong: true),
            _CardRow(label: order.product, value: order.branch),
            _CardRow(
              label: formatCurrency(order.amount),
              value: _paymentText(order),
              strong: true,
            ),
            if (order.delivered)
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Color(0xFF2E7D32),
                      size: 18,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'تم التسليم بنجاح',
                      style: TextStyle(
                        color: Color(0xFF2E7D32),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  children: [
                    if (!order.fullyPaid) ...[
                      Expanded(
                        child: _ActionButton(
                          label: 'السداد',
                          icon: Icons.credit_card,
                          color: const Color(0xFFE65100),
                          background: const Color(0xFFFFF3E0),
                          onTap: onPay,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: _ActionButton(
                        label: 'تم التسليم',
                        icon: Icons.local_shipping_outlined,
                        color: const Color(0xFF2E7D32),
                        background: const Color(0xFFE8F5E9),
                        enabled: order.fullyPaid,
                        onTap: onDeliver,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _paymentText(TodayPickupOrder order) {
    if (order.delivered) return 'تم التسليم';
    if (order.fullyPaid) return 'تم السداد';
    if (order.paid > 0) {
      return 'مدفوع: ${formatCurrency(order.paid)} - متبقي: ${formatCurrency(order.remaining)}';
    }
    return 'متبقي: ${formatCurrency(order.remaining)}';
  }
}

class _CardRow extends StatelessWidget {
  const _CardRow({
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: strong ? AppColors.navy : AppColors.textBody,
                fontSize: strong ? 14 : 12,
                fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: strong ? AppColors.navy : AppColors.textBody,
              fontSize: 12,
              fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.background,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color background;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(AppRadius.xs),
      child: Opacity(
        opacity: enabled ? 1 : 0.42,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(AppRadius.xs),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
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
  late final TextEditingController _amountController;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.remaining.round().toString(),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('سداد المتبقي'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('المبلغ المتبقي: ${formatCurrency(widget.remaining)}'),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'مبلغ السداد'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(
            context,
          ).pop(num.tryParse(_amountController.text) ?? 0),
          child: const Text('تأكيد'),
        ),
      ],
    );
  }
}

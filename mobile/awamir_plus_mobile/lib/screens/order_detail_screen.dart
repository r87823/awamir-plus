import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import '../models/app_models.dart';
import '../widgets/app_header.dart';
import '../widgets/status_badge.dart';

class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          AppHeader(
            title: order.id,
            subtitle: 'تفاصيل الطلب',
            showBack: true,
            onBack: () => Navigator.maybePop(context),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
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
                            color: AppColors.navy,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      StatusBadge(status: order.status),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _InfoRow(
                    icon: Icons.inventory_2_outlined,
                    label: 'المنتجات',
                    value: order.productSummary,
                  ),
                  _InfoRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'تاريخ الإنشاء',
                    value: order.date,
                  ),
                  _InfoRow(
                    icon: Icons.payments_outlined,
                    label: 'إجمالي الطلب',
                    value: formatCurrency(order.amount),
                  ),
                  _InfoRow(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'المتبقي',
                    value: formatCurrency(order.remainingAmount),
                  ),
                  _InfoRow(
                    icon: order.paymentMethod.icon,
                    label: 'طريقة الدفع',
                    value: order.paymentMethod.label,
                  ),
                  if (order.createdBranch.isNotEmpty)
                    _InfoRow(
                      icon: Icons.add_business_outlined,
                      label: 'فرع الإنشاء',
                      value: order.createdBranch,
                    ),
                  if (order.pickupBranch.isNotEmpty)
                    _InfoRow(
                      icon: Icons.storefront_outlined,
                      label: 'فرع الاستلام',
                      value: order.pickupBranch,
                    ),
                  if (order.details.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.cream,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        order.details,
                        style: const TextStyle(
                          color: AppColors.textBody,
                          height: 1.45,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.goldDark, size: 20),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value.trim().isEmpty ? '-' : value,
              style: const TextStyle(
                color: AppColors.navy,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';
import 'status_badge.dart';

class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.order,
    this.compact = false,
    this.onTap,
  });

  final Order order;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 20, vertical: 5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: Colors.black.withValues(alpha: 0.03)),
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
                          fontSize: 14,
                        ),
                      ),
                    ),
                    StatusBadge(status: order.status),
                  ],
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  label: 'العميل',
                  value: order.customer,
                  icon: Icons.person_outline,
                ),
                _InfoRow(
                  label: 'الطلب',
                  value: order.productSummary,
                  icon: Icons.inventory_2_outlined,
                ),
                Row(
                  children: [
                    Expanded(
                      child: _InlineInfo(
                        icon: Icons.calendar_today,
                        text: order.date,
                      ),
                    ),
                    Text(
                      formatCurrency(order.amount),
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                if (!compact) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: List.generate(4, (index) {
                      final done = order.progress >= index + 1;
                      return Expanded(
                        child: Container(
                          height: 4,
                          margin: EdgeInsetsDirectional.only(
                            end: index == 3 ? 0 : 4,
                          ),
                          decoration: BoxDecoration(
                            color: done ? AppColors.gold : AppColors.creamDark,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: _InlineInfo(icon: icon, text: value),
          ),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineInfo extends StatelessWidget {
  const _InlineInfo({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.textMuted, size: 15),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textBody,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

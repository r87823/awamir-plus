import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/formatters.dart';

class DailyCashSummaryCard extends StatelessWidget {
  const DailyCashSummaryCard({
    super.key,
    required this.total,
    required this.cash,
    required this.card,
    required this.transfer,
    required this.date,
    required this.branch,
    required this.orderCount,
  });

  final num total;
  final num cash;
  final num card;
  final num transfer;
  final String date;
  final String branch;
  final int orderCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [AppColors.navy, AppColors.navyDark],
            ),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
            boxShadow: AppShadows.strong,
          ),
          child: Column(
            children: [
              const Text(
                'إجمالي العهدة',
                style: TextStyle(
                  color: AppColors.goldLight,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                formatCurrency(total),
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '$date — $branch — $orderCount طلبات',
                style: const TextStyle(
                  color: Color(0x88FFFFFF),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: _MethodCard(method: PaymentMethod.cash, amount: cash),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MethodCard(method: PaymentMethod.card, amount: card),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MethodCard(
                  method: PaymentMethod.transfer,
                  amount: transfer,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MethodCard extends StatelessWidget {
  const _MethodCard({required this.method, required this.amount});

  final PaymentMethod method;
  final num amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.08)),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        children: [
          Icon(method.icon, color: _methodColor(method), size: 24),
          const SizedBox(height: 5),
          Text(
            formatCurrency(amount, symbol: false),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.navy,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          Text(
            method.label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Color _methodColor(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return AppColors.green;
      case PaymentMethod.card:
        return const Color(0xFF1565C0);
      case PaymentMethod.transfer:
        return AppColors.goldDark;
      case PaymentMethod.other:
        return AppColors.textMuted;
    }
  }
}

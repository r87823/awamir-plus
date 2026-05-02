import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../controllers/app_controller.dart';
import '../core/permissions/access_control.dart';
import '../core/theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/daily_cash_summary_card.dart';
import '../core/utils/formatters.dart';
import '../widgets/section_header.dart';
import '../widgets/state_views.dart';

class DailyCashScreen extends StatelessWidget {
  const DailyCashScreen({
    super.key,
    required this.controller,
    this.showBack = true,
  });

  final AppController controller;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          if (!AccessControl.canViewMyCashClosure(controller.currentUser)) {
            return const AccessDeniedStateView();
          }

          final closure = controller.dailyCashClosure;
          if (closure == null) {
            return const EmptyStateView(
              message: 'لا توجد عهدة يومية حالياً',
              icon: Icons.account_balance_wallet_outlined,
            );
          }
          final cash = controller.methodTotal(PaymentMethod.cash);
          final card = controller.methodTotal(PaymentMethod.card);
          final transfer = controller.methodTotal(PaymentMethod.transfer);
          final other = controller.methodTotal(PaymentMethod.other);
          final canSubmit =
              AccessControl.canSubmitCashClosure(controller.currentUser) &&
              (closure.status == CashClosureStatus.open ||
                  closure.status == CashClosureStatus.returnedForReview);

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              AppHeader(
                title: 'عهدتي اليومية',
                compact: true,
                showBack: showBack,
              ),
              const SizedBox(height: 18),
              _ClosureOwnerCard(closure: closure),
              const SizedBox(height: 14),
              DailyCashSummaryCard(
                total: controller.collectedDeposit,
                cash: cash,
                card: card,
                transfer: transfer,
                date: closure.date,
                branch: closure.branch,
                orderCount: closure.orderCount,
              ),
              const SizedBox(height: 18),
              const SectionHeader(title: 'الدفعات المرتبطة'),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  boxShadow: AppShadows.soft,
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: const BoxDecoration(
                        color: AppColors.navy,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(AppRadius.md),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Expanded(
                            child: Text(
                              'الطلب',
                              style: TextStyle(
                                color: AppColors.white,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Text(
                            'التفاصيل',
                            style: TextStyle(
                              color: AppColors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (closure.payments.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(18),
                        child: Text(
                          'لا توجد دفعات مرتبطة بهذه العهدة',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    else
                      ...closure.payments.map(
                        (payment) => _PaymentRow(payment: payment),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: const BoxDecoration(
                        color: AppColors.cream,
                        border: Border(
                          top: BorderSide(color: AppColors.gold, width: 2),
                        ),
                        borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(AppRadius.md),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'الإجمالي',
                              style: TextStyle(
                                color: AppColors.navy,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Text(
                            formatCurrency(closure.total),
                            style: const TextStyle(
                              color: AppColors.goldDark,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  boxShadow: AppShadows.soft,
                ),
                child: Column(
                  children: [
                    _SummaryLine(
                      label: 'نوع العهدة',
                      value: closure.type.label,
                      color: AppColors.navy,
                    ),
                    _SummaryLine(
                      label: 'حالة العهدة',
                      value: closure.status.label,
                      color: AppColors.goldDark,
                    ),
                    _SummaryLine(
                      label: 'إجمالي النقد',
                      value: formatCurrency(cash),
                      color: AppColors.green,
                    ),
                    _SummaryLine(
                      label: 'إجمالي الشبكة',
                      value: formatCurrency(card),
                      color: AppColors.navy,
                    ),
                    _SummaryLine(
                      label: 'إجمالي التحويل',
                      value: formatCurrency(transfer),
                      color: AppColors.navy,
                    ),
                    _SummaryLine(
                      label: 'طرق دفع أخرى',
                      value: formatCurrency(other),
                      color: AppColors.navy,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: controller.loadMyCashClosure,
                        icon: const Icon(Icons.refresh),
                        label: const Text('تحديث'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: canSubmit
                            ? () async {
                                final submitted = await controller
                                    .submitDailyCashClosure();
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      submitted
                                          ? 'تم إرسال العهدة لأمين الصندوق'
                                          : controller.actionErrorMessage ??
                                                'تعذر إرسال العهدة اليومية',
                                    ),
                                  ),
                                );
                              }
                            : null,
                        icon: const Icon(Icons.send),
                        label: const Text('إرسال العهدة'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ClosureOwnerCard extends StatelessWidget {
  const _ClosureOwnerCard({required this.closure});

  final DailyCashClosure closure;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        children: [
          _DarkLine(label: 'صاحب العهدة', value: closure.ownerName),
          _DarkLine(label: 'الدور', value: closure.ownerRoleLabel),
          _DarkLine(label: 'الفرع', value: closure.branch),
          _DarkLine(label: 'رقم العهدة', value: closure.id),
        ],
      ),
    );
  }
}

class _DarkLine extends StatelessWidget {
  const _DarkLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.goldLight,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.payment});

  final OrderPayment payment;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.creamDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                payment.orderId,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  payment.customer,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textBody,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _methodBackground(payment.method),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  payment.method.label,
                  style: TextStyle(
                    color: _methodColor(payment.method),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatCurrency(payment.amount),
                style: const TextStyle(
                  color: AppColors.goldDark,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            '${payment.status.label}${payment.transactionReference.isEmpty ? '' : ' • عملية ${payment.transactionReference}'} • ${formatTime(TimeOfDay.fromDateTime(payment.createdAt))}',
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

  Color _methodBackground(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return const Color(0xFFE8F5E9);
      case PaymentMethod.card:
        return const Color(0xFFE3F2FD);
      case PaymentMethod.transfer:
        return const Color(0xFFFFF3E0);
      case PaymentMethod.other:
        return const Color(0xFFECEFF1);
    }
  }

  Color _methodColor(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return const Color(0xFF2E7D32);
      case PaymentMethod.card:
        return const Color(0xFF1565C0);
      case PaymentMethod.transfer:
        return const Color(0xFFE65100);
      case PaymentMethod.other:
        return AppColors.textMuted;
    }
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textBody,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
